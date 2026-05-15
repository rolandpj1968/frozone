# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Universal call protocol: every Ruby method takes
#   m_X(Array* args, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()).
# Bodies unpack required positional params from `args` via
# array_at(args, i). Block is always available as `_block` (or
# user-named &blk). Specialisation slots like `m_X_<arity>(arg)`
# are a future optimisation layer; not generated here.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class MethodEmitter
          # Writes a virtual method on a user class (or MainObject).
          # Captures the body first so an EmissionError mid-body leaves
          # nothing committed — the method is silently skipped (it falls
          # through to BasicObject's universal m_X stub at runtime,
          # which calls method_missing).
          def self.write_user_method(emit, name, method)
            cpp_name = Cpp.method_name(name)
            sig = emit.natural_arity_names[name]
            family = emit.respond_to?(:multi_arity_table) ? emit.multi_arity_table[name] : nil
            kw_sig = emit.respond_to?(:kw_unset_table) ? emit.kw_unset_table[name] : nil
            if sig
              emit.line "using BasicObject::#{cpp_name};"
              write_natural_arity_method(emit, name, method, cpp_name, sig)
            elsif family
              emit.line "using BasicObject::#{cpp_name};"
              write_multi_arity_method(emit, name, method, cpp_name, family)
            elsif kw_sig
              emit.line "using BasicObject::#{cpp_name};"
              write_kw_unset_method(emit, name, method, cpp_name, kw_sig)
            else
              write_universal_method(emit, name, method, cpp_name)
            end
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && emit.strict_emit
            loc = method&.source_location || "(unknown)"
            $stderr.puts "[box-first] skip user_method :#{name} @ #{loc}: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
            msg = "[frozone-box-first] unimplemented method :#{name} (def @ #{loc}): #{e.message}"
            sig = emit.natural_arity_names[name]
            family = emit.respond_to?(:multi_arity_table) ? emit.multi_arity_table[name] : nil
            kw_sig = emit.respond_to?(:kw_unset_table) ? emit.kw_unset_table[name] : nil
            abort_body = lambda do
              emit.indented do
                emit.line %|std::fprintf(stderr, "%s\\n", #{emit.cpp.cpp_string_literal(msg)});|
                emit.line "std::abort();"
              end
              emit.line "}"
            end
            if family
              family.arities.to_a.sort.each do |k|
                params = (0...k).map { |i| "BasicObject* l_a#{i}" }.join(', ')
                emit.line "virtual BasicObject* #{cpp_name}(#{params}) {"
                abort_body.call
              end
              return
            end
            if kw_sig
              n_pos = kw_sig.arity_req + kw_sig.opt
              pos = (0...n_pos).map { |i| "BasicObject* l_a#{i}" }
              kw = kw_sig.all_kw_names.map { |kn| "BasicObject* #{local_cpp_name(kn)}" }
              emit.line "virtual BasicObject* #{cpp_name}(#{(pos + kw).join(', ')}) {"
              abort_body.call
              return
            end
            if sig
              pos = (0...sig.arity_req).map { |i| "BasicObject* l_a#{i}" }
              kw = sig.required_kw_names.map { |kn| "BasicObject* #{local_cpp_name(kn)}" }
              emit.line "virtual BasicObject* #{cpp_name}(#{(pos + kw).join(', ')}) {"
            else
              emit.line "virtual BasicObject* #{cpp_name}(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {"
            end
            abort_body.call
          end

          # Today's universal-signature emission. Body unpacks args via
          # array_at, runs under try/catch ReturnException for
          # return-from-block semantics.
          def self.write_universal_method(emit, _name, method, cpp_name)
            captured = method.body ? collect_method_captured(method) : Set.new
            body_buf = emit.cpp.with_captured_locals(captured) do
            emit.capture do
              locals = unpack_params(emit, method)
              # Wrap in try/catch ReturnException so `return v` inside a
              # block (which throws rather than C++-returns) lands here
              # and yields the method's return value. Zero overhead on
              # the success path; the throw cost (~microseconds) is
              # only paid when a block actually return-from-method's,
              # which is rare. Conditional-wrap (only when the body
              # contains a block whose body contains return) is a
              # follow-up optimisation.
              # Frame-targeted: __frame_id__ is unique per invocation;
              # mismatched throws re-raise so they propagate to the
              # method that owns the block (Ruby's return-from-block
              # semantics). See ReturnException doc in box_first.hpp.
              emit.line "std::uint64_t __frame_id__ = next_frame_id();"
              emit.line "try {"
              emit.indented do
                if method.body
                  ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true)
                end
                emit.line "return nil_instance();"
              end
              emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
            end
            end
            emit.line "virtual BasicObject* #{cpp_name}(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {"
            emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          # Natural-arity method emission. Gated by
          # FROZONE_NATURAL_ARGS=1 — when off, emit.natural_arity_names
          # is empty and this path is unreachable.
          #
          # Emits a SINGLE virtual slot with positional signature
          # `virtual m_<name>(BasicObject* l_a1, ..., BasicObject* l_aN)`.
          # No universal-signature slot exists for eligible names:
          # METHOD_VT[id] is nullptr, dynamic dispatch routes through
          # TRAMPOLINE_VT[id] (send / mm_dispatch), and compatible
          # direct call sites emit recv->m_<name>(a1, ...) bypassing
          # the trampoline entirely (see cpp.rb#from_method_call).
          #
          # Body skips the universal-protocol unpack: params come in
          # as named C++ parameters (no array_at), no arity check
          # (signature enforces), no kwargs-fold (eligibility implies
          # no kw params), no block alias (eligibility implies no
          # caller passes a block and no body yields).
          def self.write_natural_arity_method(emit, _name, method, cpp_name, sig)
            required = method.required_params || []
            req_kw = (method.required_kw_params || []).map(&:to_sym).sort
            # The slot signature has arity_req positional slots
            # followed by required_kw_names slots (sorted Symbol order
            # — matches sig.required_kw_names). Each slot binds to a
            # named local via decl_local_line in the body prologue.
            if required.length != sig.arity_req ||
               !(method.optional_params || []).empty? ||
               !(method.post_params || []).empty? ||
               method.rest_param ||
               method.kw_rest_param ||
               !(method.optional_kw_params || []).empty? ||
               req_kw != sig.required_kw_names ||
               method.block_param
              raise Cpp::EmissionError, "natural-arity shape mismatch for #{cpp_name}: def doesn't fit #{sig}"
            end

            pos_decls = required.each_with_index.map { |_, i| "BasicObject* _arg#{i}" }
            kw_decls = sig.required_kw_names.map { |kn| "BasicObject* _kw_#{kn}" }
            param_decls = pos_decls + kw_decls
            captured = method.body ? collect_method_captured(method) : Set.new
            body_buf = emit.cpp.with_captured_locals(captured) do
            emit.capture do
              locals = Set.new
              required.each_with_index do |p, i|
                emit.line decl_local_line(emit, p, "_arg#{i}")
                locals << p.to_s
              end
              sig.required_kw_names.each do |kn|
                emit.line decl_local_line(emit, kn, "_kw_#{kn}")
                locals << kn.to_s
              end
              # Eligibility disqualifies methods that use yield /
              # block_given? in their body, so `_block` is never
              # referenced — don't emit it. Universal-sig emits
              # `Proc* _block = static_cast<Proc*>(block);` to support
              # those constructs; natural-arity doesn't need to.
              seen_writes = collect_local_writes(method.body)
              ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                s = loc.to_s
                next if s.empty? || locals.include?(s)
                emit.line decl_local_line(emit, s, "nil_instance()")
                locals << s
              end
              emit.line "std::uint64_t __frame_id__ = next_frame_id();"
              emit.line "try {"
              emit.indented do
                ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true) if method.body
                emit.line "return nil_instance();"
              end
              emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
            end
            end
            emit.line "virtual BasicObject* #{cpp_name}(#{param_decls.join(', ')}) {"
            emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          # Defaults beachhead: emit one inline entry point per servable
          # arity. Each fills its remaining defaults in declaration
          # order (later defaults can reference earlier params via
          # decl_local_line) before running the shared body. Method
          # body emission is the same as natural-arity; only the
          # default-fill prefix differs across entries.
          def self.write_multi_arity_method(emit, _name, method, cpp_name, family)
            required = method.required_params || []
            optional = method.optional_params || []
            arity_req = required.length
            arity_max = arity_req + optional.length
            captured = method.body ? collect_method_captured(method) : Set.new
            family.arities.to_a.sort.each do |k|
              params = (0...k).map { |i| "BasicObject* _arg#{i}" }.join(', ')
              if k < arity_req || k > arity_max
                # Cross-class wrong-args stub — this method's def doesn't
                # serve arity k, but another defining class does. Raise
                # ArgumentError so a call at arity k on this class's
                # instance gets the right error, not method_missing.
                check_call = arity_req == arity_max ?
                  "check_arity_fixed(#{k}, #{arity_req});" :
                  "check_arity_range(#{k}, #{arity_req}, #{arity_max});"
                emit.line "virtual BasicObject* #{cpp_name}(#{params}) {"
                emit.indented do
                  emit.line check_call
                  emit.line "return nil_instance();"
                end
                emit.line "}"
                next
              end
              bound_opt = k - arity_req
              body_buf = emit.cpp.with_captured_locals(captured) do
                emit.capture do
                  locals = Set.new
                  required.each_with_index do |p, i|
                    emit.line decl_local_line(emit, p, "_arg#{i}")
                    locals << p.to_s
                  end
                  optional.first(bound_opt).each_with_index do |(p, _), j|
                    idx = arity_req + j
                    emit.line decl_local_line(emit, p, "_arg#{idx}")
                    locals << p.to_s
                  end
                  optional.drop(bound_opt).each do |(p, default_node)|
                    default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
                    emit.line decl_local_line(emit, p, default_str)
                    locals << p.to_s
                  end
                  seen_writes = collect_local_writes(method.body)
                  ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                    s = loc.to_s
                    next if s.empty? || locals.include?(s)
                    emit.line decl_local_line(emit, s, "nil_instance()")
                    locals << s
                  end
                  emit.line "std::uint64_t __frame_id__ = next_frame_id();"
                  emit.line "try {"
                  emit.indented do
                    ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true) if method.body
                    emit.line "return nil_instance();"
                  end
                  emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
                end
              end
              emit.line "virtual BasicObject* #{cpp_name}(#{params}) {"
              emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
              emit.line "}"
            end
          end

          # Kw-bearing top-level method emission. Slot signature: required
          # pos → opt pos (UNSET-able) → kws alphabetical. Body declares
          # locals from slot params, default-filling UNSET-marked slots
          # in source order so later defaults can read earlier params.
          def self.write_kw_unset_method(emit, _name, method, cpp_name, sig)
            required = method.required_params || []
            optional = method.optional_params || []
            opt_kw_pairs = method.optional_kw_params || []
            opt_kw_defaults = opt_kw_pairs.to_h { |p, default| [p.to_sym, default] }
            if !(method.post_params || []).empty? || method.rest_param || method.kw_rest_param || method.block_param
              raise Cpp::EmissionError, "kw-unset requires pure positional+kw def"
            end
            if required.length != sig.arity_req || optional.length != sig.opt
              raise Cpp::EmissionError, "kw-unset shape mismatch for #{cpp_name}"
            end
            captured = method.body ? collect_method_captured(method) : Set.new
            body_buf = emit.cpp.with_captured_locals(captured) do
              emit.capture do
                locals = Set.new
                required.each_with_index do |p, i|
                  emit.line decl_local_line(emit, p, "_arg#{i}")
                  locals << p.to_s
                end
                optional.each_with_index do |(p, default_node), i|
                  slot = "_arg#{sig.arity_req + i}"
                  default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
                  emit.line decl_local_line(emit, p, "(#{slot} == unset_instance()) ? (#{default_str}) : #{slot}")
                  locals << p.to_s
                end
                sig.all_kw_names.each do |kn|
                  if sig.kw_required?(kn)
                    emit.line decl_local_line(emit, kn, "_kw_#{kn}")
                  else
                    default_node = opt_kw_defaults[kn]
                    default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
                    emit.line decl_local_line(emit, kn, "(_kw_#{kn} == unset_instance()) ? (#{default_str}) : _kw_#{kn}")
                  end
                  locals << kn.to_s
                end
                seen_writes = collect_local_writes(method.body)
                ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                  s = loc.to_s
                  next if s.empty? || locals.include?(s)
                  emit.line decl_local_line(emit, s, "nil_instance()")
                  locals << s
                end
                emit.line "std::uint64_t __frame_id__ = next_frame_id();"
                emit.line "try {"
                emit.indented do
                  ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true) if method.body
                  emit.line "return nil_instance();"
                end
                emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
              end
            end
            pos_params = (0...sig.arity_req).map { |i| "BasicObject* _arg#{i}" } +
                         (0...sig.opt).map { |i| "BasicObject* _arg#{sig.arity_req + i}" }
            kw_params = sig.all_kw_names.map { |kn| "BasicObject* _kw_#{kn}" }
            emit.line "virtual BasicObject* #{cpp_name}(#{(pos_params + kw_params).join(', ')}) {"
            emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          # C++ reserved words / contextual keywords that surface as
          # Ruby identifier names from time to time (the most common
          # ones in core/4.0/). When a Ruby local/param has one of
          # these names, mangle to `rb__<name>__` consistently across
          # all emission sites — `local_cpp_name(:char)` → `rb__char__`.
          CPP_KEYWORDS = %w[
            enum class struct union template operator this namespace
            new delete default public private protected friend virtual
            override final const static extern inline mutable register
            signed unsigned void char short int long float double bool
            auto typedef typename try catch throw decltype constexpr
            return goto switch case break continue if else while do for
          ].to_set.freeze

          # User-named locals/params live in the `l_*` namespace —
          # `def foo(args, block); args.length; end` lowers to
          # `BasicObject* l_args = array_at(args, 0); l_args->m_length();`
          # so it can never collide with the universal-protocol slots
          # (`args`, `kwargs`, `block`) or with C++ keywords. C++ doesn't
          # reserve `l_class` / `l_enum` / etc., so the prefix subsumes
          # the keyword-mangle path.
          def self.local_cpp_name(name)
            "l_#{name}"
          end

          # Emit unpack-from-args lines for required positional params,
          # optional positional params (with C++ ternary against
          # args->data.size()), rest collection, and a `Proc* _block =
          # block;` alias (so from_yield's `_block` always resolves).
          # If the user named the block (`&blk`), emit a second alias.
          # Post/kw/kw_rest params raise EmissionError so the method
          # gets gracefully dropped.
          # Universal-protocol parameter names — collisions with these
          # in user param/local names break the body. `args` is the
          # most common collision (any method with `def foo(args, ...)`
          # would emit `BasicObject* args = array_at(args, 0);` —
          # initialiser refers to itself).
          UNIVERSAL_PARAM_NAMES = %w[args kwargs block].to_set.freeze

          # Emit a local decl line: BasicObject* form for stack locals,
          # BasicObject** (heap cell) form for locals captured by inner
          # blocks. The cell-pointer form is what lets a Proc capture
          # the address of the cell by value and outlive the enclosing
          # stack frame; reads/writes go through `*l_x` (see Cpp.captured?).
          def self.decl_local_line(emit, name, init_expr)
            cpp = local_cpp_name(name)
            if emit.cpp.captured?(name)
              "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init_expr});"
            else
              "BasicObject* #{cpp} = #{init_expr};"
            end
          end

          # Emit the positional arity validation at method body entry,
          # AFTER the kwargs-fold (so the effective arg count reflects
          # the Ruby-2-style trailing-Hash binding). Three forms:
          #   *rest  with required>=1   → check_arity_min
          #   *rest  with required==0   → no check (anything goes)
          #   defaults && no *rest      → check_arity_range
          #   no defaults && no *rest   → check_arity_fixed
          # Helpers are inline in frozone_post.hpp; raise functions are
          # KernelFns in frozone_universe.cpp.
          def self.emit_arity_check(emit, method)
            req = (method.required_params || []).size + (method.post_params || []).size
            opt = (method.optional_params || []).size
            has_rest = !method.rest_param.nil?
            if has_rest
              return if req == 0
              emit.line "check_arity_min(args->data.size(), #{req});"
            elsif opt == 0
              emit.line "check_arity_fixed(args->data.size(), #{req});"
            else
              emit.line "check_arity_range(args->data.size(), #{req}, #{req + opt});"
            end
          end

          def self.unpack_params(emit, method)
            locals = Set.new
            required = method.required_params || []
            # Ruby-2-style trailing hash: if the method declares no kw
            # params (no required_kw_params, optional_kw_params, or
            # kw_rest_param), and a caller passes `f(a, b, x: 1, y:
            # 2)`, MRI binds `{x: 1, y: 2}` to the trailing positional
            # parameter (not as a separate kwargs Hash). The Frozone
            # interpreter follows this; box-first call sites pass
            # kwargs as a separate Hash* arg, so the callee never sees
            # it. Fix: at param-bind time, if the method has no kw
            # params and kwargs is non-empty, append it as the last
            # positional arg before binding. This unblocks the parser
            # gem (`AST::Node.new(type, children, location: map)` ↦
            # `def initialize(type, children=[], properties={})`).
            has_kw = !(method.required_kw_params || []).empty? ||
                     !(method.optional_kw_params || []).empty? ||
                     !!method.kw_rest_param
            unless has_kw
              emit.line "if (!kwargs->data.empty()) { Array* _ext = new Array(); _ext->data = args->data; Hash* _h = new Hash(); _h->data = kwargs->data; _ext->data.push_back(static_cast<BasicObject*>(_h)); args = _ext; }"
            end
            emit_arity_check(emit, method)
            required.each_with_index do |p, i|
              emit.line decl_local_line(emit, p, "array_at(args, #{i})")
              locals << p.to_s
            end
            optional = method.optional_params || []
            optional.each_with_index do |(p, default_node), i|
              idx = required.length + i
              default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
              emit.line decl_local_line(emit, p, "(args->data.size() > #{idx}) ? args->data[#{idx}] : (#{default_str})")
              locals << p.to_s
            end
            if method.post_params && !method.post_params.empty?
              raise Cpp::EmissionError, "method with post-required params not yet supported"
            end
            (method.optional_kw_params || []).each do |(p, default_node)|
              default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
              key_lit = emit.cpp.cpp_string_literal(p.to_s)
              emit.line decl_local_line(emit, p, "[&]() -> BasicObject* { auto _it = kwargs->data.find(intern(#{key_lit})); return _it == kwargs->data.end() ? (#{default_str}) : _it->second; }()")
              locals << p.to_s
            end
            (method.required_kw_params || []).each do |p|
              key_lit = emit.cpp.cpp_string_literal(p.to_s)
              emit.line decl_local_line(emit, p, %|(kwargs->data.find(intern(#{key_lit})) != kwargs->data.end()) ? kwargs->data[intern(#{key_lit})] : ([&]() -> BasicObject* { std::fprintf(stderr, "[box-first] missing required kw arg :#{p}\\n"); std::abort(); }())|)
              locals << p.to_s
            end
            if method.kw_rest_param
              # `**rest` — bind a Hash of all kwargs not consumed by
              # named kw params. Local is BasicObject* (not Hash*) so
              # user code that reassigns `opts = ...` from a vtable
              # call result type-checks. The consumed-set is computed
              # at AOT time as a symbol-comparison list.
              name = method.kw_rest_param.to_s
              name = "_kwrest" if name.empty? || name == "**"
              cpp_name = local_cpp_name(name)
              consumed = ((method.optional_kw_params || []).map { |p, _| p.to_s } +
                          (method.required_kw_params || []).map(&:to_s)).uniq
              consumed_check = consumed.map { |k|
                "_k == intern(#{emit.cpp.cpp_string_literal(k)})"
              }.join(" || ")
              consumed_check = "false" if consumed_check.empty?
              emit.line "Hash* __#{cpp_name}_h__ = new Hash();"
              emit.line "for (auto& _kv : kwargs->data) {"
              emit.line "  auto* _k = static_cast<Symbol*>(_kv.first);"
              emit.line "  if (!(#{consumed_check})) __#{cpp_name}_h__->data[_kv.first] = _kv.second;"
              emit.line "}"
              emit.line decl_local_line(emit, name, "static_cast<BasicObject*>(__#{cpp_name}_h__)")
              locals << name
            end
            if method.rest_param
              name = method.rest_param.to_s
              name = "_rest" if name.empty? || name == "*"
              cpp_name = local_cpp_name(name)
              start_idx = required.length + optional.length
              if start_idx == 0
                emit.line decl_local_line(emit, name, "static_cast<BasicObject*>(args)") + "  // *rest = whole args"
              else
                emit.line "Array* __#{cpp_name}_rest__ = new Array();"
                emit.line "for (std::size_t _i = #{start_idx}; _i < args->data.size(); _i++) {"
                emit.line "  __#{cpp_name}_rest__->data.push_back(args->data[_i]);"
                emit.line "}"
                emit.line decl_local_line(emit, name, "static_cast<BasicObject*>(__#{cpp_name}_rest__)")
              end
              locals << name
            end
            # _block is the internal alias used by from_yield (it stays
            # as `_block` rather than `l__block` because it isn't a
            # user-named local and never appears in user-source code).
            # Type stays Proc* — yield sites do `_block->m_call(...)` and
            # need the narrowed type. Absent-block is `nil_instance()` at
            # the call surface; yield-without-block is invalid Ruby
            # (LocalJumpError) so the cast is safe by precondition.
            emit.line "Proc* _block = static_cast<Proc*>(block);"
            user_block = user_block_name(method)
            if user_block
              # `def foo(&blk)` — bind a user-facing local of type
              # BasicObject* (not Proc*) so user code can reassign it
              # from any vtable-call result without C++ type errors.
              # `truthy(l_blk)`, `l_blk->m_call(...)` (universal surface)
              # both work without a static_cast.
              emit.line decl_local_line(emit, user_block, "block")
              locals << user_block
            end
            # Pre-declare every other local in the method's `locals`
            # list. Without this, locals first-written inside an `if`
            # branch are scoped to that branch, and a sibling branch
            # that reads/writes them produces "not declared" errors.
            # Pre-declaring at method scope mirrors Ruby's behavior
            # (locals are method-scoped, not block-scoped).
            # Also scans the body for LocalVariableWrites so locals
            # whose first write is inside a graceful-degradation-skipped
            # statement still get a declaration (subsequent reads work).
            # User names get the `l_` prefix from local_cpp_name, so
            # they can't collide with the universal protocol slots.
            seen_writes = collect_local_writes(method.body)
            ((method.locals || []) + seen_writes.to_a).uniq.each do |name|
              s = name.to_s
              next if s.empty? || locals.include?(s)
              emit.line decl_local_line(emit, s, "nil_instance()")
              locals << s
            end
            locals
          end

          # Walk the method body collecting every LocalVariableWrite
          # name (including ones inside blocks — Ruby leaks block-locals
          # to the enclosing scope when first-written, our model treats
          # them all as method-scope to keep them visible across blocks).
          # Compute the set of locals that should be heap-cells for a
          # METHOD body. own_locals = parser-tracked locals + every
          # name written anywhere in the body (since unpack_params
          # hoists block-locals to method scope) + params. captured =
          # subset of own_locals referenced inside any nested block.
          def self.collect_method_captured(method)
            param_names = (method.required_params || []) +
                          (method.optional_params || []).map(&:first) +
                          (method.post_params || []) +
                          (method.required_kw_params || []) +
                          (method.optional_kw_params || []).map(&:first) +
                          [method.kw_rest_param, method.rest_param, method.block_param].compact
            own = Set.new(param_names.map(&:to_s)) |
                  Set.new((method.locals || []).map(&:to_s)) |
                  collect_local_writes(method.body)
            LambdaEmitter.collect_captured_locals(method.body, own)
          end

          def self.collect_local_writes(body)
            names = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              names << node.name.to_s if node.is_a?(Ast::LocalVariableWrite)
              # MultipleAssignment targets: descriptors `[:local, name]`
              # or `[:local_splat, name]` — these declare locals too,
              # and unpack_params hoists them to method scope, so they
              # belong in the captured-set walk's own_locals.
              if node.is_a?(Ast::MultipleAssignment) && node.respond_to?(:targets)
                node.targets.each do |t|
                  next unless t.is_a?(Array)
                  names << t[1].to_s if t[1].is_a?(Symbol) && %i[local local_splat].include?(t[0])
                end
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            walk.call(body) if body
            names
          end

          def self.user_block_name(method)
            return nil unless method.block_param
            n = method.block_param.to_s
            (n.empty? || n == "&") ? nil : n
          end

          # Legacy direct-positional sig — used by build_ctor in
          # emitter.rb. Constructors don't go through the universal
          # call protocol; they're invoked via `new ClassName(args...)`
          # from ExprEmitter's special `.new` handling.
          def self.build_params(method)
            parts = []
            locals = Set.new
            (method.required_params || []).each do |p|
              parts << "BasicObject* #{p}"
              locals << p.to_s
            end
            [parts.join(", "), locals]
          end
        end
      end
    end
  end
end

# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Universal call protocol: every Ruby method takes
#   m_X(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr).
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
            # Pre-walk for captured locals so unpack_params + the body
            # emission both know which locals need heap-cell storage.
            # Include collect_local_writes — unpack_params hoists ALL
            # body-decl LocalVariableWrites to method scope (block
            # locals included), so they share method's `captured?`
            # check; without this, a block-local declared at method
            # level via the hoist gets a bare decl while inner blocks
            # access it via *deref (mismatch).
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
            emit.line "virtual BasicObject* #{cpp_name}(Array* args = &EMPTY_ARGS, Hash* kwargs = nullptr, Proc* block = nullptr) {"
            emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
            emit.line "}"
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && emit.strict_emit
            loc = method&.source_location || "(unknown)"
            $stderr.puts "[box-first] skip user_method :#{name} @ #{loc}: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
            # Emit an abort-stub body so the runtime fails loudly with
            # a "compiler limitation" message if the method is actually
            # called. The previous silent-skip routed calls through
            # mm_dispatch → method_missing → NoMethodError, which user
            # code could rescue (silently swallowing a compiler gap),
            # and which is indistinguishable from a real Ruby
            # NoMethodError. Aborting can't be caught and points
            # straight at the missing-feature site.
            msg = "[frozone-box-first] unimplemented method :#{name} (def @ #{loc}): #{e.message}"
            emit.line "virtual BasicObject* #{cpp_name}(Array* args = &EMPTY_ARGS, Hash* kwargs = nullptr, Proc* block = nullptr) {"
            emit.indented do
              emit.line %|std::fprintf(stderr, "%s\\n", #{emit.cpp.cpp_string_literal(msg)});|
              emit.line "std::abort();"
            end
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
              "BasicObject** #{cpp} = new BasicObject*(#{init_expr});"
            else
              "BasicObject* #{cpp} = #{init_expr};"
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
              emit.line "if (kwargs && !kwargs->data.empty()) { Array* _ext = new Array(); _ext->data = args->data; Hash* _h = new Hash(); _h->data = kwargs->data; _ext->data.push_back(static_cast<BasicObject*>(_h)); args = _ext; }"
            end
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
              emit.line decl_local_line(emit, p, "(kwargs ? [&]() -> BasicObject* { auto _it = kwargs->data.find(intern(#{key_lit})); return _it == kwargs->data.end() ? (#{default_str}) : _it->second; }() : (#{default_str}))")
              locals << p.to_s
            end
            (method.required_kw_params || []).each do |p|
              key_lit = emit.cpp.cpp_string_literal(p.to_s)
              emit.line decl_local_line(emit, p, %|(kwargs && kwargs->data.find(intern(#{key_lit})) != kwargs->data.end()) ? kwargs->data[intern(#{key_lit})] : ([&]() -> BasicObject* { std::fprintf(stderr, "[box-first] missing required kw arg :#{p}\\n"); std::abort(); }())|)
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
              emit.line "if (kwargs) for (auto& _kv : kwargs->data) {"
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
            emit.line "Proc* _block = block;"
            user_block = user_block_name(method)
            if user_block
              # `def foo(&blk)` — bind a user-facing local of type
              # BasicObject* (not Proc*) so user code can reassign it
              # from any vtable-call result without C++ type errors.
              # `truthy(l_blk)`, `l_blk->m_call(...)` (universal surface)
              # both work without a static_cast.
              emit.line decl_local_line(emit, user_block, "static_cast<BasicObject*>(block)")
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

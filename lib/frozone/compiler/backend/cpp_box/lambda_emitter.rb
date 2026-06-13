# Box-first lambda-wrapped emission.
#
# Several Ruby constructs lower to a self-invoking C++ lambda
# (`[&]() -> BasicObject* { ... }()`) so that statement-position forms
# (if/case/MultipleAssignment) survive in expression context, and so
# that early-return / multi-arm bodies get a clean implicit-return:
#
# - `raise X.new(...)` / `raise "msg"`           → from_raise
# - `begin..rescue..else..ensure`                → from_rescue
# - `case ... when ...`                          → from_case
# - `if ... then ... else ... end` containing Return → from_if_as_lambda
# - block / proc bodies (`each { ... }`)         → from_block_as_proc
#
# These all share a pair of helpers:
#
# - body_as_lambda_call(body, locals) → `[&]() { ... }()` (call-site)
# - body_as_block(body, locals, last_is_return:) → `{ ... }` (raw)
#
# Plus a couple of static AST scanners — contains_return? tells from_if
# whether a ternary-lower is safe; contains_loop_escape? tells from_case
# / from_block whether it's safe to wrap a body in a fresh lambda
# (lambdas block C++ break/continue, so an escape inside would fail to
# compile or silently swallow).
#
# Mixed into Cpp so call sites stay unchanged.

module Frozone
  module Compiler
    module Backend
      module CppBox
        module LambdaEmitter
          # `raise X` → `throw new X(...)`. Three shapes supported:
          # 1) bare `raise` (re-raise current exception) — `throw;`
          # 2) `raise CONST[, args...]` — `throw new CONST_CLASS->m_new(args)`
          # 3) `raise expr` (instance) — `throw expr` (cast to Exception*)
          # `raise "msg"` is sugar for `raise RuntimeError.new("msg")`.
          # Wrapped in a lambda so it's expression-position-valid.
          def from_raise(arg_nodes, locals)
            return "([&]() -> BasicObject* { throw; }())" if arg_nodes.empty?

            first = arg_nodes[0]
            if first.is_a?(Ast::ConstantRead) || first.is_a?(Ast::ConstantPath)
              parts = first.is_a?(Ast::ConstantRead) ? [first.name.to_s] : collect_path(first)
              flat = resolve_constant(parts)
              raise Cpp::EmissionError, "raise: unknown exception class #{parts.join('::')}" unless flat && instantiable_class?(flat)
              ctor_args = arg_nodes.drop(1).map { |a| "static_cast<BasicObject*>(#{from_arg(a, locals)})" }
              args_array = "(new Array({#{ctor_args.join(", ")}}))"
              return "([&]() -> BasicObject* { throw static_cast<Exception*>((&#{flat}_CLASS)->m_new(univ, #{args_array})); }())"
            end

            if arg_nodes.length == 1
              # `raise "msg"` is sugar for `raise RuntimeError.new("msg")`.
              if first.is_a?(Ast::StringLiteral) || first.is_a?(Ast::InterpolatedString)
                msg_str = from_expr(first, locals)
                return %(([&]() -> BasicObject* { throw static_cast<Exception*>((&RuntimeError_CLASS)->m_new(univ, new Array({static_cast<BasicObject*>(#{msg_str})}))); }()))
              end
              expr_str = from_expr(first, locals)
              return "([&]() -> BasicObject* { throw static_cast<Exception*>(#{expr_str}); }())"
            end
            raise Cpp::EmissionError, "raise: unsupported arg shape (#{arg_nodes.length} args)"
          end

          # begin/rescue/else/ensure → self-invoking lambda. Body, each
          # rescue arm, and else_node each render as a NESTED lambda
          # using emit.capture + write_body(last_is_return: true), so
          # multi-statement non-expression blocks are supported. The
          # ensure_node becomes an EnsureGuard (RAII) at the top of the
          # outer lambda — runs on any exit (return, exception, rethrow).
          # No clause matched → re-throw, which propagates through the
          # ensure guard.
          def from_rescue(node, locals)
            check_no_break_next!(node, "rescue")
            # Every clause body is rendered as a nested C++ IIFE
            # (`[&]() -> BasicObject* { ... }()`). A Ruby `return` inside
            # any of them must escape the IIFE — bare C++ `return` would
            # only exit the innermost lambda and the method body would
            # fall through. Force `in_block` so write_stmt emits
            # `throw ReturnException{...}` for Ast::Return, which the
            # enclosing method's frame-id try/catch unwraps.
            emit.cpp.with_in_block do
              buf = +"([&]() -> BasicObject* { "
              if node.ensure_node
                buf << "EnsureGuard _eg([&]() #{body_as_block(node.ensure_node, locals, last_is_return: false)}); "
              end
              buf << "try { "
              if node.else_node
                # Body's value discarded; else_node provides the value.
                buf << "#{body_as_lambda_call(node.body, locals)}; "
                buf << "return #{body_as_lambda_call(node.else_node, locals)}; "
              else
                buf << "return #{body_as_lambda_call(node.body, locals)}; "
              end
              buf << "} catch (Exception* e_) { "
              (node.rescue_clauses || []).each do |clause|
                cond = rescue_clause_condition(clause, locals)
                bind_locals = locals.dup
                bind_str = ""
                if clause.var_name
                  bind_locals << clause.var_name.to_s
                  cpp_name = MethodEmitter.local_cpp_name(clause.var_name)
                  # If captured by an inner block / lambda, the closure-env
                  # convention reads/writes via `(*l_e)`; the binding has
                  # to be a heap cell. Otherwise a bare local is fine.
                  bind_str =
                    if captured?(clause.var_name)
                      "BasicObject** #{cpp_name} = gc_box<BasicObject*>(e_); "
                    else
                      "BasicObject* #{cpp_name} = e_; "
                    end
                end
                arm_call = body_as_lambda_call(clause.body, bind_locals)
                buf << "if (#{cond}) { #{bind_str}return #{arm_call}; } "
              end
              buf << "throw; } }())"
              buf
            end
          end

          # Build the LUT-based condition for one rescue clause. Bare
          # rescue (no exception_nodes) catches StandardError per Ruby
          # semantics. ConstantRead/ConstantPath specs emit a typeid+
          # LUT check via mm_is_a_q_direct (matches Ruby's is_a?
          # subclass-tolerance, alloc-free, no RTTI walk). Ast::SplatArg
          # specs (`rescue *exprs => e`) still defer to
          # rescue_splat_matches, which walks the array at runtime.
          def rescue_clause_condition(clause, locals)
            return "e_->mm_is_a_q_direct(&StandardError_CLASS)" if clause.exception_nodes.empty?
            clause.exception_nodes.map { |n|
              if n.is_a?(Ast::SplatArg)
                "rescue_splat_matches(e_, #{from_expr(n.value_node, locals)})"
              else
                cls = exception_class_name(n)
                "e_->mm_is_a_q_direct(&#{cls}_CLASS)"
              end
            }.join(" || ")
          end

          def exception_class_name(node)
            # Walk the lexical scope chain for both bare constants and
            # qualified paths — `rescue FrozoneException` inside
            # `Frozone::Vm` resolves to `Frozone_Vm_FrozoneException`,
            # and `rescue Vm::FrozoneException` inside `Frozone::Ast`
            # resolves through Frozone:: prefix to the same flat name.
            name = case node
                   when Ast::ConstantRead
                     resolve_constant([node.name.to_s]) || node.name.to_s
                   when Ast::ConstantPath
                     resolve_constant(collect_path(node)) || path_to_cpp_name(node)
                   else
                     raise Cpp::EmissionError, "rescue: non-constant exception spec (#{node.class.name})"
                   end
            unless instantiable_class?(name.to_sym)
              raise Cpp::EmissionError, "rescue: unknown exception class :#{name}"
            end
            name
          end

          # Render a body as `[&]() -> BasicObject* { ... return last; }()`
          # — the nested lambda captures all enclosing locals by reference
          # and returns the value of the last expression. Used by
          # from_rescue for body / else / arm bodies.
          # next_returns: true makes `next [v]` lower as `return v;`
          # (block-return semantics). Set when the call site's body
          # might semantically be inside a block (e.g. case-when
          # bodies emitted via body_as_lambda_call from from_case —
          # those bodies can be inside an enclosing Proc lambda
          # where `next` should target the block, not the case).
          # Default false matches the rescue-arm case where `next`
          # should escape to the enclosing loop (and would normally
          # raise EmissionError if such a next is found).
          def body_as_lambda_call(body, locals, next_returns: false)
            "#{body_as_lambda(body, locals, last_is_return: true, next_returns: next_returns)}()"
          end

          def body_as_lambda(body, locals, last_is_return:, next_returns: false)
            "[&]() -> BasicObject* #{body_as_block(body, locals, last_is_return: last_is_return, next_returns: next_returns)}"
          end

          # Render `{ ... }` for a body — used both as the lambda body
          # and as the EnsureGuard lambda body. captured via emit so any
          # statement type (if/while/case) is supported. Trailing
          # `return nil_instance();` is a safety net for empty bodies
          # and last_is_return=false paths.
          # in_block: propagated from cpp.in_block — when this body is
          # nested inside a block lambda, explicit Break/Return inside it
          # must throw to escape the block (not just the inner lambda).
          def body_as_block(body, locals, last_is_return:, next_returns: false)
            return "{ return nil_instance(); }" unless body
            in_block = emit.cpp.in_block
            inner = @emit.capture do
              ExprEmitter.write_body(@emit, body, locals: locals, last_is_return: last_is_return, next_returns: next_returns, in_block: in_block)
            end
            "{ #{inner.gsub("\n", " ")} return nil_instance(); }"
          end

          # `each { |a, b| body }` etc → `(new Proc([&, this](Array*) -> BasicObject* { ... }))`.
          # Block params unpack from `__blkargs__` Array. Required +
          # rest + post supported; optional params raise EmissionError
          # (uncommon in practice). Block body emits via write_body so
          # statement-only forms (if-as-stmt, MASS, ...) work; next_returns
          # rewrites `next [v]` as `return v;` (block-return semantics).
          # `[&, this]` (not bare `[&]`) — see comment block in body for
          # why: lambdas inside a member function would otherwise capture
          # `this` by reference, dangling for ivar-stored Procs.
          def from_block_as_proc(block_node, locals)
            if block_node.is_a?(Ast::BlockArg)
              # &:sym → synthesise a single-arg Proc that forwards to the
              # named method on its first arg. The Symbol literal is
              # known at emit time, so we pick the canonical C++ method
              # name via Cpp.method_name and emit a virtual call. The
              # closed-world emitter ensures the slot exists on
              # BasicObject (else this fails to compile, which is the
              # right outcome — pruner gap, not a runtime issue).
              if block_node.value_node.is_a?(Ast::SymbolLiteral)
                sym = block_node.value_node.value.to_sym
                m = Cpp.method_name(sym)
                body = +""
                body << "if (__blkargs__->data.empty()) { "
                body << "std::fprintf(stderr, \"[box-first] &:#{sym} Proc invoked with no args\\n\"); "
                body << "std::abort(); } "
                body << "BasicObject* __recv__ = __blkargs__->data[0]; "
                # If `sym` is a natural-arity-eligible name, the
                # universal Array path doesn't exist on that slot —
                # unpack positional args inline from __blkargs__.
                sig = emit&.natural_arity_names&.dig(sym)
                if sig
                  args_csv = (0...sig.arity_req).map { |i|
                    "(__blkargs__->data.size() > #{i + 1} ? __blkargs__->data[#{i + 1}] : nil_instance())"
                  }.join(', ')
                  body << "return __recv__->#{m}(#{args_csv});"
                else
                  body << "Array* __rest__ = &EMPTY_ARGS; "
                  body << "if (__blkargs__->data.size() > 1) { __rest__ = new Array(); "
                  body << "for (std::size_t _i = 1; _i < __blkargs__->data.size(); ++_i) "
                  body << "__rest__->data.push_back(__blkargs__->data[_i]); } "
                  body << "return __recv__->#{m}(univ, __rest__);"
                end
                return "(new Proc([](Array* __blkargs__, Hash* __blkkwargs__) -> BasicObject* { #{body} }))"
              end
              return "static_cast<Proc*>(#{from_expr(block_node.value_node, locals)})"
            end
            params = block_node.required_params || []
            optional_params = (block_node.respond_to?(:optional_params) ? block_node.optional_params : nil) || []
            rest_param = block_node.respond_to?(:rest_param) ? block_node.rest_param : nil
            post_params = (block_node.respond_to?(:post_params) ? block_node.post_params : nil) || []
            required_kw_for_elig = (block_node.respond_to?(:required_kw_params) ? block_node.required_kw_params : nil) || []
            optional_kw_for_elig = (block_node.respond_to?(:optional_kw_params) ? block_node.optional_kw_params : nil) || []
            kw_rest_for_elig = block_node.respond_to?(:kw_rest_param) ? block_node.kw_rest_param : nil
            block_param = block_node.respond_to?(:block_param) ? block_node.block_param : nil

            # Arity-specialized Proc subclass eligibility — initial shape
            # gate. Final gate (capture check) needs `inner_captured`,
            # which is computed below.
            specialized_kind = nil
            spec_shape_ok = optional_params.empty? && rest_param.nil? && post_params.empty? &&
                            required_kw_for_elig.empty? && optional_kw_for_elig.empty? && kw_rest_for_elig.nil? &&
                            block_param.nil? &&
                            params.all? { |p| p.is_a?(Symbol) || p.is_a?(String) } &&
                            params.length <= 2
            # Hash-shaped params are destructure patterns:
            #   `do |(a, b, *r, c)| ... end` →
            #   { names: [:a, :b], rest: :r, rights: [:c] }
            # Recursively nestable. Other non-symbol shapes still error.
            (params + post_params).each do |p|
              next if p.is_a?(Symbol) || p.is_a?(String)
              next if p.is_a?(Hash) && p.key?(:names)
              raise Cpp::EmissionError, "block param destructuring (#{p.class.name}) not yet supported"
            end
            # `break v` and `return v` inside a block lambda can't use
            # C++ break/return (they'd only escape the lambda). They
            # throw BreakException/ReturnException via the in_block:
            # flag — caught at the iterator call site and method body
            # respectively. `next [v]` becomes a lambda return via
            # next_returns: true (the lambda IS one block invocation).
            block_locals = locals.dup
            (params + optional_params.map { |n, _| n } + (rest_param ? [rest_param] : []) + post_params).each do |p|
              # Hash-shaped params get their inner names declared by
              # emit_mass_destructure (which appends to block_locals
              # itself). Only flat params register here.
              block_locals << p.to_s if p.is_a?(Symbol) || p.is_a?(String)
            end
            # `|x, &inner_blk|` — block_param is owned by THIS block; track
            # it in block_locals so the body's local-vs-outer-capture
            # analysis sees it as a local, not as a captured outer.
            block_locals << block_param.to_s if block_param

            body = block_node.body

            # Snapshot OUTER captured locals BEFORE entering this block's
            # scope — these are the cell pointers we need to capture by
            # value in the lambda's capture clause so they outlive the
            # outer stack frame (heap-allocated closure-env approach).
            outer_captured_at_creation = emit.cpp.captured_locals.dup

            # Compute THIS block's own captured locals (its own params
            # and body decls referenced by its own inner blocks).
            block_param_names = (params + optional_params.map { |n, _| n } + (rest_param ? [rest_param] : []) + post_params).map(&:to_s)
            block_param_names << block_param.to_s if block_param
            inner_own = Set.new(block_param_names) | Set.new((block_node.respond_to?(:locals) ? (block_node.locals || []) : []).map(&:to_s))
            inner_captured = LambdaEmitter.collect_captured_locals(body, inner_own)

            # Now that inner_captured is known: any specialized-kind block
            # whose param appears in inner_captured OR in the outer's
            # captured_locals (inherited via with_captured_locals when
            # the body emits) needs the extra gc_box indirection — the
            # universal Proc path emits `BasicObject**` for captured
            # params so inner lambdas can write through it, and
            # `from_local_variable_read` checks captured? to decide
            # whether to emit `l_x` or `(*l_x)`. The Proc0/1/2 lambda
            # signatures don't carry that indirection, so fall back to
            # the universal Proc emission whenever the param would be
            # deref'd somewhere in our body.
            if spec_shape_ok && params.none? { |p| inner_captured.include?(p.to_s) || emit.cpp.captured?(p) }
              specialized_kind = case params.length
                                 when 0 then :proc0
                                 when 1 then :proc1
                                 when 2 then :proc2
                                 end
            end

            # Body emission via write_body so statement-only forms
            # (if-as-stmt, case-as-stmt, MultipleAssignment, ...) work.
            # next_returns: true rewrites `next [v]` as `return v;` —
            # the lambda contract for one block invocation.
            body_buf = emit.capture do
              emit.cpp.with_captured_locals(inner_captured) do
                # procarg0 (block auto-splat). When a proc-style block
                # has 2+ named params and the caller passed a single
                # Array, MRI destructures it as if `*` had been splatted
                # at the call site. That's how `Hash#each { |k, v| ... }`
                # works — Hash#each yields `[k, v]`. Without this,
                # `each_with_index.filter_map { |ch, i| ... }` ends up
                # with `i = nil` because Enumerable#filter_map calls
                # `block.call(v)` with `v = [ch, i]` and the block sees
                # `ch = [ch, i]; i = nil`. Lambdas (from_lambda) never
                # auto-splat — only proc-style blocks do, so this rebind
                # is scoped to from_block_as_proc.
                # Procarg0 auto-splat + positional unpack are only needed
                # when the lambda receives the args as an Array. When the
                # block is specialized to Proc0/Proc1/Proc2, the lambda's
                # C++ parameters ARE the block params directly — no
                # __blkargs__ to unpack, and procarg0 is embedded in the
                # Proc2 cross-arity adapters in the runtime.
                unless specialized_kind
                  arity = params.length + optional_params.length + post_params.length
                  if arity >= 2 || (params.length >= 1 && rest_param)
                    emit.line "if (__blkargs__->data.size() == 1) {"
                    emit.indented do
                      emit.line "BasicObject* _a0 = __blkargs__->data[0];"
                      emit.line "if (&typeid(*_a0) == &typeid(Array)) __blkargs__ = static_cast<Array*>(_a0);"
                    end
                    emit.line "}"
                  end
                  params.each_with_index do |p, i|
                    init = "(#{i} < (int)__blkargs__->data.size()) ? __blkargs__->data[#{i}] : nil_instance()"
                    if p.is_a?(Hash) && p.key?(:names)
                      LambdaEmitter.emit_destructured_block_param(emit, p, init, block_locals)
                    else
                      cpp = MethodEmitter.local_cpp_name(p)
                      if emit.cpp.captured?(p)
                        emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                      else
                        emit.line "BasicObject* #{cpp} = #{init};"
                      end
                    end
                  end
                end
                # Optional positional params sit between required + post.
                # MRI's fill order: required first (from front), post next
                # (from back), THEN optional fills in remaining middle
                # slots. So optional[j] gets an actual arg iff there are
                # enough args to reach past required + post + (j+1). The
                # guard `size >= params.length + post_params.length + j + 1`
                # captures that. Block-flavor (Proc) semantics — missing
                # → default. Lambdas (strict) handled in from_lambda.
                optional_params.each_with_index do |(p, default_node), j|
                  idx = params.length + j
                  needed = params.length + post_params.length + j + 1
                  default_str = default_node ? from_expr(default_node, block_locals) : "nil_instance()"
                  init = "((int)__blkargs__->data.size() >= #{needed}) ? __blkargs__->data[#{idx}] : (#{default_str})"
                  cpp = MethodEmitter.local_cpp_name(p)
                  if emit.cpp.captured?(p)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                  else
                    emit.line "BasicObject* #{cpp} = #{init};"
                  end
                end
                if rest_param
                  # `|a, b=1, *rest, x, y|` — rest binds to the slice
                  # between required + optional and post-required params.
                  rest_cpp = MethodEmitter.local_cpp_name(rest_param)
                  pre = params.length + optional_params.length
                  post = post_params.length
                  emit.line "Array* __blk_rest__ = new Array();"
                  emit.line "for (std::size_t _i = #{pre}; _i + #{post} < __blkargs__->data.size(); _i++) __blk_rest__->data.push_back(__blkargs__->data[_i]);"
                  if emit.cpp.captured?(rest_param)
                    emit.line "BasicObject** #{rest_cpp} = gc_box<BasicObject*>(static_cast<BasicObject*>(__blk_rest__));"
                  else
                    emit.line "BasicObject* #{rest_cpp} = static_cast<BasicObject*>(__blk_rest__);"
                  end
                end
                post_params.each_with_index do |p, j|
                  back_idx = post_params.length - j
                  cpp = MethodEmitter.local_cpp_name(p)
                  init = "(#{back_idx} <= (int)__blkargs__->data.size()) ? __blkargs__->data[__blkargs__->data.size() - #{back_idx}] : nil_instance()"
                  if emit.cpp.captured?(p)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                  else
                    emit.line "BasicObject* #{cpp} = #{init};"
                  end
                end
                # Keyword param extraction. Blocks are method-strict on
                # kwargs (the Proc-flavor "extra dropped / missing → nil"
                # laxness applies only to POSITIONAL args). MRI raises
                # ArgumentError on both missing-required-kw and unknown-kw,
                # whether the caller is yield or Proc#call. So mirror the
                # method-side raise_missing_kw / raise_unknown_kw shape.
                required_kw_params = (block_node.respond_to?(:required_kw_params) ? block_node.required_kw_params : nil) || []
                optional_kw_params = (block_node.respond_to?(:optional_kw_params) ? block_node.optional_kw_params : nil) || []
                kw_rest_param = block_node.respond_to?(:kw_rest_param) ? block_node.kw_rest_param : nil
                required_kw_params.each do |kw_name|
                  cpp = MethodEmitter.local_cpp_name(kw_name)
                  key_lit = kw_name.to_s.inspect
                  init = "[&]() -> BasicObject* { auto _it = __blkkwargs__->data.find(intern(#{key_lit})); if (_it == __blkkwargs__->data.end()) raise_missing_kw(#{key_lit}); return _it->second; }()"
                  if emit.cpp.captured?(kw_name)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                  else
                    emit.line "BasicObject* #{cpp} = #{init};"
                  end
                  block_locals << kw_name.to_s
                end
                optional_kw_params.each do |kw_name, default_node|
                  cpp = MethodEmitter.local_cpp_name(kw_name)
                  key_lit = kw_name.to_s.inspect
                  default_str = default_node ? from_expr(default_node, block_locals) : "nil_instance()"
                  init = "[&]() -> BasicObject* { auto _it = __blkkwargs__->data.find(intern(#{key_lit})); return _it == __blkkwargs__->data.end() ? (#{default_str}) : _it->second; }()"
                  if emit.cpp.captured?(kw_name)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                  else
                    emit.line "BasicObject* #{cpp} = #{init};"
                  end
                  block_locals << kw_name.to_s
                end
                if kw_rest_param
                  # When **kwrest is declared, all unknown-named kwargs flow
                  # into the rest Hash — there's no "unknown kw" error.
                  cpp = MethodEmitter.local_cpp_name(kw_rest_param)
                  known_kws = (required_kw_params + optional_kw_params.map { |kn, _| kn }).map { |k| "intern(#{k.to_s.inspect})" }
                  filter = known_kws.empty? ? "true" : known_kws.map { |k| "_kv.first != #{k}" }.join(" && ")
                  init = "[&]() -> Hash* { Hash* _h = new Hash(); for (auto& _kv : __blkkwargs__->data) { if (#{filter}) _h->put(_kv.first, _kv.second); } return _h; }()"
                  if emit.cpp.captured?(kw_rest_param)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(static_cast<BasicObject*>(#{init}));"
                  else
                    emit.line "BasicObject* #{cpp} = static_cast<BasicObject*>(#{init});"
                  end
                  block_locals << kw_rest_param.to_s
                elsif !required_kw_params.empty? || !optional_kw_params.empty?
                  # No **kwrest, but block has named kwargs: raise on
                  # any kw whose name isn't in the declared set. Mirrors
                  # method_emitter.rb's raise_unknown_kw emission.
                  expected_set = (required_kw_params + optional_kw_params.map { |kn, _| kn }).map { |k| "intern(#{k.to_s.inspect})" }.join(", ")
                  emit.line %|for (auto& _kv : __blkkwargs__->data) { Symbol* _k = static_cast<Symbol*>(_kv.first); bool _ok = false; for (auto _e : {#{expected_set}}) { if (_k == _e) { _ok = true; break; } } if (!_ok) raise_unknown_kw(_k->name_); }|
                end
                if block_param
                  # `|x, &inner_blk|` — inner block isn't plumbed through
                  # the universal Proc call slot yet (would need a 3rd
                  # param on `(Array*, Hash*)`). Bind to nil for now —
                  # matches MRI semantics when no block is yielded to
                  # the block. Sufficient to unblock parse of typical
                  # `&blk = nil` capture patterns; real plumbing of an
                  # inner block from yield/m_call is a follow-up.
                  cpp = MethodEmitter.local_cpp_name(block_param)
                  if emit.cpp.captured?(block_param)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(static_cast<BasicObject*>(nil_instance()));"
                  else
                    emit.line "BasicObject* #{cpp} = nil_instance();"
                  end
                end
                if body
                  emit.cpp.with_in_block do
                    ExprEmitter.write_body(emit, body, locals: block_locals, last_is_return: true, next_returns: true, in_block: true)
                  end
                end
                # Fallthrough — Ruby blocks return nil when control falls
                # off the end (trailing while/until/case-without-else, or
                # an if-as-statement where neither branch returns).
                # last_is_return:true above handles the common case;
                # this safety net catches the rest. Skipped after a real
                # return is unreachable code, which C++ optimises away.
                emit.line "return nil_instance();"
              end
            end

            # Capture clause: default `[&]` keeps the existing semantics
            # (transient access to enclosing locals), `this` by value
            # (member-function `this` pointer), plus every OUTER
            # captured local (cell pointer) by value so the lambda
            # safely reads them through `*deref` even after the outer
            # stack frame returns.
            # Only capture-by-value those outer captured names that
            # this lambda body actually references — else C++ may
            # complain about names not yet in scope at the lambda's
            # creation site (e.g. an Officious proc emitted in stmt 0
            # of __top_level__ shouldn't try to capture an `l_options`
            # that's only declared in stmt 1).
            referenced = LambdaEmitter.referenced_outer_locals(body, inner_own)
            cap_extras = (outer_captured_at_creation & referenced).to_a.map { |n| MethodEmitter.local_cpp_name(n) }
            cap_str = (["&", "this"] + cap_extras).join(", ")
            body_text = body_buf.gsub(/\s+/, ' ').strip
            case specialized_kind
            when :proc0
              "(new Proc0([#{cap_str}]() -> BasicObject* { #{body_text} }))"
            when :proc1
              p0 = MethodEmitter.local_cpp_name(params[0])
              "(new Proc1([#{cap_str}](BasicObject* #{p0}) -> BasicObject* { #{body_text} }))"
            when :proc2
              p0 = MethodEmitter.local_cpp_name(params[0])
              p1 = MethodEmitter.local_cpp_name(params[1])
              "(new Proc2([#{cap_str}](BasicObject* #{p0}, BasicObject* #{p1}) -> BasicObject* { #{body_text} }))"
            else
              "(new Proc([#{cap_str}](Array* __blkargs__, Hash* __blkkwargs__) -> BasicObject* { #{body_text} }))"
            end
          end

          # Names referenced (read or written) inside `body`, recursing
          # into nested blocks and treating their params/locals as
          # shadowing. Used to filter the capture clause to only
          # names this lambda actually uses (so we don't capture
          # not-yet-declared outer names by mistake).
          # Hash-shaped block param `{ names: [...], rest: name, rights: [...] }`
          # destructures the corresponding `__blkargs__` slot via the
          # same MASS machinery used for `a, b = rhs`. Recursive on
          # nested patterns (`do |((a, b), c)|`).
          def self.emit_destructured_block_param(emit, hash_param, init_expr, block_locals)
            tag = emit.cpp.next_tmp_id
            tmp = "__blk_destr_#{tag}__"
            emit.line "BasicObject* #{tmp} = #{init_expr};"
            ExprEmitter.emit_mass_destructure(emit, mass_targets_from_hash(hash_param), tmp, block_locals)
          end

          # Convert a destructure-hash param to MASS target descriptors.
          # `:names` and `:rights` are the pre/post slots; `:rest` is the
          # splat. Inner names that are themselves Hash patterns nest
          # via [:nested, sub_targets] — emit_mass_destructure handles
          # the recursion.
          def self.mass_targets_from_hash(h)
            targets = []
            (h[:names] || []).each do |n|
              targets << (n.is_a?(Hash) && n.key?(:names) ? [:nested, mass_targets_from_hash(n)] : [:local, n])
            end
            targets << [:local_splat, h[:rest]] if h[:rest]
            (h[:rights] || []).each do |n|
              targets << (n.is_a?(Hash) && n.key?(:names) ? [:nested, mass_targets_from_hash(n)] : [:local, n])
            end
            targets
          end

          # Flat list of leaf names a block param contributes - used to
          # pre-populate block_locals so the body emission sees them.
          def self.flat_param_names(p)
            return [p.to_s] if p.is_a?(Symbol) || p.is_a?(String)
            return mass_targets_from_hash(p).flat_map { |t| flat_target_names(t) } if p.is_a?(Hash) && p.key?(:names)
            []
          end

          def self.flat_target_names(t)
            case t[0]
            when :local, :local_splat then [t[1].to_s]
            when :nested then t[1].flat_map { |sub| flat_target_names(sub) }
            else []
            end
          end

          def self.referenced_outer_locals(body, own_locals)
            own = own_locals.is_a?(Set) ? own_locals : Set.new(own_locals.map(&:to_s))
            refs = Set.new
            visit = lambda do |node, shadowed|
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::LocalVariableRead) || node.is_a?(Ast::LocalVariableWrite)
                name = node.name.to_s
                refs << name if !own.include?(name) && !shadowed.include?(name)
              end
              if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda)
                next_shadowed = shadowed | block_own_locals(node)
                (node.respond_to?(:children) ? node.children : []).each { |c| visit.call(c, next_shadowed) }
              else
                (node.respond_to?(:children) ? node.children : []).each { |c| visit.call(c, shadowed) }
              end
            end
            visit.call(body, Set.new) if body
            refs
          end

          # Lambda literal — `-> { ... }`, `lambda { ... }`, `Proc.new { ... }`.
          # Same param-unpacking as from_block_as_proc, but `return v`
          # inside the body returns from the lambda itself (not from
          # the enclosing method). We emit the body with in_block: true
          # so Return throws ReturnException, then catch it at the
          # lambda boundary and convert to a C++ return — mirrors the
          # method-frame catch in MethodEmitter.write_user_method /
          # build_override.
          # Strict arg checking (lambda?) is not yet enforced; arity
          # mismatches behave like procs.
          def from_lambda(node, locals)
            params = node.required_params || []
            optional_params = node.optional_params || []
            rest_param = node.rest_param
            post_params = node.post_params || []
            if optional_params.any?
              raise Cpp::EmissionError, "lambda with optional params not yet supported"
            end
            if (node.respond_to?(:required_kw_params) && node.required_kw_params&.any?) ||
               (node.respond_to?(:optional_kw_params) && node.optional_kw_params&.any?) ||
               (node.respond_to?(:kw_rest_param) && node.kw_rest_param) ||
               (node.respond_to?(:block_param) && node.block_param)
              raise Cpp::EmissionError, "lambda with kw/block params not yet supported"
            end
            (params + post_params).each do |p|
              next if p.is_a?(Symbol) || p.is_a?(String)
              next if p.is_a?(Hash) && p.key?(:names)
              raise Cpp::EmissionError, "lambda param destructuring (#{p.class.name}) not yet supported"
            end
            block_locals = locals.dup
            (params + (rest_param ? [rest_param] : []) + post_params).each do |p|
              # Hash-shaped params get their inner names declared by
              # emit_mass_destructure (which appends to block_locals
              # itself). Only flat params register here.
              block_locals << p.to_s if p.is_a?(Symbol) || p.is_a?(String)
            end
            body = node.body

            # Closure-capture machinery (mirrors from_block_as_proc).
            outer_captured_at_creation = emit.cpp.captured_locals.dup
            param_names = (params + (rest_param ? [rest_param] : []) + post_params).map(&:to_s)
            inner_own = Set.new(param_names) | Set.new((node.respond_to?(:locals) ? (node.locals || []) : []).map(&:to_s))
            inner_captured = LambdaEmitter.collect_captured_locals(body, inner_own)

            body_buf = emit.capture do
              emit.cpp.with_captured_locals(inner_captured) do
                params.each_with_index do |p, i|
                  init = "(#{i} < (int)__blkargs__->data.size()) ? __blkargs__->data[#{i}] : nil_instance()"
                  if p.is_a?(Hash) && p.key?(:names)
                    LambdaEmitter.emit_destructured_block_param(emit, p, init, block_locals)
                  else
                    cpp = MethodEmitter.local_cpp_name(p)
                    if emit.cpp.captured?(p)
                      emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                    else
                      emit.line "BasicObject* #{cpp} = #{init};"
                    end
                  end
                end
                if rest_param
                  rest_cpp = MethodEmitter.local_cpp_name(rest_param)
                  pre = params.length
                  post = post_params.length
                  emit.line "Array* __blk_rest__ = new Array();"
                  emit.line "for (std::size_t _i = #{pre}; _i + #{post} < __blkargs__->data.size(); _i++) __blk_rest__->data.push_back(__blkargs__->data[_i]);"
                  if emit.cpp.captured?(rest_param)
                    emit.line "BasicObject** #{rest_cpp} = gc_box<BasicObject*>(static_cast<BasicObject*>(__blk_rest__));"
                  else
                    emit.line "BasicObject* #{rest_cpp} = static_cast<BasicObject*>(__blk_rest__);"
                  end
                end
                post_params.each_with_index do |p, j|
                  back_idx = post_params.length - j
                  cpp = MethodEmitter.local_cpp_name(p)
                  init = "(#{back_idx} <= (int)__blkargs__->data.size()) ? __blkargs__->data[__blkargs__->data.size() - #{back_idx}] : nil_instance()"
                  if emit.cpp.captured?(p)
                    emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(#{init});"
                  else
                    emit.line "BasicObject* #{cpp} = #{init};"
                  end
                end
                # Lambda has its own __frame_id__ — `return` inside the
                # body shadows the enclosing method's frame and targets
                # the lambda itself. Elide the frame setup + catch when
                # nothing in the body actually emits a Return-as-throw
                # site (tracked at the emit boundary via frame_id_used).
                body_buf = nil
                needs_frame = emit.cpp.with_frame_id_tracking do
                  body_buf = emit.capture do
                    if body
                      emit.cpp.with_in_block do
                        ExprEmitter.write_body(emit, body, locals: block_locals, last_is_return: true, next_returns: true, in_block: true)
                      end
                    end
                    # Fallthrough — Ruby blocks return nil when control falls
                    # off the end (trailing while/until/case-without-else, or
                    # an if-as-statement where neither branch returns).
                    # last_is_return:true above handles the common case;
                    # this safety net catches the rest. Skipped after a real
                    # return is unreachable code, which C++ optimises away.
                    emit.line "return nil_instance();"
                  end
                end
                if needs_frame
                  emit.line "std::uint64_t __frame_id__ = next_frame_id();"
                  emit.line "try {"
                  emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
                  emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
                else
                  body_buf.each_line { |l| emit.line l.chomp }
                end
              end
            end
            referenced = LambdaEmitter.referenced_outer_locals(body, inner_own)
            cap_extras = (outer_captured_at_creation & referenced).to_a.map { |n| MethodEmitter.local_cpp_name(n) }
            cap_str = (["&", "this"] + cap_extras).join(", ")
            "(new Proc([#{cap_str}](Array* __blkargs__, Hash* __blkkwargs__) -> BasicObject* { #{body_buf.gsub(/\s+/, ' ').strip} }))"
          end

          # If-as-expression where one or both branches contain Return /
          # Break / Next — wrap in a lambda and emit each branch via
          # write_body. in_block: propagated from the surrounding context
          # (cpp.in_block) so explicit Break/Return inside the branches
          # throw rather than fall through.
          def from_if_as_lambda(node, locals)
            # We wrap the if's branches in a C++ IIFE. A Ruby `return`
            # inside either branch must escape both the IIFE and the
            # enclosing method body — bare C++ `return` would only exit
            # the lambda. Same logic for `break`/`next` w.r.t. the
            # enclosing block. Force `in_block` so write_stmt emits
            # `throw ReturnException{__frame_id__, v}` /
            # `throw BreakException{v}` instead of bare return/break.
            emit.cpp.with_in_block do
              buf = emit.capture do
                emit.line "if (truthy(#{from_expr(node.pred_node, locals)})) {"
                emit.indented do
                  if node.then_node
                    ExprEmitter.write_body(emit, node.then_node, locals: locals, last_is_return: true, in_block: true, next_returns: true)
                  else
                    emit.line "return nil_instance();"
                  end
                end
                emit.line "} else {"
                emit.indented do
                  if node.else_node
                    ExprEmitter.write_body(emit, node.else_node, locals: locals, last_is_return: true, in_block: true, next_returns: true)
                  else
                    emit.line "return nil_instance();"
                  end
                end
                emit.line "}"
              end
              "([&]() -> BasicObject* { #{buf.gsub(/\s+/, ' ').strip} }())"
            end
          end

          # Pre-walk: among `own_local_names`, return the subset that
          # is referenced (read or written) inside ANY nested
          # Block/Lambda within `body`. Those locals must be heap-
          # allocated (`BasicObject** l_x = gc_box<BasicObject*>(initial);`)
          # so an inner lambda can capture the cell pointer by value
          # and still access the live cell after our scope returns.
          # Walks across nested blocks (inner-inner captures of our
          # locals also count).
          def self.collect_captured_locals(body, own_local_names)
            own = own_local_names.is_a?(Set) ? own_local_names : Set.new(own_local_names.map(&:to_s))
            captured = Set.new
            visit = lambda do |node, in_block, shadowed|
              return unless node.is_a?(Ast::Node)
              if in_block && (node.is_a?(Ast::LocalVariableRead) || node.is_a?(Ast::LocalVariableWrite))
                name = node.name.to_s
                # Shadowed: an inner block re-declared this name (as
                # its own param or local), so the reference is to the
                # inner local, not OUR own local.
                captured << name if own.include?(name) && !shadowed.include?(name)
              end
              if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda)
                block_own = block_own_locals(node)
                next_shadowed = shadowed | block_own
                (node.respond_to?(:children) ? node.children : []).each { |c| visit.call(c, true, next_shadowed) }
              else
                (node.respond_to?(:children) ? node.children : []).each { |c| visit.call(c, in_block, shadowed) }
              end
            end
            visit.call(body, false, Set.new)
            captured
          end

          # Names introduced in a Block/Lambda's own scope that ACTUALLY
          # shadow outer names at the C++ level. Block PARAMS are
          # truly block-local in the gen (declared inside the lambda
          # body). Block-body decls (parser-tracked locals minus
          # params) are NOT — collect_local_writes hoists them to
          # the enclosing method's scope, so a Ruby-level
          # `inner { remaining = ... }` becomes a method-scope
          # `BasicObject* l_remaining` shared with the method body.
          # For captured-set computation, only params shadow.
          def self.block_own_locals(node)
            params = (node.respond_to?(:required_params) ? (node.required_params || []) : []) +
                     (node.respond_to?(:optional_params) ? (node.optional_params || []).map(&:first) : []) +
                     (node.respond_to?(:post_params) ? (node.post_params || []) : []) +
                     (node.respond_to?(:rest_param) && node.rest_param ? [node.rest_param] : []) +
                     (node.respond_to?(:block_param) && node.block_param ? [node.block_param] : []) +
                     (node.respond_to?(:required_kw_params) ? (node.required_kw_params || []) : []) +
                     (node.respond_to?(:optional_kw_params) ? (node.optional_kw_params || []).map(&:first) : []) +
                     (node.respond_to?(:kw_rest_param) && node.kw_rest_param ? [node.kw_rest_param] : [])
            Set.new(params.compact.flat_map { |p| p.is_a?(Hash) ? [] : [p.to_s] })
          end

          def contains_return?(node)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::Return)
            # Stop at things that introduce their own return scope.
            return false if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda) ||
                            node.is_a?(Ast::MethodDef) || node.is_a?(Ast::ClassDef) ||
                            node.is_a?(Ast::ModuleDef) || node.is_a?(Ast::SingletonClassDef)
            (node.respond_to?(:children) ? node.children : []).any? { |c| contains_return?(c) }
          end

          # Case-as-expression — lambda + early-return form. Multi-statement
          # bodies become Sequence (comma operator). Without subject_node,
          # conditions are truthy-tested directly.
          # break/next inside the case-arms would emit C++ break/continue
          # inside a lambda, which is invalid (lambda blocks loop scope).
          def from_case(node, locals)
            check_no_break_next!(node, "case-as-expression")
            # Each case-arm body is rendered via body_as_lambda_call —
            # nested C++ IIFE. Any Ruby `return` inside must escape both
            # the IIFE and the enclosing method. Force `in_block` so
            # write_stmt emits `throw ReturnException{__frame_id__, v}`.
            # break/next are pre-filtered by check_no_break_next!.
            emit.cpp.with_in_block do
              from_case_body(node, locals)
            end
          end

          def from_case_body(node, locals)
            buf = +"([&]() -> BasicObject* { "
            if node.subject_node
              buf << "auto* _subj = #{from_expr(node.subject_node, locals)}; "
            end
            node.whens.each do |w|
              cond_strs = w.condition_nodes.map { |c|
                c_s = from_expr(c, locals)
                node.subject_node ? "truthy(#{c_s}->op_case_eq(univ, new Array({_subj})))" : "truthy(#{c_s})"
              }
              # body_as_lambda_call (vs from_expr) handles bodies
              # with statement-position constructs the from_expr
              # lowering can't represent — MultipleAssignment is
              # the common one (e.g. `name, = *node` inside a
              # case arm in parser/builders/default.rb's
              # `def assignable`). Each arm becomes its own
              # lambda; the outer lambda short-circuits on the
              # first truthy condition.
              # ...except when the body contains Next/Break: the
              # `next`/`break` semantically targets the case's
              # ENCLOSING loop or block, not the case-arm lambda.
              # Wrapping in our own lambda would either C++-compile-
              # fail (`continue` outside a loop) or silently swallow
              # the next/break. Fall back to from_expr for those —
              # it'll EmissionError-skip the method body, which is
              # a known limitation but at least graceful.
              body_str =
                if contains_loop_escape?(w.body_node, allow_next: false)
                  from_expr(w.body_node, locals)
                else
                  body_as_lambda_call(w.body_node, locals)
                end
              buf << "if (#{cond_strs.join(" || ")}) return #{body_str}; "
            end
            else_str =
              if node.else_node.nil?
                "nil_instance()"
              elsif contains_loop_escape?(node.else_node, allow_next: false)
                from_expr(node.else_node, locals)
              else
                body_as_lambda_call(node.else_node, locals)
              end
            buf << "return #{else_str}; }())"
            buf
          end

          # Raise EmissionError if any break/next is reachable from this
          # node without an intervening nested-loop boundary. Used by
          # lambda-wrapped emission (rescue, case-as-expr, blocks) where
          # C++ break/continue would land in the lambda scope, not the
          # enclosing loop.
          def check_no_break_next!(node, ctx)
            if contains_loop_escape?(node)
              raise Cpp::EmissionError, "break/next inside #{ctx} — lambda boundary blocks loop scope, not yet supported"
            end
          end

          # `allow_next:` lets next escape — used when emitting a Proc
          # body where Next is rewritten to a lambda return. Break
          # would still need real iterator-exit machinery (throw + catch
          # at the call site) and is genuinely unsupported.
          def contains_loop_escape?(node, allow_next: false)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::Break)
            return true if node.is_a?(Ast::Next) && !allow_next
            # Stop at things that introduce their own loop scope (their
            # break/next bind there, not to our enclosing).
            return false if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda) ||
                            node.is_a?(Ast::While) || node.is_a?(Ast::Until)
            (node.respond_to?(:children) ? node.children : []).any? { |c| contains_loop_escape?(c, allow_next: allow_next) }
          end
        end
      end
    end
  end
end

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
              return "([&]() -> BasicObject* { throw static_cast<Exception*>((&#{flat}_CLASS)->m_new(#{args_array})); }())"
            end

            if arg_nodes.length == 1
              # `raise "msg"` is sugar for `raise RuntimeError.new("msg")`.
              if first.is_a?(Ast::StringLiteral) || first.is_a?(Ast::InterpolatedString)
                msg_str = from_expr(first, locals)
                return %(([&]() -> BasicObject* { throw static_cast<Exception*>((&RuntimeError_CLASS)->m_new(new Array({static_cast<BasicObject*>(#{msg_str})}))); }()))
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
              cond = rescue_clause_condition(clause)
              bind_locals = locals.dup
              bind_str = ""
              if clause.var_name
                bind_locals << clause.var_name.to_s
                bind_str = "BasicObject* #{MethodEmitter.local_cpp_name(clause.var_name)} = e_; "
              end
              arm_call = body_as_lambda_call(clause.body, bind_locals)
              buf << "if (#{cond}) { #{bind_str}return #{arm_call}; } "
            end
            buf << "throw; } }())"
            buf
          end

          # Build the dynamic_cast-based condition for one rescue clause.
          # Bare rescue (no exception_nodes) catches StandardError per
          # Ruby semantics. Exception class names come from ConstantRead
          # / ConstantPath; non-constant exception lists raise EmissionError.
          def rescue_clause_condition(clause)
            return "dynamic_cast<StandardError*>(e_) != nullptr" if clause.exception_nodes.empty?
            clause.exception_nodes.map { |n|
              cls = exception_class_name(n)
              "dynamic_cast<#{cls}*>(e_) != nullptr"
            }.join(" || ")
          end

          def exception_class_name(node)
            name = case node
                   when Ast::ConstantRead then node.name.to_s
                   when Ast::ConstantPath then path_to_cpp_name(node)
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
              # &:sym would need SymbolProc-style coercion (synthesise a
              # block that calls the named method on the arg). Defer.
              if block_node.value_node.is_a?(Ast::SymbolLiteral)
                raise Cpp::EmissionError, "&:sym block-arg coercion not yet supported"
              end
              return "static_cast<Proc*>(#{from_expr(block_node.value_node, locals)})"
            end
            params = block_node.required_params || []
            optional_params = (block_node.respond_to?(:optional_params) ? block_node.optional_params : nil) || []
            rest_param = block_node.respond_to?(:rest_param) ? block_node.rest_param : nil
            post_params = (block_node.respond_to?(:post_params) ? block_node.post_params : nil) || []
            # Optional params in blocks remain unsupported — uncommon
            # in practice (`each { |a = 1| ... }`).
            if optional_params.any?
              raise Cpp::EmissionError, "block with optional params not yet supported"
            end
            (params + post_params).each do |p|
              unless p.is_a?(Symbol) || p.is_a?(String)
                raise Cpp::EmissionError, "block param destructuring (#{p.class.name}) not yet supported"
              end
            end
            # `break v` and `return v` inside a block lambda can't use
            # C++ break/return (they'd only escape the lambda). They
            # throw BreakException/ReturnException via the in_block:
            # flag — caught at the iterator call site and method body
            # respectively. `next [v]` becomes a lambda return via
            # next_returns: true (the lambda IS one block invocation).
            block_locals = locals.dup
            (params + (rest_param ? [rest_param] : []) + post_params).each do |p|
              block_locals << p.to_s
            end

            body = block_node.body

            # Body emission via write_body so statement-only forms
            # (if-as-stmt, case-as-stmt, MultipleAssignment, ...) work.
            # next_returns: true rewrites `next [v]` as `return v;` —
            # the lambda contract for one block invocation.
            body_buf = emit.capture do
              params.each_with_index do |p, i|
                emit.line "BasicObject* #{MethodEmitter.local_cpp_name(p)} = (#{i} < (int)__blkargs__->data.size()) ? __blkargs__->data[#{i}] : nil_instance();"
              end
              if rest_param
                # `|a, b, *rest, x, y|` — rest binds to the slice
                # between required and post-required params. Build
                # a fresh Array from data[required..size-post-1].
                # Empty (zero-length) when size <= required+post.
                rest_cpp = MethodEmitter.local_cpp_name(rest_param)
                pre = params.length
                post = post_params.length
                emit.line "Array* __blk_rest__ = new Array();"
                emit.line "for (std::size_t _i = #{pre}; _i + #{post} < __blkargs__->data.size(); _i++) __blk_rest__->data.push_back(__blkargs__->data[_i]);"
                emit.line "BasicObject* #{rest_cpp} = static_cast<BasicObject*>(__blk_rest__);"
              end
              post_params.each_with_index do |p, j|
                # post param j (0-based from start of post-list)
                # binds to data[size - post_count + j], or nil if
                # data is too short.
                back_idx = post_params.length - j
                emit.line "BasicObject* #{MethodEmitter.local_cpp_name(p)} = (#{back_idx} <= (int)__blkargs__->data.size()) ? __blkargs__->data[__blkargs__->data.size() - #{back_idx}] : nil_instance();"
              end
              if body
                emit.cpp.with_in_block do
                  ExprEmitter.write_body(emit, body, locals: block_locals, last_is_return: true, next_returns: true, in_block: true)
                end
              else
                emit.line "return nil_instance();"
              end
            end

            # `[&, this]` (not bare `[&]`) — lambdas inside a member
            # function implicitly capture `this` by reference under
            # `[&]`. That's safe for short-lived blocks (passed to
            # each, transient closures) but breaks when the Proc is
            # stored on an ivar and outlives the parent stack frame:
            # dereferencing the captured reference reads invalid stack
            # memory. Racc's `@emit_integer = lambda { |chars, p|
            # emit(:tINTEGER, chars); p }` set in the lexer's
            # initialize and called later from advance hit exactly
            # this — the lambda's `this->m_emit(...)` was UB. `[&,
            # this]` captures the `this` POINTER by value (copy)
            # while keeping local-by-reference for everything else.
            "(new Proc([&, this](Array* __blkargs__) -> BasicObject* { #{body_buf.gsub(/\s+/, ' ').strip} }))"
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
              unless p.is_a?(Symbol) || p.is_a?(String)
                raise Cpp::EmissionError, "lambda param destructuring (#{p.class.name}) not yet supported"
              end
            end
            block_locals = locals.dup
            (params + (rest_param ? [rest_param] : []) + post_params).each { |p| block_locals << p.to_s }
            body = node.body
            body_buf = emit.capture do
              params.each_with_index do |p, i|
                emit.line "BasicObject* #{MethodEmitter.local_cpp_name(p)} = (#{i} < (int)__blkargs__->data.size()) ? __blkargs__->data[#{i}] : nil_instance();"
              end
              if rest_param
                rest_cpp = MethodEmitter.local_cpp_name(rest_param)
                pre = params.length
                post = post_params.length
                emit.line "Array* __blk_rest__ = new Array();"
                emit.line "for (std::size_t _i = #{pre}; _i + #{post} < __blkargs__->data.size(); _i++) __blk_rest__->data.push_back(__blkargs__->data[_i]);"
                emit.line "BasicObject* #{rest_cpp} = static_cast<BasicObject*>(__blk_rest__);"
              end
              post_params.each_with_index do |p, j|
                back_idx = post_params.length - j
                emit.line "BasicObject* #{MethodEmitter.local_cpp_name(p)} = (#{back_idx} <= (int)__blkargs__->data.size()) ? __blkargs__->data[__blkargs__->data.size() - #{back_idx}] : nil_instance();"
              end
              # Lambda has its own __frame_id__ — `return` inside the
              # body shadows the enclosing method's frame and targets
              # the lambda itself.
              emit.line "std::uint64_t __frame_id__ = next_frame_id();"
              emit.line "try {"
              if body
                emit.cpp.with_in_block do
                  ExprEmitter.write_body(emit, body, locals: block_locals, last_is_return: true, next_returns: true, in_block: true)
                end
              else
                emit.line "return nil_instance();"
              end
              emit.line "} catch (ReturnException& e_) { if (e_.target_frame != __frame_id__) throw; return e_.value; }"
            end
            "(new Proc([&, this](Array* __blkargs__) -> BasicObject* { #{body_buf.gsub(/\s+/, ' ').strip} }))"
          end

          # If-as-expression where one or both branches contain Return /
          # Break / Next — wrap in a lambda and emit each branch via
          # write_body. in_block: propagated from the surrounding context
          # (cpp.in_block) so explicit Break/Return inside the branches
          # throw rather than fall through.
          def from_if_as_lambda(node, locals)
            in_block = emit.cpp.in_block
            buf = emit.capture do
              emit.line "if (truthy(#{from_expr(node.pred_node, locals)})) {"
              emit.indented do
                if node.then_node
                  ExprEmitter.write_body(emit, node.then_node, locals: locals, last_is_return: true, in_block: in_block, next_returns: in_block)
                else
                  emit.line "return nil_instance();"
                end
              end
              emit.line "} else {"
              emit.indented do
                if node.else_node
                  ExprEmitter.write_body(emit, node.else_node, locals: locals, last_is_return: true, in_block: in_block, next_returns: in_block)
                else
                  emit.line "return nil_instance();"
                end
              end
              emit.line "}"
            end
            "([&]() -> BasicObject* { #{buf.gsub(/\s+/, ' ').strip} }())"
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
            buf = +"([&]() -> BasicObject* { "
            if node.subject_node
              buf << "auto* _subj = #{from_expr(node.subject_node, locals)}; "
            end
            node.whens.each do |w|
              cond_strs = w.condition_nodes.map { |c|
                c_s = from_expr(c, locals)
                node.subject_node ? "truthy(#{c_s}->op_case_eq(new Array({_subj})))" : "truthy(#{c_s})"
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

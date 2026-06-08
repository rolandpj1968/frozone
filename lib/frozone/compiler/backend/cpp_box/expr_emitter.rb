# Box-first C++ backend — statement-position writers.
#
# Multi-line / control-flow emission. Every method here mutates the
# Emitter buffer via `emit.line` / `emit.indented`. For inline
# expression strings, calls into `emit.cpp.from_*` (the pure side).
#
# Entry points:
#   write_body(emit, body, locals:, last_is_return:)  — emit a sequence
#   write_stmt(emit, node, locals)                    — emit one statement
#
# All other write_* methods are dispatch helpers for specific shapes
# (write_if_stmt, write_while_stmt, write_local_write_stmt, etc.).

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ExprEmitter
          # `last_is_return` (true for method bodies) wraps the final
          # statement in `return ...;` if it's an expression — Ruby's
          # implicit return semantics.
          # Statement-level graceful degradation: an EmissionError on a
          # non-final statement emits `// skipped: <reason>` and moves on
          # so a single unsupported shape doesn't drop the whole method.
          # The final statement of a `last_is_return: true` body cannot
          # gracefully degrade (we'd lose the return value); raises out.
          # `next_returns:` flips the meaning of Ast::Next from "continue
          # the enclosing C++ loop" to "return from the enclosing lambda"
          # — used when emitting a Proc body, where each block invocation
          # is one lambda call and `next [v]` semantically returns v from
          # that invocation.
          def self.write_body(emit, body, locals:, last_is_return: false, next_returns: false, in_block: false)
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
            stmts.each_with_index do |n, i|
              last = i == stmts.length - 1
              if last && last_is_return && stmt_only_node?(n)
                # Some nodes have a write_stmt special case but no
                # safe expression form: times/loop blocks (break/next
                # don't survive lambda wrap), MultipleAssignment
                # (no from_expr handler). Emit as statement + return nil
                # — matches Ruby's "last expression is the return value"
                # well enough for the common cases (initializers,
                # destructuring assignment in tail position; the [v1,v2]
                # array return value is rarely consumed).
                write_stmt(emit, n, locals, next_returns: next_returns, in_block: in_block)
                emit.line "return nil_instance();"
              elsif last && last_is_return && Cpp.expression_node?(n)
                emit.line "return #{emit.cpp.from_expr(n, locals)};"
              elsif last && last_is_return
                write_stmt(emit, n, locals, next_returns: next_returns, in_block: in_block)
              else
                write_stmt_with_rescue(emit, n, locals, next_returns: next_returns, in_block: in_block)
              end
            end
          end

          # Node has a statement-form emission but no safe expression
          # form. Used at last-statement-of-body position so we emit
          # the statement and synthesise `return nil_instance();`
          # rather than wrap the unsupported expression form.
          # Case/If at the tail of a block body where the branches
          # contain break/next can't be lambda-wrapped — break/next
          # would land in the lambda scope, not the enclosing loop.
          # Statement form lets in_block routing throw the right
          # exceptions instead.
          def self.stmt_only_node?(node)
            return true if node.is_a?(Ast::MultipleAssignment)
            return true if (node.is_a?(Ast::Case) || node.is_a?(Ast::If)) && contains_loop_escape?(node)
            stmt_only_method_call?(node)
          end

          # True if the AST contains a Break or Next that would escape
          # the enclosing loop (stops walking into Block/Lambda/While/Until
          # since those introduce their own scope). Mirrors
          # LambdaEmitter#contains_loop_escape? — kept here so the
          # ExprEmitter dispatch path doesn't depend on the lambda
          # emitter for the predicate.
          def self.contains_loop_escape?(node)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::Break) || node.is_a?(Ast::Next)
            return false if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda) ||
                            node.is_a?(Ast::While) || node.is_a?(Ast::Until)
            (node.respond_to?(:children) ? node.children : []).any? { |c| contains_loop_escape?(c) }
          end

          # Method calls that have a write_stmt special case and are
          # NOT safely expressible as expressions (because their block
          # bodies use break/next which don't survive lambda wrapping).
          def self.stmt_only_method_call?(node)
            return false unless node.is_a?(Ast::MethodCall)
            return true if node.name == :loop && !node.receiver_node && node.block_node
            return true if node.name == :times && node.receiver_node && node.block_node
            false
          end

          def self.write_stmt_with_rescue(emit, node, locals, next_returns: false, in_block: false)
            buf = emit.capture { write_stmt(emit, node, locals, next_returns: next_returns, in_block: in_block) }
            buf.each_line { |l| emit.line l.chomp }
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && emit.strict_emit
            # Compile-time skip → runtime abort. Silent stubs let
            # nil-deref propagate downstream as opaque errors; the
            # abort fires only when the skipped statement is actually
            # reached and points at the unsupported feature directly.
            # Comment retained alongside for grep-ability.
            msg = "[box-first] skipped statement reached at runtime: #{e.message}"
            emit.line "/* skipped: #{e.message.gsub('*/', '* /')} */"
            emit.line %|([](){ std::fprintf(stderr, "%s\\n", #{emit.cpp.cpp_string_literal(msg)}); std::abort(); }());|
            $stderr.puts "[box-first] skip stmt: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
          end

          # `in_block:` is set when emitting the body of a block-Proc
          # lambda. Inside such a lambda, `return v` and `break v` cannot
          # use C++ return/break (would only escape the lambda); they
          # throw ReturnException/BreakException to be caught at the
          # method body / iterator call site respectively.
          def self.write_stmt(emit, node, locals, next_returns: false, in_block: false)
            case node
            when Ast::Return
              # Bare `return` has nil value_node — Ruby's implicit nil.
              v = node.value_node ? emit.cpp.from_expr(node.value_node, locals) : "nil_instance()"
              if in_block
                # Frame-targeted: __frame_id__ resolves via C++ scope
                # to the closest enclosing method/lambda frame, which
                # is the right return target per Ruby semantics.
                emit.line "throw ReturnException{#{v}, __frame_id__};"
              else
                emit.line "return #{v};"
              end
            when Ast::If
              write_if_stmt(emit, node, locals, next_returns: next_returns, in_block: in_block)
            when Ast::While
              write_while_stmt(emit, node, locals)
            when Ast::Until
              write_until_stmt(emit, node, locals)
            when Ast::Case
              write_case_stmt(emit, node, locals, next_returns: next_returns, in_block: in_block)
            when Ast::Rescue
              # Pure `begin..end` (no rescue/else/ensure) — emit body
              # inline as plain statements. Without this, the lambda
              # wrap from from_rescue blocks `next`/`break` from
              # reaching the enclosing loop, which is exactly what
              # ragel-generated lexer actions need (`begin .. begin
              # @cs = N; _goto_level = _again; next; end .. end`
              # inside case-when bodies).
              if (node.rescue_clauses.nil? || node.rescue_clauses.empty?) &&
                 node.else_node.nil? && node.ensure_node.nil?
                write_body(emit, node.body, locals: locals, next_returns: next_returns, in_block: in_block) if node.body
              else
                emit.line "#{emit.cpp.from_expr(node, locals)};"
              end
            when Ast::LocalVariableWrite
              write_local_write_stmt(emit, node, locals)
            when Ast::MultipleAssignment
              write_multiple_assignment_stmt(emit, node, locals)
            when Ast::ForLoop
              write_for_loop_stmt(emit, node, locals)
            when Ast::Break
              # `break v` — outside a block, escape the surrounding C++
              # loop (value dropped, C++ has no value-bearing break).
              # Inside a block lambda, throw BreakException so the
              # iterator's call site catches it and returns v.
              if in_block
                v = node.value_node ? emit.cpp.from_expr(node.value_node, locals) : "nil_instance()"
                emit.line "throw BreakException{#{v}};"
              else
                emit.line "break;"
              end
            when Ast::Next
              # In a Proc lambda (block body), `next [v]` returns v from
              # the lambda — semantically equivalent to "skip to the
              # next block invocation". Outside a block, it's a C++
              # `continue;`.
              if next_returns
                v = node.value_node ? emit.cpp.from_expr(node.value_node, locals) : "nil_instance()"
                emit.line "return #{v};"
              else
                emit.line "continue;"
              end
            when Ast::ClassDef, Ast::ModuleDef
              # Synthetic re-openings produced by AOT class-const
              # hoisting carry data-init lines that need execute-phase
              # emission inside the class's lexical scope (so bare
              # ConstantRead inside hoisted Procs resolves to siblings
              # of the original class, not top-level Object). Emit the
              # body with @method_scope pushed so constant resolution
              # walks the right chain. Real class/module defs in the
              # compiled body are still a closed-world violation.
              if node.respond_to?(:synthetic_hoist) && node.synthetic_hoist
                write_synthetic_hoist_class_body(emit, node, locals, next_returns: next_returns, in_block: in_block)
              else
                raise Cpp::EmissionError,
                  "closed-world violation: runtime #{node.class.name.split('::').last} not supported in compiled body"
              end
            when Ast::MethodDef, Ast::SingletonClassDef
              raise Cpp::EmissionError,
                "closed-world violation: runtime #{node.class.name.split('::').last} not supported in compiled body"
            when Ast::MethodCall
              if node.name == :times && node.receiver_node && node.block_node
                write_times_block(emit, node, locals)
              elsif node.name == :loop && !node.receiver_node && node.block_node
                write_loop_block(emit, node, locals)
              else
                pre_hoist_local_writes!(emit, node, locals)
                emit.line "#{emit.cpp.from_expr(node, locals)};"
              end
            when Ast::Sequence
              node.nodes.each { |n| write_stmt(emit, n, locals, next_returns: next_returns, in_block: in_block) }
            else
              pre_hoist_local_writes!(emit, node, locals)
              emit.line "#{emit.cpp.from_expr(node, locals)};"
            end
          end

          # Walk a statement-level expression tree and pre-declare any
          # `LocalVariableWrite` locals at outer scope. Without this,
          # a write nested inside an expression (e.g. `v = x or abort`,
          # which parses as `Or(LocalVariableWrite(v, x), abort)`)
          # raises EmissionError from cpp.rb because the C++ form
          # `(l_v = ...)` requires l_v to already be declared.
          # Pre-declaring as nil_instance() matches Ruby semantics:
          # the local is `nil` until the assignment executes.
          # Stops at Block/Lambda boundaries — those introduce their
          # own local scope.
          def self.pre_hoist_local_writes!(emit, node, locals)
            return unless node.is_a?(Ast::Node)
            return if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda)
            if node.is_a?(Ast::LocalVariableWrite) && !locals.include?(node.name.to_s)
              locals << node.name.to_s
              cpp = MethodEmitter.local_cpp_name(node.name)
              if emit.cpp.captured?(node.name)
                emit.line "BasicObject** #{cpp} = gc_box<BasicObject*>(nil_instance());"
              else
                emit.line "BasicObject* #{cpp} = nil_instance();"
              end
            end
            node.children.each { |c| pre_hoist_local_writes!(emit, c, locals) }
          end

          # Emit the body of a hoist-synthesised class re-opening with
          # @method_scope pushed so bare ConstantRead inside the body
          # (and inside any Procs nested in it) resolves through the
          # class's lexical scope, exactly as in the original source.
          # The scope object only needs to expose `full_name` —
          # ConstantResolver#scope_prefixes is the only consumer.
          def self.write_synthetic_hoist_class_body(emit, node, locals, next_returns:, in_block:)
            scope_obj = Struct.new(:full_name).new(synthetic_class_full_name(node))
            prev = emit.cpp.method_scope
            emit.cpp.method_scope = (prev || []) + [scope_obj]
            begin
              write_body(emit, node.body, locals: locals, next_returns: next_returns, in_block: in_block) if node.body
            ensure
              emit.cpp.method_scope = prev
            end
          end

          def self.synthetic_class_full_name(node)
            (collect_namespace(node.namespace_node) + [node.name.to_s]).join("::")
          end

          def self.collect_namespace(node)
            case node
            when nil then []
            when Ast::ConstantPath then collect_namespace(node.parent_node) + [node.name.to_s]
            when Ast::ConstantRead then [node.name.to_s]
            else [node.to_s]
            end
          end

          def self.write_if_stmt(emit, node, locals, next_returns: false, in_block: false)
            cond = emit.cpp.from_expr(node.pred_node, locals)
            emit.line "if (truthy(#{cond})) {"
            emit.indented do
              write_body(emit, node.then_node, locals: locals, next_returns: next_returns, in_block: in_block) if node.then_node
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { write_body(emit, node.else_node, locals: locals, next_returns: next_returns, in_block: in_block) }
            end
            emit.line "}"
          end

          # Case/when emission. Two forms:
          #   case x; when A; ... when B, C; ... else; ... end
          #   case;   when cond1; ... when cond2; ... else; ... end
          # When subject_node is present each condition is `cond === subject`
          # via op_case_eq. Without a subject conditions are truthy-tested
          # directly (the truthy/falsy if-elsif form).
          # SplatArg in conditions (when *arr) — deferred.
          def self.write_case_stmt(emit, node, locals, next_returns: false, in_block: false)
            subj = node.subject_node ? "_subj" : nil
            if subj
              emit.line "BasicObject* #{subj} = #{emit.cpp.from_expr(node.subject_node, locals)};"
            end
            node.whens.each_with_index do |w, i|
              cond = case_when_cond(emit, w.condition_nodes, subj, locals)
              keyword = i == 0 ? "if" : "} else if"
              emit.line "#{keyword} (#{cond}) {"
              emit.indented { write_body(emit, w.body_node, locals: locals, next_returns: next_returns, in_block: in_block) if w.body_node }
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { write_body(emit, node.else_node, locals: locals, next_returns: next_returns, in_block: in_block) }
            end
            emit.line "}"
          end

          # Build the C++ condition for one when's condition list. Multiple
          # conditions (when A, B, C) join with `||`. SplatArg in a when
          # clause (`when *ArgumentStyle.keys`) iterates the splatted
          # array at runtime and tests each element as `elem === subj`
          # (or just truthy(elem) without subject).
          def self.case_when_cond(emit, condition_nodes, subj, locals)
            condition_nodes.map { |c|
              if c.is_a?(Ast::SplatArg)
                arr_str = emit.cpp.from_expr(c.value_node, locals)
                if subj
                  "([&]() -> bool { BasicObject* _sp = #{arr_str}; if (!_sp || typeid(*_sp) != typeid(Array)) return false; for (auto* _e : static_cast<Array*>(_sp)->data) { if (truthy(_e->op_case_eq(new Array({#{subj}})))) return true; } return false; }())"
                else
                  "([&]() -> bool { BasicObject* _sp = #{arr_str}; if (!_sp || typeid(*_sp) != typeid(Array)) return false; for (auto* _e : static_cast<Array*>(_sp)->data) { if (truthy(_e)) return true; } return false; }())"
                end
              else
                c_str = emit.cpp.from_expr(c, locals)
                subj ? "truthy(#{c_str}->op_case_eq(new Array({#{subj}})))" : "truthy(#{c_str})"
              end
            }.join(" || ")
          end

          def self.write_while_stmt(emit, node, locals)
            emit.line "while (truthy(#{emit.cpp.from_expr(node.condition_node, locals)})) {"
            emit.indented do
              write_body(emit, node.body_node, locals: locals) if node.body_node
            end
            emit.line "}"
          end

          # `for var in coll; body; end` desugars to coll.each { |var| body }.
          # Unlike block-locals, for-loop targets persist in the enclosing
          # scope — so we declare/update var as a regular method-scope local.
          # Only :local targets supported here; others (:index, :ivar, …)
          # would need the same MASS plumbing and aren't seen yet.
          def self.write_for_loop_stmt(emit, node, locals)
            target = node.target
            unless target.is_a?(Array) && target[0] == :local
              raise Cpp::EmissionError, "ForLoop target #{target.inspect} not yet supported"
            end
            var = target[1].to_s
            cpp_var = MethodEmitter.local_cpp_name(var)
            unless locals.include?(var)
              emit.line "BasicObject* #{cpp_var} = nil_instance();"
              locals << var
            end
            coll = emit.cpp.from_expr(node.collection_node, locals)
            emit.line "(#{coll})->m_each(&EMPTY_ARGS, &EMPTY_KWARGS, (new Proc([&, this](Array* __blkargs__, Hash* __blkkwargs__) -> BasicObject* {"
            emit.indented do
              emit.line "#{cpp_var} = __blkargs__->data.empty() ? nil_instance() : __blkargs__->data[0];"
              write_body(emit, node.body_node, locals: locals) if node.body_node
              emit.line "return nil_instance();"
            end
            emit.line "})));"
          end

          # `until cond; body; end` is `while (!truthy(cond)) { body }`.
          # `begin; body; end until cond` (post-test form) isn't yet
          # special-cased — the begin_modifier flag is ignored; we always
          # emit the pre-test form.
          def self.write_until_stmt(emit, node, locals)
            emit.line "while (!truthy(#{emit.cpp.from_expr(node.condition_node, locals)})) {"
            emit.indented do
              write_body(emit, node.body_node, locals: locals) if node.body_node
            end
            emit.line "}"
          end

          def self.write_local_write_stmt(emit, node, locals)
            rhs = emit.cpp.from_expr(node.value_node, locals)
            cpp_name = MethodEmitter.local_cpp_name(node.name)
            captured = emit.cpp.captured?(node.name)
            if locals.include?(node.name.to_s)
              emit.line(captured ? "*#{cpp_name} = #{rhs};" : "#{cpp_name} = #{rhs};")
            else
              locals << node.name.to_s
              emit.line(captured ? "BasicObject** #{cpp_name} = gc_box<BasicObject*>(#{rhs});" : "BasicObject* #{cpp_name} = #{rhs};")
            end
          end

          # `a, b = rhs` / `a, *b, c = rhs` etc. Evaluate RHS once,
          # cast to Array, distribute elements to targets. Splat
          # collects the middle slice into a new Array. Targets are
          # [:local, name, depth], [:ivar, name], [:nested, sub_targets],
          # or splat variants of those; other shapes (call/index/const)
          # raise EmissionError.
          # Statement-position only — value is dropped (the rhs).
          def self.write_multiple_assignment_stmt(emit, node, locals)
            rhs_str = emit.cpp.from_expr(node.value_node, locals)
            emit_mass_destructure(emit, node.targets, rhs_str, locals)
          end

          ALLOWED_MASS_TARGETS = %i[local ivar gvar local_splat ivar_splat gvar_splat splat_nil index nested].to_set.freeze

          # Destructure rhs_expr (a C++ expression string) across the
          # given targets, handling pre / splat / post and recursive
          # :nested targets via the same routine. Used both for top-level
          # MASS and for nested-target destructuring inside MASS.
          def self.emit_mass_destructure(emit, targets, rhs_expr, locals)
            unless targets.all? { |t| ALLOWED_MASS_TARGETS.include?(t[0]) }
              bad = (targets.map(&:first) - ALLOWED_MASS_TARGETS.to_a).first
              raise Cpp::EmissionError, "MultipleAssignment with non-local/ivar target (#{bad}) not yet supported"
            end
            splat_idx = targets.index { |t| %i[local_splat ivar_splat splat_nil].include?(t[0]) }
            pre_count = splat_idx || targets.length
            post_count = splat_idx ? targets.length - splat_idx - 1 : 0
            tag = emit.cpp.next_tmp_id
            raw = "__mass_raw_#{tag}__"
            rhs = "__mass_rhs_#{tag}__"
            n = "__mass_n_#{tag}__"
            # MRI multiple-assignment semantics: a single non-Array
            # RHS wraps to `[RHS]` (nil wraps to `[]`), so the first
            # target gets the value (or nil) and the rest get nil.
            # Pure `static_cast<Array*>` was UB on non-Array RHS —
            # racc's `_slen, _trans, _keys, _inds, _acts, _nacts =
            # nil` was reading garbage out of nil_instance()->data,
            # making the lexer state machine never transition.
            emit.line "BasicObject* #{raw} = #{rhs_expr};"
            emit.line "Array* #{rhs} = (#{raw} && typeid(*#{raw}) == typeid(Array)) ? static_cast<Array*>(#{raw}) : nullptr;"
            emit.line "if (!#{rhs}) { #{rhs} = new Array(); if (#{raw} != nil_instance()) #{rhs}->data.push_back(#{raw}); }"
            emit.line "std::size_t #{n} = #{rhs}->data.size();"
            targets[0...pre_count].each_with_index do |t, i|
              emit_mass_target_assign(emit, t, "(#{n} > #{i} ? #{rhs}->data[#{i}] : nil_instance())", locals)
            end
            if splat_idx
              splat_t = targets[splat_idx]
              splat = "__mass_splat_#{tag}__"
              emit.line "Array* #{splat} = new Array();"
              emit.line "for (std::size_t _i = #{pre_count}; _i + #{post_count} < #{n}; _i++) #{splat}->data.push_back(#{rhs}->data[_i]);"
              emit_mass_target_assign(emit, splat_t, "static_cast<BasicObject*>(#{splat})", locals)
              targets[(splat_idx + 1)..].each_with_index do |t, i|
                # Post-splat target i reads `data[n - post_count + i]`,
                # but only if pre hasn't already consumed that slot.
                # MRI: when n < pre_count + post_count, pre takes the
                # first pre_count, leaving post slots `nil` (post does
                # NOT steal from pre). Guard: n >= pre_count + post_count - i.
                # Example: `a, b, *c, d = 1, 2` → a=1, b=2, c=[], d=nil
                # (pre=2, post=1, n=2, i=0 → check 2 >= 2+1-0 = 3 → false → nil).
                emit_mass_target_assign(emit, t, "(#{n} >= #{pre_count + post_count - i} ? #{rhs}->data[#{n} - #{post_count - i}] : nil_instance())", locals)
              end
            end
          end

          # Emit one element-assignment based on target descriptor.
          def self.emit_mass_target_assign(emit, target, value_expr, locals)
            kind = target[0]
            case kind
            when :local
              name = target[1].to_s
              cpp_name = MethodEmitter.local_cpp_name(name)
              captured = emit.cpp.captured?(name)
              if locals.include?(name)
                emit.line(captured ? "*#{cpp_name} = #{value_expr};" : "#{cpp_name} = #{value_expr};")
              else
                locals << name
                emit.line(captured ? "BasicObject** #{cpp_name} = gc_box<BasicObject*>(#{value_expr});" : "BasicObject* #{cpp_name} = #{value_expr};")
              end
            when :local_splat
              name = target[1].to_s
              cpp_name = MethodEmitter.local_cpp_name(name)
              captured = emit.cpp.captured?(name)
              if locals.include?(name)
                emit.line(captured ? "*#{cpp_name} = #{value_expr};" : "#{cpp_name} = #{value_expr};")
              else
                locals << name
                emit.line(captured ? "BasicObject** #{cpp_name} = gc_box<BasicObject*>(#{value_expr});" : "BasicObject* #{cpp_name} = #{value_expr};")
              end
            when :ivar, :ivar_splat
              iv = target[1].to_s.delete_prefix('@')
              emit.line "this->iv_#{iv} = #{value_expr};"
            when :gvar, :gvar_splat
              # `$x, $y = …` and `$gvar, *$rest = …` — route through
              # the same g_global_set kernel-fn used by GlobalVariableWrite.
              # Name canonicalisation ($:, $-I, $") goes through the
              # same alias map as the bare assignment path.
              name = target[1].to_s
              canonical = Cpp::GLOBAL_NAME_ALIAS[name.to_sym] || name
              name_lit = emit.cpp.cpp_string_literal(canonical)
              emit.line "g_global_set(#{name_lit}, #{value_expr});"
            when :index
              # `q[i] = v` → q->op_aset(new Array({i, v}), nullptr, nullptr).
              # Index args are kept as exprs (re-evaluated per target); for
              # the typical `arr[lit_or_local]` case this is free. Targets
              # with side-effecting receivers/indices would need pre-eval
              # caching, but no benchmark hits that yet.
              recv_str  = emit.cpp.from_expr(target[1], locals)
              idx_strs  = (target[2] || []).map { |a| emit.cpp.from_arg(a, locals) }
              emit.line "(void)(#{recv_str})->op_aset(new Array({#{idx_strs.join(", ")}, #{value_expr}}));"
            when :splat_nil
              # Discard — evaluate the value_expr (it might have side effects via array_at) but throw it away.
              emit.line "(void)(#{value_expr});"
            when :nested
              # `def_t, (name_t, ctx) = val[0]` — the parenthesised
              # group destructures val[0]'s second element into
              # [name_t, ctx]. Recursive call into emit_mass_destructure
              # with the sub-targets and the value_expr as the new RHS.
              emit_mass_destructure(emit, target[1], value_expr, locals)
            else
              raise Cpp::EmissionError, "MultipleAssignment target kind :#{kind} not supported"
            end
          end

          # `loop do ... end` → `while (true) { body }`. Block-body
          # break/next/return work as expected (break/continue/return).
          # Mirrors Kernel#loop semantics; bypasses the universal-
          # protocol block dispatch that would otherwise wrap the body
          # in a lambda (which can't break/continue out).
          def self.write_loop_block(emit, node, locals)
            blk = node.block_node
            # `loop do ... end` semantically: an iterator that yields
            # repeatedly until the block raises StopIteration / break.
            # We inline it as `while (true) { body }` for tight loops,
            # but the body IS still a block — Ruby `return X` inside
            # must escape the ENCLOSING METHOD (throw ReturnException),
            # not the C++ enclosing function. Pass `in_block: true` so
            # write_stmt emits Return as a throw, and wrap the while
            # in `try { } catch (BreakException& _be) { … }` so
            # `break v` inside the block (also now a throw under
            # in_block=true) exits the inlined loop with the right
            # semantics.
            emit.line "try {"
            emit.indented do
              emit.line "while (true) {"
              emit.indented do
                block_locals = locals.dup
                emit.cpp.with_in_block do
                  write_body(emit, blk.body, locals: block_locals, in_block: true)
                end
              end
              emit.line "}"
            end
            emit.line "} catch (BreakException& __be_loop__) { /* break exits loop */ }"
          end

          # `recv.times { |i| body }` → C++ for-loop. Mirrors mainline's
          # special-case desugaring. recv is a BasicObject*; we extract
          # raw_ via static_cast<Integer*>, except when recv is a literal
          # (then use the int directly). Inner loop body reads the
          # block-var as a boxed Integer (`BasicObject* i = new
          # Integer(__i_raw__)`) so it can be passed to methods, stored
          # in arrays, etc. Costs an allocation per iteration but is
          # correct; specialisation-pass replacement is future work.
          def self.write_times_block(emit, node, locals)
            blk = node.block_node
            var = (blk.required_params || [])[0] || :_i
            recv_node = node.receiver_node
            count = if recv_node.is_a?(Ast::IntegerLiteral)
                      "#{recv_node.value.raw}LL"
                    else
                      "static_cast<Integer*>(#{emit.cpp.from_expr(recv_node, locals)})->raw_"
                    end
            raw_var = "__#{var}_raw__"
            cpp_var = MethodEmitter.local_cpp_name(var)
            emit.line "for (int64_t #{raw_var} = 0; #{raw_var} < #{count}; #{raw_var}++) {"
            emit.indented do
              # Block param `var` is a fresh bare local in the for-body
              # scope, shadowing any outer captured-by-name local.
              emit.cpp.with_shadowed_locals([var]) do
                emit.line "BasicObject* #{cpp_var} = new Integer(#{raw_var});"
                # Snapshot+restore: locals declared inside the block body
                # are scoped to the block (mirrors Ruby's block-local
                # semantics); without this, subsequent blocks' first
                # writes would see stale "already declared" state and
                # emit `name = ...` instead of `BasicObject* name = ...`.
                block_locals = locals.dup << var.to_s
                write_body(emit, blk.body, locals: block_locals)
              end
            end
            emit.line "}"
          end
        end
      end
    end
  end
end

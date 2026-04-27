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
          def self.write_body(emit, body, locals:, last_is_return: false)
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
            stmts.each_with_index do |n, i|
              last = i == stmts.length - 1
              if last && last_is_return && stmt_only_method_call?(n)
                # times/loop blocks at last-expression position need
                # the statement form (lambda-wrap doesn't allow
                # break/next). Emit as statement + return nil.
                write_stmt(emit, n, locals)
                emit.line "return nil_instance();"
              elsif last && last_is_return && Cpp.expression_node?(n)
                emit.line "return #{emit.cpp.from_expr(n, locals)};"
              elsif last && last_is_return
                write_stmt(emit, n, locals)
              else
                write_stmt_with_rescue(emit, n, locals)
              end
            end
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

          def self.write_stmt_with_rescue(emit, node, locals)
            buf = emit.capture { write_stmt(emit, node, locals) }
            buf.each_line { |l| emit.line l.chomp }
          rescue Cpp::EmissionError => e
            emit.line "/* skipped: #{e.message.gsub('*/', '* /')} */"
            $stderr.puts "[box-first] skip stmt: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
          end

          def self.write_stmt(emit, node, locals)
            case node
            when Ast::Return
              emit.line "return #{emit.cpp.from_expr(node.value_node, locals)};"
            when Ast::If
              write_if_stmt(emit, node, locals)
            when Ast::While
              write_while_stmt(emit, node, locals)
            when Ast::Until
              write_until_stmt(emit, node, locals)
            when Ast::Case
              write_case_stmt(emit, node, locals)
            when Ast::LocalVariableWrite
              write_local_write_stmt(emit, node, locals)
            when Ast::MultipleAssignment
              write_multiple_assignment_stmt(emit, node, locals)
            when Ast::ForLoop
              write_for_loop_stmt(emit, node, locals)
            when Ast::Break
              # Bare `break` and `break value` — value is dropped (the
              # surrounding loop's value isn't observable in
              # statement-position emission). C++ has no value-bearing
              # break.
              emit.line "break;"
            when Ast::Next
              emit.line "continue;"
            when Ast::ClassDef, Ast::ModuleDef, Ast::MethodDef, Ast::SingletonClassDef
              raise Cpp::EmissionError,
                "closed-world violation: runtime #{node.class.name.split('::').last} not supported in compiled body"
            when Ast::MethodCall
              if node.name == :times && node.receiver_node && node.block_node
                write_times_block(emit, node, locals)
              elsif node.name == :loop && !node.receiver_node && node.block_node
                write_loop_block(emit, node, locals)
              else
                emit.line "#{emit.cpp.from_expr(node, locals)};"
              end
            when Ast::Sequence
              node.nodes.each { |n| write_stmt(emit, n, locals) }
            else
              emit.line "#{emit.cpp.from_expr(node, locals)};"
            end
          end

          def self.write_if_stmt(emit, node, locals)
            cond = emit.cpp.from_expr(node.pred_node, locals)
            emit.line "if (truthy(#{cond})) {"
            emit.indented do
              write_body(emit, node.then_node, locals: locals) if node.then_node
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { write_body(emit, node.else_node, locals: locals) }
            end
            emit.line "}"
          end

          # Case/when emission. Two forms:
          #   case x; when A; ... when B, C; ... else; ... end
          #   case;   when cond1; ... when cond2; ... else; ... end
          # When subject_node is present each condition is `cond === subject`
          # via m_case_eq. Without a subject conditions are truthy-tested
          # directly (the truthy/falsy if-elsif form).
          # SplatArg in conditions (when *arr) — deferred.
          def self.write_case_stmt(emit, node, locals)
            subj = node.subject_node ? "_subj" : nil
            if subj
              emit.line "BasicObject* #{subj} = #{emit.cpp.from_expr(node.subject_node, locals)};"
            end
            node.whens.each_with_index do |w, i|
              cond = case_when_cond(emit, w.condition_nodes, subj, locals)
              keyword = i == 0 ? "if" : "} else if"
              emit.line "#{keyword} (#{cond}) {"
              emit.indented { write_body(emit, w.body_node, locals: locals) if w.body_node }
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { write_body(emit, node.else_node, locals: locals) }
            end
            emit.line "}"
          end

          # Build the C++ condition for one when's condition list. Multiple
          # conditions (when A, B, C) join with `||`.
          def self.case_when_cond(emit, condition_nodes, subj, locals)
            condition_nodes.map { |c|
              c_str = emit.cpp.from_expr(c, locals)
              subj ? "truthy(#{c_str}->m_case_eq((new Array({#{subj}})), nullptr, nullptr))" : "truthy(#{c_str})"
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
            emit.line "(#{coll})->m_each((new Array({})), nullptr, (new Proc([&](Array* __blkargs__) -> BasicObject* {"
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
            if locals.include?(node.name.to_s)
              emit.line "#{cpp_name} = #{rhs};"
            else
              if MethodEmitter::UNIVERSAL_PARAM_NAMES.include?(node.name.to_s)
                raise Cpp::EmissionError, "local :#{node.name} collides with universal protocol param"
              end
              locals << node.name.to_s
              emit.line "BasicObject* #{cpp_name} = #{rhs};"
            end
          end

          # `a, b = rhs` / `a, *b, c = rhs` etc. Evaluate RHS once,
          # cast to Array, distribute elements to targets. Splat
          # collects the middle slice into a new Array. Targets are
          # [:local, name, depth] or [:ivar, name]; other shapes
          # (call/index/const) raise EmissionError.
          # Statement-position only — value is dropped (the rhs).
          def self.write_multiple_assignment_stmt(emit, node, locals)
            targets = node.targets
            unless targets.all? { |t| %i[local ivar local_splat ivar_splat splat_nil index].include?(t[0]) }
              raise Cpp::EmissionError, "MultipleAssignment with non-local/ivar target (#{(targets.map(&:first) - %i[local ivar local_splat ivar_splat splat_nil index]).first}) not yet supported"
            end
            splat_idx = targets.index { |t| %i[local_splat ivar_splat splat_nil].include?(t[0]) }
            pre_count = splat_idx || targets.length
            post_count = splat_idx ? targets.length - splat_idx - 1 : 0
            rhs_str = emit.cpp.from_expr(node.value_node, locals)
            # Unique-named temps at the current scope (no `{}` wrap),
            # so target locals are declared at the same scope as
            # everything else and remain visible to subsequent code.
            # Monotonic id from emit.cpp avoids collisions between
            # multiple MASS statements in the same method.
            tag = emit.cpp.next_tmp_id
            rhs = "__mass_rhs_#{tag}__"
            n = "__mass_n_#{tag}__"
            emit.line "Array* #{rhs} = static_cast<Array*>(#{rhs_str});"
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
                # Post-splat targets read from end of the array.
                emit_mass_target_assign(emit, t, "(#{n} > #{post_count - i - 1} ? #{rhs}->data[#{n} - #{post_count - i}] : nil_instance())", locals)
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
              if locals.include?(name)
                emit.line "#{cpp_name} = #{value_expr};"
              else
                if MethodEmitter::UNIVERSAL_PARAM_NAMES.include?(name)
                  raise Cpp::EmissionError, "local :#{name} collides with universal protocol param"
                end
                locals << name
                emit.line "BasicObject* #{cpp_name} = #{value_expr};"
              end
            when :local_splat
              name = target[1].to_s
              cpp_name = MethodEmitter.local_cpp_name(name)
              if locals.include?(name)
                emit.line "#{cpp_name} = #{value_expr};"
              else
                locals << name
                emit.line "BasicObject* #{cpp_name} = #{value_expr};"
              end
            when :ivar, :ivar_splat
              iv = target[1].to_s.delete_prefix('@')
              emit.line "this->iv_#{iv} = #{value_expr};"
            when :index
              # `q[i] = v` → q->m_aset(new Array({i, v}), nullptr, nullptr).
              # Index args are kept as exprs (re-evaluated per target); for
              # the typical `arr[lit_or_local]` case this is free. Targets
              # with side-effecting receivers/indices would need pre-eval
              # caching, but no benchmark hits that yet.
              recv_str  = emit.cpp.from_expr(target[1], locals)
              idx_strs  = (target[2] || []).map { |a| emit.cpp.from_arg(a, locals) }
              emit.line "(void)(#{recv_str})->m_aset((new Array({#{idx_strs.join(", ")}, #{value_expr}})), nullptr, nullptr);"
            when :splat_nil
              # Discard — evaluate the value_expr (it might have side effects via array_at) but throw it away.
              emit.line "(void)(#{value_expr});"
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
            emit.line "while (true) {"
            emit.indented do
              block_locals = locals.dup
              write_body(emit, blk.body, locals: block_locals)
            end
            emit.line "}"
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
              emit.line "BasicObject* #{cpp_var} = new Integer(#{raw_var});"
              # Snapshot+restore: locals declared inside the block body
              # are scoped to the block (mirrors Ruby's block-local
              # semantics); without this, subsequent blocks' first
              # writes would see stale "already declared" state and
              # emit `name = ...` instead of `BasicObject* name = ...`.
              block_locals = locals.dup << var.to_s
              write_body(emit, blk.body, locals: block_locals)
            end
            emit.line "}"
          end
        end
      end
    end
  end
end

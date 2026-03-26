module Frozone
  module Compiler
    # Whole-program type inference over a settled Frozone VM snapshot.
    #
    # This is binding-time analysis for the AOT Crystal backend: for each
    # "slot" in the closed-world program, determine whether it always holds
    # a raw Crystal numeric (Int64, Float64, Array(Int64), ...) or must
    # remain a polymorphic RubyObject.
    #
    # The analysis is a monotone fixed-point over a small type lattice:
    #
    #   :unknown  — not yet analysed (initial state)
    #      |
    #   :i64  :f64  :array_i64  :array_f64
    #      |
    #    nil   — proven polymorphic / gives up (absorbing / terminal)
    #
    # Slots flow from :unknown toward specific types as evidence accumulates,
    # or collapse to nil when conflicting evidence is found. nil is sticky.
    #
    # Three iterations of the outer fixed-point cover all practical cases:
    #   Round 1 — literals → immediate arithmetic → methods called with literals
    #   Round 2 — round-1 return types feed callers → their locals refine
    #   Round 3 — one more hop; handles recursion base-case propagation
    #
    # Usage:
    #   env = TypeInference.new(
    #           user_methods:  { fib: method_obj, ... },
    #           user_classes:  { Planet: class_obj, ... },
    #           execute_block: block_node,
    #           constants:     { SOLAR_MASS: float_obj, ... }
    #         ).run
    #   env[:local,  :nq_solve, :k]      # => :i64
    #   env[:return, :fib]               # => :i64
    #   env[:ivar,   :Planet,  :@x]      # => :f64
    class TypeInference
      # ------------------------------------------------------------------
      # Type lattice helpers
      # ------------------------------------------------------------------

      NUMERIC_TYPES  = %i[i64 f64].to_set
      ARRAY_TYPES    = %i[array_i64 array_f64].to_set
      RAW_TYPES      = (NUMERIC_TYPES | ARRAY_TYPES).freeze

      ARRAY_ELEM_TYPE = { array_i64: :i64, array_f64: :f64 }.freeze
      ARRAY_TYPE_FOR  = { i64: :array_i64, f64: :array_f64 }.freeze

      # Binary arithmetic / bitwise operators whose result type we can infer.
      ARITH_OPS = %i[+ - * ** / % | & ^ << >>].to_set
      # Comparison operators return Bool (not a raw numeric), but we need
      # them for emit_truthy — they're NOT in ARITH_OPS.

      # Meet two type lattice values.
      # :unknown is the identity element; nil is absorbing.
      def self.meet(a, b)
        return b           if a == :unknown
        return a           if b == :unknown
        return nil         if a.nil? || b.nil?
        return a           if a == b
        return :f64        if a == :i64 && b == :f64
        return :f64        if a == :f64 && b == :i64
        nil                # incompatible — give up
      end

      # ------------------------------------------------------------------
      # TypeEnv — the result of analysis
      # ------------------------------------------------------------------

      class TypeEnv
        def initialize
          @slots = {}
        end

        # Raw type for a slot, or nil if polymorphic / unanalysed.
        def [](slot)
          v = @slots[slot]
          v == :unknown ? nil : v
        end

        # Raw type for a slot including :unknown sentinel.
        def raw(slot)
          @slots.fetch(slot, :unknown)
        end

        # Meet `type` into `slot`. Returns true if the slot changed.
        def meet!(slot, type)
          current = @slots.fetch(slot, :unknown)
          merged  = TypeInference.meet(current, type)
          return false if merged == current
          @slots[slot] = merged
          true
        end

        # Convenience predicate.
        def typed?(slot)
          !self[slot].nil?
        end

        def inspect
          typed = @slots.reject { |_, v| v == :unknown || v.nil? }
          "#<TypeEnv #{typed.size} typed slots>"
        end
      end

      # ------------------------------------------------------------------
      # TypeContext — scope during expression inference
      # ------------------------------------------------------------------

      # method_key: Symbol for top-level methods; [class_sym, method_sym] for instance methods.
      # class_name: Symbol of the enclosing class, or nil for top-level.
      TypeContext = Struct.new(:method_key, :class_name)

      TOP_LEVEL_CTX = TypeContext.new(nil, nil).freeze

      # ------------------------------------------------------------------
      # Construction
      # ------------------------------------------------------------------

      # @param user_methods  [Hash<Symbol, Vm::Method>]   top-level user methods
      # @param user_classes  [Hash<Symbol, Vm::ClassObject>] user-defined classes
      # @param execute_block [Ast::Block, nil]            the Frozone.compile! block
      # @param constants     [Hash<Symbol, Object>]       settled numeric constants
      def initialize(user_methods:, user_classes:, execute_block:, constants: {})
        @user_methods  = user_methods
        @user_classes  = user_classes
        @execute_block = execute_block
        @constants     = constants
        @env           = TypeEnv.new
      end

      attr_reader :env

      # ------------------------------------------------------------------
      # Main fixed-point loop
      # ------------------------------------------------------------------

      def run(iterations: 3)
        seed_constants

        iterations.times do
          changed = false

          # Propagate argument types from every call site into param slots.
          changed |= update_call_sites(@execute_block&.body, TOP_LEVEL_CTX)
          @user_methods.each do |mkey, method|
            ctx = TypeContext.new(mkey, nil)
            changed |= update_call_sites(method.body, ctx)
          end
          @user_classes.each do |cname, klass|
            each_user_instance_method(cname, klass) do |mkey, method|
              ctx = TypeContext.new(mkey, cname)
              changed |= update_call_sites(method.body, ctx)
            end
          end

          # Propagate types within each method body.
          changed |= propagate_execute_block
          @user_methods.each do |mkey, method|
            ctx = TypeContext.new(mkey, nil)
            changed |= propagate_method(mkey, method, ctx)
          end

          # Propagate instance variable types for each class.
          @user_classes.each do |cname, klass|
            changed |= propagate_ivars(cname, klass)
            each_user_instance_method(cname, klass) do |mkey, method|
              ctx = TypeContext.new(mkey, cname)
              changed |= propagate_method(mkey, method, ctx)
            end
          end

          break unless changed
        end

        @env
      end

      # ------------------------------------------------------------------
      # Seed: numeric constants
      # ------------------------------------------------------------------

      def seed_constants
        @constants.each do |name, value|
          case value
          when Vm::FloatObject   then @env.meet!([:const, name], :f64)
          when Vm::IntegerObject then @env.meet!([:const, name], :i64)
          end
        end
      end

      # ------------------------------------------------------------------
      # update_call_sites — interprocedural param propagation
      #
      # Walk a body; for every call foo(a, b, ...) infer arg types and
      # meet them into [:param, method_key, index].
      # ------------------------------------------------------------------

      def update_call_sites(node, ctx)
        return false unless node
        changed = false
        walk(node) do |n|
          next unless n.is_a?(Ast::MethodCall)
          recv = n.receiver_node
          args = n.arg_nodes || []
          next if args.empty?

          if recv.nil?
            # Free call — top-level method
            callee_key = n.name
            args.each_with_index do |arg, i|
              ty = infer_expr(arg, ctx)
              changed |= @env.meet!([:param, callee_key, i], ty) if ty
            end
          elsif recv.is_a?(Ast::ConstantRead) && n.name == :new
            # ClassName.new(...) — constructor call
            class_sym = recv.instance_variable_get(:@name)
            args.each_with_index do |arg, i|
              ty = infer_expr(arg, ctx)
              changed |= @env.meet!([:constructor_param, class_sym, i], ty) if ty
            end
          end
          # Instance method calls on typed receivers: handled in propagate_method
          # via infer_expr — not yet interprocedural for instance methods.
        end
        changed
      end

      # ------------------------------------------------------------------
      # propagate_execute_block — type locals in the execute block
      # ------------------------------------------------------------------

      def propagate_execute_block
        return false unless @execute_block&.body
        propagate_locals(@execute_block.body, TOP_LEVEL_CTX)
      end

      # ------------------------------------------------------------------
      # propagate_method — type locals + return for one method
      # ------------------------------------------------------------------

      def propagate_method(mkey, method, ctx)
        return false unless method.body
        changed = false
        # Array locals first: seed elem types before propagate_locals runs,
        # so that a[k] reads are typed when inferring scalar locals like i,y,z.
        changed |= propagate_array_locals(method.body, ctx)
        changed |= propagate_locals(method.body, ctx)
        ret_ty = infer_body_return(method.body, ctx)
        # Only commit definite numeric return types — don't pin to nil from
        # unresolved recursion (:unknown branches collapse to nil in meet).
        changed |= @env.meet!([:return, mkey], ret_ty) if ret_ty && NUMERIC_TYPES.include?(ret_ty)
        changed
      end

      # ------------------------------------------------------------------
      # propagate_locals — fixed-point local variable typing within a body
      # ------------------------------------------------------------------

      def propagate_locals(body, ctx)
        assignments = collect_assignments(body)
        return false if assignments.empty?

        # Seed param slots into a local view — params are read-only from
        # the method's own perspective (call sites drive their types).
        # We don't write back to param slots here; infer_expr reads them.

        changed = false
        # Fixed-point: repeat until no slot changes.
        loop do
          iter_changed = false
          assignments.each do |name, rhs_nodes|
            ty = rhs_nodes.reduce(:unknown) do |acc, rhs|
              t  = infer_expr(rhs, ctx)
              TypeInference.meet(acc, t || nil)
            end
            # :unknown means no typed evidence — don't update.
            next if ty == :unknown
            iter_changed |= @env.meet!([:local, ctx.method_key, name], ty)
          end
          changed |= iter_changed
          break unless iter_changed
        end
        changed
      end

      # ------------------------------------------------------------------
      # propagate_array_locals — type Array(T) locals within a body
      #
      # A local qualifies as Array(T) when:
      #   1. Exactly one assignment: Array.new(count, fill) with typed fill.
      #   2. Never escapes (passed as arg, aliased, returned, stored in ivar).
      #   3. All []= writes have values consistent with the element type.
      # ------------------------------------------------------------------

      def propagate_array_locals(body, ctx)
        return false unless body
        assignments = collect_assignments(body)

        param_names = param_names_for(ctx)
        changed = false

        assignments.each do |name, rhs_nodes|
          next if param_names.include?(name)
          next unless rhs_nodes.size == 1
          rhs = rhs_nodes.first
          next unless array_new_call?(rhs)
          args = rhs.instance_variable_get(:@arg_nodes) || []
          next unless args.size == 2
          fill_ty = infer_expr(args[1], ctx)
          next unless fill_ty && NUMERIC_TYPES.include?(fill_ty)
          arr_ty = ARRAY_TYPE_FOR[fill_ty]

          next if escapes?(name, body, ctx)
          next unless writes_consistent?(name, body, ctx, fill_ty)

          changed |= @env.meet!([:array_elem, ctx.method_key, name], fill_ty)
        end
        changed
      end

      # ------------------------------------------------------------------
      # propagate_ivars — infer ivar types for a class
      # ------------------------------------------------------------------

      def propagate_ivars(class_name, klass)
        init = (klass.instance_variable_get(:@methods_table) || {})[:initialize]
        return false unless init.is_a?(Vm::Method) && init.body

        req_params = init.instance_variable_get(:@required_params) || []
        param_types = req_params.each_with_index.map { |_, i|
          @env[[:constructor_param, class_name, i]]
        }
        return false unless param_types.all?

        ctx = TypeContext.new([class_name, :initialize], class_name)
        # Temporarily seed param types as locals so infer_expr sees them.
        old_seeds = @ivar_param_seeds
        @ivar_param_seeds = req_params.zip(param_types).to_h

        changed = false
        collect_ivar_assignments(init.body).each do |ivar_name, rhs_nodes|
          ty = rhs_nodes.reduce(:unknown) do |acc, rhs|
            t = infer_expr(rhs, ctx)
            TypeInference.meet(acc, t || nil)
          end
          next if ty == :unknown
          changed |= @env.meet!([:ivar, class_name, ivar_name], ty)
        end

        @ivar_param_seeds = old_seeds
        changed
      end

      # ------------------------------------------------------------------
      # infer_expr — the core BTA function
      #
      # Returns :i64, :f64, :array_i64, :array_f64, or nil (= RubyObject).
      # ------------------------------------------------------------------

      def infer_expr(node, ctx)
        return nil unless node
        case node
        when Ast::IntegerLiteral then :i64
        when Ast::FloatLiteral   then :f64

        # Parenthesised expression: (a | b) → Sequence([a | b]) — evaluate last element.
        when Ast::Sequence
          infer_expr(node.nodes.last, ctx)

        when Ast::LocalVariableRead
          name = node.instance_variable_get(:@name)
          # During propagate_ivars, @ivar_param_seeds maps param names → types
          # for the initialize method. This must be checked before any @env lookup
          # so that recursive calls through infer_call also see the seeds.
          return @ivar_param_seeds[name] if @ivar_param_seeds&.key?(name)
          # Check param slots first (use raw so :unknown propagates, not nil).
          idx = param_index(ctx, name)
          if idx
            pv = @env.raw([:param, ctx.method_key, idx])
            return pv unless pv == :unknown
          end
          @env.raw([:local, ctx.method_key, name])

        when Ast::InstanceVariableRead
          name = node.instance_variable_get(:@name)
          @env[[:ivar, ctx.class_name, name]]

        when Ast::ConstantRead
          name = node.instance_variable_get(:@name)
          @env[[:const, name]]

        when Ast::MethodCall
          infer_call(node, ctx)

        else
          nil
        end
      end

      # ------------------------------------------------------------------
      # infer_call — type inference for method calls
      # ------------------------------------------------------------------

      def infer_call(node, ctx)
        name = node.instance_variable_get(:@name)
        recv = node.instance_variable_get(:@receiver_node)
        args = node.instance_variable_get(:@arg_nodes) || []

        # Array element read: a[k] where a is a typed array local.
        # Use raw so :unknown propagates through arithmetic (defers rather than collapses).
        if name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
          lv = recv.instance_variable_get(:@name)
          return @env.raw([:array_elem, ctx.method_key, lv])
        end

        # Arithmetic / bitwise: numeric operands → numeric result.
        # :unknown operand → defer (return :unknown); nil operand → give up.
        if ARITH_OPS.include?(name) && args.size == 1 && recv
          rt = infer_expr(recv, ctx)
          at = infer_expr(args[0], ctx)
          return nil     if rt.nil? || at.nil?
          return :unknown if rt == :unknown || at == :unknown
          if NUMERIC_TYPES.include?(rt) || NUMERIC_TYPES.include?(at)
            return (rt == :f64 || at == :f64) ? :f64 : :i64
          end
        end

        # Free call to a top-level method — use raw so :unknown propagates.
        if recv.nil?
          return @env.raw([:return, name])
        end

        nil
      end

      # ------------------------------------------------------------------
      # infer_body_return — return type of the last value in a body
      # ------------------------------------------------------------------

      def infer_body_return(node, ctx)
        return nil unless node
        case node
        when Ast::Sequence
          # Collect types from all possible exits:
          # explicit `return` statements anywhere + implicit last expression.
          types = []
          node.nodes.each_with_index do |n, i|
            if i == node.nodes.size - 1
              ty = infer_body_return(n, ctx)
              types << ty if ty && ty != :unknown
            else
              scan_returns(n, ctx, types)
            end
          end
          return nil if types.empty?
          types.reduce { |a, b| TypeInference.meet(a, b) }.then { |v| v == :unknown ? nil : v }
        when Ast::If
          t = infer_body_return(node.instance_variable_get(:@then_node), ctx)
          e = infer_body_return(node.instance_variable_get(:@else_node), ctx)
          TypeInference.meet(t || :unknown, e || :unknown).then { |v| v == :unknown ? nil : v }
        when Ast::Return
          infer_expr(node.instance_variable_get(:@value_node), ctx)
        when Ast::While, Ast::Until
          nil  # loops return nil in Ruby
        else
          infer_expr(node, ctx)
        end
      end

      # Scan a node for explicit `return` statements and collect their types.
      # Does not descend into nested method/class definitions.
      def scan_returns(node, ctx, acc)
        return unless node
        case node
        when Ast::Return
          ty = infer_expr(node.instance_variable_get(:@value_node), ctx)
          acc << ty if ty && ty != :unknown
        when Ast::Sequence
          node.nodes.each { |n| scan_returns(n, ctx, acc) }
        when Ast::If
          scan_returns(node.instance_variable_get(:@then_node), ctx, acc)
          scan_returns(node.instance_variable_get(:@else_node), ctx, acc)
        when Ast::While, Ast::Until
          scan_returns(node.instance_variable_get(:@body_node), ctx, acc)
        # Do not descend into method defs, class defs, or block bodies.
        end
      end

      # ------------------------------------------------------------------
      # collect_assignments — gather all LHS→[RHS] pairs in a body.
      # Does not descend into block bodies (separate scope).
      # ------------------------------------------------------------------

      def collect_assignments(node, result = Hash.new { |h, k| h[k] = [] })
        return result unless node
        case node
        when Ast::LocalVariableWrite
          name = node.instance_variable_get(:@name)
          result[name] << node.instance_variable_get(:@value_node)
          collect_assignments(node.instance_variable_get(:@value_node), result)
        when Ast::Sequence
          node.nodes.each { |n| collect_assignments(n, result) }
        when Ast::If
          collect_assignments(node.instance_variable_get(:@condition_node), result)
          collect_assignments(node.instance_variable_get(:@then_node), result)
          collect_assignments(node.instance_variable_get(:@else_node), result)
        when Ast::While, Ast::Until
          collect_assignments(node.instance_variable_get(:@condition_node), result)
          collect_assignments(node.instance_variable_get(:@body_node), result)
        when Ast::Return
          collect_assignments(node.instance_variable_get(:@value_node), result)
        else
          %i[@body_node @value_node @then_node @else_node @condition_node].each do |slot|
            next unless node.instance_variable_defined?(slot)
            child = node.instance_variable_get(slot)
            collect_assignments(child, result) if child.is_a?(Ast::Node)
          end
          if node.instance_variable_defined?(:@arg_nodes)
            Array(node.instance_variable_get(:@arg_nodes)).each do |a|
              collect_assignments(a, result) if a.is_a?(Ast::Node)
            end
          end
        end
        result
      end

      # ------------------------------------------------------------------
      # collect_ivar_assignments — gather ivar writes in an initialize body
      # ------------------------------------------------------------------

      def collect_ivar_assignments(node, result = Hash.new { |h, k| h[k] = [] })
        return result unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_ivar_assignments(n, result) }
        when Ast::InstanceVariableWrite
          name = node.instance_variable_get(:@name)
          result[name] << node.instance_variable_get(:@value_node)
        when Ast::MultipleAssignment
          targets = node.instance_variable_get(:@targets) || []
          value   = node.instance_variable_get(:@value_node)
          if value.is_a?(Ast::ArrayLiteral)
            elems = value.instance_variable_get(:@element_nodes) || []
            targets.each_with_index do |t, i|
              next unless t[0] == :ivar
              result[t[1]] << elems[i] if elems[i]
            end
          end
        end
        result
      end

      # ------------------------------------------------------------------
      # Array local escape analysis
      # ------------------------------------------------------------------

      # True if `name` is used anywhere other than receiver of [] or []=.
      def escapes?(name, body, ctx)
        escaped = false
        walk(body) do |node|
          case node
          when Ast::MethodCall
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.instance_variable_get(:@name) == name
              # Only [] and []= are safe.
              escaped = true unless node.name == :[] || node.name == :[]=
            end
            # Passed as argument — escape.
            args.each do |a|
              if a.is_a?(Ast::LocalVariableRead) &&
                 a.instance_variable_get(:@name) == name
                escaped = true
              end
            end
          when Ast::AttributeWrite
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            # []= on the array itself is fine; anything else is escape.
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.instance_variable_get(:@name) == name
              escaped = true unless node.instance_variable_get(:@name) == :[]=
            end
            args.each do |a|
              if a.is_a?(Ast::LocalVariableRead) &&
                 a.instance_variable_get(:@name) == name
                escaped = true
              end
            end
          when Ast::LocalVariableWrite
            val = node.instance_variable_get(:@value_node)
            if val.is_a?(Ast::LocalVariableRead) &&
               val.instance_variable_get(:@name) == name
              escaped = true  # aliased
            end
          when Ast::Return
            val = node.instance_variable_get(:@value_node)
            if val.is_a?(Ast::LocalVariableRead) &&
               val.instance_variable_get(:@name) == name
              escaped = true
            end
          when Ast::InstanceVariableWrite
            val = node.instance_variable_get(:@value_node)
            if val.is_a?(Ast::LocalVariableRead) &&
               val.instance_variable_get(:@name) == name
              escaped = true
            end
          end
          throw :stop if escaped
        end
        escaped
      rescue UncaughtThrowError
        true
      end

      # True if all []= writes to `name` have values typed as `elem_ty`
      # (or promotable to it).
      def writes_consistent?(name, body, ctx, elem_ty)
        ok = true
        walk(body) do |node|
          next unless node.is_a?(Ast::AttributeWrite) &&
                      node.instance_variable_get(:@name) == :[]= &&
                      node.instance_variable_get(:@receiver_node)
                          .then { |r| r.is_a?(Ast::LocalVariableRead) &&
                                      r.instance_variable_get(:@name) == name }
          args = node.instance_variable_get(:@arg_nodes) || []
          val_ty = infer_expr(args[1], ctx) if args[1]
          # :unknown = not yet analysed — defer (treat as tentatively OK).
          # Only fail if we have a definite non-numeric type.
          next if val_ty == :unknown
          ok = false unless val_ty == elem_ty ||
                            (val_ty == :i64 && elem_ty == :f64)
        end
        ok
      end

      # ------------------------------------------------------------------
      # walk — depth-first AST traversal with early-exit via throw :stop
      # ------------------------------------------------------------------

      def walk(node, &block)
        return unless node
        yield node
        case node
        when Ast::Sequence
          node.nodes.each { |n| walk(n, &block) }
        when Ast::If
          walk(node.instance_variable_get(:@condition_node), &block)
          walk(node.instance_variable_get(:@then_node), &block)
          walk(node.instance_variable_get(:@else_node), &block)
        when Ast::While, Ast::Until
          walk(node.instance_variable_get(:@condition_node), &block)
          walk(node.instance_variable_get(:@body_node), &block)
        when Ast::Return
          walk(node.instance_variable_get(:@value_node), &block)
        when Ast::LocalVariableWrite, Ast::InstanceVariableWrite
          walk(node.instance_variable_get(:@value_node), &block)
        when Ast::MethodCall
          walk(node.instance_variable_get(:@receiver_node), &block)
          (node.instance_variable_get(:@arg_nodes) || []).each { |a| walk(a, &block) }
          blk = node.instance_variable_get(:@block_node)
          walk(blk&.instance_variable_get(:@body), &block) if blk
        when Ast::AttributeWrite
          walk(node.instance_variable_get(:@receiver_node), &block)
          (node.instance_variable_get(:@arg_nodes) || []).each { |a| walk(a, &block) }
        when Ast::MultipleAssignment
          walk(node.instance_variable_get(:@value_node), &block)
        when Ast::ArrayLiteral
          (node.instance_variable_get(:@element_nodes) || []).each { |e| walk(e, &block) }
        else
          # Generic fallback: walk common child slots so no node type is silently skipped.
          %i[@body_node @value_node @then_node @else_node @condition_node @receiver_node].each do |s|
            next unless node.instance_variable_defined?(s)
            child = node.instance_variable_get(s)
            walk(child, &block) if child.is_a?(Ast::Node)
          end
          if node.instance_variable_defined?(:@arg_nodes)
            Array(node.instance_variable_get(:@arg_nodes)).each { |a| walk(a, &block) if a.is_a?(Ast::Node) }
          end
          if node.instance_variable_defined?(:@element_nodes)
            Array(node.instance_variable_get(:@element_nodes)).each { |e| walk(e, &block) if e.is_a?(Ast::Node) }
          end
        end
      end

      # ------------------------------------------------------------------
      # Helpers
      # ------------------------------------------------------------------

      # True if node is Array.new(count, fill) with no block.
      def array_new_call?(node)
        return false unless node.is_a?(Ast::MethodCall)
        return false unless node.instance_variable_get(:@name) == :new
        recv = node.instance_variable_get(:@receiver_node)
        return false unless recv.is_a?(Ast::ConstantRead) &&
                            recv.instance_variable_get(:@name) == :Array
        node.instance_variable_get(:@block_node).nil?
      end

      # Iterate over user-defined instance methods of a class.
      def each_user_instance_method(class_name, klass)
        (klass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          mkey = [class_name, mname]
          yield mkey, method
        end
      end

      # Parameter names for the method identified by ctx.
      def param_names_for(ctx)
        mkey = ctx.method_key
        return [] unless mkey
        method = method_for_key(mkey)
        return [] unless method
        (method.instance_variable_get(:@required_params) || []) +
          (method.instance_variable_get(:@optional_params) || []).map(&:first) +
          [method.instance_variable_get(:@rest_param)].compact +
          (method.instance_variable_get(:@post_params) || [])
      end

      # Index of `name` in the param list of the current method, or nil.
      def param_index(ctx, name)
        param_names_for(ctx).index(name)
      end

      def method_for_key(mkey)
        if mkey.is_a?(Array)
          class_name, method_name = mkey
          klass = @user_classes[class_name]
          klass&.instance_variable_get(:@methods_table)&.fetch(method_name, nil)
        else
          @user_methods[mkey]
        end
      end

    end
  end
end

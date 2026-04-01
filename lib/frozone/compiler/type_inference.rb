module Frozone
  module Compiler
    # Whole-program type inference over a settled Frozone VM snapshot.
    #
    # This is binding-time analysis for the AoT Crystal backend: for each
    # "slot" in the closed-world program, determine the most precise type
    # in the Ruby class hierarchy — from raw Crystal numerics up through
    # user-defined classes to RubyObject.
    #
    # Type lattice (lower = more specific):
    #
    #   :unknown                   — bottom: not yet analysed
    #
    #   :i64  :f64                 — unboxed numerics (subtypes of Integer/Float)
    #   :array_i64  :array_f64    — unboxed typed arrays
    #   {class: :Planet}           — any Ruby class instance, user-defined or built-in
    #   {class: :Integer}          — boxed Integer (wider than :i64)
    #   {class: :Numeric}          — Integer | Float
    #   {class: :Object}           — any Object
    #   {class: :BasicObject}      — absolute top
    #
    # meet(a, b) walks the VM class hierarchy to find the LCA of two types.
    # Unboxed types (:i64, :f64) sit below their boxed counterparts and are
    # widened to the boxed class before LCA. :unknown is the identity element.
    #
    # All literals are typed precisely: nil → {class: :NilClass},
    # "str" → {class: :String}, true → {class: :TrueClass}, etc.
    #
    # Three fixed-point iterations cover all practical cases:
    #   Round 1 — literals → immediate arithmetic → methods called with literals
    #   Round 2 — return types feed callers → their locals refine
    #   Round 3 — one more hop for recursion / indirect propagation
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
    #   env[:local,  :advance, :bi]      # => {class: :Planet}
    class TypeInference
      # ------------------------------------------------------------------
      # Type lattice constants
      # ------------------------------------------------------------------

      NUMERIC_TYPES = %i[i64 f64].to_set
      ARRAY_TYPES   = %i[array_i64 array_f64].to_set
      RAW_TYPES     = (NUMERIC_TYPES | ARRAY_TYPES).freeze

      ARRAY_ELEM_TYPE = { array_i64: :i64, array_f64: :f64 }.freeze
      ARRAY_TYPE_FOR  = { i64: :array_i64, f64: :array_f64 }.freeze

      # Sentinel class-type values used frequently.
      OBJECT_TYPE      = {class: :Object}.freeze
      BASIC_OBJECT_TYPE = {class: :BasicObject}.freeze

      # Boxed class for each unboxed type.
      BOXED_CLASS = { i64: :Integer, f64: :Float,
                      array_i64: :Array, array_f64: :Array }.freeze

      # Binary arithmetic / bitwise operators; result type follows Ruby semantics.
      ARITH_OPS = %i[+ - * ** / % | & ^ << >>].to_set

      # Built-in Ruby class ancestry (name → ancestor chain, excluding self).
      # Used for LCA when the class is not in @user_classes.
      BUILTIN_ANCESTORS = {
        BasicObject: [],
        Object:      %i[BasicObject],
        Numeric:     %i[Object BasicObject],
        Integer:     %i[Numeric Object BasicObject],
        Float:       %i[Numeric Object BasicObject],
        Complex:     %i[Numeric Object BasicObject],
        Rational:    %i[Numeric Object BasicObject],
        String:      %i[Object BasicObject],
        Symbol:      %i[Object BasicObject],
        Array:       %i[Object BasicObject],
        Hash:        %i[Object BasicObject],
        NilClass:    %i[Object BasicObject],
        TrueClass:   %i[Object BasicObject],
        FalseClass:  %i[Object BasicObject],
        Module:      %i[Object BasicObject],
        Class:       %i[Module Object BasicObject],
        Proc:        %i[Object BasicObject],
        Range:       %i[Object BasicObject],
        Regexp:      %i[Object BasicObject],
        Encoding:    %i[Object BasicObject],
        IO:          %i[Object BasicObject],
        File:        %i[IO Object BasicObject],
        Comparable:  %i[Object BasicObject],
        Enumerable:  %i[Object BasicObject],
        Set:         %i[Object BasicObject],
        Struct:      %i[Object BasicObject],
        Random:      %i[Object BasicObject],
      }.freeze

      # ------------------------------------------------------------------
      # TypeEnv — mutable result of analysis
      # ------------------------------------------------------------------

      class TypeEnv
        def initialize(ti)
          @slots = {}
          @ti = ti
        end

        # Raw lattice value including :unknown sentinel.
        def raw(slot) = @slots.fetch(slot, :unknown)
        def typed?(slot) = !self[slot].nil?

        # Public type for a slot: nil when still :unknown, else the lattice value.
        def [](slot)
          v = @slots[slot]
          v == :unknown ? nil : v
        end

        # Meet `type` into `slot`. Returns true if the slot changed.
        def meet!(slot, type)
          return false unless type
          current = @slots.fetch(slot, :unknown)
          merged  = @ti.meet(current, type)
          return false if merged == current
          @slots[slot] = merged
          true
        end

        def inspect
          typed = @slots.reject { |_, v| v == :unknown }
          "#<TypeEnv #{typed.size} typed slots>"
        end
      end

      # ------------------------------------------------------------------
      # TypeContext — scope during expression inference
      # ------------------------------------------------------------------

      # method_key: Symbol for top-level methods; [class_sym, method_sym] for
      #             instance methods; nil for top-level execute block.
      # class_name: Symbol of the enclosing class, or nil.
      TypeContext = Struct.new(:method_key, :class_name)

      TOP_LEVEL_CTX = TypeContext.new(nil, nil).freeze

      # ------------------------------------------------------------------
      # Construction
      # ------------------------------------------------------------------

      # @param user_methods  [Hash<Symbol, Vm::Method>]
      # @param user_classes  [Hash<Symbol, Vm::ClassObject>]
      # @param execute_block [Ast::Block, nil]
      # @param constants     [Hash<Symbol, Vm::Object>]  all settled constants
      def initialize(user_methods:, user_classes:, execute_block:, constants: {})
        @user_methods = user_methods
        @user_classes = user_classes
        @execute_block = execute_block
        @constants = constants
        @env = TypeEnv.new(self)
        @ancestors_cache = {}
        build_class_ancestors
      end

      attr_reader :env

      # ------------------------------------------------------------------
      # meet — the lattice join operation (instance method for LCA access)
      # ------------------------------------------------------------------

      def meet(a, b)
        return b if a == :unknown
        return a if b == :unknown
        return a if a == b
        # Normalise unboxed symbols (:i64, :array_i64, …) to parameterised Hash
        # types before comparing, so the collection-param merge path sees them.
        a2 = a.is_a?(Hash) ? a : boxed_type(a)
        b2 = b.is_a?(Hash) ? b : boxed_type(b)
        return meet(a2, b2) if a2 != a || b2 != b   # retry with normalised forms
        # Both are Hash class types.
        if a[:class] == b[:class]
          merge_collection_params(a, b)
        elsif a[:class] == :NilClass
          # X | nil → preserve X with nullable flag
          b.is_a?(Hash) ? b.merge(nullable: true).freeze : {class: b[:class], nullable: true}.freeze
        elsif b[:class] == :NilClass
          a.is_a?(Hash) ? a.merge(nullable: true).freeze : {class: a[:class], nullable: true}.freeze
        else
          lca_of(a[:class], b[:class])
        end
      end

      # ------------------------------------------------------------------
      # Main fixed-point loop
      # ------------------------------------------------------------------

      def run(iterations: 10)
        seed_constants
        @_assign_cache = {}
        @_elem_write_cache = {}

        iterations.times do
          changed = false
          @_expr_cache = {}  # clear per-iteration; types evolve between rounds

          # Propagate argument types from every call site into param slots.
          changed |= update_call_sites(@execute_block&.body, TOP_LEVEL_CTX)
          @user_methods.each do |mkey, method|
            changed |= update_call_sites(method.body, TypeContext.new(mkey, nil))
          end
          @user_classes.each do |cname, klass|
            each_user_instance_method(cname, klass) do |mkey, method|
              changed |= update_call_sites(method.body, TypeContext.new(mkey, cname))
            end
          end

          # Propagate types within each method / block body.
          changed |= propagate_execute_block
          @user_methods.each do |mkey, method|
            changed |= propagate_method(mkey, method, TypeContext.new(mkey, nil))
          end

          # Propagate ivar and instance-method types for each class.
          @user_classes.each do |cname, klass|
            changed |= propagate_ivars(cname, klass)
            each_user_instance_method(cname, klass) do |mkey, method|
              changed |= propagate_method(mkey, method, TypeContext.new(mkey, cname))
            end
          end

          break unless changed
        end

        @env
      end

      # ------------------------------------------------------------------
      # Seed: all settled constants
      # ------------------------------------------------------------------

      def seed_constants
        @constants.each do |name, value|
          ty = vm_object_type(value)
          @env.meet!([:const, name], ty) if ty
        end
      end

      # ------------------------------------------------------------------
      # update_call_sites — interprocedural param propagation
      # ------------------------------------------------------------------

      def update_call_sites(node, ctx)
        return false unless node
        changed = false
        walk(node) do |n|
          next unless n.is_a?(Ast::MethodCall)
          recv = n.receiver_node
          args = n.arg_nodes || []
          blk  = n.instance_variable_get(:@block_node)

          # Seed block params for iteration methods (times, each, etc.)
          if blk
            ptypes = block_param_types(n.name, recv, ctx)
            seed_block_params(blk, ptypes, ctx) unless ptypes.empty?
          end

          next if args.empty?

          # Propagate keyword arg types from call site
          kw_args = n.instance_variable_get(:@kw_arg_nodes) || {}
          unless kw_args.empty?
            mkey = recv.nil? ? n.name : nil
            mkey ||= [recv.instance_variable_get(:@name), n.name] if recv.is_a?(Ast::ConstantRead)
            if mkey
              kw_args.each do |kw_name_node, val_node|
                kw_sym = kw_name_node.is_a?(Ast::SymbolLiteral) ? kw_name_node.instance_variable_get(:@value).raw : nil
                next unless kw_sym
                ty = infer_expr(val_node, ctx)
                changed |= @env.meet!([:kwparam, mkey, kw_sym], ty) if ty && ty != :unknown
              end
            end
          end

          if recv.nil?
            # Free call → top-level method params.
            args.each_with_index do |arg, i|
              ty = infer_expr(arg, ctx)
              next unless ty && ty != :unknown
              changed |= @env.meet!([:param, n.name, i], ty)
              # Also store under class-keyed slot if inside a class method
              # (free calls inside class methods are actually class method calls)
              changed |= @env.meet!([:param, [ctx.class_name, n.name], i], ty) if ctx.class_name
            end
          elsif recv.is_a?(Ast::ConstantRead) && n.name == :new
            # ClassName.new(...) → constructor params, keyed by calling context.
            # Per-context tracking enables constructor specialisation: sentinel
            # Node.new(nil, nil) won't pollute real Node.new(key, value) types.
            class_sym = recv.instance_variable_get(:@name)
            ctor_ctx = ctx.method_key || :__execute__
            args.each_with_index do |arg, i|
              ty = infer_expr(arg, ctx)
              changed |= @env.meet!([:constructor_param, class_sym, i, ctor_ctx], ty) if ty && ty != :unknown
            end
          elsif recv.is_a?(Ast::ConstantRead) && @user_classes.key?(recv.instance_variable_get(:@name))
            # Module.method(...) → class method params (keyed by module name).
            class_sym = recv.instance_variable_get(:@name)
            mkey = [class_sym, n.name]
            args.each_with_index do |arg, i|
              ty = infer_expr(arg, ctx)
              changed |= @env.meet!([:param, mkey, i], ty) if ty && ty != :unknown
            end
          elsif recv
            # Instance method call — propagate typed args to instance method params.
            recv_ty = infer_expr(recv, ctx)
            if recv_ty.is_a?(Hash) && recv_ty[:class]
              class_name = recv_ty[:class]
              mkey = [class_name, n.name]
              args.each_with_index do |arg, i|
                ty = infer_expr(arg, ctx)
                changed |= @env.meet!([:param, mkey, i], ty) if ty && ty != :unknown
              end
            end
          end
        end
        changed
      end

      # ------------------------------------------------------------------
      # propagate_execute_block
      # ------------------------------------------------------------------

      def propagate_execute_block
        return false unless @execute_block&.body
        changed = propagate_for_targets(@execute_block.body, TOP_LEVEL_CTX)
        changed |= propagate_locals(@execute_block.body, TOP_LEVEL_CTX)
        changed |= propagate_masgn_from_calls(@execute_block.body, TOP_LEVEL_CTX)
        changed
      end

      # ------------------------------------------------------------------
      # propagate_method — type locals + return for one method
      # ------------------------------------------------------------------

      def propagate_method(mkey, method, ctx)
        return false unless method.body
        changed = false
        # Seed kwarg types from default values
        (method.instance_variable_get(:@optional_kw_params) || []).each do |kw_name, default_node|
          next unless default_node
          ty = infer_expr(default_node, ctx)
          changed |= @env.meet!([:kwparam, mkey, kw_name], ty) if ty && ty != :unknown
        end
        # Array locals first so scalar locals that depend on array reads are typed.
        changed |= propagate_array_locals(method.body, ctx)
        # For-loop target variables (typed like block params to reflect Crystal level).
        changed |= propagate_for_targets(method.body, ctx)
        changed |= propagate_locals(method.body, ctx)
        changed |= propagate_masgn_from_calls(method.body, ctx)
        ret_ty = infer_body_return(method.body, ctx)
        # Commit any definite (non-:unknown) return type.
        changed |= @env.meet!([:return, mkey], ret_ty) if ret_ty && ret_ty != :unknown
        changed
      end

      # ------------------------------------------------------------------
      # propagate_locals — fixed-point local variable typing
      # ------------------------------------------------------------------

      def propagate_locals(body, ctx)
        assignments = @_assign_cache[ctx.method_key] ||= collect_assignments(body)
        return false if assignments.empty?
        changed = false
        loop do
          iter_changed = false
          assignments.each do |name, rhs_nodes|
            ty = rhs_nodes.reduce(:unknown) do |acc, rhs|
              t = infer_expr(rhs, ctx)
              meet(acc, t || :unknown)
            end
            next if ty == :unknown
            iter_changed |= @env.meet!([:local, ctx.method_key, name], ty)
          end
          changed |= iter_changed
          break unless iter_changed
        end
        changed
      end

      # When a multiple assignment destructures a function return (mr, mc = foo()),
      # trace through the function's body to find what each return-array element's
      # type is, and propagate to the local targets.
      def propagate_masgn_from_calls(body, ctx)
        changed = false
        walk(body) do |node|
          next unless node.is_a?(Ast::MultipleAssignment)
          targets = node.instance_variable_get(:@targets) || []
          value = node.instance_variable_get(:@value_node)
          next unless value.is_a?(Ast::MethodCall) && value.instance_variable_get(:@receiver_node).nil?
          method_name = value.instance_variable_get(:@name)
          method = @user_methods[method_name]
          next unless method
          # Find the return expression — walk method body for the last expression
          ret_node = last_expression(method.body)
          next unless ret_node.is_a?(Ast::ArrayLiteral)
          ret_elems = ret_node.instance_variable_get(:@element_nodes) || []
          # Map each element's type to the corresponding target local
          targets.each_with_index do |t, i|
            next unless t[0] == :local && ret_elems[i]
            # Infer the return element's type in the CALLED method's context
            callee_ctx = TypeContext.new(method_name, nil)
            elem_ty = infer_expr(ret_elems[i], callee_ctx)
            next unless elem_ty && elem_ty != :unknown
            changed |= @env.meet!([:local, ctx.method_key, t[1]], elem_ty)
          end
        end
        changed
      end

      def last_expression(node)
        return nil unless node
        case node
        when Ast::Sequence then last_expression(node.nodes.last)
        else node
        end
      end

      # ------------------------------------------------------------------
      # propagate_array_locals — type Array(T) unboxed locals
      #
      # A local is Array(Int64) / Array(Float64) when:
      #   1. Exactly one assignment: Array.new(count, fill) with typed fill.
      #   2. Never escapes (passed as arg, aliased, returned, stored in ivar).
      #   3. All []= writes have values consistent with the element type.
      # ------------------------------------------------------------------

      def propagate_array_locals(body, ctx)
        return false unless body
        assignments = @_assign_cache[ctx.method_key] ||= collect_assignments(body)
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
          next unless NUMERIC_TYPES.include?(fill_ty)

          next if escapes?(name, body, ctx) && !escapes_only_via_return_array?(name, body)
          next unless writes_consistent?(name, body, ctx, fill_ty)

          changed |= @env.meet!([:array_elem, ctx.method_key, name], fill_ty)
        end

        # Infer element types from push operations (<<, push, []=) on array locals.
        # Only promote when ALL writes to the array's elements are consistently typed.
        elem_writes = @_elem_write_cache[ctx.method_key] ||= collect_array_elem_writes(body)
        elem_writes.each do |key, value_nodes|
          # Direct writes: arr << val, arr[i] = val
          if key.is_a?(Symbol)
            next if param_names.include?(key)
            types = value_nodes.map { |v| infer_expr(v, ctx) }
            next unless types.all? { |t| NUMERIC_TYPES.include?(t) }
            unique = types.uniq
            next unless unique.size == 1
            changed |= @env.meet!([:array_elem, ctx.method_key, key], unique[0])
          # Nested writes: arr[i] << val — refine arr's local type to Array(Array(T))
          elsif key.is_a?(Array) && key[0] == :sub
            arr_name = key[1]
            types = value_nodes.map { |v| infer_expr(v, ctx) }
            next unless types.all? { |t| NUMERIC_TYPES.include?(t) }
            unique = types.uniq
            next unless unique.size == 1
            local_ty = @env[[:local, ctx.method_key, arr_name]]
            if local_ty.is_a?(Hash) && local_ty[:class] == :Array
              inner = { class: :Array, elem: unique[0] }
              changed |= @env.meet!([:local, ctx.method_key, arr_name], { class: :Array, elem: inner })
            end
          end
        end
        changed
      end

      # Collect value nodes pushed/written to array locals.
      # Handles: arr << val, arr.push(val), arr[i] = val,
      # and nested: arr[i] << val (propagates to arr's sub-arrays).
      def collect_array_elem_writes(node, result = Hash.new { |h, k| h[k] = [] }, depth: 0)
        return result unless node
        case node
        when Ast::MethodCall
          args = node.instance_variable_get(:@arg_nodes) || []
          recv = node.receiver_node
          if (node.name == :<< || node.name == :push) && args.size == 1
            if recv.is_a?(Ast::LocalVariableRead)
              result[recv.instance_variable_get(:@name)] << args[0]
            elsif recv.is_a?(Ast::MethodCall) && recv.name == :[] &&
                  recv.receiver_node.is_a?(Ast::LocalVariableRead)
              # arr[i] << val — val is an elem of arr's sub-arrays
              # Store with a [:sub, name] key to distinguish from direct writes
              result[[:sub, recv.receiver_node.instance_variable_get(:@name)]] << args[0]
            end
          end
          # Recurse into children
          collect_array_elem_writes(recv, result, depth: depth)
          args.each { |a| collect_array_elem_writes(a, result, depth: depth) }
          blk = node.instance_variable_get(:@block_node)
          collect_array_elem_writes(blk.body, result, depth: depth) if blk.is_a?(Ast::Block)
        when Ast::AttributeWrite
          if node.instance_variable_get(:@name) == :[]=
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            if recv.is_a?(Ast::LocalVariableRead) && args.size == 2
              result[recv.instance_variable_get(:@name)] << args[1]
            end
          end
        when Ast::Sequence
          node.nodes.each { |n| collect_array_elem_writes(n, result, depth: depth) }
        when Ast::If
          %i[@condition_node @then_node @else_node].each do |iv|
            collect_array_elem_writes(node.instance_variable_get(iv), result, depth: depth) if node.instance_variable_defined?(iv)
          end
        when Ast::While, Ast::Until
          collect_array_elem_writes(node.instance_variable_get(:@body_node), result, depth: depth)
        when Ast::Block
          collect_array_elem_writes(node.body, result, depth: depth)
        end
        result
      end

      # ------------------------------------------------------------------
      # propagate_for_targets — seed for-loop iteration variable types
      #
      # Ruby `for x in collection` does not create a new scope; `x` persists
      # in the enclosing method.  At Crystal level, `emit_for_loop` emits
      # `collection.each do |x|` where `x` arrives as RubyObject — exactly
      # like a block param.  We therefore store the inferred type in
      # [:block_param, mkey, name] (not [:local, ...]) so the codegen can
      # detect native-loop candidates without attempting raw emission on a
      # variable that is actually RubyObject in the generic path.
      # ------------------------------------------------------------------

      def propagate_for_targets(body, ctx)
        return false unless body
        changed = false
        walk(body) do |node|
          next unless node.is_a?(Ast::ForLoop)
          target = node.instance_variable_get(:@target)
          next unless target[0] == :local
          name = target[1]
          coll_node = node.instance_variable_get(:@collection_node)
          coll_ty = infer_expr(coll_node, ctx)
          elem_ty = for_loop_elem_type(coll_ty)
          next unless elem_ty && elem_ty != :unknown
          changed |= @env.meet!([:block_param, ctx.method_key, name], elem_ty)
        end
        changed
      end

      def for_loop_elem_type(coll_ty)
        return :i64 if coll_ty.is_a?(Hash) && coll_ty[:class] == :Range
        return coll_ty[:elem] if coll_ty.is_a?(Hash) && coll_ty[:class] == :Array && coll_ty.key?(:elem)
        nil
      end

      # ------------------------------------------------------------------
      # propagate_ivars — infer ivar types from initialize body
      # ------------------------------------------------------------------

      def propagate_ivars(class_name, klass)
        init = (klass.instance_variable_get(:@methods_table) || {})[:initialize]
        return false unless init.is_a?(Vm::Method) && init.body

        req_params = init.instance_variable_get(:@required_params) || []
        param_types = best_constructor_param_types(class_name, req_params.size)
        return false unless param_types&.any? { |t| t != :unknown }

        ctx = TypeContext.new([class_name, :initialize], class_name)
        old_seeds = @ivar_param_seeds
        @ivar_param_seeds = req_params.zip(param_types).to_h

        changed = false
        # Collect ivar assignments from initialize
        all_ivar_assigns = collect_ivar_assignments(init.body)

        # Infer ivar types from initialize
        all_ivar_assigns.each do |ivar_name, rhs_nodes|
          ty = rhs_nodes.reduce(:unknown) do |acc, rhs|
            t = infer_expr(rhs, ctx)
            meet(acc, t || :unknown)
          end
          next if ty == :unknown
          changed |= @env.meet!([:ivar, class_name, ivar_name], ty)
        end

        # Also collect from all other instance methods — ivars may be
        # assigned outside initialize (e.g. @root = Node.new in insert)
        (klass.methods_table || {}).each do |mname, method|
          next if mname == :initialize || !method.is_a?(Vm::Method) || !method.body
          method_ctx = TypeContext.new([class_name, mname], class_name)
          collect_ivar_assignments(method.body).each do |ivar_name, rhs_nodes|
            rhs_nodes.each do |rhs|
              ty = infer_expr(rhs, method_ctx)
              next if ty.nil? || ty == :unknown
              changed |= @env.meet!([:ivar, class_name, ivar_name], ty)
            end
          end
        end

        # Track setter calls (obj.left = val) as ivar assignments.
        # When a method on this class calls self.attr= or obj.attr= where obj
        # is known to be this class, treat it as @attr = val.
        accessor_names = Set.new
        (klass.methods_table || {}).each_key do |mn|
          accessor_names << mn.to_s.chomp('=').to_sym if mn.to_s.end_with?('=') && mn != :initialize
        end
        unless accessor_names.empty?
          # Scan all user methods (top-level + instance methods on all classes)
          all_methods = @user_methods.to_a
          @user_classes.each do |cname, ck|
            (ck.methods_table || {}).each do |mn, m|
              all_methods << [[cname, mn], m] if m.is_a?(Vm::Method)
            end
          end
          all_methods.each do |mkey, method|
            next unless method.body
            method_ctx = TypeContext.new(mkey, mkey.is_a?(Array) ? mkey[0] : nil)
            collect_setter_calls(method.body, class_name, accessor_names, method_ctx) do |attr_name, ty|
              changed |= @env.meet!([:ivar, class_name, :"@#{attr_name}"], ty)
            end
          end
        end

        @ivar_param_seeds = old_seeds
        changed
      end

      # Walk body for setter calls (obj.attr= val) on known-class receivers.
      def collect_setter_calls(node, class_name, accessor_names, ctx, &block)
        return unless node
        if node.is_a?(Ast::AttributeWrite)
          name_sym = node.instance_variable_get(:@name)
          attr = name_sym.to_s.chomp('=').to_sym
          if accessor_names.include?(attr)
            recv = node.instance_variable_get(:@receiver_node)
            recv_cls = nil
            if recv.is_a?(Ast::LocalVariableRead)
              recv_ty = @env[[:local, ctx.method_key, recv.instance_variable_get(:@name)]]
              recv_cls = recv_ty[:class] if recv_ty.is_a?(Hash)
            end
            if recv_cls == class_name
              args = node.instance_variable_get(:@arg_nodes) || []
              if args[0]
                ty = infer_expr(args[0], ctx)
                block.call(attr, ty) if ty && ty != :unknown
              end
            end
          end
        end
        node.children.each { |c| collect_setter_calls(c, class_name, accessor_names, ctx, &block) }
      end

      # ------------------------------------------------------------------
      # infer_expr — core BTA function
      # ------------------------------------------------------------------

      def infer_expr(node, ctx)
        return :unknown unless node
        cache_key = node.object_id * 31 + ctx.method_key.hash
        return @_expr_cache[cache_key] if @_expr_cache.key?(cache_key)
        result = infer_expr_uncached(node, ctx)
        @_expr_cache[cache_key] = result
      end

      def infer_expr_uncached(node, ctx)
        case node
        # Exact class types for all literals.
        when Ast::IntegerLiteral  then :i64
        when Ast::FloatLiteral    then :f64
        when Ast::NilLiteral      then {class: :NilClass}
        when Ast::TrueLiteral     then {class: :TrueClass}
        when Ast::FalseLiteral    then {class: :FalseClass}
        when Ast::StringLiteral   then {class: :String}
        when Ast::SymbolLiteral   then {class: :Symbol}
        when Ast::ArrayLiteral
          elems = node.instance_variable_get(:@element_nodes) || []
          if elems.empty?
            {class: :Array}
          else
            elem_ty = elems.reduce(:unknown) { |acc, e| meet(acc, infer_expr(e, ctx)) }
            elem_ty == :unknown ? {class: :Array} : {class: :Array, elem: elem_ty}.freeze
          end

        when Ast::HashLiteral
          pairs = node.instance_variable_get(:@kv_nodes) || []
          if pairs.empty?
            {class: :Hash}
          else
            key_ty = pairs.reduce(:unknown) { |acc, (k, _)| meet(acc, infer_expr(k, ctx)) }
            val_ty = pairs.reduce(:unknown) { |acc, (_, v)| meet(acc, infer_expr(v, ctx)) }
            result = {class: :Hash}
            result[:key] = key_ty unless key_ty == :unknown
            result[:val] = val_ty unless val_ty == :unknown
            result.freeze
          end
        when Ast::RangeLiteral    then {class: :Range}
        when Ast::RegexpLiteral   then {class: :Regexp}

        # Parenthesised expression: (a | b) → Sequence([a | b]).
        when Ast::Sequence
          infer_expr(node.nodes.last, ctx)

        when Ast::LocalVariableRead
          name = node.instance_variable_get(:@name)
          # During propagate_ivars, @ivar_param_seeds provides constructor param types.
          return @ivar_param_seeds[name] if @ivar_param_seeds&.key?(name)
          # Param slots (use raw so :unknown defers rather than collapsing).
          idx = param_index(ctx, name)
          if idx
            pv = @env.raw([:param, ctx.method_key, idx])
            return pv unless pv == :unknown
          end
          # Keyword param slots
          kp = @env.raw([:kwparam, ctx.method_key, name])
          return kp if kp != :unknown
          # Block param seeds (separate slot so codegen doesn't treat them as raw locals).
          bp = @env.raw([:block_param, ctx.method_key, name])
          return bp if bp != :unknown
          @env.raw([:local, ctx.method_key, name])

        when Ast::InstanceVariableRead
          name = node.instance_variable_get(:@name)
          @env.raw([:ivar, ctx.class_name, name])

        when Ast::ConstantRead
          name = node.instance_variable_get(:@name)
          @env.raw([:const, name])

        when Ast::MethodCall
          infer_call(node, ctx)

        when Ast::Or
          # a || b — result type is meet of both sides (either could be returned)
          lt = infer_expr(node.instance_variable_get(:@left_node), ctx)
          rt = infer_expr(node.instance_variable_get(:@right_node), ctx)
          return rt if lt == :unknown
          return lt if rt == :unknown
          meet(lt, rt)

        when Ast::And
          # a && b — result is the right side's type (if both truthy) or left (if falsy)
          lt = infer_expr(node.instance_variable_get(:@left_node), ctx)
          rt = infer_expr(node.instance_variable_get(:@right_node), ctx)
          return rt if lt == :unknown
          return lt if rt == :unknown
          meet(lt, rt)

        when Ast::Not
          {class: :TrueClass}  # !x always returns boolean

        else
          :unknown
        end
      end

      # ------------------------------------------------------------------
      # infer_call — type inference for method calls
      # ------------------------------------------------------------------

      # Math module methods that always return Float.
      MATH_FLOAT_METHODS = %i[sqrt cbrt exp log log2 log10 sin cos tan asin acos atan atan2
                               sinh cosh tanh asinh acosh atanh hypot ldexp frexp].to_set

      # Built-in methods on Array/Integer/Float with known return types.
      ARRAY_INT_METHODS  = %i[length size count].to_set
      INT_INT_METHODS    = %i[abs ceil floor round truncate].to_set
      FLOAT_FLOAT_METHODS = %i[abs].to_set
      FLOAT_INT_METHODS   = %i[ceil floor round truncate].to_set
      # Explicit coercion methods: always return a known numeric type.
      COERCE_TO_FLOAT    = %i[to_f to_f64 to_r].to_set
      COERCE_TO_INT      = %i[to_i to_i64 to_int].to_set

      def infer_call(node, ctx)
        name = node.instance_variable_get(:@name)
        recv = node.instance_variable_get(:@receiver_node)
        args = node.instance_variable_get(:@arg_nodes) || []
        blk  = node.instance_variable_get(:@block_node)

        # Array.new(n) { |i| expr }  → Array with block-inferred element type.
        # Array.new(n, fill)         → Array with fill-typed elements.
        if name == :new && recv.is_a?(Ast::ConstantRead) &&
           recv.instance_variable_get(:@name) == :Array
          if blk
            elem_ty = infer_block_return(blk, [:i64], ctx)
            return (elem_ty && elem_ty != :unknown) ?
                   {class: :Array, elem: elem_ty}.freeze : {class: :Array}
          elsif args.size == 2
            fill_ty = infer_expr(args[1], ctx)
            return (fill_ty && fill_ty != :unknown) ?
                   {class: :Array, elem: fill_ty}.freeze : {class: :Array}
          end
        end

        # Array#map { |x| expr } → new Array with block-inferred element type.
        if name == :map && blk && recv
          recv_ty = infer_expr(recv, ctx)
          if recv_ty.is_a?(Hash) && recv_ty[:class] == :Array
            elem_in  = recv_ty.fetch(:elem, :unknown)
            elem_out = infer_block_return(blk, [elem_in], ctx)
            return (elem_out && elem_out != :unknown) ?
                   {class: :Array, elem: elem_out}.freeze : {class: :Array}
          end
        end

        # Seed block params for common iteration methods (each, times, upto, etc.)
        # so that block body expressions can be typed in subsequent passes.
        if blk
          ptypes = block_param_types(name, recv, ctx)
          seed_block_params(blk, ptypes, ctx) unless ptypes.empty?
        end

        # ClassName.new(...) → exact class instance type.
        if name == :new && recv.is_a?(Ast::ConstantRead)
          class_sym = recv.instance_variable_get(:@name)
          return {class: class_sym}
        end

        # Math.method(...) → always returns Float (f64).
        if recv.is_a?(Ast::ConstantRead) &&
           recv.instance_variable_get(:@name) == :Math &&
           MATH_FLOAT_METHODS.include?(name)
          return :f64
        end

        # Array element read recv[k].
        if name == :[] && args.size == 1
          # Unboxed Array(T) local — use raw to propagate :unknown through arithmetic.
          if recv.is_a?(Ast::LocalVariableRead)
            lv = recv.instance_variable_get(:@name)
            raw = @env.raw([:array_elem, ctx.method_key, lv])
            return raw if raw != :unknown
          end
          # Typed (boxed) Array with known elem type — covers constants, params, locals.
          recv_ty = infer_expr(recv, ctx)
          return recv_ty[:elem] if recv_ty.is_a?(Hash) && recv_ty[:class] == :Array &&
                                   recv_ty.key?(:elem)
        end

        # Range#to_a → Array with endpoint element type
        # Unwrap parenthesised Sequence: (0..n).to_a parses as Sequence([RangeLiteral])
        unwrapped_recv = recv
        unwrapped_recv = unwrapped_recv.nodes.first while unwrapped_recv.is_a?(Ast::Sequence) && unwrapped_recv.nodes.size == 1
        if (name == :to_a || name == :to_ary) && unwrapped_recv.is_a?(Ast::RangeLiteral)
          begin_ty = infer_expr(unwrapped_recv.instance_variable_get(:@begin_node), ctx)
          return {class: :Array, elem: begin_ty}.freeze if NUMERIC_TYPES.include?(begin_ty)
          return {class: :Array}
        end

        # Built-in Array methods with known return types.
        if recv
          recv_ty = infer_expr(recv, ctx)
          # Explicit coercion: to_f/to_f64 always yield Float64, to_i/to_i64 always Int64.
          return :f64 if COERCE_TO_FLOAT.include?(name) && recv_ty != :unknown
          return :i64 if COERCE_TO_INT.include?(name) && recv_ty != :unknown
          if recv_ty.is_a?(Hash)
            return :i64 if recv_ty[:class] == :Array   && ARRAY_INT_METHODS.include?(name)
            return :i64 if recv_ty[:class] == :Integer && INT_INT_METHODS.include?(name)
            return :f64 if recv_ty[:class] == :Float   && FLOAT_FLOAT_METHODS.include?(name)
            return :i64 if recv_ty[:class] == :Float   && FLOAT_INT_METHODS.include?(name)
            # String byte methods return Integer
            return :i64 if recv_ty[:class] == :String && %i[getbyte ord bytesize].include?(name)
            # Random#rand(int) → Integer, Random#rand → Float
            if recv_ty[:class] == :Random && name == :rand
              return args.empty? ? :f64 : :i64
            end
          end
          # dup/clone/freeze always return the same type as the receiver
          return recv_ty if recv_ty != :unknown && (name == :dup || name == :clone || name == :freeze)
        end

        # Arithmetic / bitwise — Ruby-semantic result type.
        # :unknown operand → defer; non-numeric operand → give up.
        if ARITH_OPS.include?(name) && args.size == 1 && recv
          rt = infer_expr(recv, ctx)
          at = infer_expr(args[0], ctx)
          return :unknown if rt == :unknown || at == :unknown
          if NUMERIC_TYPES.include?(rt) && NUMERIC_TYPES.include?(at)
            return (rt == :f64 || at == :f64) ? :f64 : :i64
          end
          # One side is a boxed numeric — still may produce a numeric result.
          if numeric_class_type?(rt) && numeric_class_type?(at)
            return :unknown  # defer; not enough info to unbox
          end
          return :unknown
        end

        # Class method call: Module.method(...) → look up by module name.
        if recv.is_a?(Ast::ConstantRead) && @user_classes.key?(recv.instance_variable_get(:@name))
          class_sym = recv.instance_variable_get(:@name)
          ret = @env.raw([:return, [class_sym, name]])
          return ret if ret != :unknown
        end

        # Method call on a known class instance — look up return type.
        if recv
          recv_ty = infer_expr(recv, ctx)
          if recv_ty.is_a?(Hash) && recv_ty[:class]
            mkey = [recv_ty[:class], name]
            return @env.raw([:return, mkey])
          end
        end

        # Free call to a top-level user method.
        if recv.nil?
          return @env.raw([:return, name])
        end

        :unknown
      end

      # Infer the return type of a block body, seeding required params as locals
      # in the enclosing method's namespace (Ruby closure semantics).
      def infer_block_return(block_node, param_types, ctx)
        return :unknown unless block_node.is_a?(Ast::Block)
        seed_block_params(block_node, param_types, ctx)
        infer_body_return(block_node.body, ctx)
      end

      # Seed block required_params into [:block_param, mkey, name] env slots.
      # These are separate from [:local, ...] so the codegen doesn't treat them
      # as raw Crystal Int64/Float64 locals (block params arrive as RubyObject).
      def seed_block_params(block_node, param_types, ctx)
        return unless block_node.is_a?(Ast::Block)
        params = block_node.required_params || []
        params.each_with_index do |pname, i|
          next unless pname.is_a?(Symbol)
          ty = param_types[i]
          next unless ty && ty != :unknown
          @env.meet!([:block_param, ctx.method_key, pname], ty)
        end
      end

      # Returns the expected block param types for common built-in iteration methods.
      def block_param_types(method_name, recv_node, ctx)
        case method_name
        when :times, :upto, :downto
          [:i64]
        when :each, :map, :flat_map, :select, :reject, :filter,
             :each_with_object, :min_by, :max_by, :sort_by, :any?, :all?, :none?,
             :find, :detect, :count, :sum, :reduce, :inject
          recv_ty = recv_node ? infer_expr(recv_node, ctx) : :unknown
          if recv_ty.is_a?(Hash)
            elem = recv_ty[:elem] || :unknown
            return [elem] if recv_ty[:class] == :Array
            return [:i64] if recv_ty[:class] == :Range
          end
          []
        when :each_with_index
          recv_ty = recv_node ? infer_expr(recv_node, ctx) : :unknown
          if recv_ty.is_a?(Hash) && recv_ty[:class] == :Array
            [recv_ty[:elem] || :unknown, :i64]
          else
            [:unknown, :i64]
          end
        else
          []
        end
      end

      # ------------------------------------------------------------------
      # infer_body_return — return type of the last value in a body
      # ------------------------------------------------------------------

      def infer_body_return(node, ctx)
        return :unknown unless node
        case node
        when Ast::Sequence
          types = []
          node.nodes.each_with_index do |n, i|
            if i == node.nodes.size - 1
              ty = infer_body_return(n, ctx)
              types << ty if ty && ty != :unknown
            else
              scan_returns(n, ctx, types)
            end
          end
          # Also scan the last node for explicit returns (e.g., loop { return x })
          scan_returns(node.nodes.last, ctx, types) if types.empty?
          return :unknown if types.empty?
          types.reduce { |a, b| meet(a, b) }
        when Ast::If
          then_n = node.instance_variable_get(:@then_node)
          else_n = node.instance_variable_get(:@else_node)
          t = infer_body_return(then_n, ctx)
          e = else_n ? infer_body_return(else_n, ctx) : {class: :NilClass}
          meet(t == :unknown ? :unknown : t, e == :unknown ? :unknown : e)
        when Ast::Return
          infer_expr(node.instance_variable_get(:@value_node), ctx)
        when Ast::While, Ast::Until
          {class: :NilClass}  # while/until always returns nil in Ruby
        else
          infer_expr(node, ctx)
        end
      end

      # Collect explicit return types from a node (not the last-expression path).
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
        when Ast::MethodCall
          # Recurse into block bodies (e.g., loop { return x } or each { return x })
          blk = node.instance_variable_get(:@block_node)
          scan_returns(blk.body, ctx, acc) if blk.respond_to?(:body)
        when Ast::Block
          scan_returns(node.body, ctx, acc)
        end
      end

      # ------------------------------------------------------------------
      # collect_assignments — gather all LHS→[RHS] pairs in a body
      # ------------------------------------------------------------------

      def collect_assignments(node, result = Hash.new { |h, k| h[k] = [] })
        return result unless node
        case node
        when Ast::LocalVariableWrite
          name = node.instance_variable_get(:@name)
          result[name] << node.instance_variable_get(:@value_node)
          collect_assignments(node.instance_variable_get(:@value_node), result)
        when Ast::MultipleAssignment
          targets = node.instance_variable_get(:@targets) || []
          value   = node.instance_variable_get(:@value_node)
          if value.is_a?(Ast::ArrayLiteral)
            elems = value.instance_variable_get(:@element_nodes) || []
            targets.each_with_index do |t, i|
              next unless t[0] == :local
              result[t[1]] << elems[i] if elems[i]
            end
          end
        when Ast::Sequence
          node.nodes.each { |n| collect_assignments(n, result) }
        when Ast::If
          collect_assignments(node.instance_variable_get(:@condition_node), result)
          collect_assignments(node.instance_variable_get(:@then_node), result)
          collect_assignments(node.instance_variable_get(:@else_node), result)
        when Ast::While, Ast::Until
          collect_assignments(node.instance_variable_get(:@condition_node), result)
          collect_assignments(node.instance_variable_get(:@body_node), result)
        when Ast::ForLoop
          collect_assignments(node.instance_variable_get(:@collection_node), result)
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
          # Ruby blocks are closures — assignments inside a block body are
          # visible in the enclosing scope, so descend into block bodies.
          if node.instance_variable_defined?(:@block_node)
            blk = node.instance_variable_get(:@block_node)
            if blk&.instance_variable_defined?(:@body)
              collect_assignments(blk.instance_variable_get(:@body), result)
            end
          end
        end
        result
      end

      # ------------------------------------------------------------------
      # collect_ivar_assignments — ivar writes in an initialize body
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

      def escapes?(name, body, ctx)
        escaped = false
        walk(body) do |node|
          case node
          when Ast::MethodCall
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.instance_variable_get(:@name) == name
              escaped = true unless node.name == :[] || node.name == :[]=
            end
            args.each do |a|
              escaped = true if a.is_a?(Ast::LocalVariableRead) &&
                                a.instance_variable_get(:@name) == name
            end
          when Ast::AttributeWrite
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.instance_variable_get(:@name) == name
              escaped = true unless node.instance_variable_get(:@name) == :[]=
            end
            args.each do |a|
              escaped = true if a.is_a?(Ast::LocalVariableRead) &&
                                a.instance_variable_get(:@name) == name
            end
          when Ast::LocalVariableWrite
            val = node.instance_variable_get(:@value_node)
            if val.is_a?(Ast::LocalVariableRead) &&
               val.instance_variable_get(:@name) == name
              escaped = true
            end
          when Ast::Return, Ast::InstanceVariableWrite
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

      # Does the local escape ONLY via the final array literal return?
      # If so, Crystal tuple return preserves the type — safe to promote.
      def escapes_only_via_return_array?(name, body)
        last = last_expression(body)
        return false unless last.is_a?(Ast::ArrayLiteral)
        # Check that the local appears in the return array literal
        ret_elems = last.instance_variable_get(:@element_nodes) || []
        in_return = ret_elems.any? { |e|
          e.is_a?(Ast::LocalVariableRead) && e.instance_variable_get(:@name) == name
        }
        return false unless in_return
        # Check no other escapes besides the return array and normal []/[]= use
        escaped_elsewhere = false
        walk(body) do |node|
          # Skip the final array literal itself
          next if node.equal?(last)
          case node
          when Ast::MethodCall
            recv = node.instance_variable_get(:@receiver_node)
            args = node.instance_variable_get(:@arg_nodes) || []
            # Receiver use is OK for []/[]=
            if recv.is_a?(Ast::LocalVariableRead) && recv.instance_variable_get(:@name) == name
              escaped_elsewhere = true unless node.name == :[] || node.name == :[]=
            end
            # Arg use is an escape (passed to another function)
            args.each do |a|
              escaped_elsewhere = true if a.is_a?(Ast::LocalVariableRead) && a.instance_variable_get(:@name) == name
            end
          when Ast::AttributeWrite
            recv = node.instance_variable_get(:@receiver_node)
            if recv.is_a?(Ast::LocalVariableRead) && recv.instance_variable_get(:@name) == name
              escaped_elsewhere = true unless node.instance_variable_get(:@name) == :[]=
            end
          when Ast::Return, Ast::InstanceVariableWrite
            val = node.instance_variable_get(:@value_node)
            escaped_elsewhere = true if val.is_a?(Ast::LocalVariableRead) && val.instance_variable_get(:@name) == name
          end
          throw :stop if escaped_elsewhere
        end
        !escaped_elsewhere
      rescue UncaughtThrowError
        false
      end

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
        when Ast::ForLoop
          walk(node.instance_variable_get(:@collection_node), &block)
          walk(node.instance_variable_get(:@body_node), &block)
        when Ast::ArrayLiteral
          (node.instance_variable_get(:@element_nodes) || []).each { |e| walk(e, &block) }
        else
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
      # Class hierarchy helpers
      # ------------------------------------------------------------------

      # Build @ancestors_cache for all user-defined classes.
      def build_class_ancestors
        @user_classes.each do |name, klass|
          @ancestors_cache[name] = compute_user_ancestors(klass)
        end
      end

      # Full ancestor chain (excluding self) for a user-defined class.
      def compute_user_ancestors(klass)
        chain = []
        current = klass.instance_variable_get(:@superclass)
        while current
          cname = current.instance_variable_get(:@name)
          break unless cname
          chain << cname
          # If we've reached a built-in class, append its known ancestors.
          if BUILTIN_ANCESTORS.key?(cname)
            chain.concat(BUILTIN_ANCESTORS[cname])
            break
          end
          current = current.instance_variable_get(:@superclass)
        end
        # Ensure Object and BasicObject are always at the end.
        chain |= %i[Object BasicObject]
        chain
      end

      # Ancestor chain for any class name (user-defined or built-in).
      def ancestors_of(name)
        @ancestors_cache[name] ||=
          if BUILTIN_ANCESTORS.key?(name)
            [name] + BUILTIN_ANCESTORS[name]
          else
            [name, :Object, :BasicObject]
          end
      end

      # Least common ancestor of two class names → {class: lca_name}.
      def lca_of(a_name, b_name)
        return {class: a_name} if a_name == b_name
        chain_a = ancestors_of(a_name)
        set_a = chain_a.to_set
        chain_b = ancestors_of(b_name)
        lca = chain_b.find { |c| set_a.include?(c) }
        lca ? {class: lca} : BASIC_OBJECT_TYPE
      end

      # Full boxed (parameterized) class type for an unboxed type.
      # :i64 → {class: :Integer}, :array_i64 → {class: :Array, elem: :i64}, etc.
      def boxed_type(ty)
        case ty
        when :i64       then {class: :Integer}
        when :f64       then {class: :Float}
        when :array_i64 then {class: :Array, elem: :i64}
        when :array_f64 then {class: :Array, elem: :f64}
        when Hash       then ty
        else OBJECT_TYPE
        end
      end

      # Bare Ruby class name for a lattice type value (ignores params).
      def boxed_class(ty)
        return ty[:class] if ty.is_a?(Hash)
        BOXED_CLASS[ty] || :Object
      end

      # Meet two parameterized collection types that share the same base class.
      # Only merges params (elem, key, val) that are present in BOTH sides.
      # Strip nullable from a type and convert back to raw unboxed form if possible.
      # {class: :Float, nullable: true} → :f64, {class: :Integer, nullable: true} → :i64
      # Collect constructor param types across all calling contexts and pick
      # the best (most precise) type for each param. Contexts that pass only
      # NilClass are excluded — sentinel construction shouldn't widen ivars.
      # Returns nil if no typed contexts exist.
      def best_constructor_param_types(class_name, param_count)
        # Find all calling contexts that construct this class
        slots = @env.instance_variable_get(:@slots)
        contexts = Set.new
        slots.each_key do |slot|
          next unless slot.is_a?(Array) && slot[0] == :constructor_param && slot[1] == class_name && slot.size == 4
          contexts << slot[3]
        end
        return nil if contexts.empty?

        param_count.times.map do |i|
          # Collect types from all contexts for this param
          types = contexts.filter_map { |ctx_key| @env[[:constructor_param, class_name, i, ctx_key]] }
          return nil if types.empty?
          # Exclude NilClass-only contributions — sentinel construction
          non_nil = types.reject { |t| t.is_a?(Hash) && t[:class] == :NilClass }
          # If only NilClass contexts exist for this param, use :unknown so it
          # doesn't poison ivar typing. Real types will arrive in later iterations.
          next :unknown if non_nil.empty?
          non_nil.reduce { |a, b| meet(a, b) }
        end
      end

      def strip_nullable_to_raw(ty)
        return ty unless ty.is_a?(Hash) && ty[:nullable]
        case ty[:class]
        when :Float   then :f64
        when :Integer then :i64
        else ty.reject { |k, _| k == :nullable }.freeze
        end
      end

      def merge_collection_params(a, b)
        result = {class: a[:class]}
        result[:nullable] = true if a[:nullable] || b[:nullable]
        # For each param (:elem, :key, :val): merge if both present, take whichever
        # side has it if only one does (absent = not yet observed, not "unknowable").
        %i[elem key val].each do |param|
          if a.key?(param) && b.key?(param)
            result[param] = meet(a[param], b[param])
          elsif a.key?(param)
            result[param] = a[param]
          elsif b.key?(param)
            result[param] = b[param]
          end
        end
        result.freeze
      end

      # True if ty is a class type known to be Numeric or a subclass.
      def numeric_class_type?(ty)
        return true if NUMERIC_TYPES.include?(ty)
        return false unless ty.is_a?(Hash)
        ancestors_of(ty[:class]).include?(:Numeric)
      end

      # ------------------------------------------------------------------
      # VM object → lattice type
      # ------------------------------------------------------------------

      def vm_object_type(value)
        case value
        when Vm::IntegerObject then :i64
        when Vm::FloatObject   then :f64
        when Vm::ArrayObject
          elems = value.raw
          if elems.empty?
            {class: :Array}
          else
            elem_ty = elems.reduce(:unknown) { |acc, e| meet(acc, vm_object_type(e) || :unknown) }
            elem_ty == :unknown ? {class: :Array} : {class: :Array, elem: elem_ty}.freeze
          end
        when Vm::HashObject
          pairs = value.raw  # Hash<KeyWrapper, RubyObject>
          if pairs.empty?
            {class: :Hash}
          else
            key_ty = pairs.keys.reduce(:unknown)  { |acc, kw| meet(acc, vm_object_type(kw.key) || :unknown) }
            val_ty = pairs.values.reduce(:unknown) { |acc, v|  meet(acc, vm_object_type(v) || :unknown) }
            result = {class: :Hash}
            result[:key] = key_ty unless key_ty == :unknown
            result[:val] = val_ty unless val_ty == :unknown
            result.freeze
          end
        else
          class_obj  = value.respond_to?(:class_object) ? value.class_object : nil
          class_name = class_obj&.instance_variable_get(:@name)
          return nil unless class_name
          {class: class_name}
        end
      end

      # ------------------------------------------------------------------
      # Helpers
      # ------------------------------------------------------------------

      def array_new_call?(node)
        return false unless node.is_a?(Ast::MethodCall)
        return false unless node.instance_variable_get(:@name) == :new
        recv = node.instance_variable_get(:@receiver_node)
        return false unless recv.is_a?(Ast::ConstantRead) &&
                            recv.instance_variable_get(:@name) == :Array
        node.instance_variable_get(:@block_node).nil?
      end

      def each_user_instance_method(class_name, klass)
        (klass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          yield [class_name, mname], method
        end
        # Also walk eigenclass (class methods / module methods)
        eigenclass = klass.instance_variable_get(:@eigenclass)
        if eigenclass
          (eigenclass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            yield [class_name, mname], method
          end
        end
      end

      def param_index(ctx, name) = param_names_for(ctx).index(name)

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

      def method_for_key(mkey)
        if mkey.is_a?(Array)
          class_name, method_name = mkey
          klass = @user_classes[class_name]
          m = klass&.instance_variable_get(:@methods_table)&.fetch(method_name, nil)
          # Also check eigenclass for class/module methods
          m ||= klass&.instance_variable_get(:@eigenclass)&.instance_variable_get(:@methods_table)&.fetch(method_name, nil)
          m
        else
          @user_methods[mkey]
        end
      end
    end
  end
end

require_relative 'type'

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
    # join(a, b) walks the VM class hierarchy to find the LCA of two types.
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
          @typed_slots = {}  # slot → Type (only non-bottom entries)
          @ti = ti
        end

        # Legacy-compatible accessors (return old Symbol/Hash representation).
        # These are the boundary for downstream consumers that haven't migrated.
        def raw(slot)
          t = @typed_slots[slot]
          t ? t.to_legacy : :unknown
        end

        def typed?(slot) = @typed_slots.key?(slot)

        def [](slot)
          t = @typed_slots[slot]
          t ? t.to_legacy : nil
        end

        # Legacy-compatible slots hash (for callers that iterate @env.slots).
        def slots = @typed_slots.transform_values(&:to_legacy)

        # Type-native accessors (return Type objects directly).
        def type_of(slot) = @typed_slots.fetch(slot, Type::BOTTOM)
        def type_at(slot) = @typed_slots[slot]  # nil if absent (not BOTTOM)

        # Iterate all non-bottom slots yielding (slot_key, Type).
        def each_typed(&block) = @typed_slots.each(&block)

        # Join `type` into `slot`. Accepts both Type and legacy values.
        # Returns true if the slot changed.
        def join!(slot, type)
          return false unless type
          type = Type.from_legacy(type) unless type.is_a?(Type)
          return false if type.bottom?
          current = @typed_slots.fetch(slot, Type::BOTTOM)
          merged = @ti.join(current, type)
          return false if merged == current
          @typed_slots[slot] = merged
          true
        end

        def inspect = "#<TypeEnv #{@typed_slots.size} typed slots>"
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
        warn "[TI_DBG] user_methods keys: #{user_methods.keys.inspect}" if ENV['TI_DBG_USERS']
        @env = TypeEnv.new(self)
        @ancestors_cache = {}
        build_class_ancestors
      end

      attr_reader :env

      # ------------------------------------------------------------------
      # join — lattice join on Type value objects
      # ------------------------------------------------------------------

      def join(a, b)
        return b if a.bottom?
        return a if b.bottom?
        return a if a == b

        # Recursive self-reference widening: only fires when both sides are
        # the *same* parametric container (Array ∪ Array, Hash ∪ Hash) and
        # one is structurally contained in the other. That's the genuine
        # fixed-point growth cycle — `Array<Nil>` ∪ `Array<Array<Nil>>` adds
        # one wrapper layer per iteration forever without this. The cross-
        # shape case (Array ∪ Int) is a plain LCA, handled below.
        if a.class_type? && b.class_type? && a.class_name == b.class_name &&
           %i[Array Hash].include?(a.class_name) &&
           (type_contains?(a, b) || type_contains?(b, a))
          return widen_recursive(a, b)
        end

        # Bounded I64 union: keep both as I64 with widened bounds.
        # Types where one or both have nil bounds collapse to plain
        # Type::I64 (the unbounded singleton).
        if a.i64? && b.i64?
          ab, bb = a.int_bounds, b.int_bounds
          return Type::I64 unless ab && bb
          return Type.i64_bounded([ab[0], bb[0]].min, [ab[1], bb[1]].max)
        end

        # Ruby numeric widening: Int ∪ Float → Float. Without this, the
        # pair would go to lca_type(:Integer, :Float) → :Numeric, which
        # currently renders as int64_t in cpp — and a Float RHS gets
        # silently truncated through the int64_t local slot.
        return Type::F64 if (a.i64? && b.f64?) || (a.f64? && b.i64?)
        if a.class_type? && b.class_type?
          int_like = ->(n) { %i[Integer Numeric].include?(n) }
          return Type::F64 if (int_like[a.class_name] && b.class_name == :Float) ||
                              (int_like[b.class_name] && a.class_name == :Float)
        end

        # Normalise scalars/array_scalars to class types for comparison.
        if !a.class_type? || !b.class_type?
          return join(a.to_class_type, b.to_class_type)
        end

        # Both are class types.
        if a.class_name == b.class_name
          merged = a.merge_params(b)
          # merge_params returns :needs_join sentinels for params that need joining.
          resolve_param_joins(a, b, merged)
        elsif a.nil_type?
          Type.nullable(b)
        elsif b.nil_type?
          Type.nullable(a)
        else
          lca_type(a.class_name, b.class_name)
        end
      end

      # True if `needle` appears as a subterm of `haystack` (elem / key / val
      # at any depth). Used by join to detect recursive self-reference in
      # parametric class types (Array, Hash) — when one side is structurally
      # contained in the other, joining would grow the type by one wrapper
      # layer per fixed-point iteration. Guards against self-cycles via an
      # identity set on the haystack walk.
      def type_contains?(haystack, needle, seen = nil)
        return false unless haystack.is_a?(Type) && needle.is_a?(Type)
        return true if haystack == needle
        seen ||= {}
        return false if seen[haystack.object_id]
        seen[haystack.object_id] = true
        [haystack.elem, haystack.key, haystack.val].any? do |sub|
          sub && type_contains?(sub, needle, seen)
        end
      end

      # Widen a recursive self-reference to a finite fixed point. Preserves
      # the outer container shape when both sides are the same container
      # class (Array, Hash) — elem/key/val collapse to BasicObject — so
      # codegen still emits e.g. `RubyArray<RubyObject>` rather than a bare
      # boxed pointer. When the two sides have different outer classes (or
      # aren't containers at all), fall back to plain BasicObject.
      def widen_recursive(a, b)
        return Type::BASIC_OBJECT unless a.class_type? && b.class_type?
        return Type::BASIC_OBJECT unless a.class_name == b.class_name
        case a.class_name
        when :Array
          Type.array(elem: Type::BASIC_OBJECT)
        when :Hash
          Type.new(:class_type, class_name: :Hash,
                   key: Type::BASIC_OBJECT, val: Type::BASIC_OBJECT)
        else
          Type::BASIC_OBJECT
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

          # Clear expr cache between phases — call site propagation may have
          # cached :unknown for expressions that propagate_locals will type.
          @_expr_cache = {}

          # Propagate types within each method / block body.
          changed |= propagate_execute_block
          @user_methods.each do |mkey, method|
            changed |= propagate_method(mkey, method, TypeContext.new(mkey, nil))
          end

          # Clear cache again — propagate_locals may have cached :unknown for
          # params that update_call_sites has since typed.
          @_expr_cache = {}

          # Propagate ivar and instance-method types for each class.
          @user_classes.each do |cname, klass|
            changed |= propagate_ivars(cname, klass)
            each_user_instance_method(cname, klass) do |mkey, method|
              changed |= propagate_method(mkey, method, TypeContext.new(mkey, cname))
            end
          end

          break unless changed
        end

        if ENV['TI_DBG_SLOTS']
          pattern = ENV['TI_DBG_SLOTS']
          $stderr.puts "\n=== TI slots matching #{pattern.inspect} ==="
          @env.slots.sort_by { |k, _| k.inspect }.each do |k, v|
            $stderr.puts "  #{k.inspect} = #{v.inspect}" if k.to_s.include?(pattern)
          end
        end

        @env
      end

      # ------------------------------------------------------------------
      # Seed: all settled constants
      # ------------------------------------------------------------------

      def seed_constants
        @constants.each do |name, value|
          ty = vm_object_type(value)
          @env.join!([:const, name], ty) if ty
        end
      end

      # ------------------------------------------------------------------
      # update_call_sites — interprocedural param propagation
      # ------------------------------------------------------------------

      def update_call_sites(node, ctx)
        return false unless node
        changed = false
        walk(node) do |n|
          # AttributeWrite has the same receiver/name/arg_nodes shape as
          # MethodCall — `obj.foo = v` dispatches to the :foo= setter, so
          # propagate v's type into the setter's :param slot just like any
          # other call.
          next unless n.is_a?(Ast::MethodCall) || n.is_a?(Ast::AttributeWrite)
          changed |= seed_call_block_params(n, ctx) if n.is_a?(Ast::MethodCall)
          has_pos = !(n.arg_nodes || []).empty?
          has_kw = n.is_a?(Ast::MethodCall) && !(n.kw_arg_nodes || {}).empty?
          next unless has_pos || has_kw
          changed |= propagate_kw_args(n, ctx) if n.is_a?(Ast::MethodCall) && has_kw
          changed |= propagate_positional_args(n, ctx) if has_pos
        end
        changed
      end

      # Side-effect: seed iteration block params (times/each/etc) so the
      # body sees the element type. Returns false (no env update).
      def seed_call_block_params(call, ctx)
        blk = call.block_node
        return false unless blk
        ptypes = block_param_types(call.name, call.receiver_node, ctx)
        seed_block_params(blk, ptypes, ctx) unless ptypes.empty?
        false
      end

      # Propagate keyword arg literal types into the callee's
      # `:kwparam` slot. Only fires when the call's receiver shape lets
      # us name the callee unambiguously (free call or `Const.method`).
      def propagate_kw_args(call, ctx)
        kw_args = call.kw_arg_nodes || {}
        return false if kw_args.empty?
        recv = call.receiver_node
        mkey = if recv.nil?
                 call.name
               elsif recv.is_a?(Ast::ConstantRead)
                 [recv.name, call.name]
               end
        return false unless mkey
        changed = false
        kw_args.each do |kw_name_node, val_node|
          kw_sym = kw_name_node.is_a?(Ast::SymbolLiteral) ? kw_name_node.value : nil
          next unless kw_sym
          ty = infer_expr(val_node, ctx)
          changed |= @env.join!([:kwparam, mkey, kw_sym], ty) unless ty.bottom?
        end
        changed
      end

      # Propagate positional argument types into the callee's :param
      # slots. Dispatches on receiver shape: free call, ClassName.new,
      # Module.method, or instance method on a typed receiver.
      def propagate_positional_args(call, ctx)
        recv = call.receiver_node
        if recv.nil?
          propagate_free_call_args(call, ctx)
        elsif constant_ref?(recv) && call.name == :new
          propagate_constructor_args(call, ctx, recv.name)
        elsif constant_ref?(recv) && (@user_classes.key?(recv.name) || @user_methods.key?(call.name))
          # `Module.method(...)` for a user-defined module method → flat-keyed
          # :param slot (collect_module_methods_for_ti flattens by simple name).
          # Fall back to [class, name] for genuine class methods.
          propagate_class_method_args(call, ctx, [recv.name, call.name])
        elsif recv
          propagate_instance_method_args(call, ctx)
        else
          false
        end
      end

      # Is `node` a constant reference (bare ConstantRead or nested
      # ConstantPath like `Outer::Inner::Holder`)? Both have `.name` (the
      # leaf) which is how @user_classes is indexed.
      def constant_ref?(node)
        node.is_a?(Ast::ConstantRead) || node.is_a?(Ast::ConstantPath)
      end

      # Free call → top-level method params (and the class-keyed
      # slot when inside a class method, since a "free" call there
      # is actually a class method call).
      def propagate_free_call_args(call, ctx)
        changed = false
        (call.arg_nodes || []).each_with_index do |arg, i|
          ty = infer_expr(arg, ctx)
          next if ty.bottom?
          changed |= @env.join!([:param, call.name, i], ty)
          changed |= @env.join!([:param, [ctx.class_name, call.name], i], ty) if ctx.class_name
        end
        changed
      end

      # ClassName.new(...) → constructor params, keyed by calling
      # context for the 1-CFA constructor specialisation.
      def propagate_constructor_args(call, ctx, class_sym)
        ctor_ctx = ctx.method_key || :__execute__
        changed = false
        (call.arg_nodes || []).each_with_index do |arg, i|
          ty = infer_expr(arg, ctx)
          changed |= @env.join!([:constructor_param, class_sym, i, ctor_ctx], ty) unless ty.bottom?
        end
        changed
      end

      # Module.method(...) → class method params keyed by [class, name]…
      # except for module methods that `collect_module_methods_for_ti`
      # flattened into @user_methods under their bare name, in which case
      # the :param slot is keyed by the bare name. Fall back to [class, name]
      # for genuine class methods (e.g. struct class methods).
      def propagate_class_method_args(call, ctx, mkey)
        changed = false
        effective_key = mkey.is_a?(Array) && @user_methods.key?(mkey[1]) ? mkey[1] : mkey
        (call.arg_nodes || []).each_with_index do |arg, i|
          ty = infer_expr(arg, ctx)
          changed |= @env.join!([:param, effective_key, i], ty) unless ty.bottom?
        end
        changed
      end

      # Instance method call on a typed receiver → propagate args to
      # the receiver class's instance-method param slots.
      def propagate_instance_method_args(call, ctx)
        recv_ty = infer_expr(call.receiver_node, ctx)
        return false unless recv_ty.class_type?
        mkey = [recv_ty.class_name, call.name]
        changed = false
        (call.arg_nodes || []).each_with_index do |arg, i|
          ty = infer_expr(arg, ctx)
          changed |= @env.join!([:param, mkey, i], ty) unless ty.bottom?
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
        (method.optional_kw_params || []).each do |kw_name, default_node|
          next unless default_node
          ty = infer_expr(default_node, ctx)
          changed |= @env.join!([:kwparam, mkey, kw_name], ty) unless ty.bottom?
        end
        # Array locals first so scalar locals that depend on array reads are typed.
        changed |= propagate_array_locals(method.body, ctx)
        # For-loop target variables (typed like block params to reflect Crystal level).
        changed |= propagate_for_targets(method.body, ctx)
        changed |= propagate_locals(method.body, ctx)
        changed |= propagate_masgn_from_calls(method.body, ctx)
        ret_ty = infer_body_return(method.body, ctx)
        warn "[TI_DBG] propagate_method #{mkey.inspect}: ret=#{ret_ty.inspect}" if ENV['TI_DBG_USERS'] && mkey == :sd_solve
        changed |= @env.join!([:return, mkey], ret_ty) unless ret_ty.bottom?
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
            ty = rhs_nodes.reduce(Type::BOTTOM) do |acc, rhs|
              join(acc, infer_expr(rhs, ctx))
            end
            next if ty.bottom?
            # Drop integer bounds before storing into a :local slot.
            # Without proper loop-bound analysis (see docs/int-soundness.md)
            # the bounds at any reach of a loop-carried local would be
            # unsound — we'd compute "x = 0 then x += 1" as x having
            # bounds [0,1], but downstream a `arr << x` site would
            # incorrectly believe arr's elem fits in UInt8. Storage
            # narrowing is not safe in that direction. Locals therefore
            # always store as plain Type::I64 even when the joined RHS
            # would be bounded; the per-expression bounds tracking
            # still works for literals and pure arithmetic chains
            # within a single statement, which is where storage
            # narrowing of constants gets its win from.
            ty = strip_int_bounds(ty)
            iter_changed |= @env.join!([:local, ctx.method_key, name], ty)
          end
          changed |= iter_changed
          break unless iter_changed
        end
        changed
      end

      # Recursively replace any bounded :i64 type in `ty` with the
      # unbounded Type::I64 singleton. Used by propagate_locals to
      # keep bounds out of local-variable slots until loop-bound
      # analysis is in place.
      def strip_int_bounds(ty)
        return ty unless ty.is_a?(Type)
        return Type::I64 if ty.i64? && ty.int_bounds
        if ty.array? && ty.elem
          new_elem = strip_int_bounds(ty.elem)
          return Type.array(elem: new_elem) if new_elem != ty.elem
        end
        ty
      end

      # When a multiple assignment destructures a function return (mr, mc = foo()),
      # trace through the function's body to find what each return-array element's
      # type is, and propagate to the local targets.
      def propagate_masgn_from_calls(body, ctx)
        changed = false
        walk(body) do |node|
          next unless node.is_a?(Ast::MultipleAssignment)
          targets = node.targets || []
          value = node.value_node
          next unless value.is_a?(Ast::MethodCall) && value.receiver_node.nil?
          method_name = value.name
          method = @user_methods[method_name]
          next unless method
          # Find the return expression — walk method body for the last expression
          ret_node = last_expression(method.body)
          next unless ret_node.is_a?(Ast::ArrayLiteral)
          ret_elems = ret_node.element_nodes || []
          # Map each element's type to the corresponding target local
          targets.each_with_index do |t, i|
            next unless t[0] == :local && ret_elems[i]
            # Infer the return element's type in the CALLED method's context
            callee_ctx = TypeContext.new(method_name, nil)
            elem_ty = infer_expr(ret_elems[i], callee_ctx)
            next if elem_ty.bottom?
            changed |= @env.join!([:local, ctx.method_key, t[1]], elem_ty)
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
          args = rhs.arg_nodes || []
          next unless args.size == 2
          fill_ty = infer_expr(args[1], ctx)
          next unless fill_ty.raw?

          next if escapes?(name, body, ctx) && !escapes_only_via_return_array?(name, body)
          next unless writes_consistent?(name, body, ctx, fill_ty)

          changed |= @env.join!([:array_elem, ctx.method_key, name], fill_ty)
        end

        # Infer element types from push operations (<<, push, []=) on array locals.
        # Only promote when ALL writes to the array's elements are consistently typed.
        elem_writes = @_elem_write_cache[ctx.method_key] ||= collect_array_elem_writes(body)
        elem_writes.each do |key, value_nodes|
          # Direct writes: arr << val, arr[i] = val
          if key.is_a?(Symbol)
            next if param_names.include?(key)
            types = value_nodes.map { |v| infer_expr(v, ctx) }
            next unless types.all?(&:raw?)
            unique = types.uniq
            next unless unique.size == 1
            changed |= @env.join!([:array_elem, ctx.method_key, key], unique[0])
          elsif key.is_a?(Array) && key[0] == :sub
            arr_name = key[1]
            types = value_nodes.map { |v| infer_expr(v, ctx) }
            next unless types.all?(&:raw?)
            unique = types.uniq
            next unless unique.size == 1
            local_ty = @env.type_of([:local, ctx.method_key, arr_name])
            if local_ty.array?
              inner = Type.array(elem: unique[0])
              changed |= @env.join!([:local, ctx.method_key, arr_name], Type.array(elem: inner))
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
          args = node.arg_nodes || []
          recv = node.receiver_node
          if (node.name == :<< || node.name == :push) && args.size == 1
            if recv.is_a?(Ast::LocalVariableRead)
              result[recv.name] << args[0]
            elsif recv.is_a?(Ast::MethodCall) && recv.name == :[] &&
                  recv.receiver_node.is_a?(Ast::LocalVariableRead)
              # arr[i] << val — val is an elem of arr's sub-arrays
              # Store with a [:sub, name] key to distinguish from direct writes
              result[[:sub, recv.receiver_node.name]] << args[0]
            end
          end
          # Recurse into children
          collect_array_elem_writes(recv, result, depth: depth)
          args.each { |a| collect_array_elem_writes(a, result, depth: depth) }
          blk = node.block_node
          collect_array_elem_writes(blk.body, result, depth: depth) if blk.is_a?(Ast::Block)
        when Ast::AttributeWrite
          if node.name == :[]=
            recv = node.receiver_node
            args = node.arg_nodes || []
            if recv.is_a?(Ast::LocalVariableRead) && args.size == 2
              result[recv.name] << args[1]
            end
          end
        when Ast::Sequence
          node.nodes.each { |n| collect_array_elem_writes(n, result, depth: depth) }
        when Ast::If
          collect_array_elem_writes(node.then_node, result, depth: depth)
          collect_array_elem_writes(node.else_node, result, depth: depth)
        when Ast::While, Ast::Until
          collect_array_elem_writes(node.body_node, result, depth: depth)
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
          target = node.target
          next unless target[0] == :local
          name = target[1]
          coll_node = node.collection_node
          coll_ty = infer_expr(coll_node, ctx)
          elem_ty = for_loop_elem_type(coll_ty)
          next if elem_ty.nil? || elem_ty.bottom?
          changed |= @env.join!([:block_param, ctx.method_key, name], elem_ty)
        end
        changed
      end

      def for_loop_elem_type(coll_ty)
        return Type::I64 if coll_ty.class_type? && coll_ty.class_name == :Range
        return coll_ty.elem if coll_ty.array? && coll_ty.elem
        nil
      end

      # ------------------------------------------------------------------
      # propagate_ivars — infer ivar types from initialize body
      # ------------------------------------------------------------------

      def propagate_ivars(class_name, klass)
        init = (klass.methods_table || {})[:initialize]
        return false unless init.is_a?(Vm::Method) && init.body

        req_params = init.required_params || []
        param_types = req_params.empty? ? [] : best_constructor_param_types(class_name, req_params.size)
        return false unless param_types

        old_seeds = @ivar_param_seeds
        @ivar_param_seeds = req_params.zip(param_types).to_h
        changed = false
        changed |= seed_constructor_params(class_name, param_types)
        changed |= propagate_ivars_from_initialize(class_name, init)
        changed |= propagate_ivars_from_other_methods(class_name, klass)
        changed |= propagate_ivars_from_setter_calls(class_name, klass)
        changed |= propagate_ivar_array_elem_writes(class_name, klass)
        changed |= widen_ivar_arrays_from_mutations(class_name, klass)
        changed |= widen_scalar_ivars_from_mutations(class_name, klass)
        changed |= seed_setter_params_from_ivars(class_name, klass)
        changed
      ensure
        @ivar_param_seeds = old_seeds if defined?(old_seeds)
      end

      # For each setter method `foo=(v)`, seed the :param slot's type from
      # the ivar `@foo`'s type. Covers attr_writer-synthesised and hand-
      # written setters that have no external call sites (otherwise
      # update_call_sites would populate :param via the caller). Without
      # this, an attr_accessor-generated `levar=` that's never explicitly
      # called via `obj.levar = v` has a BOTTOM param slot → BOTTOM return,
      # which strict-TI emission rejects.
      def seed_setter_params_from_ivars(class_name, klass)
        changed = false
        (klass.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method)
          next unless mname.to_s.end_with?('=')
          req = method.required_params || []
          next unless req.size == 1
          ivar_sym = :"@#{mname.to_s.chomp('=')}"
          iv_ty = @env.type_of([:ivar, class_name, ivar_sym])
          next if iv_ty.bottom?
          changed |= @env.join!([:param, [class_name, mname], 0], iv_ty)
        end
        changed
      end

      # Seed the initialize param slots from the best-known constructor
      # call site types. Returns whether any slot type widened.
      def seed_constructor_params(class_name, param_types)
        changed = false
        param_types.each_with_index do |ty, i|
          changed |= @env.join!([:param, [class_name, :initialize], i], ty) unless ty.bottom?
        end
        changed
      end

      # Walk the initialize body and join each `@ivar = ...` RHS into
      # the global ivar type slot for the class.
      def propagate_ivars_from_initialize(class_name, init)
        ctx = TypeContext.new([class_name, :initialize], class_name)
        changed = false
        collect_ivar_assignments(init.body).each do |ivar_name, rhs_nodes|
          ty = rhs_nodes.reduce(Type::BOTTOM) { |acc, rhs| join(acc, infer_expr(rhs, ctx)) }
          next if ty.bottom?
          changed |= @env.join!([:ivar, class_name, ivar_name], ty)
        end
        changed
      end

      # Ivars may be assigned outside initialize (e.g. `@root = Node.new`
      # in an insert method). Walk every other instance method and
      # propagate their `@ivar = ...` assignments too.
      def propagate_ivars_from_other_methods(class_name, klass)
        changed = false
        (klass.methods_table || {}).each do |mname, method|
          next if mname == :initialize || !method.is_a?(Vm::Method) || !method.body
          method_ctx = TypeContext.new([class_name, mname], class_name)
          collect_ivar_assignments(method.body).each do |ivar_name, rhs_nodes|
            rhs_nodes.each do |rhs|
              ty = infer_expr(rhs, method_ctx)
              next if ty.nil? || ty.bottom?
              changed |= @env.join!([:ivar, class_name, ivar_name], ty)
            end
          end
        end
        changed
      end

      # Setter calls (`obj.left = val`) on instances of this class show
      # up as method calls in other methods, but their effect on the
      # ivar type lattice is the same as `@left = val`. Walk all user
      # methods and feed any setter targets back into the ivar slot.
      def propagate_ivars_from_setter_calls(class_name, klass)
        accessor_names = Set.new
        (klass.methods_table || {}).each_key do |mn|
          accessor_names << mn.to_s.chomp('=').to_sym if mn.to_s.end_with?('=') && mn != :initialize
        end
        return false if accessor_names.empty?

        changed = false
        each_user_method do |mkey, method|
          next unless method.body
          method_ctx = TypeContext.new(mkey, mkey.is_a?(Array) ? mkey[0] : nil)
          collect_setter_calls(method.body, class_name, accessor_names, method_ctx) do |attr_name, ty|
            changed |= @env.join!([:ivar, class_name, :"@#{attr_name}"], ty)
          end
        end
        changed
      end

      # Ivar array element-type inference: `@list[i] = val` in any method
      # contributes `val`'s type to `@list`'s elem type, refining
      # untyped Array slots to Array(T).
      def propagate_ivar_array_elem_writes(class_name, klass)
        changed = false
        (klass.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          method_ctx = TypeContext.new([class_name, mname], class_name)
          collect_ivar_array_elem_writes(method.body, class_name, method_ctx) do |ivar_name, elem_ty|
            # Skip ivars already widened by mutation soundness check
            next if (@_widened_array_ivars ||= Set.new).include?([class_name, ivar_name])
            current = @env.type_of([:ivar, class_name, ivar_name])
            if current.array? && !current.elem
              changed |= @env.join!([:ivar, class_name, ivar_name], Type.array(elem: elem_ty))
            end
          end
        end
        changed
      end

      # Soundness check: if any method pushes/appends a non-raw value to
      # an array ivar, widen it back to generic Array. Prevents incorrect
      # Array(Int64) specialisation when the array also holds RubyObject.
      # Array mutation methods that add elements (must agree on element type
      # for specialisation to be sound).
      ARRAY_MUTATE_METHODS = %i[<< push append unshift prepend concat insert fill].to_set

      def widen_ivar_arrays_from_mutations(class_name, klass)
        changed = false
        (klass.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          method_ctx = TypeContext.new([class_name, mname], class_name)
          collect_ivar_array_mutations(method.body, method_ctx) do |ivar_name, val_ty|
            # Once widened, don't re-narrow (survives across TI iterations)
            widened_key = [class_name, ivar_name]
            next if (@_widened_array_ivars ||= Set.new).include?(widened_key)
            current = @env.type_of([:ivar, class_name, ivar_name])
            next unless current.array?
            # Value is not raw → the array can't be specialised
            unless val_ty.raw? || (val_ty.class_type? && %i[Integer Float].include?(val_ty.class_name))
              @_widened_array_ivars << widened_key
              changed |= @env.join!([:ivar, class_name, ivar_name], Type::ARRAY)
            end
          end
        end
        changed
      end

      # Soundness check for scalar ivars: if any non-constructor method
      # writes a non-raw value (or no value info) to a scalar ivar, the
      # ivar can't be safely typed as Int64/Float64. Widen to generic.
      # Soundness check for scalar ivars: if any non-constructor method
      # writes a non-raw value to a scalar-typed ivar, widen it. This
      # catches cases like Racc's _racc_init_sysvars writing boxed 0
      # to an ivar that constructor analysis typed as Int64.
      def widen_scalar_ivars_from_mutations(class_name, klass)
        changed = false
        (klass.methods_table || {}).each do |mname, method|
          next if mname == :initialize
          next unless method.is_a?(Vm::Method) && method.body
          method_ctx = TypeContext.new([class_name, mname], class_name)
          collect_ivar_typed_writes(method.body, method_ctx) do |ivar_name, val_ty|
            widened_key = [:scalar, class_name, ivar_name]
            next if (@_widened_array_ivars ||= Set.new).include?(widened_key)
            current = @env.type_of([:ivar, class_name, ivar_name])
            next unless current.raw?
            # Value is not raw and not bottom → ivar can't be scalar-typed
            next if val_ty.raw? || val_ty.bottom?
            @_widened_array_ivars << widened_key
            changed |= @env.join!([:ivar, class_name, ivar_name], Type::BOTTOM)
          end
        end
        changed
      end

      # Yield [ivar_name, value_type] for InstanceVariableWrite nodes.
      def collect_ivar_typed_writes(node, ctx, &block)
        return unless node
        if node.is_a?(Ast::InstanceVariableWrite)
          val_ty = infer_expr(node.value_node, ctx)
          yield node.name, val_ty
        end
        node.children.each { |c| collect_ivar_typed_writes(c, ctx, &block) if c.is_a?(Ast::Node) }
      end

      # Scan body for @ivar.<<(val) / @ivar.push(val) etc. patterns.
      # Yields [ivar_name, value_type] for each mutation found.
      def collect_ivar_array_mutations(node, ctx, &block)
        return unless node
        if node.is_a?(Ast::MethodCall) && ARRAY_MUTATE_METHODS.include?(node.name)
          recv = node.receiver_node
          args = node.arg_nodes || []
          if recv.is_a?(Ast::InstanceVariableRead) && !args.empty?
            ivar_name = recv.name
            args.each do |arg|
              val_ty = infer_expr(arg, ctx)
              # Yield for ALL values including bottom — if we can't
              # determine the type, the array can't be safely specialised.
              yield ivar_name, val_ty
            end
          end
        end
        node.children.each { |c| collect_ivar_array_mutations(c, ctx, &block) }
      end

      # Iterate every user-defined method (top-level + instance methods
      # on every user class). Yields [mkey, method].
      def each_user_method(&block)
        @user_methods.each(&block)
        @user_classes.each do |cname, ck|
          (ck.methods_table || {}).each do |mn, m|
            yield [[cname, mn], m] if m.is_a?(Vm::Method)
          end
        end
      end

      # Scan body for @ivar[i] = val patterns and yield ivar_name + value type.
      def collect_ivar_array_elem_writes(node, class_name, ctx, &block)
        return unless node
        if node.is_a?(Ast::AttributeWrite) && node.name == :[]=
          recv = node.receiver_node
          args = node.arg_nodes || []
          if recv.is_a?(Ast::InstanceVariableRead) && args.size == 2
            ivar_name = recv.name
            val_ty = infer_expr(args[1], ctx)
            # Accept raw numerics and boxed Float/Integer (unbox to raw)
            unless val_ty.bottom?
              raw = if val_ty.raw? then val_ty
                    elsif val_ty.class_type? && val_ty.class_name == :Float then Type::F64
                    elsif val_ty.class_type? && val_ty.class_name == :Integer then Type::I64
                    end
              yield ivar_name, raw if raw
            end
          end
        end
        node.children.each { |c| collect_ivar_array_elem_writes(c, class_name, ctx, &block) }
      end

      # Walk body for setter calls (obj.attr= val) on known-class receivers.
      def collect_setter_calls(node, class_name, accessor_names, ctx, &block)
        return unless node
        if node.is_a?(Ast::AttributeWrite)
          name_sym = node.name
          attr = name_sym.to_s.chomp('=').to_sym
          if accessor_names.include?(attr)
            recv = node.receiver_node
            recv_cls = nil
            if recv.is_a?(Ast::LocalVariableRead)
              recv_ty = @env.type_of([:local, ctx.method_key, recv.name])
              recv_cls = recv_ty.class_name if recv_ty.class_type?
            end
            if recv_cls == class_name
              args = node.arg_nodes || []
              if args[0]
                ty = infer_expr(args[0], ctx)
                block.call(attr, ty) unless ty.bottom?
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
        return Type::BOTTOM unless node
        cache_key = [node, ctx.method_key]
        return @_expr_cache[cache_key] if @_expr_cache.key?(cache_key)
        result = infer_expr_uncached(node, ctx)
        @_expr_cache[cache_key] = result
      end

      def infer_expr_uncached(node, ctx)
        case node
        when Ast::IntegerLiteral
          v = node.value.respond_to?(:raw) ? node.value.raw : node.value
          v.is_a?(Integer) ? Type.i64_bounded(v, v) : Type::I64
        when Ast::FloatLiteral          then Type::F64
        when Ast::NilLiteral            then Type::NIL_CLASS
        when Ast::TrueLiteral           then Type::TRUE_CLASS
        when Ast::FalseLiteral          then Type::FALSE_CLASS
        when Ast::StringLiteral         then Type::STRING
        when Ast::SymbolLiteral         then Type::SYMBOL
        when Ast::RangeLiteral          then Type::RANGE
        when Ast::RegexpLiteral         then Type::REGEXP
        when Ast::ArrayLiteral          then infer_array_literal_type(node, ctx)
        when Ast::HashLiteral           then infer_hash_literal_type(node, ctx)
        when Ast::Sequence              then infer_expr(node.nodes.last, ctx)
        when Ast::LocalVariableRead     then infer_local_var_type(node, ctx)
        when Ast::InstanceVariableRead  then @env.type_of([:ivar, ctx.class_name, node.name])
        when Ast::ConstantRead          then @env.type_of([:const, node.name])
        when Ast::LocalVariableWrite    then infer_expr(node.value_node, ctx)
        when Ast::InstanceVariableWrite then infer_expr(node.value_node, ctx)
        when Ast::ClassVariableWrite    then infer_expr(node.value_node, ctx)
        when Ast::AttributeWrite        then infer_expr(node.arg_nodes.last, ctx) # obj.foo = v / obj[i] = v — the written value is always the last arg
        when Ast::If                    then infer_if_type(node, ctx)
        when Ast::MethodCall            then infer_call(node, ctx)
        when Ast::Or                    then infer_short_circuit_type(node, ctx)
        when Ast::And                   then infer_short_circuit_type(node, ctx)
        else                                 Type::BOTTOM
        end
      end

      # Element-wise join over the literal's elements; empty literal
      # falls back to the unspecialised Type::ARRAY.
      def infer_array_literal_type(node, ctx)
        # Tree-node literal: `[nil, nil]` or `[f(x), f(x)]` with 2 entries,
        # each a NilLiteral or a free MethodCall. Codegen special-cases this
        # as `RubyTree(left, right)` — a dedicated 2-child heap node —
        # because the recursive shape can't be expressed as a finite
        # RubyArray type. Mirror that here so TI's return types match.
        return Type.of(:Tree) if tree_node_literal?(node)
        elems = node.element_nodes || []
        return Type::ARRAY if elems.empty?
        elem_ty = elems.reduce(Type::BOTTOM) { |acc, e| join(acc, infer_expr(e, ctx)) }
        elem_ty.bottom? ? Type::ARRAY : Type.array(elem: elem_ty)
      end

      def tree_node_literal?(node)
        elems = node.element_nodes || []
        return false unless elems.size == 2
        elems.all? do |e|
          e.is_a?(Ast::NilLiteral) ||
            (e.is_a?(Ast::MethodCall) && e.receiver_node.nil?)
        end
      end

      # Element-wise joins over keys and values; empty hash falls back
      # to the unspecialised Type::HASH.
      def infer_hash_literal_type(node, ctx)
        pairs = node.kv_nodes || []
        return Type::HASH if pairs.empty?
        key_ty = pairs.reduce(Type::BOTTOM) { |acc, (k, _)| join(acc, infer_expr(k, ctx)) }
        val_ty = pairs.reduce(Type::BOTTOM) { |acc, (_, v)| join(acc, infer_expr(v, ctx)) }
        Type.hash_type(
          key: key_ty.bottom? ? nil : key_ty,
          val: val_ty.bottom? ? nil : val_ty
        )
      end

      # Local variable type — checks ivar-derived seed (Frozone-specific
      # init-param tracking), then positional params, kwparams, block
      # params, and finally the per-method local map.
      def infer_local_var_type(node, ctx)
        name = node.name
        return @ivar_param_seeds[name] if @ivar_param_seeds&.key?(name)
        idx = param_index(ctx, name)
        if idx
          pv = @env.type_of([:param, ctx.method_key, idx])
          return pv unless pv.bottom?
        end
        kp = @env.type_of([:kwparam, ctx.method_key, name])
        return kp unless kp.bottom?
        bp = @env.type_of([:block_param, ctx.method_key, name])
        return bp unless bp.bottom?
        @env.type_of([:local, ctx.method_key, name])
      end

      # If/else result type: join of both arms; one-armed if implicitly
      # has nil as the else value.
      def infer_if_type(node, ctx)
        t = infer_expr(node.then_node, ctx)
        e_ty = node.else_node ? infer_expr(node.else_node, ctx) : Type::NIL_CLASS
        return t if e_ty.bottom?
        return e_ty if t.bottom?
        join(t, e_ty)
      end

      # `&&` and `||` are identical at the type level — both yield the
      # join of the two operand types, with bottoms eliminated.
      def infer_short_circuit_type(node, ctx)
        lt = infer_expr(node.left_node, ctx)
        rt = infer_expr(node.right_node, ctx)
        return rt if lt.bottom?
        return lt if rt.bottom?
        join(lt, rt)
      end

      # ------------------------------------------------------------------
      # infer_call — type inference for method calls
      # ------------------------------------------------------------------

      # Math module methods that always return Float.
      MATH_FLOAT_METHODS = %i[sqrt cbrt exp log log2 log10 sin cos tan asin acos atan atan2
                               sinh cosh tanh asinh acosh atanh hypot ldexp frexp].to_set

      # Built-in methods on Array/Integer/Float with known return types.
      ARRAY_INT_METHODS = %i[length size count].to_set
      INT_INT_METHODS = %i[abs ceil floor round truncate times upto downto].to_set
      FLOAT_FLOAT_METHODS = %i[abs].to_set
      FLOAT_INT_METHODS = %i[ceil floor round truncate].to_set
      # Explicit coercion methods: always return a known numeric type.
      COERCE_TO_FLOAT = %i[to_f to_f64 to_r].to_set
      COERCE_TO_INT = %i[to_i to_i64 to_int].to_set

      # Top-level dispatcher: walk a chain of try_infer_* helpers, each
      # of which returns either a Type or nil. The first non-nil result
      # wins. Block-param seeding is the only side effect that has to
      # run regardless, so it sits between the array/map factory cases
      # (which need block return inference *before* seeding the
      # surrounding context) and everything else.
      def infer_call(node, ctx)
        result = try_infer_array_factory(node, ctx) ||
                 try_infer_map_factory(node, ctx)
        return result if result

        seed_iteration_block_params(node, ctx)

        try_infer_class_new(node, ctx) ||
          try_infer_math_call(node, ctx) ||
          try_infer_subscript_read(node, ctx) ||
          try_infer_range_to_a(node, ctx) ||
          try_infer_builtin_method(node, ctx) ||
          try_infer_arith_op(node, ctx) ||
          try_infer_max_min_two_arg(node, ctx) ||
          try_infer_class_method_call(node, ctx) ||
          try_infer_instance_method_call(node, ctx) ||
          try_infer_free_call(node, ctx) ||
          Type::BOTTOM
      end

      # Array.new(n) { |i| expr } or Array.new(n, fill) or Array.new(n).
      # Size-only (no block, no fill) yields an untyped Array whose elements
      # start as nil — the element type gets refined by subsequent writes
      # via propagate_ivar_array_elem_writes / widen_ivar_arrays_from_mutations.
      def try_infer_array_factory(node, ctx)
        return nil unless node.name == :new
        recv = node.receiver_node
        return nil unless recv.is_a?(Ast::ConstantRead) && recv.name == :Array
        blk = node.block_node
        args = node.arg_nodes || []
        if blk
          elem_ty = infer_block_return(blk, [Type::I64], ctx)
          return elem_ty.bottom? ? Type::ARRAY : Type.array(elem: elem_ty)
        elsif args.size == 2
          fill_ty = infer_expr(args[1], ctx)
          return fill_ty.bottom? ? Type::ARRAY : Type.array(elem: fill_ty)
        elsif args.size == 1
          Type::ARRAY
        end
      end

      # Array#map { |x| expr } → new Array with block-inferred element type.
      def try_infer_map_factory(node, ctx)
        return nil unless node.name == :map && node.block_node && node.receiver_node
        recv_ty = infer_expr(node.receiver_node, ctx)
        return nil unless recv_ty.array?
        elem_in = recv_ty.elem || Type::BOTTOM
        elem_out = infer_block_return(node.block_node, [elem_in], ctx)
        elem_out.bottom? ? Type::ARRAY : Type.array(elem: elem_out)
      end

      # Side-effect: seed block params for common iteration methods so
      # the body's local types pick up the element type.
      def seed_iteration_block_params(node, ctx)
        return unless node.block_node
        ptypes = block_param_types(node.name, node.receiver_node, ctx)
        seed_block_params(node.block_node, ptypes, ctx) unless ptypes.empty?
      end

      # ClassName.new(...) → class instance type.
      def try_infer_class_new(node, ctx)
        return nil unless node.name == :new
        recv = node.receiver_node
        recv.is_a?(Ast::ConstantRead) ? Type.of(recv.name) : nil
      end

      # Math.method(...) → always Float64.
      def try_infer_math_call(node, ctx)
        recv = node.receiver_node
        return nil unless recv.is_a?(Ast::ConstantRead) && recv.name == :Math
        MATH_FLOAT_METHODS.include?(node.name) ? Type::F64 : nil
      end

      # Array element read recv[k].
      def try_infer_subscript_read(node, ctx)
        args = node.arg_nodes || []
        return nil unless node.name == :[] && args.size == 1
        recv = node.receiver_node
        if recv.is_a?(Ast::LocalVariableRead)
          ae = @env.type_of([:array_elem, ctx.method_key, recv.name])
          return ae unless ae.bottom?
        end
        recv_ty = infer_expr(recv, ctx)
        recv_ty.array? && recv_ty.elem ? recv_ty.elem : nil
      end

      # Range#to_a → Array with endpoint element type.
      def try_infer_range_to_a(node, ctx)
        return nil unless node.name == :to_a || node.name == :to_ary
        unwrapped = node.receiver_node
        unwrapped = unwrapped.nodes.first while unwrapped.is_a?(Ast::Sequence) && unwrapped.nodes.size == 1
        return nil unless unwrapped.is_a?(Ast::RangeLiteral)
        begin_ty = infer_expr(unwrapped.begin_node, ctx)
        begin_ty.raw? ? Type.array(elem: begin_ty) : Type::ARRAY
      end

      # Built-in methods with known return types on a typed receiver.
      def try_infer_builtin_method(node, ctx)
        recv = node.receiver_node
        return nil unless recv
        name = node.name
        recv_ty = infer_expr(recv, ctx)
        return Type::F64 if COERCE_TO_FLOAT.include?(name) && !recv_ty.bottom?
        return Type::I64 if COERCE_TO_INT.include?(name) && !recv_ty.bottom?
        # Integer methods (times/upto/abs/etc.) — accept either a boxed
        # :Integer class type or the unboxed :i64 kind as the receiver.
        if (recv_ty.i64? || (recv_ty.class_type? && recv_ty.class_name == :Integer)) &&
           INT_INT_METHODS.include?(name)
          return Type::I64
        end
        if (recv_ty.f64? || (recv_ty.class_type? && recv_ty.class_name == :Float)) &&
           FLOAT_FLOAT_METHODS.include?(name)
          return Type::F64
        end
        if (recv_ty.f64? || (recv_ty.class_type? && recv_ty.class_name == :Float)) &&
           FLOAT_INT_METHODS.include?(name)
          return Type::I64
        end
        if recv_ty.class_type?
          cn = recv_ty.class_name
          return Type::I64 if cn == :Array   && ARRAY_INT_METHODS.include?(name)
          return Type::I64 if cn == :String  && %i[getbyte ord bytesize size length setbyte].include?(name)
          return Type::STRING if cn == :String && %i[b upcase downcase capitalize reverse chomp chop strip lstrip rstrip].include?(name)
          # "str" * n → String; "str" + "s" → String.
          if cn == :String && (name == :* || name == :+) && (node.arg_nodes || []).size == 1
            return Type::STRING
          end
          # "str"[from, len] → String (two-arg slice).
          return Type::STRING if cn == :String && name == :[] && (node.arg_nodes || []).size == 2
          # "str".slice / .dup are both String-returning (dup/clone already handled below,
          # but slice needs an explicit entry).
          return Type::STRING if cn == :String && name == :slice
          return ((node.arg_nodes || []).empty? ? Type::F64 : Type::I64) if cn == :Random && name == :rand
        end
        # Array accessors that return an element: max/min/sum/first/last
        # plus fetch / at / [].
        if recv_ty.array? && recv_ty.elem && %i[max min sum first last fetch at [] pop shift].include?(name)
          return recv_ty.elem
        end
        # dup/clone/freeze return the same type.
        return recv_ty if !recv_ty.bottom? && (name == :dup || name == :clone || name == :freeze)
        nil
      end

      # Arithmetic / bitwise — Ruby-semantic result type.
      def try_infer_arith_op(node, ctx)
        args = node.arg_nodes || []
        recv = node.receiver_node
        return nil unless recv
        # Unary `-@` / `+@` (Ruby parses `-x` as `x.-@`, zero args). Return
        # the receiver's numeric type.
        if args.empty? && (node.name == :-@ || node.name == :+@)
          rt = infer_expr(recv, ctx)
          return rt if rt.f64? || rt.i64?
          return nil
        end
        return nil unless ARITH_OPS.include?(node.name) && args.size == 1
        rt = infer_expr(recv, ctx)
        at = infer_expr(args[0], ctx)
        return Type::BOTTOM if rt.bottom? || at.bottom?
        if rt.raw? && at.raw?
          return Type::F64 if rt.f64? || at.f64?
          # Both Int64 — try to propagate bounds.
          return propagate_int_bounds(node.name, rt, at)
        end
        # Numeric × numeric or anything else → unknown specific type;
        # Type::BOTTOM is a *result*, not a "no match", so return it.
        Type::BOTTOM
      end

      # Compute the integer bounds of `lhs op rhs` for the bitwise /
      # arithmetic operators we currently track. Returns plain
      # Type::I64 (unbounded) when bounds aren't tracked on either
      # side, when the operator's bounds are unknown, or when the
      # result would overflow Int64.
      def propagate_int_bounds(op, lhs, rhs)
        a = lhs.int_bounds
        b = rhs.int_bounds
        return Type::I64 unless a && b
        amin, amax = a
        bmin, bmax = b
        result = case op
                 when :+ then [amin + bmin, amax + bmax]
                 when :- then [amin - bmax, amax - bmin]
                 when :*
                   corners = [amin * bmin, amin * bmax, amax * bmin, amax * bmax]
                   [corners.min, corners.max]
                 when :%
                   # x % n where n > 0 → [0, n-1]; conservative otherwise.
                   bmin > 0 ? [0, bmax - 1] : nil
                 when :&
                   # Both non-negative: result ≤ min(amax, bmax).
                   (amin >= 0 && bmin >= 0) ? [0, [amax, bmax].min] : nil
                 when :|
                   # Both non-negative: result ≤ next_pow2(max(amax, bmax)) - 1.
                   if amin >= 0 && bmin >= 0
                     hi = [amax, bmax].max
                     # Round up to all-ones below the next power of two.
                     bits = hi == 0 ? 0 : Math.log2(hi).to_i + 1
                     [[amin, bmin].max, (1 << bits) - 1]
                   end
                 when :^
                   if amin >= 0 && bmin >= 0
                     hi = [amax, bmax].max
                     bits = hi == 0 ? 0 : Math.log2(hi).to_i + 1
                     [0, (1 << bits) - 1]
                   end
                 when :<<
                   # x << n: only safe when n is a small constant and
                   # both bounds are non-negative.
                   if bmin == bmax && bmin >= 0 && bmin < 63 && amin >= 0
                     [amin << bmin, amax << bmin]
                   end
                 when :>>
                   if bmin == bmax && bmin >= 0 && bmin < 63 && amin >= 0
                     [amin >> bmin, amax >> bmin]
                   end
                 end
        return Type::I64 if result.nil?
        new_min, new_max = result
        # Overflow guard: drop to unbounded if either bound escapes Int64.
        return Type::I64 if new_min < -(2**63) || new_max > 2**63 - 1
        Type.i64_bounded(new_min, new_max)
      end

      # max/min with 2 args: return the wider numeric type.
      def try_infer_max_min_two_arg(node, ctx)
        args = node.arg_nodes || []
        return nil unless (node.name == :max || node.name == :min) && args.size == 2
        at = infer_expr(args[0], ctx)
        bt = infer_expr(args[1], ctx)
        return nil if at.bottom? || bt.bottom?
        if at.raw? && bt.raw?
          return (at.f64? || bt.f64?) ? Type::F64 : Type::I64
        end
        return nil unless at.numeric? && bt.numeric?
        if at.f64? || bt.f64? ||
           (at.class_type? && at.class_name == :Float) ||
           (bt.class_type? && bt.class_name == :Float)
          return Type::F64
        end
        (at.raw? || bt.raw?) ? Type::I64 : nil
      end

      # Class method call: Module.method(...) → look up by module name.
      def try_infer_class_method_call(node, ctx)
        recv = node.receiver_node
        return nil unless constant_ref?(recv)
        # Module.method(...) for user-defined module methods: TI stores the
        # :return slot by flat method name (collect_module_methods_for_ti
        # flattens module methods into @user_methods by name). Mirror the
        # fallback from propagate_positional_args.
        if @user_methods.key?(node.name)
          flat = @env.type_of([:return, node.name])
          return flat unless flat.bottom?
        end
        return nil unless @user_classes.key?(recv.name)
        ret = @env.type_of([:return, [recv.name, node.name]])
        ret.bottom? ? nil : ret
      end

      # Method call on a known class instance — look up return type.
      def try_infer_instance_method_call(node, ctx)
        recv = node.receiver_node
        return nil unless recv
        recv_ty = infer_expr(recv, ctx)
        return nil unless recv_ty.class_type?
        @env.type_of([:return, [recv_ty.class_name, node.name]])
      end

      # Free call to a top-level user method.
      def try_infer_free_call(node, _ctx) = node.receiver_node.nil? ? @env.type_of([:return, node.name]) : nil

      # Infer the return type of a block body, seeding required params as locals
      # in the enclosing method's namespace (Ruby closure semantics).
      def infer_block_return(block_node, param_types, ctx)
        return Type::BOTTOM unless block_node.is_a?(Ast::Block)
        seed_block_params(block_node, param_types, ctx)
        infer_body_return(block_node.body, ctx)
      end

      def seed_block_params(block_node, param_types, ctx)
        return unless block_node.is_a?(Ast::Block)
        params = block_node.required_params || []
        params.each_with_index do |pname, i|
          next unless pname.is_a?(Symbol)
          ty = param_types[i]
          next unless ty.is_a?(Type) && !ty.bottom?
          @env.join!([:block_param, ctx.method_key, pname], ty)
        end
      end

      # Returns the expected block param types for common built-in iteration methods.
      def block_param_types(method_name, recv_node, ctx)
        case method_name
        when :times, :upto, :downto
          [Type::I64]
        when :each, :map, :flat_map, :select, :reject, :filter,
             :each_with_object, :min_by, :max_by, :sort_by, :any?, :all?, :none?,
             :find, :detect, :count, :sum, :reduce, :inject
          recv_ty = recv_node ? infer_expr(recv_node, ctx) : Type::BOTTOM
          if recv_ty.class_type?
            return [recv_ty.elem || Type::BOTTOM] if recv_ty.array?
            return [Type::I64] if recv_ty.class_name == :Range
          end
          []
        when :each_with_index
          recv_ty = recv_node ? infer_expr(recv_node, ctx) : Type::BOTTOM
          if recv_ty.array?
            [recv_ty.elem || Type::BOTTOM, Type::I64]
          else
            [Type::BOTTOM, Type::I64]
          end
        else
          []
        end
      end

      # ------------------------------------------------------------------
      # infer_body_return — return type of the last value in a body
      # ------------------------------------------------------------------

      def infer_body_return(node, ctx)
        return Type::BOTTOM unless node
        case node
        when Ast::Sequence
          types = []
          node.nodes.each_with_index do |n, i|
            if i == node.nodes.size - 1
              ty = infer_body_return(n, ctx)
              warn "[TI_DBG] sudoku Seq last=#{n.class}, ty=#{ty.inspect}" if ENV['TI_DBG_USERS'] && ctx.method_key == :sd_solve
              types << ty unless ty.bottom?
            else
              scan_returns(n, ctx, types)
            end
          end
          scan_returns(node.nodes.last, ctx, types) if types.empty?
          return Type::BOTTOM if types.empty?
          types.reduce { |a, b| join(a, b) }
        when Ast::If
          t = infer_body_return(node.then_node, ctx)
          e = node.else_node ? infer_body_return(node.else_node, ctx) : Type::NIL_CLASS
          join(t, e)
        when Ast::Return
          infer_expr(node.value_node, ctx)
        when Ast::While, Ast::Until
          # A `while true` / `until false` loop can't exit normally — its
          # only exit is via an explicit return inside the body (those are
          # picked up via scan_returns on an earlier pass). Skip the nil
          # contribution so the function's return type doesn't pick up a
          # spurious nil branch. (fannkuchredux relies on this.)
          infinite_loop?(node) ? Type::BOTTOM : Type::NIL_CLASS
        else
          infer_expr(node, ctx)
        end
      end

      def infinite_loop?(node)
        cond = node.condition_node
        cond = cond.nodes.first while cond.is_a?(Ast::Sequence) && cond.nodes.size == 1
        return false unless cond
        cond_is_constant_true =
          case node
          when Ast::While then cond.is_a?(Ast::TrueLiteral)
          when Ast::Until then cond.is_a?(Ast::FalseLiteral)
          end
        return false unless cond_is_constant_true
        # `while true` with a reachable `break` inside can still exit normally —
        # treat it as a regular loop (returns nil on break). Only truly
        # non-terminating loops (only exit path is `return`) collapse to BOTTOM.
        !contains_break?(node.body_node)
      end

      def contains_break?(node)
        return false unless node
        return true if node.is_a?(Ast::Break)
        # Don't descend into nested loops — their `break` exits the inner loop,
        # not the one we're asking about.
        return false if node.is_a?(Ast::While) || node.is_a?(Ast::Until) ||
                        node.is_a?(Ast::ForLoop) ||
                        (node.is_a?(Ast::MethodCall) && %i[times each each_with_index upto downto map select reject].include?(node.name))
        node.children.any? { |c| c.is_a?(Ast::Node) && contains_break?(c) }
      end

      def scan_returns(node, ctx, acc)
        return unless node
        case node
        when Ast::Return
          ty = infer_expr(node.value_node, ctx)
          acc << ty unless ty.bottom?
        when Ast::Sequence
          node.nodes.each { |n| scan_returns(n, ctx, acc) }
        when Ast::If
          scan_returns(node.then_node, ctx, acc)
          scan_returns(node.else_node, ctx, acc)
        when Ast::While, Ast::Until
          scan_returns(node.body_node, ctx, acc)
        when Ast::MethodCall
          blk = node.block_node
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
          name = node.name
          result[name] << node.value_node
          collect_assignments(node.value_node, result)
        when Ast::MultipleAssignment
          targets = node.targets || []
          value = node.value_node
          if value.is_a?(Ast::ArrayLiteral)
            elems = value.element_nodes || []
            targets.each_with_index do |t, i|
              next unless t[0] == :local
              result[t[1]] << elems[i] if elems[i]
            end
          end
        when Ast::Sequence
          node.nodes.each { |n| collect_assignments(n, result) }
        when Ast::If
          collect_assignments(node.pred_node, result)
          collect_assignments(node.then_node, result)
          collect_assignments(node.else_node, result)
        when Ast::While, Ast::Until
          collect_assignments(node.condition_node, result)
          collect_assignments(node.body_node, result)
        when Ast::ForLoop
          collect_assignments(node.collection_node, result)
          collect_assignments(node.body_node, result)
        when Ast::Return
          collect_assignments(node.value_node, result)
        else
          node.children.each { |c| collect_assignments(c, result) if c.is_a?(Ast::Node) }
          # Ruby blocks are closures — assignments inside a block body are
          # visible in the enclosing scope, so descend into block bodies.
          if node.respond_to?(:block_node) && (blk = node.block_node)
            collect_assignments(blk.body, result) if blk.respond_to?(:body)
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
          name = node.name
          result[name] << node.value_node
        when Ast::MultipleAssignment
          targets = node.targets || []
          value = node.value_node
          if value.is_a?(Ast::ArrayLiteral)
            elems = value.element_nodes || []
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
            recv = node.receiver_node
            args = node.arg_nodes || []
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.name == name
              escaped = true unless node.name == :[] || node.name == :[]=
            end
            args.each do |a|
              escaped = true if a.is_a?(Ast::LocalVariableRead) &&
                                a.name == name
            end
          when Ast::AttributeWrite
            recv = node.receiver_node
            args = node.arg_nodes || []
            if recv.is_a?(Ast::LocalVariableRead) &&
               recv.name == name
              escaped = true unless node.name == :[]=
            end
            args.each do |a|
              escaped = true if a.is_a?(Ast::LocalVariableRead) &&
                                a.name == name
            end
          when Ast::LocalVariableWrite
            val = node.value_node
            if val.is_a?(Ast::LocalVariableRead) &&
               val.name == name
              escaped = true
            end
          when Ast::Return, Ast::InstanceVariableWrite
            val = node.value_node
            if val.is_a?(Ast::LocalVariableRead) &&
               val.name == name
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
        ret_elems = last.element_nodes || []
        in_return = ret_elems.any? { |e|
          e.is_a?(Ast::LocalVariableRead) && e.name == name
        }
        return false unless in_return
        # Check no other escapes besides the return array and normal []/[]= use
        escaped_elsewhere = false
        walk(body) do |node|
          # Skip the final array literal itself
          next if node.equal?(last)
          case node
          when Ast::MethodCall
            recv = node.receiver_node
            args = node.arg_nodes || []
            # Receiver use is OK for []/[]=
            if recv.is_a?(Ast::LocalVariableRead) && recv.name == name
              escaped_elsewhere = true unless node.name == :[] || node.name == :[]=
            end
            # Arg use is an escape (passed to another function)
            args.each do |a|
              escaped_elsewhere = true if a.is_a?(Ast::LocalVariableRead) && a.name == name
            end
          when Ast::AttributeWrite
            recv = node.receiver_node
            if recv.is_a?(Ast::LocalVariableRead) && recv.name == name
              escaped_elsewhere = true unless node.name == :[]=
            end
          when Ast::Return, Ast::InstanceVariableWrite
            val = node.value_node
            escaped_elsewhere = true if val.is_a?(Ast::LocalVariableRead) && val.name == name
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
                      node.name == :[]= &&
                      node.receiver_node
                          .then { |r| r.is_a?(Ast::LocalVariableRead) &&
                                      r.name == name }
          args = node.arg_nodes || []
          val_ty = infer_expr(args[1], ctx) if args[1]
          next if val_ty.nil? || val_ty.bottom?
          ok = false unless val_ty == elem_ty ||
                            (val_ty.i64? && elem_ty.f64?)
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
          walk(node.pred_node, &block)
          walk(node.then_node, &block)
          walk(node.else_node, &block)
        when Ast::While, Ast::Until
          walk(node.condition_node, &block)
          walk(node.body_node, &block)
        when Ast::Return
          walk(node.value_node, &block)
        when Ast::LocalVariableWrite, Ast::InstanceVariableWrite
          walk(node.value_node, &block)
        when Ast::MethodCall
          walk(node.receiver_node, &block)
          (node.arg_nodes || []).each { |a| walk(a, &block) }
          blk = node.block_node
          walk(blk.body, &block) if blk.respond_to?(:body)
        when Ast::AttributeWrite
          walk(node.receiver_node, &block)
          (node.arg_nodes || []).each { |a| walk(a, &block) }
        when Ast::MultipleAssignment
          walk(node.value_node, &block)
        when Ast::ForLoop
          walk(node.collection_node, &block)
          walk(node.body_node, &block)
        when Ast::ArrayLiteral
          (node.element_nodes || []).each { |e| walk(e, &block) }
        else
          node.children.each { |c| walk(c, &block) if c.is_a?(Ast::Node) }
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
        current = klass.respond_to?(:superclass) ? klass.superclass : nil
        while current
          cname = current.name
          break unless cname
          chain << cname
          # If we've reached a built-in class, append its known ancestors.
          if BUILTIN_ANCESTORS.key?(cname)
            chain.concat(BUILTIN_ANCESTORS[cname])
            break
          end
          current = current.superclass
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

      # LCA returning a Type object.
      def lca_type(a_name, b_name)
        return Type.of(a_name) if a_name == b_name
        chain_a = ancestors_of(a_name)
        set_a = chain_a.to_set
        chain_b = ancestors_of(b_name)
        lca = chain_b.find { |c| set_a.include?(c) }
        lca ? Type.of(lca) : Type::BASIC_OBJECT
      end

      # Resolve :needs_join sentinels in merged collection params.
      def resolve_param_joins(a, b, merged)
        return merged unless needs_param_resolution?(merged)
        elem = merged.elem == :needs_join ? join(a.elem, b.elem) : merged.elem
        key = merged.key == :needs_join ? join(a.key, b.key) : merged.key
        val = merged.val == :needs_join ? join(a.val, b.val) : merged.val
        Type.new(:class_type, class_name: merged.class_name,
                 nullable: merged.nullable?, exact: merged.exact?,
                 elem: elem, key: key, val: val)
      end

      def needs_param_resolution?(t) = t.elem == :needs_join || t.key == :needs_join || t.val == :needs_join

      # Collect constructor param types across all calling contexts and pick
      # the best (most precise) type for each param. Contexts that pass only
      # NilClass are excluded — sentinel construction shouldn't widen ivars.
      # Unresolved param slots are returned as Type::BOTTOM rather than
      # aborting the whole class — ivar inference from the initialize body
      # doesn't always depend on knowing param types (e.g. `@list = Array.new(...)`).
      def best_constructor_param_types(class_name, param_count)
        slots = @env.slots
        contexts = Set.new
        slots.each_key do |slot|
          next unless slot.is_a?(Array) && slot[0] == :constructor_param && slot[1] == class_name && slot.size == 4
          contexts << slot[3]
        end
        return nil if contexts.empty?

        param_count.times.map do |i|
          types = contexts.filter_map { |ctx_key|
            t = @env.type_of([:constructor_param, class_name, i, ctx_key])
            t.bottom? ? nil : t
          }
          next Type::BOTTOM if types.empty?
          non_nil = types.reject(&:nil_type?)
          next Type::BOTTOM if non_nil.empty?
          non_nil.reduce { |a, b| join(a, b) }
        end
      end

      # ------------------------------------------------------------------
      # VM object → lattice type
      # ------------------------------------------------------------------

      def vm_object_type(value)
        case value
        when Vm::IntegerObject
          v = value.raw
          v.is_a?(Integer) ? Type.i64_bounded(v, v) : Type::I64
        when Vm::FloatObject   then Type::F64
        when Vm::ArrayObject
          elems = value.raw
          if elems.empty?
            Type::ARRAY
          else
            elem_ty = elems.reduce(Type::BOTTOM) { |acc, e| join(acc, vm_object_type(e) || Type::BOTTOM) }
            elem_ty.bottom? ? Type::ARRAY : Type.array(elem: elem_ty)
          end
        when Vm::HashObject
          pairs = value.raw
          if pairs.empty?
            Type::HASH
          else
            key_ty = pairs.keys.reduce(Type::BOTTOM)  { |acc, kw| join(acc, vm_object_type(kw.key) || Type::BOTTOM) }
            val_ty = pairs.values.reduce(Type::BOTTOM) { |acc, v|  join(acc, vm_object_type(v) || Type::BOTTOM) }
            Type.hash_type(
              key: key_ty.bottom? ? nil : key_ty,
              val: val_ty.bottom? ? nil : val_ty
            )
          end
        else
          class_obj = value.respond_to?(:class_object) ? value.class_object : nil
          class_name = class_obj&.name
          return nil unless class_name
          Type.of(class_name)
        end
      end

      # ------------------------------------------------------------------
      # Helpers
      # ------------------------------------------------------------------

      def array_new_call?(node)
        return false unless node.is_a?(Ast::MethodCall)
        return false unless node.name == :new
        recv = node.receiver_node
        return false unless recv.is_a?(Ast::ConstantRead) &&
                            recv.name == :Array
        node.block_node.nil?
      end

      def each_user_instance_method(class_name, klass)
        (klass.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          yield [class_name, mname], method
        end
        # Also walk eigenclass (class methods / module methods)
        eigenclass = klass.eigenclass
        if eigenclass
          (eigenclass.methods_table || {}).each do |mname, method|
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
        (method.required_params || []) +
          (method.optional_params || []).map(&:first) +
          [method.rest_param].compact +
          (method.post_params || [])
      end

      def method_for_key(mkey)
        if mkey.is_a?(Array)
          class_name, method_name = mkey
          klass = @user_classes[class_name]
          m = klass&.methods_table&.fetch(method_name, nil)
          # Also check eigenclass for class/module methods
          m ||= klass&.eigenclass&.methods_table&.fetch(method_name, nil)
          m
        else
          @user_methods[mkey]
        end
      end
    end
  end
end

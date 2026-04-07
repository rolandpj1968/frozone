# Maps TypeInference results to Crystal-specific type decisions.
#
# Takes the raw TypeEnv from TI and produces lookup structures for the Codegen:
# - Per-method local types (Int64/Float64 unboxing)
# - Per-method array element types (Array(T) promotion)
# - Per-method class-typed locals (devirtualization)
# - Per-method param types (typed overloads)
# - Per-method return types (raw return annotation)
# - Block param types (native iteration)
# - Constant types
# - Instance variable types
#
# All Crystal-specific decisions (what to promote, what to leave as RubyObject)
# are made here, not in the Codegen.

module Frozone
  module Compiler
    class CrystalTypeMapper
      attr_reader :local_types
      attr_reader :locals, :arrays, :class_locals, :local_array_elems
      attr_reader :block_params, :class_params, :inferred_params, :typed_params
      attr_reader :typed_method_returns, :instance_method_raw_returns
      attr_reader :const_raw_types, :typed_ivars, :user_class_names

      def initialize(env, user_methods:, user_classes:, opt_flags:)
        @env = env
        @user_methods = user_methods
        @user_classes = user_classes
        @opt_flags = opt_flags
        @user_class_names = user_classes.keys.to_set

        # Output maps — populated by build!
        @local_types = {}
        @locals = {}
        @arrays = {}
        @class_locals = {}
        @local_array_elems = {}
        @block_params = {}
        @class_params = {}
        @inferred_params = {}
        @typed_params = {}
        @typed_method_returns = {}
        @instance_method_raw_returns = {}
        @const_raw_types = {}
        @typed_ivars = {}
      end

      def build!
        unpack_slots
        build_top_level_params
        build_eigenclass_params
        build_class_params
        self
      end

      private

      def opt?(flag) = @opt_flags.include?(flag)

      # Unpack TypeEnv slots into per-kind lookup maps.
      def unpack_slots
        @env.each_typed do |slot, ty|
          next unless slot.is_a?(Array)
          case slot[0]
          when :local       then unpack_local(slot, ty)
          when :block_param then unpack_block_param(slot, ty)
          when :array_elem  then unpack_array_elem(slot, ty)
          when :const       then unpack_const(slot, ty)
          when :ivar        then unpack_ivar(slot, ty)
          when :return      then unpack_return(slot, ty)
          end
        end
      end

      def unpack_local(slot, ty)
        mkey, name = slot[1], slot[2]
        ct = CrystalType.from_type(ty, user_class_names: @user_class_names)
        (@local_types[mkey] ||= {})[name] = ct if ct != :ruby_object
        if ty.class_type? && opt?(:devirtualize)
          cls = ty.class_name
          skip_builtin = %i[Object BasicObject Numeric Array Hash].include?(cls)
          if !skip_builtin && (@user_class_names.include?(cls) || CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(cls))
            (@class_locals[mkey] ||= {})[name] = ty.nullable? ? [cls, :nullable] : cls
          end
        end
        if ty.array? && opt?(:native_arrays) && ty.elem&.raw?
          (@local_array_elems[mkey] ||= {})[name] = ty.elem
        end
        if opt?(:unbox_locals) && ty.raw?
          (@locals[mkey] ||= {})[name] = ty
        end
      end

      def unpack_block_param(slot, ty)
        return unless opt?(:native_iteration) && ty.raw?
        (@block_params[slot[1]] ||= {})[slot[2]] = ty
      end

      def unpack_array_elem(slot, ty)
        return unless opt?(:native_arrays) && ty.raw?
        (@arrays[slot[1]] ||= {})[slot[2]] = ty
      end

      def unpack_const(slot, ty)
        return unless opt?(:unbox_locals)
        if ty.raw?
          @const_raw_types[slot[1]] = ty
          return
        end
        if ty.array? && ty.elem&.raw?
          @const_raw_types[slot[1]] = ty.elem.f64? ? Type::ARRAY_F64 : Type::ARRAY_I64
        end
      end

      def unpack_ivar(slot, ty)
        return unless opt?(:typed_ivars)
        if ty.raw?
          (@typed_ivars[slot[1]] ||= {})[slot[2]] = ty
          return
        end
        if ty.array? && ty.elem&.raw?
          (@typed_ivars[slot[1]] ||= {})[slot[2]] = ty.elem.f64? ? Type::ARRAY_F64 : Type::ARRAY_I64
        end
      end

      def unpack_return(slot, ty)
        return unless opt?(:method_specialization) || opt?(:raw_returns) || opt?(:accessor_inline)
        return unless ty.raw?
        mkey = slot[1]
        raw = ty
        if mkey.is_a?(Symbol)
          params = @typed_params[mkey]
          return if params && params.any? { |t| !raw_type(t) }
          @typed_method_returns[mkey] = raw
        elsif mkey.is_a?(Array) && mkey.size == 2
          cname, fname = mkey
          if @user_class_names.include?(cname)
            params = @class_params[mkey]
            unless params && params.any? { |t| !raw_type(t) } && params.any? { |t| raw_type(t) }
              @instance_method_raw_returns[[cname, fname]] = raw
            end
          end
        end
      end

      def build_top_level_params
        return unless opt?(:call_site_types) || opt?(:method_specialization)
        @user_methods.each do |mname, method|
          req = method.required_params || []
          next if req.empty?
          crystal_types = req.each_with_index.map { |_, i|
            ty = @env.type_of([:param, mname, i])
            ty.bottom? ? :ruby_object : CrystalType.from_type(ty, user_class_names: @user_class_names)
          }
          next unless crystal_types.any? { |t| t != :ruby_object }
          @inferred_params[mname] = crystal_types
          raw_types = req.each_with_index.map { |_, i|
            ty = @env.type_of([:param, mname, i])
            ty.raw? ? ty : nil
          }
          @typed_params[mname] = raw_types if raw_types.all? && @typed_method_returns[mname]
        end
      end

      def build_eigenclass_params
        return unless opt?(:call_site_types) || opt?(:method_specialization)
        @user_classes.each do |_cname, klass|
          eigenclass = klass.eigenclass
          next unless eigenclass
          (eigenclass.methods_table || {}).each do |mname, method|
            next unless method.is_a?(Vm::Method)
            next if @inferred_params.key?(mname)
            req = method.required_params || []
            next if req.empty?
            crystal_types = req.each_with_index.map { |_, i|
              ty = @env.type_of([:param, mname, i])
              ty.bottom? ? :ruby_object : CrystalType.from_type(ty, user_class_names: @user_class_names)
            }
            @inferred_params[mname] = crystal_types if crystal_types.any? { |t| t != :ruby_object }
          end
        end
      end

      def build_class_params
        @user_classes.each do |cname, klass|
          build_method_params(klass, cname)
          eigenclass = klass.eigenclass
          build_method_params(eigenclass, cname) if eigenclass
        end
      end

      def build_method_params(klass, cname)
        (klass.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method)
          req = method.required_params || []
          next if req.empty?
          mkey = [cname, mname]
          crystal_types = req.each_with_index.map { |_, i|
            ty = @env.type_of([:param, mkey, i])
            ty.bottom? ? :ruby_object : CrystalType.from_type(ty, user_class_names: @user_class_names)
          }
          @class_params[mkey] = crystal_types if crystal_types.any? { |t| t != :ruby_object }
        end
      end

      # --- Type conversion helpers (legacy — used by unpack_return) ---

      def raw_type(ty) = Type.raw?(ty) ? ty : nil
    end
  end
end

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
        @env.instance_variable_get(:@slots).each do |slot, ty|
          next if ty == :unknown || !slot.is_a?(Array)
          case slot[0]
          when :local    then unpack_local(slot, ty)
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
        # Class-typed locals (devirtualize)
        if ty.is_a?(Hash) && opt?(:devirtualize)
          cls = ty[:class]
          skip_builtin = %i[Object BasicObject Numeric Array Hash].include?(cls)
          if cls && !skip_builtin && (@user_class_names.include?(cls) || CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(cls))
            (@class_locals[mkey] ||= {})[name] = cls
          end
        end
        # Array element type (boxed RubyArray with known elem type)
        if ty.is_a?(Hash) && ty[:class] == :Array && opt?(:native_arrays) && (elem_raw = raw_type(ty[:elem]))
          (@local_array_elems[mkey] ||= {})[name] = elem_raw
        end
        # Scalar unboxing
        if opt?(:unbox_locals) && (raw = raw_type(ty))
          (@locals[mkey] ||= {})[name] = raw
        end
      end

      def unpack_block_param(slot, ty)
        return unless opt?(:native_iteration)
        raw = raw_type(ty) or return
        (@block_params[slot[1]] ||= {})[slot[2]] = raw
      end

      def unpack_array_elem(slot, ty)
        return unless opt?(:native_arrays)
        raw = raw_type(ty) or return
        (@arrays[slot[1]] ||= {})[slot[2]] = raw
      end

      def unpack_const(slot, ty)
        return unless opt?(:unbox_locals)
        raw = raw_type(ty) or return
        @const_raw_types[slot[1]] = raw
      end

      def unpack_ivar(slot, ty)
        return unless opt?(:typed_ivars)
        raw = raw_type(ty) or return
        (@typed_ivars[slot[1]] ||= {})[slot[2]] = raw
      end

      def unpack_return(slot, ty)
        return unless opt?(:method_specialization) || opt?(:raw_returns) || opt?(:accessor_inline)
        mkey = slot[1]
        raw = raw_type(ty) or return
        if mkey.is_a?(Symbol)
          @typed_method_returns[mkey] = raw
        elsif mkey.is_a?(Array) && mkey.size == 2
          cname, fname = mkey
          @instance_method_raw_returns[[cname, fname]] = raw if @user_class_names.include?(cname)
        end
      end

      # Build @inferred_params and @typed_params for top-level methods
      def build_top_level_params
        return unless opt?(:call_site_types) || opt?(:method_specialization)
        @user_methods.each do |mname, method|
          req = method.instance_variable_get(:@required_params) || []
          next if req.empty?
          crystal_types = req.each_with_index.map { |_, i|
            ty = @env[[:param, mname, i]]
            ty ? crystal_type(ty) : 'RubyObject'
          }
          next unless crystal_types.any? { |t| t != 'RubyObject' }
          @inferred_params[mname] = crystal_types
          raw_types = req.each_with_index.map { |_, i| raw_type(@env[[:param, mname, i]]) }
          @typed_params[mname] = raw_types if raw_types.all? && @typed_method_returns[mname]
        end
      end

      # Build @inferred_params for eigenclass methods
      def build_eigenclass_params
        return unless opt?(:call_site_types) || opt?(:method_specialization)
        @user_classes.each do |_cname, klass|
          eigenclass = klass.instance_variable_get(:@eigenclass)
          next unless eigenclass
          (eigenclass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
            next unless method.is_a?(Vm::Method)
            next if @inferred_params.key?(mname)
            req = method.instance_variable_get(:@required_params) || []
            next if req.empty?
            crystal_types = req.each_with_index.map { |_, i|
              ty = @env[[:param, mname, i]]
              ty ? crystal_type(ty) : 'RubyObject'
            }
            @inferred_params[mname] = crystal_types if crystal_types.any? { |t| t != 'RubyObject' }
          end
        end
      end

      # Build @class_params for instance AND class methods
      def build_class_params
        @user_classes.each do |cname, klass|
          build_method_params(klass, cname)
          eigenclass = klass.instance_variable_get(:@eigenclass)
          build_method_params(eigenclass, cname) if eigenclass
        end
      end

      def build_method_params(klass, cname)
        (klass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method)
          req = method.instance_variable_get(:@required_params) || []
          next if req.empty?
          mkey = [cname, mname]
          crystal_types = req.each_with_index.map { |_, i|
            ty = @env[[:param, mkey, i]]
            ty ? crystal_type(ty) : 'RubyObject'
          }
          @class_params[mkey] = crystal_types if crystal_types.any? { |t| t != 'RubyObject' }
        end
      end

      # --- Type conversion helpers ---

      def raw_type(ty)
        ty == :i64 || ty == :f64 ? ty : nil
      end

      def native_elem?(crystal_type)
        crystal_type == 'Int64' || crystal_type == 'Float64' || crystal_type.start_with?('Array(')
      end

      def crystal_type(ty)
        case ty
        when :i64 then 'Int64'
        when :f64 then 'Float64'
        when :array_i64 then 'Array(Int64)'
        when :array_f64 then 'Array(Float64)'
        when Hash
          case ty[:class]
          when :Integer, :Float, :String, :Symbol then 'RubyObject'
          when :NilClass, :TrueClass, :FalseClass then 'RubyObject'
          when :Array
            if ty[:elem]
              elem_crystal = crystal_type(ty[:elem])
              native_elem?(elem_crystal) ? "Array(#{elem_crystal})" : 'RubyObject'
            else
              'RubyObject'
            end
          when :Hash then 'RubyHash'
          when :Proc then 'RubyProc'
          else
            cls = ty[:class]
            (@user_class_names.include?(cls) || CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(cls)) ? crystal_class_name(cls) : 'RubyObject'
          end
        else 'RubyObject'
        end
      end

      def crystal_class_name(cls)
        CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{cls}"
      end
    end
  end
end

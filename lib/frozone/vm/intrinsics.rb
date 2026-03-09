module Frozone
  module Vm
    module Intrinsics
      StrictTypes = true

      class << self
        def bool_object_for(bool) = bool ? TrueObject::TRUE : FalseObject::FALSE

        # BasicObject
        def basic_object___id__(_, v) = IntegerObject.new(v.__id__)

        def basic_object__equal_equal_(_, v1, v2) = bool_object_for(v1.equal?(v2))

        def basic_object_method_missing(context, receiver, name, args, kwargs)
          raise "BasicObject#method_missing name must be a Symbol" unless name.is_a?(Symbol)
          class_name = receiver.class_object.name
          raise "undefined method '#{name}' for an instance of #{class_name}"
        end

        def basic_object___send__(context, receiver, name, args, kwargs)
          raise "BasicObject#__send__ name must be a SymbolObject" unless name.is_a?(SymbolObject)
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          receiver.dispatch(context, name.raw, args.raw, raw_kwargs)
        end

        # Class
        def class_new(context, klass, args, kwargs) = klass.new_instance(context, args.raw, kwargs.raw)

        # Integer
        def integer_hash(_, v) = IntegerObject.new(v.raw.hash)

        def integer_eql(_, v1, v2) = bool_object_for(v2.is_a?(IntegerObject) && v1.raw == v2.raw)

        # Integer generated methods
        def is_int(v) = v.is_a?(IntegerObject)

        def check_integer_bin_args(op) = ("raise 'BUG: Integer #{op} intrinsic called with non-Integer values' unless is_int(v1) and is_int(v2)" if StrictTypes)

        def def_integer_cmp(name, op) = eval "def integer_#{name}(_, v1, v2); #{check_integer_bin_args(op)}; bool_object_for(v1.raw #{op} v2.raw); end"

        def def_integer_bin_op(name, op) = eval "def integer_#{name}(_, v1, v2); #{check_integer_bin_args(op)}; IntegerObject.new(v1.raw #{op} v2.raw); end"

        # String
        def string_hash(_, v) = IntegerObject.new(v.raw.hash)

        def string_eql(_, v1, v2) = bool_object_for(v2.is_a?(StringObject) && v1.raw == v2.raw)

        # Symbol
        def symbol_hash(_, v) = IntegerObject.new(v.raw.hash)

        def symbol_eql(_, v1, v2) = bool_object_for(v2.is_a?(SymbolObject) && v1.raw == v2.raw)

        # Array
        def array_hash(context, v)
          hash_val = v.raw.reduce(0) { |acc, e| acc * 31 + e.dispatch(context, :hash, [], {}).raw }
          IntegerObject.new(hash_val)
        end

        def array_eql(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(ArrayObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.zip(v2.raw).all? { |a, b| a.dispatch(context, :eql?, [b], {}).truthy? }
          bool_object_for(result)
        end

        # Hash
        def hash_hash(context, v)
          hash_val = v.raw.reduce(0) { |acc, (k, val)| acc ^ (k.dispatch(context, :hash, [], {}).raw ^ val.dispatch(context, :hash, [], {}).raw) }
          IntegerObject.new(hash_val)
        end

        def hash_index(context, h, key)
          value = h[key]
          value.nil? ? NilObject::NIL : value
        end

        def hash_eql(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(HashObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.all? do |k1, val1|
            pair2 = v2.raw.find { |k2, _| k1.dispatch(context, :eql?, [k2], {}).truthy? }
            pair2 && val1.dispatch(context, :eql?, [pair2[1]], {}).truthy?
          end
          bool_object_for(result)
        end
      end

      # Integer
      def_integer_cmp('_lt_', '<')
      def_integer_cmp('_le_', '<=')
      def_integer_cmp('_ge_', '>=')
      def_integer_cmp('_gt_', '>')
      def_integer_cmp('_eq_', '==') # TODO - should be alias for ===

      def_integer_bin_op('_plus_', '+')
      def_integer_bin_op('_minus_', '-')
    end
  end
end

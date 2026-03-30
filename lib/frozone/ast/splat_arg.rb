require_relative 'node'

module Frozone
  module Ast
    # Represents *expr in a method call argument list
    class SplatArg < Node
      def initialize(value_node)
        @value_node = value_node
      end

      def children = [@value_node].compact

      def evaluate(context)
        return Vm::ArrayObject.new([]) if @value_node.nil?
        val = @value_node.evaluate(context)
        return val if val.is_a?(Vm::ArrayObject)
        # Ruby 4.0: *nil → [] without calling to_a
        return Vm::ArrayObject.new([]) if val.is_a?(Vm::NilObject)
        # Splat calls to_a (NOT to_ary), including private; checks respond_to?(:to_a, true) first
        has_to_a = begin
          result = val.dispatch(context, :respond_to?, [Vm::SymbolObject.from(:to_a), Vm::TrueObject::TRUE], {})
          result.truthy?
        rescue
          # BasicObject may not have respond_to? — check for to_a directly
          !val.lookup_instance_method(:to_a).nil?
        end
        if has_to_a
          result = val.dispatch(context, :to_a, [], {}, nil, private_ok: true)
          return Vm::ArrayObject.new([val]) if result.is_a?(Vm::NilObject)
          return result if result.is_a?(Vm::ArrayObject)
          raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Array")
        end
        Vm::ArrayObject.new([val])
      end
    end
  end
end

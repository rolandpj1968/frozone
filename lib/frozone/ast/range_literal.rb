require_relative 'node'
require_relative '../vm/range_object'

module Frozone
  module Ast
    class RangeLiteral < Node
      def initialize(begin_node, end_node, exclusive)
        @begin_node = begin_node
        @end_node   = end_node
        @exclusive  = exclusive
      end

      def evaluate(context)
        b = @begin_node ? @begin_node.evaluate(context) : Vm::NilObject::NIL
        e = @end_node   ? @end_node.evaluate(context)   : Vm::NilObject::NIL
        # Call b <=> e to validate range (matches MRI Range.new behavior)
        unless b.is_a?(Vm::NilObject) || e.is_a?(Vm::NilObject) ||
               b.is_a?(Vm::IntegerObject) || b.is_a?(Vm::FloatObject) ||
               b.is_a?(Vm::StringObject) || b.is_a?(Vm::SymbolObject)
          begin
            result = b.dispatch(context, :<=>, [e], {})
            if result.is_a?(Vm::NilObject)
              raise Vm::FrozoneException.make(:ArgumentError, "bad value for range")
            end
          rescue Vm::FrozoneException => exc
            raise unless exc.vm_object&.class_object&.name == :NoMethodError
            raise Vm::FrozoneException.make(:ArgumentError, "bad value for range")
          end
        end
        Vm::RangeObject.new(b, e, @exclusive)
      end
    end
  end
end

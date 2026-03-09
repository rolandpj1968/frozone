require_relative 'node'
require_relative '../vm/range_object'

module Frozone
  module Ast
    class RangeLiteral < Node
      def initialize(begin_node, end_node, exclusive)
        @begin_node = check_nil_or_type("begin_node", begin_node, Node)
        @end_node   = check_nil_or_type("end_node", end_node, Node)
        @exclusive  = exclusive
      end

      def evaluate(context)
        b = @begin_node ? @begin_node.evaluate(context) : Vm::NilObject::NIL
        e = @end_node   ? @end_node.evaluate(context)   : Vm::NilObject::NIL
        Vm::RangeObject.new(b, e, @exclusive)
      end
    end
  end
end

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

      def children = [@begin_node, @end_node].compact

      def evaluate(context)
        b = @begin_node ? @begin_node.evaluate(context) : Vm::NilObject::NIL
        e = @end_node   ? @end_node.evaluate(context)   : Vm::NilObject::NIL
        # MRI range literals call b <=> e (so mock expectations work) but do NOT raise
        # ArgumentError when nil is returned — that only happens in Range.new/initialize.
        unless b.is_a?(Vm::NilObject) || e.is_a?(Vm::NilObject) ||
               b.is_a?(Vm::IntegerObject) || b.is_a?(Vm::FloatObject) ||
               b.is_a?(Vm::StringObject) || b.is_a?(Vm::SymbolObject)
          b.dispatch(context, :<=>, [e], {}) rescue nil
        end
        Vm::RangeObject.new(b, e, @exclusive)
      end
    end
  end
end

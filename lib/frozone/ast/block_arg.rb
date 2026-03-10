require_relative 'node'
require_relative '../vm/symbol_proc_object'

module Frozone
  module Ast
    # Represents &expr passed as a block in a method call.
    # Evaluates expr (expected to be a ProcObject or SymbolObject) and wraps it as a block.
    class BlockArg < Node
      def initialize(value_node)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        val = @value_node.evaluate(context)
        return nil if val.is_a?(Vm::NilObject)
        return Vm::SymbolProcObject.new(val) if val.is_a?(Vm::SymbolObject)
        return val if val.is_a?(Vm::ProcObject) || val.is_a?(Vm::BlockObject)
        raise "block argument must be a Proc (got #{val.class})"
      end
    end
  end
end

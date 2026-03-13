require_relative 'node'
require_relative '../vm/symbol_proc_object'

module Frozone
  module Ast
    # Represents &expr passed as a block in a method call.
    # Evaluates expr (expected to be a ProcObject or SymbolObject) and wraps it as a block.
    class BlockArg < Node
      def initialize(value_node)
        @value_node = value_node
      end

      def evaluate(context)
        val = @value_node.evaluate(context)
        return nil if val.is_a?(Vm::NilObject)
        return Vm::SymbolProcObject.new(val) if val.is_a?(Vm::SymbolObject)
        return val if val.is_a?(Vm::ProcObject) || val.is_a?(Vm::BlockObject)
        # Try to_proc coercion for other objects
        if val.respond_to?(:dispatch)
          has_to_proc = begin
            val.dispatch(context, :respond_to?, [Vm::SymbolObject.from(:to_proc)], {}).truthy?
          rescue
            false
          end
          if has_to_proc
            proc_val = val.dispatch(context, :to_proc, [], {})
            return proc_val if proc_val.is_a?(Vm::ProcObject) || proc_val.is_a?(Vm::BlockObject)
          end
        end
        raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Proc")
      end
    end
  end
end

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
        return Vm::SymbolProcObject.new(val, active_refinements: context.frame&.active_refinements) if val.is_a?(Vm::SymbolObject)
        return val if val.is_a?(Vm::ProcObject) || val.is_a?(Vm::BlockObject)
        return val if val.is_a?(Vm::BoundMethodObject)
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
            # to_proc returned a non-Proc
            val_class = val.class_object.full_name.to_s
            ret_class = proc_val.respond_to?(:class_object) ? proc_val.class_object.name.to_s : proc_val.class.name
            raise Vm::FrozoneException.make(:TypeError, "can't convert #{val_class} into Proc (#{val_class}#to_proc gives #{ret_class})")
          end
        end
        raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Proc")
      end
    end
  end
end

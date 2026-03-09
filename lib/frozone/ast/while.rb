require_relative 'node'

module Frozone
  module Ast
    class While < Node
      def initialize(condition_node, body_node)
        @condition_node = check_type("condition_node", condition_node, Node)
        @body_node = check_type("body_node", body_node, Node)
      end

      def to_s
        "while(#{@condition_node}, #{@body_node})"
      end

      def evaluate(context)
        while @condition_node.evaluate(context).truthy?
          begin
            @body_node.evaluate(context)
          rescue NextException
            next
          rescue RedoException
            redo
          rescue BreakException => e
            raise if e.from_block
            return e.value
          end
        end
        Vm::NilObject::NIL
      end
    end
  end
end

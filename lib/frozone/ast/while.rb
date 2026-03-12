require_relative 'node'

module Frozone
  module Ast
    class While < Node
      def initialize(condition_node, body_node, begin_modifier: false)
        @condition_node = condition_node
        @body_node = body_node
        @begin_modifier = begin_modifier
      end

      def to_s
        "while(#{@condition_node}, #{@body_node})"
      end

      def evaluate(context)
        first = @begin_modifier
        while first || @condition_node.evaluate(context).truthy?
          first = false
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

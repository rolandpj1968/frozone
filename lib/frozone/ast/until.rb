require_relative 'node'

module Frozone
  module Ast
    class Until < Node
      def initialize(condition_node, body_node)
        @condition_node = check_type("condition_node", condition_node, Node)
        @body_node = check_type("body_node", body_node, Node)
      end

      def to_s
        "until(#{@condition_node}, #{@body_node})"
      end

      def evaluate(context)
        until @condition_node.evaluate(context).truthy?
          @body_node.evaluate(context)
        end
        Vm::NilObject::NIL
      end
    end
  end
end

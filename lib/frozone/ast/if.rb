require_relative 'node'

module Frozone
  module Ast
    class If < Node
      def initialize(pred_node, then_node, else_node)
        @pred_node = check_type("pred_node", pred_node, Node)
        @then_node = check_type("then_node", then_node, Node)
        @else_node = check_nil_or_type("else_node", else_node, Node)
      end

      def to_s
        "if(#{@pred_node} ? #{@then_node} : #{@else_node || '_'})"
      end

      def evaluate(context)
        pred = @pred_node.evaluate(context)

        if pred.truthy?
          @then_node.evaluate(context)
        else
          if @else_node.nil?
            Vm::NilObject::NIL
          else
            @else_node.evaluate(context)
          end
        end
      end
    end
  end
end

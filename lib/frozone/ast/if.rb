module Frozone
  module Ast
    class If
      def initialize(pred_node, then_node, else_node)
        @pred_node = pred_node
        @then_node = then_node
        @else_node = else_node
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

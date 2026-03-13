require_relative 'node'

module Frozone
  module Ast
    class FlipFlop < Node
      def initialize(left_node, right_node, exclude_end, left_int_literal: false, right_int_literal: false)
        @left_node = left_node
        @right_node = right_node
        @exclude_end = exclude_end
        @left_int_literal = left_int_literal
        @right_int_literal = right_int_literal
        @state = false
      end

      def to_s = "flip_flop(#{@left_node}#{@exclude_end ? '...' : '..'}#{@right_node})"

      def evaluate(context)
        if @state
          # Currently on: check right condition
          if flip_cond_truthy?(@right_node, context, int_literal: @right_int_literal)
            @state = false
          end
          Vm::TrueObject::TRUE
        else
          # Currently off: check left condition
          if flip_cond_truthy?(@left_node, context, int_literal: @left_int_literal)
            @state = true
            if !@exclude_end && flip_cond_truthy?(@right_node, context, int_literal: @right_int_literal)
              @state = false  # inclusive: can turn on and off same iteration
            end
            Vm::TrueObject::TRUE
          else
            Vm::FalseObject::FALSE
          end
        end
      end
      private

      # Integer LITERAL flip-flop conditions compare against $. (current line number).
      def flip_cond_truthy?(node, context, int_literal:)
        val = node.evaluate(context)
        if int_literal && val.is_a?(Vm::IntegerObject)
          dollar_dot = Vm::GLOBALS.fetch(:"$.", Vm::NilObject::NIL)
          dollar_dot.is_a?(Vm::IntegerObject) && dollar_dot.raw == val.raw
        else
          val.truthy?
        end
      end
    end
  end
end

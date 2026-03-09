require_relative 'node'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class Case < Node
      When = Struct.new(:condition_nodes, :body_node)

      def initialize(subject_node, whens, else_node)
        @subject_node = check_nil_or_type("subject_node", subject_node, Node)
        @whens = whens
        @else_node = check_nil_or_type("else_node", else_node, Node)
      end

      def to_s = "case(#{@subject_node}, #{@whens.length} whens)"

      def evaluate(context)
        subject = @subject_node&.evaluate(context)

        @whens.each do |w|
          w.condition_nodes.each do |cond_node|
            cond_val = cond_node.evaluate(context)
            matched =
              if subject.nil?
                cond_val.truthy?
              else
                cond_val.dispatch(context, :===, [subject], {}).truthy?
              end
            return w.body_node.evaluate(context) if matched
          end
        end

        @else_node ? @else_node.evaluate(context) : Vm::NilObject::NIL
      end
    end
  end
end

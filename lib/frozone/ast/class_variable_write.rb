require_relative 'node'

module Frozone
  module Ast
    class ClassVariableWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def to_s = "cvar=(#{@name}, #{@value_node})"

      def evaluate(context) = store(context, @value_node.evaluate(context))

      def store(context, value)
        current_class(context).set_class_var(@name, value)
        value
      end

      private

      def current_class(context)
        s = context.frame.the_self
        s.is_a?(Vm::ModuleObject) ? s : s.class_object
      end
    end
  end
end

require_relative 'node'

module Frozone
  module Ast
    class MethodCall < Node
      def initialize(name, receiver_node, param_nodes)
        @name = check_type("name", name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @param_nodes = check_array_type("param_nodes", param_nodes, Node)
      end

      def to_s
        "call(#{@name}, #{@receiver_node || '_'}, #{@param_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        #puts "          RPJ = MethodCall#evaluate method :#{@name} receiver #{@receiver_node}"
        receiver =
          if @receiver_node.nil?
            context.frame.the_self
          else
            @receiver_node.evaluate(context)
          end
      
        params = @param_nodes.map { |p| p.evaluate(context) }

        method = receiver.lookup_method(@name)
        #puts "          RPJ = MethodCall#evaluate method :#{@name} receiver #{receiver.class}"
        #puts "          RPJ =    method found is #{method}"

        # TODO - this is a runtime exception, not an assert
        raise "method :#{@name} not found - not yet doing missing_method" if method.nil?

        method.invoke(context, receiver, params)
      end
    end
  end
end

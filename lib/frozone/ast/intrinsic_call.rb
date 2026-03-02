require_relative '../vm/intrinsics'

module Frozone
  module Ast
    class IntrinsicCall
      def initialize(method_name, arg_nodes)
        @method = IntrinsicCall.method_for(method_name)
        @arg_nodes = arg_nodes
      end

      def to_s
        # @method.owner is class's eigenclass??? - not sure how to get the Class name
        "intrinsic[#{@method.name}](#{@arg_nodes.map(&:to_s).join(', ')})"
      end

      def execute(context)
        args = @arg_nodes.map { |arg_node| arg_node.execute(context) }

        @method.call(*args)
      end

      # TODO - thread safety
      Methods = {}

      def self.method_for(method_name)
        raise 'IntrinsicCall method_name must be a Symbol' unless method_name.class.equal?(Symbol)
        Methods[method_name] ||= ::Frozone::Vm::Intrinsics.method(method_name)
      end
    end
  end
end

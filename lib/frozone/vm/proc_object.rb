require_relative 'object_object'
require_relative '../ast/return'

module Frozone
  module Vm
    class ProcObject < ObjectObject
      def initialize(block_object, lambda: false)
        super(Core::OBJECT_CLASS.get_constant(:Proc))
        @block_object = block_object
        @lambda = lambda
      end

      def lambda? = @lambda

      def call(context, args, receiver: nil)
        if @lambda
          begin
            @block_object.invoke(context, args, receiver: receiver)
          rescue Ast::ReturnException => e
            e.value  # `return` in a lambda exits the lambda
          end
        else
          @block_object.invoke(context, args, receiver: receiver)
        end
      end

      def invoke(context, args, receiver: nil) = call(context, args, receiver: receiver)
    end
  end
end

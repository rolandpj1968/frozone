require_relative 'object_object'

module Frozone
  module Vm
    class ProcObject < ObjectObject
      def initialize(block_object, lambda: false)
        super(Core::OBJECT_CLASS.get_constant(:Proc))
        @block_object = block_object
        @lambda = lambda
      end

      def lambda? = @lambda
      def call(context, args, receiver: nil) = @block_object.invoke(context, args, receiver: receiver)
      def invoke(context, args, receiver: nil) = @block_object.invoke(context, args, receiver: receiver)
    end
  end
end

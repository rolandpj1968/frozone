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

      def block_object = @block_object
      def lambda? = @lambda

      def call(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil)
        # BlockObject#invoke already handles lambda return semantics (catches its own return,
        # re-raises ReturnExceptions destined for outer methods). Don't rescue here.
        @block_object.invoke(context, args, kw_args: kw_args, receiver: receiver, block: block, instance_eval_receiver: instance_eval_receiver)
      end

      def invoke(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil) = call(context, args, kw_args: kw_args, receiver: receiver, block: block, instance_eval_receiver: instance_eval_receiver)
    end
  end
end

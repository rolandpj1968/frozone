module Frozone
  module Vm
    # A native (host Ruby) block that can be used as a VM block.
    # Does not create a new frame - used for for-loop collection.
    class NativeBlock
      def initialize(&proc)
        @proc = proc
      end

      def invoke(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil, def_scope: nil)
        @proc.call(context, args)
        NilObject::NIL
      end

      def call(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil, def_scope: nil)
        invoke(context, args, kw_args: kw_args, receiver: receiver, block: block, instance_eval_receiver: instance_eval_receiver)
      end
    end
  end
end

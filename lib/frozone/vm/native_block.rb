module Frozone
  module Vm
    # A native (host Ruby) block that can be used as a VM block.
    # Does not create a new frame - used for for-loop collection.
    class NativeBlock
      def initialize(&proc)
        @proc = proc
      end

      def invoke(context, args, receiver: nil)
        @proc.call(context, args)
        NilObject::NIL
      end

      def call(context, args, receiver: nil)
        invoke(context, args, receiver: receiver)
      end
    end
  end
end

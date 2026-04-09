module Frozone
  module Vm
    # A native (host Ruby) block that can be used as a VM block.
    # Does not create a new frame - used for for-loop collection.
    class NativeBlock
      attr_reader :source_location, :parameters_override, :is_lambda
      attr_accessor :is_curried, :symbol_name

      def initialize(source_location: nil, parameters_override: nil, is_lambda: false, is_curried: false, symbol_name: nil, &proc)
        @proc = proc
        @source_location = source_location
        @parameters_override = parameters_override
        @is_lambda = is_lambda
        @is_curried = is_curried
        @symbol_name = symbol_name
      end

      def invoke(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil, def_scope: nil, current_method: nil, as_method: false, callee_name: nil, thread_boundary: false) = @proc.call(context, args, block: block) || NilObject::NIL

      def call(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil, def_scope: nil, current_method: nil, as_method: false, callee_name: nil, thread_boundary: false) = invoke(context, args, kw_args: kw_args, receiver: receiver, block: block, instance_eval_receiver: instance_eval_receiver)
    end
  end
end

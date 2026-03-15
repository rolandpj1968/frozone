require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    # Wraps a Frozone method bound to a specific receiver (the Method class in Ruby).
    class BoundMethodObject < ObjectObject
      attr_reader :raw_method, :bound_receiver, :bound_name, :bound_owner

      def initialize(method, name, receiver, owner)
        super(Core.method_class || Core::OBJECT_CLASS)
        @raw_method = method
        @bound_name = name
        @bound_receiver = receiver
        @bound_owner = owner
      end

      # Callable as a block (strict arity like a lambda/Method).
      def invoke(context, args, kw_args: {}, block: nil, **_kwargs)
        block_obj = block.is_a?(ProcObject) ? block.block_object : block
        block_obj = nil if block_obj.nil? || block_obj.is_a?(NilObject)
        @bound_receiver.dispatch(context, @bound_name, args, kw_args, block_obj)
      end

      def truthy? = true
    end
  end
end

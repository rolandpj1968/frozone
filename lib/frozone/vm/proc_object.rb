require_relative 'object_object'

module Frozone
  module Vm
    class ProcObject < ObjectObject
      def initialize(block_object, lambda: false)
        super(Core.proc_class)
        @block_object = block_object
        @lambda = lambda
      end

      def lambda? = @lambda
      def call(context, args) = @block_object.invoke(context, args)
    end
  end
end

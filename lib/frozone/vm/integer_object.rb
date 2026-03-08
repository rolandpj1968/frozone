require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class IntegerObject < ObjectObject
      def initialize(value)
        raise "IntegerObject must have an Integer value" unless value.is_a?(Integer)

        super(Core::INTEGER_CLASS)

        @value = value
      end

      def to_s = @value.to_s

      def raw = @value

      #
      # (Including) for Hash emulation using "native" Hash
      #
      # TODO work out how to do this properly - we need to call :hash, :eql? properly, but don't have the context
      #
      def hash = raw.hash
      def eql?(v) = v.is_a?(IntegerObject) && raw.eql?(v.raw)
    end
  end
end


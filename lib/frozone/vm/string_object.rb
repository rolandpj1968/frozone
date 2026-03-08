require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class StringObject < ObjectObject
      def initialize(value)
        raise "StringObject must have an String value" unless value.is_a?(String)

        super(Core::STRING_CLASS)

        @value = value.freeze
      end


      def raw = @value

      #
      # For Hash emulation using "native" Hash
      #
      # TODO work out how to do this properly - we need to call :hash, :eql? properly, but don't have the context
      #
      def hash = raw.hash
      def eql?(v) = v.is_a?(StringObject) && raw.eql?(v.raw)

      def to_s = @value
    end
  end
end


require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class HashObject < ObjectObject
      def initialize(elements)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        @elements = elements
      end

      def raw = @elements

      #
      # For Hash emulation using "native" Hash
      #
      # TODO work out how to do this properly - we need to call :hash, :eql? properly, but don't have the context
      #
      def hash = raw.hash
      def eql?(v) = v.is_a?(HashObject) && raw.eql?(v.raw)

      def to_s = "{#{@elements.map { |k, v| "#{k} => #{v}"}.join(', ')}}"
    end
  end
end


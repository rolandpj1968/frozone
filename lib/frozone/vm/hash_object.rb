require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class HashObject < ObjectObject
      # Wrapper to call the real #hash and #eql? methods on Frozone objects.
      # Used by the wrapped_elements hash for VM-correct key lookup.
      class KeyWrapper
        def initialize(key)
          @key = key
        end

        def unwrap = @key

        def hash = @key.dispatch(Fiber[:context], :hash, [], {}).raw
        def eql?(v) = v.is_a?(KeyWrapper) && @key.dispatch(Fiber[:context], :eql?, [v.unwrap], {}).truthy?
      end

      def initialize(elements)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        @elements = elements
      end

      # Returns the underlying Hash with original VM-object keys.
      def raw = @elements

      # VM-correct key lookup using KeyWrapper dispatch (requires Fiber[:context]).
      def [](key) = wrapped_elements[wrap(key)]

      def to_s = "{#{@elements.map { |k, v| "#{k} => #{v}"}.join(', ')}}"

      private

      def wrap(key) = KeyWrapper.new(key)

      def wrapped_elements
        @wrapped_elements ||= @elements.to_h { |k, v| [wrap(k), v] }
      end
    end
  end
end

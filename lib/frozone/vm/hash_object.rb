require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class HashObject < ObjectObject
      # Wrapper to call the real #hash and #eql? methods on Frozone objects.
      # Keys are always stored wrapped so mutations stay consistent.
      class KeyWrapper
        attr_reader :unwrap

        def initialize(key)
          @unwrap = key
        end

        def hash = @unwrap.dispatch(Fiber[:context], :hash, [], {}, nil, private_ok: true).raw
        def eql?(v) = v.is_a?(KeyWrapper) && (@unwrap.equal?(v.unwrap) || @unwrap.dispatch(Fiber[:context], :eql?, [v.unwrap], {}).truthy?)
      end

      attr_accessor :default_block, :default_value

      attr_accessor :ruby2_keywords

      def initialize(elements = {}, default_value: nil, default_block: nil)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        @elements = elements.to_h { |k, v| [wrap(k), v] }
        @default_value = default_value
        @default_block = default_block
        @ruby2_keywords = false
      end

      # Returns a Hash with the original VM-object keys (unwrapped).
      def raw = @elements.transform_keys(&:unwrap)

      # VM-correct key lookup via KeyWrapper dispatch (requires Fiber[:context]).
      def [](key) = @elements[wrap(key)]

      def []=(key, value)
        raise FrozoneException.make(:FrozenError, "can't modify frozen Hash: #{inspect_for_error}", receiver: self) if frozen_object?
        # String keys are dup'd (no singleton methods) and frozen, matching MRI behaviour.
        # Ruby Hash keeps the existing key object when updating; only the value changes.
        key = StringObject.new(key.raw.dup, frozen: true) if key.is_a?(StringObject) && !key.frozen_object?
        @elements[wrap(key)] = value
      end

      def size = @elements.size
      def key?(key) = @elements.key?(wrap(key))
      def delete(key) = @elements.delete(wrap(key))
      def clear_elements; @elements.clear; self; end

      def to_s = "{#{@elements.map { |k, v| "#{k.unwrap} => #{v}" }.join(', ')}}"

      private

      def wrap(key) = KeyWrapper.new(key)
    end
  end
end

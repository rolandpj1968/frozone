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

        def hash = @unwrap.dispatch(Fiber[:context], :hash, [], {}).raw
        def eql?(v) = v.is_a?(KeyWrapper) && @unwrap.dispatch(Fiber[:context], :eql?, [v.unwrap], {}).truthy?
      end

      attr_reader :default_block, :default_value

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
        @elements[wrap(key)] = value
      end

      def size = @elements.size
      def key?(key) = @elements.key?(wrap(key))
      def delete(key) = @elements.delete(wrap(key))

      def to_s = "{#{@elements.map { |k, v| "#{k.unwrap} => #{v}" }.join(', ')}}"

      private

      def wrap(key) = KeyWrapper.new(key)
    end
  end
end

require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class HashObject < ObjectObject
      # Wrapper to call the real #hash and #eql? methods on Frozone objects
      class KeyWrapper
        def initialize(key)
          @key = key
        end

        def unwrap = @key

        def hash = @key.dispatch(Fiber[:context], :hash, [], {}).raw
        def eql?(v) = @key.dispatch(Fiber[:context], :eql?, [v], {})
      end

      def initialize(elements)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        @elements = elements.to_h { |k, v| [wrap(k), v] }
      end

      def raw = @elements

      def to_s = "{#{@elements.map { |k, v| "#{k.unwrap} => #{v}"}.join(', ')}}"

      private

      def wrap(key) = KeyWrapper.new(key)
    end
  end
end


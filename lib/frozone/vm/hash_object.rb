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
          @hash = key.dispatch(Fiber[:context], :hash, [], {}, nil, private_ok: true).raw
        end

        def hash = @hash
        def eql?(v) = v.is_a?(KeyWrapper) && (@unwrap.equal?(v.unwrap) || @unwrap.dispatch(Fiber[:context], :eql?, [v.unwrap], {}).truthy?)
      end

      # Identity-based key wrapper for compare_by_identity hashes.
      class IdentityKeyWrapper
        attr_reader :unwrap

        def initialize(key)
          @unwrap = key
          @id = key.object_id
        end

        def hash = @id
        def eql?(v) = v.is_a?(IdentityKeyWrapper) && @unwrap.equal?(v.unwrap)
      end

      attr_accessor :default_block, :default_value, :compare_by_identity_flag

      attr_accessor :ruby2_keywords

      def initialize(elements = {}, default_value: nil, default_block: nil)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        @compare_by_identity_flag = false
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
        # String keys are dup'd (no singleton methods) and frozen, matching MRI behaviour,
        # UNLESS we're in compare_by_identity mode (identity means we keep the original object).
        key = StringObject.new(key.raw.dup, frozen: true) if !@compare_by_identity_flag && key.is_a?(StringObject) && !key.frozen_object?
        @elements[wrap(key)] = value
      end

      def compare_by_identity!
        return self if @compare_by_identity_flag
        raise FrozoneException.make(:FrozenError, "can't modify frozen Hash: #{inspect_for_error}", receiver: self) if frozen_object?
        @compare_by_identity_flag = true
        # Rebuild the hash table with identity-based keys
        old = @elements
        @elements = {}
        old.each { |kw, v| @elements[IdentityKeyWrapper.new(kw.unwrap)] = v }
        self
      end

      def reset_compare_by_identity!
        @compare_by_identity_flag = false
        self
      end

      def size = @elements.size
      def key?(key) = @elements.key?(wrap(key))
      def delete(key) = @elements.delete(wrap(key))
      def clear_elements = tap { @elements.clear }

      def to_s = "{#{@elements.map { |k, v| "#{k.unwrap} => #{v}" }.join(', ')}}"

      private

      def wrap(key) = @compare_by_identity_flag ? IdentityKeyWrapper.new(key) : KeyWrapper.new(key)
    end
  end
end

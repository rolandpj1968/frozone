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
        def eql?(v) = @unwrap.equal?(v.unwrap) || @unwrap.dispatch(Fiber[:context], :eql?, [v.unwrap], {}).truthy?
      end

      # Identity-based key wrapper for compare_by_identity hashes.
      class IdentityKeyWrapper
        attr_reader :unwrap

        def initialize(key)
          @unwrap = key
          @id = key.object_id
        end

        def hash = @id
        def eql?(v) = @unwrap.equal?(v.unwrap)
      end

      attr_accessor :default_block, :default_value
      attr_accessor :ruby2_keywords

      def initialize(elements = {}, default_value: nil, default_block: nil)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        # Set @compare_by_identity ivar at construction (canonical location
        # in core/4.0/hash.rb's #initialize, but Vm::HashObject.new bypasses
        # that path). wrap() reads it via get_ivar.
        @instance_variables_hash[:@compare_by_identity] = FalseObject::FALSE

        @elements = elements.to_h { |k, v| [wrap(k), v] }
        @default_value = default_value
        @default_block = default_block
        @ruby2_keywords = false
      end

      def compare_by_identity? = get_ivar(:@compare_by_identity).truthy?

      # Returns a Hash with the original VM-object keys (unwrapped).
      def raw = @elements.transform_keys { |k| k.unwrap }

      # VM-correct key lookup via KeyWrapper dispatch (requires Fiber[:context]).
      def [](key) = @elements[wrap(key)]

      def []=(key, value)
        raise FrozoneException.make(:FrozenError, "can't modify frozen Hash: #{inspect_for_error}", receiver: self) if frozen_object?
        # String keys are dup'd (no singleton methods) and frozen, matching MRI behaviour,
        # UNLESS we're in compare_by_identity mode (identity means we keep the original object).
        key = StringObject.new(key.raw.dup, frozen: true) if !compare_by_identity? && key.is_a?(StringObject) && !key.frozen_object?
        @elements[wrap(key)] = value
      end

      def compare_by_identity!
        old = @elements
        @elements = {}
        old.each { |kw, v| @elements[IdentityKeyWrapper.new(kw.unwrap)] = v }
        self
      end

      def reset_compare_by_identity!
        self
      end

      def key?(key) = @elements.key?(wrap(key))
      def delete(key) = @elements.delete(wrap(key))
      def clear_elements = tap { @elements.clear }

      private

      # @elements is the host hash backing for the interpreter's HashObject.
      # KeyWrapper bridges its host KeyEq to guest hash/eql? semantics.
      # Whether this body runs as MRI Ruby or as compiled cpp from a
      # self-built bin/frozone_box, the role is the same: interpreter
      # machinery. The wrap is always needed.
      def wrap(key)
        compare_by_identity? ? IdentityKeyWrapper.new(key) : KeyWrapper.new(key)
      end
    end
  end
end

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
        # MRI Hash collisions check via #eql?; cpp Hash's KeyEq uses op_eq_q (==).
        # Alias makes the wrapper work in both backends.
        alias == eql?
      end

      attr_accessor :default_block, :default_value
      attr_accessor :ruby2_keywords

      def initialize(elements = {}, default_value: nil, default_block: nil)
        raise "HashObject must have an Hash elements" unless elements.is_a?(Hash)

        super(Core::HASH_CLASS)

        # Seed the guest @compare_by_identity ivar to false — core/4.0/hash.rb's
        # #initialize sets it there, but `{}` literals and Vm::HashObject.new
        # callsites bypass that path. Initial mode is value-eq.
        @instance_variables_hash[:@compare_by_identity] = FalseObject::FALSE

        @elements = elements.to_h { |k, v| [KeyWrapper.new(k), v] }
        @default_value = default_value
        @default_block = default_block
        @ruby2_keywords = false
      end

      # Memberwise copy of the host-MRI ivars this class adds on top of
      # ObjectObject's base. Pointer-shared per MRI shallow-dup semantics
      # — Hash#dup layers Intrinsics.hash_clone_storage on top to give
      # the dup independent @elements storage.
      def copy_fields_from(source, eigenclass: nil, frozen: false)
        super
        @elements = source.elements_for_copy
        @default_value = source.default_value
        @default_block = source.default_block
        @ruby2_keywords = source.ruby2_keywords
        self
      end

      # Internal: the raw KeyWrapper-keyed Hash used by copy_fields_from
      # and by Intrinsics.hash_clone_storage. `raw` is the public reader
      # which unwraps keys; this returns the storage as-is.
      def elements_for_copy = @elements
      def replace_elements_for_copy!(new_elements) = (@elements = new_elements)
      protected :elements_for_copy, :replace_elements_for_copy!

      # Iterate (key, value) pairs with keys logically unwrapped.
      # With no block, returns an Enumerator so callers can chain
      # `.to_a` / `.map` / etc.
      def raw_each
        return enum_for(:raw_each) unless block_given?
        @elements.each { |k, v| yield __unwrap_key__(k), v }
      end

      # Returns a Hash with the original VM-object keys (unwrapped).
      # Allocating; prefer #raw_each when iterating.
      def raw = @elements.transform_keys { |k| __unwrap_key__(k) }

      def [](key, by_identity:) = @elements[wrap(key, by_identity)]

      def []=(key, value, by_identity:)
        raise FrozoneException.make(:FrozenError, "can't modify frozen Hash: #{inspect_for_error}", receiver: self) if frozen_object?
        # String keys are dup'd (no singleton methods) and frozen, matching MRI behaviour,
        # UNLESS we're in compare_by_identity mode (identity keeps the original object).
        key = StringObject.new(key.raw.dup, frozen: true) if !by_identity && key.is_a?(StringObject) && !key.frozen_object?
        @elements[wrap(key, by_identity)] = value
      end

      # Rebuild @elements after a compare-by-identity flip.
      # In identity mode we don't wrap: host MRI Hash's default key semantics
      # (object-identity #hash + #equal? #eql?) already give us what we want.
      # In value-eq mode we wrap with KeyWrapper to bridge to guest #hash/#eql?.
      def set_identity_mode!(by_identity)
        old = @elements
        @elements = {}
        if by_identity
          old.each { |k, v| @elements[__unwrap_key__(k)] = v }
        else
          old.each { |k, v| @elements[KeyWrapper.new(__unwrap_key__(k))] = v }
        end
        self
      end

      def key?(key, by_identity:) = @elements.key?(wrap(key, by_identity))
      def delete(key, by_identity:) = @elements.delete(wrap(key, by_identity))
      def clear_elements = tap { @elements.clear }
      # Host-side count helper used by hash_size intrinsic bridge.
      def size = @elements.size

      # Host-side predicate used by intrinsic bridges that need to know the
      # current compare-by-identity mode (e.g. hash_transform_keys_bang's
      # rebuild loop). Reads the guest @compare_by_identity ivar, which is
      # the canonical truth (set/cleared by core/4.0/hash.rb).
      def compare_by_identity? = get_ivar(:@compare_by_identity).truthy?

      private

      # @elements is the host hash backing for the interpreter's HashObject.
      # In value-eq mode we wrap with KeyWrapper to bridge host KeyEq to
      # guest #hash/#eql?. In identity mode we store the raw key — MRI's
      # default host Hash KeyEq (object_id.hash + equal?) gives identity
      # semantics for guest Vm objects without any bridging.
      def wrap(key, by_identity)
        by_identity ? key : KeyWrapper.new(key)
      end

      # Pull the logical (guest-level) key from a host @elements key,
      # which is either a KeyWrapper (value-eq mode) or the raw key
      # (identity mode).
      def __unwrap_key__(k) = k.is_a?(KeyWrapper) ? k.unwrap : k
    end
  end
end

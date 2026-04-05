# Immutable value object representing a type in the TI lattice.
#
# Replaces the ad-hoc mix of Symbols (:i64, :f64, :unknown) and frozen
# Hashes ({class: :X, nullable: true, elem: ...}) with a single type
# that has well-defined query methods.
#
# The lattice ordering (⊑) and join (⊔) operation are NOT on this class —
# they require class hierarchy context and live on the Lattice / TypeInference.

module Frozone
  module Compiler
    class Type
      attr_reader :kind, :class_name, :elem, :key, :val

      def initialize(kind, class_name: nil, nullable: false, exact: false, elem: nil, key: nil, val: nil)
        @kind = kind
        @class_name = class_name
        @nullable = nullable
        @exact = exact
        @elem = elem
        @key = key
        @val = val
        freeze
      end

      # -- Predicates ----------------------------------------------------------

      def bottom? = @kind == :bottom
      def i64? = @kind == :i64
      def f64? = @kind == :f64
      def raw? = @kind == :i64 || @kind == :f64
      def array_scalar? = @kind == :array_scalar
      def class_type? = @kind == :class_type
      def nullable? = @nullable
      def exact? = @exact

      def numeric?
        raw? || (class_type? && %i[Integer Float Numeric].include?(@class_name))
      end

      def array?
        class_type? && @class_name == :Array
      end

      def hash_type?
        class_type? && @class_name == :Hash
      end

      def nil_type?
        class_type? && @class_name == :NilClass
      end

      # -- Equality (value semantics) ------------------------------------------

      def ==(other)
        return false unless other.is_a?(Type)
        @kind == other.kind &&
          @class_name == other.class_name &&
          @nullable == other.nullable? &&
          @exact == other.exact? &&
          @elem == other.elem &&
          @key == other.key &&
          @val == other.val
      end

      alias eql? ==

      def hash
        [@kind, @class_name, @nullable, @exact, @elem, @key, @val].hash
      end

      # -- Display -------------------------------------------------------------

      def inspect
        case @kind
        when :bottom then "Type::BOTTOM"
        when :i64 then "Type::I64"
        when :f64 then "Type::F64"
        when :array_scalar
          "Type::#{@elem&.i64? ? 'ARRAY_I64' : 'ARRAY_F64'}"
        when :class_type
          parts = ["Type.of(:#{@class_name}"]
          parts << "nullable: true" if @nullable
          parts << "exact: true" if @exact
          parts << "elem: #{@elem.inspect}" if @elem
          parts << "key: #{@key.inspect}" if @key
          parts << "val: #{@val.inspect}" if @val
          parts.join(", ") + ")"
        else
          "Type(#{@kind})"
        end
      end

      alias to_s inspect

      # -- Singletons ----------------------------------------------------------

      BOTTOM = new(:bottom)
      I64 = new(:i64)
      F64 = new(:f64)
      ARRAY_I64 = new(:array_scalar, elem: I64)
      ARRAY_F64 = new(:array_scalar, elem: F64)

      # Commonly used class types — interned for identity and GC pressure.
      NIL_CLASS = new(:class_type, class_name: :NilClass)
      TRUE_CLASS = new(:class_type, class_name: :TrueClass)
      FALSE_CLASS = new(:class_type, class_name: :FalseClass)
      STRING = new(:class_type, class_name: :String)
      SYMBOL = new(:class_type, class_name: :Symbol)
      INTEGER = new(:class_type, class_name: :Integer)
      FLOAT = new(:class_type, class_name: :Float)
      NUMERIC = new(:class_type, class_name: :Numeric)
      ARRAY = new(:class_type, class_name: :Array)
      HASH = new(:class_type, class_name: :Hash)
      OBJECT = new(:class_type, class_name: :Object)
      BASIC_OBJECT = new(:class_type, class_name: :BasicObject)
      RANGE = new(:class_type, class_name: :Range)
      REGEXP = new(:class_type, class_name: :Regexp)
      RANDOM = new(:class_type, class_name: :Random)
      PROC = new(:class_type, class_name: :Proc)

      # -- Factories -----------------------------------------------------------

      class << self
        def of(class_name, nullable: false, exact: false)
          # Return interned singletons for common non-decorated types.
          if !nullable && !exact
            case class_name
            when :NilClass then return NIL_CLASS
            when :TrueClass then return TRUE_CLASS
            when :FalseClass then return FALSE_CLASS
            when :String then return STRING
            when :Symbol then return SYMBOL
            when :Integer then return INTEGER
            when :Float then return FLOAT
            when :Numeric then return NUMERIC
            when :Array then return ARRAY
            when :Hash then return HASH
            when :Object then return OBJECT
            when :BasicObject then return BASIC_OBJECT
            when :Range then return RANGE
            when :Regexp then return REGEXP
            when :Random then return RANDOM
            when :Proc then return PROC
            end
          end
          new(:class_type, class_name: class_name, nullable: nullable, exact: exact)
        end

        def array(elem:)
          new(:class_type, class_name: :Array, elem: elem)
        end

        def hash_type(key: nil, val: nil)
          h = new(:class_type, class_name: :Hash, key: key, val: val)
          (key.nil? && val.nil?) ? HASH : h
        end

        # Nullable variant of an existing type.
        def nullable(type)
          return type if type.nullable?
          return type if type.nil_type?
          case type.kind
          when :bottom then NIL_CLASS
          when :i64 then of(:Integer, nullable: true)
          when :f64 then of(:Float, nullable: true)
          when :class_type
            new(:class_type, class_name: type.class_name, nullable: true,
                exact: type.exact?, elem: type.elem, key: type.key, val: type.val)
          else type
          end
        end
      end

      # -- Conversion from legacy representation ------------------------------

      # Convert from the old Symbol/:Hash representation used pre-refactor.
      def self.from_legacy(v)
        case v
        when Type then v
        when :unknown then BOTTOM
        when :i64 then I64
        when :f64 then F64
        when :array_i64 then ARRAY_I64
        when :array_f64 then ARRAY_F64
        when ::Hash
          cls = v[:class]
          nullable = v[:nullable] || false
          exact = v[:exact] || false
          elem = v.key?(:elem) ? from_legacy(v[:elem]) : nil
          key = v.key?(:key) ? from_legacy(v[:key]) : nil
          val = v.key?(:val) ? from_legacy(v[:val]) : nil
          if elem || key || val
            new(:class_type, class_name: cls, nullable: nullable, exact: exact,
                elem: elem, key: key, val: val)
          else
            of(cls, nullable: nullable, exact: exact)
          end
        when nil then BOTTOM
        else BOTTOM
        end
      end

      # Convert back to the old representation for downstream consumers
      # that haven't been migrated yet.
      def to_legacy
        case @kind
        when :bottom then :unknown
        when :i64 then :i64
        when :f64 then :f64
        when :array_scalar then @elem&.i64? ? :array_i64 : :array_f64
        when :class_type
          h = { class: @class_name }
          h[:nullable] = true if @nullable
          h[:exact] = true if @exact
          h[:elem] = @elem.to_legacy if @elem
          h[:key] = @key.to_legacy if @key
          h[:val] = @val.to_legacy if @val
          h.freeze
        end
      end

      # -- Helpers for lattice operations (used by TypeInference#join) ---------

      # The boxed class name for this type (for LCA computation).
      def boxed_class_name
        case @kind
        when :i64 then :Integer
        when :f64 then :Float
        when :array_scalar then :Array
        when :class_type then @class_name
        else :Object
        end
      end

      # Promote to a class type (for normalisation before LCA).
      def to_class_type
        case @kind
        when :i64 then INTEGER
        when :f64 then FLOAT
        when :array_scalar
          @elem&.i64? ? Type.array(elem: I64) : Type.array(elem: F64)
        when :class_type then self
        else OBJECT
        end
      end

      # Merge collection parameters (elem, key, val) with another type
      # of the same base class. Used in join when both sides are the same class.
      def merge_params(other)
        new_nullable = @nullable || other.nullable?
        new_elem = merge_param(@elem, other.elem)
        new_key = merge_param(@key, other.key)
        new_val = merge_param(@val, other.val)
        if new_nullable == @nullable && new_elem.equal?(@elem) &&
           new_key.equal?(@key) && new_val.equal?(@val)
          self
        elsif new_nullable == other.nullable? && new_elem.equal?(other.elem) &&
              new_key.equal?(other.key) && new_val.equal?(other.val)
          other
        else
          Type.new(:class_type, class_name: @class_name, nullable: new_nullable,
                   exact: @exact && other.exact?,
                   elem: new_elem, key: new_key, val: new_val)
        end
      end

      private

      # Merge one collection param: present on both → needs join (caller handles),
      # present on one → take it, absent on both → nil.
      def merge_param(a, b)
        if a && b then :needs_join  # sentinel — caller must join(a, b)
        elsif a then a
        elsif b then b
        end
      end
    end
  end
end

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
      attr_reader :kind, :class_name, :elem, :key, :val, :int_min, :int_max

      def initialize(kind, class_name: nil, nullable: false, exact: false, elem: nil, key: nil, val: nil, int_min: nil, int_max: nil)
        @kind = kind
        @class_name = class_name
        @nullable = nullable
        @exact = exact
        @elem = elem
        @key = key
        @val = val
        # int_min / int_max are optional bounds tracked on :i64 types
        # (and recursively on :array_scalar elem types). nil = full
        # Int64 range. When set, both must be set together. They get
        # populated from integer literals and propagated through a few
        # arithmetic operations in TI; downstream consumers (codegen)
        # can use them to pick narrower native storage types like
        # Bytes / Array(UInt8) instead of Array(Int64).
        @int_min = int_min
        @int_max = int_max
        freeze
      end

      # Returns [min, max] if this is a bounded integer type, else nil.
      def int_bounds
        return nil unless @kind == :i64 && @int_min && @int_max
        [@int_min, @int_max]
      end

      # The narrowest unsigned/signed Crystal integer type that fits
      # this type's known bounds. nil if bounds aren't tracked.
      def narrowest_int_type
        return nil unless (b = int_bounds)
        min, max = b
        if min >= 0
          return "UInt8"  if max <= 0xff
          return "UInt16" if max <= 0xffff
          return "UInt32" if max <= 0xffff_ffff
          return "UInt64"
        end
        return "Int8"  if min >= -0x80         && max <= 0x7f
        return "Int16" if min >= -0x8000       && max <= 0x7fff
        return "Int32" if min >= -0x8000_0000  && max <= 0x7fff_ffff
        "Int64"
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

      def numeric? = raw? || (class_type? && %i[Integer Float Numeric].include?(@class_name))
      def array? = class_type? && @class_name == :Array
      # Any array form: scalar-elem flat array OR class_type Array.
      def array_like? = array_scalar? || array?
      def hash_type? = class_type? && @class_name == :Hash
      def nil_type? = class_type? && @class_name == :NilClass

      # -- Codegen queries (C++ backend, union-representation decisions) -------
      #
      # These answer "what does the runtime representation look like from
      # the collector's point of view?" — NOT lattice questions. They live
      # on Type rather than codegen so codegen doesn't re-discover structural
      # info by regex on rendered strings.

      # Classes whose runtime representation in C++ holds no gc_refs,
      # regardless of internal byte/pointer state. RubyString's byte vector
      # is malloc-backed but holds no gc_refs; RubySymbol is an interned
      # pointer into a static table; primitives are primitives.
      VALUE_TYPED_BUILTINS = %i[
        Integer Float Numeric NilClass TrueClass FalseClass
        String Symbol Range Regexp Proc Tree
      ].to_set.freeze

      # Built-in runtime types that the emitter represents as raw Ruby_X*
      # but that don't participate in Dustman's tracing — see
      # cpp_emitter.rb's NON_GC_BUILTIN_CLASSES.
      NON_GC_BUILTIN_CLASSES = %i[Random].to_set.freeze

      # Does this Type's runtime representation hold any gc_refs that
      # Dustman needs to trace? Container element/key/val types recurse.
      def contains_gc_refs?
        case @kind
        when :bottom, :i64, :f64 then false
        when :array_scalar
          @elem ? @elem.contains_gc_refs? : false
        when :class_type
          return false if VALUE_TYPED_BUILTINS.include?(@class_name)
          return false if NON_GC_BUILTIN_CLASSES.include?(@class_name)
          case @class_name
          when :Array then @elem ? @elem.contains_gc_refs? : false
          when :Hash  then (@key && @key.contains_gc_refs?) || (@val && @val.contains_gc_refs?) || false
          when nil    then false                        # "auto" — conservatively untyped
          else true                                     # Object, BasicObject, user class
          end
        end
      end

      # Can a value of this Type be passed through coerce_to_ref<RubyObject>()
      # at the C++ level? True for anything the runtime helper knows how to
      # upcast or box (pointers, value-typed RubyObject subclasses, primitives
      # via boxed wrappers, RubySymbol via Ruby_Symbol, nil). False for types
      # that escape the runtime's handled set (NON_GC_BUILTIN class pointers
      # can't upcast to RubyObject because those runtime classes don't
      # inherit from it).
      def ruby_object_convertible?
        case @kind
        when :bottom, :i64, :f64 then true
        when :array_scalar then true
        when :class_type
          return false if NON_GC_BUILTIN_CLASSES.include?(@class_name)
          true
        end
      end

      # Is this a user-defined class pointer — i.e. one that renders as
      # `Ruby_<Name>*` in the emitter and participates in Dustman tracing
      # as a gc_ref? Excludes value-typed builtins (String, Symbol, etc.),
      # NON_GC_BUILTIN classes (Random), Object/BasicObject, Array/Hash,
      # and unresolved class_type (class_name == nil, renders as "auto").
      #
      # Used when the answer "do we wrap this in gc_ref / trace it?" matters
      # — Tracer FieldList membership, boxing decisions.
      def user_class_pointer?
        return false unless class_type?
        return false if @class_name.nil?
        return false if VALUE_TYPED_BUILTINS.include?(@class_name)
        return false if NON_GC_BUILTIN_CLASSES.include?(@class_name)
        return false if %i[Object BasicObject Array Hash].include?(@class_name)
        true
      end

      # The "universal boxed any" type — renders as `RubyObject*` (or
      # `gc_ref<RubyObject>` under wrapper). Used as the union representation
      # for mixed reference types and the target slot for coerce_to_ref.
      def object_root?
        class_type? && %i[Object BasicObject].include?(@class_name)
      end

      # Does this Type carry enough information to render as something other
      # than `auto`? :bottom kind always renders auto; an unresolved
      # class_type (class_name nil) does too. Everything else renders to
      # something concrete. Used by ti_type to filter out "TI knew there was
      # a slot but couldn't say what" results.
      def concrete?
        return false if bottom?
        return false if class_type? && @class_name.nil?
        true
      end

      # Does this Type render as a `T*` pointer in the C++ output? Covers
      # user classes, Object/BasicObject, AND NON_GC_BUILTIN_CLASSES (e.g.
      # Random — emits as `Ruby_Random*` even though it isn't Dustman-
      # managed). Used for `.` vs `->` dispatch, pointer-local registration,
      # and explicit-return-type picks — anywhere the question is "does the
      # emitted expression have pointer syntax?" rather than "is this a
      # gc_ref?".
      def emitted_as_pointer?
        return false unless class_type?
        return false if @class_name.nil?
        return false if VALUE_TYPED_BUILTINS.include?(@class_name)
        return false if %i[Array Hash].include?(@class_name)
        true
      end

      # Does this Type render as `std::optional<T>` in to_cpp? True for
      # nullable raw numerics (:i64 / :f64) AND nullable numeric class_types
      # (Integer / Float / Numeric). Non-numeric nullable class_types use
      # pointer nil, not std::optional — see class_to_cpp.
      def renders_as_optional?
        return false unless nullable?
        i64? || f64? || (class_type? && %i[Integer Float Numeric].include?(@class_name))
      end

      # Pick the C++ representation for a union of participant Types.
      # Called at union-entry sites (hash literal V-type, ternary meet,
      # &&/|| result type, etc.) where TI's LCA joined heterogeneous classes
      # at :Object (or where the emitter combines distinct operand types).
      #
      #   - any participant contains gc_refs → "RubyObject*" (MUST — precise
      #     tracing can't see through std::any's type erasure).
      #   - else all are RubyObject-convertible → "RubyObject*"
      #     (consistent with TI's LCA decision; primitives get boxed via
      #     coerce_to_ref's Ruby_Integer/Float/Boolean boxes).
      #   - else → "std::any" as last-resort. Only reachable via
      #     NON_GC_BUILTIN classes (Random) in a mixed union — a rare,
      #     safe-under-current-GC case.
      def self.union_representation(types)
        return "RubyObject*" if types.any?(&:contains_gc_refs?)
        return "RubyObject*" if types.all?(&:ruby_object_convertible?)
        "std::any"
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
          @val == other.val &&
          @int_min == other.int_min &&
          @int_max == other.int_max
      end

      alias eql? ==

      def hash = [@kind, @class_name, @nullable, @exact, @elem, @key, @val, @int_min, @int_max].hash

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

      # -- Crystal codegen -----------------------------------------------------

      # Ruby class name → Crystal class name mapping.
      # Must match CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.
      CRYSTAL_CLASS_NAMES = {
        Object: 'RubyGenericObject', Integer: 'RubyInteger', Float: 'RubyFloat',
        String: 'RubyString', Symbol: 'RubySymbol', Array: 'RubyArray',
        Hash: 'RubyHash', NilClass: 'RubyNil', Numeric: 'RubyObject',
        Struct: 'RubyObject', Math: 'RubyMath', Random: 'Ruby_Random',
        Proc: 'RubyProc',
      }.freeze

      # Crystal source string for this type. Live-value version: i64
      # always renders as Int64 because the value may participate in
      # arithmetic that would overflow a narrower type.
      def to_crystal
        case @kind
        when :i64 then 'Int64'
        when :f64 then 'Float64'
        when :array_scalar then "Array(#{@elem.to_crystal_storage})"
        when :class_type then class_to_crystal
        else 'RubyObject'
        end
      end

      def to_cpp(wrapper: nil)
        case @kind
        when :bottom then "auto"
        when :i64 then nullable? ? "std::optional<int64_t>" : "int64_t"
        when :f64 then nullable? ? "std::optional<double>" : "double"
        when :array_scalar
          elem_cpp = @elem&.i64? ? "int64_t" : "double"
          "RubyArray<#{elem_cpp}>"
        when :class_type then class_to_cpp(wrapper: wrapper)
        else "auto"
        end
      end

      # Emission-wrapped variants. `to_cpp_ref` renders pointer-to-user-class
      # types as `gc_ref<Ruby_X>` (ivar / param / return positions), and
      # `to_cpp_local` as `gc_local<Ruby_X>` (stack-local declarations).
      # NON_GC_BUILTIN classes (Random) render as bare `Ruby_X*` under both
      # — they aren't Dustman-managed. Container element/key/val types
      # recurse so nested pointer shapes propagate correctly.
      def to_cpp_ref   = to_cpp(wrapper: "gc_ref")
      def to_cpp_local = to_cpp(wrapper: "gc_local")

      def class_to_cpp(wrapper: nil)
        case @class_name
        when :Integer, :Numeric
          nullable? ? "std::optional<int64_t>" : "int64_t"
        when :Float
          nullable? ? "std::optional<double>" : "double"
        when :String then "RubyString"
        when :Symbol then "RubySymbol"
        when :Array
          elem_cpp = @elem ? @elem.to_cpp(wrapper: wrapper) : "int64_t"
          elem_cpp = "int64_t" if elem_cpp == "auto"
          "RubyArray<#{elem_cpp}>"
        when :Hash
          key_cpp = @key ? @key.to_cpp(wrapper: wrapper) : "RubySymbol"
          key_cpp = "RubySymbol" if key_cpp == "auto"
          val_cpp = @val ? @val.to_cpp(wrapper: wrapper) : "int64_t"
          val_cpp = "int64_t" if val_cpp == "auto"
          "RubyHash<#{key_cpp}, #{val_cpp}>"
        when :NilClass then "RubyNil"
        when :TrueClass, :FalseClass then "bool"
        when nil then "auto"
        when :Object, :BasicObject
          wrapper ? "#{wrapper}<RubyObject>" : "RubyObject*"
        when :Tree
          # Runtime-built-in tree node (RubyTree) — value-typed with
          # shared_ptr-backed storage, so no wrapper / no pointer. Used for
          # the `[nil_or_f, nil_or_f]` tree-literal pattern (see
          # tree_node_literal? in TI + codegen).
          "RubyTree"
        else
          if wrapper && !NON_GC_BUILTIN_CLASSES.include?(@class_name)
            "#{wrapper}<Ruby_#{@class_name}>"
          else
            "Ruby_#{@class_name}*"
          end
        end
      end

      # Storage-context version of to_crystal: for i64 types with
      # known bounds, returns the narrowest Crystal integer type
      # that fits (UInt8 / Int16 / etc.). Used for array element
      # types and other contexts where the value is read but never
      # the live operand of arithmetic — the read site widens to
      # Int64 on access.
      def to_crystal_storage
        case @kind
        when :i64 then narrowest_int_type || 'Int64'
        when :f64 then 'Float64'
        when :array_scalar then "Array(#{@elem.to_crystal_storage})"
        when :class_type
          if array? && @elem&.native?
            "Array(#{@elem.to_crystal_storage})"
          else
            class_to_crystal
          end
        else 'RubyObject'
        end
      end

      # Is this a Crystal-native type (not a RubyObject subtype)?
      # Native types need raw emission, can't be passed where RubyObject expected.
      def native? = raw? || array_scalar? || (array? && @elem&.native?)

      # Can this type appear in a generic (all-RubyObject) overload?
      def generic_compatible? = !native?

      private

      def class_to_crystal
        # Array elements are inherently storage — the element type may
        # have tighter bounds than Int64 and we want the Crystal Array
        # type to reflect that (Array(UInt8) for byte tables etc).
        return "Array(#{@elem.to_crystal_storage})" if array? && @elem&.native?
        CRYSTAL_CLASS_NAMES[@class_name] || "Ruby_#{@class_name}"
      end

      public

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

        def array(elem:) = new(:class_type, class_name: :Array, elem: elem)

        # Bounded I64 factory: Type.i64_bounded(min, max). Used by TI
        # for integer literals (where min == max == the literal value)
        # and by the join operator for unioning bounded i64 types.
        def i64_bounded(min, max)
          return I64 if min.nil? || max.nil?
          new(:i64, int_min: min, int_max: max)
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

      # -- Codegen-side type derivation from a TI Type ------------------------

      # Map a Type from the inference layer to a codegen-friendly Type:
      #   - Raw scalars and array_scalars pass through
      #   - Class types Array(T) with native elem → nested array (Type.array)
      #   - User class types in user_class_names → Type.of(class_name)
      #   - Builtin Hash / Proc / Array → Type.of(...)
      #   - Other class types (String, Integer, etc.), nil, BOTTOM → Type::BOTTOM
      #     (renders as RubyObject in codegen).
      #
      # Returns the same shape that codegen consumers want — replaces
      # The codegen-side counterpart to TI's lattice — narrows TI types into the
      # subset that the Crystal backend cares about.
      def self.from_ti(ty, user_class_names: Set.new)
        return BOTTOM if ty.nil? || ty.bottom?
        return ty if ty.raw? || ty.array_scalar?
        return BOTTOM unless ty.class_type?
        case ty.class_name
        when :Array
          if ty.elem
            mapped_elem = from_ti(ty.elem, user_class_names: user_class_names)
            mapped_elem.native? ? Type.array(elem: mapped_elem) : BOTTOM
          else
            BOTTOM
          end
        when :Hash, :Proc then of(ty.class_name)
        when :String, :Symbol, :Integer, :Float,
             :NilClass, :TrueClass, :FalseClass,
             :Object, :Numeric, :BasicObject, :Comparable, :Enumerable
          BOTTOM
        else
          cls = ty.class_name
          if user_class_names.include?(cls) || CRYSTAL_CLASS_NAMES.key?(cls)
            of(cls)
          else
            BOTTOM
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

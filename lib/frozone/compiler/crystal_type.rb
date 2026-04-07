require_relative 'type'

# Structured Crystal type representation for the AoT compiler.
#
# Instead of string-matching on "Array(Int64)" or "RubyObject", the type
# system uses a recursive data structure that supports N-level nesting
# naturally. One representation, one set of queries.
#
# Type values:
#   :i64                         → Int64
#   :f64                         → Float64
#   [:array, :i64]               → Array(Int64)
#   [:array, [:array, :i64]]     → Array(Array(Int64))
#   :ruby_object                 → RubyObject (boxed, untyped)
#   [:ruby_class, :Foo]          → Ruby_Foo (user class)
#   [:ruby_builtin, :Array]      → RubyArray
#   [:ruby_builtin, :Hash]       → RubyHash
#   [:ruby_builtin, :Proc]       → RubyProc
#   [:ruby_builtin, :String]     → RubyString

module Frozone
  module Compiler
    module CrystalType
      # Is this a Crystal-native type (not a RubyObject subtype)?
      # Native types need raw emission and can't be passed where RubyObject is expected.
      def self.native?(ty)
        case ty
        when :i64, :f64 then true
        when Array then ty[0] == :array
        else false
        end
      end

      # Is this a scalar (Int64/Float64)?
      def self.scalar?(ty) = Type.raw?(ty)
      # Extract the raw scalar type (:i64/:f64) or nil.
      def self.raw(ty)
        return ty if ty.is_a?(Type) && ty.raw?
        return Type::I64 if ty == :i64
        return Type::F64 if ty == :f64
        nil
      end
      # Is this an array type at any depth?
      def self.array?(ty) = ty.is_a?(Array) && ty[0] == :array
      # Element type of an array type, or nil.
      def self.elem(ty) = array?(ty) ? ty[1] : nil
      # Can this type be used as a param in a generic (RubyObject) overload?
      # Native types can't — they need their own typed overload.
      def self.generic_compatible?(ty) = !native?(ty)

      # Convert to Crystal source string.
      def self.to_crystal(ty)
        return ty.to_crystal if ty.is_a?(Type)
        case ty
        when :i64 then 'Int64'
        when :f64 then 'Float64'
        when :ruby_object then 'RubyObject'
        when Array
          case ty[0]
          when :array then "Array(#{to_crystal(ty[1])})"
          when :ruby_class then CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[ty[1]] || "Ruby_#{ty[1]}"
          when :ruby_builtin
            case ty[1]
            when :Array  then 'RubyArray'
            when :Hash   then 'RubyHash'
            when :Proc   then 'RubyProc'
            when :String then 'RubyString'
            else "Ruby#{ty[1]}"
            end
          else 'RubyObject'
          end
        else 'RubyObject'
        end
      end

      # Convert from a Type value object to a CrystalType.
      def self.from_type(ty, user_class_names: Set.new)
        return :ruby_object if ty.nil? || ty.bottom?
        return :i64 if ty.i64?
        return :f64 if ty.f64?
        if ty.array_scalar?
          return [:array, ty.elem.i64? ? :i64 : :f64]
        end
        return :ruby_object unless ty.class_type?
        case ty.class_name
        when :Array
          if ty.elem
            elem = from_type(ty.elem, user_class_names: user_class_names)
            native?(elem) ? [:array, elem] : :ruby_object
          else
            :ruby_object
          end
        when :Hash   then [:ruby_builtin, :Hash]
        when :Proc   then [:ruby_builtin, :Proc]
        when :String, :Symbol, :Integer, :Float,
             :NilClass, :TrueClass, :FalseClass,
             :Object, :Numeric, :BasicObject, :Comparable, :Enumerable
          :ruby_object
        else
          cls = ty.class_name
          if user_class_names.include?(cls) || CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(cls)
            [:ruby_class, cls]
          else
            :ruby_object
          end
        end
      end

      # Legacy adapter — convert from old Symbol/Hash representation.
      def self.from_ti(ty, user_class_names: Set.new)
        from_type(Type.from_legacy(ty), user_class_names: user_class_names)
      end
    end
  end
end

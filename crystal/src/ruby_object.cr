# RubyObject — abstract base class for all Ruby value types.
#
# Every Ruby value (Integer, Float, String, Symbol, Array, Hash, nil, true,
# false, …) inherits from this class, mirroring MRI's VALUE hierarchy.
#
# Hash/equality routing:
#   Crystal's Hash(RubyObject, RubyObject) requires #hash : UInt64 and
#   #==(other) : Bool on the key type.  Each subclass overrides both.
#   The default implementations here use object identity, which is correct
#   for types that don't define value equality (e.g. arbitrary objects).
#
# Note on Crystal pseudo-methods:
#   `!` and `nil?` are compiler built-ins that cannot be overridden on
#   arbitrary classes.  We expose `not` and `ruby_nil?` instead; the
#   transpiler maps them to the right Ruby method names.

abstract class RubyObject
  # -------------------------------------------------------------------------
  # String representation
  # -------------------------------------------------------------------------
  abstract def to_s    : String
  abstract def inspect : String

  # -------------------------------------------------------------------------
  # Equality and hashing  (subclasses override for value equality)
  # -------------------------------------------------------------------------
  def ==(other : RubyObject) : Bool
    same?(other)   # identity by default
  end

  def !=(other : RubyObject) : Bool
    !(self == other)
  end

  # Crystal's Hash uses #hash : UInt64 for bucket placement.
  # Default: identity hash via object_id.
  def hash : UInt64
    object_id
  end

  # -------------------------------------------------------------------------
  # Ruby truthiness  (nil and false override to return false)
  # -------------------------------------------------------------------------
  def truthy? : Bool
    true
  end

  # -------------------------------------------------------------------------
  # Type predicates
  # -------------------------------------------------------------------------
  def ruby_nil?  : Bool; false; end
  def ruby_bool? : Bool; false; end

  # -------------------------------------------------------------------------
  # Logical negation (Crystal `!` can't be overridden; use `not`)
  # -------------------------------------------------------------------------
  def not : RubyObject
    # default: any truthy object negated is false
    truthy? ? RubyBool::FALSE : RubyBool::TRUE
  end
end

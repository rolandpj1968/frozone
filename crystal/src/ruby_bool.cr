# RubyBool — Crystal implementation of Ruby's true and false singletons.
#
# Ruby's true and false are singleton objects. This class enforces that
# by making the constructor private and providing two constants.

require "./ruby_object"

class RubyBool < RubyObject
  # The two singleton instances.
  TRUE  = new(true)
  FALSE = new(false)

  getter value : Bool

  # -------------------------------------------------------------------------
  # Private constructor — use TRUE or FALSE
  # -------------------------------------------------------------------------

  private def initialize(@value : Bool)
  end

  # -------------------------------------------------------------------------
  # Core operations
  # -------------------------------------------------------------------------

  def to_s : String
    @value.to_s
  end

  def inspect : String
    @value.to_s
  end

  def ==(other : RubyBool) : Bool
    @value == other.value
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def ==(other) : Bool
    false
  end

  # -------------------------------------------------------------------------
  # RubyObject overrides
  # -------------------------------------------------------------------------

  def truthy? : Bool
    @value
  end

  def ruby_bool? : Bool
    true
  end

  # Logical AND — both must be true.
  def &(other : RubyBool) : RubyBool
    (@value && other.value) ? TRUE : FALSE
  end

  # Logical OR — at least one must be true.
  def |(other : RubyBool) : RubyBool
    (@value || other.value) ? TRUE : FALSE
  end

  # Logical XOR — exactly one must be true.
  def ^(other : RubyBool) : RubyBool
    (@value ^ other.value) ? TRUE : FALSE
  end

  # not: logical negation — returns the opposite singleton.
  def not : RubyBool
    @value ? FALSE : TRUE
  end

  # -------------------------------------------------------------------------
  # Hash
  # -------------------------------------------------------------------------

  def hash : UInt64
    @value ? 1_u64 : 0_u64
  end
end

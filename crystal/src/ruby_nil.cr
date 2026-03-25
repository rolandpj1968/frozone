# RubyNil — Crystal implementation of Ruby's nil singleton.
#
# nil is the one-and-only null value in Ruby. This class uses the singleton
# pattern: INSTANCE is the sole RubyNil object. The constructor is private
# to enforce this invariant.

require "./ruby_bool"
require "./ruby_integer"
require "./ruby_float"

class RubyNil < RubyObject
  # The one and only nil value.
  INSTANCE = new

  # -------------------------------------------------------------------------
  # Private constructor — use INSTANCE
  # -------------------------------------------------------------------------

  private def initialize
  end

  # -------------------------------------------------------------------------
  # Core operations
  # -------------------------------------------------------------------------

  # nil.to_s => "" (empty string, not "nil")
  def to_s : String
    ""
  end

  # nil.inspect => "nil"
  def inspect : String
    "nil"
  end

  def ==(other : RubyNil) : Bool
    true
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
    false
  end

  def ruby_nil? : Bool
    true
  end

  def not : RubyBool
    RubyBool::TRUE
  end

  # nil.to_i => 0
  def to_i : RubyInteger
    RubyInteger.new(0_i64)
  end

  # nil.to_f => 0.0
  def to_f : RubyFloat
    RubyFloat.new(0.0_f64)
  end

  # nil.to_a => [] (empty array)
  def to_a : Array(RubyNil)
    [] of RubyNil
  end

  # nil & anything => false (Ruby: nil & x is always false)
  def &(other) : Bool
    false
  end

  # nil | x => x's truthiness (Ruby: nil | x returns x's truth value)
  def |(other : Bool) : Bool
    other
  end

  # -------------------------------------------------------------------------
  # Hash
  # -------------------------------------------------------------------------

  def hash : UInt64
    0_u64
  end
end

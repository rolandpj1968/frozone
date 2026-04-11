require "./ruby_object"
require "./ruby_exception"
require "./ruby_bool"
require "./ruby_nil"
require "./ruby_integer"
require "./ruby_float"
require "./ruby_string"
require "./ruby_encoding_object"
require "./ruby_symbol"
require "./ruby_array"
require "./ruby_range"
require "./ruby_proc"
require "./ruby_hash"
require "./ruby_tuple"
require "./encoding/single_byte_tables"
require "./encoding/single_byte_transcoder"
require "./ruby_math"
require "./ruby_random"
require "./ruby_set"
require "./ruby_io"

# Generic Ruby object — concrete class for Object.new / top-level self.
class RubyGenericObject < RubyObject
  def to_s : String; "#<Object>"; end
  def inspect : String; "#<Object>"; end
end

# Crystal Nil extensions — needed when methods return RubyObject | Nil.
# Ruby semantics: nil is falsy and responds to common methods.
struct Nil
  def truthy? : Bool; false; end
  def ruby_nil? : Bool; true; end
  def to_s : String; ""; end
  def ruby_to_s : String; ""; end
  def ruby_inspect : String; "nil"; end
  # Catch-all for method calls on Crystal nil from missing else branches.
  # Ruby nil would use RubyNil's methods; Crystal nil means the codegen
  # dropped an else branch. These should never be reached at runtime.
  macro method_missing(call)
    raise "BUG: method " + {{call.name.stringify}} + " called on Crystal nil (missing else RUBY_NIL?)"
  end
end

# Crystal native type extensions for mixed arithmetic with RubyObject.
# When specialised methods return raw Float64/Int64 but operate on
# RubyObject values, Crystal needs these overloads.
struct Float64
  def *(other : RubyObject) : RubyObject; RubyFloat.new(self) * other; end
  def +(other : RubyObject) : RubyObject; RubyFloat.new(self) + other; end
  def -(other : RubyObject) : RubyObject; RubyFloat.new(self) - other; end
  def /(other : RubyObject) : RubyObject; RubyFloat.new(self) / other; end
end

struct Int64
  def *(other : RubyObject) : RubyObject; RubyInteger.new(self) * other; end
  def +(other : RubyObject) : RubyObject; RubyInteger.new(self) + other; end
  def -(other : RubyObject) : RubyObject; RubyInteger.new(self) - other; end
  def /(other : RubyObject) : RubyObject; RubyInteger.new(self) / other; end
  def <(other : RubyObject) : Bool; RubyInteger.new(self) < other; end
  def <=(other : RubyObject) : Bool; RubyInteger.new(self) <= other; end
  def >(other : RubyObject) : Bool; RubyInteger.new(self) > other; end
  def >=(other : RubyObject) : Bool; RubyInteger.new(self) >= other; end
  def ==(other : RubyObject) : Bool; RubyInteger.new(self) == other; end
end

# Top-level self (Ruby's "main" object)
RUBY_MAIN = RubyGenericObject.new
def itself : RubyObject; RUBY_MAIN; end

# Multiple-assignment coercion: ensure value is an array for destructuring.
def masgn_coerce(val : RubyArray) : RubyArray
  val
end

{% for n in (1..8) %}
def masgn_coerce(val : RubyTuple{{n}}) : RubyArray
  RubyArray.new([{% for i in (0...n) %}val[{{i}}_i64]{% if i < n - 1 %}, {% end %}{% end %}] of RubyObject)
end
{% end %}

def masgn_coerce(val : Nil) : RubyArray
  RubyArray.new([] of RubyObject)
end

def masgn_coerce(val : RubyObject) : RubyArray
  val.is_a?(RubyArray) ? val.as(RubyArray) : RubyArray.new([val] of RubyObject)
end

# Kernel conversion methods — Ruby's Rational(), Integer(), etc.
def ruby_Rational(val : RubyObject) : RubyObject
  # Stub: return the value as-is (proper Rational not implemented)
  val
end

def ruby_Integer(val : RubyObject, base : RubyObject = RubyNil::INSTANCE) : RubyObject
  val
end

def ruby_Float(val : RubyObject) : RubyObject
  val
end

def ruby_Complex(val : RubyObject, imag : RubyObject = RubyNil::INSTANCE) : RubyObject
  val
end

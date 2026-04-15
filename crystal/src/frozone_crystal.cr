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
# Overrides ruby_class / ruby_class_name to say "Object" rather than
# letting the default strip-"Ruby"-prefix logic yield "GenericObject".
class RubyGenericObject < RubyObject
  def to_s : String; "#<Object>"; end
  def inspect : String; "#<Object>"; end
  def ruby_class : RubyClassProxy; RubyClassProxy.new("Object"); end
  def ruby_class_name : RubyString; RubyString.new("Object"); end
end

# Crystal Nil extensions — needed when methods return RubyObject | Nil.
# Ruby semantics: nil is falsy and responds to common methods.
struct Nil
  def truthy? : Bool; false; end
  def ruby_nil? : RubyBool; RubyBool::TRUE; end
  def to_s : String; ""; end
  def ruby_to_s : String; ""; end
  def ruby_inspect : String; "nil"; end
  def nonzero? : Nil; nil; end
  def to_a : RubyArray; RubyArray.new; end
  # Catch-all for method calls on Crystal nil from missing else branches.
  # Ruby nil would use RubyNil's methods; Crystal nil means the codegen
  # dropped an else branch. These should never be reached at runtime.
  macro method_missing(call)
    raise "BUG: method " + {{call.name.stringify}} + " called on Crystal nil (missing else RUBY_NIL?)"
  end
end

struct Bool
  def truthy? : Bool; self; end
  def ruby_nil? : RubyBool; RubyBool::FALSE; end
  def nonzero? : Bool?; self ? self : nil; end
end

struct Int32
  def nonzero? : Int32?; self == 0 ? nil : self; end
  def truthy? : Bool; true; end
  def ruby_nil? : RubyBool; RubyBool::FALSE; end
end

struct Tuple
  def include?(val) : RubyBool
    includes?(val) ? RubyBool::TRUE : RubyBool::FALSE
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

# Ruby's `puts` semantics: array arguments print one element per line
# (recursively flattening nested arrays), nil prints as empty line, and
# everything else prints via `to_s` + newline. This matches MRI's
# `IO#puts` behaviour, which differs from Crystal's `STDOUT.puts` that
# calls the object's `to_s` directly (yielding `[e1, e2]` for arrays).
def ruby_puts(obj : RubyObject) : Nil
  case obj
  when RubyNil
    STDOUT.puts
  when RubyArray
    if obj.data.empty?
      STDOUT.puts
    else
      obj.data.each { |e| ruby_puts(e) }
    end
  when RubyTuple1, RubyTuple2, RubyTuple3, RubyTuple4,
       RubyTuple5, RubyTuple6, RubyTuple7, RubyTuple8
    # RubyTuple iterates via .each — delegate so fixed-size tuples
    # follow the same per-element-per-line rule as RubyArray.
    obj.each { |e| ruby_puts(e); RubyNil::INSTANCE }
  else
    STDOUT.puts(obj.to_s)
  end
end

def ruby_puts(obj : Nil) : Nil
  STDOUT.puts
end

# RubyClassProxy isn't a RubyObject subclass but has a to_s — so that
# `puts obj.class` works when obj is a user class.
def ruby_puts(obj : RubyClassProxy) : Nil
  STDOUT.puts(obj.to_s)
end

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

# catch/throw — Ruby's non-local exit mechanism.
# catch(tag) { body } runs body; throw(tag, value) exits the catch.
class RubyThrow < Exception
  getter tag : RubyObject
  getter value : RubyObject
  def initialize(@tag, @value = RubyNil::INSTANCE); end
end

def catch(tag : RubyObject, &block) : RubyObject
  block.call
rescue ex : RubyThrow
  ex.tag == tag ? ex.value : raise ex
end

def throw(tag : RubyObject, value : RubyObject = RubyNil::INSTANCE) : NoReturn
  raise RubyThrow.new(tag, value)
end

# Kernel#format / sprintf — minimal implementation for %s substitution.
def format(template : RubyObject, args : RubyObject) : RubyObject
  t = template.to_s
  if args.is_a?(RubyHash)
    args.each do |k, v|
      t = t.gsub("%{#{k}}", v.to_s)
    end
  elsif args.is_a?(RubyArray)
    args.each { |v| t = t.sub("%s", v.to_s) }
  end
  RubyString.new(t)
end

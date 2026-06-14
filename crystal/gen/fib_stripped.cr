require "../src/frozone_crystal"

RUBY_NIL    = RubyNil::INSTANCE
RUBY_TRUE   = RubyBool::TRUE
RUBY_FALSE  = RubyBool::FALSE
RUBY_GLOBALS = {} of String => RubyObject
Ruby_ARGV   = RubyArray.new(ARGV.map { |s| RubyString.new(s).as(RubyObject) })
module Ruby_ENV
  def self.[](key : RubyObject) : RubyObject
    val = ENV[key.to_s]?
    val ? RubyString.new(val).as(RubyObject) : RUBY_NIL
  end
  def self.[]=(key : RubyObject, val : RubyObject) : RubyObject
    ENV[key.to_s] = val.to_s
    val
  end
end

# Global method-name → index for O(1) respond_to? lookup

def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end

def fib(n : Int64) : Int64
  if n < 2_i64
    return n
  end
  return (fib((n - 1_i64)) + fib((n - 2_i64)))

end

def fib(n : RubyObject)
  if (n < RubyInteger.new(2_i64))
    return n
  end
  return RubyInteger.new(fib((n.to_i64 - 1_i64)) + fib((n.to_i64 - 2_i64)))
end

# User methods on Object — also available as instance methods
class RubyObject
  def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end
  def fib(n : RubyObject)
  if (n < RubyInteger.new(2_i64))
    return n
  end
  return RubyInteger.new(fib((n.to_i64 - 1_i64)) + fib((n.to_i64 - 2_i64)))
end
end


result = fib(35_i64)
unless (result == 9227465_i64)
  raise RuntimeError.new(RubyString.new(String.build { |_s| _s << "fib(35) = "; _s << (  RubyInteger.new(result)).to_s; _s << ", expected 9227465"; }).to_s)
end
3_i64.times { fib(35_i64) }

require "../src/frozone_crystal"

RUBY_NIL = RubyNil::INSTANCE
RUBY_TRUE = RubyBool::TRUE  
RUBY_FALSE = RubyBool::FALSE

@[AlwaysInline]
def fib(n : Int64) : Int64
  return n if n < 2_i64
  fib(n - 1_i64) + fib(n - 2_i64)
end

def fib(n : RubyObject)
  return n if (n < RubyInteger.new(2_i64)).truthy?
  RubyInteger.new(fib(n.to_i64 - 1_i64) + fib(n.to_i64 - 2_i64))
end

3_i64.times { fib(35_i64) }

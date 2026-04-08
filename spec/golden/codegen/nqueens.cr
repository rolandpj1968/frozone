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

def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end

def nq_solve(n : Int64) : Int64
  a = Array(Int64).new(n, -1_i64)
  l = Array(Int64).new(n, 0_i64)
  c = Array(Int64).new(n, 0_i64)
  r = Array(Int64).new(n, 0_i64)
  y0 = ((1_i64 << n) - 1_i64)
  m = 0_i64
  k = 0_i64
  while (k >= 0_i64)
  y = (((l[k] | c[k]) | r[k]) & y0)
  if (((y ^ y0) >> (a[k] + 1_i64)) != 0_i64)
    i = (a[k] + 1_i64)
    while ((i < n) && ((y & (1_i64 << i)) != 0_i64))
      i = (i + 1_i64)
    end
    if (k < (n - 1_i64))
      z = (1_i64 << i)
      a[k] = i
      k = (k + 1_i64)
      l[k] = ((l[(k - 1_i64)] | z) << 1_i64)
      c[k] = (c[(k - 1_i64)] | z)
      r[k] = ((r[(k - 1_i64)] | z) >> 1_i64)
    else
      m = (m + 1_i64)
      k = (k - 1_i64)
    end
  else
    a[k] = -1_i64
    k = (k - 1_i64)
  end
end
  m
end

def nq_solve(n : RubyObject)
  a = Array(Int64).new(n.to_i64, -1_i64)
  l = Array(Int64).new(n.to_i64, 0_i64)
  c = Array(Int64).new(n.to_i64, 0_i64)
  r = Array(Int64).new(n.to_i64, 0_i64)
  y0 = (  (RubyInteger.new(1_i64) << n).to_i64 - 1_i64)
  m = 0_i64
  k = 0_i64
  while (k >= 0_i64)
    y = (((l[k] | c[k]) | r[k]) & y0)
    if (((y ^ y0) >> (a[k] + 1_i64)) != 0_i64)
      i = (a[k] + 1_i64)
      while (_and0 = ((RubyInteger.new(i) < n) ? RUBY_TRUE : RUBY_FALSE); _and0.truthy? ? ((((y & (1_i64 << i)) != 0_i64) ? RUBY_TRUE : RUBY_FALSE)) : _and0).truthy?
        i = (i + 1_i64)
      end
      if ((RubyInteger.new(k) < (n - RubyInteger.new(1_i64))) ? RUBY_TRUE : RUBY_FALSE).truthy?
        z = (1_i64 << i)
        a[k] = i
        k = (k + 1_i64)
        l[k] = ((l[(k - 1_i64)] | z) << 1_i64)
        c[k] = (c[(k - 1_i64)] | z)
        r[k] = ((r[(k - 1_i64)] | z) >> 1_i64)
      else
        m = (m + 1_i64)
        k = (k - 1_i64)
      end
    else
      a[k] = -1_i64
      k = (k - 1_i64)
    end
  end
  RubyInteger.new(m)
end

# User methods on Object — also available as instance methods
class RubyObject
  def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end
end


last = 0_i64
500_i64.times { last = nq_solve(12_i64) }
STDOUT.puts(RubyInteger.new(last).to_s); RUBY_NIL

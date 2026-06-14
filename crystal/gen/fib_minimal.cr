require "../src/frozone_crystal"

def fib(n : Int64) : Int64
  if n < 2_i64
    return n
  end
  return (fib((n - 1_i64)) + fib((n - 2_i64)))
end

3_i64.times { fib(35_i64) }

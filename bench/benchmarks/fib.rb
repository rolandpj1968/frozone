# Frozone-scaled fib benchmark: fib(20) instead of fib(32)
# fib(32) would take hours in Frozone; fib(20) ~640ms/iter

def fib(n)
  if n < 2
    return n
  end
  return fib(n-1) + fib(n-2)
end

run_benchmark(3) do
  fib(20)
end

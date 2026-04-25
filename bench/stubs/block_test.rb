$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

def thrice
  yield 1
  yield 2
  yield 3
end

def maybe_yield(x)
  yield x
end

# ---- Execute ----
thrice { |n| puts n }     # 1\n2\n3
maybe_yield(42) { |x| puts x }   # 42

# Closure over enclosing local
total = 0
thrice { |n| total = total + n }
puts total                # 6

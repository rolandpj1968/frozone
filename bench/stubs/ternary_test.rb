$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Top-level methods MUST come before any execute-phase statement.
# Anything after the first non-def is execute-phase (closed-world:
# runtime def would abort).
def classify(x)
  if x > 100
    "huge"
  elsif x > 10
    "big"
  else
    "small"
  end
end

# ---- Execute phase ----

n = 5

# Plain ternary
puts(n < 10 ? "small" : "big")           # small
puts(n > 10 ? "big" : "small")           # small

# Ternary as RHS — pure expressions both branches
sign = n < 0 ? "neg" : "pos"
puts sign                                 # pos

# If-as-expression with single-expression bodies (no local writes)
result = if n > 0
  n + 100
else
  0
end
puts result                               # 105

# If-as-implicit-return inside method (uses ternary semantics on tail)
puts classify(5)                          # small
puts classify(50)                         # big
puts classify(500)                        # huge

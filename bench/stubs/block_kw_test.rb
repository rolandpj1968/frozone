# Exercise block keyword parameters under box-first AOT.
#
# Block kwarg semantics — STRICT (same as methods, NOT Proc-flavored
# laxness, which only applies to positional args):
#   - missing required kw  → ArgumentError
#   - unknown kw            → ArgumentError  (unless **kwrest declared)
#   - optional kw           → uses default expression when absent
#   - **kw_rest_param       → collects unknown kwargs into a Hash
#
# The yield site builds and passes a kwargs Hash literal.

def yield_simple_kw
  yield x: 1, y: 2
end

def yield_no_kw
  yield
end

def yield_one_kw(v)
  yield z: v
end

def yield_mixed(a, k:)
  yield a, x: k
end

# 1. Required kw — block reads `|x:, y:|` from kwargs.
result_simple = yield_simple_kw { |x:, y:| x + y }
raise "simple kw: expected 3, got #{result_simple.inspect}" unless result_simple == 3

# 2. Optional kw with default expressions (no yield args).
result_opt_defaults = yield_no_kw { |x: 99, y: 88| [x, y] }
raise "optional kw defaults: expected [99, 88], got #{result_opt_defaults.inspect}" unless result_opt_defaults == [99, 88]

# 3. Optional kw with one default + one provided.
result_opt_mixed = yield_one_kw(42) { |z: 0, w: 100| [z, w] }
raise "optional kw mixed: expected [42, 100], got #{result_opt_mixed.inspect}" unless result_opt_mixed == [42, 100]

# 4. **kw_rest collects leftover kwargs into a Hash.
result_rest = yield_simple_kw { |x:, **rest| [x, rest] }
raise "kw_rest: expected [1, {y: 2}], got #{result_rest.inspect}" unless result_rest == [1, {y: 2}]

# 5. Mixed positional + kw at the yield site.
result_mix = yield_mixed(10, k: 5) { |a, x:| [a, x] }
raise "mixed pos+kw: expected [10, 5], got #{result_mix.inspect}" unless result_mix == [10, 5]

# 6. Missing required kw → ArgumentError.
begin
  yield_no_kw { |x:| x }
  raise "missing required kw: did not raise"
rescue ArgumentError => e
  raise "missing required kw: wrong message #{e.message.inspect}" unless e.message.include?("missing keyword")
end

# 7. Unknown kw → ArgumentError (when no **kwrest declared).
begin
  yield_simple_kw { |x:| x }
  raise "unknown kw: did not raise"
rescue ArgumentError => e
  raise "unknown kw: wrong message #{e.message.inspect}" unless e.message.include?("unknown keyword")
end

puts "block_kw_test: OK"

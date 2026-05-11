# Arity validation test stub.
#
# Exercises the positional arity check emitted at every method body
# entry. Each case calls the method with wrong/right arity and prints
# either the ArgumentError message or the return value. The integration
# spec asserts exact stdout match — see spec/.../integration_spec.rb.
#
# Coverage:
#   - Fixed arity:    under, over, exact
#   - With defaults:  below-min, in-range (min + max), above-max
#   - With splat:     below-required, at-required, well-above

def takes_one(a)
  a
end

def takes_one_or_two(a, b = 99)
  a * 100 + b
end

def takes_one_plus(a, *rest)
  a + rest.size
end

# Fixed
begin; takes_one(); rescue ArgumentError => e; puts e.message; end
begin; takes_one(1, 2); rescue ArgumentError => e; puts e.message; end
puts takes_one(42)

# Defaults
begin; takes_one_or_two(); rescue ArgumentError => e; puts e.message; end
begin; takes_one_or_two(1, 2, 3); rescue ArgumentError => e; puts e.message; end
puts takes_one_or_two(7)
puts takes_one_or_two(7, 8)

# Splat
begin; takes_one_plus(); rescue ArgumentError => e; puts e.message; end
puts takes_one_plus(10)
puts takes_one_plus(10, 1, 1, 1)

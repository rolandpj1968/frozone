# Multi-arity dispatch test stub.
#
# Exercises per-arity natural-args dispatch for methods with optional
# positional params (defaults beachhead — single def shape, multiple
# servable arities). The integration spec asserts exact stdout match.
#
# Coverage:
#   - Direct call at every servable arity
#   - Default expression using prior bound param
#   - Subclass inheriting the default-bearing method
#   - send-dispatch at every arity (exercises universal slot path)

class Adder
  def add(a, b = 10, c = 100)
    a + b + c
  end

  # Default expression using a prior param.
  def chain(x, y = x + 1, z = y * 2)
    x * 1000 + y * 10 + z
  end
end

class SubAdder < Adder
end

a = Adder.new
puts a.add(1)
puts a.add(1, 2)
puts a.add(1, 2, 3)

puts a.chain(1)
puts a.chain(1, 5)
puts a.chain(1, 5, 9)

s = SubAdder.new
puts s.add(1)
puts s.add(1, 2)
puts s.add(1, 2, 3)

puts a.send(:add, 7)
puts a.send(:add, 7, 8)
puts a.send(:add, 7, 8, 9)

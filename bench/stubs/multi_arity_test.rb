# Multi-arity dispatch test stub.
#
# Exercises per-arity natural-args dispatch for methods with optional
# positional params (defaults beachhead — single def shape, multiple
# servable arities) AND for cross-class arity divergence (two classes
# define the same name at different arities; per-arity overload
# resolution routes to the right slot, wrong-arity calls raise
# ArgumentError on the receiver's actual class).
#
# The integration spec asserts exact stdout match.

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

# Cross-class divergence: Ans#act takes one arg; Box#act takes two.
class Ans
  def act(x); x * 100; end
end

class Box
  def act(x, y); x + y; end
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

an = Ans.new
bx = Box.new
puts an.act(5)
puts bx.act(5, 6)
begin; an.act(5, 6); rescue ArgumentError => e; puts e.message; end
begin; bx.act(5); rescue ArgumentError => e; puts e.message; end

# Multi-arity dispatch test stub.
#
# Comprehensive coverage of per-arity natural-args dispatch:
#   - Single-shape with defaults; defaults referencing prior params
#   - Subclass inheritance (per-arity slots inherit cleanly)
#   - send-dispatch through universal-sig trampoline
#   - Cross-class arity divergence; wrong-args stubs
#   - Splat call sites — dynamic arity routes through trampoline
#   - super with multi-arity
#   - Cross-class with defaults (mixed arity ranges)
#   - Subclass changes its arity range
#   - send with wrong arity → ArgumentError (not method_missing)
#   - Multi-arity method recursing into itself
#   - Default expression invoking another method
#
# Integration spec asserts exact stdout match.

class Adder
  def add(a, b = 10, c = 100)
    a + b + c
  end

  def chain(x, y = x + 1, z = y * 2)
    x * 1000 + y * 10 + z
  end
end

class SubAdder < Adder
end

class Ans
  def act(x); x * 100; end
end

class Box
  def act(x, y); x + y; end
end

# (3) Cross-class with defaults: arity ranges overlap.
class Hop
  def m(a, b = 5)         # arities 1, 2
    a * 10 + b
  end
end

class Hap
  def m(a, b, c)          # arity 3
    a + b + c
  end
end

# (4) Subclass changes arity range.
class Stepper
  def step(a, b = 5)              # arities 1, 2
    a + b
  end
end

class FastStepper < Stepper
  def step(a, b, c = 7)           # arities 2, 3
    a * 100 + b * 10 + c
  end
end

# (2) super with multi-arity.
class Base
  def greet(name, suffix = "!")
    "hi-" + name + suffix
  end
end

class Greeter < Base
  def greet(name, suffix = "!")
    "[" + super + "]"
  end
end

# (6) Recursive multi-arity.
class Walker
  def walk(n, acc = 0)
    return acc if n == 0
    walk(n - 1, acc + n)
  end
end

# (7) Default expression invoking a method.
class Hour
  def now; 11; end
  def with_default(n, h = now)
    n * 100 + h
  end
end

# --- Single-shape defaults (existing coverage)
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

# --- Cross-class arity divergence (existing)
an = Ans.new
bx = Box.new
puts an.act(5)
puts bx.act(5, 6)
begin; an.act(5, 6); rescue ArgumentError => e; puts e.message; end
begin; bx.act(5); rescue ArgumentError => e; puts e.message; end

# --- (1) Splat call site
sp1 = [1]
sp2 = [1, 2]
sp3 = [1, 2, 3]
puts a.add(*sp1)
puts a.add(*sp2)
puts a.add(*sp3)

# --- (2) super with multi-arity
puts Greeter.new.greet("alice")
puts Greeter.new.greet("alice", "?")

# --- (3) Cross-class with defaults
hop = Hop.new
hap = Hap.new
puts hop.m(1)
puts hop.m(1, 2)
begin; hop.m(1, 2, 3); rescue ArgumentError => e; puts e.message; end
puts hap.m(1, 2, 3)
begin; hap.m(1); rescue ArgumentError => e; puts e.message; end
begin; hap.m(1, 2); rescue ArgumentError => e; puts e.message; end

# --- (4) Subclass changes arity range
st = Stepper.new
fs = FastStepper.new
puts st.step(3)
puts st.step(3, 4)
begin; st.step(1, 2, 3); rescue ArgumentError => e; puts e.message; end
puts fs.step(3, 4)
puts fs.step(3, 4, 5)
begin; fs.step(3); rescue ArgumentError => e; puts e.message; end

# --- (5) send with wrong arity
begin; hop.send(:m); rescue ArgumentError => e; puts e.message; end
begin; hop.send(:m, 1, 2, 3); rescue ArgumentError => e; puts e.message; end

# --- (6) Recursive multi-arity
puts Walker.new.walk(5)

# --- (7) Default expression invoking a method
hr = Hour.new
puts hr.with_default(3)
puts hr.with_default(3, 22)

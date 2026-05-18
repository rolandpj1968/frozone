$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Super-call regression: from_method_call's super branch lowers
# `super(a, b)` as `this->Parent::m_X(new Array({a, b}))` — universal-
# sig wrap. Latent risk identical to the IndexOperatorWrite bug:
# under NA, if Parent::m_X has only an NA slot the Array gets
# reinterpreted as the first arg.

# 1. Super with explicit args, parent method NA-eligible shape.
class Animal
  def describe(prefix)
    prefix + ": animal"
  end
  def power(base, exp)
    r = 1
    n = 0
    while n < exp
      r = r * base
      n = n + 1
    end
    r
  end
end

class Dog < Animal
  def describe(prefix)
    super(prefix) + " (dog)"
  end
  def power(base, exp)
    super(base, exp) + 1
  end
end

class Cat < Animal
  # Bare super — forwards current args.
  def describe(prefix)
    super
  end
end

class Triple < Animal
  # Super as expression — result used in further computation.
  def describe(prefix)
    "[" + super(prefix) + "]"
  end
end

# 2. Super-in-initialize chain. (All class defs must precede any
# execute-phase statement per closed-world validator.)
class Base
  def initialize(x)
    @x = x
  end
  def x ; @x ; end
end

class Mid < Base
  def initialize(x, y)
    super(x)
    @y = y
  end
  def y ; @y ; end
end

class Leaf < Mid
  def initialize(x, y, z)
    super(x, y)
    @z = z
  end
  def z ; @z ; end
end

puts Dog.new.describe("hi")          # hi: animal (dog)
puts Dog.new.power(2, 5)             # 33
puts Cat.new.describe("hi")          # hi: animal
puts Triple.new.describe("yo")       # [yo: animal]

n = Leaf.new(10, 20, 30)
puts n.x                              # 10
puts n.y                              # 20
puts n.z                              # 30

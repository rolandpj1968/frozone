$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# from_attribute_write (`obj.attr = val`) regression — same shape as
# the IndexOperatorWrite bug (Array-wrap hardcoded). Setters generated
# by attr_writer / attr_accessor are NA-eligible (single arg, no kw,
# no block), so the call must use the correct arg shape under NA.
# All class defs at load phase (closed-world validator).

class Box
  attr_accessor :v
  attr_reader   :w
  def initialize(v, w)
    @v = v
    @w = w
  end
end

class Counter
  def initialize
    @n = 0
    @label = "init"
  end
  def n     ; @n     ; end
  def label ; @label ; end
  def n=(x)
    @n = x
  end
  def label=(s)
    @label = s + "!"
  end
end

class Tweaker
  def initialize ; @v = 0 ; end
  def v ; @v ; end
  def bump(x)
    self.v = x + 1
  end
  def v=(x) ; @v = x ; end
end

# 1. attr_accessor setter.
b = Box.new(10, 20)
puts b.v          # 10
b.v = 99
puts b.v          # 99

# 2. Explicit single-arg setter — Integer arg.
c = Counter.new
c.n = 42
puts c.n          # 42

# 3. Explicit setter — String arg, side-effect in body.
c.label = "hello"
puts c.label      # hello!

# 4. Setter assigned the result of an expression with NA-eligible op.
# NB: `c.n += 1` (CallOperatorWrite) is a separate AST node not yet
# lowered in box-first — exercised only through manual read+write here.
c.n = c.n * 2
puts c.n          # 84

# 5. self.attr = ... inside a method (implicit-receiver setter).
t = Tweaker.new
t.bump(9)
puts t.v          # 10

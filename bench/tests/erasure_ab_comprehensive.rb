# Comprehensive module erasure A/B test.
# Tests all dimensions: methods, constants, ivars, prepends, is_a?,
# super, multiple inclusion, diamond inheritance.

# --- Module with methods and constants ---
module Printable
  FORMAT = "<%s>"
  def formatted
    FORMAT % to_s
  end
end

module Measurable
  UNIT = "items"
  def measure
    "#{size} #{UNIT}"
  end
end

# --- Basic inclusion ---
class Bag
  include Printable
  include Measurable

  def initialize
    @items = []
  end

  def add(x)
    @items << x
    self
  end

  def size
    @items.size
  end

  def to_s
    @items.join(", ")
  end
end

b = Bag.new.add(1).add(2).add(3)
puts b.formatted
puts b.measure

# --- Inherited module methods through superclass ---
class SpecialBag < Bag
  def to_s
    "[#{super}]"
  end
end

sb = SpecialBag.new.add("a").add("b")
puts sb.formatted  # should use Printable#formatted via inheritance
puts sb.measure    # should use Measurable#measure via inheritance

# --- Constants through inheritance chain ---
puts SpecialBag::FORMAT    # inherited from Printable via Bag
puts SpecialBag::UNIT      # inherited from Measurable via Bag

# --- Prepend ---
module Logger
  def add(x)
    $log ||= []
    $log << "adding #{x}"
    super
  end
end

class LoggedBag < Bag
  prepend Logger
end

lb = LoggedBag.new.add("x").add("y")
puts $log.join("; ")
puts lb.size

# --- is_a? checks ---
puts lb.is_a?(Logger)
puts lb.is_a?(Printable)
puts lb.is_a?(Measurable)
puts lb.is_a?(Bag)
puts lb.is_a?(LoggedBag)

# --- Diamond inclusion ---
module A
  def who
    "A"
  end
end

module B
  include A
  def who
    "B(#{super})"
  end
end

module C
  include A
  def who
    "C(#{super})"
  end
end

class D
  include B
  include C
end

puts D.new.who

# --- Module with ivars ---
module Cacheable
  def cached_value
    @cache ||= compute
  end
end

class Expensive
  include Cacheable

  def compute
    42
  end
end

e = Expensive.new
puts e.cached_value
puts e.cached_value  # should use cache

# --- ancestors ---
puts D.ancestors.map(&:to_s).join(", ")

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

class Counter
  def initialize(n)
    @n = n
  end

  def value
    @n
  end

  # Class methods — land on Counter's eigenclass.
  def self.create_with(n)
    Counter.new(n)
  end

  def self.zero
    Counter.new(0)
  end
end

c1 = Counter.create_with(42)
puts c1.value     # 42

c2 = Counter.zero
puts c2.value     # 0

# Polymorphism on class object — assign Counter to a variable, call method
klass = Counter
c3 = klass.create_with(99)
puts c3.value     # 99

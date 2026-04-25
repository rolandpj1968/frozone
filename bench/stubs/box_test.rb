$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

class Box
  def initialize(v)
    @v = v
  end

  def value
    @v
  end

  def doubled
    @v + @v
  end
end

# Under --aot, everything below is compiled.
b = Box.new(42)
puts b.value
puts b.doubled

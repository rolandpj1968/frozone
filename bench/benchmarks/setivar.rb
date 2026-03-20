# Frozone-scaled setivar benchmark: 10K iterations instead of 1M

class TheClass
  def initialize
    @v0 = 1
    @v1 = 2
    @v3 = 3
    @levar = 1
  end

  def set_value_loop
    i = 0
    while i < 10000
      @levar = i
      @levar = i
      @levar = i
      @levar = i
      @levar = i
      i += 1
    end
  end
end

obj = TheClass.new

run_benchmark(3) do
  obj.set_value_loop
end

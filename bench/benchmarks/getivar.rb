# Frozone-scaled getivar benchmark: 10K iterations instead of 1M
# Each call does 100K ivar reads

class TheClass
  def initialize
    @v0 = 1
    @v1 = 2
    @v2 = 3
    @levar = 1
  end

  def get_value_loop
    sum = 0
    i = 0
    while i < 10000
      sum += @levar
      sum += @levar
      sum += @levar
      sum += @levar
      sum += @levar
      i += 1
    end
    return sum
  end
end

OBJ = TheClass.new

run_benchmark(3) do
  OBJ.get_value_loop
end

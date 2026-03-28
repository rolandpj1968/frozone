# Struct-like benchmark with a plain class (Struct.new not yet compiled)
require_relative '../harness/loader'

class TheClass
  attr_accessor :v0, :v1, :v2, :levar

  def initialize(v0, v1, v2, levar)
    @v0 = v0
    @v1 = v1
    @v2 = v2
    @levar = levar
  end
end

def get_value_loop(obj)
  sum = 0
  i = 0
  while i < 1000000
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    sum += obj.levar
    i += 1
  end
  return sum
end

run_benchmark(850) do
  get_value_loop(TheClass.new(1, 2, 3, 1))
end

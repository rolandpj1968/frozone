# Struct-like benchmark with a plain class (Struct.new not yet compiled)
require_relative '../harness/loader'

class TheSetClass
  attr_accessor :v0, :v1, :v2, :levar

  def initialize(v0, v1, v2, levar)
    @v0 = v0
    @v1 = v1
    @v2 = v2
    @levar = levar
  end

  def set_value_loop
    i = 0
    while i < 1000000
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      self.levar = 1
      i += 1
    end
  end
end

run_benchmark(850) do
  TheSetClass.new(1, 2, 3, 1).set_value_loop
end

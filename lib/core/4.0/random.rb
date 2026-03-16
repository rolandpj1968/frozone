class Random
  def self.new(seed = Intrinsics.random_new_seed(nil))
    Intrinsics.random_new(nil, seed)
  end

  def self.rand(n = nil)
    Intrinsics.random_rand(nil, n)
  end

  def self.new_seed
    Intrinsics.random_new_seed(nil)
  end

  def self.seed
    Intrinsics.random_seed(nil)
  end

  def self.srand(seed = nil)
    Kernel.srand(seed)
  end

  def rand(n = nil)
    Intrinsics.random_rand(self, n)
  end

  def seed
    Intrinsics.random_seed(self)
  end
end

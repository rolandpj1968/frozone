class Random
  def self.new(seed = Intrinsics.random_new_seed(nil))
    Intrinsics.random_new(nil, seed)
  end

  def self.rand(n = nil)
    Intrinsics.random_rand(nil, n)
  end

  def self.random_number(n = nil) = Intrinsics.random_rand(nil, n)

  def self.new_seed
    Intrinsics.random_new_seed(nil)
  end

  def self.seed
    Intrinsics.random_seed(nil)
  end

  def self.srand(seed = nil)
    Kernel.srand(seed)
  end

  def self.bytes(n) = Intrinsics.random_bytes(nil, n)
  def self.urandom(n) = Intrinsics.random_urandom(nil, n)

  def rand(n = nil) = Intrinsics.random_rand(self, n)
  def random_number(n = nil) = Intrinsics.random_rand(self, n)
  def seed = Intrinsics.random_seed(self)
  def bytes(n) = Intrinsics.random_bytes(self, n)
  def state = Intrinsics.random_state(self)

  def ==(other)
    return false unless other.is_a?(Random)
    seed == other.seed && state == other.state
  end
end

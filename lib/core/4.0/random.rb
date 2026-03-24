class Random
  def self.random_number(n = nil) = Intrinsics.random_rand(nil, n)
  def self.bytes(n) = Intrinsics.random_bytes(nil, n)
  def self.urandom(n) = Intrinsics.random_urandom(nil, n)
  def self.new(seed = Intrinsics.random_new_seed(nil)) = Intrinsics.random_new(nil, seed)
  def self.rand(n = nil) = Intrinsics.random_rand(nil, n)
  def self.new_seed = Intrinsics.random_new_seed(nil)
  def self.seed = Intrinsics.random_seed(nil)
  def self.srand(seed = nil) = Kernel.srand(seed)
  def rand(n = nil) = Intrinsics.random_rand(self, n)
  def random_number(n = nil) = Intrinsics.random_rand(self, n)
  def seed = Intrinsics.random_seed(self)
  def bytes(n) = Intrinsics.random_bytes(self, n)
  def state = Intrinsics.random_state(self)
  def marshal_load(data) = Intrinsics.random_marshal_load(self, data)

  def ==(other)
    return false unless other.is_a?(Random)
    seed == other.seed && state == other.state
  end
end

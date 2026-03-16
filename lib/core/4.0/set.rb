class Set
  include Enumerable

  def self.[](*args)
    new(args)
  end

  def initialize(enum = nil, &block)
    @hash = {}
    if enum
      enum.each { |x| add(block ? block.call(x) : x) }
    end
  end

  def add(obj)
    @hash[obj] = true
    self
  end
  alias << add

  def include?(obj) = @hash.key?(obj)
  alias member? include?

  def delete(obj)
    @hash.delete(obj)
    self
  end

  def each(&block)
    return to_enum(:each) unless block
    @hash.each_key(&block)
    self
  end

  def size = @hash.size
  alias length size

  def empty? = @hash.empty?

  def to_a = @hash.keys

  def merge(enum)
    enum.each { |x| add(x) }
    self
  end

  def ==(other)
    return false unless other.is_a?(Set)
    return false unless size == other.size
    all? { |x| other.include?(x) }
  end

  def &(other)
    self.class.new(select { |x| other.include?(x) })
  end

  def |(other)
    r = dup
    other.each { |x| r.add(x) }
    r
  end

  def -(other)
    self.class.new(reject { |x| other.include?(x) })
  end

  def subset?(other)
    all? { |x| other.include?(x) }
  end

  def superset?(other)
    other.all? { |x| include?(x) }
  end

  def inspect
    "#<Set: {#{to_a.map(&:inspect).join(', ')}}>"
  end
  alias to_s inspect

  def dup
    self.class.new(self)
  end

  def hash = to_a.sort_by(&:hash).hash
  def eql?(other) = self == other
end

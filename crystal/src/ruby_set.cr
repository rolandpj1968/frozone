# Minimal Set implementation for compiled Ruby programs.
# Wraps Crystal's Set(RubyObject) but presents as RubyObject.

class Ruby_Set < RubyObject
  @data : Set(UInt64)
  @objects : Hash(UInt64, RubyObject)

  def initialize
    @data = Set(UInt64).new
    @objects = {} of UInt64 => RubyObject
  end

  def self.[] : Ruby_Set
    new
  end

  def self.[](*args : RubyObject) : Ruby_Set
    s = new
    args.each { |a| s.<<(a) }
    s
  end

  def <<(v : RubyObject) : Ruby_Set
    id = v.hash
    @data << id
    @objects[id] = v
    self
  end

  def add(v : RubyObject) : Ruby_Set
    self << v
  end

  def include?(v : RubyObject) : RubyBool
    @data.includes?(v.hash) ? RubyBool::TRUE : RubyBool::FALSE
  end

  def empty? : RubyBool
    @data.empty? ? RubyBool::TRUE : RubyBool::FALSE
  end

  def size : RubyInteger
    RubyInteger.new(@data.size.to_i64)
  end

  def to_s : String
    "#<Set: {#{@objects.values.map(&.inspect).join(", ")}}>"
  end

  def inspect : String
    to_s
  end

  def each(&block : RubyObject ->)
    @objects.each_value { |v| block.call(v) }
  end

  def to_a : RubyArray
    RubyArray.new(@objects.values.map(&.as(RubyObject)))
  end
end

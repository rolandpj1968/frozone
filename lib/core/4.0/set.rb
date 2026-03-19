class Set
  include Enumerable
  include Comparable

  def self.[](*args)
    new(args)
  end

  def initialize(enum = nil, &block)
    @hash = {}
    return unless enum
    begin
      if enum.respond_to?(:each_entry)
        enum.each_entry { |x| add(block ? block.call(x) : x) }
      elsif enum.respond_to?(:each)
        enum.each { |x| add(block ? block.call(x) : x) }
      else
        raise ArgumentError, "value must be enumerable"
      end
    rescue NoMethodError
      raise ArgumentError, "value must be enumerable"
    end
  end

  def initialize_clone(orig, freeze: nil)
    super(orig)
    @hash = orig.instance_variable_get(:@hash).dup
    @hash.compare_by_identity if orig.compare_by_identity?
  end

  def add(obj)
    raise RuntimeError, "can't add to set during iteration" if @iterating
    @hash[obj] = true
    self
  end
  alias << add

  def add?(obj)
    return nil if include?(obj)
    add(obj)
    self
  end

  def include?(obj) = @hash.key?(obj)
  alias member? include?
  alias === include?

  def delete(obj)
    @hash.delete(obj)
    self
  end

  def delete?(obj)
    return nil unless include?(obj)
    delete(obj)
    self
  end

  def delete_if
    return to_enum(:delete_if) unless block_given?
    to_a.each { |x| delete(x) if yield(x) }
    self
  end

  def keep_if
    return to_enum(:keep_if) unless block_given?
    to_a.each { |x| delete(x) unless yield(x) }
    self
  end

  def select!
    return to_enum(:select!) unless block_given?
    n = size
    keep_if { |x| yield(x) }
    size == n ? nil : self
  end
  alias filter! select!

  def reject!
    return to_enum(:reject!) unless block_given?
    n = size
    delete_if { |x| yield(x) }
    size == n ? nil : self
  end

  def each(&block)
    return to_enum(:each) unless block
    if frozen?
      @hash.each_key(&block)
      return self
    end
    @iterating = true
    begin
      @hash.each_key(&block)
    ensure
      @iterating = false
    end
    self
  end

  def size = @hash.size
  alias length size

  def empty? = @hash.empty?

  def clear
    @hash.clear
    self
  end

  def to_a = @hash.keys

  def replace(enum)
    raise RuntimeError, "can't replace set during iteration" if @iterating
    clear
    enum.each { |x| add(x) }
    self
  end

  def merge(*enums)
    enums.each do |enum|
      raise ArgumentError, "value must be enumerable" unless enum.respond_to?(:each)
      enum.each { |x| add(x) }
    end
    self
  end

  def subtract(enum)
    enum.each { |x| delete(x) }
    self
  end

  def collect!
    return to_enum(:collect!) unless block_given?
    new_vals = to_a.map { |x| yield(x) }
    clear
    new_vals.each { |x| add(x) }
    self
  end
  alias map! collect!

  def flatten
    result = self.class.new
    __do_flatten__(result, {})
    result
  end

  def flatten!
    return nil unless any? { |x| x.is_a?(Set) }
    replace(flatten)
    self
  end

  def ==(other)
    return false unless other.is_a?(Set)
    return true if equal?(other)
    return false unless compare_by_identity? == other.compare_by_identity?
    return false unless size == other.size
    all? { |x| other.include?(x) }
  end

  def <=>(other)
    return nil unless other.is_a?(Set)
    if size < other.size
      subset?(other) ? -1 : nil
    elsif size > other.size
      superset?(other) ? 1 : nil
    else
      self == other ? 0 : nil
    end
  end

  def &(other)
    raise ArgumentError, "value must be a set" unless other.respond_to?(:each)
    self.class.new(select { |x| other.include?(x) })
  end
  alias intersection &

  def |(other)
    raise ArgumentError, "value must be a set" unless other.respond_to?(:each)
    r = dup
    other.each { |x| r.add(x) }
    r
  end
  alias union |
  alias + |

  def -(other)
    raise ArgumentError, "value must be a set" unless other.respond_to?(:each)
    self.class.new(reject { |x| other.include?(x) })
  end
  alias difference -

  def ^(other)
    raise ArgumentError, "value must be a set" unless other.respond_to?(:each)
    (self | other) - (self & other)
  end

  def subset?(other)
    raise ArgumentError, "value must be a set" unless other.is_a?(Set)
    size <= other.size && all? { |x| other.include?(x) }
  end

  def proper_subset?(other)
    raise ArgumentError, "value must be a set" unless other.is_a?(Set)
    size < other.size && all? { |x| other.include?(x) }
  end

  def superset?(other)
    raise ArgumentError, "value must be a set" unless other.is_a?(Set)
    size >= other.size && other.all? { |x| include?(x) }
  end

  def proper_superset?(other)
    raise ArgumentError, "value must be a set" unless other.is_a?(Set)
    size > other.size && other.all? { |x| include?(x) }
  end

  def intersect?(other)
    raise ArgumentError, "value must be a set" unless other.is_a?(Set)
    if size < other.size
      any? { |x| other.include?(x) }
    else
      other.any? { |x| include?(x) }
    end
  end

  def disjoint?(other)
    !intersect?(other)
  end

  def classify
    return to_enum(:classify) unless block_given?
    result = {}
    each do |x|
      key = yield(x)
      (result[key] ||= self.class.new).add(x)
    end
    result
  end

  def divide(&block)
    return to_enum(:divide) unless block
    if block.arity == 2
      # Build adjacency graph calling block for all ordered pairs of distinct elements,
      # then find connected components via BFS.
      elems = to_a
      adj = {}
      elems.each { |x| adj[x.object_id] = [] }
      elems.each do |x|
        elems.each do |y|
          next if x.equal?(y)
          adj[x.object_id] << y if block.call(x, y)
        end
      end
      visited = {}
      components = []
      elems.each do |start|
        next if visited[start.object_id]
        component = []
        queue = [start]
        while (v = queue.shift)
          next if visited[v.object_id]
          visited[v.object_id] = true
          component << v
          adj[v.object_id].each { |w| queue << w }
        end
        components << component
      end
      result = self.class.new
      components.each { |c| result.add(self.class.new(c)) }
      result
    else
      classify(&block).values.each_with_object(self.class.new) { |s, r| r.add(s) }
    end
  end

  def join(sep = nil)
    to_a.join(sep)
  end

  def compare_by_identity
    raise FrozenError, "can't modify frozen #{self.class}: #{inspect}" if frozen?
    @hash.compare_by_identity
    self
  end

  def compare_by_identity?
    @hash.compare_by_identity?
  end

  def inspect
    ids = (Fiber[:__set_inspect__] ||= {})
    if ids.key?(object_id)
      return "Set[...]"
    end
    ids[object_id] = true
    begin
      "Set[#{to_a.map(&:inspect).join(', ')}]"
    ensure
      ids.delete(object_id)
    end
  end
  alias to_s inspect

  def pretty_print(pp)
    pp.text inspect
  end

  def pretty_print_cycle(pp)
    pp.text "Set[...]"
  end

  def dup
    s = self.class.new(self)
    s.compare_by_identity if compare_by_identity?
    s
  end

  def hash = to_a.sort_by(&:hash).hash
  def eql?(other) = self == other

  protected

  def __do_flatten__(result, seen)
    raise ArgumentError, "tried to flatten recursive Set" if seen.key?(object_id)
    seen[object_id] = true
    each { |x| x.is_a?(Set) ? x.__do_flatten__(result, seen) : result.add(x) }
    seen.delete(object_id)
  end
end

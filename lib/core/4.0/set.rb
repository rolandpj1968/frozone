class Set
  include Enumerable
  include Comparable

  def self.[](*args)
    new(args)
  end

  def initialize(enum = nil, &block)
    @hash = {}
    if enum
      enum.each { |x| add(block ? block.call(x) : x) }
    end
  end

  def initialize_clone(orig)
    super
    @hash = orig.instance_variable_get(:@hash).dup
  end

  def add(obj)
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
    each { |x| delete(x) if yield(x) }
    self
  end

  def keep_if
    return to_enum(:keep_if) unless block_given?
    each { |x| delete(x) unless yield(x) }
    self
  end

  alias filter! keep_if
  alias select! keep_if

  def reject!(&block)
    return to_enum(:reject!) unless block
    n = size
    delete_if(&block)
    size == n ? nil : self
  end

  def each(&block)
    return to_enum(:each) unless block
    @hash.each_key(&block)
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
    clear
    merge(enum)
    self
  end

  def merge(*enums)
    enums.each { |enum| enum.each { |x| add(x) } }
    self
  end

  def subtract(enum)
    enum.each { |x| delete(x) }
    self
  end

  def collect!
    return to_enum(:collect!) unless block_given?
    new_set = self.class.new
    each { |x| new_set.add(yield(x)) }
    replace(new_set)
    self
  end
  alias map! collect!

  def flatten
    _flatten_into(self.class.new, {})
  end

  def flatten!
    return nil unless any? { |x| x.is_a?(Set) }
    replace(flatten)
    self
  end

  private

  def _flatten_into(result, seen)
    raise ArgumentError, "tried to flatten recursive Set" if seen.key?(object_id)
    seen[object_id] = true
    each { |x| x.is_a?(Set) ? x._flatten_into(result, seen) : result.add(x) }
    seen.delete(object_id)
    result
  end

  public

  def ===(obj) = include?(obj)

  def ==(other)
    return false unless other.is_a?(Set)
    return true if equal?(other)
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
    self.class.new(select { |x| other.include?(x) })
  end
  alias intersection &

  def |(other)
    r = dup
    other.each { |x| r.add(x) }
    r
  end
  alias union |
  alias + |

  def -(other)
    self.class.new(reject { |x| other.include?(x) })
  end
  alias difference -

  def ^(other)
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
      # Equivalence relation: two-arg block
      groups = []
      each do |x|
        placed = false
        groups.each do |g|
          if block.call(g.first, x)
            g.push(x)
            placed = true
            break
          end
        end
        groups.push([x]) unless placed
      end
      result = self.class.new
      groups.each { |g| result.add(self.class.new(g)) }
      result
    else
      classify(&block).values.each_with_object(self.class.new) { |s, r| r.add(s) }
    end
  end

  def join(sep = nil)
    to_a.join(sep)
  end

  def compare_by_identity
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
    self.class.new(self)
  end

  def hash = to_a.sort_by(&:hash).hash
  def eql?(other) = self == other
end

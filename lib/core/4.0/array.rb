class Array
  def self.new(size_or_array = nil, fill = nil, &block)
    Intrinsics.array_new(self, size_or_array, fill, block)
  end

  def initialize(size_or_array = nil, fill = nil, &block)
    Intrinsics.array_initialize(self, size_or_array, fill, block)
  end

  def at(i) = Intrinsics.array_at(self, i)
  def [](i, len = nil)
    if len
      Intrinsics.array_slice(self, i, len)
    elsif i.is_a?(Range)
      Intrinsics.array_slice(self, i, nil)
    else
      at(i)
    end
  end
  def []=(i, len_or_val, val = :__unset__)
    if val.equal?(:__unset__)
      Intrinsics.array_index_write(self, i, len_or_val)
    else
      Intrinsics.array_slice_write(self, i, len_or_val, val)
    end
  end
  def push(*vals); vals.each { |v| Intrinsics.array_push(self, v) }; self; end
  alias append push
  def <<(v); Intrinsics.array_push(self, v); self; end
  def concat(other) = Intrinsics.array_concat(self, other)
  def replace(other) = Intrinsics.array_replace(self, other)
  def clear; replace([]); self; end
  def length = Intrinsics.array_length(self)
  alias size length
  def count(&block); return length unless block; n = 0; each { |x| n += 1 if block.call(x) }; n; end
  def empty? = length == 0
  def first(n = nil) = n ? self[0, n] : self[0]
  def last(n = nil) = n ? self[-n, n] : self[self.length - 1]
  def ==(other)
    return false unless other.is_a?(Array)
    return false unless length == other.length
    i = 0; while i < length; return false unless self[i] == other[i]; i += 1; end
    true
  end
  def to_s = Intrinsics.array_to_s(self)
  alias inspect to_s
  def to_a = self
  def to_h(&block)
    r = {}
    each { |e|
      pair = block ? block.call(e) : e
      r[pair[0]] = pair[1]
    }
    r
  end
  def dup; r = []; each { |e| r << e }; r; end


  def hash; reduce(0) { |acc, e| acc * 31 + e.hash }; end
  def eql?(other)
    return false unless other.is_a?(Array)
    return false unless length == other.length
    i = 0; while i < length; return false unless self[i].eql?(other[i]); i += 1; end
    true
  end

  def &(other)
    set = {}; other.each { |e| set[e] = true }
    seen = {}; r = []
    each { |e| r << e and seen[e] = true if set.key?(e) && !seen.key?(e) }
    r
  end
  def |(other)
    seen = {}; r = []
    each { |e| r << e and seen[e] = true unless seen.key?(e) }
    other.each { |e| r << e and seen[e] = true unless seen.key?(e) }
    r
  end
  def -(other)
    set = {}; other.each { |e| set[e] = true }
    reject { |e| set.key?(e) }
  end
  def +(other); r = dup; r.concat(other); r; end
  def *(n)
    if n.is_a?(Integer)
      r = []; n.times { r.concat(self) }; r
    else
      join(n)
    end
  end

  def flatten(depth = nil)
    r = []
    each { |e|
      if e.is_a?(Array) && (depth.nil? || depth > 0)
        e.flatten(depth.nil? ? nil : depth - 1).each { |x| r << x }
      else
        r << e
      end
    }
    r
  end

  def compact;  reject { |x| x.nil? }; end
  def compact!; reject! { |x| x.nil? }; end
  def uniq; seen = {}; r = []; each { |e| r << e and seen[e] = true unless seen.key?(e) }; r; end
  def reverse = Intrinsics.array_reverse(self)
  def reverse!; replace(reverse); self; end
  def sort = Intrinsics.array_sort(self)
  def sort!; replace(sort); self; end
  def sort_by(&block) = Intrinsics.array_sort_by(self, block)
  def min; empty? ? nil : reduce { |a, b| (a <=> b) <= 0 ? a : b }; end
  def max; empty? ? nil : reduce { |a, b| (a <=> b) >= 0 ? a : b }; end
  def sum(initial = nil)
    acc = initial.nil? ? 0 : initial
    each { |e| acc = acc + e }
    acc
  end
  def join(sep = nil)
    sep_str = sep.nil? ? '' : sep.to_s
    result = ''
    first = true
    each { |e|
      result << sep_str unless first
      result << (e.is_a?(Array) ? e.join(sep) : e.to_s)
      first = false
    }
    result
  end
  def include?(elem); any? { |x| x == elem }; end
  def pop = Intrinsics.array_pop(self)
  def shift = Intrinsics.array_shift(self)
  def unshift(*elems) = Intrinsics.array_unshift(self, *elems)
  alias prepend unshift
  def delete(elem); n = length; reject! { |x| x == elem }; n == length ? nil : elem; end
  def delete_if(&block); reject!(&block); self; end
  def index(elem = nil); i = 0; while i < length; return i if self[i] == elem; i += 1; end; nil; end
  alias find_index index
  def take(n)
    r = []; i = 0
    while i < n && i < length; r << self[i]; i += 1; end
    r
  end
  def drop(n)
    r = []; i = n
    while i < length; r << self[i]; i += 1; end
    r
  end
  def rotate(n = nil)
    n = n.nil? ? 1 : n
    return dup if empty?
    n = n % length
    return dup if n == 0
    self[n, length - n] + self[0, n]
  end
  def sample = Intrinsics.array_sample(self)
  def shuffle = Intrinsics.array_shuffle(self)
  def zip(*others)
    result = []
    i = 0
    while i < length
      row = [self[i]]
      others.each { |o| row << (i < o.length ? o[i] : nil) }
      result << row
      i += 1
    end
    result
  end
  def combination(n, &block) = Intrinsics.array_combination(self, n, block)
  def permutation(n = nil, &block) = Intrinsics.array_permutation(self, n, block)

  def each
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end

  def map(&block);        r = []; each { |x| r << (block ? block.call(x) : yield(x)) };           r; end
  def map!(&block);       i = 0; while i < length; self[i] = (block ? block.call(self[i]) : yield(self[i])); i += 1; end; self; end
  alias collect map
  alias collect! map!
  def select(&block);    r = []; each { |x| r << x if (block ? block.call(x) : yield(x)) };      r; end
  alias filter select
  alias find_all select
  def reject(&block);    r = []; each { |x| r << x unless (block ? block.call(x) : yield(x)) }; r; end
  def reject!(&block);   n = length; r = reject(&block); replace(r); n == length ? nil : self; end
  def select!(&block);   n = length; r = select(&block); replace(r); n == length ? nil : self; end
  alias filter! select!

  def flat_map(&block)
    r = []
    each { |e|
      v = block ? block.call(e) : yield(e)
      v.is_a?(Array) ? v.each { |x| r << x } : r << v
    }
    r
  end
  alias collect_concat flat_map

  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end
  def each_with_object(obj, &block)
    each { |e| block ? block.call(e, obj) : yield(e, obj) }
    obj
  end

  def find; each { |x| return x if yield(x) }; nil; end
  alias detect find

  def any?(&block)  = (each { |x| return true  if (block ? block.call(x) : yield(x)) }; false)
  def all?(&block)  = (each { |x| return false unless (block ? block.call(x) : yield(x)) }; true)
  def none?(&block) = (each { |x| return false if (block ? block.call(x) : yield(x)) }; true)

  def reduce(initial = nil, &block); acc = initial; each { |x| acc = acc.nil? ? x : (block ? block.call(acc, x) : yield(acc, x)) }; acc; end
  alias inject reduce

  def each_slice(n)
    i = 0
    while i < length
      yield self[i, n] || []
      i += n
    end
    nil
  end

  def each_cons(n)
    i = 0
    while i + n <= length
      yield self[i, n]
      i += 1
    end
    nil
  end

  def group_by; result = {}; each { |x| k = yield(x); result[k] ||= []; result[k] << x }; result; end
  def tally;    result = {}; each { |x| result[x] = (result[x] || 0) + 1 };                result; end
end

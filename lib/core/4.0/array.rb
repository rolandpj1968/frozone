class Array
  def self.new(size_or_array = nil, fill = nil, &block)
    Intrinsics.array_new(size_or_array, fill, block)
  end

  def initialize(size_or_array = nil, fill = nil, &block)
    Intrinsics.array_initialize(self, size_or_array, fill, block)
  end

  def [](i, len = nil) = Intrinsics.array_index(self, i, len)
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
  def count(&block) = Intrinsics.array_count(self, block)
  def empty? = Intrinsics.array_empty(self)
  def first = self[0]
  def last = self[self.length - 1]
  def ==(other) = Intrinsics.array_eq(self, other)
  def to_s = Intrinsics.array_to_s(self)
  alias inspect to_s
  def to_a = Intrinsics.array_to_a(self)
  def to_h(&block) = Intrinsics.array_to_h(self, block)
  def dup = Intrinsics.array_dup(self)
  def freeze = Intrinsics.array_freeze(self)
  def frozen? = Intrinsics.array_frozen(self)

  def hash = Intrinsics.array_hash(self)
  def eql?(v) = Intrinsics.array_eql(self, v)

  def &(other) = Intrinsics.array_intersection(self, other)
  def |(other) = Intrinsics.array_union(self, other)
  def -(other) = Intrinsics.array_difference(self, other)
  def +(other) = Intrinsics.array_plus(self, other)
  def *(n) = Intrinsics.array_multiply(self, n)

  def flatten(depth = nil) = Intrinsics.array_flatten(self, depth)
  def compact = Intrinsics.array_compact(self)
  def uniq = Intrinsics.array_uniq(self)
  def reverse = Intrinsics.array_reverse(self)
  def reverse! = Intrinsics.array_reverse(self)
  def sort = Intrinsics.array_sort(self)
  def sort! = Intrinsics.array_sort(self)
  def sort_by(&block) = Intrinsics.array_sort_by(self, block)
  def min = Intrinsics.array_min(self)
  def max = Intrinsics.array_max(self)
  def sum(initial = nil) = Intrinsics.array_sum(self, initial)
  def join(sep = nil) = Intrinsics.array_join(self, sep)
  def include?(elem) = Intrinsics.array_include(self, elem)
  def pop = Intrinsics.array_pop(self)
  def shift = Intrinsics.array_shift(self)
  def unshift(*elems) = Intrinsics.array_unshift(self, *elems)
  alias prepend unshift
  def delete(elem) = Intrinsics.array_delete(self, elem)
  def delete_if(&block) = Intrinsics.array_delete_if(self, block)
  def index(elem = nil) = Intrinsics.array_index_of(self, elem)
  alias find_index index
  def take(n) = Intrinsics.array_take(self, n)
  def drop(n) = Intrinsics.array_drop(self, n)
  def rotate(n = nil) = Intrinsics.array_rotate(self, n)
  def sample = Intrinsics.array_sample(self)
  def shuffle = Intrinsics.array_shuffle(self)
  def zip(*others) = Intrinsics.array_zip(self, *others)
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
  alias collect map
  def select(&block);    r = []; each { |x| r << x if (block ? block.call(x) : yield(x)) };      r; end
  alias filter select
  alias find_all select
  def reject(&block);    r = []; each { |x| r << x unless (block ? block.call(x) : yield(x)) }; r; end
  def reject!(&block);   n = length; r = reject(&block); replace(r); n == length ? nil : self; end
  def select!(&block);   n = length; r = select(&block); replace(r); n == length ? nil : self; end
  alias filter! select!

  def flat_map(&block) = Intrinsics.array_flat_map(self, block)
  alias collect_concat flat_map

  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end
  def each_with_object(obj, &block) = Intrinsics.array_each_with_object(self, obj, block)

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

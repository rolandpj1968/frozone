class Array
  def self.new(size_or_array = nil, fill = nil, &block)
    Intrinsics.array_new(self, size_or_array, fill, block)
  end

  def initialize(size_or_array = nil, fill = nil, &block)
    raise FrozenError, "can't modify frozen #{self.class}" if frozen?
    if size_or_array.nil?
      warn "warning: given block not used" if block
      Intrinsics.array_initialize(self, nil, nil, nil)
    elsif size_or_array.is_a?(Array)
      raise TypeError, "wrong number of arguments (given 2, expected 0..1)" if !fill.nil?
      warn "warning: given block not used" if block
      Intrinsics.array_initialize(self, size_or_array, nil, nil)
    elsif size_or_array.respond_to?(:to_ary, true)
      raise TypeError, "wrong number of arguments (given 2, expected 0..1)" if !fill.nil?
      warn "warning: given block not used" if block
      Intrinsics.array_initialize(self, size_or_array.send(:to_ary), nil, nil)
    elsif size_or_array.is_a?(Integer)
      warn "warning: block supersedes default value argument" if block && !fill.nil?
      Intrinsics.array_initialize(self, size_or_array, fill, block)
    elsif size_or_array.respond_to?(:to_int)
      n = size_or_array.to_int
      raise TypeError, "no implicit conversion of #{size_or_array.class} into Integer" unless n.is_a?(Integer)
      raise TypeError, "wrong number of arguments (given 2, expected 0..1)" if !fill.nil? && !n.is_a?(Integer)
      warn "warning: block supersedes default value argument" if block && !fill.nil?
      Intrinsics.array_initialize(self, n, fill, block)
    else
      raise TypeError, "no implicit conversion of #{size_or_array.class} into Integer"
    end
  end

  def at(i) = Intrinsics.array_at(self, i)

  def [](i, len = nil)
    n = length

    if len
      s = i < 0 ? i + n : i
      return nil if s < 0 || s > n
      stop = s + len > n ? n : s + len
      r = []; j = s; while j < stop; r << at(j); j += 1; end; r
    elsif i.is_a?(Range)
      b = i.begin.nil? ? 0       : (i.begin < 0 ? i.begin + n : i.begin)
      e = i.end.nil?   ? n - 1   : (i.end   < 0 ? i.end   + n : i.end)
      e -= 1 if i.exclude_end?
      return nil if b > n
      return [] if b == n || e < b
      e = n - 1 if e >= n
      (b..e).map { |idx| at(idx) }
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
  def count(val = :__undefined__, &block)
    if val.equal?(:__undefined__)
      return length unless block
      n = 0; each { |x| n += 1 if block.call(x) }; n
    else
      warn "warning: given block not used" if block
      n = 0; each { |x| n += 1 if x == val }; n
    end
  end
  def empty? = length == 0
  def first(n = nil) = n ? self[0, n] : self[0]
  def last(n = nil) = n ? self[[length - n, 0].max, n] : self[length - 1]

  def ==(other)
    return false unless other.is_a?(Array)
    return false unless length == other.length
    return true if equal?(other)
    ongoing = (Fiber[:__array_eq__] ||= [])
    id1, id2 = __id__, other.__id__
    return true if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << [id1, id2]
    begin
      i = 0; while i < length; return false unless self[i] == other[i]; i += 1; end
      true
    ensure
      ongoing.pop
    end
  end

  def to_s = Intrinsics.array_to_s(self)
  alias inspect to_s
  def to_a = self
  def to_ary = self

  def to_h(&block)
    r = {}
    each { |e|
      pair = block ? block.call(e) : e
      r[pair[0]] = pair[1]
    }
    r
  end

  def dup = Intrinsics.array_dup(self)
  def clone(freeze: nil) = Intrinsics.array_clone(self, freeze)

  def hash
    ongoing = (Fiber[:__array_hash__] ||= [])
    return 0 if ongoing.include?(__id__)
    ongoing << __id__
    begin
      reduce(0) { |acc, e| acc * 31 + e.hash }
    ensure
      ongoing.pop
    end
  end

  def eql?(other)
    return false unless other.is_a?(Array)
    return false unless length == other.length
    return true if equal?(other)
    ongoing = (Fiber[:__array_eql__] ||= [])
    id1, id2 = __id__, other.__id__
    return true if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << [id1, id2]
    begin
      i = 0; while i < length; return false unless self[i].eql?(other[i]); i += 1; end
      true
    ensure
      ongoing.pop
    end
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

  def pack(fmt) = Intrinsics.array_pack(self, fmt)

  def compact;  reject { |x| x.nil? }; end
  def compact!; reject! { |x| x.nil? }; end
  def uniq; seen = {}; r = []; each { |e| r << e and seen[e] = true unless seen.key?(e) }; r; end
  def reverse = Intrinsics.array_reverse(self)
  def reverse!; replace(reverse); self; end
  def <=>(other)
    return nil unless other.is_a?(Array)
    i = 0
    while i < length && i < other.length
      c = self[i] <=> other[i]
      return c if c != 0
      i += 1
    end
    length <=> other.length
  end

  def sort(&block)
    block ? Intrinsics.array_sort_block(self, block) : Intrinsics.array_sort(self)
  end

  def sort!(&block); replace(sort(&block)); self; end
  def sort_by(&block) = Intrinsics.array_sort_by(self, block)
  def min(&block)
    return nil if empty?
    if block
      # Call both < and > on block result to match MRI behavior
      r = self[0]
      each_with_index do |x, i|
        next if i == 0
        cmp = block.call(x, r)
        if cmp < 0
          r = x      # new element is smaller
        elsif cmp > 0
          # keep r   # new element is larger
        end
      end
      r
    else
      reduce { |a, b| (a <=> b) <= 0 ? a : b }
    end
  end

  def max(&block)
    return nil if empty?
    if block
      r = self[0]
      each_with_index do |x, i|
        next if i == 0
        cmp = block.call(x, r)
        if cmp > 0
          r = x      # new element is larger
        elsif cmp < 0
          # keep r   # new element is smaller
        end
      end
      r
    else
      reduce { |a, b| (a <=> b) >= 0 ? a : b }
    end
  end

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
      result += sep_str unless first
      result += e.is_a?(Array) ? e.join(sep) : e.to_s
      first = false
    }
    result
  end

  def include?(elem); any? { |x| x == elem }; end
  def pop = Intrinsics.array_pop(self)
  def shift = Intrinsics.array_shift(self)
  def unshift(*elems) = Intrinsics.array_unshift(self, *elems)
  alias prepend unshift
  def dig(idx, *rest)
    val = self[idx]
    return val if rest.empty?
    raise TypeError, "#{val.class} does not have #dig method" unless val.respond_to?(:dig)
    val.dig(*rest)
  end

  def delete(elem); n = length; reject! { |x| x == elem }; n == length ? nil : elem; end
  def delete_if(&block); reject!(&block); self; end
  def index(elem = :__none__, &block)
    if block
      warn "warning: given block not used" unless elem.equal?(:__none__)
      i = 0; while i < length; return i if block.call(self[i]); i += 1; end; nil
    elsif elem.equal?(:__none__)
      return to_enum(:index)
    else
      i = 0; while i < length; return i if self[i] == elem; i += 1; end; nil
    end
  end
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
    n = length
    converted = others.map do |o|
      if o.respond_to?(:to_ary)
        o.to_ary
      elsif o.respond_to?(:each)
        elems = []
        o.each { |e| elems << e; break if elems.length >= n }
        elems
      else
        raise TypeError, "wrong argument type #{o.class} (must respond to :each)"
      end
    end
    if block_given?
      each_with_index { |elem, i| yield([elem] + converted.map { |arr| i < arr.length ? arr[i] : nil }) }
      nil
    else
      result = []
      each_with_index { |elem, i| result << ([elem] + converted.map { |arr| i < arr.length ? arr[i] : nil }) }
      result
    end
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

  def map(&block)
    return to_enum(:map) { size } unless block
    r = []; each { |x| r << block.call(x) }; r
  end

  def map!(&block)
    return to_enum(:map!) { size } unless block
    raise FrozenError, "can't modify frozen Array" if frozen?
    i = 0; while i < length; self[i] = block.call(self[i]); i += 1; end; self
  end

  alias collect map
  alias collect! map!

  def select(&block)
    return to_enum(:select) { size } unless block
    r = []; each { |x| r << x if block.call(x) }; r
  end

  alias filter select
  alias find_all select

  def reject(&block)
    return to_enum(:reject) { size } unless block
    r = []; each { |x| r << x unless block.call(x) }; r
  end

  def reject!(&block)
    return to_enum(:reject!) { size } unless block
    n = length; r = reject(&block); replace(r); n == length ? nil : self
  end

  def select!(&block)
    return to_enum(:select!) { size } unless block
    n = length; r = select(&block); replace(r); n == length ? nil : self
  end

  alias filter! select!

  def flat_map(&block)
    return to_enum(:flat_map) { size } unless block
    r = []
    each { |e|
      v = block.call(e)
      v.is_a?(Array) ? v.each { |x| r << x } : r << v
    }
    r
  end

  alias collect_concat flat_map

  def each_with_index(&block)
    return to_enum(:each_with_index) { size } unless block
    i = 0; each { |x| block.call(x, i); i += 1 }; self
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) { size } unless block
    each { |e| block.call(e, obj) }
    obj
  end

  def find; each { |x| return x if yield(x) }; nil; end
  alias detect find

  def any?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |x| return true if (block ? block.call(x) : x) }
    else
      warn "warning: given block not used" if block
      each { |x| return true if pat === x }
    end
    false
  end

  def all?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |x| return false unless (block ? block.call(x) : x) }
    else
      warn "warning: given block not used" if block
      each { |x| return false unless pat === x }
    end
    true
  end

  def none?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |x| return false if (block ? block.call(x) : x) }
    else
      warn "warning: given block not used" if block
      each { |x| return false if pat === x }
    end
    true
  end

  def one?(pat = :__none__, &block)
    found = false
    if pat.equal?(:__none__)
      each do |x|
        if block ? block.call(x) : x
          return false if found
          found = true
        end
      end
    else
      warn "warning: given block not used" if block
      each do |x|
        if pat === x
          return false if found
          found = true
        end
      end
    end
    found
  end

  def reduce(*args, &block)
    sym = nil; has_initial = false; initial = nil
    case args.length
    when 0
      raise ArgumentError, "no block given (yield)" unless block
    when 1
      if args[0].is_a?(Symbol) || args[0].is_a?(String)
        sym = args[0].to_sym
        warn "warning: given block not used" if block
      else
        has_initial = true; initial = args[0]
        raise ArgumentError, "no block given (yield)" unless block
      end
    when 2
      initial = args[0]; has_initial = true
      arg1 = args[1]
      if arg1.is_a?(Symbol)
        sym = arg1.to_sym
      elsif arg1.is_a?(String)
        sym = arg1.to_sym
      elsif arg1.respond_to?(:to_str)
        sym = arg1.to_str.to_sym
      else
        raise TypeError, "#{arg1.inspect} is not a symbol nor a string"
      end
      warn "warning: given block not used" if block
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
    acc = initial; first = !has_initial
    each do |x|
      if first
        acc = x; first = false
      elsif sym
        acc = acc.send(sym, x)
      else
        acc = block.call(acc, x)
      end
    end
    acc
  end
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

  def grep(pattern, &block)
    r = []
    if block
      each { |x| r << block.call(x) if pattern === x }
    else
      each { |x| r << x if pattern === x }
    end
    r
  end

  def grep_v(pattern, &block)
    r = []
    if block
      each { |x| r << block.call(x) unless pattern === x }
    else
      each { |x| r << x unless pattern === x }
    end
    r
  end

  def group_by(&block)
    return to_enum(:group_by) unless block
    result = {}; each { |x| k = block.call(x); result[k] ||= []; result[k] << x }; result
  end

  def tally(hash = nil)
    result = hash || {}; each { |x| result[x] = (result[x] || 0) + 1 }; result
  end

  def assoc(key)
    each { |e| return e if e.is_a?(Array) && !e.empty? && e[0] == key }
    nil
  end

  def rassoc(val)
    each { |e| return e if e.is_a?(Array) && e.length >= 2 && e[1] == val }
    nil
  end

  def bsearch(&block)
    return to_enum(:bsearch) unless block
    lo = 0; hi = length
    # Detect mode from first truthy result
    # find-minimum mode: block returns true/false
    # find-any mode: block returns negative/zero/positive
    mode = nil
    result_idx = nil
    lo = 0; hi = length
    while lo < hi
      mid = (lo + hi) / 2
      val = block.call(self[mid])
      if val == true
        mode ||= :min
        hi = mid
      elsif val == false || val.nil?
        mode ||= :min
        lo = mid + 1
      elsif val.is_a?(Integer) || val.is_a?(Float)
        mode = :any
        if val == 0
          return self[mid]
        elsif val < 0
          lo = mid + 1
        else
          hi = mid
        end
      else
        raise TypeError, "wrong argument type #{val.class} (must be numeric, true, false or nil)"
      end
    end
    return nil if mode == :any
    lo < length ? self[lo] : nil
  end

  def bsearch_index(&block)
    return to_enum(:bsearch_index) unless block
    lo = 0; hi = length
    mode = nil
    while lo < hi
      mid = (lo + hi) / 2
      val = block.call(self[mid])
      if val == true
        mode ||= :min
        hi = mid
      elsif val == false || val.nil?
        mode ||= :min
        lo = mid + 1
      elsif val.is_a?(Integer) || val.is_a?(Float)
        mode = :any
        if val == 0
          return mid
        elsif val < 0
          lo = mid + 1
        else
          hi = mid
        end
      else
        raise TypeError, "wrong argument type #{val.class} (must be numeric, true, false or nil)"
      end
    end
    return nil if mode == :any
    lo < length ? lo : nil
  end

  # $LOAD_PATH.resolve_feature_path(feature) — return [:rb, path] or [:so, path] or nil
  def resolve_feature_path(feature)
    each do |dir|
      rb = File.join(dir.to_s, "#{feature}.rb")
      return [:rb, rb] if File.exist?(rb)
      ['so', 'bundle', 'dylib'].each do |ext|
        so = File.join(dir.to_s, "#{feature}.#{ext}")
        return [:so, so] if File.exist?(so)
      end
    end
    nil
  end
end

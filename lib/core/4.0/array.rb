class Array
  include Enumerable

  def self.[](*args)
    a = allocate
    args.each { |x| a << x }
    a
  end

  def self.try_convert(obj)
    return obj if obj.is_a?(Array)
    return nil unless obj.respond_to?(:to_ary)
    result = obj.to_ary
    raise TypeError, "can't convert #{obj.class} into Array (#{obj.class}#to_ary gives #{result.class})" unless result.is_a?(Array) || result.nil?
    result
  end

  def initialize(size_or_array = nil, fill = nil, &block)
    raise FrozenError, "can't modify frozen #{self.class}" if frozen?
    if size_or_array.nil?
      Intrinsics.kernel_verbose_warn(self, "given block not used") if block
      Intrinsics.array_initialize(self, nil, nil, nil)
    elsif size_or_array.is_a?(Array)
      raise TypeError, "wrong number of arguments (given 2, expected 0..1)" if !fill.nil?
      Intrinsics.kernel_verbose_warn(self, "given block not used") if block
      Intrinsics.array_initialize(self, size_or_array, nil, nil)
    elsif size_or_array.respond_to?(:to_ary, true)
      raise TypeError, "wrong number of arguments (given 2, expected 0..1)" if !fill.nil?
      Intrinsics.kernel_verbose_warn(self, "given block not used") if block
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

  def at(i)
    i = __coerce_to_int__(i)
    Intrinsics.array_at(self, i)
  end

  ARRAY_MAX_INDEX = (1 << 63)

  def <<(v); Intrinsics.array_push(self, v); self; end
  def clear; replace([]); self; end
  def length = Intrinsics.array_length(self)
  alias size length
  def empty? = length == 0
  def to_s = Intrinsics.array_to_s(self)
  alias inspect to_s
  def to_ary = self
  def dup = Intrinsics.array_dup(self)
  def clone(freeze: nil) = Intrinsics.array_clone(self, freeze, self.class)
  def pack(fmt, buffer: nil) = Intrinsics.array_pack(self, fmt, buffer)
  def compact;  reject { |x| x.nil? }; end
  def compact!; reject! { |x| x.nil? }; end
  def reverse!; replace(reverse); self; end
  def sort!(&block); replace(sort(&block)); self; end
  def include?(elem); any? { |x| x == elem }; end
  def unshift(*elems) = Intrinsics.array_unshift(self, *elems)
  alias prepend unshift
  def deconstruct = self
  def fetch_values(*indices, &block) = indices.map { |i| fetch(i, &block) }

  def [](i, len = nil)
    if len
      __slice_int__(i, len)
    elsif i.is_a?(Enumerator::ArithmeticSequence)
      __slice_arith_seq__(i)
    elsif i.is_a?(Range)
      __slice_range__(i)
    else
      i_int = __coerce_to_int__(i)
      raise RangeError, "index too large" if i_int.abs >= ARRAY_MAX_INDEX
      Intrinsics.array_at(self, i_int)
    end
  end

  def []=(i, len_or_val, val = :__unset__)
    __check_frozen__
    if val.equal?(:__unset__)
      # 2-arg form: ary[index] = val or ary[range] = val
      if i.is_a?(Range)
        bi = i.begin
        ei = i.end
        bi_int = bi.nil? ? nil : __coerce_to_int__(bi)
        ei_int = ei.nil? ? nil : __coerce_to_int__(ei)
        i = Range.new(bi_int, ei_int, i.exclude_end?)
      else
        i = __coerce_to_int__(i)
      end
      Intrinsics.array_index_write(self, i, len_or_val)
    else
      # 3-arg form: ary[start, length] = val
      start_int = __coerce_to_int__(i)
      length_int = __coerce_to_int__(len_or_val)
      # Coerce val via to_ary if not already an Array
      unless val.is_a?(Array)
        if val.respond_to?(:to_ary)
          converted = val.to_ary
          val = converted if converted.is_a?(Array)
        end
      end
      Intrinsics.array_slice_write(self, start_int, length_int, val)
    end
  end

  def push(*vals)
    __check_frozen__
    vals.each { |v| Intrinsics.array_push(self, v) }
    self
  end
  alias append push

  def concat(*others)
    return self if others.empty?
    __check_frozen__
    # Coerce and snapshot all args before any mutation (handles concat(self, self))
    coerced = others.map { |other|
      arr = if other.is_a?(Array)
        other
      else
        begin
          r = other.to_ary
          raise TypeError, "to_ary must return Array" unless r.is_a?(Array)
          r
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{other.class} into Array"
        end
      end
      arr.equal?(self) ? arr.dup : arr
    }
    coerced.each { |other| Intrinsics.array_concat(self, other) }
    self
  end

  def replace(other)
    other = __array_coerce__(other) unless other.is_a?(Array)
    Intrinsics.array_replace(self, other)
  end

  def count(val = :__undefined__, &block)
    if val.equal?(:__undefined__)
      return length unless block
      n = 0; each { |x| n += 1 if block.call(x) }; n
    else
      warn "warning: given block not used" if block
      n = 0; each { |x| n += 1 if x == val }; n
    end
  end

  def first(n = :__none__)
    return self[0] if n.equal?(:__none__)
    n = __coerce_to_int__(n)
    raise ArgumentError, "negative array size" if n < 0
    self[0, n]
  end

  def last(n = :__none__)
    return self[length - 1] if n.equal?(:__none__)
    n = __coerce_to_int__(n)
    raise ArgumentError, "negative array size" if n < 0
    self[[length - n, 0].max, n]
  end

  def ==(other)
    return true if equal?(other)
    unless other.is_a?(Array)
      return false unless other.respond_to?(:to_ary)
      return other == self
    end
    return false unless length == other.length
    ongoing = (Fiber[:__array_eq__] ||= [])
    id1, id2 = __id__, other.__id__
    return true if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << [id1, id2]
    begin
      i = 0; while i < length; e1 = self[i]; e2 = other[i]; return false unless e1.__id__ == e2.__id__ || e1 == e2; i += 1; end
      true
    ensure
      ongoing.pop
    end
  end

  def to_a
    return self if instance_of?(Array)
    Array.new(self)
  end

  def to_h(&block)
    r = {}
    idx = 0
    each { |e|
      pair = block ? block.call(e) : e
      pair = __coerce_to_pair__(pair, idx)
      r[pair[0]] = pair[1]
      idx += 1
    }
    r
  end

  def hash
    ongoing = (Fiber[:__array_hash__] ||= [])
    if ongoing.include?(__id__)
      outer_tag = Fiber[:__hash_hash_outer__]
      throw outer_tag, 0 if outer_tag
      return 0
    end
    ongoing << __id__
    outer_tag = Fiber[:__hash_hash_outer__]
    begin
      if outer_tag.nil?
        my_tag = __id__
        acc = 0
        each do |e|
          e_hash = catch(my_tag) do
            Fiber[:__hash_hash_outer__] = my_tag
            e.hash
          end
          Fiber[:__hash_hash_outer__] = nil
          h = e_hash.is_a?(Integer) ? e_hash : e_hash.to_int
          acc = acc * 31 + h
        end
        acc
      else
        acc = 0
        each do |e|
          Fiber[:__hash_hash_outer__] = outer_tag
          h = e.hash
          h = h.to_int unless h.is_a?(Integer)
          acc = acc * 31 + h
        end
        acc
      end
    ensure
      ongoing.delete(__id__)
      Fiber[:__hash_hash_outer__] = outer_tag
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
    other = __array_coerce__(other)
    set = {}; other.each { |e| set[e] = true }
    seen = {}; r = []
    each { |e| r << e and seen[e] = true if set.key?(e) && !seen.key?(e) }
    r
  end

  def |(other)
    other = __array_coerce__(other)
    seen = {}; r = []
    each { |e| r << e and seen[e] = true unless seen.key?(e) }
    other.each { |e| r << e and seen[e] = true unless seen.key?(e) }
    r
  end

  def -(other)
    other = __array_coerce__(other)
    set = {}; other.each { |e| set[e] = true }
    reject { |e| set.key?(e) }
  end

  def +(other)
    other = __array_coerce__(other)
    r = Array.new(self)
    r.concat(other)
    r
  end

  def *(n)
    if n.is_a?(String)
      join(n)
    elsif n.is_a?(Integer)
      raise ArgumentError, "negative argument" if n < 0
      r = []; n.times { r.concat(self) }; r
    elsif n.respond_to?(:to_str)
      join(n.to_str)
    else
      begin
        n_int = n.to_int
        raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n_int.is_a?(Integer)
        raise ArgumentError, "negative argument" if n_int < 0
        r = []; n_int.times { r.concat(self) }; r
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{n.class} into Integer"
      end
    end
  end

  def flatten(depth = nil)
    d =
      if depth.nil?
        nil
      elsif depth.is_a?(Integer)
        depth < 0 ? nil : depth
      else
        begin
          n = depth.to_int
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{depth.class} into Integer"
        end
        raise TypeError, "no implicit conversion of #{depth.class} into Integer" unless n.is_a?(Integer)
        n < 0 ? nil : n
      end
    result = []
    __flatten_into__(self, d, result, [])
    result
  end

  def flatten!(depth = nil)
    __check_frozen__
    result = flatten(depth)
    return nil if result == self
    replace(result)
    self
  end

  def uniq(&block)
    seen = {}
    r = []
    i = 0
    while i < length
      e = Intrinsics.array_at(self, i)
      key = block ? block.call(e) : e
      unless seen.key?(key)
        r << e
        seen[key] = true
      end
      i += 1
    end
    r
  end

  def reverse
    n = length
    result = []
    i = n - 1
    while i >= 0
      result << Intrinsics.array_at(self, i)
      i -= 1
    end
    result
  end

  def <=>(other)
    unless other.is_a?(Array)
      begin
        converted = other.to_ary
        return nil unless converted.is_a?(Array)
        other = converted
      rescue NoMethodError
        return nil
      rescue
        return nil
      end
    end
    ongoing = (Fiber[:__array_cmp__] ||= [])
    id1, id2 = __id__, other.__id__
    key = [id1, id2]
    return 0 if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << key
    begin
      i = 0
      while i < length && i < other.length
        c = self[i] <=> other[i]
        return nil if c.nil?
        return c if c != 0
        i += 1
      end
      length <=> other.length
    ensure
      ongoing.pop
    end
  end

  def sort(&block)
    return dup if length <= 1
    cmp = block || method(:__default_cmp__)
    __merge_sort__(dup, cmp)
  end

  def sort_by(&block)
    return to_enum(:sort_by) unless block
    pairs = map { |e| [block.call(e), e] }
    pairs = __merge_sort__(pairs, ->(a, b) {
      c = a[0] <=> b[0]
      c.nil? ? 0 : c
    })
    pairs.map { |_, e| e }
  end

  def sort_by!(&block)
    return to_enum(:sort_by!) { size } unless block
    __check_frozen__
    replace(sort_by(&block))
    self
  end

  def min(&block)
    return nil if empty?
    if block
      r = self[0]
      each_with_index do |x, i|
        next if i == 0
        cmp = block.call(x, r)
        raise ArgumentError, "comparison failed" if cmp.nil?
        if cmp < 0
          r = x      # new element is smaller
        elsif cmp > 0
          # keep r   # new element is larger
        end
      end
      r
    else
      reduce { |a, b|
        cmp = a <=> b
        raise ArgumentError, "comparison of #{a.class} with #{b.class} failed" if cmp.nil?
        cmp <= 0 ? a : b
      }
    end
  end

  def max(&block)
    return nil if empty?
    if block
      r = self[0]
      each_with_index do |x, i|
        next if i == 0
        cmp = block.call(x, r)
        raise ArgumentError, "comparison failed" if cmp.nil?
        if cmp > 0
          r = x      # new element is larger
        elsif cmp < 0
          # keep r   # new element is smaller
        end
      end
      r
    else
      reduce { |a, b|
        cmp = a <=> b
        raise ArgumentError, "comparison of #{a.class} with #{b.class} failed" if cmp.nil?
        cmp >= 0 ? a : b
      }
    end
  end

  def sum(initial = nil, &block)
    acc = initial.nil? ? 0 : initial
    # Kahan's compensated summation for all-finite-float arrays (no block, no init override)
    if initial.nil? && !block && all? { |e| e.is_a?(Float) && e.finite? }
      c = 0.0; acc = 0.0
      i = 0; n = length
      while i < n
        y = self[i] - c; t = acc + y; c = (t - acc) - y; acc = t
        i += 1
      end
      return acc
    end
    i = 0
    while i < length
      e = block ? block.call(self[i]) : self[i]
      acc = acc + e
      i += 1
    end
    acc
  end

  def join(sep = nil)
    if sep.nil?
      sep = $,
      if sep && !Fiber[:__join_warn_guard__]
        Fiber[:__join_warn_guard__] = true
        begin
          warn "warning: $, is set to non-nil value"
        ensure
          Fiber[:__join_warn_guard__] = nil
        end
      end
    end
    return ''.force_encoding('US-ASCII') if empty?
    sep_str =
      if sep.nil?
        ''
      elsif sep.is_a?(String)
        sep
      else
        begin
          s = sep.to_str
          raise TypeError, "no implicit conversion of #{sep.class} into String" unless s.is_a?(String)
          s
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{sep.class} into String"
        end
      end
    guard = (Fiber[:__array_join_guard__] ||= [])
    raise ArgumentError, "recursive array join" if guard.include?(__id__)
    guard << __id__
    begin
      # Initialize result with the encoding of the first string-like element,
      # matching MRI behavior where the first element's encoding is used as base.
      _join_first_enc =
        if sep_str && !sep_str.empty?
          sep_str.encoding
        else
          _join_first_str = nil
          each do |e|
            if e.is_a?(String)
              _join_first_str = e
              break
            elsif (s = begin; e.to_str; rescue NoMethodError; nil; end).is_a?(String)
              _join_first_str = s
              break
            end
          end
          _join_first_str ? _join_first_str.encoding : Encoding::UTF_8
        end
      result = ''.force_encoding(_join_first_enc)
      first = true
      each { |e|
        result += sep_str unless first
        first = false
        if e.is_a?(String)
          result += e
        elsif e.is_a?(Array)
          result += e.join(sep_str)
        else
          # Try to_str, then to_ary, then to_s (direct calls, no respond_to? check)
          str_val = begin; e.to_str; rescue NoMethodError; nil; end
          if str_val.is_a?(String)
            result += str_val
          elsif str_val.nil?
            ary_val = begin; e.to_ary; rescue NoMethodError; nil; end
            if ary_val.is_a?(Array)
              result += ary_val.join(sep_str)
            elsif ary_val.nil?
              result += e.to_s
            else
              result += e.to_s
            end
          else
            result += e.to_s
          end
        end
      }
      result
    ensure
      guard.pop
    end
  end

  def pop(__native_n__ = :__none__)
    __check_frozen__
    if __native_n__.equal?(:__none__)
      Intrinsics.array_pop(self)
    else
      __native_n__ = __coerce_to_int__(__native_n__)
      raise ArgumentError, "negative array size" if __native_n__ < 0
      len = length
      cnt = __native_n__ > len ? len : __native_n__
      result = self[len - cnt, cnt]
      self[len - cnt, cnt] = []
      result
    end
  end

  def shift(n = :__none__)
    __check_frozen__
    if n.equal?(:__none__)
      Intrinsics.array_shift(self)
    else
      n = __coerce_to_int__(n)
      raise ArgumentError, "negative array size" if n < 0
      len = length
      cnt = n > len ? len : n
      result = self[0, cnt]
      self[0, cnt] = []
      result
    end
  end

  def dig(idx, *rest)
    val = self[idx]
    return val if rest.empty?
    return nil if val.nil?
    raise TypeError, "#{val.class} does not have #dig method" unless val.respond_to?(:dig)
    val.dig(*rest)
  end
  alias slice []

  def slice!(i, len = :__none__)
    __check_frozen__
    if len.equal?(:__none__)
      if i.is_a?(Range)
        bi = i.begin
        ei = i.end
        bi_int = bi.nil? ? 0 : __coerce_to_int__(bi)
        ei_int = ei.nil? ? nil : __coerce_to_int__(ei)
        n = length
        b = bi_int < 0 ? bi_int + n : bi_int
        return nil if b < 0 || b > n
        e = ei_int.nil? ? n - 1 : (ei_int < 0 ? ei_int + n : ei_int)
        e -= 1 if i.exclude_end? && !ei_int.nil?
        cnt = e < b ? 0 : [e - b + 1, n - b].min
        result = self[b, cnt]
        self[b, cnt] = []
        result
      else
        i_int = __coerce_to_int__(i)
        n = length
        adj = i_int < 0 ? i_int + n : i_int
        return nil if adj < 0 || adj >= n
        val = Intrinsics.array_at(self, i_int)
        self[i_int, 1] = []
        val
      end
    else
      start_int = __coerce_to_int__(i)
      len_int = __coerce_to_int__(len)
      result = self[start_int, len_int]
      return nil if result.nil?
      self[start_int, len_int] = []
      result
    end
  end

  def delete_at(i)
    i = __coerce_to_int__(i)
    return nil if i >= length || i < -length
    val = self[i]
    self[i, 1] = []
    val
  end

  def delete(elem, &block)
    found = any? { |x| x == elem }
    if found
      reject! { |x| x == elem }
      elem
    else
      block ? block.call : nil
    end
  end

  def delete_if(&block)
    return to_enum(:delete_if) { size } unless block
    reject!(&block)
    self
  end

  def index(elem = :__none__, &block)
    if !elem.equal?(:__none__)
      warn "warning: given block not used" if block
      i = 0; while i < length; return i if self[i] == elem; i += 1; end; nil
    elsif block
      i = 0; while i < length; return i if block.call(self[i]); i += 1; end; nil
    else
      return to_enum(:index)
    end
  end
  alias find_index index

  def take(n)
    n = __coerce_to_int__(n)
    raise ArgumentError, "attempt to take negative size" if n < 0
    r = []; i = 0
    while i < n && i < length; r << self[i]; i += 1; end
    r
  end

  def drop(n)
    n = __coerce_to_int__(n)
    raise ArgumentError, "attempt to drop negative size" if n < 0
    r = []; i = n
    while i < length; r << self[i]; i += 1; end
    r
  end

  def rotate(n = 1)
    n = __coerce_to_int__(n)
    return dup if empty?
    n = n % length
    return dup if n == 0
    self[n, length - n] + self[0, n]
  end

  def sample(n = :__none__, random: nil)
    if n.equal?(:__none__)
      return nil if empty?
      if random.nil?
        Intrinsics.array_sample(self)
      else
        idx = __array_rand_int__(random, length)
        Intrinsics.array_at(self, idx)
      end
    else
      n = __coerce_to_int__(n)
      raise ArgumentError, "negative sample number" if n < 0
      len = length
      n = len if n > len
      return Intrinsics.array_sample_n(self, n) if random.nil?
      pool = Array.new(self)
      n.times do |i|
        j = i + __array_rand_int__(random, len - i)
        tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
      end
      pool[0, n]
    end
  end

  def shuffle(random: nil)
    result = Array.new(self)
    len = result.length
    i = len - 1
    while i > 0
      j = random.nil? ? rand(i + 1) : __array_rand_int__(random, i + 1)
      tmp = result[i]; result[i] = result[j]; result[j] = tmp
      i -= 1
    end
    result
  end

  def shuffle!(random: nil)
    __check_frozen__
    replace(shuffle(random: random))
    self
  end

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

  def combination(n, &block)
    n = __coerce_to_int__(n)
    unless block
      sz = if n < 0
        0
      elsif n == 0
        1
      elsif n > length
        0
      else
        __binomial_coeff__(length, n)
      end
      return to_enum(:combination, n) { sz }
    end
    return self if n < 0 || n > length
    __combination_r__(self, n, 0, [], block)
    self
  end

  def permutation(n_arg = nil, &block)
    n = n_arg.nil? ? length : __coerce_to_int__(n_arg)
    unless block
      sz = if n < 0 || n > length
        0
      else
        p = 1; (length - n + 1..length).each { |k| p *= k }; p
      end
      return n_arg.nil? ? to_enum(:permutation) { sz } : to_enum(:permutation, n) { sz }
    end
    return self if n < 0 || n > length
    arr = self.dup
    __permutation_r__(arr, n, [], Array.new(arr.length, false), block)
    self
  end

  def each
    return to_enum(:each) { size } unless block_given?
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end

  def each_index
    return to_enum(:each_index) { size } unless block_given?
    i = 0
    while i < length
      yield i
      i += 1
    end
    self
  end

  def fetch(i, default = :__unset__, &block)
    orig_i = i
    i = __coerce_to_int__(i)
    n = length
    i = i < 0 ? i + n : i
    if i >= 0 && i < n
      self[i]
    elsif block
      warn "warning: block supersedes default value argument" unless default.equal?(:__unset__)
      block.call(orig_i)
    elsif !default.equal?(:__unset__)
      default
    else
      raise IndexError, "index #{orig_i} outside of array bounds: #{-n}...#{n}"
    end
  end

  def insert(idx, *vals)
    __check_frozen__
    return self if vals.empty?
    idx = __coerce_to_int__(idx)
    n = length
    raise IndexError, "index #{idx} too small for array; minimum: #{-n - 1}" if idx < -(n + 1)
    idx = n + 1 + idx if idx < 0
    self[idx, 0] = vals
    self
  end

  def fill(arg1 = :__unset__, arg2 = :__unset__, arg3 = :__unset__, &block)
    if block
      # fill([start_or_range [, len]]) { |i| ... }
      raise ArgumentError, "wrong number of arguments" unless arg3.equal?(:__unset__)
      if arg1.equal?(:__unset__)
        fill_start = 0
        fill_len = nil
      elsif arg1.is_a?(Range)
        fill_start, fill_len = __fill_range_bounds__(arg1)
      else
        fill_start = __coerce_to_int__(arg1)
        fill_start = [fill_start + length, 0].max if fill_start < 0
        fill_len = (arg2.equal?(:__unset__) || arg2.nil?) ? nil : __coerce_to_int__(arg2)
        fill_len = 0 if fill_len && fill_len < 0
      end
      fill_value = nil
    else
      # fill(value [, start_or_range [, len]])
      raise ArgumentError, "wrong number of arguments" if arg1.equal?(:__unset__)
      fill_value = arg1
      if arg2.equal?(:__unset__) || arg2.nil?
        fill_start = 0
        fill_len = nil
      elsif arg2.is_a?(Range)
        raise TypeError, "no implicit conversion of #{arg3.class} into Array" unless arg3.equal?(:__unset__)
        fill_start, fill_len = __fill_range_bounds__(arg2)
      else
        fill_start = __coerce_to_int__(arg2)
        fill_start = [fill_start + length, 0].max if fill_start < 0
        fill_len = (arg3.equal?(:__unset__) || arg3.nil?) ? nil : __coerce_to_int__(arg3)
        fill_len = 0 if fill_len && fill_len < 0
      end
    end
    __check_frozen__
    if fill_len
      raise RangeError, "fill length too large" if fill_len >= (1 << 63)
      raise ArgumentError, "fill length too large" if fill_len > (1 << 30)
    end
    n = length
    stop = fill_len.nil? ? [n, fill_start].max : fill_start + fill_len
    i = fill_start
    while i < stop
      self[i] = block ? block.call(i) : fill_value
      i += 1
    end
    self
  end

  def intersect?(other)
    unless other.is_a?(Array)
      begin
        other = other.to_ary
        raise TypeError, "no implicit conversion into Array" unless other.is_a?(Array)
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{other.class} into Array"
      end
    end
    set = {}
    other.each { |e| set[e] = true }
    any? { |e| set.key?(e) }
  end

  def map(&block)
    return to_enum(:map) { size } unless block
    result = []
    i = 0
    while i < length
      result << block.call(Intrinsics.array_at(self, i))
      i += 1
    end
    result
  end

  def map!(&block)
    return to_enum(:map!) { size } unless block
    __check_frozen__
    i = 0
    while i < length
      Intrinsics.array_index_write(self, i, block.call(Intrinsics.array_at(self, i)))
      i += 1
    end
    self
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
    __check_frozen__
    n = length
    write_idx = 0
    read_idx = 0
    begin
      while read_idx < length
        unless block.call(self[read_idx])
          self[write_idx] = self[read_idx]
          write_idx += 1
        end
        read_idx += 1
      end
    rescue => e
      while read_idx < length
        self[write_idx] = self[read_idx]
        write_idx += 1
        read_idx += 1
      end
      raise e
    ensure
      self[write_idx, length - write_idx] = [] if write_idx < length
    end
    write_idx == n ? nil : self
  end

  def select!(&block)
    return to_enum(:select!) { size } unless block
    __check_frozen__
    n = length
    write_idx = 0
    read_idx = 0
    begin
      while read_idx < length
        if block.call(self[read_idx])
          self[write_idx] = self[read_idx]
          write_idx += 1
        end
        read_idx += 1
      end
    rescue => e
      while read_idx < length
        self[write_idx] = self[read_idx]
        write_idx += 1
        read_idx += 1
      end
      raise e
    ensure
      self[write_idx, length - write_idx] = [] if write_idx < length
    end
    write_idx == n ? nil : self
  end
  alias filter! select!

  def keep_if(&block)
    return to_enum(:keep_if) { size } unless block
    __check_frozen__
    write_idx = 0
    read_idx = 0
    begin
      while read_idx < length
        if block.call(self[read_idx])
          self[write_idx] = self[read_idx]
          write_idx += 1
        end
        read_idx += 1
      end
    rescue => e
      while read_idx < length
        self[write_idx] = self[read_idx]
        write_idx += 1
        read_idx += 1
      end
      raise e
    ensure
      self[write_idx, length - write_idx] = [] if write_idx < length
    end
    self
  end

  def flat_map(&block)
    return to_enum(:flat_map) { size } unless block
    r = []
    each { |e|
      v = block.call(e)
      if v.is_a?(Array)
        v.each { |x| r << x }
      elsif v.respond_to?(:to_ary)
        arr = v.to_ary
        if arr.nil?
          r << v
        elsif arr.is_a?(Array)
          arr.each { |x| r << x }
        else
          raise TypeError, "can't convert #{v.class} into Array (#{v.class}#to_ary gives #{arr.class})"
        end
      else
        r << v
      end
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

  def find(ifnone = nil, &block)
    return to_enum(:find, ifnone) unless block
    each { |x| return x if block.call(x) }
    ifnone ? ifnone.call : nil
  end
  alias detect find

  def any?(pat = :__none__, &block)
    pat.equal?(:__none__) ? super(&block) : super(pat, &block)
  end

  def all?(pat = :__none__, &block)
    pat.equal?(:__none__) ? super(&block) : super(pat, &block)
  end

  def none?(pat = :__none__, &block)
    pat.equal?(:__none__) ? super(&block) : super(pat, &block)
  end

  def one?(pat = :__none__, &block)
    pat.equal?(:__none__) ? super(&block) : super(pat, &block)
  end

  def reduce(*args, &block)
    sym, has_initial, initial, should_warn = __parse_reduce_args__(args, block)
    Intrinsics.kernel_verbose_warn(self, "given block not used") if should_warn
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
  # each_slice and each_cons are defined later with block/enumerator support

  def grep(pattern, &block)
    is_regexp = pattern.is_a?(Regexp) rescue false
    r = []
    if block
      each { |x| r << block.call(x) if pattern === x }
    else
      each { |x| matched = is_regexp ? pattern.match?(x) : (pattern === x); r << x if matched }
    end
    r
  end

  def grep_v(pattern, &block)
    is_regexp = pattern.is_a?(Regexp) rescue false
    r = []
    if block
      each { |x| r << block.call(x) unless pattern === x }
    else
      each { |x| matched = is_regexp ? pattern.match?(x) : (pattern === x); r << x unless matched }
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
    each { |e|
      arr = e.is_a?(Array) ? e : begin; e.to_ary; rescue; nil; end
      return arr if arr.is_a?(Array) && !arr.empty? && arr[0] == key
    }
    nil
  end

  def rassoc(val)
    each { |e|
      arr = e.is_a?(Array) ? e : begin; e.to_ary; rescue; nil; end
      return arr if arr.is_a?(Array) && arr.length >= 2 && arr[1] == val
    }
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

  def reverse_each(&block)
    return to_enum(:reverse_each) { size } unless block
    i = length - 1
    while i >= 0
      yield self[i]
      i -= 1
    end
    self
  end

  def rindex(elem = :__none__, &block)
    if !elem.equal?(:__none__)
      warn "warning: given block not used" if block
      i = length - 1; while i >= 0; return i if self[i] == elem; i -= 1; end; nil
    elsif block
      i = length - 1; while i >= 0 && i < length; return i if block.call(self[i]); i -= 1; end; nil
    else
      return to_enum(:rindex)
    end
  end

  def values_at(*indices)
    n = length
    r = []
    indices.each { |i|
      if i.is_a?(Range)
        bi = i.begin
        ei = i.end
        bi_int = bi.nil? ? 0 : __coerce_to_int__(bi)
        b = bi_int < 0 ? bi_int + n : bi_int
        if ei.nil?
          # endless range: go to end of array
          e = n - 1
        else
          ei_int = __coerce_to_int__(ei)
          e = ei_int < 0 ? ei_int + n : ei_int
          e -= 1 if i.exclude_end?
        end
        j = b; while j <= e; r << (j >= 0 && j < n ? self[j] : nil); j += 1; end
      else
        r << self[__coerce_to_int__(i)]
      end
    }
    r
  end

  def repeated_combination(n, &block)
    n = __coerce_to_int__(n)
    unless block
      sz = n < 0 ? 0 : (n == 0 ? 1 : __binomial_coeff__(length + n - 1, n))
      return to_enum(:repeated_combination, n) { sz }
    end
    return self if n < 0
    __repeated_combination_r__(self, n, 0, [], block)
    self
  end

  def repeated_permutation(n, &block)
    n = __coerce_to_int__(n)
    unless block
      sz = n < 0 ? 0 : (length == 0 ? (n == 0 ? 1 : 0) : length ** n)
      return to_enum(:repeated_permutation, n) { sz }
    end
    return self if n < 0
    __repeated_permutation_r__(self.dup, n, [], block)
    self
  end

  def __binomial_coeff__(n, k)
    return 0 if k < 0 || k > n
    k = n - k if k > n - k
    result = 1
    k.times { |i| result = result * (n - i) / (i + 1) }
    result
  end

  def product(*others, &block)
    arrays = [self] + others.map { |o|
      if o.is_a?(Array)
        o
      else
        begin
          converted = o.to_ary
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{o.class} into Array"
        end
        raise TypeError, "no implicit conversion of #{o.class} into Array" unless converted.is_a?(Array)
        converted
      end
    }
    # Check for unreasonably large product
    total = arrays.reduce(1) { |acc, a| acc * a.length }
    raise RangeError, "too big to product" if total > 65536
    if block
      return self if arrays.any?(&:empty?)
      # Yield combinations iteratively
      indices = Array.new(arrays.length, 0)
      loop do
        combo = indices.each_with_index.map { |idx, i| arrays[i][idx] }
        block.call(combo)
        # Increment indices from right
        i = arrays.length - 1
        while i >= 0
          indices[i] += 1
          break if indices[i] < arrays[i].length
          indices[i] = 0
          i -= 1
        end
        break if i < 0
      end
      self
    else
      result = [[]]
      arrays.each { |a| result = result.flat_map { |r| a.map { |e| r + [e] } } }
      result
    end
  end

  def transpose
    return [] if empty?
    rows = map { |row|
      if row.is_a?(Array)
        row
      elsif row.respond_to?(:to_ary)
        converted = row.to_ary
        raise TypeError, "no implicit conversion of #{row.class} into Array" unless converted.is_a?(Array)
        converted
      else
        raise TypeError, "no implicit conversion of #{row.class} into Array"
      end
    }
    n = rows[0].length
    rows.each { |row| raise IndexError, "element size differs (#{row.length} should be #{n})" unless row.length == n }
    (0...n).map { |j| rows.map { |row| row[j] } }
  end

  def take_while(&block)
    return to_enum(:take_while) unless block
    r = []
    each { |e| block.call(e) ? r << e : break }
    r
  end

  def partition(&block)
    return to_enum(:partition) unless block
    yes = []; no = []
    each { |e| block.call(e) ? yes << e : no << e }
    [yes, no]
  end

  def minmax(&block)
    return [nil, nil] if empty?
    [min(&block), max(&block)]
  end

  def minmax_by(&block)
    return to_enum(:minmax_by) unless block
    [min_by(&block), max_by(&block)]
  end

  def min_by(&block)
    return to_enum(:min_by) unless block
    sort_by(&block).first
  end

  def max_by(&block)
    return to_enum(:max_by) unless block
    sort_by(&block).last
  end

  def each_slice(n, &block)
    return to_enum(:each_slice, n) { (length + n - 1) / n } unless block
    i = 0
    while i < length
      yield self[i, n] || []
      i += n
    end
    nil
  end

  def each_cons(n, &block)
    return to_enum(:each_cons, n) { [length - n + 1, 0].max } unless block
    i = 0
    while i + n <= length
      yield self[i, n]
      i += 1
    end
    nil
  end

  def uniq!(&block)
    __check_frozen__
    seen = {}; write_idx = 0; read_idx = 0
    while read_idx < length
      e = Intrinsics.array_at(self, read_idx)
      key = block ? block.call(e) : e
      unless seen.key?(key)
        self[write_idx] = e
        seen[key] = true
        write_idx += 1
      end
      read_idx += 1
    end
    if write_idx < length
      self[write_idx, length - write_idx] = []
      self
    end
  end

  def rotate!(n = 1)
    __check_frozen__
    replace(rotate(n))
    self
  end

  def difference(*others)
    result = Array.new(self)
    others.each { |other| result = result - other }
    result
  end

  def union(*others)
    result = uniq
    others.each { |other| result = result | other }
    result
  end

  def intersection(*others)
    result = dup
    others.each { |other| result = result & other }
    result
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
  private

  def __check_frozen__
    raise FrozenError, "can't modify frozen Array" if frozen?
  end

  def __flatten_into__(arr, depth, result, seen_ids)
    raise ArgumentError, "flatten: cannot flatten recursive array" if seen_ids.include?(arr.__id__)
    seen_ids << arr.__id__
    i = 0
    while i < arr.length
      elem = Intrinsics.array_at(arr, i)
      # Use Intrinsics.object_is_a (bypasses method dispatch) so that elements with
      # catch-all method_missing don't masquerade as Array.
      if Intrinsics.object_is_a(elem, Array) && (depth.nil? || depth > 0)
        __flatten_into__(elem, depth.nil? ? nil : depth - 1, result, seen_ids)
      elsif depth.nil? || depth > 0
        # MRI (rb_check_funcall): checks respond_to?(:to_ary, true) ONLY when the object's
        # singleton class explicitly defines respond_to? or respond_to_missing?. Otherwise,
        # calls to_ary directly (which may succeed via method_missing). This matches the
        # behavior where explicit respond_to?→false gates the call, but inherited respond_to?
        # returning false does not prevent method_missing from handling to_ary.
        if Intrinsics.object_eigenclass_has_respond_to_guard(elem)
          has_to_ary = begin
            elem.respond_to?(:to_ary, true)
          rescue NoMethodError
            false
          end
          if has_to_ary
            converted = elem.to_ary
            if converted.nil?
              result << elem
            elsif Intrinsics.object_is_a(converted, Array)
              __flatten_into__(converted, depth.nil? ? nil : depth - 1, result, seen_ids)
            else
              raise TypeError, "can't convert #{elem.class} into Array (#{elem.class}#to_ary gives #{converted.class})"
            end
          else
            result << elem
          end
        else
          converted = begin
            elem.to_ary
          rescue NoMethodError
            :__no_to_ary__
          end
          if converted == :__no_to_ary__
            result << elem
          elsif converted.nil?
            result << elem
          elsif Intrinsics.object_is_a(converted, Array)
            __flatten_into__(converted, depth.nil? ? nil : depth - 1, result, seen_ids)
          else
            raise TypeError, "can't convert #{elem.class} into Array (#{elem.class}#to_ary gives #{converted.class})"
          end
        end
      else
        result << elem
      end
      i += 1
    end
    seen_ids.pop
  end

  def __default_cmp__(a, b)
    r = a <=> b
    raise ArgumentError, "comparison failed" if r.nil?
    r
  end

  def __merge_sort__(arr, cmp)
    n = arr.length
    return arr if n <= 1
    mid = n / 2
    left = __merge_sort__(arr[0...mid], cmp)
    right = __merge_sort__(arr[mid..], cmp)
    __merge__(left, right, cmp)
  end

  def __merge__(left, right, cmp)
    result = []
    i = 0
    j = 0
    while i < left.length && j < right.length
      c = cmp.call(left[i], right[j])
      raise ArgumentError, "comparison failed" if c.nil?
      if c <= 0
        result << left[i]
        i += 1
      else
        result << right[j]
        j += 1
      end
    end
    while i < left.length
      result << left[i]
      i += 1
    end
    while j < right.length
      result << right[j]
      j += 1
    end
    result
  end

  def __combination_r__(arr, n, start, current, block)
    if n == 0
      block.call(current.dup)
      return
    end
    i = start
    while i <= arr.length - n
      current << arr[i]
      __combination_r__(arr, n - 1, i + 1, current, block)
      current.pop
      i += 1
    end
  end

  def __permutation_r__(arr, n, current, used, block)
    if current.length == n
      block.call(current.dup)
      return
    end
    i = 0
    while i < arr.length
      unless used[i]
        used[i] = true
        current << arr[i]
        __permutation_r__(arr, n, current, used, block)
        current.pop
        used[i] = false
      end
      i += 1
    end
  end

  def __repeated_combination_r__(arr, n, start, current, block)
    if n == 0
      block.call(current.dup)
      return
    end
    i = start
    while i < arr.length
      current << arr[i]
      __repeated_combination_r__(arr, n - 1, i, current, block)
      current.pop
      i += 1
    end
  end

  def __repeated_permutation_r__(arr, n, current, block)
    if current.length == n
      block.call(current.dup)
      return
    end
    i = 0
    while i < arr.length
      current << arr[i]
      __repeated_permutation_r__(arr, n, current, block)
      current.pop
      i += 1
    end
  end

  def __fill_range_bounds__(r)
    n = length
    b = r.begin.nil? ? 0 : __coerce_to_int__(r.begin)
    b_adj = b < 0 ? b + n : b
    raise RangeError, "#{b} is out of range" if b_adj < 0
    end_nil = r.end.nil?
    e = end_nil ? n - 1 : __coerce_to_int__(r.end)
    e_adj = e < 0 ? e + n : e
    e_adj -= 1 if r.exclude_end? && !end_nil
    rlen = e_adj < b_adj ? 0 : e_adj - b_adj + 1
    [b_adj, rlen]
  end

  def __binomial_coeff__(n, k)
    return 0 if k < 0 || k > n
    k = n - k if k > n - k
    result = 1
    k.times { |i| result = result * (n - i) / (i + 1) }
    result
  end

  def __array_rand_int__(rng, n)
    v = rng.rand(n)
    unless v.is_a?(Integer)
      v = v.to_int
      raise TypeError, "to_int should return Integer" unless v.is_a?(Integer)
    end
    raise RangeError, "random number too small #{v}" if v < 0
    raise RangeError, "random number too large #{v}" if v >= n
    v
  end

  def __slice_int__(i, len)
    n = length
    i = __coerce_to_int__(i)
    len = __coerce_to_int__(len)
    raise RangeError, "length too large" if len.abs >= ARRAY_MAX_INDEX
    return nil if len < 0
    s = i < 0 ? i + n : i
    return nil if s < 0 || s > n
    stop = s + len > n ? n : s + len
    r = []; j = s; while j < stop; r << Intrinsics.array_at(self, j); j += 1; end; r
  end

  def __slice_range__(i)
    n = length
    bi = i.begin
    end_nil = i.end.nil?
    bi_int = bi.nil? ? 0 : __coerce_to_int__(bi)
    raise RangeError, "index too large" if bi_int.abs >= ARRAY_MAX_INDEX
    ei_int = end_nil ? n - 1 : __coerce_to_int__(i.end)
    raise RangeError, "index too large" if !end_nil && ei_int.abs >= ARRAY_MAX_INDEX
    b = bi_int < 0 ? bi_int + n : bi_int
    e = ei_int < 0 ? ei_int + n : ei_int
    e -= 1 if i.exclude_end? && !end_nil
    return nil if b > n || b < 0
    return [] if b == n || e < b
    e = n - 1 if e >= n
    r = []; j = b; while j <= e; r << Intrinsics.array_at(self, j); j += 1; end; r
  end

  def __slice_arith_seq__(seq)
    n = length
    b = seq.begin
    e = seq.end
    st = seq.step
    raise ArgumentError, "step can't be 0" if st == 0
    abs_st = st.abs
    if st > 0
      # Positive step
      b_int = b.nil? ? 0 : __coerce_to_int__(b)
      b_int = b_int < 0 ? b_int + n : b_int
      if e.nil?
        # Endless range: OOB begin is nil (step=1) or RangeError (step>1) or [] (begin==n)
        return [] if b_int == n
        if b_int > n
          return nil if st == 1
          raise RangeError, "#{seq.inspect} out of range of array size #{n}"
        end
        result = []
        j = b_int
        while j < n; result << Intrinsics.array_at(self, j); j += st; end
        result
      else
        e_int = __coerce_to_int__(e)
        e_int = e_int < 0 ? e_int + n : e_int
        e_int -= 1 if seq.exclude_end?
        # RangeError if end is reachable from begin (same step alignment) and is OOB, unless step==1
        if e_int >= n && st > 1 && (e_int - b_int) % st == 0
          raise RangeError, "#{seq.inspect} out of range of array size #{n}"
        end
        result = []
        j = b_int
        while j <= e_int
          result << Intrinsics.array_at(self, j) if j >= 0 && j < n
          j += st
        end
        result
      end
    else
      # Negative step
      b_int = b.nil? ? n - 1 : __coerce_to_int__(b)
      b_int = b_int < 0 ? b_int + n : b_int
      if e.nil?
        # Endless (beginless) with negative step: start from b_int, go down to 0
        if b_int >= n
          b_int = n - 1  # clamp
        end
        result = []
        j = b_int
        while j >= 0; result << Intrinsics.array_at(self, j); j += st; end
        result
      else
        e_int = __coerce_to_int__(e)
        e_int = e_int < 0 ? e_int + n : e_int
        lower = seq.exclude_end? ? e_int + 1 : e_int
        # RangeError if begin is OOB and reachable-aligned (same step modular alignment)
        if b_int >= n && abs_st > 1 && (b_int - e_int) % abs_st == 0
          raise RangeError, "#{seq.inspect} out of range of array size #{n}"
        end
        # Clamp b_int to n-1 if OOB
        b_int = n - 1 if b_int >= n
        result = []
        j = b_int
        while j >= lower
          result << Intrinsics.array_at(self, j) if j >= 0 && j < n
          j += st
        end
        result
      end
    end
  end

  def __coerce_to_pair__(pair, idx)
    unless pair.is_a?(Array)
      if pair.respond_to?(:to_ary)
        pair = pair.to_ary
        raise TypeError, "wrong element type #{pair.class} at #{idx} (expected Array)" unless pair.is_a?(Array)
      else
        raise TypeError, "wrong element type #{pair.class} at #{idx} (expected Array)"
      end
    end
    raise ArgumentError, "wrong array length at #{idx} (expected 2, was #{pair.length})" unless pair.length == 2
    pair
  end

  def __array_coerce__(other)
    return other if other.is_a?(Array)
    unless other.respond_to?(:to_ary)
      raise TypeError, "no implicit conversion of #{other.class} into Array"
    end
    result = other.to_ary
    raise TypeError, "no implicit conversion of #{other.class} into Array" unless result.is_a?(Array)
    result
  end

  def __coerce_to_int__(n)
    return n if n.is_a?(Integer)
    begin
      result = n.to_int
      raise TypeError, "can't convert #{n.class} into Integer (to_int gives #{result.class})" unless result.is_a?(Integer)
      result
    rescue NoMethodError
      raise TypeError, "no implicit conversion of #{n.class} into Integer"
    end
  end
end

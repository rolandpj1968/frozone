module Enumerable
  private

  def __unpack_enum_args__(x)
    x.empty? ? nil : (x.length == 1 ? x[0] : x)
  end

  def __parse_reduce_args__(args, block)
    sym = nil; has_initial = false; initial = nil; should_warn = false
    case args.length
    when 0
      raise ArgumentError, "no block given (yield)" unless block
    when 1
      arg = args[0]
      if block
        # With block: treat any single arg as initial value
        has_initial = true; initial = arg
        # Warn if it's a Symbol (would normally be op, but block takes precedence)
        should_warn = true if arg.is_a?(Symbol)
      else
        # Without block: arg must be a method name
        if arg.is_a?(Symbol)
          sym = arg
        elsif arg.is_a?(String)
          sym = arg.to_sym
        elsif arg.respond_to?(:to_str)
          str = arg.to_str
          raise TypeError, "#{arg.inspect} is not a symbol nor a string" unless str.is_a?(String)
          sym = str.to_sym
        else
          raise TypeError, "#{arg.inspect} is not a symbol nor a string"
        end
      end
    when 2
      initial = args[0]; has_initial = true
      arg1 = args[1]
      if arg1.is_a?(Symbol)
        sym = arg1
      elsif arg1.is_a?(String)
        sym = arg1.to_sym
      elsif arg1.respond_to?(:to_str)
        sym = arg1.to_str.to_sym
      else
        raise TypeError, "#{arg1.inspect} is not a symbol nor a string"
      end
      should_warn = true if block
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
    [sym, has_initial, initial, should_warn]
  end

  def __coerce_count__(n, method_name)
    n = __coerce_to_int__(n) unless n.is_a?(Integer)
    raise RangeError, "#{method_name}: integer #{n} too big to convert into `long'" if n > 2**62
    raise ArgumentError, "#{method_name}: negative length (#{n})" if n < 0
    n
  end

  public

  def sort(&block) = to_a.sort(&block)
  def lazy = Enumerator::Lazy.new(self) { |y, *vals| y.yield(*vals) }
  def chain(*enums) = Enumerator::Chain.new(self, *enums)
  alias + chain

  def to_a(*args)
    r = []; each(*args) { |*x| r << __unpack_enum_args__(x) }; r
  end
  alias entries to_a

  def to_h(*args, &block)
    r = {}
    each(*args) do |*x|
      v = __unpack_enum_args__(x)
      pair = block ? block.call(v) : v
      unless pair.is_a?(Array)
        if pair.respond_to?(:to_ary)
          pair = pair.to_ary
          raise TypeError, "wrong element type #{pair.class} (expected Array)" unless pair.is_a?(Array)
        else
          raise TypeError, "wrong element type #{pair.nil? ? 'NilClass' : pair.class} (expected Array)"
        end
      end
      raise ArgumentError, "element has wrong array length (expected 2, was #{pair.length})" unless pair.length == 2
      r[pair[0]] = pair[1]
    end
    r
  end

  def map(&block)
    return to_enum(:map) { respond_to?(:size) ? size : nil } unless block
    r = []
    case block.arity
    when 1 then each { |x| r << block.call(x) }
    when 2 then each { |x, y| r << block.call(x, y) }
    else each { |*x| r << block.call(*x) }
    end
    r
  end
  alias collect map

  def flat_map(&block)
    return to_enum(:flat_map) { respond_to?(:size) ? size : nil } unless block
    r = []
    each { |*x|
      v = __unpack_enum_args__(x)
      w = block.call(v)
      if w.is_a?(Array)
        w.each { |e| r << e }
      elsif w.respond_to?(:to_ary)
        arr = w.to_ary
        if arr.nil?
          r << w
        elsif arr.is_a?(Array)
          arr.each { |e| r << e }
        else
          raise TypeError, "can't convert #{w.class} into Array (#{w.class}#to_ary gives #{arr.class})"
        end
      else
        r << w
      end
    }
    r
  end
  alias collect_concat flat_map

  def select(&block)
    return to_enum(:select) { respond_to?(:size) ? size : nil } unless block
    r = []; each { |*x| v = __unpack_enum_args__(x); r << v if block.call(v) }; r
  end
  alias filter select
  alias find_all select

  def reject(&block)
    return to_enum(:reject) { respond_to?(:size) ? size : nil } unless block
    r = []; each { |*x| v = __unpack_enum_args__(x); r << v unless block.call(v) }; r
  end

  def find(ifnone = nil, &block)
    return to_enum(:find, ifnone) unless block
    each { |*x| v = __unpack_enum_args__(x); return v if block.call(v) }
    ifnone ? ifnone.call : nil
  end
  alias detect find

  def find_index(val = :__none__, &block)
    if !val.equal?(:__none__)
      warn "warning: given block not used" if block
      i = 0; each { |*x| v = __unpack_enum_args__(x); return i if v == val; i += 1 }; nil
    elsif block
      i = 0; each { |*x| return i if block.call(*x); i += 1 }; nil
    else
      return to_enum(:find_index)
    end
  end

  def include?(val)
    each { |*x| v = __unpack_enum_args__(x); return true if v == val }
    false
  end
  alias member? include?

  def any?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = __unpack_enum_args__(x); return true if (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = __unpack_enum_args__(x); return true if pat === v }
    end
    false
  end

  def all?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = __unpack_enum_args__(x); return false unless (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = __unpack_enum_args__(x); return false unless pat === v }
    end
    true
  end

  def none?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = __unpack_enum_args__(x); return false if (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = __unpack_enum_args__(x); return false if pat === v }
    end
    true
  end

  def one?(pat = :__none__, &block)
    found = false
    if pat.equal?(:__none__)
      each do |*x|
        v = __unpack_enum_args__(x)
        if block ? block.call(*x) : v
          return false if found
          found = true
        end
      end
    else
      warn "warning: given block not used" if block
      each do |*x|
        v = __unpack_enum_args__(x)
        if pat === v
          return false if found
          found = true
        end
      end
    end
    found
  end

  def count(val = :__none__, &block)
    if val.equal?(:__none__)
      return to_a.length unless block
      n = 0; each { |*x| n += 1 if block.call(*x) }; n
    else
      warn "warning: given block not used" if block
      n = 0; each { |*x| v = __unpack_enum_args__(x); n += 1 if v == val }; n
    end
  end

  def reduce(*args, &block)
    sym, has_initial, initial, should_warn = __parse_reduce_args__(args, block)
    Intrinsics.kernel_verbose_warn(self, "given block not used") if should_warn
    acc = initial; first = !has_initial
    each do |*x|
      v = __unpack_enum_args__(x)
      if first
        acc = v; first = false
      elsif sym
        acc = acc.send(sym, v)
      else
        acc = block.call(acc, v)
      end
    end
    acc
  end
  alias inject reduce

  def sum(initial = 0, &block)
    r = initial
    using_kahan = r.is_a?(Float)
    c = 0.0
    each do |*x|
      v = __unpack_enum_args__(x)
      v = block.call(v) if block
      if !using_kahan && v.is_a?(Float)
        r = r.to_f
        using_kahan = true
      end
      if using_kahan
        y = v - c; t = r + y; c = (t - r) - y; r = t
      else
        r += v
      end
    end
    r
  end

  def min(n = nil, &block)
    if n
      n = __coerce_count__(n, "min")
      arr = sort(&block)
      arr.first(n)
    else
      result = nil; first = true
      each do |*x|
        v = __unpack_enum_args__(x)
        if first
          result = v; first = false
        elsif block
          cmp = block.call(v, result)
          raise ArgumentError, "comparison failed" if cmp.nil?
          result = v if cmp < 0
        else
          cmp = v <=> result
          raise ArgumentError, "comparison of #{v.class} with #{result.class} failed" if cmp.nil?
          result = v if cmp < 0
        end
      end
      result
    end
  end

  def max(n = nil, &block)
    if n
      n = __coerce_count__(n, "max")
      arr = sort(&block)
      arr.last(n).reverse
    else
      result = nil; first = true
      each do |*x|
        v = __unpack_enum_args__(x)
        if first
          result = v; first = false
        elsif block
          cmp = block.call(v, result)
          raise ArgumentError, "comparison failed" if cmp.nil?
          result = v if cmp > 0
        else
          cmp = v <=> result
          raise ArgumentError, "comparison of #{v.class} with #{result.class} failed" if cmp.nil?
          result = v if cmp > 0
        end
      end
      result
    end
  end

  def min_by(n = nil, &block)
    return to_enum(:min_by) { respond_to?(:size) ? size : nil } unless block
    if n
      n = __coerce_count__(n, "min_by")
      sort_by(&block).first(n)
    else
      best = nil; best_key = nil; first = true
      each do |*x|
        v = __unpack_enum_args__(x)
        k = block.call(v)
        if first || (k <=> best_key) < 0
          best = v; best_key = k; first = false
        end
      end
      best
    end
  end

  def max_by(n = nil, &block)
    return to_enum(:max_by) { respond_to?(:size) ? size : nil } unless block
    if n
      n = __coerce_count__(n, "max_by")
      sort_by(&block).last(n).reverse
    else
      best = nil; best_key = nil; first = true
      each do |*x|
        v = __unpack_enum_args__(x)
        k = block.call(v)
        if first || (k <=> best_key) > 0
          best = v; best_key = k; first = false
        end
      end
      best
    end
  end

  def minmax(&block)
    min_val = nil; max_val = nil; first = true
    each do |*x|
      v = __unpack_enum_args__(x)
      if first
        min_val = max_val = v; first = false
      elsif block
        cmp_min = block.call(v, min_val)
        raise ArgumentError, "comparison failed" if cmp_min.nil?
        min_val = v if cmp_min < 0
        cmp_max = block.call(v, max_val)
        raise ArgumentError, "comparison failed" if cmp_max.nil?
        max_val = v if cmp_max > 0
      else
        cmp_min = v <=> min_val
        raise ArgumentError, "comparison of #{v.class} with #{min_val.class} failed" if cmp_min.nil?
        min_val = v if cmp_min < 0
        cmp_max = v <=> max_val
        raise ArgumentError, "comparison of #{v.class} with #{max_val.class} failed" if cmp_max.nil?
        max_val = v if cmp_max > 0
      end
    end
    [min_val, max_val]
  end

  def minmax_by(&block)
    return to_enum(:minmax_by) { respond_to?(:size) ? size : nil } unless block
    min_val = nil; max_val = nil; min_key = nil; max_key = nil; first = true
    each do |*x|
      v = __unpack_enum_args__(x)
      k = block.call(v)
      if first
        min_val = max_val = v; min_key = max_key = k; first = false
      else
        if (k <=> min_key) < 0; min_val = v; min_key = k; end
        if (k <=> max_key) > 0; max_val = v; max_key = k; end
      end
    end
    [min_val, max_val]
  end

  def sort_by(&block)
    return to_enum(:sort_by) { respond_to?(:size) ? size : nil } unless block
    to_a.sort_by(&block)
  end

  def each_with_index(*args, &block)
    return to_enum(:each_with_index, *args) { respond_to?(:size) ? size : nil } unless block
    i = 0
    each(*args) do |*x|
      v = __unpack_enum_args__(x)
      block.call(v, i); i += 1
    end
    self
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) { respond_to?(:size) ? size : nil } unless block
    each do |*x|
      v = __unpack_enum_args__(x)
      block.call(v, obj)
    end
    obj
  end

  def each_slice(n, &block)
    n = __coerce_count__(n, "each_slice")
    raise ArgumentError, "invalid slice size" if n == 0
    return to_enum(:each_slice, n) { s = respond_to?(:size) ? size : nil; s ? (s.zero? ? 0 : (s + n - 1) / n) : nil } unless block
    buf = []
    each do |*x|
      buf << __unpack_enum_args__(x)
      if buf.length == n
        block.call(buf); buf = []
      end
    end
    block.call(buf) unless buf.empty?
    self
  end

  def each_cons(n, &block)
    n = __coerce_count__(n, "each_cons")
    raise ArgumentError, "invalid size" if n == 0
    return to_enum(:each_cons, n) { s = respond_to?(:size) ? size : nil; s ? [s - n + 1, 0].max : nil } unless block
    buf = []
    each do |*x|
      buf << __unpack_enum_args__(x)
      buf.shift if buf.length > n
      block.call(buf.dup) if buf.length == n
    end
    self
  end

  def zip(*others)
    arrays = others.map do |o|
      if o.respond_to?(:to_ary)
        o.to_ary
      else
        begin
          o.to_enum(:each).to_a
        rescue NoMethodError
          raise TypeError, "wrong argument type #{o.class} (must respond to :each)"
        end
      end
    end
    result = []
    i = 0
    each do |*x|
      v = __unpack_enum_args__(x)
      row = [v]
      arrays.each { |a| row << (i < a.length ? a[i] : nil) }
      if block_given?
        yield row
      else
        result << row
      end
      i += 1
    end
    block_given? ? nil : result
  end

  def group_by(&block)
    return to_enum(:group_by) { respond_to?(:size) ? size : nil } unless block
    result = {}
    each do |*x|
      v = __unpack_enum_args__(x)
      k = block.call(v); result[k] ||= []; result[k] << v
    end
    result
  end

  def tally(hash = nil)
    hash = __coerce_to_hash__(hash) if hash && !hash.is_a?(Hash)
    result = hash || {}
    each do |*x|
      v = __unpack_enum_args__(x)
      result.store(v, result.fetch(v, 0) + 1)
    end
    result
  end

  def grep(pattern, &block)
    r = []
    each do |*x|
      v = __unpack_enum_args__(x)
      r << (block ? block.call(v) : v) if pattern === v
    end
    r
  end

  def grep_v(pattern, &block)
    r = []
    each do |*x|
      v = __unpack_enum_args__(x)
      r << (block ? block.call(v) : v) unless pattern === v
    end
    r
  end

  def first(n = :__none__)
    if n.equal?(:__none__)
      each { |*x| return __unpack_enum_args__(x) }
      nil
    else
      n = __coerce_count__(n, "first")
      return [] if n == 0
      r = []
      catch(:__first_done__) do
        each do |*x|
          r << __unpack_enum_args__(x)
          throw :__first_done__ if r.length >= n
        end
      end
      r
    end
  end

  def take(n)
    n = __coerce_count__(n, "take")
    return [] if n == 0
    r = []
    catch(:__take_done__) do
      each do |*x|
        r << __unpack_enum_args__(x)
        throw :__take_done__ if r.length >= n
      end
    end
    r
  end

  def take_while(&block)
    return to_enum(:take_while) unless block
    r = []
    each do |*x|
      v = __unpack_enum_args__(x)
      break unless block.call(*x)
      r << v
    end
    r
  end

  def drop(n)
    n = __coerce_to_int__(n) unless n.is_a?(Integer)
    raise ArgumentError, "attempt to drop negative size" if n < 0
    r = []; i = 0
    each { |*x| v = __unpack_enum_args__(x); i < n ? (i += 1) : (r << v) }
    r
  end

  def drop_while(&block)
    return to_enum(:drop_while) unless block
    r = []; dropping = true
    each do |*x|
      v = __unpack_enum_args__(x)
      dropping = false if dropping && !block.call(v)
      r << v unless dropping
    end
    r
  end

  def uniq(&block)
    seen = {}; r = []
    each do |*x|
      v = __unpack_enum_args__(x)
      k = block ? block.call(v) : v
      r << v and seen[k] = true unless seen.key?(k)
    end
    r
  end

  def chunk(&block)
    return to_enum(:chunk) unless block
    Enumerator.new do |y|
      last_key = nil; has_key = false; buf = []
      each do |*x|
        v = __unpack_enum_args__(x)
        k = block.call(v)
        if k.nil? || k == :_separator
          y << [last_key, buf] if has_key && !buf.empty?
          has_key = false; last_key = nil; buf = []
        elsif k.is_a?(Symbol) && k.to_s[0] == '_' && k != :_alone
          raise RuntimeError, "chunk doesn't accept special symbol #{k.inspect}"
        elsif k == :_alone
          y << [last_key, buf] if has_key && !buf.empty?
          y << [:_alone, [v]]
          has_key = false; last_key = nil; buf = []
        elsif !has_key || k != last_key
          y << [last_key, buf] if has_key && !buf.empty?
          last_key = k; has_key = true; buf = [v]
        else
          buf << v
        end
      end
      y << [last_key, buf] if has_key && !buf.empty?
    end
  end

  def chunk_while(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = __unpack_enum_args__(x)
        if buf.nil?
          buf = [v]
        elsif block.call(buf.last, v)
          buf << v
        else
          y << buf; buf = [v]
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def slice_when(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = __unpack_enum_args__(x)
        if buf.nil?
          buf = [v]
        elsif block.call(buf.last, v)
          y << buf; buf = [v]
        else
          buf << v
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def filter_map(&block)
    return to_enum(:filter_map) unless block
    r = []
    each { |*x| v = __unpack_enum_args__(x); w = block.call(v); r << w if w }
    r
  end

  def compact
    r = []; each { |*x| v = __unpack_enum_args__(x); r << v unless v.nil? }; r
  end

  def each_entry(*args, &block)
    return to_enum(:each_entry, *args) { respond_to?(:size) ? size : nil } unless block
    each(*args) { |*x| v = __unpack_enum_args__(x); block.call(v) }
    self
  end

  def reverse_each(&block)
    return to_enum(:reverse_each) { respond_to?(:size) ? size : nil } unless block
    to_a.reverse.each { |x| block.call(x) }
    self
  end

  def partition(&block)
    return to_enum(:partition) { respond_to?(:size) ? size : nil } unless block
    yes = []; no = []
    each { |*x| v = __unpack_enum_args__(x); (block.call(v) ? yes : no) << v }
    [yes, no]
  end

  def cycle(n = nil, &block)
    n = __coerce_to_int__(n) unless n.nil? || n.is_a?(Integer)
    _self = self
    return to_enum(:cycle, n) {
      s = _self.respond_to?(:size) ? _self.size : nil
      if s.nil?
        nil
      elsif n.nil?
        s == 0 ? 0 : Float::INFINITY
      elsif n <= 0
        0
      else
        s * n
      end
    } unless block
    return nil if n && n <= 0
    # First pass: call each directly (lazy, break-safe), collect cache
    cache = []
    each do |*x|
      v = __unpack_enum_args__(x)
      cache << v
      block.call(v)
    end
    return nil if cache.empty?
    # Subsequent passes: use cached elements
    if n.nil?
      return loop { cache.each { |v| block.call(v) } }
    else
      (n - 1).times { cache.each { |v| block.call(v) } }
    end
    nil
  end

  def slice_before(pat = :__none__, &block)
    if pat.equal?(:__none__)
      raise ArgumentError, "tried to create Proc object without a block" unless block
    else
      raise ArgumentError, "wrong number of arguments (given 2, expected 1)" if block
      block = proc { |x| pat === x }
    end
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = __unpack_enum_args__(x)
        if block.call(v)
          y << buf if buf && !buf.empty?
          buf = [v]
        else
          buf ||= []
          buf << v
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def slice_after(pat = :__none__, &block)
    if pat.equal?(:__none__)
      raise ArgumentError, "tried to create Proc object without a block" unless block
    else
      raise ArgumentError, "wrong number of arguments (given 2, expected 1)" if block
      block = proc { |x| pat === x }
    end
    Enumerator.new do |y|
      buf = []
      each do |*x|
        v = __unpack_enum_args__(x)
        buf << v
        if block.call(v)
          y << buf
          buf = []
        end
      end
      y << buf unless buf.empty?
    end
  end

  def to_set(klass = Set, *args, &block)
    Intrinsics.kernel_deprecation_warn(self, "Enumerable#to_set is deprecated and will be removed in Ruby 4.2.")
    klass.new(self, *args, &block)
  end
end

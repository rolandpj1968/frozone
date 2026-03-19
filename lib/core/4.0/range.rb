class Range
  include Enumerable

  def self.new(b, e, excl = false)
    r = allocate
    r.__send__(:initialize, b, e, excl)
    r
  end

  def self.allocate = Intrinsics.range_allocate(self)

  def initialize(b, e, excl = false)
    raise FrozenError, "can't modify frozen Range" if Intrinsics.range_initialized_q(self)
    unless b.nil? || e.nil?
      # Validate that b and e are comparable; propagate any exception from <=>
      cmp = b <=> e
      raise ArgumentError, "bad value for range" if cmp.nil?
    end
    Intrinsics.range_set(self, b, e, excl)
  end

  private :initialize

  def begin          = Intrinsics.range_begin(self)
  def end            = Intrinsics.range_end(self)
  def exclude_end?   = Intrinsics.range_exclude_end(self)

  def each(&block)
    return to_enum(:each) { size } unless block
    i = self.begin
    raise TypeError, "can't iterate from #{i.class}" if i.nil?
    e = self.end
    discrete = i.is_a?(Integer) || i.is_a?(String) || i.is_a?(Symbol)
    excl = exclude_end?
    unless discrete
      raise TypeError, "can't iterate from #{i.class}" unless i.respond_to?(:succ)
    end
    if discrete
      # Single-char String/Symbol: iterate by character code (MRI semantics).
      # succ-based iteration is wrong here — "Z".succ == "AA" which is still
      # < "z" lexicographically, causing an infinite loop.
      if !e.nil? && (i.is_a?(String) || i.is_a?(Symbol)) && i.to_s.length == 1 && e.to_s.length == 1
        sym  = i.is_a?(Symbol)
        s    = i.to_s
        enc  = s.encoding.name
        ic   = s.ord
        ec   = e.to_s.ord
        r    = excl ? (ic...ec) : (ic..ec)
        r.each { |c| block.call(sym ? c.chr(enc).to_sym : c.chr(enc)) }
      else
        # Integer and multi-char String/Symbol: succ-based; guard against length growth
        while e.nil? || (excl ? i < e : i <= e)
          break if !e.nil? && i.respond_to?(:length) && e.respond_to?(:length) && i.length > e.length
          block.call(i)
          i = i.succ
        end
      end
    elsif excl
      loop do
        break unless e.nil? || (i <=> e) < 0
        block.call(i)
        i = i.succ
      end
    else
      # Inclusive: yield then check equality to avoid calling succ on last element
      loop do
        break unless e.nil? || (cmp = i <=> e; cmp <= 0)
        block.call(i)
        break if !e.nil? && cmp == 0
        i = i.succ
      end
    end
    self
  end

  def to_a
    raise RangeError, "cannot convert endless range to an array" if self.end.nil?
    raise TypeError, "cannot convert beginless range to an array" if self.begin.nil?
    r = []
    each { |x| r << x }
    r
  end

  def cover?(val)
    if val.is_a?(Range)
      # Subrange check: both begin and end of val must be covered by self
      vb = val.begin; ve = val.end; vexcl = val.exclude_end?
      # If val is endless, self must also be endless
      if ve.nil?
        return false unless self.end.nil?
        return vb.nil? || __cover_value__?(vb)
      end
      # If val is beginless, self must also be beginless
      if vb.nil?
        return self.begin.nil? && __cover_value__?(ve)
      end
      # Check val's begin is covered
      return false unless __cover_value__?(vb)
      # Check val's end is covered
      e = self.end
      if vexcl && !e.nil?
        cmp = ve <=> e
        return false if cmp.nil?
        if exclude_end?
          # Both exclusive: val [vb,ve) ⊆ self [b,e) iff ve <= e
          return cmp <= 0
        else
          # Self inclusive, val exclusive: need effective last of val (ve-1 for integers) <= e
          if ve.is_a?(Integer) && e.is_a?(Integer)
            return cmp <= 1  # ve <= e + 1, i.e., ve - 1 <= e
          else
            return cmp <= 0  # continuous: need ve <= e
          end
        end
      else
        return __cover_value__?(ve)
      end
    else
      __cover_value__?(val)
    end
  end

  def include?(val)
    b = self.begin; e = self.end
    # For Integer/Float begin: use comparison (numeric ranges are continuous)
    if b.is_a?(Integer) || b.is_a?(Float)
      return cover?(val)
    end
    # For other types (String, custom): use succ-based iteration if succ available
    return cover?(val) unless b.respond_to?(:succ)
    # First check if val is in the comparison range (quick filter)
    return false unless cover?(val)
    # Iterate via succ; for String, stop if succ grows in length
    begin_len = b.is_a?(String) ? b.length : nil
    i = b
    while true
      cmp = i <=> val
      return true if cmp == 0
      return false if cmp > 0
      break if !e.nil? && (i <=> e) >= (exclude_end? ? 0 : 1)
      s = i.succ
      # For String ranges: stop iteration if string grew in length
      return false if begin_len && s.is_a?(String) && s.length > begin_len
      return false if s == i  # infinite succ loop guard
      i = s
    end
    false
  end

  alias member? include?
  alias === cover?

  def size
    b = self.begin; e = self.end
    # Matches each: if begin can't succ, raise TypeError
    raise TypeError, "can't iterate from #{b.class}" if b.nil? || !b.respond_to?(:succ)
    # Only Integer begins have a numeric size
    return nil unless b.is_a?(Integer)
    return Float::INFINITY if e.nil? || e == Float::INFINITY
    return nil unless e.is_a?(Integer)
    n = exclude_end? ? e - b : e - b + 1
    n < 0 ? 0 : n
  end

  alias length size

  def min(&block)
    b = self.begin; e = self.end
    raise RangeError, "cannot get the minimum of beginless range" if b.nil?
    if block
      raise RangeError, "cannot get the minimum of endless range with custom comparison method" if e.nil?
      to_a.min(&block)
    else
      return nil if !e.nil? && (b <=> e) > 0
      return nil if exclude_end? && !e.nil? && (b <=> e) == 0
      b
    end
  end

  def max(&block)
    b = self.begin; e = self.end
    raise RangeError, "cannot get the maximum of endless range" if e.nil?
    if block
      raise RangeError, "cannot get the maximum of beginless range with custom comparison method" if b.nil?
      to_a.max(&block)
    elsif exclude_end?
      # Check for empty range FIRST before any TypeError
      if !b.nil?
        cmp = b <=> e
        return nil if cmp.nil? || cmp >= 0
      end
      if e.is_a?(Integer)
        e - 1
      elsif e.is_a?(Float)
        raise TypeError, "cannot exclude non Integer end value"
      elsif !b.nil? && b.respond_to?(:succ)
        # Non-numeric exclusive range with succ: iterate to find last element
        last = nil
        each { |x| last = x }
        last
      else
        raise TypeError, "cannot exclude non Integer end value"
      end
    else
      return nil if !b.nil? && (b <=> e) > 0
      e
    end
  end

  def minmax(&block)
    if block
      b = self.begin; e = self.end
      raise RangeError, "cannot get the minimum of beginless range" if b.nil?
      raise RangeError, "cannot get the maximum of endless range" if e.nil?
      a = to_a
      [a.min(&block), a.max(&block)]
    else
      [min, max]
    end
  end

  def to_set(&block)
    raise RangeError, "cannot convert endless range to a set" if self.end.nil?
    raise TypeError, "can't iterate from NilClass" if self.begin.nil?
    s = Set.new
    each { |x| s.add(block ? block.call(x) : x) }
    s
  end

  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end
  def map;    r = []; each { |x| r << yield(x) };      r; end
  def select; r = []; each { |x| r << x if yield(x) }; r; end
  def any?  = (each { |x| return true  if yield(x) }; false)
  def all?  = (each { |x| return false unless yield(x) }; true)
  def none? = (each { |x| return false if yield(x) }; true)
  def to_s
    b = self.begin; e = self.end; sep = exclude_end? ? '...' : '..'
    if b.nil? && e.nil?; "nil#{sep}nil"
    elsif b.nil?; "#{sep}#{e}"
    elsif e.nil?; "#{b}#{sep}"
    else; "#{b}#{sep}#{e}"
    end
  end

  def inspect
    b = self.begin; e = self.end; sep = exclude_end? ? '...' : '..'
    if b.nil? && e.nil?; "nil#{sep}nil"
    elsif b.nil?; "#{sep}#{e.inspect}"
    elsif e.nil?; "#{b.inspect}#{sep}"
    else; "#{b.inspect}#{sep}#{e.inspect}"
    end
  end

  def ==(other)
    return false unless other.is_a?(Range)
    self.begin == other.begin && self.end == other.end && self.exclude_end? == other.exclude_end?
  end

  def eql?(other)
    return false unless other.is_a?(Range)
    self.begin.eql?(other.begin) && self.end.eql?(other.end) && self.exclude_end? == other.exclude_end?
  end

  def step(n = 1, &block)
    b = self.begin
    e = self.end
    excl = exclude_end?

    raise ArgumentError, "cannot step endless beginless range" if b.nil? && e.nil?

    b_numeric = b.is_a?(Integer) || b.is_a?(Float)
    e_numeric_val = e.is_a?(Integer) || e.is_a?(Float)
    e_numeric = e.nil? || e_numeric_val
    numeric = b_numeric && e_numeric
    # ArithmeticSequence for numeric begin, OR beginless with numeric end
    arithmetic = numeric || (b.nil? && e_numeric_val)

    unless block
      raise ArgumentError, "step can't be 0" if numeric && (n == 0 || n == 0.0)
      rng = self
      if arithmetic
        return Enumerator::ArithmeticSequence._from_method(self, :step, [n], proc { rng.send(:__step_size__, n) })
      end
      return to_enum(:step, n) { __step_size__(n) }
    end

    # With block: coerce or validate step for numeric ranges
    if numeric
      unless n.is_a?(Integer) || n.is_a?(Float)
        if n.respond_to?(:coerce)
          coerced = n.coerce(b.to_f)
          n = coerced[1]
        else
          raise TypeError, "no implicit conversion of #{n.class} into Float"
        end
      end
      raise ArgumentError, "step can't be 0" if n == 0 || n == 0.0
    end

    if numeric
      use_float = n.is_a?(Float) || b.is_a?(Float) || (!e.nil? && e_numeric_val && e.is_a?(Float))
      if use_float
        __step_float__(b.to_f, e.nil? ? nil : e.to_f, n.to_f, excl, &block)
      else
        __step_integer__(b, e, n, excl, &block)
      end
    elsif n.is_a?(Float)
      raise TypeError, "no implicit conversion of Float into String" if b.is_a?(String)
      raise TypeError, "no implicit conversion of Float into #{b.class}"
    elsif n.is_a?(Integer)
      __step_succ__(b, e, n, excl, &block)
    else
      __step_plus__(b, e, n, excl, &block)
    end
    self
  end

  def reduce(init = nil, &block)
    if init.nil?
      acc = nil
      first = true
      each { |x| first ? (acc = x; first = false) : (acc = block.call(acc, x)) }
    else
      acc = init
      each { |x| acc = block.call(acc, x) }
    end
    acc
  end

  alias inject reduce

  def find(&block); each { |x| return x if yield(x) }; nil; end
  alias detect find
  def sum(init = 0); inject(init) { |a, x| a + x }; end
  def flat_map(&block); map(&block).flatten(1); end
  alias collect_concat flat_map

  def each_slice(n)
    return to_enum(:each_slice, n) unless block_given?
    slice = []
    each do |x|
      slice << x
      if slice.length == n
        yield slice
        slice = []
      end
    end
    yield slice unless slice.empty?
    self
  end

  def each_cons(n)
    return to_enum(:each_cons, n) unless block_given?
    buf = []
    each do |x|
      buf << x
      if buf.length == n
        yield buf.dup
        buf.shift
      end
    end
    self
  end

  def zip(*others)
    result = []
    to_a.each_with_index { |x, i| result << ([x] + others.map { |o| o.to_a[i] }) }
    result
  end

  def reverse_each(&block)
    return to_enum(:reverse_each) { __reverse_each_size__ } unless block
    b    = self.begin
    e    = self.end
    excl = exclude_end?
    raise TypeError, "can't iterate from NilClass" if e.nil?
    if b.nil?
      # Beginless range: only Integer end supported (otherwise always NilClass error)
      raise TypeError, "can't iterate from NilClass" unless e.is_a?(Integer)
      i = excl ? e - 1 : e
      loop { block.call(i); i -= 1 }
    elsif b.is_a?(Integer)
      raise TypeError, "can't iterate from #{e.class}" unless e.is_a?(Integer)
      i = excl ? e - 1 : e
      while i >= b
        block.call(i)
        i -= 1
      end
    else
      to_a.reverse_each(&block)
    end
    self
  end

  def sort; to_a.sort; end
  def sort_by(&block); to_a.sort_by(&block); end
  def min_by(&block); to_a.min_by(&block); end
  def max_by(&block); to_a.max_by(&block); end
  def count(&block)
    return Float::INFINITY if !block && (self.begin.nil? || self.end.nil?)
    block ? to_a.count(&block) : (size || to_a.size)
  end
  def take(n); to_a.take(n); end
  def drop(n); to_a.drop(n); end
  def first(*args)
    if args.empty?
      raise RangeError, "cannot get the first element of beginless range" if self.begin.nil?
      return self.begin
    end
    n = args[0]
    raise RangeError, "cannot get the first element of beginless range" if self.begin.nil?
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    raise ArgumentError, "negative array size (or exceeds maximum)" if n < 0
    to_a.first(n)
  end

  def last(*args)
    if args.empty?
      raise RangeError, "cannot get the last element of endless range" if self.end.nil?
      return self.end
    end
    n = args[0]
    raise RangeError, "cannot get the last element of endless range" if self.end.nil?
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    raise ArgumentError, "negative array size (or exceeds maximum)" if n < 0
    to_a.last(n)
  end
  def entries; to_a; end
  def hash; [self.begin, self.end, self.exclude_end?].hash; end

  def %(n, &block)
    return step(n, &block) if block
    # No block: create ArithmeticSequence with :% method name (affects inspect)
    b = self.begin; e = self.end
    b_numeric = b.is_a?(Integer) || b.is_a?(Float)
    e_numeric = e.nil? || e.is_a?(Integer) || e.is_a?(Float)
    numeric = b_numeric && e_numeric
    arithmetic = numeric || (b.nil? && (e.is_a?(Integer) || e.is_a?(Float)))
    raise ArgumentError, "step can't be 0" if numeric && (n == 0 || n == 0.0)
    rng = self
    if arithmetic
      return Enumerator::ArithmeticSequence._from_method(self, :%, [n], proc { rng.send(:__step_size__, n) })
    end
    to_enum(:%, n) { __step_size__(n) }
  end

  def overlap?(other)
    raise TypeError, "wrong argument type #{other.class} (expected Range)" unless other.is_a?(Range)
    a_begin = self.begin; a_end = self.end; a_excl = self.exclude_end?
    b_begin = other.begin; b_end = other.end; b_excl = other.exclude_end?

    # Empty ranges don't overlap
    return false if !a_begin.nil? && !a_end.nil? && (a_excl ? a_begin >= a_end : a_begin > a_end)
    return false if !b_begin.nil? && !b_end.nil? && (b_excl ? b_begin >= b_end : b_begin > b_end)

    # Check a_end vs b_begin
    if !a_end.nil? && !b_begin.nil?
      cmp = a_end <=> b_begin
      return false if cmp.nil?
      return false if a_excl ? cmp <= 0 : cmp < 0
    end

    # Check b_end vs a_begin
    if !b_end.nil? && !a_begin.nil?
      cmp = b_end <=> a_begin
      return false if cmp.nil?
      return false if b_excl ? cmp <= 0 : cmp < 0
    end

    true
  end

  def bsearch(&block)
    b = self.begin; e = self.end
    b_ok = b.nil? || b.is_a?(Integer) || b.is_a?(Float)
    e_ok = e.nil? || e.is_a?(Integer) || e.is_a?(Float)
    unless b_ok && e_ok
      raise TypeError, "can't do binary search for #{b_ok ? e.class : b.class}"
    end
    return to_enum(:bsearch) { __bsearch_size__ } unless block
    if (b.nil? || b.is_a?(Integer)) && (e.nil? || e.is_a?(Integer))
      __bsearch_integer__(b, e, exclude_end?, &block)
    else
      bf = b.nil? ? -Float::INFINITY : b.to_f
      ef = e.nil? ?  Float::INFINITY : e.to_f
      __bsearch_float__(bf, ef, exclude_end?, &block)
    end
  end

  private

  def __cover_value__?(val)
    b = self.begin; e = self.end
    return false if !b.nil? && ((cmp = b <=> val).nil? || cmp > 0)
    return false if !e.nil? && ((cmp2 = val <=> e).nil? || (exclude_end? ? cmp2 >= 0 : cmp2 > 0))
    true
  end

  def __step_size__(n)
    b = self.begin; e = self.end; excl = exclude_end?
    return nil unless b.is_a?(Integer) || b.is_a?(Float)
    return nil unless n.is_a?(Numeric)
    return Float::INFINITY if e.nil?
    return nil unless e.is_a?(Integer) || e.is_a?(Float)
    return 0 if n == 0

    n_f = n.to_f
    if n_f > 0
      diff = e.to_f - b.to_f
      return 0 if diff < 0
      if n.is_a?(Integer) && b.is_a?(Integer) && e.is_a?(Integer)
        diff_i = e - b
        excl ? (diff_i <= 0 ? 0 : (diff_i - 1) / n + 1) : diff_i / n + 1
      else
        count = excl ? (diff / n_f).ceil : (diff / n_f).floor + 1
        # For exclusive: check if one more element fits (float precision)
        if excl && count > 0
          last = n_f * (count - 1) + b.to_f
          next_el = n_f * count + b.to_f
          count += 1 if last < e.to_f && next_el < e.to_f
        end
        # For inclusive: trust floor+1 (boundary snap handles slight overshoot in iteration)
        [count, 0].max
      end
    else
      diff = b.to_f - e.to_f
      return 0 if diff < 0
      n_abs = (-n_f)
      if n.is_a?(Integer) && b.is_a?(Integer) && e.is_a?(Integer)
        diff_i = b - e
        excl ? (diff_i <= 0 ? 0 : (diff_i - 1) / (-n) + 1) : diff_i / (-n) + 1
      else
        count = excl ? (diff / n_abs).ceil : (diff / n_abs).floor + 1
        [count, 0].max
      end
    end
  end

  def __reverse_each_size__
    b = self.begin; e = self.end
    if b.nil?
      # Beginless: only Integer end is iterable
      return Float::INFINITY if e.is_a?(Integer)
      raise TypeError, "can't iterate from #{e.nil? ? 'NilClass' : e.class}"
    end
    if b.is_a?(Float)
      raise TypeError, "can't iterate from #{e.nil? ? 'NilClass' : e.class}"
    end
    return nil unless b.is_a?(Integer)
    return Float::INFINITY if e.nil?
    if e.is_a?(Integer)
      n = exclude_end? ? e - b : e - b + 1
    elsif e.is_a?(Float)
      hi = exclude_end? ? e.ceil - 1 : e.floor
      n = hi - b + 1
    else
      raise TypeError, "can't iterate from #{e.class}"
    end
    n < 0 ? 0 : n
  end

  # Float step over a numeric range. b_f and e_f are already converted to Float.
  # e_f is nil for an endless range.
  def __step_float__(b_f, e_f, step_f, excl, &block)
    if e_f.nil? || (e_f.respond_to?(:infinite?) && e_f.infinite?) ||
       (b_f.respond_to?(:infinite?) && b_f.infinite?)
      __step_float_unbounded__(b_f, e_f, step_f, excl, &block)
    elsif step_f > 0
      __step_float_positive__(b_f, e_f, step_f, excl, &block)
    else
      __step_float_negative__(b_f, e_f, step_f, excl, &block)
    end
  end

  # Float step: endless or infinite-boundary — simple loop with no count pre-computation.
  def __step_float_unbounded__(b_f, e_f, step_f, excl, &block)
    k = 0
    loop do
      i = step_f * k + b_f
      if e_f.nil?
        yield i
      elsif step_f > 0
        break if excl ? i >= e_f : i > e_f
        yield i
      else
        break if excl ? i <= e_f : i < e_f
        yield i
      end
      k += 1
    end
  end

  # Float step: positive step, bounded range.
  def __step_float_positive__(b_f, e_f, step_f, excl, &block)
    if excl
      # Loop-based for exclusive: naturally handles float precision
      k = 0
      loop do
        i = step_f * k + b_f
        break if i >= e_f
        yield i
        k += 1
      end
    else
      # Count-based for inclusive with boundary snap
      n_long = ((e_f - b_f) / step_f).floor.to_i + 1
      n_long.times do |ki|
        i = step_f * ki + b_f
        if i > e_f
          yield e_f; break  # snap to end if slightly over (float precision)
        end
        yield i
      end
    end
  end

  # Float step: negative step, bounded range.
  def __step_float_negative__(b_f, e_f, step_f, excl, &block)
    if excl
      k = 0
      loop do
        i = step_f * k + b_f
        break if i <= e_f
        yield i
        k += 1
      end
    else
      n_long = ((b_f - e_f) / (-step_f)).floor.to_i + 1
      n_long.times do |ki|
        i = step_f * ki + b_f
        if i < e_f
          yield e_f; break
        end
        yield i
      end
    end
  end

  # Integer step over a numeric (integer-only) range.
  def __step_integer__(b, e, n, excl, &block)
    i = b
    loop do
      if e.nil?
        yield i
      elsif n > 0
        break if excl ? i >= e : i > e
        yield i
      else
        break if excl ? i <= e : i < e
        yield i
      end
      i += n
    end
  end

  # Non-numeric range with an integer step: advance via succ abs(n) times per step.
  def __step_succ__(b, e, n, excl, &block)
    abs_n = n.abs
    i = b
    loop do
      if e.nil?
        yield i
        abs_n.times { i = i.succ }
      else
        cmp = i <=> e
        break if cmp.nil?
        break if excl ? cmp >= 0 : cmp > 0
        yield i
        break if cmp == 0
        abs_n.times { i = i.succ }
      end
    end
  end

  # Non-numeric range with a non-integer step: advance via + operator.
  def __step_plus__(b, e, n, excl, &block)
    if e.nil?
      i = b
      loop { yield i; i = i + n }
    else
      dir = b <=> e
      first_next = b + n
      step_dir = b <=> first_next
      # Check direction alignment (done before loop, but loop also calls i<=>e once)
      aligned = dir.nil? || dir == 0 || step_dir.nil? || (dir < 0) == (step_dir < 0)
      i = b; first_iter = true
      loop do
        cmp = i <=> e
        break if cmp.nil?
        if dir.nil? || dir <= 0
          break if excl ? cmp >= 0 : cmp > 0
        else
          break if excl ? cmp <= 0 : cmp < 0
        end
        break unless aligned  # no iteration if step direction doesn't match range
        yield i
        break if cmp == 0
        i = first_iter ? (first_iter = false; first_next) : i + n
      end
    end
  end

  def __bsearch_size__ = nil

  def __bsearch_validate__(r)
    return if r == true || r == false || r.nil? || r.is_a?(Numeric)
    raise TypeError, "wrong argument type #{r.class} (must be numeric, true, false or nil)"
  end

  # Integer bsearch
  def __bsearch_integer__(lo, hi, excl, &block)
    lo_val = lo.nil? ? (-(2**62)) : lo
    hi_val = hi.nil? ? (2**62) : (excl ? hi - 1 : hi)
    return nil if lo_val > hi_val
    r0 = block.call(lo_val)
    __bsearch_validate__(r0)
    r0.is_a?(Numeric) ? __bsearch_int_any__(lo_val, hi_val, r0, &block)
                      : __bsearch_int_min__(lo_val, hi_val, r0, &block)
  end

  # Integer find-minimum (true/false mode)
  # Convention: find leftmost element where block returns truthy
  def __bsearch_int_min__(lo, hi, r0, &block)
    result = r0 ? lo : nil
    left = r0 ? lo : lo + 1
    right = hi
    while left <= right
      mid = left + (right - left) / 2
      r = block.call(mid)
      raise TypeError, "wrong argument type #{r.class} (must be true, false or nil)" if r.is_a?(Numeric)
      __bsearch_validate__(r)
      if r
        result = mid
        right = mid - 1
      else
        left = mid + 1
      end
    end
    result
  end

  # Integer find-any (numeric mode)
  # Convention: block returns positive if element is too small (go right),
  #             negative if too large (go left), zero if found
  def __bsearch_int_any__(lo, hi, r0, &block)
    n0 = r0.is_a?(Numeric) ? r0 : (r0 ? 1 : -1)
    return lo if n0 == 0
    return nil if n0 < 0  # lo is already too large, answer is left of range
    left = lo + 1; right = hi  # n0 > 0: lo is too small, search right
    while left <= right
      mid = left + (right - left) / 2
      r = block.call(mid)
      __bsearch_validate__(r)
      n = r.is_a?(Numeric) ? r : (r ? 1 : -1)
      if n == 0
        return mid
      elsif n > 0
        left = mid + 1   # too small, go right
      else
        right = mid - 1  # too large, go left
      end
    end
    nil
  end

  # Float bsearch: convert floats to sortable uint64 for exact integer binary search
  FLOAT_SIGN_BIT = 1 << 63
  FLOAT_UINT64_MASK = (1 << 64) - 1

  def __float_to_ord__(f)
    bits = [f].pack('G').unpack1('Q>')
    (bits & FLOAT_SIGN_BIT) != 0 ? (~bits & FLOAT_UINT64_MASK) : (bits | FLOAT_SIGN_BIT)
  end

  def __ord_to_float__(ord)
    bits = (ord & FLOAT_SIGN_BIT) != 0 ? (ord ^ FLOAT_SIGN_BIT) : (~ord & FLOAT_UINT64_MASK)
    [bits].pack('Q>').unpack1('G')
  end

  def __bsearch_float__(lo, hi, excl, &block)
    lo_ord = __float_to_ord__(lo)
    hi_ord = __float_to_ord__(hi)
    hi_ord -= 1 if excl
    return nil if lo_ord > hi_ord

    # Probe at lo to detect mode
    lo_f = __ord_to_float__(lo_ord)
    r0 = block.call(lo_f)
    __bsearch_validate__(r0)

    if r0.is_a?(Numeric)
      # Find-any mode: block returns positive=too small, negative=too large, 0=found
      n0 = r0.to_f
      return lo_f if n0 == 0.0
      return nil if n0 < 0.0  # lo is already too large
      # n0 > 0: lo is too small, search [lo_ord+1, hi_ord]
      left = lo_ord + 1; right = hi_ord
      while left <= right
        mid_ord = left + (right - left) / 2
        mid = __ord_to_float__(mid_ord)
        r = block.call(mid)
        __bsearch_validate__(r)
        n = r.is_a?(Numeric) ? r.to_f : (r ? 1.0 : -1.0)
        return mid if n == 0.0
        n > 0.0 ? (left = mid_ord + 1) : (right = mid_ord - 1)
      end
      nil
    else
      # Find-min mode: find leftmost element where block returns truthy
      result = r0 ? lo_f : nil
      left = r0 ? lo_ord : lo_ord + 1
      right = hi_ord
      while left <= right
        mid_ord = left + (right - left) / 2
        mid = __ord_to_float__(mid_ord)
        r = block.call(mid)
        raise TypeError, "wrong argument type #{r.class} (must be true, false or nil)" if r.is_a?(Numeric)
        __bsearch_validate__(r)
        if r
          result = mid
          right = mid_ord - 1
        else
          left = mid_ord + 1
        end
      end
      result
    end
  end

  public

  # SpecVersion (mspec) may call split on a Range when given a range version like ""..."3.4".
  # Fall back to splitting the end value's string representation.
  def split(sep = nil, limit = nil)
    v = self.end
    v = v.nil? ? '' : v.to_s
    limit.nil? ? v.split(sep) : v.split(sep, limit)
  end
end

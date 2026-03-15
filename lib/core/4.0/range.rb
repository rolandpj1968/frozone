class Range
  def self.new(b, e, excl = false)
    Intrinsics.range_new(b, e, excl)
  end

  def self.allocate = Intrinsics.range_allocate(self)

  def initialize(b, e, excl = false)
    raise FrozenError, "can't modify frozen Range" if Intrinsics.range_initialized_q(self)
    raise ArgumentError, "bad value for range" unless b.respond_to?(:<=>) || e.respond_to?(:<=>) || b.nil? || e.nil?
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
    # For non-discrete types: validate comparability (calls <=>) before checking succ (matches MRI)
    unless discrete
      e.nil? || (i <=> e)
      raise TypeError, "can't iterate from #{i.class}" unless i.respond_to?(:succ)
    end
    if discrete
      # Fast path for known discrete types: succ on last element is safe
      while e.nil? || (excl ? i < e : i <= e)
        block.call(i)
        i = i.succ
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
    r = []
    each { |x| r << x }
    r
  end

  def _cover_value?(val)
    b = self.begin; e = self.end
    return false if !b.nil? && ((cmp = b <=> val).nil? || cmp > 0)
    return false if !e.nil? && ((cmp2 = val <=> e).nil? || (exclude_end? ? cmp2 >= 0 : cmp2 > 0))
    true
  end

  def cover?(val)
    if val.is_a?(Range)
      # Subrange check: both begin and end of val must be covered by self
      vb = val.begin; ve = val.end; vexcl = val.exclude_end?
      # If val is endless, self must also be endless
      if ve.nil?
        return false unless self.end.nil?
        return vb.nil? || _cover_value?(vb)
      end
      # If val is beginless, self must also be beginless
      if vb.nil?
        return self.begin.nil? && _cover_value?(ve)
      end
      # Check val's begin is covered
      return false unless _cover_value?(vb)
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
        return _cover_value?(ve)
      end
    else
      _cover_value?(val)
    end
  end

  def include?(val)
    b = self.begin; e = self.end
    # For Integer/Float begin: use comparison (numeric ranges are continuous)
    if b.is_a?(Integer) || b.is_a?(Float)
      return cover?(val)
    end
    # For other types (String, custom): use succ-based iteration
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
      raise TypeError, "cannot exclude non Integer end value" unless e.is_a?(Integer)
      return nil if !b.nil? && (b <=> e) >= 0
      e - 1
    else
      return nil if !b.nil? && (b <=> e) > 0
      e
    end
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

  alias eql? ==

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
      # Non-numeric: check direction once (mspec mock expects exactly 1 call to <=>)
      b <=> e if !b.nil? && !e.nil? && !numeric
      rng = self
      if arithmetic
        return Enumerator::ArithmeticSequence._from_method(self, :step, [n], proc { rng.send(:_step_size, n) })
      end
      return to_enum(:step, n) { _step_size(n) }
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
        b_f = b.to_f; step_f = n.to_f; e_f = e.nil? ? nil : e.to_f
        if e_f.nil? || (e_f.respond_to?(:infinite?) && e_f.infinite?) ||
           (b_f.respond_to?(:infinite?) && b_f.infinite?)
          # Endless or infinite boundary: simple loop
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
        elsif step_f > 0
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
        else
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
      else
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
    elsif n.is_a?(Float)
      raise TypeError, "no implicit conversion of Float into String" if b.is_a?(String)
      raise TypeError, "no implicit conversion of Float into #{b.class}"
    elsif n.is_a?(Integer)
      # Non-numeric range with integer step: use succ n times
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
    else
      # Ruby 3.4: non-numeric range with non-integer step — use + on each element
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
    self
  end

  private def _step_size(n)
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
    return to_enum(:reverse_each) unless block
    to_a.reverse_each(&block)
    self
  end

  def sort; to_a.sort; end
  def sort_by(&block); to_a.sort_by(&block); end
  def min_by(&block); to_a.min_by(&block); end
  def max_by(&block); to_a.max_by(&block); end
  def count(&block); block ? to_a.count(&block) : size; end
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

  # SpecVersion (mspec) may call split on a Range when given a range version like ""..."3.4".
  # Fall back to splitting the end value's string representation.
  def split(sep = nil, limit = nil)
    v = self.end
    v = v.nil? ? '' : v.to_s
    limit.nil? ? v.split(sep) : v.split(sep, limit)
  end
end

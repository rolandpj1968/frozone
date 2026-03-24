class Numeric
  include Comparable

  def integer? = false
  def real? = true
  def zero? = self == 0
  def positive? = self > 0
  def negative? = self < 0
  def finite? = true
  def infinite? = nil
  def abs2 = self * self
  def +@() = self
  def -@() = 0 - self
  def real = self
  def conj = self
  alias conjugate conj
  def imag = 0
  alias imaginary imag
  def polar = [abs, arg]
  def rect = [self, 0]
  alias rectangular rect
  def to_int = to_i
  def to_c = Complex(self, 0)
  def i  = Complex(0, self)
  def dup = self
  def nonzero? = zero? ? nil : self
  def abs = self < 0 ? -self : self
  alias magnitude abs
  def angle = self < 0 ? Math::PI : 0.0
  alias arg   angle
  alias phase angle
  def eql?(other) = other.instance_of?(self.class) && self == other
  def <=>(other) = equal?(other) ? 0 : nil
  def ceil(ndigits = 0) = to_f.ceil(ndigits)
  def floor(ndigits = 0) = to_f.floor(ndigits)
  def truncate(ndigits = 0) = to_f.truncate(ndigits)
  def divmod(other) = [div(other), modulo(other)]
  def modulo(other) = self - other * div(other)
  alias % modulo
  def fdiv(other) = to_f / other.to_f
  def numerator = to_r.numerator
  def denominator = to_r.denominator
  def singleton_method_added(id) = raise(TypeError, "can't define singleton")

  def round(ndigits = 0, half: :up)
    to_f.round(ndigits, half: half)
  end

  def clone(freeze: nil)
    raise ArgumentError, "can't unfreeze #{self.class}" if freeze == false
    self
  end

  def div(other)
    raise ZeroDivisionError, "divided by 0" if other.respond_to?(:zero?) && other.zero?
    (self / other).floor
  end

  def remainder(other)
    r = self % other
    r != 0 && (self < 0) != (other < 0) ? r - other : r
  end

  def quo(other)
    raise TypeError, "#{other.class} can't be coerced into Rational" unless other.is_a?(Numeric)
    r = to_r
    raise TypeError, "#{r.class} is not a Rational" unless r.is_a?(Rational)
    r / other
  end

  def coerce(other)
    if other.instance_of?(self.class)
      [other, self]
    elsif other.is_a?(Numeric)
      [other.to_f, to_f]
    elsif other.is_a?(String)
      begin
        [Float(other), to_f]
      rescue ArgumentError
        raise ArgumentError, "invalid value for Float(): #{other.inspect}"
      end
    elsif !other.nil? && other != true && other != false && !other.is_a?(Symbol) && other.respond_to?(:to_f)
      result = other.to_f
      raise TypeError, "#{other.class} can't be coerced into #{self.class}" unless result.is_a?(Float)
      [result, to_f]
    else
      raise TypeError, "#{other.class} can't be coerced into #{self.class}"
    end
  end

  # Numeric#step
  def step(to_arg = :__unset__, by_arg = :__unset__, to: :__unset__, by: :__unset__, &block)
    # Track how args were supplied (for ArithmeticSequence#inspect reconstruction)
    pos_to_given = !to_arg.equal?(:__unset__)
    pos_by_given = !by_arg.equal?(:__unset__)
    kw_to_given  = !to.equal?(:__unset__)
    kw_by_given  = !by.equal?(:__unset__)

    # --- Argument parsing ---
    # Positional `to_arg` and `by_arg` conflict with keyword `to:` and `by:`.
    unless pos_to_given
      nil # no-op
    else
      raise ArgumentError, "to is given twice" unless to.equal?(:__unset__)
      to = to_arg
    end
    unless pos_by_given
      nil # no-op
    else
      raise ArgumentError, "step is given twice" unless by.equal?(:__unset__)
      by = by_arg
    end

    limit  = to.equal?(:__unset__)  ? nil : to
    step_v = by.equal?(:__unset__)  ? 1   : by

    # String step raises ArgumentError
    if step_v.is_a?(String)
      raise ArgumentError, "invalid value for Float(): #{step_v.inspect}" if block
      # No block: return plain Enumerator that raises on size
      str_step = step_v
      origin = self
      lim = limit
      return to_enum(:step, *[lim, step_v].compact) { raise ArgumentError, "invalid value for Float(): #{str_step.inspect}" }
    end

    # Determine numeric types
    int_step  = self.is_a?(Integer) && (limit.nil? || limit.is_a?(Integer)) && step_v.is_a?(Integer)
    float_any = self.is_a?(Float) || (!limit.nil? && limit.is_a?(Float)) || step_v.is_a?(Float)

    # Validate step != 0 for numeric steps
    if (int_step || float_any) && step_v == 0
      raise ArgumentError, "step can't be 0"
    end

    # Size computation lambda
    size_fn = proc do
      __step_size__(limit, step_v, int_step, float_any)
    end

    # No block: return ArithmeticSequence or Enumerator
    unless block
      if int_step || float_any
        # Preserve original call style for inspect reconstruction
        if pos_to_given || pos_by_given
          # Positional call: store as positional args (omit default step=1 if not given)
          as_args = pos_to_given ? [limit] : []
          as_args << step_v if pos_by_given
          # Mixed: keyword by: was given alongside positional to — store in kwargs
          as_kwargs = {}
          as_kwargs[:by] = step_v if kw_by_given && !pos_by_given
          as_kwargs[:to] = limit  if kw_to_given && !pos_to_given
        elsif kw_to_given || kw_by_given
          # Keyword call: store as keyword args
          as_args = []
          as_kwargs = {}
          as_kwargs[:by] = step_v if kw_by_given
          as_kwargs[:to] = limit if kw_to_given
        else
          # No args at all (infinite: 1.step)
          as_args = []
          as_kwargs = {}
        end
        return Enumerator::ArithmeticSequence._from_method(self, :step, as_args, size_fn, as_kwargs)
      end
      pos_args = [limit, step_v].compact
      return to_enum(:step, *pos_args) { size_fn.call }
    end

    __step_each__(limit, step_v, int_step, float_any, &block)
    self
  end

  private

  def __step_size__(limit, step_v, int_step, float_any)
    return Float::INFINITY if limit.nil?

    sv = float_any ? step_v.to_f : step_v
    lim = float_any ? limit.to_f : limit
    origin = float_any ? to_f : self

    # Infinity step: yield at most once
    if sv.is_a?(Float) && sv.infinite?
      if sv > 0
        return (lim.is_a?(Float) && lim.infinite? && lim < 0) ? 0 : (origin > lim ? 0 : 1)
      else
        return (lim.is_a?(Float) && lim.infinite? && lim > 0) ? 0 : (origin < lim ? 0 : 1)
      end
    end

    if sv > 0
      return 0 if origin > lim
    elsif sv < 0
      return 0 if origin < lim
    end

    diff = (lim - origin).to_f
    # NaN: inf - inf or -inf - (-inf) = indeterminate → 0 steps
    return 0 if diff.respond_to?(:nan?) && diff.nan?
    # Infinite diff with finite step: going the right direction → infinite sequence
    if diff.respond_to?(:infinite?) && diff.infinite?
      return Float::INFINITY if (sv > 0 && diff > 0) || (sv < 0 && diff < 0)
      return 0
    end

    if int_step
      ((lim - origin) / sv).floor + 1
    else
      (diff / sv.to_f).floor + 1
    end
  end

  def __step_each__(limit, step_v, int_step, float_any, &block)
    if int_step && !float_any
      # Pure integer stepping: exact arithmetic
      i = self
      if step_v > 0
        while limit.nil? || i <= limit
          block.call(i)
          i += step_v
        end
      elsif step_v < 0
        while limit.nil? || i >= limit
          block.call(i)
          i += step_v
        end
      end
    else
      # Float stepping: count-based to avoid accumulation errors
      origin_f = to_f
      sv_f = step_v.to_f

      if sv_f.infinite?
        # Infinity step: yield at most once
        if sv_f > 0
          return if !limit.nil? && limit.to_f < origin_f
          block.call(float_any ? origin_f : self)
        else
          return if !limit.nil? && limit.to_f > origin_f
          block.call(float_any ? origin_f : self)
        end
        return
      end

      if limit.nil?
        # Infinite sequence
        i = 0
        loop do
          v = origin_f + i * sv_f
          block.call(v)
          i += 1
        end
      else
        lim_f = limit.to_f
        # Count-based: compute number of steps to avoid float accumulation errors.
        # MRI uses: n = floor((lim - start) / step), yields n+1 values (i=0..n),
        # and clamps the last value to lim if rounding causes it to exceed lim.
        n = __step_size__(limit, step_v, false, true)
        n = 0 if n < 0
        if n.is_a?(Float) && n.infinite?
          # Infinite n: iterate until manually stopped (shouldn't happen with finite step+limit)
          i = 0
          loop do
            v = origin_f + i * sv_f
            block.call(v)
            i += 1
          end
          return
        end
        n.times do |i|
          v = origin_f + i * sv_f
          # On the last step, MRI clamps to the limit if rounding overshoots.
          if i == n - 1
            v = lim_f if sv_f > 0 && v > lim_f
            v = lim_f if sv_f < 0 && v < lim_f
          end
          block.call(v)
        end
      end
    end
  end
end

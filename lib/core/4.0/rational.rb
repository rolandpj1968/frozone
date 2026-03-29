class Rational < Numeric
  def numerator = @numerator
  def denominator = @denominator
  def to_i = @numerator < 0 ? -(-@numerator / @denominator) : @numerator / @denominator
  def to_r = self
  def to_c = Complex(self, 0)
  def dup = self
  def clone(freeze: nil) = self
  def divmod(other) = [div(other), self - other * div(other)]
  def abs = @numerator < 0 ? Rational(-@numerator, @denominator) : self
  def negative? = @numerator < 0
  def positive? = @numerator > 0
  def zero? = @numerator == 0
  def nonzero? = @numerator == 0 ? nil : self
  def hash = [@numerator, @denominator].hash
  def eql?(other) = other.is_a?(Rational) && @numerator == other.numerator && @denominator == other.denominator
  def quo(other) = self / other
  def self.new(*) = raise NoMethodError, "undefined method 'new' for class #{self}"
  def inspect = "(#{@numerator}/#{@denominator})"
  def to_s = "#{@numerator}/#{@denominator}"

  def +(other)
    case other
    when Rational then Rational(@numerator * other.denominator + other.numerator * @denominator, @denominator * other.denominator)
    when Integer  then Rational(@numerator + other * @denominator, @denominator)
    when Float    then to_f + other
    else __coerce_op__(other, :+)
    end
  end

  def -(other)
    case other
    when Rational then Rational(@numerator * other.denominator - other.numerator * @denominator, @denominator * other.denominator)
    when Integer  then Rational(@numerator - other * @denominator, @denominator)
    when Float    then to_f - other
    else __coerce_op__(other, :-)
    end
  end

  def *(other)
    case other
    when Rational then Rational(@numerator * other.numerator, @denominator * other.denominator)
    when Integer  then Rational(@numerator * other, @denominator)
    when Float    then to_f * other
    else __coerce_op__(other, :*)
    end
  end

  def /(other)
    case other
    when Rational then Rational(@numerator * other.denominator, @denominator * other.numerator)
    when Integer  then Rational(@numerator, @denominator * other)
    when Float    then to_f / other
    else __coerce_op__(other, :/)
    end
  end

  def **(other)
    case other
    when Integer
      if other >= 0
        Rational(@numerator ** other, @denominator ** other)
      else
        raise ZeroDivisionError, "divided by 0" if @numerator == 0
        Rational(@denominator ** (-other), @numerator ** (-other))
      end
    when Float    then to_f ** other
    when Rational
      raise ZeroDivisionError, "divided by 0" if @numerator == 0 && other.negative?
      if other.denominator == 1
        self ** other.numerator
      else
        to_f ** other.to_f
      end
    else __coerce_op__(other, :**)
    end
  end

  def ==(other)
    case other
    when Rational then @numerator == other.numerator && @denominator == other.denominator
    when Integer  then @denominator == 1 && @numerator == other
    when Float    then to_f == other
    else
      begin; other == self; rescue; false; end
    end
  end

  def <=>(other)
    case other
    when Rational then (@numerator * other.denominator) <=> (other.numerator * @denominator)
    when Integer  then @numerator <=> (other * @denominator)
    when Float    then to_f <=> other
    else
      return nil unless other.respond_to?(:coerce)
      a, b = other.coerce(self)
      a <=> b
    end
  end

  def coerce(other)
    case other
    when Float   then [other, to_f]
    when Integer then [Rational(other), self]
    when Rational then [other, self]
    else raise TypeError, "can't coerce #{other.class} into Rational"
    end
  end

  def to_f
    n_bits = @numerator.abs.bit_length
    d_bits = @denominator.bit_length
    max_bits = n_bits > d_bits ? n_bits : d_bits
    if max_bits > 1022
      shift = max_bits - 1022
      (@numerator >> shift).to_f / (@denominator >> shift).to_f
    else
      @numerator.to_f / @denominator.to_f
    end
  end

  def floor(n = 0)
    n = __coerce_to_int__(n)
    if n == 0
      @numerator / @denominator
    elsif n > 0
      f = 10 ** n
      Rational(@numerator * f / @denominator, f)
    else
      f = 10 ** (-n)
      (@numerator / (@denominator * f)) * f
    end
  end

  def ceil(n = 0)
    n = __coerce_to_int__(n)
    if n == 0
      -(-@numerator / @denominator)
    elsif n > 0
      f = 10 ** n
      Rational(-(-@numerator * f / @denominator), f)
    else
      f = 10 ** (-n)
      (-(-@numerator / (@denominator * f))) * f
    end
  end

  def truncate(n = 0)
    n = __coerce_to_int__(n)
    @numerator < 0 ? ceil(n) : floor(n)
  end

  def round(n = 0, half: :up)
    n = __coerce_to_int__(n)
    # Scale numerator/denominator for the given precision
    num = n >= 0 ? @numerator * (10 ** n) : @numerator
    den = n >= 0 ? @denominator : @denominator * (10 ** (-n))

    # floor division and remainder
    q, r = num.divmod(den)
    r2 = r * 2

    rounded =
      if r2 < den
        q
      elsif r2 > den
        q + 1
      else
        case half
        when :up, nil then num >= 0 ? q + 1 : q
        when :down    then num >= 0 ? q : q + 1
        when :even    then q.even? ? q : q + 1
        else raise ArgumentError, "invalid rounding mode: #{half}"
        end
      end

    if n >= 0
      n == 0 ? rounded : Rational(rounded, 10 ** n)
    else
      rounded * (10 ** (-n))
    end
  end

  def div(other)
    raise ZeroDivisionError, "divided by 0" if other.respond_to?(:zero?) && other.zero?
    (self / other).floor
  end

  def %(other)
    raise ZeroDivisionError, "divided by 0" if other.respond_to?(:zero?) && other.zero?
    self - other * (self / other).floor
  end
  alias modulo %

  def remainder(other)
    r = self % other
    return r if r == 0
    if self < 0
      other > 0 ? r - other : r
    elsif self > 0
      other < 0 ? r - other : r
    else
      r
    end
  end

  def rationalize(eps = nil)
    return self if eps.nil?
    eps = eps.is_a?(Rational) ? eps.abs : Rational(eps.abs)
    lo = self - eps
    hi = self + eps
    __simplest_rational__(lo, hi)
  end

  private

  def marshal_dump = [@numerator, @denominator]

  def initialize(numerator, denominator = 1)
    raise ZeroDivisionError, "divided by 0" if denominator == 0
    g = numerator.gcd(denominator)
    @numerator = numerator / g
    @denominator = denominator / g
    if @denominator < 0
      @numerator = -@numerator
      @denominator = -@denominator
    end
    freeze
  end

  def __coerce_op__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)
  rescue NoMethodError
    raise TypeError, "#{other.class} can't be coerced into Rational"
  end

  def __simplest_rational__(lo, hi)
    return Rational(0, 1) if lo <= 0 && hi >= 0
    return -__simplest_rational__(-hi, -lo) if hi < 0
    lo_ceil = lo.ceil
    return Rational(lo_ceil, 1) if lo_ceil <= hi
    k = lo.floor
    lo2 = Rational(1, 1) / (hi - k)
    hi2 = Rational(1, 1) / (lo - k)
    y = __simplest_rational__(lo2, hi2)
    Rational(k * y.numerator + y.denominator, y.numerator)
  end

  def marshal_load(ary)
    g = ary[0].gcd(ary[1])
    @numerator = ary[0] / g
    @denominator = ary[1] / g
  end
end

module Kernel
  def Rational(numerator, *denom_args, exception: true)
    no_denom = denom_args.empty?
    denominator = no_denom ? 1 : denom_args[0]

    # Special case: Complex denominator with non-zero imaginary part
    # Result is n / d (complex division), not a pure Rational
    if denominator.is_a?(Complex) && denominator.imaginary != 0
      begin
        n = __rational_coerce__(numerator)
      rescue StandardError
        return nil unless exception
        raise
      end
      return n / denominator
    end

    begin
      n = __rational_coerce__(numerator)
      d = __rational_coerce__(denominator)
    rescue StandardError
      return nil unless exception
      raise
    end

    # Handle Float
    if n.is_a?(Float)
      n = n.to_r
    end
    if d.is_a?(Float)
      d = d.to_r
    end

    # Reduce: result = (n_num/n_den) / (d_num/d_den) = n_num*d_den / (n_den*d_num)
    n_num = n.is_a?(Rational) ? n.numerator : n
    n_den = n.is_a?(Rational) ? n.denominator : 1
    d_num = d.is_a?(Rational) ? d.numerator : d
    d_den = d.is_a?(Rational) ? d.denominator : 1

    final_num = n_num * d_den
    final_den = n_den * d_num

    result = Rational.allocate
    result.__send__(:initialize, final_num, final_den)
    result
  end

  def __rational_coerce__(val)
    # Use rescue NoMethodError to handle BasicObject subclasses that lack is_a?, respond_to?, etc.
    begin
      return val if val.is_a?(Integer) || val.is_a?(Rational)
      return val if val.is_a?(Float)
      raise TypeError, "can't convert nil into Rational" if val.nil?
      if val.is_a?(String)
        return Intrinsics.kernel_rational_from_string(self, val, true)
      end
      if val.respond_to?(:to_r)
        begin
          r = val.to_r
        rescue RangeError
          raise
        rescue
          raise TypeError, "can't convert #{val.class} into Rational"
        end
        return r if r.is_a?(Integer) || r.is_a?(Rational) || r.is_a?(Float)
        raise TypeError, "can't convert #{val.class} into Rational (#{val.class}#to_r gives #{r.class})"
      end
      if val.respond_to?(:to_int)
        begin
          return val.to_int
        rescue
          raise TypeError, "can't convert #{val.class} into Rational"
        end
      end
    rescue TypeError, RangeError
      raise
    rescue NoMethodError
      # BasicObject or similar: doesn't have is_a?/respond_to?/class — try to_r directly
      val_cls_name = Intrinsics.object_class(val).name
      begin
        r = val.to_r
        return r if r.is_a?(Rational)
        r_cls_name = begin r.class.name rescue Intrinsics.object_class(r).name end
        raise TypeError, "can't convert #{val_cls_name} to Rational (#{val_cls_name}#to_r gives #{r_cls_name})"
      rescue NoMethodError
        raise TypeError, "can't convert #{val_cls_name} into Rational"
      end
    end
    raise TypeError, "can't convert #{val.class} into Rational"
  end
  private :__rational_coerce__
end

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
    n = __validate_ndigits__(n) unless n.is_a?(Integer)
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
    n = __validate_ndigits__(n) unless n.is_a?(Integer)
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
    n = __validate_ndigits__(n) unless n.is_a?(Integer)
    @numerator < 0 ? ceil(n) : floor(n)
  end

  def round(n = 0, half: :up)
    n = __validate_ndigits__(n) unless n.is_a?(Integer)
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

  def __validate_ndigits__(n)
    raise TypeError, "not an integer" unless n.is_a?(Integer)
    n
  end

  def marshal_load(ary)
    g = ary[0].gcd(ary[1])
    @numerator = ary[0] / g
    @denominator = ary[1] / g
  end
end

class Complex
  def self._real_check(v)
    if v.is_a?(Complex)
      raise TypeError, "not a real" unless v.imaginary == 0
      return v.real
    end
    raise TypeError, "not a real" unless v.is_a?(Numeric)
    raise TypeError, "not a real" if v.respond_to?(:real?) && v.real? == false
    v
  end

  private_class_method :_real_check

  def self.polar(r, theta = 0)
    r     = _real_check(r)
    theta = _real_check(theta)
    Complex(r * Math.cos(theta.to_f), r * Math.sin(theta.to_f))
  end

  def self.rect(real, imag = 0)
    real = _real_check(real)
    imag = _real_check(imag)
    new(real, imag)
  end

  def self.rectangular(real, imag = 0)
    real = _real_check(real)
    imag = _real_check(imag)
    new(real, imag)
  end

  def initialize(real, imaginary = 0)
    @real = real
    @imaginary = imaginary
    freeze
  end

  I = Complex.new(0, 1)

  def real = @real
  def imaginary = @imaginary
  alias imag imaginary
  def real? = false
  def abs2 = @real * @real + @imaginary * @imaginary
  def abs = Math.sqrt(abs2.to_f)
  alias magnitude abs
  def rect = [@real, @imaginary]
  alias rectangular rect
  def conj = Complex(@real, -@imaginary)
  alias conjugate conj
  def to_c = self
  def dup = self
  def clone(freeze: nil) = self
  def integer? = false
  def zero? = @real == 0 && @imaginary == 0
  def nonzero? = zero? ? nil : self
  def real? = false
  def quo(other) = self / other
  def hash = [@real, @imaginary].hash
  def -@ = Complex(-@real, -@imaginary)
  def angle = Math.atan2(@imaginary.to_f, @real.to_f)
  alias arg   angle
  alias phase angle
  def polar = [abs, angle]

  def +(other)
    __complex_coerce_op__(other, :+) do |v|
      if v.is_a?(Complex)
        Complex(@real + v.real, @imaginary + v.imaginary)
      else
        Complex(@real + v, @imaginary)
      end
    end
  end

  def -(other)
    __complex_coerce_op__(other, :-) do |v|
      if v.is_a?(Complex)
        Complex(@real - v.real, @imaginary - v.imaginary)
      else
        Complex(@real - v, @imaginary)
      end
    end
  end

  def *(other)
    __complex_coerce_op__(other, :*) do |v|
      if v.is_a?(Complex)
        Complex(@real * v.real - @imaginary * v.imaginary,
                @real * v.imaginary + @imaginary * v.real)
      else
        Complex(@real * v, @imaginary * v)
      end
    end
  end

  def /(other)
    if other.is_a?(Complex)
      # Standard complex division: (a+bi)/(c+di) = ((ac+bd) + (bc-ad)i) / (c²+d²)
      denom = other.real * other.real + other.imaginary * other.imaginary
      Complex((@real * other.real + @imaginary * other.imaginary).quo(denom),
              (@imaginary * other.real - @real * other.imaginary).quo(denom))
    else
      real_q = other.respond_to?(:real?) ? other.real? : nil
      if real_q == false
        begin
          a, b = other.coerce(self)
          a.quo(b)
        rescue NoMethodError
          raise TypeError, "#{other.class} can't be coerced into Complex"
        end
      elsif other.is_a?(Numeric) || real_q
        Complex(@real.quo(other), @imaginary.quo(other))
      else
        begin
          a, b = other.coerce(self)
          a / b
        rescue NoMethodError
          raise TypeError, "#{other.class} can't be coerced into Complex"
        end
      end
    end
  end

  def **(other)
    if other.is_a?(Integer)
      return Complex(1, 0) if other == 0
      if other > 0
        result = Complex(1, 0)
        other.times { result = result * self }
        result
      else
        (self ** (-other)).quo(Complex(1, 0)).tap { |_|
          # invert
        }
        denom = abs2
        Complex(@real.to_f / denom, -@imaginary.to_f / denom) ** (-other)
      end
    elsif other.is_a?(Float) || other.is_a?(Rational)
      # Use polar form: (r*e^(i*theta))^n = r^n * e^(i*n*theta)
      r = abs
      theta = angle
      exp_other = other.is_a?(Float) ? other : other.to_f
      r_n = r ** exp_other
      theta_n = theta * exp_other
      Complex(r_n * Math.cos(theta_n), r_n * Math.sin(theta_n))
    elsif other.is_a?(Complex)
      # General: self^other = e^(other * log(self))
      r = abs
      theta = angle
      log_r = Math.log(r)
      # other * log(self) = (a+bi)(log_r + i*theta) = (a*log_r - b*theta) + (b*log_r + a*theta)i
      a = other.real.to_f; b = other.imaginary.to_f
      re = a * log_r - b * theta
      im = b * log_r + a * theta
      e_re = Math.exp(re)
      Complex(e_re * Math.cos(im), e_re * Math.sin(im))
    else
      begin
        a, b = other.coerce(self)
        a ** b
      rescue NoMethodError
        raise TypeError, "#{other.class} can't be coerced into Complex"
      end
    end
  end

  def ==(other)
    case other
    when Complex then @real == other.real && @imaginary == other.imaginary
    when Numeric then @imaginary == 0 && @real == other
    else
      other == self rescue false
    end
  end

  def <=>(other)
    # Returns nil if either has imaginary part, otherwise compares real parts
    if @imaginary == 0 && other.respond_to?(:imaginary) && other.imaginary == 0
      @real <=> other.real
    elsif @imaginary == 0 && other.is_a?(Numeric) && !other.is_a?(Complex)
      @real <=> other
    else
      nil
    end
  end

  def numerator
    cd = denominator
    Complex(@real.is_a?(Rational) ? @real.numerator * (cd / @real.denominator) : @real * cd,
            @imaginary.is_a?(Rational) ? @imaginary.numerator * (cd / @imaginary.denominator) : @imaginary * cd)
  end

  def denominator
    rd = @real.is_a?(Rational) ? @real.denominator : 1
    id = @imaginary.is_a?(Rational) ? @imaginary.denominator : 1
    rd.lcm(id)
  end

  def rationalize(eps = nil)
    raise RangeError, "can't convert #{inspect} into Rational" unless !@imaginary.is_a?(Float) && @imaginary == 0
    @real.rationalize(eps)
  end

  def to_f
    # Float 0.0 as imaginary is not accepted (only Integer 0 or Rational 0)
    unless !@imaginary.is_a?(Float) && @imaginary == 0
      raise RangeError, "can't convert #{inspect} into Float"
    end
    @real.to_f
  end

  def to_i
    unless !@imaginary.is_a?(Float) && @imaginary == 0
      raise RangeError, "can't convert #{inspect} into Integer"
    end
    @real.to_i
  end

  def to_r
    raise RangeError, "can't convert #{to_s} into Rational" unless @imaginary == 0
    @real.to_r
  end

  def finite?
    @real.respond_to?(:finite?) && @real.finite? &&
    @imaginary.respond_to?(:finite?) && @imaginary.finite?
  end

  def infinite?
    r_inf = @real.respond_to?(:infinite?) ? @real.infinite? : nil
    i_inf = @imaginary.respond_to?(:infinite?) ? @imaginary.infinite? : nil
    (r_inf && r_inf != 0) || (i_inf && i_inf != 0) ? 1 : nil
  end

  def coerce(other)
    if other.is_a?(Complex)
      [other, self]
    elsif other.is_a?(Numeric)
      real_q = other.respond_to?(:real?) ? other.real? : true
      raise TypeError, "#{other.class} can't be coerced into Complex" if real_q == false
      [Complex(other, 0), self]
    else
      raise TypeError, "#{other.class} can't be coerced into Complex"
    end
  end

  def fdiv(other)
    raise TypeError, "#{other.class} can't be coerced into Complex" unless other.is_a?(Numeric)
    Complex(@real.fdiv(other), @imaginary.fdiv(other))
  end

  def eql?(other)
    return false unless other.instance_of?(Complex)
    @real.class == other.real.class &&
    @imaginary.class == other.imaginary.class &&
    self == other
  end

  def inspect
    re_s = @real.inspect
    im_s = @imaginary.inspect
    sep, disp = __format_imag__(im_s)
    star = (disp[-1] =~ /[0-9]/) ? '' : '*'
    "(#{re_s}#{sep}#{disp}#{star}i)"
  end

  def to_s
    re_s = @real.to_s
    im_s = @imaginary.to_s
    sep, disp = __format_imag__(im_s)
    star = (disp[-1] =~ /[0-9]/) ? '' : '*'
    "#{re_s}#{sep}#{disp}#{star}i"
  end

  private

  def __format_imag__(im_s) = im_s.start_with?('-') ? ['-', im_s[1..]] : ['+', im_s]
  def marshal_dump = [@real, @imaginary]

  def __complex_coerce_op__(other, op)
    if other.is_a?(Complex)
      yield other
    else
      real_q = other.respond_to?(:real?) ? other.real? : nil
      if real_q == false
        begin
          a, b = other.coerce(self)
          a.send(op, b)
        rescue NoMethodError
          raise TypeError, "#{other.class} can't be coerced into Complex"
        end
      elsif other.is_a?(Numeric) || real_q
        yield other
      else
        begin
          a, b = other.coerce(self)
          a.send(op, b)
        rescue NoMethodError
          raise TypeError, "#{other.class} can't be coerced into Complex"
        end
      end
    end
  end

  def marshal_load(ary)
    @real, @imaginary = ary
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

  def Complex(real, *imag_args, exception: true)
    no_imag = imag_args.empty?
    imaginary = no_imag ? 0 : imag_args[0]

    # String real: delegate strict parsing to intrinsic
    if real.is_a?(String)
      c = Intrinsics.kernel_complex_from_string(self, real, exception ? true : false)
      return nil if c.nil?
      return no_imag ? c : Complex.new(c.real - c.imaginary * 0, c.imaginary + imaginary)
    end
    # nil real
    if real.nil?
      return nil unless exception
      raise TypeError, "can't convert nil into Complex"
    end
    real_numeric = real.is_a?(Numeric) || real.is_a?(Complex) || real.is_a?(Rational)

    # Non-Numeric real: try to_c
    unless real_numeric
      if no_imag
        begin
          return real.to_c
        rescue NoMethodError, TypeError
          return nil unless exception
          raise TypeError, "not a real"
        end
      else
        imag_numeric = imaginary.is_a?(Numeric) || imaginary.is_a?(Complex) || imaginary.is_a?(Rational)
        # With explicit imaginary: raise regardless of exception: if imaginary is Numeric
        raise TypeError, "not a real" if imag_numeric
        return nil unless exception
        raise TypeError, "not a real"
      end
    end
    # String imaginary
    if imaginary.is_a?(String)
      c = Intrinsics.kernel_complex_from_string(self, imaginary, exception ? true : false)
      return nil if c.nil?
      return Complex.new(real, c.real + c.imaginary)
    end
    # nil imaginary
    if imaginary.nil?
      return nil unless exception
      raise TypeError, "can't convert nil into Complex"
    end
    # Non-Numeric imaginary
    imag_numeric = imaginary.is_a?(Numeric) || imaginary.is_a?(Complex) || imaginary.is_a?(Rational)
    unless imag_numeric
      return nil unless exception
      raise TypeError, "not a real"
    end
    # If either arg is not "real" (responds to real? with false), use n1 + n2*i formula
    real_is_complex = real.respond_to?(:real?) && !real.real?
    imag_is_complex = imaginary.respond_to?(:real?) && !imaginary.real?
    if real_is_complex || imag_is_complex
      return real if no_imag  # single non-real Numeric: return as-is
      return real + imaginary * Complex(0, 1)
    end
    Complex.new(real, imaginary)
  end
end

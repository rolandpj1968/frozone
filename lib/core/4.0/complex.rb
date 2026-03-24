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

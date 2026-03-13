class Rational
  def initialize(numerator, denominator = 1)
    raise ZeroDivisionError, "divided by 0" if denominator == 0
    g = numerator.gcd(denominator)
    @numerator = numerator / g
    @denominator = denominator / g
    if @denominator < 0
      @numerator = -@numerator
      @denominator = -@denominator
    end
  end

  def numerator = @numerator
  def denominator = @denominator

  def +(other)
    case other
    when Rational then Rational(@numerator * other.denominator + other.numerator * @denominator, @denominator * other.denominator)
    when Integer  then Rational(@numerator + other * @denominator, @denominator)
    when Float    then to_f + other
    else               raise TypeError, "#{other.class} can't be coerced into Rational"
    end
  end

  def -(other)
    case other
    when Rational then Rational(@numerator * other.denominator - other.numerator * @denominator, @denominator * other.denominator)
    when Integer  then Rational(@numerator - other * @denominator, @denominator)
    when Float    then to_f - other
    else               raise TypeError, "#{other.class} can't be coerced into Rational"
    end
  end

  def *(other)
    case other
    when Rational then Rational(@numerator * other.numerator, @denominator * other.denominator)
    when Integer  then Rational(@numerator * other, @denominator)
    when Float    then to_f * other
    else               raise TypeError, "#{other.class} can't be coerced into Rational"
    end
  end

  def /(other)
    case other
    when Rational then Rational(@numerator * other.denominator, @denominator * other.numerator)
    when Integer  then Rational(@numerator, @denominator * other)
    when Float    then to_f / other
    else               raise TypeError, "#{other.class} can't be coerced into Rational"
    end
  end

  def **(other)
    case other
    when Integer
      if other >= 0
        Rational(@numerator ** other, @denominator ** other)
      else
        Rational(@denominator ** (-other), @numerator ** (-other))
      end
    when Float    then to_f ** other
    when Rational then to_f ** other.to_f
    else               raise TypeError, "#{other.class} can't be coerced into Rational"
    end
  end

  def ==(other)
    case other
    when Rational then @numerator == other.numerator && @denominator == other.denominator
    when Integer  then @denominator == 1 && @numerator == other
    when Float    then to_f == other
    else               false
    end
  end

  def <=>(other)
    case other
    when Rational then (@numerator * other.denominator) <=> (other.numerator * @denominator)
    when Integer  then @numerator <=> (other * @denominator)
    when Float    then to_f <=> other
    else               nil
    end
  end

  def to_f = @numerator.to_f / @denominator.to_f
  def to_i = @numerator / @denominator
  def to_r = self
  def to_c = Complex(self, 0)

  def abs = @numerator < 0 ? Rational(-@numerator, @denominator) : self
  def negative? = @numerator < 0
  def positive? = @numerator > 0
  def zero? = @numerator == 0
  def nonzero? = @numerator == 0 ? nil : self

  def hash = [@numerator, @denominator].hash
  def eql?(other) = other.is_a?(Rational) && @numerator == other.numerator && @denominator == other.denominator

  def inspect = "(#{@numerator}/#{@denominator})"
  def to_s = "#{@numerator}/#{@denominator}"
end

class Complex
  def initialize(real, imaginary = 0)
    @real = real
    @imaginary = imaginary
  end

  def real = @real
  def imaginary = @imaginary
  alias imag imaginary
  def real? = false

  def +(other)
    case other
    when Complex then Complex(@real + other.real, @imaginary + other.imaginary)
    when Numeric then Complex(@real + other, @imaginary)
    else              raise TypeError, "#{other.class} can't be coerced into Complex"
    end
  end

  def -(other)
    case other
    when Complex then Complex(@real - other.real, @imaginary - other.imaginary)
    when Numeric then Complex(@real - other, @imaginary)
    else              raise TypeError, "#{other.class} can't be coerced into Complex"
    end
  end

  def *(other)
    case other
    when Complex then Complex(@real * other.real - @imaginary * other.imaginary,
                              @real * other.imaginary + @imaginary * other.real)
    when Numeric then Complex(@real * other, @imaginary * other)
    else              raise TypeError, "#{other.class} can't be coerced into Complex"
    end
  end

  def ==(other)
    case other
    when Complex then @real == other.real && @imaginary == other.imaginary
    when Numeric then @imaginary == 0 && @real == other
    else              false
    end
  end

  def abs2 = @real * @real + @imaginary * @imaginary
  def abs = Math.sqrt(abs2.to_f)
  def to_f
    raise RangeError, "can't convert #{inspect} into Float" unless @imaginary == 0
    @real.to_f
  end
  def to_i
    raise RangeError, "can't convert #{inspect} into Integer" unless @imaginary == 0
    @real.to_i
  end
  def to_r
    raise RangeError, "can't convert #{inspect} into Rational" unless @imaginary == 0
    @real.to_r
  end
  def to_c = self

  def hash = [@real, @imaginary].hash
  def eql?(other) = other.is_a?(Complex) && @real.eql?(other.real) && @imaginary.eql?(other.imaginary)

  def inspect
    if @imaginary < 0 || (@imaginary.is_a?(Float) && @imaginary.nan?)
      "(#{@real}#{@imaginary}i)"
    else
      "(#{@real}+#{@imaginary}i)"
    end
  end

  def to_s
    if @imaginary < 0 || (@imaginary.is_a?(Float) && @imaginary.nan?)
      "#{@real}#{@imaginary}i"
    else
      "#{@real}+#{@imaginary}i"
    end
  end
end

module Kernel
  def Rational(numerator, denominator = 1)
    Rational.new(numerator, denominator)
  end

  def Complex(real, imaginary = 0)
    if imaginary == 0 && real.is_a?(Numeric) && !real.is_a?(Complex)
      Complex.new(real, 0)
    else
      Complex.new(real, imaginary)
    end
  end
end

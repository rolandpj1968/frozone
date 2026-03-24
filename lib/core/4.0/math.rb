module Math
  class DomainError < ArgumentError; end

  PI = 3.141592653589793
  E  = 2.718281828459045

  def self._coerce_float(x, func)
    return x if x.is_a?(Float)
    return x.to_f if x.is_a?(Integer)
    if x.is_a?(Numeric)
      result = x.to_f
      raise TypeError, "can't convert #{x.class} into Float (to_f should return Float, not #{result.class})" unless result.is_a?(Float)
      return result
    end
    raise TypeError, "can't convert #{x.nil? ? 'nil' : x.class} into Float"
  end
  private_class_method :_coerce_float

  def self._coerce_integer(n)
    return n if n.is_a?(Integer)
    type_name = n.nil? ? "nil" : n.class.to_s
    raise TypeError, "can't convert #{type_name} into Integer" unless n.respond_to?(:to_int)
    result = n.to_int
    raise TypeError, "can't convert #{type_name} into Integer" unless result.is_a?(Integer)
    result
  end
  private_class_method :_coerce_integer

  def self.sqrt(x) = Intrinsics.float_sqrt(_coerce_float(x, :sqrt))
  def self.cbrt(x) = Intrinsics.float_cbrt(_coerce_float(x, :cbrt))
  def self.exp(x) = Intrinsics.float_exp(_coerce_float(x, :exp))
  def self.log10(x) = Intrinsics.float_log10(_coerce_float(x, :log10))
  def self.sin(x) = Intrinsics.float_sin(_coerce_float(x, :sin))
  def self.cos(x) = Intrinsics.float_cos(_coerce_float(x, :cos))
  def self.tan(x) = Intrinsics.float_tan(_coerce_float(x, :tan))
  def self.asin(x) = Intrinsics.float_asin(_coerce_float(x, :asin))
  def self.acos(x) = Intrinsics.float_acos(_coerce_float(x, :acos))
  def self.atan(x) = Intrinsics.float_atan(_coerce_float(x, :atan))
  def self.atan2(y, x) = Intrinsics.float_atan2(_coerce_float(y, :atan2), _coerce_float(x, :atan2))
  def self.sinh(x) = Intrinsics.float_sinh(_coerce_float(x, :sinh))
  def self.cosh(x) = Intrinsics.float_cosh(_coerce_float(x, :cosh))
  def self.tanh(x) = Intrinsics.float_tanh(_coerce_float(x, :tanh))
  def self.asinh(x) = Intrinsics.float_asinh(_coerce_float(x, :asinh))
  def self.acosh(x) = Intrinsics.float_acosh(_coerce_float(x, :acosh))
  def self.atanh(x) = Intrinsics.float_atanh(_coerce_float(x, :atanh))
  def self.hypot(a, b) = Intrinsics.float_hypot(_coerce_float(a, :hypot), _coerce_float(b, :hypot))
  def self.frexp(x) = Intrinsics.float_frexp(_coerce_float(x, :frexp))
  def self.erf(x) = Intrinsics.float_erf(_coerce_float(x, :erf))
  def self.erfc(x) = Intrinsics.float_erfc(_coerce_float(x, :erfc))
  def self.expm1(x) = Intrinsics.float_expm1(_coerce_float(x, :expm1))
  def self.log1p(x) = Intrinsics.float_log1p(_coerce_float(x, :log1p))
  def self.gamma(x) = Intrinsics.float_gamma(_coerce_float(x, :gamma))
  def self.lgamma(x) = Intrinsics.float_lgamma(_coerce_float(x, :lgamma))

  def self.log(x, base = :__no_base__)
    xf = _coerce_float(x, :log)
    base.equal?(:__no_base__) ? Intrinsics.float_log(xf) : Intrinsics.float_log(xf) / Intrinsics.float_log(_coerce_float(base, :log))
  end

  def self.log2(x)
    if x.is_a?(Integer) && x > 0
      xf = x.to_f
      if xf.infinite?
        bl = x.bit_length
        mantissa = (x >> (bl - 54)).to_f / (1 << 53).to_f
        return Intrinsics.float_log2(mantissa) + (bl - 1)
      end
      return Intrinsics.float_log2(xf)
    end
    Intrinsics.float_log2(_coerce_float(x, :log2))
  end

  def self.ldexp(x, n)
    xf = _coerce_float(x, :ldexp)
    ni =
      if n.is_a?(Float)
        raise RangeError, "float NaN out of range of integer" if n.nan?
        n.to_i
      else
        _coerce_integer(n)
      end
    Intrinsics.float_ldexp(xf, ni)
  end
  # Also define instance methods for when Math is included
  def sqrt(x) = Math.sqrt(x)
  def cbrt(x) = Math.cbrt(x)
  def exp(x) = Math.exp(x)
  def log(x, base = nil) = Math.log(x, *[base].compact)
  def log2(x) = Math.log2(x)
  def log10(x) = Math.log10(x)
  def log1p(x) = Math.log1p(x)
  def sin(x) = Math.sin(x)
  def cos(x) = Math.cos(x)
  def tan(x) = Math.tan(x)
  def asin(x) = Math.asin(x)
  def acos(x) = Math.acos(x)
  def atan(x) = Math.atan(x)
  def atan2(y, x) = Math.atan2(y, x)
  def sinh(x) = Math.sinh(x)
  def cosh(x) = Math.cosh(x)
  def tanh(x) = Math.tanh(x)
  def asinh(x) = Math.asinh(x)
  def acosh(x) = Math.acosh(x)
  def atanh(x) = Math.atanh(x)
  def hypot(a, b) = Math.hypot(a, b)
  def frexp(x) = Math.frexp(x)
  def ldexp(x, n) = Math.ldexp(x, n)
  def erf(x) = Math.erf(x)
  def erfc(x) = Math.erfc(x)
  def expm1(x) = Math.expm1(x)
  def gamma(x) = Math.gamma(x)
  def lgamma(x) = Math.lgamma(x)
  private :sqrt, :cbrt, :exp, :log, :log2, :log10, :log1p, :sin, :cos, :tan,
          :asin, :acos, :atan, :atan2, :sinh, :cosh, :tanh, :asinh, :acosh, :atanh,
          :hypot, :frexp, :ldexp, :erf, :erfc, :expm1, :gamma, :lgamma
end

require "../src/frozone_crystal"

RUBY_NIL    = RubyNil::INSTANCE
RUBY_TRUE   = RubyBool::TRUE
RUBY_FALSE  = RubyBool::FALSE
RUBY_GLOBALS = {} of String => RubyObject
Ruby_ARGV   = RubyArray.new(ARGV.map { |s| RubyString.new(s).as(RubyObject) })
Ruby_Fiber  = RubyHash.new  # Fiber-local storage (single-fiber compiled mode)
RUBY_STDIN  = RubyIO.new(STDIN)
RUBY_STDOUT = RubyIO.new(STDOUT)
RUBY_STDERR = RubyIO.new(STDERR)
module Ruby_ENV
  def self.[](key : RubyObject) : RubyObject
    val = ENV[key.to_s]?
    val ? RubyString.new(val).as(RubyObject) : RUBY_NIL
  end
  def self.[]=(key : RubyObject, val : RubyObject) : RubyObject
    ENV[key.to_s] = val.to_s
    val
  end
end

Ruby_Str_0 = RubyString.new("\u0000").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("/home/rolandpj/src/frozone/bench/benchmarks/blurhash/test.bin").tap { |_s| _s.freeze_known_ascii! }

# User-defined method stubs on RubyObject for polymorphic dispatch
class RubyObject
  def blurHashForPixels(*args) : RubyObject
    raise Exception.new("undefined method 'blurHashForPixels' for #{self.class}")
  end
end

module Ruby_Blurhash
  module Ruby_Ruby
        def to_s : String; "#<Ruby>"; end
        def inspect : String; "#<Ruby>"; end

    def self.sRGBToLinear(value : Int64) : Float64
      v = (value.to_f64 / 255_i64)
      if (v <= 0.04045_f64)
        (v / 12.92_f64)
      else
        (((v + 0.055_f64) / 1.055_f64) ** 2.4_f64)
      end
    end

    def self.sRGBToLinear(value : RubyObject)
            v = RUBY_NIL
      v = RubyFloat.new(value.to_f64 / 255_i64.to_f64)
      if (((v <= RubyFloat.new(0.04045_f64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        (v / RubyFloat.new(12.92_f64))
      else
        (((v + RubyFloat.new(0.055_f64)) / RubyFloat.new(1.055_f64)) ** RubyFloat.new(2.4_f64))
      end
    end

    def self.multiplyBasisFunction(xComponent : Int64, yComponent : Int64, width : Int64, height : Int64, rgb : Array(UInt8), bytesPerRow : Int64, factors : Ruby_ThreeDArray)
      r = g = b = 0.0_f64
      normalisation = begin
        if ((xComponent == 0_i64) && (yComponent == 0_i64))
          1_i64
        else
          2_i64
        end
      end
      height.times() do |y|
  y_coef = Math.cos((((Math::PI * yComponent) * y) / height))
  width.times() do |x|
  basis = (Math.cos((((Math::PI * xComponent) * x) / width)) * y_coef)
  r = (r + (basis * sRGBToLinear(rgb.[]((((3_i64 * x) + 0_i64) + (y * bytesPerRow))).to_i64)))
  g = (g + (basis * sRGBToLinear(rgb.[]((((3_i64 * x) + 1_i64) + (y * bytesPerRow))).to_i64)))
  b = (b + (basis * sRGBToLinear(rgb.[]((((3_i64 * x) + 2_i64) + (y * bytesPerRow))).to_i64)))
end
end
      scale = (normalisation.to_f64 / (width * height))
      factors.set(RubyInteger.new(yComponent), RubyInteger.new(xComponent), RubyInteger.new(0_i64), RubyFloat.new(r * scale))
      factors.set(RubyInteger.new(yComponent), RubyInteger.new(xComponent), RubyInteger.new(1_i64), RubyFloat.new(g * scale))
      factors.set(RubyInteger.new(yComponent), RubyInteger.new(xComponent), RubyInteger.new(2_i64), RubyFloat.new(b * scale))
    end

    def self.multiplyBasisFunction(xComponent : RubyObject, yComponent : RubyObject, width : RubyObject, height : RubyObject, rgb : RubyObject, bytesPerRow : RubyObject, factors : RubyObject)
            r = RUBY_NIL
            g = RUBY_NIL
            b = RUBY_NIL
            normalisation = RUBY_NIL
            scale = RUBY_NIL
      r = g = b = RubyFloat.new(0.0_f64)
      normalisation = if ((_and0 = ((xComponent == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _and0.truthy? ? (((yComponent == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and0)).truthy?
        RubyInteger.new(1_i64)
      else
        RubyInteger.new(2_i64)
      end
      height.times() do |y| 
        y_coef = RubyMath.cos((((RubyFloat.new(Math::PI) * yComponent) * y) / height))
        width.times() do |x| 
          basis = (RubyMath.cos((((RubyFloat.new(Math::PI) * xComponent) * x) / width)) * y_coef)
          r = (r + (basis * self.sRGBToLinear(rgb[(((RubyInteger.new(3_i64) * x) + RubyInteger.new(0_i64)) + (y * bytesPerRow))].to_i64)))
          g = (g + (basis * self.sRGBToLinear(rgb[(((RubyInteger.new(3_i64) * x) + RubyInteger.new(1_i64)) + (y * bytesPerRow))].to_i64)))
          b = (b + (basis * self.sRGBToLinear(rgb[(((RubyInteger.new(3_i64) * x) + RubyInteger.new(2_i64)) + (y * bytesPerRow))].to_i64)))
        end
      end
      scale = (normalisation.to_f / (width * height))
      factors.set(yComponent, xComponent, RubyInteger.new(0_i64), (r * scale))
      factors.set(yComponent, xComponent, RubyInteger.new(1_i64), (g * scale))
      factors.set(yComponent, xComponent, RubyInteger.new(2_i64), (b * scale))
    end

    def self.encode_int(value : Int64, length : Int64, destination : Ruby_Buffer)
      divisor = (83_i64 ** (length - 1_i64))
      length.times() do |i|
  digit = ((value // divisor) % 83_i64)
  divisor = (divisor // 83_i64)
  destination.putc(Ruby_CHARACTERS[digit])
end
    end

    def self.encode_int(value : RubyObject, length : RubyObject, destination : RubyObject)
            divisor = RUBY_NIL
      divisor = (RubyInteger.new(83_i64) ** (length - RubyInteger.new(1_i64)))
      length.times() do |i| 
        digit = ((value / divisor) % RubyInteger.new(83_i64))
        divisor = (divisor / RubyInteger.new(83_i64))
        destination.putc(Ruby_CHARACTERS[digit])
      end
    end

    def self.linearTosRGB(value : Float64) : Int64
      v = Math.max(0_i64, Math.min(1_i64, value))
      if (v <= 0.0031308_f64)
        (((v * 12.92_f64) * 255_i64) + 0.5_f64).to_i64
      else
        ((((1.055_f64 * (v ** (1_i64 / 2.4_f64))) - 0.055_f64) * 255_i64) + 0.5_f64).to_i64
      end
    end

    def self.linearTosRGB(value : RubyObject)
            v = RUBY_NIL
      v = self.max(0_i64.to_f64, self.min(1_i64, value.to_f64))
      if (((v <= RubyFloat.new(0.0031308_f64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        (((v * RubyFloat.new(12.92_f64)) * RubyInteger.new(255_i64)) + RubyFloat.new(0.5_f64)).to_i
      else
        ((((RubyFloat.new(1.055_f64) * (v ** RubyFloat.new(1_i64.to_f64 / 2.4_f64))) - RubyFloat.new(0.055_f64)) * RubyInteger.new(255_i64)) + RubyFloat.new(0.5_f64)).to_i
      end
    end

    def self.encodeDC(r : Float64, g : Float64, b : Float64)
      roundedR = linearTosRGB(r.to_f64)
      roundedG = linearTosRGB(g.to_f64)
      roundedB = linearTosRGB(b.to_f64)
      (((roundedR << 16_i64) + (roundedG << 8_i64)) + roundedB)
    end

    def self.encodeDC(r : RubyObject, g : RubyObject, b : RubyObject)
            roundedR = RUBY_NIL
            roundedG = RUBY_NIL
            roundedB = RUBY_NIL
      roundedR = self.linearTosRGB(r.to_f64)
      roundedG = self.linearTosRGB(g.to_f64)
      roundedB = self.linearTosRGB(b.to_f64)
      (((roundedR << RubyInteger.new(16_i64)) + (roundedG << RubyInteger.new(8_i64))) + roundedB)
    end

    def self.max(a : Float64, b : Float64) : Float64
      RubyTuple2.new(RubyFloat.new(a), RubyFloat.new(b)).max
    end

    def self.max(a : RubyObject, b : RubyObject)
RubyTuple2.new(a, b).max
    end

    def self.min(a : Int64, b : Float64) : Float64
      RubyTuple2.new(RubyInteger.new(a), RubyFloat.new(b)).min
    end

    def self.min(a : RubyObject, b : RubyObject)
RubyTuple2.new(a, b).min
    end

    def self.signPow(value : Float64, exp : Float64) : Float64
      pow = (value.abs ** exp)
      if (value < 0_i64)
        (-pow)
      else
        pow
      end
    end

    def self.signPow(value : RubyObject, exp : RubyObject)
            pow = RUBY_NIL
      pow = (value.abs ** exp)
      if (((value < RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        (pow.-)
      else
        pow
      end
    end

    def self.encodeAC(r : Float64, g : Float64, b : Float64, maximumValue : Float64)
      quantR = Math.max(0_i64, Math.min(18_i64, ((signPow((r / maximumValue).to_f64, 0.5_f64.to_f64) * 9_i64) + 9.5_f64).floor.to_i64))
      quantG = Math.max(0_i64, Math.min(18_i64, ((signPow((g / maximumValue).to_f64, 0.5_f64.to_f64) * 9_i64) + 9.5_f64).floor.to_i64))
      quantB = Math.max(0_i64, Math.min(18_i64, ((signPow((b / maximumValue).to_f64, 0.5_f64.to_f64) * 9_i64) + 9.5_f64).floor.to_i64))
      ((((quantR * 19_i64) * 19_i64) + (quantG * 19_i64)) + quantB)
    end

    def self.encodeAC(r : RubyObject, g : RubyObject, b : RubyObject, maximumValue : RubyObject)
            quantR = RUBY_NIL
            quantG = RUBY_NIL
            quantB = RUBY_NIL
      quantR = self.max(0_i64.to_f64, self.min(18_i64, RubyFloat.new((self.signPow((r / maximumValue).to_f64, 0.5_f64) * 9_i64.to_f64) + 9.5_f64).floor.to_f64))
      quantG = self.max(0_i64.to_f64, self.min(18_i64, RubyFloat.new((self.signPow((g / maximumValue).to_f64, 0.5_f64) * 9_i64.to_f64) + 9.5_f64).floor.to_f64))
      quantB = self.max(0_i64.to_f64, self.min(18_i64, RubyFloat.new((self.signPow((b / maximumValue).to_f64, 0.5_f64) * 9_i64.to_f64) + 9.5_f64).floor.to_f64))
      ((((quantR * RubyInteger.new(19_i64)) * RubyInteger.new(19_i64)) + (quantG * RubyInteger.new(19_i64))) + quantB)
    end

    def self.blurHashForPixels(xComponents : Int64, yComponents : Int64, width : Int64, height : Int64, rgb : Array(UInt8), bytesPerRow : Int64)
      if ((xComponents < 1_i64) || (xComponents > 9_i64))
        return
      else
        RUBY_NIL
      end
      if ((yComponents < 1_i64) || (yComponents > 9_i64))
        return
      else
        RUBY_NIL
      end
      factors = Ruby_ThreeDArray.new(yComponents, xComponents, 3_i64)
      ptr = Ruby_Buffer.new((((2_i64 + 4_i64) + (((9_i64 * 9_i64) - 1_i64) * 2_i64)) + 1_i64))
      yComponents.times() { |y| xComponents.times() { |x| multiplyBasisFunction(x.to_i64, y.to_i64, width.to_i64, height.to_i64, rgb, bytesPerRow.to_i64, factors) } }
      acCount = ((xComponents * yComponents) - 1_i64)
      sizeFlag = ((xComponents - 1_i64) + ((yComponents - 1_i64) * 9_i64))
      encode_int(sizeFlag.to_i64, 1_i64.to_i64, ptr)
      if (acCount > 0_i64)
        actualMaximumValue = 0.0_f64
        (acCount * 3_i64).times { |i| actualMaximumValue = self.max(actualMaximumValue, factors.[]((i + 3_i64)).abs.to_f64) }
        quantisedMaximumValue = Math.max(0_i64, Math.min(82_i64, ((actualMaximumValue * 166_i64) - 0.5_f64).floor.to_i64))
        maximumValue = ((quantisedMaximumValue.to_f64 + 1_i64) / 166_i64)
        encode_int(quantisedMaximumValue.to_i64, 1_i64.to_i64, ptr)
      else
        maximumValue = 1_i64
        encode_int(0_i64.to_i64, 1_i64.to_i64, ptr)
      end
      encode_int(encodeDC(factors.[](0_i64).to_f64.to_f64, factors.[](1_i64).to_f64.to_f64, factors.[](2_i64).to_f64.to_f64).to_i64, 4_i64.to_i64, ptr)
      acCount.times() { |i| encode_int(encodeAC(factors.[](((i * 3_i64) + 3_i64)).to_f64.to_f64, factors.[](((i * 3_i64) + 4_i64)).to_f64.to_f64, factors.[](((i * 3_i64) + 5_i64)).to_f64.to_f64, maximumValue.to_f64).to_i64, 2_i64.to_i64, ptr) }
      ptr.[](0_i64, ptr.pos().to_i64)
    end

    def self.blurHashForPixels(xComponents : RubyObject, yComponents : RubyObject, width : RubyObject, height : RubyObject, rgb : RubyObject, bytesPerRow : RubyObject)
            factors = RUBY_NIL
            ptr = RUBY_NIL
            acCount = RUBY_NIL
            sizeFlag = RUBY_NIL
            actualMaximumValue = RUBY_NIL
            quantisedMaximumValue = RUBY_NIL
            maximumValue = RUBY_NIL
      if ((_or1 = ((xComponents < RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE); _or1.truthy? ? _or1 : (((xComponents > RubyInteger.new(9_i64)) ? RUBY_TRUE : RUBY_FALSE)))).truthy?
        return
      else
        RUBY_NIL
      end
      if ((_or2 = ((yComponents < RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE); _or2.truthy? ? _or2 : (((yComponents > RubyInteger.new(9_i64)) ? RUBY_TRUE : RUBY_FALSE)))).truthy?
        return
      else
        RUBY_NIL
      end
      factors = Ruby_ThreeDArray.new(yComponents, xComponents, RubyInteger.new(3_i64))
      ptr = Ruby_Buffer.new(RubyInteger.new(((2_i64 + 4_i64) + (((9_i64 * 9_i64) - 1_i64) * 2_i64)) + 1_i64))
      yComponents.times() { |y| xComponents.times() { |x| self.multiplyBasisFunction(x.to_i64, y.to_i64, width.to_i64, height.to_i64, rgb, bytesPerRow.to_i64, factors) } }
      acCount = ((xComponents * yComponents) - RubyInteger.new(1_i64))
      sizeFlag = ((xComponents - RubyInteger.new(1_i64)) + ((yComponents - RubyInteger.new(1_i64)) * RubyInteger.new(9_i64)))
      self.encode_int(sizeFlag.to_i64, 1_i64, ptr)
      if (((acCount > RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        actualMaximumValue = RubyFloat.new(0.0_f64)
        (acCount * RubyInteger.new(3_i64)).times() { |i| actualMaximumValue = self.max(actualMaximumValue.to_f64, factors.[]((i.to_i64 + 3_i64)).abs.to_f64) }
        quantisedMaximumValue = self.max(0_i64.to_f64, self.min(82_i64, ((actualMaximumValue * RubyInteger.new(166_i64)) - RubyFloat.new(0.5_f64)).floor.to_f64))
        maximumValue = RubyFloat.new((quantisedMaximumValue.to_f64 + 1_i64.to_f64) / 166_i64.to_f64)
        self.encode_int(quantisedMaximumValue.to_i64, 1_i64, ptr)
      else
        maximumValue = RubyInteger.new(1_i64)
        self.encode_int(0_i64, 1_i64, ptr)
      end
      self.encode_int(self.encodeDC(factors.[](0_i64), factors.[](1_i64), factors.[](2_i64)).to_i64, 4_i64, ptr)
      acCount.times() { |i| self.encode_int(self.encodeAC(factors.[](((i.to_i64 * 3_i64) + 3_i64)), factors.[](((i.to_i64 * 3_i64) + 4_i64)), factors.[](((i.to_i64 * 3_i64) + 5_i64)), maximumValue.to_f64).to_i64, 2_i64, ptr) }
      ptr.[](0_i64, ptr.as(::Ruby_Blurhash::Ruby_Ruby::Ruby_Buffer).pos_raw)
    end

    class Ruby_ThreeDArray < RubyObject
            @list : Array(Float64) = Array(Float64).new
            @x : Int64 = 0_i64
            @y : Int64 = 0_i64
            @z : Int64 = 0_i64

            def to_s : String; "#<ThreeDArray>"; end
            def inspect : String; "#<ThreeDArray>"; end

      def initialize(y : Int64, x : Int64, z : Int64)
        @y = y
        @x = x
        @z = z
        @list = Array(Float64).new(((y * x) * z), 0.0)
      end

      def initialize(y : RubyObject, x : RubyObject, z : RubyObject)
        @y = ((_v = y); _v.ruby_nil? ? 0_i64 : _v.to_i64)
        @x = ((_v = x); _v.ruby_nil? ? 0_i64 : _v.to_i64)
        @z = ((_v = z); _v.ruby_nil? ? 0_i64 : _v.to_i64)
        @list = Array(Float64).new(((y * x) * z).to_i64, 0.0)
      end

      def set(y : Int64, x : Int64, z : Int64, val : Float64) : Float64
                i = RUBY_NIL
i = ((z + (x * @z)) + ((y * @z) * @x))
        @list[i] = val
      end

      def set(y : RubyObject, x : RubyObject, z : RubyObject, val : RubyObject)
                i = RUBY_NIL
        i = ((z + (x * RubyInteger.new(@z))) + ((y * RubyInteger.new(@z)) * RubyInteger.new(@x))).to_i64
        @list[i] = val.to_f64
      end

      def get(y : RubyObject, x : RubyObject, z : RubyObject)
                i = RUBY_NIL
        i = ((z + (x * RubyInteger.new(@z))) + ((y * RubyInteger.new(@z)) * RubyInteger.new(@x)))
        RubyFloat.new(@list[i.to_i64])
      end

      def [](i : Int64) : Float64
RubyFloat.new(@list[i])
      end

      def [](i : RubyObject)
RubyFloat.new(@list[i.to_i64])
      end

      def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
                __anon_block__ = RUBY_NIL
RUBY_NIL
      end

      def make_shareable(x : RubyObject)
x
      end

      def putc(c : RubyObject)
RUBY_STDOUT.putc(c)
      end

              RESPOND_TO_TABLE = StaticArray[false]

            def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
        sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
        idx = sym.method_index
        (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
            end

    end
    class Ruby_Buffer < RubyObject
            @pos : Int64 = 0_i64
            @buf : RubyObject = RUBY_NIL

            def to_s : String; "#<Buffer>"; end
            def inspect : String; "#<Buffer>"; end

            def pos : RubyObject; RubyInteger.new(@pos); end
      def pos_raw : Int64; @pos; end
      def initialize(size : Int64)
        @pos = 0_i64
        @buf = (Ruby_Str_0.b * RubyInteger.new(size))
      end

      def initialize(size : RubyObject)
        @pos = 0_i64
        @buf = (Ruby_Str_0.b * size)
      end

      def putc(c : RubyObject)
        @buf.setbyte(RubyInteger.new(@pos), c)
        @pos = (@pos + 1_i64)
      end

      def [](from : Int64, len : Int64)
@buf.[](from, len)
      end

      def [](from : RubyObject, len : RubyObject)
@buf.[](from, len)
      end

      def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
                __anon_block__ = RUBY_NIL
RUBY_NIL
      end

      def make_shareable(x : RubyObject)
x
      end

              RESPOND_TO_TABLE = StaticArray[false]

            def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
        sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
        idx = sym.method_index
        (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
            end

    end
  end
end
def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
    __anon_block__ = RUBY_NIL
RUBY_NIL
end

def make_shareable(x : RubyObject)
x
end

# User methods on Object — also available as instance methods
class RubyObject
  def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
    __anon_block__ = RUBY_NIL
RUBY_NIL
end
  def make_shareable(x : RubyObject)
x
end
end


last = Ruby_Str_1
10_i64.times { last = Ruby_Blurhash.encode_rb(204_i64, 204_i64, Ruby_ARRAY) }
ruby_puts(last); RUBY_NIL

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

Ruby_Str_0 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }

def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end

def fannkuch(n : Int64)
    loc_p = RUBY_NIL
    s = RUBY_NIL
    q = RUBY_NIL
    sign = RUBY_NIL
    sum = RUBY_NIL
    maxflips = RUBY_NIL
    q1 = RUBY_NIL
    flips = RUBY_NIL
    qq = RUBY_NIL
    i = RUBY_NIL
    j = RUBY_NIL
    t = RUBY_NIL
  loc_p = (0_i64..n).to_a
  s = loc_p.dup
  q = loc_p.dup
  sign = 1_i64
  sum = maxflips = 0_i64
  while (  RUBY_TRUE).truthy?
    if ((q1 = loc_p[1_i64]) != 1_i64)
      q[0_i64..-1_i64] = loc_p
      flips = 1_i64
      until ((qq = q[q1]) == 1_i64)
        q[q1] = q1
        if (q1 >= 4_i64)
          i = 2_i64
          j = (q1 - 1_i64)
          while (i < j)
            _ma0 = masgn_coerce(RubyTuple2.new(RubyInteger.new(q[j]), RubyInteger.new(q[i])))
            q[i] = _ma0[0_i64].to_i64
            q[j] = _ma0[1_i64].to_i64
            i = (i + 1_i64)
            j = (j - 1_i64)
          end
        end
        q1 = qq
        flips = (flips + 1_i64)
      end
      sum = (sum + (sign * flips))
      if (flips > maxflips)
        maxflips = flips
      end
    end
    if (sign == 1_i64)
      _ma1 = masgn_coerce(RubyTuple2.new(RubyInteger.new(loc_p[2_i64]), RubyInteger.new(loc_p[1_i64])))
      loc_p[1_i64] = _ma1[0_i64].to_i64
      loc_p[2_i64] = _ma1[1_i64].to_i64
      sign = -1_i64
    else
      _ma2 = masgn_coerce(RubyTuple2.new(RubyInteger.new(loc_p[3_i64]), RubyInteger.new(loc_p[2_i64])))
      loc_p[2_i64] = _ma2[0_i64].to_i64
      loc_p[3_i64] = _ma2[1_i64].to_i64
      sign = 1_i64
      i = 3_i64
      while ((i <= n) && (s[i] == 1_i64))
        if (i == n)
          return RubyTuple2.new(RubyInteger.new(sum), RubyInteger.new(maxflips))
        end
        s[i] = i
        t = loc_p.delete_at(1_i64)
        i = (i + 1_i64)
        loc_p.insert(i, t)
      end
      if (i <= n)
        s[i] -= 1_i64
      end
    end
  end
end

def fannkuch(n : RubyObject)
    loc_p = RUBY_NIL
    s = RUBY_NIL
    q = RUBY_NIL
    sign = RUBY_NIL
    sum = RUBY_NIL
    maxflips = RUBY_NIL
    q1 = RUBY_NIL
    flips = RUBY_NIL
    qq = RUBY_NIL
    i = RUBY_NIL
    j = RUBY_NIL
    t = RUBY_NIL
  loc_p = (0_i64..n.to_i64).to_a
  s = loc_p.dup
  q = loc_p.dup
  sign = 1_i64
  sum = maxflips = 0_i64
  while (  RUBY_TRUE).truthy?
    if ((q1 = loc_p[1_i64]) != 1_i64)
      q[0_i64..-1_i64] = loc_p
      flips = 1_i64
      until ((qq = q[q1]) == 1_i64)
        q[q1] = q1
        if (q1 >= 4_i64)
          i = 2_i64
          j = (q1 - 1_i64)
          while (i < j)
            _ma3 = masgn_coerce(RubyTuple2.new(RubyInteger.new(q[j]), RubyInteger.new(q[i])))
            q[i] = _ma3[0_i64].to_i64
            q[j] = _ma3[1_i64].to_i64
            i = (i + 1_i64)
            j = (j - 1_i64)
          end
        end
        q1 = qq
        flips = (flips + 1_i64)
      end
      sum = (sum + (sign * flips))
      if (flips > maxflips)
        maxflips = flips
      end
    end
    if (sign == 1_i64)
      _ma4 = masgn_coerce(RubyTuple2.new(RubyInteger.new(loc_p[2_i64]), RubyInteger.new(loc_p[1_i64])))
      loc_p[1_i64] = _ma4[0_i64].to_i64
      loc_p[2_i64] = _ma4[1_i64].to_i64
      sign = -1_i64
    else
      _ma5 = masgn_coerce(RubyTuple2.new(RubyInteger.new(loc_p[3_i64]), RubyInteger.new(loc_p[2_i64])))
      loc_p[2_i64] = _ma5[0_i64].to_i64
      loc_p[3_i64] = _ma5[1_i64].to_i64
      sign = 1_i64
      i = 3_i64
      while ((_and6 = ((RubyInteger.new(i) <= n) ? RUBY_TRUE : RUBY_FALSE); _and6.truthy? ? (((s[i] == 1_i64) ? RUBY_TRUE : RUBY_FALSE)) : _and6)).truthy?
        if (((RubyInteger.new(i) == n) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return RubyTuple2.new(RubyInteger.new(sum), RubyInteger.new(maxflips))
        end
        s[i] = i
        t = loc_p.delete_at(1_i64)
        i = (i + 1_i64)
        loc_p.insert(i, t)
      end
      if (((RubyInteger.new(i) <= n) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        s[i] -= 1_i64
      end
    end
  end
end

# User methods on Object — also available as instance methods
class RubyObject
  def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end
end

Ruby_N = RubyInteger.new(9_i64)

sum = 0_i64
flips = 0_i64
10_i64.times { _ma7 = masgn_coerce(fannkuch(Ruby_N.to_i64))
sum = _ma7[0_i64].to_i64
flips = _ma7[1_i64].to_i64 }
ruby_puts(RubyInteger.new(sum)); RUBY_NIL
ruby_puts(RubyInteger.new(flips)); RUBY_NIL

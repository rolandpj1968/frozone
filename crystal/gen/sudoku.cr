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

Ruby_Str_0 = RubyString.new("1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("9").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }

def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
    __anon_block__ = RUBY_NIL
RUBY_NIL
end

def make_shareable(x : RubyObject)
x
end

def sd_genmat
    mr = RUBY_NIL
    mc = RUBY_NIL
    r = RUBY_NIL
    i = RUBY_NIL
    j = RUBY_NIL
    k = RUBY_NIL
    mcr = RUBY_NIL
    r2 = RUBY_NIL
    c2 = RUBY_NIL
  mr = Array(Array(Int64)).new(324_i64) { Array(Int64).new }
  mc = Array(Array(Int64)).new(729_i64) { Array(Int64).new(4_i64, 0_i64) }
  r = 0_i64
  i = 0_i64
  while (i < 9_i64)
    j = 0_i64
    while (j < 9_i64)
      k = 0_i64
      while (k < 9_i64)
        mcr = mc[r]
        mcr[0_i64] = ((9_i64 * i) + j)
        mcr[1_i64] = ((((((i // 3_i64) * 3_i64) + (j // 3_i64)) * 9_i64) + k) + 81_i64)
        mcr[2_i64] = (((9_i64 * i) + k) + 162_i64)
        mcr[3_i64] = (((9_i64 * j) + k) + 243_i64)
        r = (r + 1_i64)
        k = (k + 1_i64)
      end
      j = (j + 1_i64)
    end
    i = (i + 1_i64)
  end
  r2 = 0_i64
  while (r2 < 729_i64)
    c2 = 0_i64
    while (c2 < 4_i64)
      mr[mc[r2][c2].to_i64] << r2
      c2 = (c2 + 1_i64)
    end
    r2 = (r2 + 1_i64)
  end
  {mr, mc}
end

def sd_update_forward(mr : Array(Array(Int64)), mc : Array(Array(Int64)), sr : Array(Int64), sc : Array(Int64), r : Int64)
    min = RUBY_NIL
    min_c = RUBY_NIL
    mcr = RUBY_NIL
    c2 = RUBY_NIL
    mrc = RUBY_NIL
    r2 = RUBY_NIL
    rr = RUBY_NIL
    loc_p = RUBY_NIL
    cc2 = RUBY_NIL
    cc = RUBY_NIL
  min = 10_i64
  min_c = 0_i64
  mcr = mc[r]
  c2 = 0_i64
  while (c2 < 4_i64)
    sc[mcr[c2]] += 128_i64
    c2 = (c2 + 1_i64)
  end
  c2 = 0_i64
  while (c2 < 4_i64)
    mrc = mr[mcr[c2]]
    r2 = 0_i64
    while (r2 < 9_i64)
      rr = mrc[r2]
      if ((sr[rr] += 1_i64) == 1_i64)
        loc_p = mc[rr]
        cc2 = 0_i64
        while (cc2 < 4_i64)
          cc = loc_p[cc2]
          if ((sc[cc] -= 1_i64) < min)
            min = sc[cc]
            min_c = cc
          else
            RUBY_NIL
          end
          cc2 = (cc2 + 1_i64)
        end
      else
        RUBY_NIL
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
  {min, min_c}
end

def sd_update_forward(mr : RubyObject, mc : RubyObject, sr : RubyObject, sc : RubyObject, r : RubyObject)
    min = RUBY_NIL
    min_c = RUBY_NIL
    mcr = RUBY_NIL
    c2 = RUBY_NIL
    mrc = RUBY_NIL
    r2 = RUBY_NIL
    rr = RUBY_NIL
    loc_p = RUBY_NIL
    cc2 = RUBY_NIL
    cc = RUBY_NIL
  min = 10_i64
  min_c = 0_i64
  mcr = mc[r].as(RubyArray)
  c2 = 0_i64
  while (c2 < 4_i64)
    (_iopw_r0 = sc; _iopw_i0 = mcr[c2].as(RubyInteger).to_i64; _iopw_r0[_iopw_i0] = (_iopw_r0[_iopw_i0] + RubyInteger.new(128_i64)))
    c2 = (c2 + 1_i64)
  end
  c2 = 0_i64
  while (c2 < 4_i64)
    mrc = mr[mcr[c2].as(RubyInteger).to_i64].as(RubyArray)
    r2 = 0_i64
    while (r2 < 9_i64)
      rr = mrc[r2].as(RubyInteger).to_i64
      if (((((_iopw_r1 = sr; _iopw_i1 = rr; _iopw_r1[_iopw_i1] = (_iopw_r1[_iopw_i1] + RubyInteger.new(1_i64)))) == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        loc_p = mc[rr].as(RubyArray)
        cc2 = 0_i64
        while (cc2 < 4_i64)
          cc = loc_p[cc2].as(RubyInteger).to_i64
          if (((((_iopw_r2 = sc; _iopw_i2 = cc; _iopw_r2[_iopw_i2] = (_iopw_r2[_iopw_i2] - RubyInteger.new(1_i64)))) < RubyInteger.new(min)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            min = sc[cc].to_i64
            min_c = cc
          else
            RUBY_NIL
          end
          cc2 = (cc2 + 1_i64)
        end
      else
        RUBY_NIL
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
  {min, min_c}
end

def sd_update_reverse(mr : Array(Array(Int64)), mc : Array(Array(Int64)), sr : Array(Int64), sc : Array(Int64), r : Int64)
    c2 = RUBY_NIL
    c = RUBY_NIL
    r2 = RUBY_NIL
    rr = RUBY_NIL
    loc_p = RUBY_NIL
  c2 = 0_i64
  while (c2 < 4_i64)
    sc[mc[r][c2].to_i64] -= 128_i64
    c2 = (c2 + 1_i64)
  end
  c2 = 0_i64
  while (c2 < 4_i64)
    c = mc[r][c2].to_i64
    r2 = 0_i64
    while (r2 < 9_i64)
      rr = mr[c][r2].to_i64
      if ((sr[rr] -= 1_i64) == 0_i64)
        loc_p = mc[rr]
        sc[loc_p[0_i64]] += 1_i64
        sc[loc_p[1_i64]] += 1_i64
        sc[loc_p[2_i64]] += 1_i64
        sc[loc_p[3_i64]] += 1_i64
      else
        RUBY_NIL
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
end

def sd_update_reverse(mr : RubyObject, mc : RubyObject, sr : RubyObject, sc : RubyObject, r : RubyObject)
    c2 = RUBY_NIL
    c = RUBY_NIL
    r2 = RUBY_NIL
    rr = RUBY_NIL
    loc_p = RUBY_NIL
  c2 = 0_i64
  while (c2 < 4_i64)
    (_iopw_r3 = sc; _iopw_i3 = mc[r][c2]; _iopw_r3[_iopw_i3] = (_iopw_r3[_iopw_i3] - RubyInteger.new(128_i64)))
    c2 = (c2 + 1_i64)
  end
  c2 = 0_i64
  while (c2 < 4_i64)
    c = mc[r][c2].to_i64
    r2 = 0_i64
    while (r2 < 9_i64)
      rr = mr[c][r2].to_i64
      if (((((_iopw_r4 = sr; _iopw_i4 = rr; _iopw_r4[_iopw_i4] = (_iopw_r4[_iopw_i4] - RubyInteger.new(1_i64)))) == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
        loc_p = mc[rr].as(RubyArray)
        (_iopw_r5 = sc; _iopw_i5 = loc_p[0_i64].as(RubyInteger).to_i64; _iopw_r5[_iopw_i5] = (_iopw_r5[_iopw_i5] + RubyInteger.new(1_i64)))
        (_iopw_r6 = sc; _iopw_i6 = loc_p[1_i64].as(RubyInteger).to_i64; _iopw_r6[_iopw_i6] = (_iopw_r6[_iopw_i6] + RubyInteger.new(1_i64)))
        (_iopw_r7 = sc; _iopw_i7 = loc_p[2_i64].as(RubyInteger).to_i64; _iopw_r7[_iopw_i7] = (_iopw_r7[_iopw_i7] + RubyInteger.new(1_i64)))
        (_iopw_r8 = sc; _iopw_i8 = loc_p[3_i64].as(RubyInteger).to_i64; _iopw_r8[_iopw_i8] = (_iopw_r8[_iopw_i8] + RubyInteger.new(1_i64)))
      else
        RUBY_NIL
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
end

def sd_solve(mr : Array(Array(Int64)), mc : Array(Array(Int64)), s : RubyObject)
    sr = RUBY_NIL
    sc = RUBY_NIL
    hints = RUBY_NIL
    i = RUBY_NIL
    char = RUBY_NIL
    a = RUBY_NIL
    cr = RUBY_NIL
    cc = RUBY_NIL
    min = RUBY_NIL
    dir = RUBY_NIL
    c = RUBY_NIL
    r2 = RUBY_NIL
    o = RUBY_NIL
    j = RUBY_NIL
    r = RUBY_NIL
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if ((_and9 = ((char >= Ruby_Str_0) ? RUBY_TRUE : RUBY_FALSE); _and9.truthy? ? (((char <= Ruby_Str_1) ? RUBY_TRUE : RUBY_FALSE)) : _and9)).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
    else
      RUBY_NIL
    end
    i = (i + 1_i64)
  end
  cr = Array(Int64).new(81_i64, -1_i64)
  cc = Array(Int64).new(81_i64, 0_i64)
  i = 0_i64
  min = 10_i64
  dir = 1_i64
  while true
    while ((i >= 0_i64) && (i < (81_i64 - hints)))
      if (dir == 1_i64)
        if (min > 1_i64)
          c = 0_i64
          while (c < 324_i64)
            if (sc[c] < min)
              min = sc[c]
              cc[i] = c
              if (min < 2_i64)
                break
              else
                RUBY_NIL
              end
            else
              RUBY_NIL
            end
            c = (c + 1_i64)
          end
        else
          RUBY_NIL
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        else
          RUBY_NIL
        end
      else
        RUBY_NIL
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
      else
        RUBY_NIL
      end
      r2 = (cr[i] + 1_i64)
      while ((r2 < 9_i64) && (sr[mr[c][r2].to_i64] != 0_i64))
r2 = (r2 + 1_i64)
      end
      if (r2 < 9_i64)
        _tup10_0, _tup10_1 = sd_update_forward(mr, mc, sr, sc, mr[c][r2].to_i64)
        min = _tup10_0.to_i64
        cc[(i + 1_i64)] = _tup10_1.to_i64
        cr[i] = r2
        dir = 1_i64
        i = (i + 1_i64)
      else
        cr[i] = -1_i64
        dir = -1_i64
        i = (i - 1_i64)
      end
    end
    if (i < 0_i64)
      break
    else
      RUBY_NIL
    end
    o = Array(Int64).new(81_i64, 0_i64)
    j = 0_i64
    while (j < 81_i64)
      o[j] = (s[j].ord.to_i64 - 48_i64)
      j = (j + 1_i64)
    end
    j = 0_i64
    while (j < i)
      r = mr[cc[j]][cr[j]].to_i64
      o[(r // 9_i64)] = ((r % 9_i64) + 1_i64)
      j = (j + 1_i64)
    end
    o.join
    i = (i - 1_i64)
    dir = -1_i64
  end
end

def sd_solve(mr : RubyObject, mc : RubyObject, s : RubyObject)
    sr = RUBY_NIL
    sc = RUBY_NIL
    hints = RUBY_NIL
    i = RUBY_NIL
    char = RUBY_NIL
    a = RUBY_NIL
    cr = RUBY_NIL
    cc = RUBY_NIL
    min = RUBY_NIL
    dir = RUBY_NIL
    c = RUBY_NIL
    r2 = RUBY_NIL
    o = RUBY_NIL
    j = RUBY_NIL
    r = RUBY_NIL
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if ((_and11 = ((char >= Ruby_Str_0) ? RUBY_TRUE : RUBY_FALSE); _and11.truthy? ? (((char <= Ruby_Str_1) ? RUBY_TRUE : RUBY_FALSE)) : _and11)).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
    else
      RUBY_NIL
    end
    i = (i + 1_i64)
  end
  cr = Array(Int64).new(81_i64, -1_i64)
  cc = Array(Int64).new(81_i64, 0_i64)
  i = 0_i64
  min = 10_i64
  dir = 1_i64
  while true
    while ((i >= 0_i64) && (i < (81_i64 - hints)))
      if (dir == 1_i64)
        if (min > 1_i64)
          c = 0_i64
          while (c < 324_i64)
            if (sc[c] < min)
              min = sc[c]
              cc[i] = c
              if (min < 2_i64)
                break
              else
                RUBY_NIL
              end
            else
              RUBY_NIL
            end
            c = (c + 1_i64)
          end
        else
          RUBY_NIL
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        else
          RUBY_NIL
        end
      else
        RUBY_NIL
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
      else
        RUBY_NIL
      end
      r2 = (cr[i] + 1_i64)
      while ((r2 < 9_i64) && (sr[mr[c][r2].to_i64] != 0_i64))
r2 = (r2 + 1_i64)
      end
      if (r2 < 9_i64)
        _tup12_0, _tup12_1 = sd_update_forward(mr, mc, sr, sc, mr[c][r2].to_i64)
        min = _tup12_0.to_i64
        cc[(i + 1_i64)] = _tup12_1.to_i64
        cr[i] = r2
        dir = 1_i64
        i = (i + 1_i64)
      else
        cr[i] = -1_i64
        dir = -1_i64
        i = (i - 1_i64)
      end
    end
    if (i < 0_i64)
      break
    else
      RUBY_NIL
    end
    o = Array(Int64).new(81_i64, 0_i64)
    j = 0_i64
    while (j < 81_i64)
      o[j] = (s[j].ord.to_i64 - 48_i64)
      j = (j + 1_i64)
    end
    j = 0_i64
    while (j < i)
      r = mr[cc[j]][cr[j]].to_i64
      o[(r // 9_i64)] = ((r % 9_i64) + 1_i64)
      j = (j + 1_i64)
    end
    o.join
    i = (i - 1_i64)
    dir = -1_i64
  end
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
  def sd_genmat
    mr = RUBY_NIL
    mc = RUBY_NIL
    r = RUBY_NIL
    i = RUBY_NIL
    j = RUBY_NIL
    k = RUBY_NIL
    mcr = RUBY_NIL
    r2 = RUBY_NIL
    c2 = RUBY_NIL
  mr = Array(Array(Int64)).new(324_i64) { Array(Int64).new }
  mc = Array(Array(Int64)).new(729_i64) { Array(Int64).new(4_i64, 0_i64) }
  r = 0_i64
  i = 0_i64
  while (i < 9_i64)
    j = 0_i64
    while (j < 9_i64)
      k = 0_i64
      while (k < 9_i64)
        mcr = mc[r]
        mcr[0_i64] = ((9_i64 * i) + j)
        mcr[1_i64] = ((((((i // 3_i64) * 3_i64) + (j // 3_i64)) * 9_i64) + k) + 81_i64)
        mcr[2_i64] = (((9_i64 * i) + k) + 162_i64)
        mcr[3_i64] = (((9_i64 * j) + k) + 243_i64)
        r = (r + 1_i64)
        k = (k + 1_i64)
      end
      j = (j + 1_i64)
    end
    i = (i + 1_i64)
  end
  r2 = 0_i64
  while (r2 < 729_i64)
    c2 = 0_i64
    while (c2 < 4_i64)
      mr[mc[r2][c2].to_i64] << r2
      c2 = (c2 + 1_i64)
    end
    r2 = (r2 + 1_i64)
  end
  {mr, mc}
end
  def sd_solve(mr : RubyObject, mc : RubyObject, s : RubyObject)
    sr = RUBY_NIL
    sc = RUBY_NIL
    hints = RUBY_NIL
    i = RUBY_NIL
    char = RUBY_NIL
    a = RUBY_NIL
    cr = RUBY_NIL
    cc = RUBY_NIL
    min = RUBY_NIL
    dir = RUBY_NIL
    c = RUBY_NIL
    r2 = RUBY_NIL
    o = RUBY_NIL
    j = RUBY_NIL
    r = RUBY_NIL
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if ((_and13 = ((char >= Ruby_Str_0) ? RUBY_TRUE : RUBY_FALSE); _and13.truthy? ? (((char <= Ruby_Str_1) ? RUBY_TRUE : RUBY_FALSE)) : _and13)).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
    else
      RUBY_NIL
    end
    i = (i + 1_i64)
  end
  cr = Array(Int64).new(81_i64, -1_i64)
  cc = Array(Int64).new(81_i64, 0_i64)
  i = 0_i64
  min = 10_i64
  dir = 1_i64
  while true
    while ((i >= 0_i64) && (i < (81_i64 - hints)))
      if (dir == 1_i64)
        if (min > 1_i64)
          c = 0_i64
          while (c < 324_i64)
            if (sc[c] < min)
              min = sc[c]
              cc[i] = c
              if (min < 2_i64)
                break
              else
                RUBY_NIL
              end
            else
              RUBY_NIL
            end
            c = (c + 1_i64)
          end
        else
          RUBY_NIL
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        else
          RUBY_NIL
        end
      else
        RUBY_NIL
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
      else
        RUBY_NIL
      end
      r2 = (cr[i] + 1_i64)
      while ((r2 < 9_i64) && (sr[mr[c][r2].to_i64] != 0_i64))
r2 = (r2 + 1_i64)
      end
      if (r2 < 9_i64)
        _tup14_0, _tup14_1 = sd_update_forward(mr, mc, sr, sc, mr[c][r2].to_i64)
        min = _tup14_0.to_i64
        cc[(i + 1_i64)] = _tup14_1.to_i64
        cr[i] = r2
        dir = 1_i64
        i = (i + 1_i64)
      else
        cr[i] = -1_i64
        dir = -1_i64
        i = (i - 1_i64)
      end
    end
    if (i < 0_i64)
      break
    else
      RUBY_NIL
    end
    o = Array(Int64).new(81_i64, 0_i64)
    j = 0_i64
    while (j < 81_i64)
      o[j] = (s[j].ord.to_i64 - 48_i64)
      j = (j + 1_i64)
    end
    j = 0_i64
    while (j < i)
      r = mr[cc[j]][cr[j]].to_i64
      o[(r // 9_i64)] = ((r % 9_i64) + 1_i64)
      j = (j + 1_i64)
    end
    o.join
    i = (i - 1_i64)
    dir = -1_i64
  end
end
end


_tup15_0, _tup15_1 = sd_genmat
mr = _tup15_0
mc = _tup15_1
last = Ruby_Str_2
20_i64.times { Ruby_HARD20.as(RubyArray).each() { |line| last = sd_solve(mr, mc, line) } }
ruby_puts(last); RUBY_NIL

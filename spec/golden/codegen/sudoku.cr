require "../src/frozone_crystal"

RUBY_NIL    = RubyNil::INSTANCE
RUBY_TRUE   = RubyBool::TRUE
RUBY_FALSE  = RubyBool::FALSE
RUBY_GLOBALS = {} of String => RubyObject
Ruby_ARGV   = RubyArray.new(ARGV.map { |s| RubyString.new(s).as(RubyObject) })
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

def run_benchmark(*__anon_rest__ : RubyObject, &__anon_block__)
RUBY_NIL
end

def make_shareable(x : RubyObject)
  x
end

def sd_genmat
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
          end
          cc2 = (cc2 + 1_i64)
        end
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
  {min, min_c}
end

def sd_update_forward(mr : RubyObject, mc : RubyObject, sr : RubyObject, sc : RubyObject, r : RubyObject)
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
      if (((      (_iopw_r1 = sr; _iopw_i1 = rr; _iopw_r1[_iopw_i1] = (_iopw_r1[_iopw_i1] + RubyInteger.new(1_i64)))) == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        loc_p = mc[rr].as(RubyArray)
        cc2 = 0_i64
        while (cc2 < 4_i64)
          cc = loc_p[cc2].as(RubyInteger).to_i64
          if (((          (_iopw_r2 = sc; _iopw_i2 = cc; _iopw_r2[_iopw_i2] = (_iopw_r2[_iopw_i2] - RubyInteger.new(1_i64)))) < RubyInteger.new(min)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            min = sc[cc].to_i64
            min_c = cc
          end
          cc2 = (cc2 + 1_i64)
        end
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
  {min, min_c}
end

def sd_update_reverse(mr : Array(Array(Int64)), mc : Array(Array(Int64)), sr : Array(Int64), sc : Array(Int64), r : Int64)
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
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
end

def sd_update_reverse(mr : RubyObject, mc : RubyObject, sr : RubyObject, sc : RubyObject, r : RubyObject)
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
      if (((      (_iopw_r4 = sr; _iopw_i4 = rr; _iopw_r4[_iopw_i4] = (_iopw_r4[_iopw_i4] - RubyInteger.new(1_i64)))) == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        loc_p = mc[rr].as(RubyArray)
        (_iopw_r5 = sc; _iopw_i5 = loc_p[0_i64].as(RubyInteger).to_i64; _iopw_r5[_iopw_i5] = (_iopw_r5[_iopw_i5] + RubyInteger.new(1_i64)))
        (_iopw_r6 = sc; _iopw_i6 = loc_p[1_i64].as(RubyInteger).to_i64; _iopw_r6[_iopw_i6] = (_iopw_r6[_iopw_i6] + RubyInteger.new(1_i64)))
        (_iopw_r7 = sc; _iopw_i7 = loc_p[2_i64].as(RubyInteger).to_i64; _iopw_r7[_iopw_i7] = (_iopw_r7[_iopw_i7] + RubyInteger.new(1_i64)))
        (_iopw_r8 = sc; _iopw_i8 = loc_p[3_i64].as(RubyInteger).to_i64; _iopw_r8[_iopw_i8] = (_iopw_r8[_iopw_i8] + RubyInteger.new(1_i64)))
      end
      r2 = (r2 + 1_i64)
    end
    c2 = (c2 + 1_i64)
  end
end

def sd_solve(mr : Array(Array(Int64)), mc : Array(Array(Int64)), s : RubyObject)
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if     (_and9 = ((char >= RubyString.new("1")) ? RUBY_TRUE : RUBY_FALSE); _and9.truthy? ? (((char <= RubyString.new("9")) ? RUBY_TRUE : RUBY_FALSE)) : _and9).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
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
              end
            end
            c = (c + 1_i64)
          end
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        end
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
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
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if     (_and11 = ((char >= RubyString.new("1")) ? RUBY_TRUE : RUBY_FALSE); _and11.truthy? ? (((char <= RubyString.new("9")) ? RUBY_TRUE : RUBY_FALSE)) : _and11).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
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
              end
            end
            c = (c + 1_i64)
          end
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        end
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
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
RUBY_NIL
end
  def make_shareable(x : RubyObject)
  x
end
  def sd_genmat
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
  sr = Array(Int64).new(729_i64, 0_i64)
  sc = Array(Int64).new(324_i64, 9_i64)
  hints = 0_i64
  i = 0_i64
  while (i < 81_i64)
    char = s[i]
    a = if     (_and13 = ((char >= RubyString.new("1")) ? RUBY_TRUE : RUBY_FALSE); _and13.truthy? ? (((char <= RubyString.new("9")) ? RUBY_TRUE : RUBY_FALSE)) : _and13).truthy?
      (char.ord - RubyInteger.new(49_i64))
    else
      RubyInteger.new(-1_i64)
    end.to_i64
    if (a >= 0_i64)
      sd_update_forward(mr, mc, sr, sc, ((i * 9_i64) + a))
      hints = (hints + 1_i64)
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
              end
            end
            c = (c + 1_i64)
          end
        end
        if ((min == 0_i64) || (min == 10_i64))
          cr[i] = dir = -1_i64
          i = (i - 1_i64)
        end
      end
      c = cc[i]
      if ((dir == -1_i64) && (cr[i] >= 0_i64))
        sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]].to_i64)
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

Ruby_HARD20 = RubyArray.new([RubyString.new("..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9"), RubyString.new(".......12........3..23..4....18....5.6..7.8.......9.....85.....9...4.5..47...6..."), RubyString.new(".2..5.7..4..1....68....3...2....8..3.4..2.5.....6...1...2.9.....9......57.4...9.."), RubyString.new("........3..1..56...9..4..7......9.5.7.......8.5.4.2....8..2..9...35..1..6........"), RubyString.new("12.3....435....1....4........54..2..6...7.........8.9...31..5.......9.7.....6...8"), RubyString.new("1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1"), RubyString.new(".......39.....1..5..3.5.8....8.9...6.7...2...1..4.......9.8..5..2....6..4..7....."), RubyString.new("12.3.....4.....3....3.5......42..5......8...9.6...5.7...15..2......9..6......7..8"), RubyString.new("..3..6.8....1..2......7...4..9..8.6..3..4...1.7.2.....3....5.....5...6..98.....5."), RubyString.new("1.......9..67...2..8....4......75.3...5..2....6.3......9....8..6...4...1..25...6."), RubyString.new("..9...4...7.3...2.8...6...71..8....6....1..7.....56...3....5..1.4.....9...2...7.."), RubyString.new("....9..5..1.....3...23..7....45...7.8.....2.......64...9..1.....8..6......54....7"), RubyString.new("4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........"), RubyString.new("7.8...3.....2.1...5.........4.....263...8.......1...9..9.6....4....7.5..........."), RubyString.new("3.7.4...........918........4.....7.....16.......25..........38..9....5...2.6....."), RubyString.new("........8..3...4...9..2..6.....79.......612...6.5.2.7...8...5...1.....2.4.5.....3"), RubyString.new(".......1.4.........2...........5.4.7..8...3....1.9....3..4..2...5.1........8.6..."), RubyString.new(".......12....35......6...7.7.....3.....4..8..1...........12.....8.....4..5....6.."), RubyString.new("1.......2.9.4...5...6...7...5.3.4.......6........58.4...2...6...3...9.8.7.......1"), RubyString.new(".....1.2.3...4.5.....6....7..2.....1.8..9..3.4.....8..5....2....9..3.4....67.....")] of RubyObject)

_tup15_0, _tup15_1 = sd_genmat
mr = _tup15_0
mc = _tup15_1
last = RubyString.new("")
20_i64.times { Ruby_HARD20.each() { |line| last = sd_solve(mr, mc, line) } }
STDOUT.puts(last.to_s); RUBY_NIL

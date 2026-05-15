# Kw-UNSET dispatch test stub.
#
# Comprehensive coverage of UnsetSentinel-based kw-bearing dispatch:
#   - Optional kw only — default applies when caller omits
#   - Mixed required + optional kw — required must be present
#   - Positional defaults + kw — both can be UNSET
#   - Default expression using a prior bound kw
#   - send-dispatch through universal-sig trampoline
#   - Splat call site (universal-sig trampoline path)
#   - **kw_splat call site (universal-sig trampoline path)
#   - Multiple optional kws with non-contiguous binding
#   - super with kw_unset (parent has same shape)
#   - Recursive kw_unset call (self-dispatch via `using` un-hide)
#   - Default expression invoking another method on self
#
# Soundness note (not covered): missing required kw via `send` aborts
# the process (process-fatal) instead of raising ArgumentError —
# inherited from the v1 simple_kw_only? path. Test can't catch it
# without spawning a child; deferred until raise_missing_kw kernel fn.

class W
  def opt(a, x: 5)
    a * 10 + x
  end

  def mixed(a, must:, also: 7)
    a + must + also
  end

  def both(a, b = 2, x: 100)
    a + b + x
  end

  def chain(a, x: 3, y: x * 10)
    a * 1000 + x * 10 + y
  end

  def quad(a, x: 1, y: 2, z: 3)
    a * 1000 + x * 100 + y * 10 + z
  end

  def rec(n, acc: 0)
    return acc if n == 0
    rec(n - 1, acc: acc + n)
  end

  def helper
    42
  end

  def from_method(a, x: helper)
    a * 100 + x
  end
end

class Base
  def greet(name, suffix: "!")
    "hi-" + name + suffix
  end
end

class Greeter < Base
  def greet(name, suffix: "!")
    "[" + super + "]"
  end
end

class Logger
  def initialize
    @log = []
  end
  def tick(label)
    @log << label
    label
  end
  def log
    @log
  end
end

class Recorder
  def via(x: nil, y: nil, z: nil)
    0
  end
end

w = W.new

# Optional kw — default and explicit.
puts w.opt(1)             # 15
puts w.opt(1, x: 99)      # 109

# Mixed kw — required must be present.
puts w.mixed(1, must: 2)               # 10
puts w.mixed(1, must: 2, also: 3)      # 6

# Positional default + kw default.
puts w.both(1)                  # 103
puts w.both(1, 5)               # 106
puts w.both(1, x: 50)           # 53
puts w.both(1, 5, x: 50)        # 56

# Default-using-prior-kw.
puts w.chain(1)                 # 1060
puts w.chain(1, x: 4)           # 1080
puts w.chain(1, x: 4, y: 99)    # 1139

# send-dispatch through universal trampoline.
puts w.send(:opt, 2)                   # 25
puts w.send(:opt, 2, x: 7)             # 27
puts w.send(:mixed, 2, must: 3)        # 12
puts w.send(:both, 2, x: 8)            # 12

# Splat call site (universal trampoline).
sp = [3]
puts w.opt(*sp)             # 35
puts w.opt(*sp, x: 7)       # 37

# **kw_splat call site.
kws = { x: 9 }
puts w.opt(1, **kws)        # 19

# Multiple opt kws — non-contiguous binding.
puts w.quad(1)                       # 1123
puts w.quad(1, y: 9)                 # 1193
puts w.quad(1, z: 8, x: 5)           # 1528
puts w.quad(1, x: 5, y: 9, z: 8)     # 1598

# Super with kw_unset.
puts Greeter.new.greet("alice")               # [hi-alice!]
puts Greeter.new.greet("alice", suffix: "?")  # [hi-alice?]

# Recursive self-dispatch through `using` un-hide.
puts w.rec(5)               # 15

# Default expression invoking another method.
puts w.from_method(3)            # 342
puts w.from_method(3, x: 99)     # 399

# Missing required kw — direct + via send. Both raise ArgumentError.
begin; w.mixed(1); rescue ArgumentError => e; puts e.message; end
begin; w.send(:mixed, 1); rescue ArgumentError => e; puts e.message; end

# Unknown kw — direct + via send. Both raise ArgumentError.
begin; w.opt(1, bogus: 99); rescue ArgumentError => e; puts e.message; end
begin; w.send(:opt, 1, bogus: 99); rescue ArgumentError => e; puts e.message; end

# kw value evaluation order — MRI evaluates kw value expressions in
# source order regardless of slot/alpha order. Logger captures side-
# effect ordering; expected [:Z, :X, :Y] (call-site source order).
logger = Logger.new
Recorder.new.via(z: logger.tick(:Z), x: logger.tick(:X), y: logger.tick(:Y))
puts logger.log.inspect

# Kw-UNSET dispatch test stub.
#
# Exercises the UnsetSentinel lowering for kw-bearing methods —
# slot signature is required pos → opt pos → kws alphabetical, with
# absent optionals filled by UNSET at the call site and default-filled
# in the callee body.
#
# Coverage:
#   - Optional kw only — default applies when caller omits
#   - Mixed required + optional kw — caller supplies some, defaults fill rest
#   - Positional defaults + kw — both can be UNSET
#   - Default expression using a prior kw — order matters
#   - send-dispatch through universal-sig trampoline

class W
  # Optional kw only — default applies when caller omits.
  def opt(a, x: 5)
    a * 10 + x
  end

  # Mixed required + optional kw.
  def mixed(a, must:, also: 7)
    a + must + also
  end

  # Positional default + kw default.
  def both(a, b = 2, x: 100)
    a + b + x
  end

  # Default that uses a prior bound kw.
  def chain(a, x: 3, y: x * 10)
    a * 1000 + x * 10 + y
  end
end

w = W.new

# Optional kw — default and explicit.
puts w.opt(1)             # 15
puts w.opt(1, x: 99)      # 109

# Mixed kw — required must be present.
puts w.mixed(1, must: 2)               # 10  (1+2+7)
puts w.mixed(1, must: 2, also: 3)      # 6   (1+2+3)

# Positional default + kw default — both absent.
puts w.both(1)                  # 103
puts w.both(1, 5)               # 106
puts w.both(1, x: 50)           # 53
puts w.both(1, 5, x: 50)        # 56

# Default-using-prior-kw.
puts w.chain(1)                 # 1000 + 30 + 30 = 1060
puts w.chain(1, x: 4)           # 1000 + 40 + 40 = 1080
puts w.chain(1, x: 4, y: 99)    # 1000 + 40 + 99 = 1139

# send-dispatch through universal trampoline.
puts w.send(:opt, 2)                   # 25
puts w.send(:opt, 2, x: 7)             # 27
puts w.send(:mixed, 2, must: 3)        # 12
puts w.send(:both, 2, x: 8)            # 12

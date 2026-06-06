# Cross-arity adapter semantics for Proc0/Proc1/Proc2 (#167).
#
# When a block is statically specialized to ProcN, but the yield site
# invokes callM (different arity), the adapter applies Ruby's Proc-
# flavor laxness rules:
#   - extra args dropped
#   - missing args → nil
#   - procarg0 auto-splat: yield(arr) into 2-param block destructures
#
# These tests force cross-arity invocation by passing one block to
# yield sites with different arity. The block-creation site picks the
# ProcN subclass; the yield site picks callM via static arg count.

# All method defs at load phase — closed-world AOT requires it.
def yield_zero
  yield
end

def yield_one(v)
  yield v
end

def yield_two(a, b)
  yield a, b
end

def yield_kw
  yield 1, foo: 99
end

def yield_capture
  yield 10
end

# --- Proc0 receiving call1 / call2: extras dropped -----------------

r1 = yield_one(99) { 42 }
raise "Proc0.call1: expected 42, got #{r1.inspect}" unless r1 == 42

r2 = yield_two(99, 100) { 43 }
raise "Proc0.call2: expected 43, got #{r2.inspect}" unless r2 == 43

# --- Proc1 receiving call0 / call2: missing → nil, extra dropped --

r3 = yield_zero { |x| x.nil? ? :got_nil : :got_value }
raise "Proc1.call0: expected :got_nil, got #{r3.inspect}" unless r3 == :got_nil

r4 = yield_two(7, 99) { |x| x }
raise "Proc1.call2 (extra dropped): expected 7, got #{r4.inspect}" unless r4 == 7

# --- Proc2 procarg0 auto-splat -----------------------------------

r5 = yield_one([10, 20]) { |x, y| [x, y] }
raise "Proc2.call1 procarg0: expected [10, 20], got #{r5.inspect}" unless r5 == [10, 20]

r6 = yield_one(99) { |x, y| [x, y] }
raise "Proc2.call1 (non-Array): expected [99, nil], got #{r6.inspect}" unless r6 == [99, nil]

r7 = yield_zero { |x, y| [x, y] }
raise "Proc2.call0: expected [nil, nil], got #{r7.inspect}" unless r7 == [nil, nil]

# --- Universal Proc fallback: kwargs path bypasses callN ---------

r8 = yield_kw { |x, foo:| [x, foo] }
raise "kw fallback: expected [1, 99], got #{r8.inspect}" unless r8 == [1, 99]

# --- Captured param fallback: inner block captures outer's param --

r9 = yield_capture do |n|
  inner = lambda { n * 2 }   # captures n
  inner.call
end
raise "capture fallback: expected 20, got #{r9.inspect}" unless r9 == 20

puts "block_specialization_test: OK"

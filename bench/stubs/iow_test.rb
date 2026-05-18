$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# All method defs at load phase (closed-world validator requires this).
def tick(arr, i)
  arr[i] += 1
end

# IndexOperatorWrite (`s[i] -= 1` and friends) regression test.
# Bug history: IOW lowering hard-coded the universal-sig call convention
# for the operator (`op_minus(new Array({val}))`). Under NA, Integer's
# op_minus has only an NA-sig slot (`op_minus(BasicObject* other)`)
# which `static_cast<Integer*>(other)->raw_`s its arg — so the Array
# got reinterpreted as an Integer and `raw_` read garbage. Surface:
# fannkuchredux silently produced wrong results under FROZONE_NATURAL_ARGS=1.
# Fix: IOW now checks NA eligibility per-op and emits direct or
# Array-wrapped arg accordingly (mirrors from_method_call).

# 1. Integer subtract on Array element — the fannkuch trigger.
s = [0, 1, 2, 3]
s[3] -= 1
s[2] -= 1
puts s.inspect              # [0, 1, 1, 2]

# 2. All five arithmetic ops on Array elements (Integer receivers).
a = [10, 20, 30, 40, 50]
a[0] += 5
a[1] -= 3
a[2] *= 2
a[3] /= 4
a[4] %= 7
puts a.inspect              # [15, 17, 60, 10, 1]

# 3. Bitwise + shift ops.
b = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
b[0] &= 0x0F
b[1] |= 0x100
b[2] ^= 0x55
b[3] <<= 2
b[4] >>= 3
puts b.inspect              # [15, 511, 170, 1020, 31]

# 4. String concat on Array element (op_lshift on String).
ss = ["hello"]
ss[0] += " world"
puts ss.inspect             # ["hello world"]

# 5. Inside a method body (NA-eligible shape).
counts = [10, 20, 30]
tick(counts, 0)
tick(counts, 1)
tick(counts, 1)
tick(counts, 2)
tick(counts, 2)
tick(counts, 2)
puts counts.inspect         # [11, 22, 33]

# 6. Hash[key] -= 1 — exercises Hash#op_aref / op_aset. (Box-first
# Hash#inspect doesn't preserve insertion order — sort the entries
# for a stable assertion.)
h = { a: 10, b: 20 }
h[:a] -= 3
h[:b] *= 2
puts [h[:a], h[:b]].inspect # [7, 40]

# 7. Chained — `s[i][j] += 1` (nested op_aref on result of op_aref).
m = [[1, 2], [3, 4]]
m[0][1] += 10
m[1][0] -= 1
puts m.inspect              # [[1, 12], [2, 4]]

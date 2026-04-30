# Strict Array#[] semantics under box-first: single-Integer index,
# 2-arg slice (start, len), Range slice (incl. beginless / endless),
# and the error paths (ArgumentError on 0/3+ args, TypeError on
# non-Integer-coercible index).

a = [10, 20, 30, 40, 50]

# Single-Integer
puts a[0]
puts a[2]
puts a[-1]
puts a[10].inspect       # nil
puts a[-10].inspect      # nil

# 2-arg slice
puts a[1, 2].join(",")   # 20,30
puts a[-2, 2].join(",")  # 40,50
puts a[3, 10].join(",")  # 40,50 (clamps)
puts a[10, 2].inspect    # nil (start > sz)

# Range slice
puts a[1..3].join(",")   # 20,30,40
puts a[1...3].join(",")  # 20,30
puts a[1..-2].join(",")  # 20,30,40
puts a[1..].join(",")    # 20,30,40,50  (endless)
puts a[..2].join(",")    # 10,20,30     (beginless)
puts a[nil..nil].join(",") # 10,20,30,40,50  (explicit unbounded)

# Error paths
begin; a[1, 2, 3]; rescue ArgumentError; puts "ArgumentError 3-arg"; end
begin; a["x"]; rescue TypeError; puts "TypeError non-Integer"; end

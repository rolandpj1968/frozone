# Array#push variadic — zero, single, multi-arg, plus the
# "no-kwarg method takes the keyword form positionally" behaviour
# that closed-world routes via kwargs absorption.

a = []
a.push                # no-op
puts a.size           # 0

a.push(1)
a.push(2, 3, 4)
puts a.size           # 4
puts a.last           # 4

a.push(name: "foo")   # kwargs absorbed as positional Hash
puts a.size           # 5
puts a.last[:name]    # foo

# Multi-arg + trailing kwargs
a.push(:x, :y, key: 1)
puts a.size           # 8
puts a[-1][:key]      # 1
puts a[-2]            # y

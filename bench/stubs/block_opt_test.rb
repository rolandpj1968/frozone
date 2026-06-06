# Block optional positional params + block_param (#166).
#
# Block-flavored (Proc) optional positional semantics: when __blkargs__
# has fewer values than required+optional, the missing optionals get
# their default expressions. Blocks are lax on positional arity in
# general — extra args dropped, missing required → nil. Optionals
# slot between required and rest.

def yield2(a, b); yield a, b; end
def yield1(a); yield a; end
def yield0; yield; end
def yield3(a, b, c); yield a, b, c; end

# 1. All args provided — defaults not used.
result1 = yield2(10, 20) { |a, b = 99| [a, b] }
raise "all provided: expected [10, 20], got #{result1.inspect}" unless result1 == [10, 20]

# 2. Optional defaults to expression.
result2 = yield1(10) { |a, b = 99| [a, b] }
raise "opt default: expected [10, 99], got #{result2.inspect}" unless result2 == [10, 99]

# 3. Default expression that references an earlier param.
result3 = yield1(10) { |a, b = (a + 5)| [a, b] }
raise "opt default expr: expected [10, 15], got #{result3.inspect}" unless result3 == [10, 15]

# 4. Multiple optional params.
result4 = yield1(5) { |a, b = 10, c = 20| [a, b, c] }
raise "multi opt: expected [5, 10, 20], got #{result4.inspect}" unless result4 == [5, 10, 20]

# 5. Optional + rest.
result5 = yield3(1, 2, 3) { |a, b = 99, *rest| [a, b, rest] }
raise "opt + rest: expected [1, 2, [3]], got #{result5.inspect}" unless result5 == [1, 2, [3]]

# 6. Optional + rest with only required arg.
result6 = yield1(1) { |a, b = 99, *rest| [a, b, rest] }
raise "opt+rest minimal: expected [1, 99, []], got #{result6.inspect}" unless result6 == [1, 99, []]

# 7. Required + optional + post.
result7 = yield3(1, 2, 3) { |a, b = 99, c| [a, b, c] }
raise "req+opt+post: expected [1, 2, 3], got #{result7.inspect}" unless result7 == [1, 2, 3]

# 8. Required + optional + post when optional missing (Ruby fills post first).
result8 = yield2(1, 3) { |a, b = 99, c| [a, b, c] }
raise "req+opt+post missing opt: expected [1, 99, 3], got #{result8.inspect}" unless result8 == [1, 99, 3]

puts "block_opt_test: OK"

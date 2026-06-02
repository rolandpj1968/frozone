# Comprehensive Hash semantics probe.
# Output must be byte-identical across:
#   1. MRI Frozone:    bundle exec bin/frozone bench/stubs/hash_semantics.rb
#   2. Box-first app:  compile + run
#   3. Self-host:      bin/frozone_box bench/stubs/hash_semantics.rb
#
# Each line prints one observation as "<label> <value>" so diffs pin the
# offending case directly. No rescue, no exception paths — keep this focused
# on Hash insert/lookup/iter/eq semantics for Integer, String, Symbol, Float.

# --- empty hash ---
h = {}
puts "empty size #{h.size}"
puts "empty empty? #{h.empty?}"
puts "empty lookup #{h[:none].inspect}"
puts "empty include? #{h.include?(:x)}"
puts "empty keys #{h.keys.inspect}"
puts "empty values #{h.values.inspect}"

# --- Symbol keys ---
h = {}
h[:a] = 1
h[:b] = 2
h[:c] = 3
puts "sym size #{h.size}"
puts "sym [:a] #{h[:a]}"
puts "sym [:b] #{h[:b]}"
puts "sym [:c] #{h[:c]}"
puts "sym [:miss] #{h[:miss].inspect}"
puts "sym include? a #{h.include?(:a)}"
puts "sym include? miss #{h.include?(:miss)}"
puts "sym key? a #{h.key?(:a)}"
puts "sym has_key? a #{h.has_key?(:a)}"
puts "sym member? a #{h.member?(:a)}"
puts "sym value? 1 #{h.value?(1)}"
puts "sym value? 99 #{h.value?(99)}"
h[:a] = 10
puts "sym update [:a] #{h[:a]}"
puts "sym update size #{h.size}"
h.delete(:a)
puts "sym delete size #{h.size}"
puts "sym delete [:a] #{h[:a].inspect}"
puts "sym delete include? #{h.include?(:a)}"

# --- Integer keys ---
h = {}
h[1] = :one
h[2] = :two
h[1000000] = :million
h[-5] = :neg
puts "int size #{h.size}"
puts "int [1] #{h[1]}"
puts "int [2] #{h[2]}"
puts "int [1000000] #{h[1000000]}"
puts "int [-5] #{h[-5]}"
puts "int [99] #{h[99].inspect}"
puts "int include? 1 #{h.include?(1)}"
puts "int include? 99 #{h.include?(99)}"
h[1] = :ONE
puts "int update [1] #{h[1]}"
puts "int update size #{h.size}"
h.delete(1)
puts "int delete size #{h.size}"
puts "int delete [1] #{h[1].inspect}"

# --- String keys, same instance ---
k = "alpha"
h = {}
h[k] = 1
puts "str same lookup #{h[k]}"
puts "str same include? #{h.include?(k)}"
puts "str same size #{h.size}"

# --- String keys, literal at insert and lookup ---
h = {}
h["beta"] = 2
puts "str lit lookup #{h["beta"]}"
puts "str lit include? #{h.include?("beta")}"
puts "str lit size #{h.size}"

# --- String keys, distinct instances, same content (regression for #149) ---
a = "gamma"
b = "gamma"
puts "str distinct == #{a == b}"
puts "str distinct equal? #{a.equal?(b)}"
h = {}
h[a] = 1
puts "str distinct lookup via b #{h[b]}"
h[b] = 99
puts "str distinct after-update size #{h.size}"
puts "str distinct value via a #{h[a]}"
puts "str distinct value via b #{h[b]}"

# --- String key delete ---
h = {}
h["x"] = 1
h.delete("x")
puts "str delete size #{h.size}"
puts "str delete lookup #{h["x"].inspect}"

# --- String keys, multi-byte / UTF-8 ---
h = {}
h["héllo"] = 1
h["world"] = 2
puts "str utf8 héllo #{h["héllo"]}"
puts "str utf8 world #{h["world"]}"
puts "str utf8 size #{h.size}"

# --- Float keys ---
h = {}
h[0.5] = :half
h[1.5] = :one_half
h[-2.25] = :neg
puts "float [0.5] #{h[0.5]}"
puts "float [1.5] #{h[1.5]}"
puts "float [-2.25] #{h[-2.25]}"
puts "float size #{h.size}"
puts "float include? 0.5 #{h.include?(0.5)}"
puts "float include? 9.9 #{h.include?(9.9)}"

# --- nil / true / false keys ---
h = {}
h[nil] = :nil_val
h[true] = :true_val
h[false] = :false_val
puts "nil-key #{h[nil]}"
puts "true-key #{h[true]}"
puts "false-key #{h[false]}"
puts "special size #{h.size}"

# --- mixed-type keys ---
h = {}
h[:sym] = 1
h["str"] = 2
h[42] = 3
h[0.5] = 4
puts "mixed size #{h.size}"
puts "mixed sym #{h[:sym]}"
puts "mixed str #{h["str"]}"
puts "mixed int #{h[42]}"
puts "mixed float #{h[0.5]}"

# --- equality ---
puts "== empty #{ {} == {} }"
puts "== same content #{ {a: 1, b: 2} == {a: 1, b: 2} }"
puts "== order-indep #{ {a: 1, b: 2} == {b: 2, a: 1} }"
puts "== diff values #{ {a: 1} == {a: 2} }"
puts "== diff keys #{ {a: 1} == {b: 1} }"
puts "== diff sizes #{ {a: 1} == {a: 1, b: 2} }"
puts "== str-keys #{ {"a" => 1} == {"a" => 1} }"
puts "== int-keys #{ {1 => :x, 2 => :y} == {2 => :y, 1 => :x} }"

# --- each iteration (insertion order) ---
h = {}
h[:x] = 1
h[:y] = 2
h[:z] = 3
seen_k = []
seen_v = []
h.each { |k, v| seen_k << k; seen_v << v }
puts "each keys #{seen_k.inspect}"
puts "each values #{seen_v.inspect}"

# --- each_key / each_value / each_pair ---
h = {a: 10, b: 20}
ek = []; h.each_key { |k| ek << k }
ev = []; h.each_value { |v| ev << v }
puts "each_key #{ek.inspect}"
puts "each_value #{ev.inspect}"

# --- keys / values / to_a ---
h = {}
h[:a] = 1
h[:b] = 2
puts "keys #{h.keys.inspect}"
puts "values #{h.values.inspect}"
puts "to_a #{h.to_a.inspect}"

# --- dup independence ---
h = {a: 1}
d = h.dup
d[:b] = 2
puts "dup orig size #{h.size}"
puts "dup copy size #{d.size}"
puts "dup copy b #{d[:b]}"

# --- merge ---
m = {a: 1}.merge(b: 2)
puts "merge size #{m.size}"
puts "merge a #{m[:a]}"
puts "merge b #{m[:b]}"
m2 = {a: 1}.merge(a: 99)
puts "merge override #{m2[:a]}"

# --- fetch ---
h = {a: 1}
puts "fetch present #{h.fetch(:a)}"
puts "fetch default #{h.fetch(:miss, :fallback)}"

# Hash.new(default) deferred — hash_new in box-first IMPLEMENT_QUEUE (#140).

puts "DONE"

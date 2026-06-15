$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/iile_parity_lib'

# Exercises every Ruby control-flow shape that the form-switch helpers
# emit differently between IILE and stmt_expr modes. The same program
# built under both modes MUST produce identical stdout — that's the
# runtime parity assertion.
#
# Method defs live in bench/benchmarks/iile_parity_lib.rb (load-phase
# requirement of closed-world AOT). The execute body below just
# invokes them and prints results.

# --- block_expr: && / || short-circuit semantics ---

puts "and_nil:   #{(nil && 99).inspect}"
puts "and_true:  #{(1 && 2)}"
puts "or_nil:    #{(nil || 42)}"
puts "or_true:   #{(5 || 99)}"

# --- block_expr: hash & array literal builders with splat ---

h_splat = { a: 1, **{b: 2, c: 3} }
puts "hash_splat: #{h_splat.inspect}"
a_splat = [1, *[2, 3], 4]
puts "array_splat: #{a_splat.inspect}"

# --- block_expr: range literal ---

r = 1..3
puts "range: #{r.to_a.inspect}"

# --- block_expr: op-aset ---

arr = [10, 20, 30]
arr[1] = arr[1] + 5
puts "op_aset: #{arr.inspect}"

# --- staged_block_expr: ||= / &&= short-circuit (RHS must NOT run
# when LHS is the short-circuit value) ---

side_effects = []
trace = ->(x) { side_effects << x; x }

x = 1
x &&= trace.call(2)            # truthy → evaluates → 2 added
y = nil
y &&= trace.call(:should_not)  # nil → NOT evaluated
z = nil
z ||= trace.call(3)            # nil → evaluates → 3 added
w = 4
w ||= trace.call(:should_not)  # truthy → NOT evaluated

puts "and_eq_x: #{x}"
puts "and_eq_y: #{y.inspect}"
puts "or_eq_z:  #{z}"
puts "or_eq_w:  #{w}"
puts "side_effects: #{side_effects.inspect}"  # MUST be [2, 3]

# --- staged_block_expr on hash[k] ||= ---

h = {}
h[:a] ||= :first   # missing → evaluates RHS
h[:a] ||= :second  # present → does NOT evaluate
puts "hash_or_eq: #{h.inspect}"  # {:a=>:first}

# --- block_expr: safe-nav &. on nil receiver ---

nil_recv = nil
puts "safe_nav_nil:  #{nil_recv&.upcase.inspect}"
real_recv = "hello"
puts "safe_nav_real: #{real_recv&.upcase}"

# --- body_as_lambda_call: case/when returning value ---

puts "case_1:     #{parity_case_value(1)}"
puts "case_2:     #{parity_case_value(2)}"
puts "case_other: #{parity_case_value(3)}"

# --- body_as_lambda_call + Ast::Return: case-arm with explicit return ---

puts "case_ret_1:     #{parity_case_return(1)}"
puts "case_ret_2:     #{parity_case_return(2)}"
puts "case_ret_other: #{parity_case_return(3)}"

# --- from_if_as_stmt_expr: if/else with internal return ---

puts "if_ret_pos: #{parity_if_return(5)}"
puts "if_ret_neg: #{parity_if_return(-1)}"

# --- from_rescue_stmt_expr: rescue value yield ---

puts "rescue_no:  #{parity_rescue_value(false)}"
puts "rescue_yes: #{parity_rescue_value(true)}"

# --- from_rescue_stmt_expr: ensure runs on both paths ---

puts "ensure_no:  #{parity_ensure_runs(false)}"
puts "ensure_yes: #{parity_ensure_runs(true)}"

# --- from_rescue + Ast::Return inside rescue arm ---

puts "return_from_rescue: #{parity_return_from_rescue}"

# --- try_catch_expr: break inside iterator becomes the call's value ---

found = [10, 20, 30, 40].each do |v|
  break v if v > 25
end
puts "break_value: #{found}"

# --- throw_expr inside a ternary ---

puts "raise_expr_ok: #{parity_raise_via_expr(true)}"
puts "raise_caught:  #{parity_raise_caught}"

puts "ALL OK"

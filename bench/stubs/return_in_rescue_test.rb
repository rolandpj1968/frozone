# Regression coverage for `return` inside the IIFE-wrapped constructs
# emitted by cpp_box (begin/rescue/else/ensure). Pre-fix, a bare C++
# `return val` inside a nested lambda would only escape that lambda;
# the method body would fall through to whatever followed the
# begin/end. Post-fix, `return` in any rescue-IIFE position throws a
# frame-targeted ReturnException so the method exits correctly.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# ---- 1. Bare `return val` in begin/rescue body (with rescue clause) ----
def rescue_body_return(x)
  begin
    return :early if x > 0
    :nope
  rescue StandardError
    :rescued
  end
  :fallthrough
end

# ---- 2. `return val if cond` — most common Ruby idiom ----
# This is the exact shape that hit __rational_coerce__'s first
# `return val if val.is_a?(Integer)` line.
def conditional_return(val)
  begin
    return :was_int if val.is_a?(Integer)
    return :was_str if val.is_a?(String)
    :other
  rescue StandardError
    :impossible
  end
end

# ---- 3. Multiple `return` guards chained in begin body ----
def guard_chain(n)
  begin
    return :zero    if n == 0
    return :one     if n == 1
    return :two     if n == 2
    :many
  rescue StandardError
    :unreached
  end
end

# ---- 4. `return val` from inside the rescue clause ----
def return_from_rescue
  begin
    raise ArgumentError, "boom"
  rescue ArgumentError
    return :from_rescue
  end
  :fallthrough
end

# ---- 5. `return val` from inside the else clause ----
def return_from_else
  begin
    :body_value
  rescue StandardError
    :unused
  else
    return :from_else
  end
  :fallthrough
end

# ---- 6. `return` inside if-inside-begin-body ----
def nested_if_return(n)
  begin
    if n > 0
      return :positive
    else
      return :nonpos
    end
  rescue StandardError
    :unreached
  end
end

# ---- 7. `return` inside case-inside-begin-body ----
def nested_case_return(n)
  begin
    case n
    when 0 then return :zero
    when 1 then return :one
    else        return :many
    end
  rescue StandardError
    :unreached
  end
end

# ---- 8. Multi-layer: begin/rescue nested inside begin/rescue ----
def nested_rescue(x)
  begin
    begin
      return :inner if x == 1
    rescue StandardError
      return :inner_rescue
    end
    return :outer if x == 2
    :outer_fallthrough
  rescue StandardError
    :outer_rescue
  end
end

# ---- 9. begin/rescue/ensure with `return` — ensure must still run ----
$ensure_ran = 0
def return_with_ensure(x)
  begin
    return :early if x > 0
    :body
  ensure
    $ensure_ran += 1
  end
end

# ---- 10. `return val if cond` in begin/rescue/ensure (the full shape) ----
def full_shape(x)
  begin
    return :one if x == 1
    return :two if x == 2
    :neither
  rescue StandardError
    :rescued
  else
    # Ruby semantics: else runs only when body completes without
    # exception AND without `return`. Since we may have returned above,
    # this only runs in the :neither / no-early-return path.
    :else_branch
  end
end

# ---- 11. Implicit (non-early) return path — make sure we don't break
#         the normal case where the begin/rescue value IS the method
#         return value.
def implicit_return(x)
  begin
    x * 2
  rescue StandardError
    -1
  end
end

# ---- 12. `return` inside if-as-expression (from_if_as_lambda IIFE) ----
# The if-expression value is assigned to a local; one branch returns
# early. Before the fix, `return :positive` would only escape the
# if's IIFE — the method body would then fall through and use the
# stale local value of x.
def return_in_if_expr(n)
  x = if n > 0
        return :positive
      else
        :nonpos
      end
  x
end

# ---- 13. `return val if cond` nested inside if-as-expression branch ----
# `return val if cond` inside a branch — Sequence with Ast::If
# containing Ast::Return nested in the IIFE.
def mixed_if_return(n)
  result = if n.is_a?(Integer)
             return :got_int if n > 100
             n * 2
           else
             :not_int
           end
  "result=#{result}"
end

# ---- 14. `return` inside case-as-expression (from_case IIFE) ----
# case-as-expression: one arm returns early, others produce values.
def return_in_case_expr(n)
  y = case n
      when 0 then return :zero
      when 1 then :one
      else        :many
      end
  y
end

# ---- Execute ----
puts rescue_body_return(1)        # early
puts rescue_body_return(-1)       # fallthrough (begin returns :nope, but method continues to final :fallthrough)

puts conditional_return(42)       # was_int
puts conditional_return("hi")     # was_str
puts conditional_return(:sym)     # other

puts guard_chain(0)               # zero
puts guard_chain(1)               # one
puts guard_chain(2)               # two
puts guard_chain(5)               # many

puts return_from_rescue           # from_rescue
puts return_from_else             # from_else

puts nested_if_return(3)          # positive
puts nested_if_return(-3)         # nonpos

puts nested_case_return(0)        # zero
puts nested_case_return(1)        # one
puts nested_case_return(7)        # many

puts nested_rescue(1)             # inner
puts nested_rescue(2)             # outer
puts nested_rescue(3)             # outer_fallthrough

puts return_with_ensure(5)        # early
puts return_with_ensure(-1)       # body
puts $ensure_ran                  # 2

puts full_shape(1)                # one
puts full_shape(2)                # two
puts full_shape(99)               # else_branch

puts implicit_return(21)          # 42

puts return_in_if_expr(5)         # positive
puts return_in_if_expr(-5)        # nonpos

puts mixed_if_return(200)         # got_int
puts mixed_if_return(50)          # result=100
puts mixed_if_return("hi")        # result=not_int

puts return_in_case_expr(0)       # zero
puts return_in_case_expr(1)       # one
puts return_in_case_expr(99)      # many

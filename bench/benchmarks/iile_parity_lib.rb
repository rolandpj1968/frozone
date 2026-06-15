# Helper methods for bench/stubs/iile_parity.rb. Method definitions
# must be at load time (closed-world rule), so we hoist them here
# and require_relative from the stub's execute body.

def parity_case_value(x)
  case x
  when 1 then "one"
  when 2 then "two"
  else "other"
  end
end

def parity_case_return(x)
  case x
  when 1 then return "early"
  when 2 then "two"
  else "other"
  end
end

def parity_if_return(x)
  if x > 0
    return "positive"
  else
    "non_positive"
  end
end

def parity_rescue_value(should_raise)
  begin
    raise "oops" if should_raise
    "no_raise"
  rescue => e
    "rescued: #{e.message}"
  end
end

def parity_ensure_runs(should_raise)
  state = []
  begin
    state << "body"
    raise "boom" if should_raise
    "ok"
  rescue
    state << "rescue"
    "rescued"
  ensure
    state << "ensure"
  end
  state.join("|")
end

def parity_return_from_rescue
  begin
    raise "x"
  rescue
    return "rescue_returned"
  end
end

def parity_raise_via_expr(cond)
  cond ? "ok" : raise("not ok")
end

def parity_raise_caught
  begin
    parity_raise_via_expr(false)
  rescue => e
    e.message
  end
end

# Visibility regression: explicit-other call to a private method must
# raise NoMethodError even when the arg expression is itself a method
# call that touches g_caller_self.
#
# The bug shape: codegen wraps the outer call as
#     (g_caller_self = this, b->m_priv_target(arg_expr))
# If arg_expr is itself `(g_caller_self = nullptr, this->m_helper())`
# — because `helper` is P4 (mixed-visibility) and needs its own wrap —
# the inner comma evaluates AFTER the outer set, clobbering it.
# By the time priv_target's body prologue snapshots g_caller_self,
# the value is nullptr (from the inner wrap), not `this` (from the
# outer one). The prologue treats the call as "privileged" and silently
# allows the private dispatch.
#
# Both `priv_target` and `helper_p4` must end up as P4 (mixed-visibility)
# in the closed-world survey. P4 requires the survey to SEE both a
# private def and a public def of the same name. We force this by
# touching both variant classes so neither gets pruned.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# ---- Force `priv_target` to be P4 (mixed-visibility) ----
class HasPrivPriv
  def priv_target(x)
    "should not be reached: #{x.inspect}"
  end
  private :priv_target
end

class HasPublicPrivVariant
  def priv_target(x)
    # Public on this class — forces the name into the P4 bucket so
    # the callee's body decides visibility, not the static call site.
    "public variant: #{x}"
  end
end

# ---- Force `helper_p4` to be P4 (mixed-visibility) ----
class HasPrivHelper
  def helper_p4
    "private helper variant"
  end
  private :helper_p4

  # Public method that internally exercises the private helper — keeps
  # HasPrivHelper's private helper_p4 reachable in the closed world.
  def touch_private = helper_p4
end

class Caller
  # Public on Caller — implicit-recv calls to helper_p4 from inside
  # Caller#trigger* are allowed. P4 status forces the codegen to wrap
  # each call with `(g_caller_self = nullptr, ...)`.
  def helper_p4
    99
  end

  # Sanity check 1: bare explicit-other call to a private method.
  # No args, so nothing can clobber. MUST raise.
  def trigger_bare
    HasPrivPriv.new.priv_target(0)
  end

  # The bug-tickling shape. Arg is `helper_p4` — a P4 implicit-recv
  # call whose comma-wrap can clobber the outer g_caller_self set.
  def trigger_clobber
    HasPrivPriv.new.priv_target(helper_p4)
  end

  # Variant: arg is `self.helper_p4` (explicit-self). Same P4 wrap
  # gets emitted but with `g_caller_self = nullptr` (self counts as
  # privileged), still clobbering.
  def trigger_clobber_explicit_self
    HasPrivPriv.new.priv_target(self.helper_p4)
  end
end

# ---- Run + report ----
def report(label, &block)
  begin
    result = block.call
    puts "#{label}: BUG — call allowed, returned #{result.inspect}"
  rescue NoMethodError => e
    puts "#{label}: OK — NoMethodError raised"
  end
end

# Touch the variant classes so they survive closed-world pruning.
puts "p4-touch-1: #{HasPublicPrivVariant.new.priv_target("hi")}"
puts "p4-touch-2: #{HasPrivHelper.new.touch_private}"

c = Caller.new

report("bare")                  { c.trigger_bare }
report("clobber_implicit")      { c.trigger_clobber }
report("clobber_explicit_self") { c.trigger_clobber_explicit_self }

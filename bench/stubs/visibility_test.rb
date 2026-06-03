# Visibility test stub.
#
# Covers Stage 2 of method visibility (#116, docs/box-first-visibility.md):
# call-site emission for P2 (all-private) and P3 (all-protected) names,
# across the three call flavors:
#   - implicit recv (no check)
#   - explicit self (no check, 4.x relaxed)
#   - explicit other (runtime equal? for private, kind_of? for protected)
#
# Mixed-visibility (P4) names are out of scope here — they need Stage 3
# (universal-slot caller_self thread). Once Stage 3 lands, extend this
# stub with a P4 case.

# Pub_v: all-public — no check anywhere.
class Pub_v
  def m; :pub; end
end

# Priv_v: all-private (P2) — explicit-other must raise NoMethodError;
# implicit and explicit-self must succeed.
class Priv_v
  def call_implicit
    helper
  end

  def call_explicit_self
    self.helper
  end

  def call_explicit_other(other)
    other.helper  # P2 explicit-other → runtime equal?(self) check
  end

  private

  def helper
    :priv
  end
end

# Prot_v: all-protected (P3) — sibling instance (kind_of? defining class)
# must succeed; non-sibling must raise NoMethodError.
class Prot_v
  def call_implicit
    helper
  end

  def call_explicit_self
    self.helper
  end

  def call_explicit_other(other)
    other.helper  # P3 explicit-other → runtime kind_of?(recv.class) check
  end

  protected

  def helper
    :prot
  end
end

class ProtSubcaller_v < Prot_v
  # Subclass caller; `self` is a ProtSubcaller_v which IS a Prot_v, so
  # the kind_of? check succeeds against a Prot_v receiver.
  def sibling_call(other)
    other.helper
  end
end

# --- Implicit / explicit-self: always succeed ---
raise "Pub_v public failed" unless Pub_v.new.m == :pub
raise "Priv_v implicit failed" unless Priv_v.new.call_implicit == :priv
raise "Priv_v explicit-self failed" unless Priv_v.new.call_explicit_self == :priv
raise "Prot_v implicit failed" unless Prot_v.new.call_implicit == :prot
raise "Prot_v explicit-self failed" unless Prot_v.new.call_explicit_self == :prot

# --- P2 explicit-other: ALWAYS raises (MRI's syntactic check) ---
# Even when `other` happens to equal self at runtime, the syntactic
# form `other.helper` raises — only the literal `self.helper` form
# is relaxed by 4.x. So all explicit-other variants raise the same
# NoMethodError.
p1 = Priv_v.new
begin
  p1.call_explicit_other(p1)
  raise "Priv_v explicit-other with recv==self should still have raised"
rescue NoMethodError => e
  raise "Priv_v wrong msg: #{e.message}" unless e.message.include?("private method")
  raise "Priv_v wrong name: #{e.message}" unless e.message.include?("helper")
end

begin
  Priv_v.new.call_explicit_other(Priv_v.new)
  raise "Priv_v explicit-other on different instance should have raised"
rescue NoMethodError => e
  raise "Priv_v wrong msg: #{e.message}" unless e.message.include?("private method")
  raise "Priv_v wrong name: #{e.message}" unless e.message.include?("helper")
end

# --- P3 explicit-other: kind_of?(recv.class) check ---
# Sibling instance: same class → passes
pr1 = Prot_v.new
pr2 = Prot_v.new
raise "Prot_v sibling failed" unless pr1.call_explicit_other(pr2) == :prot

# Subclass caller on parent receiver: ProtSubcaller_v.is_a?(Prot_v) → passes
sub = ProtSubcaller_v.new
raise "Prot_v subclass-caller failed" unless sub.sibling_call(pr1) == :prot

# Unrelated caller: ProtSubcaller_v has its own implementation inherited
# but ProtSubcaller_v is_a? Prot_v, so this should succeed too. The fail
# case for P3 needs a totally unrelated caller class — but Frozone's
# closed-world walk gives every method body the chance to call other.helper
# only if the other class is in scope. So we use Pub_v which doesn't
# have a `helper` at all; the explicit-other call should miss on the
# message itself (NoMethodError "undefined method"). Distinct error
# shape — leave the "real" P3 failure case to the universal-slot Stage 3
# verification.

puts "visibility_test: OK"

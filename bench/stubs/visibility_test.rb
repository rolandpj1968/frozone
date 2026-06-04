# Visibility test stub.
#
# Covers Stage 2 of method visibility (#116, docs/box-first-visibility.md):
# call-site emission for P2 (all-private) and P3 (all-protected) names,
# across the three call flavors:
#   - implicit recv (no check)
#   - explicit self (no check, 4.x relaxed)
#   - explicit other (unconditional raise for private — MRI's syntactic
#                     check; runtime kind_of? for protected)
#
# Names must be UNIQUE per visibility (no collisions) so the closed-world
# survey classifies them as P2 / P3 and not P4. `priv_helper` exists only
# on Priv_v (private); `prot_helper` only on Prot_v hierarchy (protected).
#
# Mixed-visibility (P4) names are out of scope here — they need Stage 3
# (universal-slot caller_self thread). Once Stage 3 lands, extend this
# stub with a P4 case (same name with different visibilities across
# classes).

# Pub_v: all-public — no check anywhere.
class Pub_v
  def m; :pub; end
end

# Priv_v: priv_helper is P2 (all-private — only defined here, private).
# Explicit-other must raise NoMethodError; implicit and explicit-self
# must succeed.
class Priv_v
  def call_implicit
    priv_helper
  end

  def call_explicit_self
    self.priv_helper
  end

  def call_explicit_other(other)
    other.priv_helper
  end

  private

  def priv_helper
    :priv
  end
end

# Prot_v: prot_helper is P3 (all-protected — only defined in this
# hierarchy, protected). Sibling instance (kind_of? Prot_v) must
# succeed; non-sibling must raise NoMethodError.
class Prot_v
  def call_implicit
    prot_helper
  end

  def call_explicit_self
    self.prot_helper
  end

  def call_explicit_other(other)
    other.prot_helper
  end

  protected

  def prot_helper
    :prot
  end
end

class ProtSubcaller_v < Prot_v
  # Subclass caller; `self` is a ProtSubcaller_v which IS a Prot_v, so
  # the kind_of? check succeeds against a Prot_v receiver.
  def sibling_call(other)
    other.prot_helper
  end
end

# P4 mixed-visibility (Stage 3 target): mixed_helper is private in
# MixedHost_v and public in MixedPub_v. The survey classifies it as
# P4, so Stage 2 skips the call-site check and Stage 3's
# g_caller_self thread_local + body prologue resolves at runtime
# per the receiver's class.
class MixedHost_v
  def call_implicit
    mixed_helper                  # OK: implicit → privileged
  end

  def call_explicit_self
    self.mixed_helper              # OK: explicit-self → privileged (4.x)
  end

  def call_explicit_other(other)
    other.mixed_helper             # body decides at runtime per recv's class
  end

  private
  def mixed_helper
    :mixed_priv
  end
end

class MixedPub_v
  # PUBLIC mixed_helper makes the name P4 across the closed world.
  def mixed_helper
    :mixed_pub
  end
end

# Stage 5 — attr_accessor and post-hoc visibility setters. The
# interpreter applies the right visibility to the generated methods
# (attr_*) and to post-hoc declarations (private :foo / public :foo);
# the survey reads from methods_table where those decisions live, so
# Stage 2 + 3 codegen automatically honors them.
class AttrPriv_v
  attr_accessor :priv_attr   # would be public, but...
  private :priv_attr, :priv_attr=
end

class PostHocPriv_v
  def post_hoc_priv; :phpriv; end
  private :post_hoc_priv
end

# --- Implicit / explicit-self: always succeed ---
raise "Pub_v public failed" unless Pub_v.new.m == :pub
raise "Priv_v implicit failed" unless Priv_v.new.call_implicit == :priv
raise "Priv_v explicit-self failed" unless Priv_v.new.call_explicit_self == :priv
raise "Prot_v implicit failed" unless Prot_v.new.call_implicit == :prot
raise "Prot_v explicit-self failed" unless Prot_v.new.call_explicit_self == :prot

# --- P2 explicit-other: ALWAYS raises (MRI's syntactic check) ---
# Even when `other` happens to equal self at runtime, the syntactic
# form `other.priv_helper` raises — only the literal `self.priv_helper`
# form is relaxed by 4.x. So all explicit-other variants raise.
p1 = Priv_v.new
begin
  p1.call_explicit_other(p1)
  raise "Priv_v explicit-other with recv==self should still have raised"
rescue NoMethodError => e
  raise "Priv_v wrong msg: #{e.message}" unless e.message.include?("private method")
  raise "Priv_v wrong name: #{e.message}" unless e.message.include?("priv_helper")
end

begin
  Priv_v.new.call_explicit_other(Priv_v.new)
  raise "Priv_v explicit-other on different instance should have raised"
rescue NoMethodError => e
  raise "Priv_v wrong msg: #{e.message}" unless e.message.include?("private method")
  raise "Priv_v wrong name: #{e.message}" unless e.message.include?("priv_helper")
end

# --- P3 explicit-other: kind_of?(recv.class) check ---
# Sibling instance: same class → passes
pr1 = Prot_v.new
pr2 = Prot_v.new
raise "Prot_v sibling failed" unless pr1.call_explicit_other(pr2) == :prot

# Subclass caller on parent receiver: ProtSubcaller_v.is_a?(Prot_v) → passes
sub = ProtSubcaller_v.new
raise "Prot_v subclass-caller failed" unless sub.sibling_call(pr1) == :prot

# --- P4 mixed-visibility (Stage 3) ---
# Implicit / explicit-self on the private side — allowed
raise "MixedHost_v implicit failed" unless MixedHost_v.new.call_implicit == :mixed_priv
raise "MixedHost_v explicit-self failed" unless MixedHost_v.new.call_explicit_self == :mixed_priv

# Explicit-other dispatching to MixedHost_v (private body) — body prologue raises
begin
  MixedHost_v.new.call_explicit_other(MixedHost_v.new)
  raise "MixedHost_v explicit-other private should have raised"
rescue NoMethodError => e
  raise "MixedHost_v P4 wrong msg: #{e.message}" unless e.message.include?("private method")
  raise "MixedHost_v P4 wrong name: #{e.message}" unless e.message.include?("mixed_helper")
end

# Explicit-other dispatching to MixedPub_v (public body) — body has no prologue, returns value
raise "MixedPub_v explicit-other public failed" unless MixedHost_v.new.call_explicit_other(MixedPub_v.new) == :mixed_pub

# Direct call on the public class works regardless
raise "MixedPub_v direct failed" unless MixedPub_v.new.mixed_helper == :mixed_pub

# --- Stage 5: attr_accessor under private ---
# AttrPriv_v.new.priv_attr (reader, explicit-other → raise)
begin
  AttrPriv_v.new.priv_attr
  raise "AttrPriv_v.priv_attr (explicit-other) should have raised"
rescue NoMethodError => e
  raise "AttrPriv_v wrong: #{e.message}" unless e.message.include?("private method")
end
# AttrPriv_v.new.priv_attr= (writer, explicit-other → raise)
begin
  AttrPriv_v.new.priv_attr = 1
  raise "AttrPriv_v.priv_attr= (explicit-other) should have raised"
rescue NoMethodError => e
  raise "AttrPriv_v= wrong: #{e.message}" unless e.message.include?("private method")
end

# --- Stage 5: post-hoc private setter ---
begin
  PostHocPriv_v.new.post_hoc_priv
  raise "PostHocPriv_v explicit-other should have raised"
rescue NoMethodError => e
  raise "PostHocPriv_v wrong: #{e.message}" unless e.message.include?("private method")
end

puts "visibility_test: OK"

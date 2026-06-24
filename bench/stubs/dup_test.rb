# Dup chain regression test (#198).
#
# Verifies:
#   - Hash#dup, Array#dup, String#dup, Set#dup all have independent
#     underlying storage (mutating the dup doesn't mutate the source)
#   - User class with custom `def dup` runs its body under AOT
#     compilation — the pre-#198 force-override would silently replace
#     it with a C++ memberwise copy ctor, dropping the user's logic
#   - User class without `def dup` gets correct memberwise shallow copy
#     (all ivars present and equal to source, but shared inner objects
#     remain shared per MRI shallow-dup semantics)
#
# Integration spec asserts exact stdout match.

require 'set'

h = { a: 1 }
h2 = h.dup
h2[:b] = 2
puts "hash_independent=#{!h.key?(:b) && h2.key?(:b)}"

a = [1, 2, 3]
a2 = a.dup
a2 << 4
puts "array_independent=#{a.length == 3 && a2.length == 4}"

s = "hello"
s2 = s.dup
s2 << "!"
puts "string_independent=#{s == 'hello' && s2 == 'hello!'}"

st = Set[:x]
st2 = st.dup
st2.add(:y)
puts "set_independent=#{!st.include?(:y) && st2.include?(:y)}"

class CustomDuper
  attr_accessor :marker
  def initialize
    @marker = "default"
  end
  def dup
    r = super
    r.marker = "custom-#{r.marker}"
    r
  end
end

c = CustomDuper.new
d = c.dup
puts "user_def_dup_honored=#{d.marker == 'custom-default'}"

class PlainContainer
  attr_accessor :items, :name
  def initialize
    @items = [1, 2, 3]
    @name = "src"
  end
end

p1 = PlainContainer.new
p2 = p1.dup
puts "user_shallow_dup_fresh_instance=#{!p2.equal?(p1)}"
puts "user_shallow_dup_ivars_copied=#{p2.items == [1, 2, 3] && p2.name == 'src'}"
puts "user_shallow_dup_shares_inner=#{p1.items.equal?(p2.items)}"

# #199: dup is always-unfrozen; clone(freeze: false) is always-unfrozen.
# clone_preserves_frozen and clone(freeze: true) aren't asserted here
# because object_freeze / object_frozen lower to no-ops in box-first
# compiled mode (frozen state isn't tracked), so they would trivially
# pass for the wrong reason. The interpreted-mode rspec covers them.
fz_src = PlainContainer.new
fz_src.freeze
puts "dup_unfrozen=#{!fz_src.dup.frozen?}"
puts "clone_freeze_false_unfrozen=#{!fz_src.clone(freeze: false).frozen?}"

# Ivar slots are independent on plain dup (mutating dup doesn't affect src).
mut_src = PlainContainer.new
mut_dup = mut_src.dup
mut_dup.name = "mutated"
puts "user_dup_ivar_slots_independent=#{mut_src.name == 'src' && mut_dup.name == 'mutated'}"

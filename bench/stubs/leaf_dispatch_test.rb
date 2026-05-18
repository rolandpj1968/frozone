$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Coverage for box-first Phase A leaf-dispatch (FROZONE_LEAF_DISPATCH=1).
# Each case is independent; the test passes if the program prints the
# expected lines regardless of whether the methods went through the
# typeid gateway or the universal VT slot.

# Positive: `double` is single-def on a leaf class (LeafCalc) →
# Phase A eligible (K=1).
# Phase B positive (cross-stub): `label` is multi-def — it also exists
# on Thread::Backtrace::Location in core/4.0/thread.rb, which is itself
# a leaf. Under Phase A this was a negative; under Phase B with K≥2
# it's admitted as a K-way OR-chain.
class LeafCalc
  def double(x) = x + x
  def label = "leaf"
end

# Negative: parent class is NOT a leaf (Child extends it), so even
# though `kind` is single-def on Parent, leaf detection rejects it.
class Parent
  def kind = "P"
end
class Child < Parent
  def kind = "C"
end

# Phase B positive: same method name on two unrelated leaf classes →
# multi-def-all-leaf. Phase B handles via K-way typeid OR-chain
# (K=2 here). Phase A excludes these — Phase B admits them. Behavior
# is identical in both phases; only codegen differs.
class Animal
  def speak = "animal-noise"
end
class Robot
  def speak = "beep"
end

# Mix with natural-args style (optional positional). When NA=1, the
# `greet` slot gets per-arity overloads; leaf-dispatch is told to
# skip names already claimed by natural-args. Verifies the two
# features compose without collision.
class Greeter
  def greet(name, prefix = "Hi") = "#{prefix}, #{name}"
end

puts LeafCalc.new.double(21)
puts LeafCalc.new.label
puts Parent.new.kind
puts Child.new.kind
puts Animal.new.speak
puts Robot.new.speak
puts Greeter.new.greet("alice")
puts Greeter.new.greet("bob", "Yo")

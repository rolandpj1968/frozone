require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/snapshot'

# Pure-function tests for the load-phase Snapshot graph serializer.
# Identity-preserving: every distinct object materialized once, all
# references resolving to that one materialization; cycle-safe via the
# allocate-then-wire split.

S = Frozone::Compiler::Backend::CppBox::Snapshot unless defined?(S)
CppC = Frozone::Compiler::Backend::CppBox::Cpp unless defined?(CppC)
Vm = Frozone::Vm unless defined?(Vm)

module SnapFactory
  module_function
  def int(n)  = Vm::IntegerObject.new(n)
  def str(s)  = Vm::StringObject.new(s)
  def arr(es) = Vm::ArrayObject.new(es)
  def obj(ivars = {})
    o = Vm::ObjectObject.new(Vm::Core::OBJECT_CLASS)
    ivars.each { |k, v| o.set_ivar(k, v) }
    o
  end
end

RSpec.describe Frozone::Compiler::Backend::CppBox::Snapshot do
  include SnapFactory

  let(:cpp)  { CppC.new(user_classes: {}, user_constants: {}) }
  let(:snap) { described_class.new(cpp) }

  def accessor_bodies(fns) = fns.to_h { |f| [f.name, f.body] }

  describe "leaf values stay inline (not slotted)" do
    it "renders an Integer inline, not as a snapshot accessor" do
      expect(snap.register_constant(:N, int(5))).to eq(:leaf)
      expect(snap.ref_expr(int(5))).not_to include("k_")
    end
  end

  describe "identity dedup across constants" do
    it "shares one canonical accessor; aliases route to it (Array)" do
      a = arr([int(1)])
      expect(snap.register_constant(:FOO, a)).to eq(:canonical)
      expect(snap.register_constant(:BAR, a)).to eq(:alias)

      expect(snap.ref_expr(a)).to eq("k_FOO()")
      bodies = accessor_bodies(snap.alloc_fns)
      expect(bodies["k_FOO"]).to include("new Array()")
      expect(bodies["k_BAR"]).to eq("return k_FOO();")   # router, not a 2nd Array
    end

    it "dedups a shared String by object identity" do
      s = str("x")
      expect(snap.register_constant(:S1, s)).to eq(:canonical)
      expect(snap.register_constant(:S2, s)).to eq(:alias)
      expect(snap.ref_expr(s)).to eq("k_S1()")
      expect(accessor_bodies(snap.alloc_fns)["k_S2"]).to eq("return k_S1();")
    end

    it "does NOT dedup structurally-equal-but-distinct objects" do
      snap.register_constant(:A, str("x"))
      snap.register_constant(:B, str("x"))   # different object
      # two canonical accessors, no router
      names = snap.alloc_fns.map(&:name)
      expect(names).to contain_exactly("k_A", "k_B")
    end
  end

  describe "interior unnamed objects get slotted + wired" do
    it "assigns a k_snap_ slot to an object reached only via an ivar" do
      inner = obj(:@v => int(7))
      outer = obj(:@inner => inner)
      snap.register_constant(:OUTER, outer)

      fns = snap.alloc_fns
      names = fns.map(&:name)
      expect(names).to include("k_OUTER")
      snap_name = names.find { |n| n.start_with?("k_snap_") }
      expect(snap_name).not_to be_nil

      wire = snap.wire_lines.join("\n")
      # outer's ivar points at the interior object's canonical accessor
      expect(wire).to match(/iv_inner = #{Regexp.escape(snap_name)}\(\);/)
    end
  end

  describe "cycles terminate and self-reference resolves" do
    it "handles an object whose ivar points at itself" do
      a = obj
      a.set_ivar(:@self, a)
      snap.register_constant(:CYC, a)

      # discovery terminated (one node), alloc empty, wire references self
      expect(snap.alloc_fns.map(&:name)).to contain_exactly("k_CYC")
      expect(snap.wire_lines.join("\n")).to include("iv_self = k_CYC();")
    end

    it "handles a mutual cycle between two interior objects" do
      a = obj
      b = obj(:@back => a)
      a.set_ivar(:@fwd, b)
      snap.register_constant(:A, a)

      names = snap.alloc_fns.map(&:name)
      expect(names).to include("k_A")
      expect(names.size).to eq(2)   # A + one k_snap for b
      wire = snap.wire_lines.join("\n")
      expect(wire).to match(/iv_fwd = k_snap_\d+\(\);/)   # a -> b
      expect(wire).to include("iv_back = k_A();")          # b -> a
    end
  end
end

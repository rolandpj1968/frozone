require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/crystal_emitter'
require_relative '../../../lib/frozone/compiler/crystal_type'

CT = Frozone::Compiler::CrystalType

RSpec.describe Frozone::Compiler::CrystalType do
  describe ".native?" do
    it "scalars are native" do
      expect(CT.native?(:i64)).to be true
      expect(CT.native?(:f64)).to be true
    end

    it "arrays are native" do
      expect(CT.native?([:array, :i64])).to be true
      expect(CT.native?([:array, [:array, :f64]])).to be true
    end

    it "ruby types are not native" do
      expect(CT.native?(:ruby_object)).to be false
      expect(CT.native?([:ruby_class, :Foo])).to be false
      expect(CT.native?([:ruby_builtin, :Hash])).to be false
    end
  end

  describe ".scalar?" do
    it "identifies scalars" do
      expect(CT.scalar?(:i64)).to be true
      expect(CT.scalar?(:f64)).to be true
      expect(CT.scalar?([:array, :i64])).to be false
      expect(CT.scalar?(:ruby_object)).to be false
    end
  end

  describe ".array?" do
    it "identifies arrays" do
      expect(CT.array?([:array, :i64])).to be true
      expect(CT.array?([:array, [:array, :f64]])).to be true
      expect(CT.array?(:i64)).to be false
    end
  end

  describe ".elem" do
    it "returns element type" do
      expect(CT.elem([:array, :i64])).to eq(:i64)
      expect(CT.elem([:array, [:array, :f64]])).to eq([:array, :f64])
      expect(CT.elem(:i64)).to be_nil
    end
  end

  describe ".to_crystal" do
    it "renders scalars" do
      expect(CT.to_crystal(:i64)).to eq("Int64")
      expect(CT.to_crystal(:f64)).to eq("Float64")
    end

    it "renders flat arrays" do
      expect(CT.to_crystal([:array, :i64])).to eq("Array(Int64)")
      expect(CT.to_crystal([:array, :f64])).to eq("Array(Float64)")
    end

    it "renders nested arrays" do
      expect(CT.to_crystal([:array, [:array, :i64]])).to eq("Array(Array(Int64))")
      expect(CT.to_crystal([:array, [:array, [:array, :f64]]])).to eq("Array(Array(Array(Float64)))")
    end

    it "renders ruby types" do
      expect(CT.to_crystal(:ruby_object)).to eq("RubyObject")
      expect(CT.to_crystal([:ruby_class, :Foo])).to eq("Ruby_Foo")
      expect(CT.to_crystal([:ruby_builtin, :Hash])).to eq("RubyHash")
    end
  end

  describe ".from_ti" do
    it "converts scalars" do
      expect(CT.from_ti(:i64)).to eq(:i64)
      expect(CT.from_ti(:f64)).to eq(:f64)
    end

    it "converts flat arrays" do
      expect(CT.from_ti({ class: :Array, elem: :i64 })).to eq([:array, :i64])
    end

    it "converts nested arrays" do
      expect(CT.from_ti({ class: :Array, elem: { class: :Array, elem: :i64 } })).to eq([:array, [:array, :i64]])
    end

    it "converts unknown/nil to ruby_object" do
      expect(CT.from_ti(:unknown)).to eq(:ruby_object)
      expect(CT.from_ti(nil)).to eq(:ruby_object)
    end

    it "converts unpromotable arrays to ruby_object" do
      expect(CT.from_ti({ class: :Array })).to eq(:ruby_object)
      expect(CT.from_ti({ class: :Array, elem: { class: :String } })).to eq(:ruby_object)
    end

    it "converts user classes" do
      expect(CT.from_ti({ class: :Foo }, user_class_names: Set[:Foo])).to eq([:ruby_class, :Foo])
    end
  end
end

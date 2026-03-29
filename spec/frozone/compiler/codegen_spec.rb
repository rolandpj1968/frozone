require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/codegen'

RSpec.describe Frozone::Compiler::Codegen do
  describe Frozone::Compiler::CrystalTypeMapper do
    def mapper(opts = Set.new)
      Frozone::Compiler::CrystalTypeMapper.new(
        double("env"), user_methods: {}, user_classes: {}, opt_flags: opts
      )
    end

    it "maps :i64 to Int64" do
      expect(mapper.send(:crystal_type, :i64)).to eq("Int64")
    end

    it "maps :f64 to Float64" do
      expect(mapper.send(:crystal_type, :f64)).to eq("Float64")
    end

    it "maps Array[:i64] to Array(Int64)" do
      expect(mapper.send(:crystal_type, { class: :Array, elem: :i64 })).to eq("Array(Int64)")
    end

    it "maps Array[:f64] to Array(Float64)" do
      expect(mapper.send(:crystal_type, { class: :Array, elem: :f64 })).to eq("Array(Float64)")
    end

    it "maps Array with unknown elem to RubyObject" do
      expect(mapper.send(:crystal_type, { class: :Array })).to eq("RubyObject")
    end

    it "maps String to RubyObject (not narrow)" do
      expect(mapper.send(:crystal_type, { class: :String })).to eq("RubyObject")
    end

    it "maps unknown to RubyObject" do
      expect(mapper.send(:crystal_type, :unknown)).to eq("RubyObject")
      expect(mapper.send(:crystal_type, nil)).to eq("RubyObject")
    end

    it "maps Hash to RubyHash" do
      expect(mapper.send(:crystal_type, { class: :Hash })).to eq("RubyHash")
    end

    it "extracts raw type for scalars only" do
      expect(mapper.send(:raw_type, :i64)).to eq(:i64)
      expect(mapper.send(:raw_type, :f64)).to eq(:f64)
      expect(mapper.send(:raw_type, { class: :Integer })).to be_nil
      expect(mapper.send(:raw_type, :unknown)).to be_nil
    end
  end
end

require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/codegen'

T = Frozone::Compiler::Type unless defined?(T)

RSpec.describe Frozone::Compiler::Codegen do
  describe "Type.from_ti" do
    it "passes Type::I64 / F64 through" do
      expect(T.from_ti(T::I64)).to eq(T::I64)
      expect(T.from_ti(T::F64)).to eq(T::F64)
    end

    it "passes array_scalar Types through" do
      expect(T.from_ti(T::ARRAY_I64)).to eq(T::ARRAY_I64)
      expect(T.from_ti(T::ARRAY_F64)).to eq(T::ARRAY_F64)
    end

    it "maps Array with unknown elem to BOTTOM" do
      expect(T.from_ti(T::ARRAY)).to eq(T::BOTTOM)
    end

    it "maps String to BOTTOM" do
      expect(T.from_ti(T::STRING)).to eq(T::BOTTOM)
    end

    it "maps BOTTOM / nil to BOTTOM" do
      expect(T.from_ti(T::BOTTOM)).to eq(T::BOTTOM)
      expect(T.from_ti(nil)).to eq(T::BOTTOM)
    end

    it "maps Hash to Type::HASH" do
      expect(T.from_ti(T::HASH)).to eq(T::HASH)
    end

    it "maps user class to Type.of(name)" do
      expect(T.from_ti(T.of(:Planet), user_class_names: Set[:Planet])).to eq(T.of(:Planet))
    end
  end

  describe "Type#to_crystal" do
    it "converts scalar types" do
      expect(T::I64.to_crystal).to eq("Int64")
      expect(T::F64.to_crystal).to eq("Float64")
    end

    it "converts array_scalar types" do
      expect(T::ARRAY_I64.to_crystal).to eq("Array(Int64)")
      expect(T::ARRAY_F64.to_crystal).to eq("Array(Float64)")
    end

    it "converts BOTTOM to RubyObject" do
      expect(T::BOTTOM.to_crystal).to eq("RubyObject")
    end
  end

  describe Frozone::Compiler::CrystalTypeMapper do
    def mapper(opts = Set.new)
      Frozone::Compiler::CrystalTypeMapper.new(
        double("env"), user_methods: {}, user_classes: {}, opt_flags: opts
      )
    end

    it "raw_type returns Type::I64/F64 for scalars, nil otherwise" do
      expect(mapper.send(:raw_type, T::I64)).to eq(T::I64)
      expect(mapper.send(:raw_type, T::F64)).to eq(T::F64)
      expect(mapper.send(:raw_type, T::INTEGER)).to be_nil
      expect(mapper.send(:raw_type, nil)).to be_nil
    end
  end
end

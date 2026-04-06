require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/codegen'

T = Frozone::Compiler::Type unless defined?(T)
CT = Frozone::Compiler::CrystalType

RSpec.describe Frozone::Compiler::Codegen do
  describe Frozone::Compiler::CrystalType do
    describe ".from_type" do
      it "maps i64 to :i64" do
        expect(CT.from_type(T::I64)).to eq(:i64)
      end

      it "maps f64 to :f64" do
        expect(CT.from_type(T::F64)).to eq(:f64)
      end

      it "maps Array(i64) to [:array, :i64]" do
        expect(CT.from_type(T.array(elem: T::I64))).to eq([:array, :i64])
      end

      it "maps Array(f64) to [:array, :f64]" do
        expect(CT.from_type(T.array(elem: T::F64))).to eq([:array, :f64])
      end

      it "maps Array with unknown elem to :ruby_object" do
        expect(CT.from_type(T::ARRAY)).to eq(:ruby_object)
      end

      it "maps String to :ruby_object" do
        expect(CT.from_type(T::STRING)).to eq(:ruby_object)
      end

      it "maps bottom/nil to :ruby_object" do
        expect(CT.from_type(T::BOTTOM)).to eq(:ruby_object)
        expect(CT.from_type(nil)).to eq(:ruby_object)
      end

      it "maps Hash to [:ruby_builtin, :Hash]" do
        expect(CT.from_type(T::HASH)).to eq([:ruby_builtin, :Hash])
      end

      it "maps user class to [:ruby_class, name]" do
        expect(CT.from_type(T.of(:Planet), user_class_names: Set[:Planet])).to eq([:ruby_class, :Planet])
      end
    end

    describe ".to_crystal" do
      it "converts scalar types" do
        expect(CT.to_crystal(:i64)).to eq("Int64")
        expect(CT.to_crystal(:f64)).to eq("Float64")
      end

      it "converts array types" do
        expect(CT.to_crystal([:array, :i64])).to eq("Array(Int64)")
        expect(CT.to_crystal([:array, :f64])).to eq("Array(Float64)")
      end

      it "converts ruby_object" do
        expect(CT.to_crystal(:ruby_object)).to eq("RubyObject")
      end
    end
  end

  describe Frozone::Compiler::CrystalTypeMapper do
    def mapper(opts = Set.new)
      Frozone::Compiler::CrystalTypeMapper.new(
        double("env"), user_methods: {}, user_classes: {}, opt_flags: opts
      )
    end

    it "raw_type returns :i64/:f64 for scalars, nil otherwise" do
      expect(mapper.send(:raw_type, :i64)).to eq(:i64)
      expect(mapper.send(:raw_type, :f64)).to eq(:f64)
      expect(mapper.send(:raw_type, {class: :Integer})).to be_nil
      expect(mapper.send(:raw_type, :unknown)).to be_nil
    end
  end
end

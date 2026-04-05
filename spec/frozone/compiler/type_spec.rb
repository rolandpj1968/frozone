require_relative '../../../lib/frozone/compiler/type'

T = Frozone::Compiler::Type

RSpec.describe Frozone::Compiler::Type do
  # -- Singletons and identity -----------------------------------------------

  describe "singletons" do
    it "interned constants are frozen" do
      [T::BOTTOM, T::I64, T::F64, T::ARRAY_I64, T::ARRAY_F64,
       T::NIL_CLASS, T::STRING, T::INTEGER, T::FLOAT, T::OBJECT].each do |t|
        expect(t).to be_frozen
      end
    end

    it "Type.of returns interned singletons for common classes" do
      expect(T.of(:NilClass)).to equal(T::NIL_CLASS)
      expect(T.of(:String)).to equal(T::STRING)
      expect(T.of(:Integer)).to equal(T::INTEGER)
      expect(T.of(:Float)).to equal(T::FLOAT)
      expect(T.of(:Object)).to equal(T::OBJECT)
      expect(T.of(:Array)).to equal(T::ARRAY)
      expect(T.of(:Hash)).to equal(T::HASH)
    end

    it "Type.of returns new instance for decorated types" do
      expect(T.of(:String, nullable: true)).not_to equal(T::STRING)
    end

    it "Type.of returns new instance for user classes" do
      t = T.of(:Planet)
      expect(t.class_name).to eq(:Planet)
      expect(t).to be_class_type
    end
  end

  # -- Predicates ------------------------------------------------------------

  describe "predicates" do
    it "bottom?" do
      expect(T::BOTTOM).to be_bottom
      expect(T::I64).not_to be_bottom
    end

    it "raw?" do
      expect(T::I64).to be_raw
      expect(T::F64).to be_raw
      expect(T::INTEGER).not_to be_raw
      expect(T::BOTTOM).not_to be_raw
    end

    it "numeric?" do
      expect(T::I64).to be_numeric
      expect(T::F64).to be_numeric
      expect(T::INTEGER).to be_numeric
      expect(T::FLOAT).to be_numeric
      expect(T::NUMERIC).to be_numeric
      expect(T::STRING).not_to be_numeric
    end

    it "nullable?" do
      expect(T.of(:String, nullable: true)).to be_nullable
      expect(T::STRING).not_to be_nullable
      expect(T::NIL_CLASS).not_to be_nullable
    end

    it "nil_type?" do
      expect(T::NIL_CLASS).to be_nil_type
      expect(T::STRING).not_to be_nil_type
    end

    it "array?" do
      expect(T::ARRAY).to be_array
      expect(T.array(elem: T::I64)).to be_array
      expect(T::STRING).not_to be_array
    end

    it "hash_type?" do
      expect(T::HASH).to be_hash_type
      expect(T::ARRAY).not_to be_hash_type
    end

    it "array_scalar?" do
      expect(T::ARRAY_I64).to be_array_scalar
      expect(T::ARRAY_F64).to be_array_scalar
      expect(T::ARRAY).not_to be_array_scalar
    end
  end

  # -- Equality (value semantics) --------------------------------------------

  describe "equality" do
    it "same singletons are ==" do
      expect(T::I64).to eq(T::I64)
      expect(T::BOTTOM).to eq(T::BOTTOM)
    end

    it "structurally equal types are ==" do
      a = T.of(:Planet, nullable: true)
      b = T.of(:Planet, nullable: true)
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "different types are not ==" do
      expect(T::I64).not_to eq(T::F64)
      expect(T::STRING).not_to eq(T.of(:String, nullable: true))
    end

    it "parameterised array types compare deeply" do
      a = T.array(elem: T::I64)
      b = T.array(elem: T::I64)
      c = T.array(elem: T::F64)
      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end
  end

  # -- Factories -------------------------------------------------------------

  describe "factories" do
    it "Type.array creates Array with elem" do
      t = T.array(elem: T::F64)
      expect(t).to be_array
      expect(t.elem).to eq(T::F64)
    end

    it "Type.hash_type creates Hash with key/val" do
      t = T.hash_type(key: T::SYMBOL, val: T::I64)
      expect(t).to be_hash_type
      expect(t.key).to eq(T::SYMBOL)
      expect(t.val).to eq(T::I64)
    end

    it "Type.nullable wraps a type" do
      t = T.nullable(T::STRING)
      expect(t).to be_nullable
      expect(t.class_name).to eq(:String)
    end

    it "Type.nullable is identity on already-nullable" do
      t = T.of(:String, nullable: true)
      expect(T.nullable(t)).to equal(t)
    end

    it "Type.nullable on NilClass returns NilClass" do
      expect(T.nullable(T::NIL_CLASS)).to equal(T::NIL_CLASS)
    end

    it "Type.nullable on raw types boxes them" do
      expect(T.nullable(T::I64)).to eq(T.of(:Integer, nullable: true))
      expect(T.nullable(T::F64)).to eq(T.of(:Float, nullable: true))
    end
  end

  # -- Legacy round-trip -----------------------------------------------------

  describe "legacy conversion" do
    it "round-trips scalars" do
      expect(T.from_legacy(:unknown).to_legacy).to eq(:unknown)
      expect(T.from_legacy(:i64).to_legacy).to eq(:i64)
      expect(T.from_legacy(:f64).to_legacy).to eq(:f64)
      expect(T.from_legacy(:array_i64).to_legacy).to eq(:array_i64)
      expect(T.from_legacy(:array_f64).to_legacy).to eq(:array_f64)
    end

    it "round-trips class types" do
      expect(T.from_legacy({class: :String}).to_legacy).to eq({class: :String})
      expect(T.from_legacy({class: :Planet}).to_legacy).to eq({class: :Planet})
    end

    it "round-trips nullable" do
      legacy = {class: :String, nullable: true}
      expect(T.from_legacy(legacy).to_legacy).to eq(legacy)
    end

    it "round-trips parameterised arrays" do
      legacy = {class: :Array, elem: :i64}
      result = T.from_legacy(legacy).to_legacy
      expect(result[:class]).to eq(:Array)
      expect(result[:elem]).to eq(:i64)
    end

    it "round-trips nested arrays" do
      legacy = {class: :Array, elem: {class: :Array, elem: :i64}}
      result = T.from_legacy(legacy).to_legacy
      expect(result[:class]).to eq(:Array)
      expect(result[:elem][:class]).to eq(:Array)
      expect(result[:elem][:elem]).to eq(:i64)
    end

    it "round-trips hashes with key/val" do
      legacy = {class: :Hash, key: {class: :Symbol}, val: :i64}
      result = T.from_legacy(legacy).to_legacy
      expect(result[:class]).to eq(:Hash)
      expect(result[:key]).to eq({class: :Symbol})
      expect(result[:val]).to eq(:i64)
    end

    it "Type objects pass through from_legacy" do
      expect(T.from_legacy(T::I64)).to equal(T::I64)
    end
  end

  # -- Helpers for lattice ---------------------------------------------------

  describe "lattice helpers" do
    it "boxed_class_name" do
      expect(T::I64.boxed_class_name).to eq(:Integer)
      expect(T::F64.boxed_class_name).to eq(:Float)
      expect(T::ARRAY_I64.boxed_class_name).to eq(:Array)
      expect(T::STRING.boxed_class_name).to eq(:String)
      expect(T::BOTTOM.boxed_class_name).to eq(:Object)
    end

    it "to_class_type promotes scalars" do
      expect(T::I64.to_class_type).to eq(T::INTEGER)
      expect(T::F64.to_class_type).to eq(T::FLOAT)
      expect(T::STRING.to_class_type).to equal(T::STRING)
    end
  end
end

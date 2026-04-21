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

  # -- Crystal codegen -------------------------------------------------------

  describe "#to_crystal" do
    it "scalars" do
      expect(T::I64.to_crystal).to eq('Int64')
      expect(T::F64.to_crystal).to eq('Float64')
    end

    it "array scalars" do
      expect(T::ARRAY_I64.to_crystal).to eq('Array(Int64)')
      expect(T::ARRAY_F64.to_crystal).to eq('Array(Float64)')
    end

    it "class types with Crystal names" do
      expect(T::INTEGER.to_crystal).to eq('RubyInteger')
      expect(T::FLOAT.to_crystal).to eq('RubyFloat')
      expect(T::STRING.to_crystal).to eq('RubyString')
      expect(T::ARRAY.to_crystal).to eq('RubyArray')
      expect(T::HASH.to_crystal).to eq('RubyHash')
      expect(T::NIL_CLASS.to_crystal).to eq('RubyNil')
    end

    it "user classes" do
      expect(T.of(:Planet).to_crystal).to eq('Ruby_Planet')
      expect(T.of(:Node).to_crystal).to eq('Ruby_Node')
    end

    it "parameterised arrays with native elems" do
      expect(T.array(elem: T::I64).to_crystal).to eq('Array(Int64)')
      expect(T.array(elem: T::F64).to_crystal).to eq('Array(Float64)')
    end

    it "bottom" do
      expect(T::BOTTOM.to_crystal).to eq('RubyObject')
    end
  end

  describe "#native?" do
    it "scalars are native" do
      expect(T::I64).to be_native
      expect(T::F64).to be_native
    end

    it "array scalars are native" do
      expect(T::ARRAY_I64).to be_native
      expect(T::ARRAY_F64).to be_native
    end

    it "class types are not native" do
      expect(T::STRING).not_to be_native
      expect(T::INTEGER).not_to be_native
    end

    it "parameterised arrays with native elems are native" do
      expect(T.array(elem: T::I64)).to be_native
    end

    it "bottom is not native" do
      expect(T::BOTTOM).not_to be_native
    end
  end

  describe "#contains_gc_refs?" do
    it "primitives and bottom don't contain gc_refs" do
      expect(T::BOTTOM).not_to be_contains_gc_refs
      expect(T::I64).not_to be_contains_gc_refs
      expect(T::F64).not_to be_contains_gc_refs
    end

    it "value-typed builtins don't contain gc_refs" do
      expect(T::STRING).not_to be_contains_gc_refs
      expect(T::SYMBOL).not_to be_contains_gc_refs
      expect(T::INTEGER).not_to be_contains_gc_refs
      expect(T::FLOAT).not_to be_contains_gc_refs
      expect(T::NIL_CLASS).not_to be_contains_gc_refs
    end

    it "NON_GC_BUILTIN classes (Random) don't contain gc_refs" do
      expect(T::RANDOM).not_to be_contains_gc_refs
    end

    it "Object and BasicObject contain gc_refs (polymorphic reference)" do
      expect(T::OBJECT).to be_contains_gc_refs
      expect(T::BASIC_OBJECT).to be_contains_gc_refs
    end

    it "user classes (non-builtin) contain gc_refs" do
      expect(T.of(:SomeUserClass)).to be_contains_gc_refs
    end

    it "array of primitives does not contain gc_refs" do
      expect(T::ARRAY_I64).not_to be_contains_gc_refs
      expect(T::ARRAY_F64).not_to be_contains_gc_refs
    end

    it "array of user classes contains gc_refs (recursive)" do
      arr_of_node = T.new(:class_type, class_name: :Array, elem: T.of(:Node))
      expect(arr_of_node).to be_contains_gc_refs
    end

    it "hash with user-class value contains gc_refs (recursive)" do
      hash_t = T.new(:class_type, class_name: :Hash, key: T::SYMBOL, val: T.of(:Node))
      expect(hash_t).to be_contains_gc_refs
    end

    it "hash with primitive value does not contain gc_refs" do
      hash_t = T.new(:class_type, class_name: :Hash, key: T::SYMBOL, val: T::I64)
      expect(hash_t).not_to be_contains_gc_refs
    end

    it "class_type with nil class_name (auto) conservatively does not contain gc_refs" do
      anon = T.new(:class_type, class_name: nil)
      expect(anon).not_to be_contains_gc_refs
    end
  end

  describe "#ruby_object_convertible?" do
    it "bottom, primitives, array_scalar are all convertible" do
      expect(T::BOTTOM).to be_ruby_object_convertible
      expect(T::I64).to be_ruby_object_convertible
      expect(T::F64).to be_ruby_object_convertible
      expect(T::ARRAY_I64).to be_ruby_object_convertible
    end

    it "class types are convertible" do
      expect(T::STRING).to be_ruby_object_convertible
      expect(T::INTEGER).to be_ruby_object_convertible
      expect(T::OBJECT).to be_ruby_object_convertible
      expect(T.of(:UserClass)).to be_ruby_object_convertible
    end

    it "NON_GC_BUILTIN classes are NOT convertible (Ruby_Random doesn't inherit RubyObject)" do
      expect(T::RANDOM).not_to be_ruby_object_convertible
    end
  end

  describe ".union_representation" do
    it "RubyObject* when any participant contains gc_refs" do
      expect(T.union_representation([T::I64, T.of(:Node)])).to eq("RubyObject*")
      expect(T.union_representation([T::STRING, T::OBJECT])).to eq("RubyObject*")
    end

    it "RubyObject* when all are convertible" do
      expect(T.union_representation([T::I64, T::F64])).to eq("RubyObject*")
      expect(T.union_representation([T::STRING, T::INTEGER])).to eq("RubyObject*")
    end

    it "std::any when a participant can't convert (NON_GC_BUILTIN mixed)" do
      expect(T.union_representation([T::RANDOM, T::I64])).to eq("std::any")
    end
  end

  describe "#user_class_pointer?" do
    it "user classes are user class pointers" do
      expect(T.of(:Node)).to be_user_class_pointer
      expect(T.of(:SplayTree)).to be_user_class_pointer
      expect(T.of(:PayloadNode)).to be_user_class_pointer
    end

    it "value-typed builtins are not user class pointers" do
      expect(T::STRING).not_to be_user_class_pointer
      expect(T::SYMBOL).not_to be_user_class_pointer
      expect(T::INTEGER).not_to be_user_class_pointer
      expect(T::FLOAT).not_to be_user_class_pointer
      expect(T::NIL_CLASS).not_to be_user_class_pointer
    end

    it "Array / Hash are not user class pointers" do
      expect(T::ARRAY).not_to be_user_class_pointer
      expect(T::HASH).not_to be_user_class_pointer
    end

    it "Object / BasicObject are not user class pointers" do
      expect(T::OBJECT).not_to be_user_class_pointer
      expect(T::BASIC_OBJECT).not_to be_user_class_pointer
    end

    it "NON_GC_BUILTIN (Random) is not a user class pointer" do
      expect(T::RANDOM).not_to be_user_class_pointer
    end

    it "bottom / primitives are not user class pointers" do
      expect(T::BOTTOM).not_to be_user_class_pointer
      expect(T::I64).not_to be_user_class_pointer
      expect(T::F64).not_to be_user_class_pointer
    end

    it "class_type with nil class_name (auto) is not a user class pointer" do
      anon = T.new(:class_type, class_name: nil)
      expect(anon).not_to be_user_class_pointer
    end
  end

  describe "#emitted_as_pointer?" do
    it "user classes render as T*" do
      expect(T.of(:Node)).to be_emitted_as_pointer
    end

    it "Object / BasicObject render as T*" do
      expect(T::OBJECT).to be_emitted_as_pointer
      expect(T::BASIC_OBJECT).to be_emitted_as_pointer
    end

    it "NON_GC_BUILTIN (Random) DOES render as T* (unlike user_class_pointer?)" do
      expect(T::RANDOM).to be_emitted_as_pointer
    end

    it "value-typed builtins don't render as pointers" do
      expect(T::STRING).not_to be_emitted_as_pointer
      expect(T::SYMBOL).not_to be_emitted_as_pointer
      expect(T::INTEGER).not_to be_emitted_as_pointer
      expect(T::FLOAT).not_to be_emitted_as_pointer
      expect(T::NIL_CLASS).not_to be_emitted_as_pointer
    end

    it "Array / Hash don't render as pointers" do
      expect(T::ARRAY).not_to be_emitted_as_pointer
      expect(T::HASH).not_to be_emitted_as_pointer
    end

    it "bottom / primitives / nil-classname don't render as pointers" do
      expect(T::BOTTOM).not_to be_emitted_as_pointer
      expect(T::I64).not_to be_emitted_as_pointer
      expect(T.new(:class_type, class_name: nil)).not_to be_emitted_as_pointer
    end
  end

  describe "#to_cpp_ref and #to_cpp_local" do
    it "user classes wrap in gc_ref / gc_local" do
      expect(T.of(:Node).to_cpp_ref).to eq("gc_ref<Ruby_Node>")
      expect(T.of(:Node).to_cpp_local).to eq("gc_local<Ruby_Node>")
    end

    it "Object / BasicObject wrap in gc_ref / gc_local" do
      expect(T::OBJECT.to_cpp_ref).to eq("gc_ref<RubyObject>")
      expect(T::BASIC_OBJECT.to_cpp_local).to eq("gc_local<RubyObject>")
    end

    it "NON_GC_BUILTIN (Random) stays as raw pointer in both" do
      expect(T::RANDOM.to_cpp_ref).to eq("Ruby_Random*")
      expect(T::RANDOM.to_cpp_local).to eq("Ruby_Random*")
    end

    it "value types don't get wrapped" do
      expect(T::STRING.to_cpp_ref).to eq("RubyString")
      expect(T::INTEGER.to_cpp_ref).to eq("int64_t")
      expect(T::F64.to_cpp_ref).to eq("double")
    end

    it "nested: array of user-class recurses wrapping" do
      t = T.new(:class_type, class_name: :Array, elem: T.of(:Node))
      expect(t.to_cpp_ref).to eq("RubyArray<gc_ref<Ruby_Node>>")
      expect(t.to_cpp_local).to eq("RubyArray<gc_local<Ruby_Node>>")
    end

    it "nested: hash with user-class value recurses" do
      t = T.new(:class_type, class_name: :Hash, key: T::SYMBOL, val: T.of(:Node))
      expect(t.to_cpp_ref).to eq("RubyHash<RubySymbol, gc_ref<Ruby_Node>>")
    end

    it "no wrapper specified → plain to_cpp unchanged" do
      expect(T.of(:Node).to_cpp).to eq("Ruby_Node*")
      expect(T::OBJECT.to_cpp).to eq("RubyObject*")
    end
  end
end

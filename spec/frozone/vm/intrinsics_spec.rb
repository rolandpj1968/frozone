require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::Intrinsics do
  let(:i3) { Frozone::Vm::IntegerObject.new(3) }
  let(:i5) { Frozone::Vm::IntegerObject.new(5) }
  let(:ctx) { nil } # context is unused by these intrinsics

  describe '.integer__plus_' do
    it 'adds two integers' do
      result = described_class.integer__plus_(ctx, i3, i5)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(8)
    end

  end

  describe '.integer__minus_' do
    it 'subtracts two integers' do
      result = described_class.integer__minus_(ctx, i5, i3)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(2)
    end

    it 'produces negative results' do
      result = described_class.integer__minus_(ctx, i3, i5)
      expect(result.raw).to eq(-2)
    end
  end

  describe '.integer__lt_' do
    it 'returns TRUE when left < right' do
      expect(described_class.integer__lt_(ctx, i3, i5)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left >= right' do
      expect(described_class.integer__lt_(ctx, i5, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
      expect(described_class.integer__lt_(ctx, i3, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__le_' do
    it 'returns TRUE when left <= right' do
      expect(described_class.integer__le_(ctx, i3, i5)).to equal(Frozone::Vm::TrueObject::TRUE)
      expect(described_class.integer__le_(ctx, i3, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left > right' do
      expect(described_class.integer__le_(ctx, i5, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__ge_' do
    it 'returns TRUE when left >= right' do
      expect(described_class.integer__ge_(ctx, i5, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
      expect(described_class.integer__ge_(ctx, i3, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left < right' do
      expect(described_class.integer__ge_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__gt_' do
    it 'returns TRUE when left > right' do
      expect(described_class.integer__gt_(ctx, i5, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left <= right' do
      expect(described_class.integer__gt_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
      expect(described_class.integer__gt_(ctx, i3, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__eq_' do
    it 'returns TRUE when values are equal' do
      expect(described_class.integer__eq_(ctx, i3, Frozone::Vm::IntegerObject.new(3))).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when values differ' do
      expect(described_class.integer__eq_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.basic_object_method_missing' do
    let(:klass) { Frozone::Vm::Core::OBJECT_CLASS }
    let(:obj)   { Frozone::Vm::ObjectObject.new(klass) }
    let(:real_ctx) { make_context(the_self: obj) }
    let(:empty_args)   { Frozone::Vm::ArrayObject.new([]) }
    let(:empty_kwargs) { Frozone::Vm::HashObject.new({}) }

    it 'raises with the method name and class name in the message' do
      expect {
        described_class.basic_object_method_missing(real_ctx, obj, :no_such, empty_args, empty_kwargs)
      }.to raise_error(Frozone::Vm::FrozoneException, /undefined method 'no_such' for an instance of Object/)
    end

  end

  describe '.basic_object___send__' do
    let(:klass) { Frozone::Vm::Core::OBJECT_CLASS }
    let(:obj)   { Frozone::Vm::ObjectObject.new(klass) }
    let(:real_ctx) { make_context(the_self: obj) }

    it 'dispatches a method by SymbolObject name' do
      m = make_method(klass, :greet, body: Frozone::Ast::IntegerLiteral.from(42))
      klass.set_method(:greet, m)
      result = described_class.basic_object___send__(
        real_ctx, obj, Frozone::Vm::SymbolObject.from(:greet),
        Frozone::Vm::ArrayObject.new([]),
        Frozone::Vm::HashObject.new({})
      )
      expect(result.raw).to eq(42)
    end

    it 'passes positional args through' do
      m = make_method(klass, :echo, body: Frozone::Ast::LocalVariableRead.new(:x, 0),
                      required_params: [:x])
      klass.set_method(:echo, m)
      result = described_class.basic_object___send__(
        real_ctx, obj, Frozone::Vm::SymbolObject.from(:echo),
        Frozone::Vm::ArrayObject.new([Frozone::Vm::IntegerObject.new(7)]),
        Frozone::Vm::HashObject.new({})
      )
      expect(result.raw).to eq(7)
    end

    it 'raises NoMethodError when method not found' do
      expect {
        described_class.basic_object___send__(real_ctx, obj, Frozone::Vm::SymbolObject.from(:no_such),
          Frozone::Vm::ArrayObject.new([]), Frozone::Vm::HashObject.new({}))
      }.to raise_error(Frozone::Vm::FrozoneException, /undefined method/)
    end

    it 'raises when method is not found' do
      expect {
        described_class.basic_object___send__(real_ctx, obj, Frozone::Vm::SymbolObject.from(:no_such_method_zz),
          Frozone::Vm::ArrayObject.new([]), Frozone::Vm::HashObject.new({}))
      }.to raise_error(Frozone::Vm::FrozoneException, /undefined method/)
    end
  end

  describe '.basic_object___id__' do
    it 'returns an IntegerObject' do
      expect(described_class.basic_object___id__(ctx, i3)).to be_a(Frozone::Vm::IntegerObject)
    end

    it 'returns the same value for the same object' do
      result1 = described_class.basic_object___id__(ctx, i3)
      result2 = described_class.basic_object___id__(ctx, i3)
      expect(result1.raw).to eq(result2.raw)
    end

    it 'returns different values for different objects' do
      a = Frozone::Vm::IntegerObject.new(1)
      b = Frozone::Vm::IntegerObject.new(1)
      expect(described_class.basic_object___id__(ctx, a).raw).not_to eq(
        described_class.basic_object___id__(ctx, b).raw
      )
    end
  end

  describe '.integer_hash' do
    it 'returns an IntegerObject' do
      expect(described_class.integer_hash(ctx, i3)).to be_a(Frozone::Vm::IntegerObject)
    end

    it 'returns the same hash for equal integer values' do
      a = Frozone::Vm::IntegerObject.new(42)
      b = Frozone::Vm::IntegerObject.new(42)
      expect(described_class.integer_hash(ctx, a).raw).to eq(described_class.integer_hash(ctx, b).raw)
    end

    it 'returns the Ruby integer hash value' do
      expect(described_class.integer_hash(ctx, i5).raw).to eq(5.hash)
    end
  end

  describe '.integer_eql' do
    it 'returns TRUE for equal integer values' do
      expect(described_class.integer_eql(ctx, i3, Frozone::Vm::IntegerObject.new(3))).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE for different integer values' do
      expect(described_class.integer_eql(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
    end

    it 'returns FALSE when compared to a non-IntegerObject' do
      expect(described_class.integer_eql(ctx, i3, Frozone::Vm::StringObject.new("3"))).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.string_hash' do
    it 'returns equal hashes for equal string values' do
      a = Frozone::Vm::StringObject.new("hello")
      b = Frozone::Vm::StringObject.new("hello")
      expect(described_class.string_hash(ctx, a).raw).to eq(described_class.string_hash(ctx, b).raw)
    end

    it 'returns the Ruby string hash value' do
      expect(described_class.string_hash(ctx, Frozone::Vm::StringObject.new("abc")).raw).to eq("abc".hash)
    end
  end

  describe '.string_eql' do
    let(:s_abc) { Frozone::Vm::StringObject.new("abc") }

    it 'returns TRUE for equal string values' do
      expect(described_class.string_eql(ctx, s_abc, Frozone::Vm::StringObject.new("abc"))).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE for different string values' do
      expect(described_class.string_eql(ctx, s_abc, Frozone::Vm::StringObject.new("def"))).to equal(Frozone::Vm::FalseObject::FALSE)
    end

    it 'returns FALSE when compared to a non-StringObject' do
      expect(described_class.string_eql(ctx, s_abc, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.symbol_hash' do
    it 'returns equal hashes for the same symbol' do
      a = Frozone::Vm::SymbolObject.from(:foo)
      b = Frozone::Vm::SymbolObject.from(:foo)
      expect(described_class.symbol_hash(ctx, a).raw).to eq(described_class.symbol_hash(ctx, b).raw)
    end

    it 'returns the Ruby symbol hash value' do
      expect(described_class.symbol_hash(ctx, Frozone::Vm::SymbolObject.from(:bar)).raw).to eq(:bar.hash)
    end
  end


  describe '.array_hash and .array_eql' do
    let(:real_ctx) { make_context }
    let(:i1) { Frozone::Vm::IntegerObject.new(1) }
    let(:i2) { Frozone::Vm::IntegerObject.new(2) }

    it 'array hash returns equal values for equal arrays' do
      a = Frozone::Vm::ArrayObject.new([i1, i2])
      b = Frozone::Vm::ArrayObject.new([Frozone::Vm::IntegerObject.new(1), Frozone::Vm::IntegerObject.new(2)])
      expect(a.dispatch(real_ctx, :hash, [], {}).raw).to eq(b.dispatch(real_ctx, :hash, [], {}).raw)
    end

    it 'array eql? returns true for arrays with equal elements' do
      a = Frozone::Vm::ArrayObject.new([i1, i2])
      b = Frozone::Vm::ArrayObject.new([Frozone::Vm::IntegerObject.new(1), Frozone::Vm::IntegerObject.new(2)])
      expect(a.dispatch(real_ctx, :eql?, [b], {})).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'array eql? returns false for arrays with different elements' do
      a = Frozone::Vm::ArrayObject.new([i1])
      b = Frozone::Vm::ArrayObject.new([i2])
      expect(a.dispatch(real_ctx, :eql?, [b], {})).to equal(Frozone::Vm::FalseObject::FALSE)
    end

    it 'array eql? returns false when compared to a non-ArrayObject' do
      a = Frozone::Vm::ArrayObject.new([])
      expect(a.dispatch(real_ctx, :eql?, [Frozone::Vm::HashObject.new({})], {})).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.hash_hash and .hash_eql' do
    let(:real_ctx) { make_context }
    let(:k) { Frozone::Vm::SymbolObject.from(:key) }
    let(:v1) { Frozone::Vm::IntegerObject.new(1) }
    let(:v2) { Frozone::Vm::IntegerObject.new(2) }

    it 'hash hash returns equal values for equal hashes' do
      h1 = Frozone::Vm::HashObject.new({ k => v1 })
      h2 = Frozone::Vm::HashObject.new({ Frozone::Vm::SymbolObject.from(:key) => Frozone::Vm::IntegerObject.new(1) })
      expect(h1.dispatch(real_ctx, :hash, [], {}).raw).to eq(h2.dispatch(real_ctx, :hash, [], {}).raw)
    end

    it 'hash eql? returns true for hashes with equal key-value pairs' do
      h1 = Frozone::Vm::HashObject.new({ k => v1 })
      h2 = Frozone::Vm::HashObject.new({ Frozone::Vm::SymbolObject.from(:key) => Frozone::Vm::IntegerObject.new(1) })
      expect(h1.dispatch(real_ctx, :eql?, [h2], {})).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'hash eql? returns false for hashes with different values' do
      h1 = Frozone::Vm::HashObject.new({ k => v1 })
      h2 = Frozone::Vm::HashObject.new({ k => v2 })
      expect(h1.dispatch(real_ctx, :eql?, [h2], {})).to equal(Frozone::Vm::FalseObject::FALSE)
    end

    it 'hash eql? returns false for hashes with different keys' do
      h1 = Frozone::Vm::HashObject.new({ k => v1 })
      h2 = Frozone::Vm::HashObject.new({ Frozone::Vm::SymbolObject.from(:other) => v1 })
      expect(h1.dispatch(real_ctx, :eql?, [h2], {})).to equal(Frozone::Vm::FalseObject::FALSE)
    end

    it 'hash eql? returns false when compared to a non-HashObject' do
      h = Frozone::Vm::HashObject.new({})
      expect(h.dispatch(real_ctx, :eql?, [Frozone::Vm::ArrayObject.new([])], {})).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.n2f_bool' do
    it 'returns TrueObject::TRUE for true' do
      expect(described_class.n2f_bool(true)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FalseObject::FALSE for false' do
      expect(described_class.n2f_bool(false)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end
end

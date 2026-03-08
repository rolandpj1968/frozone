require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::Method do
  let(:klass)    { Frozone::Vm::Core::OBJECT_CLASS }
  let(:receiver) { Frozone::Vm::ObjectObject.new(klass) }
  let(:ctx)      { make_context }

  def int(n) = Frozone::Vm::IntegerObject.new(n)
  def local(name) = Frozone::Ast::LocalVariableRead.new(sym(name), 0)
  def lit(n) = Frozone::Ast::IntegerLiteral.from(n)

  describe '#initialize' do
    it 'constructs with minimal parameters' do
      expect { make_method(klass, :test) }.not_to raise_error
    end

    it 'raises when scopes is not an array of ModuleObjects' do
      expect {
        described_class.new(["bad"], sym(:test), [], [], nil, [], [], [], nil, [], Frozone::Ast::NilLiteral::NIL)
      }.to raise_error(RuntimeError)
    end

    it 'raises when name is not a SymbolObject' do
      expect {
        described_class.new([klass], "not_symbol", [], [], nil, [], [], [], nil, [], Frozone::Ast::NilLiteral::NIL)
      }.to raise_error(RuntimeError)
    end

    it 'raises when name is a raw Symbol' do
      expect {
        described_class.new([klass], :test, [], [], nil, [], [], [], nil, [], Frozone::Ast::NilLiteral::NIL)
      }.to raise_error(RuntimeError)
    end

    it 'raises when post_params are given without a rest_param' do
      expect {
        described_class.new([klass], sym(:test), [], [], nil, [sym(:post)], [], [], nil, [], Frozone::Ast::NilLiteral::NIL)
      }.to raise_error(RuntimeError, /post_params/)
    end
  end

  describe '#invoke' do
    context 'with no parameters' do
      it 'evaluates the body and returns its result' do
        m = make_method(klass, :answer, body: lit(42))
        result = m.invoke(ctx, receiver, [], {})
        expect(result).to be_a(Frozone::Vm::IntegerObject)
        expect(result.raw).to eq(42)
      end

      it 'returns NilObject::NIL for a nil body' do
        m = make_method(klass, :noop)
        expect(m.invoke(ctx, receiver, [], {})).to equal(Frozone::Vm::NilObject::NIL)
      end
    end

    context 'with required parameters' do
      let(:m) { make_method(klass, :echo, body: local(:x), required_params: [:x]) }

      it 'binds the argument to the param and the body can read it' do
        result = m.invoke(ctx, receiver, [int(7)], {})
        expect(result.raw).to eq(7)
      end

      it 'raises on too few arguments' do
        expect { m.invoke(ctx, receiver, [], {}) }.to raise_error(RuntimeError, /wrong number/)
      end

      it 'raises on too many arguments' do
        expect { m.invoke(ctx, receiver, [int(1), int(2)], {}) }.to raise_error(RuntimeError, /wrong number/)
      end
    end

    context 'with optional parameters' do
      let(:m) do
        make_method(klass, :opt, body: local(:x),
          optional_params: [[:x, lit(99)]])
      end

      it 'uses the provided value when supplied' do
        expect(m.invoke(ctx, receiver, [int(5)], {}).raw).to eq(5)
      end

      it 'uses the default when the argument is omitted' do
        expect(m.invoke(ctx, receiver, [], {}).raw).to eq(99)
      end
    end

    context 'with rest parameter' do
      let(:m) { make_method(klass, :splat, body: local(:rest), rest_param: :rest) }

      it 'collects all args into an ArrayObject' do
        result = m.invoke(ctx, receiver, [int(1), int(2), int(3)], {})
        expect(result).to be_a(Frozone::Vm::ArrayObject)
        expect(result.raw.map(&:raw)).to eq([1, 2, 3])
      end

      it 'is an empty ArrayObject when no args given' do
        result = m.invoke(ctx, receiver, [], {})
        expect(result.raw).to be_empty
      end
    end

    context 'with required + rest + post parameters' do
      let(:m) do
        make_method(klass, :mixed, body: local(:last),
          required_params: [:first], rest_param: :mid, post_params: [:last])
      end

      it 'binds first, rest, and last correctly' do
        result = m.invoke(ctx, receiver, [int(1), int(2), int(3), int(4)], {})
        expect(result.raw).to eq(4)
      end
    end

    context 'with required keyword parameters' do
      let(:kw) { sym(:count) }
      let(:m)  { make_method(klass, :kw_req, body: local(:count), required_kw_params: [kw]) }

      it 'populates the kw param from the given kw_args' do
        result = m.invoke(ctx, receiver, [], { kw => int(10) })
        expect(result.raw).to eq(10)
      end

      it 'raises when the required kw arg is missing' do
        expect { m.invoke(ctx, receiver, [], {}) }.to raise_error(RuntimeError, /missing keyword/)
      end

      it 'raises on unknown keyword when no kw_rest_param' do
        extra = sym(:unknown)
        expect { m.invoke(ctx, receiver, [], { kw => int(1), extra => int(2) }) }.to raise_error(RuntimeError, /unknown keyword/)
      end
    end

    context 'with optional keyword parameters' do
      let(:kw) { sym(:mode) }
      let(:m)  { make_method(klass, :kw_opt, body: local(:mode), optional_kw_params: [[kw, lit(0)]]) }

      it 'uses the supplied kw value' do
        result = m.invoke(ctx, receiver, [], { kw => int(7) })
        expect(result.raw).to eq(7)
      end

      it 'uses the default when the kw arg is omitted' do
        result = m.invoke(ctx, receiver, [], {})
        expect(result.raw).to eq(0)
      end
    end

    context 'with kw_rest parameter' do
      let(:m) { make_method(klass, :kw_rest, body: local(:opts), kw_rest_param: :opts) }

      it 'captures remaining kw args in a HashObject' do
        k1 = sym(:a)
        k2 = sym(:b)
        result = m.invoke(ctx, receiver, [], { k1 => int(1), k2 => int(2) })
        expect(result).to be_a(Frozone::Vm::HashObject)
        expect(result.raw.keys).to contain_exactly(k1, k2)
      end

      it 'is an empty HashObject when no kw args given' do
        result = m.invoke(ctx, receiver, [], {})
        expect(result).to be_a(Frozone::Vm::HashObject)
        expect(result.raw).to be_empty
      end
    end
  end

  describe '#alias_as' do
    it 'returns a new Method object' do
      m = make_method(klass, :original)
      aliased = m.alias_as(sym(:aliased))
      expect(aliased).to be_a(described_class)
      expect(aliased).not_to equal(m)
    end

    it 'the aliased method evaluates to the same body result' do
      m = make_method(klass, :original, body: lit(42))
      aliased = m.alias_as(sym(:aliased))
      expect(aliased.invoke(ctx, receiver, [], {}).raw).to eq(42)
    end
  end
end

require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::LocalVariableRead do
  describe '#initialize' do
    it 'accepts a SymbolObject name and integer depth' do
      expect { described_class.new(sym(:x), 0) }.not_to raise_error
    end

    it 'raises when name is a raw Symbol' do
      expect { described_class.new(:x, 0) }.to raise_error(RuntimeError)
    end

    it 'raises when name is a String' do
      expect { described_class.new("x", 0) }.to raise_error(RuntimeError)
    end

    it 'raises when depth is not an Integer' do
      expect { described_class.new(sym(:x), "0") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'reads a declared local from the current frame' do
      ctx = make_context(locals: [sym(:x)])
      ctx.frame.set_local(sym(:x), Frozone::Vm::IntegerObject.new(42))
      result = described_class.new(sym(:x), 0).evaluate(ctx)
      expect(result.raw).to eq(42)
    end

    it 'returns NilObject::NIL for a declared-but-unset local' do
      ctx = make_context(locals: [sym(:y)])
      result = described_class.new(sym(:y), 0).evaluate(ctx)
      expect(result).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'returns nil (Ruby nil) for an undeclared local' do
      ctx = make_context
      result = described_class.new(sym(:undeclared), 0).evaluate(ctx)
      expect(result).to be_nil
    end
  end

  describe '#to_s' do
    it 'includes the variable name' do
      expect(described_class.new(sym(:foo), 0).to_s).to include("foo")
    end
  end
end

RSpec.describe Frozone::Ast::ConstantRead do
  describe '#initialize' do
    it 'accepts a SymbolObject name' do
      expect { described_class.new(sym(:MY_CONST)) }.not_to raise_error
    end

    it 'raises when name is a raw Symbol' do
      expect { described_class.new(:MY_CONST) }.to raise_error(RuntimeError)
    end

    it 'raises when name is a String' do
      expect { described_class.new("MY_CONST") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'finds a constant in the current scope' do
      scope = Frozone::Vm::ClassObject.new(sym(:CRScope), nil, Frozone::Vm::Core::OBJECT_CLASS)
      val = Frozone::Vm::IntegerObject.new(7)
      scope.set_constant(sym(:X), val)
      ctx = make_context(scopes: [scope])
      result = described_class.new(sym(:X)).evaluate(ctx)
      expect(result).to equal(val)
    end

    it 'finds a constant from an outer scope when not in inner' do
      outer = Frozone::Vm::ClassObject.new(sym(:CROuter), nil, Frozone::Vm::Core::OBJECT_CLASS)
      inner = Frozone::Vm::ClassObject.new(sym(:CRInner), nil, Frozone::Vm::Core::OBJECT_CLASS)
      val = Frozone::Vm::IntegerObject.new(99)
      outer.set_constant(sym(:OUTER_C), val)
      ctx = make_context(scopes: [outer, inner])
      result = described_class.new(sym(:OUTER_C)).evaluate(ctx)
      expect(result).to equal(val)
    end

    it 'returns nil when constant is not found' do
      scope = Frozone::Vm::ClassObject.new(sym(:CRMiss), nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      result = described_class.new(sym(:MISSING_ZZ)).evaluate(ctx)
      expect(result).to be_nil
    end
  end

  describe '#to_s' do
    it 'includes the constant name' do
      expect(described_class.new(sym(:MY_CONST)).to_s).to include("MY_CONST")
    end
  end
end

RSpec.describe Frozone::Ast::ConstantWrite do
  describe '#initialize' do
    it 'accepts a SymbolObject name and a value Node' do
      expect { described_class.new(sym(:C), Frozone::Ast::NilLiteral::NIL) }.not_to raise_error
    end

    it 'raises when name is a raw Symbol' do
      expect { described_class.new(:C, Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when name is a String' do
      expect { described_class.new("C", Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when value_node is not a Node' do
      expect { described_class.new(sym(:C), "bad") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'sets the constant in the innermost scope' do
      scope = Frozone::Vm::ClassObject.new(sym(:CWScope), nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      int_node = Frozone::Ast::IntegerLiteral.from(42)
      described_class.new(sym(:ANSWER), int_node).evaluate(ctx)
      expect(scope.get_constant(sym(:ANSWER)).raw).to eq(42)
    end

    it 'returns the result of evaluating the value node' do
      scope = Frozone::Vm::ClassObject.new(sym(:CWScope2), nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      int_node = Frozone::Ast::IntegerLiteral.from(10)
      result = described_class.new(sym(:N), int_node).evaluate(ctx)
      # ConstantWrite returns the result of set_constant which is the value
      # (Hash#[]=  returns the value in Ruby)
      expect(result.raw).to eq(10)
    end
  end

  describe '#to_s' do
    it 'includes the constant name' do
      expect(described_class.new(sym(:MY_C), Frozone::Ast::NilLiteral::NIL).to_s).to include("MY_C")
    end
  end
end

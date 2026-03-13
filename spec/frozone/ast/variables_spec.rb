require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::LocalVariableRead do
  describe '#initialize' do
    it 'accepts a symbol name and integer depth' do
      expect { described_class.new(:x, 0) }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'reads a declared local from the current frame' do
      ctx = make_context(locals: [:x])
      ctx.frame.set_local(:x, Frozone::Vm::IntegerObject.new(42))
      result = described_class.new(:x, 0).evaluate(ctx)
      expect(result.raw).to eq(42)
    end

    it 'returns NilObject::NIL for a declared-but-unset local' do
      ctx = make_context(locals: [:y])
      result = described_class.new(:y, 0).evaluate(ctx)
      expect(result).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'returns nil (Ruby nil) for an undeclared local' do
      ctx = make_context
      result = described_class.new(:undeclared, 0).evaluate(ctx)
      expect(result).to be_nil
    end
  end

  describe '#to_s' do
    it 'includes the variable name' do
      expect(described_class.new(:foo, 0).to_s).to include("foo")
    end
  end
end

RSpec.describe Frozone::Ast::ConstantRead do
  describe '#initialize' do
    it 'accepts a symbol name' do
      expect { described_class.new(:MY_CONST) }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'finds a constant in the current scope' do
      scope = Frozone::Vm::ClassObject.new(:CRScope, nil, Frozone::Vm::Core::OBJECT_CLASS)
      val = Frozone::Vm::IntegerObject.new(7)
      scope.set_constant(:X, val)
      ctx = make_context(scopes: [scope])
      result = described_class.new(:X).evaluate(ctx)
      expect(result).to equal(val)
    end

    it 'finds a constant from an outer scope when not in inner' do
      outer = Frozone::Vm::ClassObject.new(:CROuter, nil, Frozone::Vm::Core::OBJECT_CLASS)
      inner = Frozone::Vm::ClassObject.new(:CRInner, nil, Frozone::Vm::Core::OBJECT_CLASS)
      val = Frozone::Vm::IntegerObject.new(99)
      outer.set_constant(:OUTER_C, val)
      ctx = make_context(scopes: [outer, inner])
      result = described_class.new(:OUTER_C).evaluate(ctx)
      expect(result).to equal(val)
    end

    it 'raises NameError when constant is not found' do
      scope = Frozone::Vm::ClassObject.new(:CRMiss, nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      expect { described_class.new(:MISSING_ZZ).evaluate(ctx) }
        .to raise_error(Frozone::Vm::FrozoneException, /uninitialized constant.*MISSING_ZZ/)
    end
  end

  describe '#to_s' do
    it 'includes the constant name' do
      expect(described_class.new(:MY_CONST).to_s).to include("MY_CONST")
    end
  end
end

RSpec.describe Frozone::Ast::ConstantWrite do
  describe '#initialize' do
    it 'accepts a symbol name and a value Node' do
      expect { described_class.new(:C, Frozone::Ast::NilLiteral::NIL) }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'sets the constant in the innermost scope' do
      scope = Frozone::Vm::ClassObject.new(:CWScope, nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      int_node = Frozone::Ast::IntegerLiteral.from(42)
      described_class.new(:ANSWER, int_node).evaluate(ctx)
      expect(scope.get_constant(:ANSWER).raw).to eq(42)
    end

    it 'returns the result of evaluating the value node' do
      scope = Frozone::Vm::ClassObject.new(:CWScope2, nil, Frozone::Vm::Core::OBJECT_CLASS)
      ctx = make_context(scopes: [scope])
      int_node = Frozone::Ast::IntegerLiteral.from(10)
      result = described_class.new(:N, int_node).evaluate(ctx)
      # ConstantWrite returns the result of set_constant which is the value
      # (Hash#[]=  returns the value in Ruby)
      expect(result.raw).to eq(10)
    end
  end

  describe '#to_s' do
    it 'includes the constant name' do
      expect(described_class.new(:MY_C, Frozone::Ast::NilLiteral::NIL).to_s).to include("MY_C")
    end
  end
end

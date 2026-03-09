require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::LocalVariableWrite do
  describe '#initialize' do
    it 'accepts a Symbol name, integer depth, and value Node' do
      expect {
        described_class.new(:x, 0, Frozone::Ast::NilLiteral::NIL)
      }.not_to raise_error
    end

    it 'raises when name is a String' do
      expect { described_class.new("x", 0, Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when depth is not an Integer' do
      expect { described_class.new(:x, "0", Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when value_node is not a Node' do
      expect { described_class.new(:x, 0, "bad") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'writes to a declared local and returns the value' do
      ctx = make_context(locals: [:x])
      node = described_class.new(:x, 0, Frozone::Ast::IntegerLiteral.from(42))
      result = node.evaluate(ctx)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(42)
      expect(ctx.frame.get_local(:x).raw).to eq(42)
    end

    it 'writes to an undeclared local' do
      ctx = make_context
      node = described_class.new(:y, 0, Frozone::Ast::IntegerLiteral.from(7))
      node.evaluate(ctx)
      expect(ctx.frame.get_local(:y).raw).to eq(7)
    end

    it 'overwrites a previously written local' do
      ctx = make_context(locals: [:n])
      described_class.new(:n, 0, Frozone::Ast::IntegerLiteral.from(1)).evaluate(ctx)
      described_class.new(:n, 0, Frozone::Ast::IntegerLiteral.from(2)).evaluate(ctx)
      expect(ctx.frame.get_local(:n).raw).to eq(2)
    end

    it 'returns the value of the expression (not nil)' do
      ctx = make_context(locals: [:z])
      result = described_class.new(:z, 0, Frozone::Ast::IntegerLiteral.from(99)).evaluate(ctx)
      expect(result.raw).to eq(99)
    end
  end

  describe '#to_s' do
    it 'includes the variable name' do
      node = described_class.new(:foo, 0, Frozone::Ast::NilLiteral::NIL)
      expect(node.to_s).to include("foo")
    end
  end
end

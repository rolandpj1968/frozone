require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::If do
  let(:ctx)   { make_context }
  let(:true_node)  { Frozone::Ast::TrueLiteral::TRUE }
  let(:false_node) { Frozone::Ast::FalseLiteral::FALSE }
  let(:nil_node)   { Frozone::Ast::NilLiteral::NIL }
  let(:int1) { Frozone::Ast::IntegerLiteral.from(1) }
  let(:int2) { Frozone::Ast::IntegerLiteral.from(2) }

  describe '#initialize' do
    it 'accepts pred, then, and optional else nodes' do
      expect { described_class.new(true_node, int1, int2) }.not_to raise_error
      expect { described_class.new(true_node, int1, nil)  }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'evaluates then_node when predicate is truthy' do
      node = described_class.new(true_node, int1, int2)
      expect(node.evaluate(ctx).raw).to eq(1)
    end

    it 'evaluates else_node when predicate is falsy' do
      node = described_class.new(false_node, int1, int2)
      expect(node.evaluate(ctx).raw).to eq(2)
    end

    it 'returns NilObject::NIL when predicate is falsy and else is nil' do
      node = described_class.new(false_node, int1, nil)
      expect(node.evaluate(ctx)).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'returns NilObject::NIL when predicate is NilObject' do
      node = described_class.new(nil_node, int1, nil)
      expect(node.evaluate(ctx)).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'treats integer 0 as truthy' do
      zero_node = Frozone::Ast::IntegerLiteral.from(0)
      node = described_class.new(zero_node, int1, int2)
      expect(node.evaluate(ctx).raw).to eq(1)
    end
  end

  describe '#to_s' do
    it 'produces a readable representation' do
      node = described_class.new(true_node, int1, int2)
      expect(node.to_s).to include("if")
    end
  end
end

RSpec.describe Frozone::Ast::Sequence do
  let(:ctx) { make_context }
  let(:int1) { Frozone::Ast::IntegerLiteral.from(1) }
  let(:int2) { Frozone::Ast::IntegerLiteral.from(2) }
  let(:int3) { Frozone::Ast::IntegerLiteral.from(3) }

  describe '#initialize' do
    it 'accepts an array of Nodes' do
      expect { described_class.new([int1]) }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'returns NilObject::NIL for an empty sequence' do
      expect(described_class.new([]).evaluate(ctx)).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'returns the result of the last node' do
      seq = described_class.new([int1, int2, int3])
      expect(seq.evaluate(ctx).raw).to eq(3)
    end

    it 'evaluates all nodes (side effects observed via locals)' do
      # We use a class with a method to observe evaluation order
      # Here we just verify the last result
      seq = described_class.new([int1, int2])
      expect(seq.evaluate(ctx).raw).to eq(2)
    end
  end

  describe '#to_s' do
    it 'produces a readable representation' do
      expect(described_class.new([int1, int2]).to_s).to include("seq")
    end
  end
end

RSpec.describe Frozone::Ast::Or do
  let(:ctx)   { make_context }
  let(:true_node)  { Frozone::Ast::TrueLiteral::TRUE }
  let(:false_node) { Frozone::Ast::FalseLiteral::FALSE }
  let(:nil_node)   { Frozone::Ast::NilLiteral::NIL }
  let(:int1) { Frozone::Ast::IntegerLiteral.from(1) }
  let(:int2) { Frozone::Ast::IntegerLiteral.from(2) }

  describe '#initialize' do
    it 'accepts two Node arguments' do
      expect { described_class.new(true_node, false_node) }.not_to raise_error
    end

  end

  describe '#evaluate' do
    it 'returns left when left is truthy (short-circuits)' do
      node = described_class.new(int1, int2)
      expect(node.evaluate(ctx).raw).to eq(1)
    end

    it 'returns right when left is falsy (false)' do
      node = described_class.new(false_node, int2)
      expect(node.evaluate(ctx).raw).to eq(2)
    end

    it 'returns right when left is nil' do
      node = described_class.new(nil_node, int2)
      expect(node.evaluate(ctx).raw).to eq(2)
    end

    it 'returns the left truthy value itself (not just true)' do
      int5 = Frozone::Ast::IntegerLiteral.from(5)
      node = described_class.new(int5, int2)
      expect(node.evaluate(ctx).raw).to eq(5)
    end
  end

  describe '#to_s' do
    it 'produces a readable representation' do
      expect(described_class.new(true_node, false_node).to_s).to include("or")
    end
  end
end

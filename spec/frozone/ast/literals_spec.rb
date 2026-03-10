require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::NilLiteral do
  describe '::NIL' do
    it 'is a singleton' do
      expect(described_class::NIL).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(described_class::NIL).to equal(described_class::NIL)
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns NilObject::NIL' do
      expect(described_class::NIL.evaluate(nil)).to equal(Frozone::Vm::NilObject::NIL)
    end
  end

  describe '#to_s' do
    it 'returns "nil"' do
      expect(described_class::NIL.to_s).to eq("nil")
    end
  end
end

RSpec.describe Frozone::Ast::TrueLiteral do
  describe '::TRUE' do
    it 'is a singleton' do
      expect(described_class::TRUE).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(described_class::TRUE).to equal(described_class::TRUE)
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns TrueObject::TRUE' do
      expect(described_class::TRUE.evaluate(nil)).to equal(Frozone::Vm::TrueObject::TRUE)
    end
  end

  describe '#to_s' do
    it 'returns "true"' do
      expect(described_class::TRUE.to_s).to eq("true")
    end
  end
end

RSpec.describe Frozone::Ast::FalseLiteral do
  describe '::FALSE' do
    it 'is a singleton' do
      expect(described_class::FALSE).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(described_class::FALSE).to equal(described_class::FALSE)
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns FalseObject::FALSE' do
      expect(described_class::FALSE.evaluate(nil)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '#to_s' do
    it 'returns "false"' do
      expect(described_class::FALSE.to_s).to eq("false")
    end
  end
end

RSpec.describe Frozone::Ast::SelfLiteral do
  describe '::SELF' do
    it 'is a singleton' do
      expect(described_class::SELF).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(described_class::SELF).to equal(described_class::SELF)
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns the_self from the current frame' do
      ctx = make_context
      the_self = ctx.frame.the_self
      expect(described_class::SELF.evaluate(ctx)).to equal(the_self)
    end
  end

  describe '#to_s' do
    it 'returns "self"' do
      expect(described_class::SELF.to_s).to eq("self")
    end
  end
end

RSpec.describe Frozone::Ast::IntegerLiteral do
  describe '.from' do
    it 'returns an IntegerLiteral' do
      expect(described_class.from(42)).to be_a(described_class)
    end

    it 'returns the same object for the same value (interned)' do
      expect(described_class.from(7)).to equal(described_class.from(7))
    end

    it 'returns different objects for different values' do
      expect(described_class.from(1)).not_to equal(described_class.from(2))
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new(Frozone::Vm::IntegerObject.new(1)) }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns an IntegerObject with the literal value' do
      result = described_class.from(42).evaluate(nil)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(42)
    end

    it 'always returns the same IntegerObject (no copy)' do
      lit = described_class.from(5)
      expect(lit.evaluate(nil)).to equal(lit.evaluate(nil))
    end
  end

  describe '#to_s' do
    it 'includes the value' do
      expect(described_class.from(99).to_s).to include("99")
    end
  end
end

RSpec.describe Frozone::Ast::StringLiteral do
  describe '.from' do
    it 'returns a StringLiteral' do
      expect(described_class.from("hello")).to be_a(described_class)
    end

    it 'returns the same object for the same string (interned)' do
      expect(described_class.from("abc")).to equal(described_class.from("abc"))
    end

    it 'returns different objects for different strings' do
      expect(described_class.from("x")).not_to equal(described_class.from("y"))
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new(Frozone::Vm::StringObject.new("x")) }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns a StringObject with the literal value' do
      result = described_class.from("hello").evaluate(nil)
      expect(result).to be_a(Frozone::Vm::StringObject)
      expect(result.raw).to eq("hello")
    end

    it 'returns a copy (dup) each time to avoid mutation aliasing' do
      lit = described_class.from("dup_test")
      expect(lit.evaluate(nil)).not_to equal(lit.evaluate(nil))
    end
  end

  describe '#to_s' do
    it 'includes the string value' do
      expect(described_class.from("world").to_s).to include("world")
    end
  end
end

RSpec.describe Frozone::Ast::SymbolLiteral do
  describe '.from' do
    it 'accepts a string and converts to symbol' do
      result = described_class.from("foo")
      expect(result).to be_a(described_class)
    end

    it 'accepts a symbol directly' do
      result = described_class.from(:bar)
      expect(result).to be_a(described_class)
    end

    it 'returns the same object for the same name (interned)' do
      expect(described_class.from(:foo)).to equal(described_class.from(:foo))
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new(Frozone::Vm::SymbolObject.from(:x)) }.to raise_error(NoMethodError)
    end
  end

  describe '#evaluate' do
    it 'returns a SymbolObject with the literal value' do
      result = described_class.from(:hello).evaluate(nil)
      expect(result).to be_a(Frozone::Vm::SymbolObject)
      expect(result.raw).to eq(:hello)
    end

    it 'always returns the same SymbolObject (interned)' do
      lit = described_class.from(:sym)
      expect(lit.evaluate(nil)).to equal(lit.evaluate(nil))
    end
  end

  describe '#to_s' do
    it 'includes the symbol name' do
      expect(described_class.from(:my_sym).to_s).to include("my_sym")
    end
  end
end

RSpec.describe Frozone::Ast::ArrayLiteral do
  describe '#initialize' do
    it 'accepts an array of Nodes' do
      expect { described_class.new([]) }.not_to raise_error
    end

    it 'raises when elements are not Nodes' do
      expect { described_class.new(["not a node"]) }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'returns an empty ArrayObject for an empty literal' do
      result = described_class.new([]).evaluate(make_context)
      expect(result).to be_a(Frozone::Vm::ArrayObject)
      expect(result.raw).to be_empty
    end

    it 'evaluates each element node and collects results' do
      nodes = [Frozone::Ast::IntegerLiteral.from(1), Frozone::Ast::IntegerLiteral.from(2)]
      result = described_class.new(nodes).evaluate(make_context)
      expect(result.raw.map(&:raw)).to eq([1, 2])
    end
  end
end

RSpec.describe Frozone::Ast::HashLiteral do
  describe '#initialize' do
    it 'accepts an array of [Node, Node] pairs' do
      expect { described_class.new([]) }.not_to raise_error
    end

    it 'accepts [nil, Node] pairs for double-splat elements' do
      # nil key represents a **splat element
      expect { described_class.new([[nil, Frozone::Ast::NilLiteral::NIL]]) }.not_to raise_error
    end
  end

  describe '#evaluate' do
    it 'returns an empty HashObject for an empty literal' do
      result = described_class.new([]).evaluate(make_context)
      expect(result).to be_a(Frozone::Vm::HashObject)
      expect(result.raw).to be_empty
    end

    it 'evaluates key and value nodes and builds a HashObject' do
      k_node = Frozone::Ast::SymbolLiteral.from(:x)
      v_node = Frozone::Ast::IntegerLiteral.from(99)
      result = described_class.new([[k_node, v_node]]).evaluate(make_context)
      expect(result).to be_a(Frozone::Vm::HashObject)
      key = Frozone::Vm::SymbolObject.from(:x)
      expect(result.raw[key].raw).to eq(99)
    end
  end
end

RSpec.describe Frozone::Ast::FloatLiteral do
  describe '.from' do
    it 'returns a FloatLiteral' do
      expect(described_class.from(3.14)).to be_a(described_class)
    end
  end

  describe '#initialize' do
    it 'raises when given a non-Float' do
      expect { described_class.from(1) }.to raise_error(RuntimeError)
    end
  end

  describe '#to_s' do
    it 'includes the float value' do
      expect(described_class.from(2.5).to_s).to include("2.5")
    end
  end
end

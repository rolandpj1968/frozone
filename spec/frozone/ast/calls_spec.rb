require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::IntrinsicCall do
  describe '#initialize' do
    it 'accepts a valid intrinsic method name and param nodes' do
      expect { described_class.new(:integer__plus_, []) }.not_to raise_error
    end

    it 'raises when method name does not exist in Intrinsics' do
      expect { described_class.new(:nonexistent_intrinsic_zz, []) }.to raise_error(NameError)
    end

    it 'raises when param_nodes are not Nodes' do
      expect { described_class.new(:integer__plus_, ["bad"]) }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'calls the intrinsic and returns the result' do
      i3 = Frozone::Ast::IntegerLiteral.from(3)
      i5 = Frozone::Ast::IntegerLiteral.from(5)
      node = described_class.new(:integer__plus_, [i3, i5])
      result = node.evaluate(make_context)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(8)
    end

    it 'evaluates comparison intrinsics returning TrueObject / FalseObject' do
      i3 = Frozone::Ast::IntegerLiteral.from(3)
      i5 = Frozone::Ast::IntegerLiteral.from(5)
      node = described_class.new(:integer__lt_, [i3, i5])
      expect(node.evaluate(make_context)).to equal(Frozone::Vm::TrueObject::TRUE)
    end
  end

  describe '#to_s' do
    it 'includes the method name' do
      node = described_class.new(:integer__plus_, [])
      expect(node.to_s).to include("integer__plus_")
    end
  end
end

RSpec.describe Frozone::Ast::MethodCall do
  let(:klass)    { Frozone::Vm::ClassObject.new(:MCTestClass, nil, Frozone::Vm::Core::OBJECT_CLASS) }
  let(:receiver_obj) { Frozone::Vm::ObjectObject.new(klass) }

  describe '#initialize' do
    it 'accepts name, nil receiver, arg_nodes, and kw_arg_nodes' do
      expect { described_class.new(:foo, nil, [], {}) }.not_to raise_error
    end

    it 'raises when name is not a Symbol' do
      expect { described_class.new("foo", nil, [], {}) }.to raise_error(RuntimeError)
    end

    it 'raises when arg_nodes contains a non-Node' do
      expect { described_class.new(:foo, nil, ["bad"], {}) }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'calls a method on an explicit receiver' do
      m = make_method(klass, :answer, body: Frozone::Ast::IntegerLiteral.from(42))
      klass.set_method(:answer, m)
      receiver_node = Frozone::Ast::SelfLiteral::SELF
      ctx = make_context(the_self: receiver_obj, scopes: [klass])
      node = described_class.new(:answer, receiver_node, [], {})
      expect(node.evaluate(ctx).raw).to eq(42)
    end

    it 'calls a method on implicit self when receiver_node is nil' do
      m = make_method(klass, :ping, body: Frozone::Ast::IntegerLiteral.from(1))
      klass.set_method(:ping, m)
      ctx = make_context(the_self: receiver_obj, scopes: [klass])
      node = described_class.new(:ping, nil, [], {})
      expect(node.evaluate(ctx).raw).to eq(1)
    end

    it 'passes arguments to the method' do
      m = make_method(klass, :echo, body: Frozone::Ast::LocalVariableRead.new(:x, 0),
                      required_params: [:x])
      klass.set_method(:echo, m)
      ctx = make_context(the_self: receiver_obj, scopes: [klass])
      node = described_class.new(:echo, nil, [Frozone::Ast::IntegerLiteral.from(7)], {})
      expect(node.evaluate(ctx).raw).to eq(7)
    end

    it 'raises when method is not found' do
      ctx = make_context(the_self: receiver_obj, scopes: [klass])
      node = described_class.new(:no_such_method_zz, nil, [], {})
      expect { node.evaluate(ctx) }.to raise_error(Frozone::Vm::FrozoneException, /undefined method/)
    end
  end

  describe '#to_s' do
    it 'includes the method name' do
      expect(described_class.new(:foo, nil, [], {}).to_s).to include("foo")
    end
  end
end

RSpec.describe Frozone::Ast::MethodDef do
  let(:scope) { Frozone::Vm::ClassObject.new(:MDScope, nil, Frozone::Vm::Core::OBJECT_CLASS) }
  let(:ctx)   { make_context(scopes: [scope]) }

  describe '#initialize' do
    it 'accepts a valid method definition' do
      expect {
        described_class.new(:foo, nil, [], [], nil, [], [], [], nil, nil, [], Frozone::Ast::NilLiteral::NIL)
      }.not_to raise_error
    end

    it 'raises when name is not a Symbol' do
      expect {
        described_class.new("foo", nil, [], [], nil, [], [], [], nil, nil, [], Frozone::Ast::NilLiteral::NIL)
      }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'defines a method on the current scope' do
      node = described_class.new(:my_method, nil, [], [], nil, [], [], [], nil, nil, [],
                                 Frozone::Ast::IntegerLiteral.from(99))
      node.evaluate(ctx)
      expect(scope.get_method(:my_method)).to be_a(Frozone::Vm::Method)
    end

    it 'returns a SymbolObject naming the method' do
      node = described_class.new(:defined_method, nil, [], [], nil, [], [], [], nil, nil, [],
                                 Frozone::Ast::NilLiteral::NIL)
      result = node.evaluate(ctx)
      expect(result).to be_a(Frozone::Vm::SymbolObject)
      expect(result.raw).to eq(:defined_method)
    end

    it 'defined method is callable and returns its body result' do
      node = described_class.new(:calc, nil, [], [], nil, [], [], [], nil, nil, [],
                                 Frozone::Ast::IntegerLiteral.from(7))
      node.evaluate(ctx)
      method = scope.get_method(:calc)
      receiver = Frozone::Vm::ObjectObject.new(scope)
      result = method.invoke(ctx, receiver, [], {})
      expect(result.raw).to eq(7)
    end
  end
end

RSpec.describe Frozone::Ast::MethodAlias do
  let(:scope) { Frozone::Vm::ClassObject.new(:MAScope, nil, Frozone::Vm::Core::OBJECT_CLASS) }
  let(:ctx)   { make_context(scopes: [scope]) }

  before do
    original = make_method(scope, :original, body: Frozone::Ast::IntegerLiteral.from(42))
    scope.set_method(:original, original)
  end

  describe '#initialize' do
    it 'accepts two symbol names' do
      expect { described_class.new(:new_name, :old_name) }.not_to raise_error
    end

    it 'raises when new_name is not a Symbol' do
      expect { described_class.new("new", :old) }.to raise_error(RuntimeError)
    end

    it 'raises when old_name is not a Symbol' do
      expect { described_class.new(:new, "old") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'creates an alias so the new name calls the same body' do
      described_class.new(:alias_method, :original).evaluate(ctx)
      aliased = scope.get_method(:alias_method)
      expect(aliased).not_to be_nil
      receiver = Frozone::Vm::ObjectObject.new(scope)
      expect(aliased.invoke(ctx, receiver, [], {}).raw).to eq(42)
    end

    it 'returns a SymbolObject of the new name' do
      result = described_class.new(:another_alias, :original).evaluate(ctx)
      expect(result).to be_a(Frozone::Vm::SymbolObject)
      expect(result.raw).to eq(:another_alias)
    end

    it 'raises when the original method does not exist' do
      node = described_class.new(:new_name, :no_such_method_zz)
      expect { node.evaluate(ctx) }.to raise_error(RuntimeError, /undefined method/)
    end
  end
end

RSpec.describe Frozone::Ast::ClassDef do
  let(:outer_scope) { Frozone::Vm::ClassObject.new(:CDOuter, nil, Frozone::Vm::Core::OBJECT_CLASS) }
  let(:ctx)         { make_context(scopes: [outer_scope]) }

  describe '#initialize' do
    it 'accepts a symbol name, empty locals, optional superclass node, and a body Node' do
      expect { described_class.new(:MyClass, [], nil, Frozone::Ast::NilLiteral::NIL) }.not_to raise_error
    end

    it 'raises when name is not a Symbol' do
      expect { described_class.new("Bad", [], nil, Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when body is not a Node' do
      expect { described_class.new(:MyClass, [], nil, "bad") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'creates a new ClassObject constant in the current scope' do
      described_class.new(:NewClass, [], nil, Frozone::Ast::NilLiteral::NIL).evaluate(ctx)
      expect(outer_scope.get_constant(:NewClass)).to be_a(Frozone::Vm::ClassObject)
    end

    it 'finds an existing class on re-evaluation instead of creating a new one' do
      node = described_class.new(:ExistingClass, [], nil, Frozone::Ast::NilLiteral::NIL)
      node.evaluate(ctx)
      first_class = outer_scope.get_constant(:ExistingClass)
      node.evaluate(ctx)
      second_class = outer_scope.get_constant(:ExistingClass)
      expect(second_class).to equal(first_class)
    end

    it 'evaluates the body within the class scope' do
      # body defines a method on the class
      method_def_node = described_class::new(  # using ClassDef to wrap MethodDef test
        :BodyTestClass,
        [],
        nil,
        Frozone::Ast::MethodDef.new(:inner_method, nil, [], [], nil, [], [], [], nil, nil, [],
                                    Frozone::Ast::IntegerLiteral.from(55))
      )
      method_def_node.evaluate(ctx)
      klass = outer_scope.get_constant(:BodyTestClass)
      expect(klass.get_method(:inner_method)).to be_a(Frozone::Vm::Method)
    end

    it 'raises when the constant names a non-class' do
      outer_scope.set_constant(:NotAClass, Frozone::Vm::IntegerObject.new(1))
      ctx2 = make_context(scopes: [outer_scope])
      expect {
        described_class.new(:NotAClass, [], nil, Frozone::Ast::NilLiteral::NIL).evaluate(ctx2)
      }.to raise_error(RuntimeError, /not a class/)
    end

    it 'sets namespace to nil when enclosing scope is OBJECT_CLASS' do
      object_scope = Frozone::Vm::Core::OBJECT_CLASS
      ctx_top = make_context(scopes: [object_scope])
      described_class.new(:TopLevelClass, [], nil, Frozone::Ast::NilLiteral::NIL).evaluate(ctx_top)
      klass = object_scope.get_constant(:TopLevelClass)
      expect(klass.instance_variable_get(:@namespace)).to be_nil
    end

    it 'sets namespace to enclosing scope when nested inside a class' do
      described_class.new(:NestedClass, [], nil, Frozone::Ast::NilLiteral::NIL).evaluate(ctx)
      klass = outer_scope.get_constant(:NestedClass)
      expect(klass.instance_variable_get(:@namespace)).to equal(outer_scope)
    end
  end
end

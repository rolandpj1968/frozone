require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/analysis/passes/type_inference_pass'
require_relative '../../../../../lib/frozone/compiler/analysis/engine'
require_relative '../../../../../lib/frozone/ast/integer_literal'
require_relative '../../../../../lib/frozone/ast/float_literal'
require_relative '../../../../../lib/frozone/ast/nil_literal'
require_relative '../../../../../lib/frozone/ast/true_literal'
require_relative '../../../../../lib/frozone/ast/false_literal'
require_relative '../../../../../lib/frozone/ast/local_variable_read'
require_relative '../../../../../lib/frozone/ast/local_variable_write'
require_relative '../../../../../lib/frozone/ast/if'
require_relative '../../../../../lib/frozone/ast/return'
require_relative '../../../../../lib/frozone/ast/method_call'
require_relative '../../../../../lib/frozone/ast/self_literal'
require_relative '../../../../../lib/frozone/ast/intrinsic_call'

RSpec.describe Frozone::Compiler::Analysis::Passes::TypeInferencePass do
  let(:vm) { Frozone::Vm }
  let(:ast) { Frozone::Ast }

  # A minimal closed-world hierarchy for the tests.
  let(:hierarchy) do
    basic = vm::ClassObject.new(:BasicObject, nil, nil)
    object = vm::ClassObject.new(:Object, nil, basic)
    numeric = vm::ClassObject.new(:Numeric, nil, object)
    integer = vm::ClassObject.new(:Integer, nil, numeric)
    float = vm::ClassObject.new(:Float, nil, numeric)
    string = vm::ClassObject.new(:String, nil, object)
    true_c = vm::ClassObject.new(:TrueClass, nil, object)
    false_c = vm::ClassObject.new(:FalseClass, nil, object)
    nil_c = vm::ClassObject.new(:NilClass, nil, object)
    foo = vm::ClassObject.new(:Foo, nil, object)
    {
      BasicObject: basic, Object: object, Numeric: numeric,
      Integer:    integer, Float:    float, String: string,
      TrueClass:  true_c, FalseClass: false_c, NilClass: nil_c,
      Foo:        foo
    }
  end

  # Minimal Vm::Method shim carrying just what the pass reads.
  def make_method(body, required_params: [], optional_params: [])
    m = double('Vm::Method',
      required_params: required_params,
      optional_params: optional_params,
      rest_param: nil,
      body: body,
    )
    allow(m).to receive(:respond_to?).and_return(false)
    allow(m).to receive(:respond_to?).with(:rest_param).and_return(true)
    m
  end

  def run_pass(methods, mode: :eager)
    pass = described_class.new(methods: methods, all_classes: hierarchy)
    engine = Frozone::Compiler::Analysis::Engine.new(pass, mode: mode)
    engine.run
    pass
  end

  # For readability in expectations.
  def t(sym, nullable: false)
    Frozone::Compiler::Analysis::TypeLattice.new(hierarchy).concrete(sym, nullable: nullable)
  end

  describe 'literal return types' do
    it 'infers Integer for a method returning an Integer literal' do
      body = ast::IntegerLiteral.from(42)
      methods = { [:Foo, :answer] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'infers Float for Float literal' do
      body = ast::FloatLiteral.new(3.14)
      methods = { [:Foo, :pi] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float))
    end

    it 'infers TrueClass / FalseClass separately' do
      body_t = ast::TrueLiteral::TRUE
      body_f = ast::FalseLiteral::FALSE
      methods = { [:Foo, :t] => make_method(body_t), [:Foo, :f] => make_method(body_f) }
      pass = run_pass(methods)
      expect(pass.type_of(body_t)).to eq(t(:TrueClass))
      expect(pass.type_of(body_f)).to eq(t(:FalseClass))
    end

    it 'infers NilClass for nil literal' do
      body = ast::NilLiteral::NIL
      methods = { [:Foo, :nada] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:NilClass))
    end
  end

  describe 'local variables (flow-insensitive)' do
    it 'reads back the type written to a local' do
      write = ast::LocalVariableWrite.new(:x, 0, ast::IntegerLiteral.from(1))
      read  = ast::LocalVariableRead.new(:x, 0)
      # body = write; read  — represented as a MethodCall's arg-list would
      # in real code. For the unit test we just walk each in turn against
      # the same context by making the read the tail: the pass caches types
      # per-node, so we can check both.
      body = ast::MethodCall.new(:puts, nil, [write, read], [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(write)).to eq(t(:Integer))
      expect(pass.type_of(read)).to  eq(t(:Integer))
    end

    it 'joins writes: two writes of different types → their LUB' do
      w1 = ast::LocalVariableWrite.new(:y, 0, ast::IntegerLiteral.from(1))
      w2 = ast::LocalVariableWrite.new(:y, 0, ast::FloatLiteral.new(2.0))
      r  = ast::LocalVariableRead.new(:y, 0)
      body = ast::MethodCall.new(:noop, nil, [w1, w2, r], [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(r)).to eq(t(:Numeric))
    end

    it 'defaults to top for a param' do
      # method(:m, [:p]) => body is just `p`
      p_read = ast::LocalVariableRead.new(:p, 0)
      body = p_read
      methods = { [:Foo, :m] => make_method(body, required_params: [:p]) }
      pass = run_pass(methods)
      expect(pass.type_of(p_read).top?).to be true
    end
  end

  describe 'If expressions' do
    it 'joins branches when both are present' do
      body = ast::If.new(ast::TrueLiteral::TRUE,
                        ast::IntegerLiteral.from(1),
                        ast::FloatLiteral.new(2.0))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Numeric))
    end

    it 'produces nullable when there is no else branch' do
      body = ast::If.new(ast::TrueLiteral::TRUE,
                        ast::IntegerLiteral.from(1),
                        nil)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer, nullable: true))
    end

    it 'when both arms are Integer, result is Integer (no widening)' do
      body = ast::If.new(ast::TrueLiteral::TRUE,
                        ast::IntegerLiteral.from(1),
                        ast::IntegerLiteral.from(2))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end
  end

  describe 'Return' do
    it 'contributes to the method return type' do
      # `return 42` at top level of body — walk returns ⊥ for the
      # expression, but the pass's return-type collector captures Integer.
      body = ast::Return.new(ast::IntegerLiteral.from(42))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # Check the ENGINE's value for the method — that's the actual
      # inferred return type.
      key = described_class.method_node(:Foo, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value).to eq(t(:Integer))
    end
  end

  describe 'MethodCall recursion' do
    it 'converges on a method that returns a literal Integer' do
      # def m; 42; end  — MethodCall to :m from another method resolves
      # via the engine's fixpoint.
      inner_body = ast::IntegerLiteral.from(42)
      call = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [], [])
      outer_body = call
      methods = {
        [:Foo, :m]     => make_method(inner_body),
        [:Foo, :outer] => make_method(outer_body),
      }
      pass = run_pass(methods)
      # `self` inside outer_body is Foo → call to :m on Foo resolves to
      # Foo.m which returns Integer.
      expect(pass.type_of(call)).to eq(t(:Integer))
    end

    it 'yields top for a method call with unknown receiver' do
      # `some_var.foo` where some_var was never written → ⊤
      recv = ast::LocalVariableRead.new(:x, 0)  # x is undefined → ⊤
      call = ast::MethodCall.new(:foo, recv, [], [])
      methods = { [:Foo, :m] => make_method(call) }
      pass = run_pass(methods)
      expect(pass.type_of(call).top?).to be true
    end
  end

  describe 'MethodCall ancestor-chain walk (universe = user, no special case)' do
    it 'finds a method defined on the receiver class directly' do
      # class Foo; def bar; 42; end; end
      # class Zap; def m; Foo.new.bar; end; end
      # (elided: Foo.new — we just test that Foo#bar resolves to Integer)
      bar_body = ast::IntegerLiteral.from(42)
      recv = ast::LocalVariableWrite.new(:x, 0, ast::MethodCall.new(:noop, nil, [], []))
      # Simpler: put the whole recv path into env with Foo type by writing.
      # Actually simplest — call Foo#bar directly from Foo#outer via self.
      outer_call = ast::MethodCall.new(:bar, ast::SelfLiteral::SELF, [], [])
      methods = {
        [:Foo, :bar]   => make_method(bar_body),
        [:Foo, :outer] => make_method(outer_call),
      }
      pass = run_pass(methods)
      expect(pass.type_of(outer_call)).to eq(t(:Integer))
    end

    it 'finds a method defined on the receiver`s superclass' do
      # class Numeric; def sign; 1; end; end
      # class Integer < Numeric; ; end
      # class Foo; def m; some_int.sign; end; end
      # where some_int has type Integer.
      sign_body = ast::IntegerLiteral.from(1)
      # some_int : Integer via a write, then read + call.
      # To keep the test simple: use self of Foo, cast to Integer via
      # a MethodCall on Foo that returns Integer, then call sign.
      # Even simpler — manually seed a local as Integer via an
      # IntrinsicCall whose annotation is Integer, then call sign.
      int_from_intrinsic = ast::IntrinsicCall.new(:integer_to_s, [ast::IntegerLiteral.from(1)])
      # Oops, that returns String. Use integer__plus_.
      int_from_intrinsic = ast::IntrinsicCall.new(:integer__plus_, [
        ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
      ])
      w = ast::LocalVariableWrite.new(:x, 0, int_from_intrinsic)
      r = ast::LocalVariableRead.new(:x, 0)
      call = ast::MethodCall.new(:sign, r, [], [])
      body = ast::MethodCall.new(:noop, nil, [w, call], [])

      methods = {
        [:Numeric, :sign] => make_method(sign_body),
        [:Foo, :m]        => make_method(body),
      }
      pass = run_pass(methods)
      # Integer inherits from Numeric — sign found via chain walk.
      expect(pass.type_of(call)).to eq(t(:Integer))
    end

    it 'returns ⊤ when the method is not found anywhere on the ancestor chain' do
      # No `unknown_method` defined anywhere.
      recv = ast::LocalVariableWrite.new(:x, 0,
        ast::IntrinsicCall.new(:integer__plus_, [
          ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
        ]))
      call = ast::MethodCall.new(:unknown_method, ast::LocalVariableRead.new(:x, 0), [], [])
      body = ast::MethodCall.new(:noop, nil, [recv, call], [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(call).top?).to be true
    end

    it 'a universe class (e.g. Integer) is not special — its methods walk the same way' do
      # This is the key test: put Integer#to_i in @methods just like a
      # user class, and TI resolves it identically. No universe-specific
      # code path.
      to_i_body = ast::IntrinsicCall.new(:integer__plus_, [
        ast::IntegerLiteral.from(0), ast::IntegerLiteral.from(0)
      ])  # returns Integer per the intrinsic annotation
      call = ast::MethodCall.new(:to_i,
        ast::IntrinsicCall.new(:integer__plus_, [
          ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
        ]),
        [], [])
      methods = {
        [:Integer, :to_i] => make_method(to_i_body),
        [:Foo, :m]        => make_method(call),
      }
      pass = run_pass(methods)
      expect(pass.type_of(call)).to eq(t(:Integer))
    end
  end

  describe 'IntrinsicCall — annotated return type via INTRINSIC_RETURN_TYPES' do
    it 'infers Integer for integer__plus_' do
      body = ast::IntrinsicCall.new(:integer__plus_, [
        ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
      ])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'infers Float for integer_to_f' do
      body = ast::IntrinsicCall.new(:integer_to_f, [ast::IntegerLiteral.from(1)])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float))
    end

    it 'infers <boolean> for basic_object__equal_equal_' do
      body = ast::IntrinsicCall.new(:basic_object__equal_equal_, [
        ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
      ])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # <boolean> is the synthetic union of TrueClass | FalseClass.
      expect(pass.type_of(body).boolean_synth?).to be true
    end

    it 'infers nullable when annotation carries nullable: true' do
      body = ast::IntrinsicCall.new(:string_slice, [ast::IntegerLiteral.from(0), ast::IntegerLiteral.from(3)])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:String, nullable: true))
    end

    it 'defaults to ⊤ for an unannotated intrinsic (annotation-missing => safe)' do
      body = ast::IntrinsicCall.new(:not_declared_anywhere, [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end

    it 'infers ⊤ when annotation is :__top__' do
      # hash_delete's value type is genuinely unknown at annotation
      # time — the value came from user code with no shared type
      # discipline. Declared explicitly to distinguish "unannotated"
      # (bug) from "unannotable" (semantic ⊤).
      body = ast::IntrinsicCall.new(:hash_delete, [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end
  end

  describe 'engine value map' do
    it 'stores each method-return-type node under [:method, C, m]' do
      body = ast::IntegerLiteral.from(1)
      methods = { [:Foo, :one] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy)
      values = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values
      expect(values[described_class.method_node(:Foo, :one)]).to eq(t(:Integer))
    end
  end
end

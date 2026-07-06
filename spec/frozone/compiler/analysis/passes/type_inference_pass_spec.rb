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
require_relative '../../../../../lib/frozone/ast/constant_read'
require_relative '../../../../../lib/frozone/ast/sequence'
require_relative '../../../../../lib/frozone/ast/break'
require_relative '../../../../../lib/frozone/ast/next'
require_relative '../../../../../lib/frozone/ast/redo'
require_relative '../../../../../lib/frozone/ast/retry'
require_relative '../../../../../lib/frozone/ast/while'
require_relative '../../../../../lib/frozone/ast/until'
require_relative '../../../../../lib/frozone/ast/for_loop'
require_relative '../../../../../lib/frozone/ast/array_literal'

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

  describe 'Sequence' do
    it 'types as the last child' do
      # `_ = 1; 3.14` — result is Float
      first = ast::IntegerLiteral.from(1)
      last = ast::FloatLiteral.new(3.14)
      body = ast::Sequence.new([first, last])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float))
      # Both children are cached.
      expect(pass.type_of(first)).to eq(t(:Integer))
      expect(pass.type_of(last)).to eq(t(:Float))
    end

    it 'walks all children — writes in earlier statements feed later reads' do
      # `x = 1; x` — env captures Integer at write, read returns Integer
      write = ast::LocalVariableWrite.new(:x, 0, ast::IntegerLiteral.from(1))
      read = ast::LocalVariableRead.new(:x, 0)
      body = ast::Sequence.new([write, read])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
      expect(pass.type_of(read)).to eq(t(:Integer))
    end

    it 'empty sequence types as NilClass' do
      body = ast::Sequence.new([])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:NilClass))
    end

    it 'trailing Return makes the sequence divergent but return_joins captures the value' do
      # `x = 1; return 42` — sequence type = ⊥, method return = Integer.
      body = ast::Sequence.new([
        ast::LocalVariableWrite.new(:x, 0, ast::IntegerLiteral.from(1)),
        ast::Return.new(ast::IntegerLiteral.from(42)),
      ])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).bottom?).to be true
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[described_class.method_node(:Foo, :m)]
      expect(engine_value).to eq(t(:Integer))
    end
  end

  describe 'divergent jumps (Break/Next/Redo/Retry)' do
    it 'Break diverges — expression type is ⊥' do
      body = ast::Break.new(ast::IntegerLiteral.from(1))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).bottom?).to be true
    end

    it 'Next diverges — expression type is ⊥' do
      body = ast::Next.new(ast::IntegerLiteral.from(1))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).bottom?).to be true
    end

    it 'Redo diverges — expression type is ⊥' do
      body = ast::Redo.new
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).bottom?).to be true
    end

    it 'Retry diverges — expression type is ⊥' do
      body = ast::Retry.new
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).bottom?).to be true
    end

    it 'Break without break scope silently drops the value type (LocalJumpError at runtime)' do
      # No enclosing loop or block-catching frame — break_joins stack
      # is empty, so nothing to push onto. Type-inference stays ⊥.
      body = ast::Break.new(ast::IntegerLiteral.from(1))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # Method's return type: only the terminal (⊥) — collapses to ⊤
      # per the "no-op divergent" rule.
      key = described_class.method_node(:Foo, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value.top?).to be true
    end
  end

  describe 'While / Until' do
    it 'plain while returns NilClass' do
      # while true; end  — no break, no body
      body = ast::While.new(ast::TrueLiteral::TRUE, ast::NilLiteral::NIL)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:NilClass))
    end

    it 'while with break-with-value joins NilClass and the break value' do
      # while true; break 42; end  → nil ∪ Integer → Integer? (nullable Integer)
      brk = ast::Break.new(ast::IntegerLiteral.from(42))
      body = ast::While.new(ast::TrueLiteral::TRUE, brk)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer, nullable: true))
    end

    it 'until behaves the same as while (nil-return, break-joined)' do
      brk = ast::Break.new(ast::FloatLiteral.new(1.5))
      body = ast::Until.new(ast::FalseLiteral::FALSE, brk)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float, nullable: true))
    end

    it 'multiple break values are joined into their LUB' do
      # while true; if cond; break 1; else break 1.5; end; end
      brk_a = ast::Break.new(ast::IntegerLiteral.from(1))
      brk_b = ast::Break.new(ast::FloatLiteral.new(1.5))
      if_body = ast::If.new(ast::TrueLiteral::TRUE, brk_a, brk_b)
      body = ast::While.new(ast::TrueLiteral::TRUE, if_body)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # Break contribs: Integer, Float → LUB = Numeric. Loop join: nil
      # ∪ Numeric = Numeric?.
      expect(pass.type_of(body)).to eq(t(:Numeric, nullable: true))
    end

    it 'nested loops: inner break contributes to inner scope only' do
      # while true; while true; break 42; end; end
      #   inner loop → Integer? ; outer loop → nil (no break there)
      inner_brk = ast::Break.new(ast::IntegerLiteral.from(42))
      inner = ast::While.new(ast::TrueLiteral::TRUE, inner_brk)
      outer = ast::While.new(ast::TrueLiteral::TRUE, inner)
      methods = { [:Foo, :m] => make_method(outer) }
      pass = run_pass(methods)
      expect(pass.type_of(inner)).to eq(t(:Integer, nullable: true))
      expect(pass.type_of(outer)).to eq(t(:NilClass))
    end
  end

  describe 'ForLoop' do
    it 'returns the collection type when there is no break' do
      # for x in [1,2,3]; x; end  →  Array
      arr = ast::ArrayLiteral.new([])
      body = ast::LocalVariableRead.new(:x, 0)
      loop_node = ast::ForLoop.new([:local, :x], arr, body)
      methods = { [:Foo, :m] => make_method(loop_node) }
      pass = run_pass(methods)
      expect(pass.type_of(loop_node)).to eq(t(:Array))
    end

    it 'joins collection type with break-with-value' do
      # for x in [1]; break "s"; end  →  Array ∪ String → BasicObject
      # under this spec's hierarchy (Array not in the class map, so the
      # LUB walk falls all the way to BasicObject).
      arr = ast::ArrayLiteral.new([])
      brk = ast::Break.new(ast::StringLiteral.from('s'))
      loop_node = ast::ForLoop.new([:local, :x], arr, brk)
      methods = { [:Foo, :m] => make_method(loop_node) }
      pass = run_pass(methods)
      expect(pass.type_of(loop_node)).to eq(t(:BasicObject))
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

  describe 'class-value peek-through for .new / .allocate' do
    it 'infers the class from a bare ConstantRead receiver on .new' do
      # Foo.new  — receiver AST resolves to Foo, so .new returns Foo.
      body = ast::MethodCall.new(:new, ast::ConstantRead.new(:Foo), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Foo))
    end

    it 'infers the class from a bare ConstantRead receiver on .allocate' do
      body = ast::MethodCall.new(:allocate, ast::ConstantRead.new(:Integer), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'falls through to normal dispatch when receiver isn`t a ConstantRead' do
      # cls = Foo; cls.new — LocalVariableRead receiver, no peek.
      w = ast::LocalVariableWrite.new(:cls, 0, ast::ConstantRead.new(:Foo))
      r = ast::LocalVariableRead.new(:cls, 0)
      call = ast::MethodCall.new(:new, r, [], [])
      body = ast::MethodCall.new(:noop, nil, [w, call], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      # Falls through: no annotation for Class#new in our test @methods,
      # ancestor walk on receiver's TYPE (which is ⊤ since ConstantRead
      # types as ⊤ until we add ConstantRead handling) → ⊤.
      expect(pass.type_of(call).top?).to be true
    end

    it 'does not peek for methods other than .new / .allocate' do
      # Foo.some_class_method — receiver is a ConstantRead but the
      # method isn't a class-value primitive, so no peek. Falls through
      # to ancestor walk (⊤ here since no method registered).
      body = ast::MethodCall.new(:some_class_method, ast::ConstantRead.new(:Foo), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end

    it 'does not peek when the ConstantRead name is unknown' do
      # NoSuchClass.new — receiver is a ConstantRead but the name
      # doesn't match any class we know about → no peek, fall through.
      body = ast::MethodCall.new(:new, ast::ConstantRead.new(:NoSuchClass), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end
  end

  describe 'ConstantRead (Tier 1 — class-of-value; classes collapse to Class)' do
    it 'defaults to ⊤ when no top_level_scope is provided' do
      body = ast::ConstantRead.new(:Integer)
      methods = { [:Foo, :m] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy)
      Frozone::Compiler::Analysis::Engine.new(pass).run
      expect(pass.type_of(body).top?).to be true
    end

    it 'types a class-valued constant as Class' do
      # top_level_scope with `Integer` mapped to the Integer class object.
      scope = double('scope', constants_table: { Integer: hierarchy[:Integer] })
      body = ast::ConstantRead.new(:Integer)
      methods = { [:Foo, :m] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy, top_level_scope: scope)
      Frozone::Compiler::Analysis::Engine.new(pass).run
      # Precision loss: Integer class → Class. This is the case that
      # motivates the Class[X] Tier 2 extension.
      expect(pass.type_of(body)).to eq(t(:Class))
    end

    it 'types a value-constant as the value`s class' do
      # X = 42 — value is an IntegerObject; its class_object is Integer.
      int_val = double('IntegerObject', class_object: hierarchy[:Integer])
      allow(int_val).to receive(:is_a?).and_return(false)
      allow(int_val).to receive(:respond_to?).with(:class_object).and_return(true)
      scope = double('scope', constants_table: { X: int_val })
      body = ast::ConstantRead.new(:X)
      methods = { [:Foo, :m] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy, top_level_scope: scope)
      Frozone::Compiler::Analysis::Engine.new(pass).run
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'types a module-valued constant as Module' do
      mod_val = Frozone::Vm::ModuleObject.new(:Comparable, nil)
      scope = double('scope', constants_table: { Comparable: mod_val })
      body = ast::ConstantRead.new(:Comparable)
      methods = { [:Foo, :m] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy, top_level_scope: scope)
      Frozone::Compiler::Analysis::Engine.new(pass).run
      expect(pass.type_of(body)).to eq(t(:Module))
    end

    it 'is ⊤ when the constant name isn`t in top_level_scope' do
      scope = double('scope', constants_table: { Integer: hierarchy[:Integer] })
      body = ast::ConstantRead.new(:NoSuchConst)
      methods = { [:Foo, :m] => make_method(body) }
      pass = described_class.new(methods: methods, all_classes: hierarchy, top_level_scope: scope)
      Frozone::Compiler::Analysis::Engine.new(pass).run
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

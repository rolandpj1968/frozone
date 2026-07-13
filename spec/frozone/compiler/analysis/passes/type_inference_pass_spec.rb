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
require_relative '../../../../../lib/frozone/ast/case'
require_relative '../../../../../lib/frozone/ast/and'
require_relative '../../../../../lib/frozone/ast/or'
require_relative '../../../../../lib/frozone/ast/rescue'
require_relative '../../../../../lib/frozone/ast/range_literal'
require_relative '../../../../../lib/frozone/ast/regexp_literal'
require_relative '../../../../../lib/frozone/ast/interpolated_string'
require_relative '../../../../../lib/frozone/ast/super'
require_relative '../../../../../lib/frozone/ast/yield'
require_relative '../../../../../lib/frozone/ast/lambda'
require_relative '../../../../../lib/frozone/ast/method_def'
require_relative '../../../../../lib/frozone/ast/class_def'
require_relative '../../../../../lib/frozone/ast/module_def'
require_relative '../../../../../lib/frozone/ast/singleton_class_def'
require_relative '../../../../../lib/frozone/ast/method_alias'
require_relative '../../../../../lib/frozone/ast/global_alias'
require_relative '../../../../../lib/frozone/ast/attribute_write'
require_relative '../../../../../lib/frozone/ast/constant_write'
require_relative '../../../../../lib/frozone/ast/multiple_assignment'
require_relative '../../../../../lib/frozone/ast/index_op_write'
require_relative '../../../../../lib/frozone/ast/constant_op_write'
require_relative '../../../../../lib/frozone/ast/call_or_write'
require_relative '../../../../../lib/frozone/ast/instance_variable_write'
require_relative '../../../../../lib/frozone/ast/class_variable_write'
require_relative '../../../../../lib/frozone/ast/global_variable_write'
require_relative '../../../../../lib/frozone/ast/splat_arg'
require_relative '../../../../../lib/frozone/ast/block_arg'
require_relative '../../../../../lib/frozone/ast/match_write'
require_relative '../../../../../lib/frozone/ast/defined_expr'
require_relative '../../../../../lib/frozone/ast/defined_constant'
require_relative '../../../../../lib/frozone/ast/flip_flop'

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

  # Helper: def m(x); if x.<pred>(...); then_expr; else else_expr; end; end
  # + a caller that pushes a specific type for x so the param arrives at a
  # useful starting point. Used by predicate-narrowing and Never-routing-
  # collapse tests.
  def narrow_scenario(pred_call, then_expr, else_expr, caller_arg_type:)
    caller_arg =
      case caller_arg_type
      when :Integer then ast::IntegerLiteral.from(42)
      when :String  then ast::StringLiteral.from('s')
      when :NilClass then ast::NilLiteral::NIL
      end
    caller_body = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [caller_arg], [])
    m_body = ast::If.new(pred_call, then_expr, else_expr)
    {
      [:Foo, :m]      => make_method(m_body, required_params: [:x]),
      [:Foo, :caller] => make_method(caller_body),
    }
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

    it 'params of an unreached method stay at ⊥ (no callsite pushes)' do
      # method(:m, [:p]) => body is just `p`. Nothing calls Foo#m, so
      # its :p param node never gets a callsite push and stays at ⊥.
      # (Under the new bipolar model this is what "unreached" looks
      # like — an entry point / execute-block synthetic root is what
      # elevates params to concrete values in real programs.)
      p_read = ast::LocalVariableRead.new(:p, 0)
      body = p_read
      methods = { [:Foo, :m] => make_method(body, required_params: [:p]) }
      pass = run_pass(methods)
      expect(pass.type_of(p_read).bottom?).to be true
    end

    it 'callsite pushes propagate a concrete type into the callee param' do
      # def m(p); p; end;  def caller; m(42); end
      # Round 1: caller pushes Integer to Foo#m's :p.
      # Round 2: Foo#m returns Integer.
      m_read = ast::LocalVariableRead.new(:p, 0)
      m_body = m_read
      call = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(42)], [])
      caller_body = call
      methods = {
        [:Foo, :m]      => make_method(m_body, required_params: [:p]),
        [:Foo, :caller] => make_method(caller_body),
      }
      pass = run_pass(methods)
      # Callsite's push flows through: Foo#m's :p → Integer, so `p` reads Integer.
      expect(pass.type_of(m_read)).to eq(t(:Integer))
      # And Foo#m returns Integer. Under 1-CFA the return lives at the
      # specific context; the widening helper LUBs across contexts.
      engine = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }
      expect(pass.method_return_widened(engine.values, :Foo, :m)).to eq(t(:Integer))
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

  describe 'noreturn — divergent intrinsics and missing methods' do
    it 'kernel_raise is annotated :__noreturn__ → callers type as noreturn' do
      # def m; Intrinsics.kernel_raise(nil, nil, nil, nil, nil); end
      call = ast::IntrinsicCall.new(:kernel_raise, [
        ast::NilLiteral::NIL, ast::NilLiteral::NIL, ast::NilLiteral::NIL,
        ast::NilLiteral::NIL, ast::NilLiteral::NIL,
      ])
      methods = { [:Foo, :m] => make_method(call) }
      pass = run_pass(methods)
      expect(pass.type_of(call).noreturn?).to be true
    end

    it 'missing method with no user-override method_missing types as noreturn' do
      # def m(x); x.no_such_method_defined_anywhere; end
      # No class in x's ancestor chain has a method_missing override.
      # Falls through to canonical BasicObject#method_missing which
      # raises → noreturn.
      no_such = ast::MethodCall.new(:no_such_method_defined_anywhere,
                                    ast::LocalVariableRead.new(:x, 0), [], [])
      caller = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      methods = {
        [:Foo, :m]      => make_method(no_such, required_params: [:x]),
        [:Foo, :caller] => make_method(caller),
      }
      pass = run_pass(methods)
      expect(pass.type_of(no_such).noreturn?).to be true
    end

    it 'missing method routes through method_missing when defined on the chain (noreturn body)' do
      # Set up: BasicObject#method_missing → noreturn intrinsic.
      mm_call = ast::IntrinsicCall.new(:basic_object_method_missing, [
        ast::SelfLiteral::SELF, ast::NilLiteral::NIL, ast::NilLiteral::NIL,
        ast::NilLiteral::NIL,
      ])
      # def m(x); x.no_such_method; end
      no_such = ast::MethodCall.new(:no_such_method,
                                    ast::LocalVariableRead.new(:x, 0), [], [])
      caller_body = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      methods = {
        [:BasicObject, :method_missing] => make_method(mm_call),
        [:Foo, :m]      => make_method(no_such, required_params: [:x]),
        [:Foo, :caller] => make_method(caller_body),
      }
      pass = run_pass(methods)
      # The call routes through method_missing → BasicObject#method_missing
      # → basic_object_method_missing intrinsic (noreturn). So the call
      # types as noreturn.
      expect(pass.type_of(no_such).noreturn?).to be true
    end

    it 'method call on a noreturn receiver stays noreturn (short-circuit)' do
      # x = raise "err"; x.foo  — after the raise, x is noreturn; x.foo
      # inherits noreturn (receiver never has a real value at runtime).
      raise_call = ast::IntrinsicCall.new(:kernel_raise, [
        ast::NilLiteral::NIL, ast::NilLiteral::NIL, ast::NilLiteral::NIL,
        ast::NilLiteral::NIL, ast::NilLiteral::NIL,
      ])
      x_write = ast::LocalVariableWrite.new(:x, 0, raise_call)
      x_foo = ast::MethodCall.new(:foo, ast::LocalVariableRead.new(:x, 0), [], [])
      body = ast::Sequence.new([x_write, x_foo])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # x's env-type = noreturn. x.foo's receiver walk returns noreturn,
      # transfer_method_call short-circuits, x.foo is noreturn.
      expect(pass.type_of(x_foo).noreturn?).to be true
    end
  end

  describe 'predicate narrowing on If' do
    it 'x.is_a?(Integer) narrows x to Integer in the truthy arm' do
      x_read = ast::LocalVariableRead.new(:x, 0)
      is_a = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      then_expr = x_read                                # x here should type as Integer
      else_expr = ast::NilLiteral::NIL
      methods = narrow_scenario(is_a, then_expr, else_expr, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(then_expr)).to eq(t(:Integer))
    end

    it 'kind_of? behaves the same as is_a?' do
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:kind_of?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      methods = narrow_scenario(pred, x_read, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'nil? — truthy arm narrows to NilClass, falsy strips nullable' do
      # def m(x); if x.nil?; then_read; else else_read; end; end
      # caller pushes NilClass (nullable NilClass, technically NilClass literal),
      # so x arrives as NilClass. But to make the narrow observable we want a
      # nullable receiver — use two callers, one pushing Integer, one pushing nil.
      then_read = ast::LocalVariableRead.new(:x, 0)
      else_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], [])
      m_body = ast::If.new(pred, then_read, else_read)
      # Two callers so x's param joins Integer ∪ NilClass = Integer?.
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      # Truthy arm: x narrowed to NilClass.
      expect(pass.type_of(then_read)).to eq(t(:NilClass))
      # Falsy arm: x narrowed to Integer (nullable bit stripped).
      expect(pass.type_of(else_read)).to eq(t(:Integer))
    end

    it 'nil? on a non-nullable receiver — falsy is unchanged' do
      # Single caller pushes Integer (non-nullable) → falsy arm keeps Integer.
      else_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], [])
      methods = narrow_scenario(pred, ast::NilLiteral::NIL, else_read, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(else_read)).to eq(t(:Integer))
    end

    it 'non-narrowing predicate (e.g. a bare method call not on a local) leaves the arm untouched' do
      # `foo?` in an If pred — no narrowing.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:foo?, ast::SelfLiteral::SELF, [], [])
      methods = narrow_scenario(pred, x_read, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      # Whatever x's env-type is, no narrowing applied — still Integer here
      # because the caller pushed Integer.
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'a write inside the narrowed arm invalidates the narrowing for subsequent reads' do
      # def m(x); if x.is_a?(Integer); x = "s"; second_read; end; end
      # First read (implicit — the write's LHS access) shouldn't come up.
      # After x = "s", second_read should see the env's joined type, not
      # the stale Integer narrowing.
      write = ast::LocalVariableWrite.new(:x, 0, ast::StringLiteral.from('s'))
      second_read = ast::LocalVariableRead.new(:x, 0)
      then_body = ast::Sequence.new([write, second_read])
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      methods = narrow_scenario(pred, then_body, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      # env after write: join(Integer, String) = Object.
      # Narrowing was deleted by the write, so second_read sees env → Object.
      expect(pass.type_of(second_read)).to eq(t(:Object))
    end
  end

  describe 'And/Or/Case narrowing (compound predicates)' do
    it 'And of two same-target facts: truthy arm sees meet of narrowings' do
      # def m(x); if x.is_a?(Integer) && x.is_a?(Numeric); use_x; end; end
      # Both narrow x to their respective classes. Truthy narrow = meet.
      # Integer ⊑ Numeric → meet = Integer.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::And.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], []),
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Numeric)], []),
      )
      m_body = ast::If.new(pred, x_read, ast::NilLiteral::NIL)
      caller = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      methods = {
        [:Foo, :m]      => make_method(m_body, required_params: [:x]),
        [:Foo, :caller] => make_method(caller),
      }
      pass = run_pass(methods)
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'Or of two same-target nil?/is_a?: falsy arm sees meet of falsy narrowings' do
      # def m(x); if x.nil? || x.is_a?(String); nil; else; x; end; end
      # Truthy: no narrowing (either could be truthy).
      # Falsy: NOT nil? AND NOT is_a?(String) → x is neither nil nor String.
      #   nil?.falsy = strip_nullable(x). is_a?.falsy = current (Tier-1 no negative).
      #   meet(strip_nullable, current) = strip_nullable (more precise).
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::Or.new(
        ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], []),
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:String)], []),
      )
      m_body = ast::If.new(pred, ast::NilLiteral::NIL, x_read)
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      # Falsy arm: nullable-bit stripped. x's pre-If type = Integer? →
      # falsy = Integer.
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'And of different-target facts: no compound narrowing (Tier-1 lattice limit)' do
      # def m(x, y); if x.is_a?(Integer) && y.is_a?(String); x; end; end
      # Two different targets — narrowing_fact returns nil for the And.
      # So x doesn't get narrowed. But since caller pushes Integer for x
      # anyway, the read is still Integer via env.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::And.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], []),
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:y, 0), [ast::ConstantRead.new(:String)], []),
      )
      m_body = ast::If.new(pred, x_read, ast::NilLiteral::NIL)
      caller = ast::MethodCall.new(:m, ast::SelfLiteral::SELF,
        [ast::IntegerLiteral.from(1), ast::StringLiteral.from('s')], [])
      methods = {
        [:Foo, :m]      => make_method(m_body, required_params: %i[x y]),
        [:Foo, :caller] => make_method(caller),
      }
      pass = run_pass(methods)
      # x is Integer via callsite push (env), no compound narrowing.
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'Case with class-ref when: each arm narrows the subject' do
      # def m(x); case x; when Integer; x; when String; x; end; end
      # x's callsite: mixed (Integer + String). Case-arms narrow x per when.
      arm1_read = ast::LocalVariableRead.new(:x, 0)
      arm2_read = ast::LocalVariableRead.new(:x, 0)
      subj = ast::LocalVariableRead.new(:x, 0)
      w1 = ast::Case::When.new([ast::ConstantRead.new(:Integer)], arm1_read)
      w2 = ast::Case::When.new([ast::ConstantRead.new(:String)], arm2_read)
      m_body = ast::Case.new(subj, [w1, w2], nil)
      # Mixed callers so x's param joins Integer ∪ String = Object.
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::StringLiteral.from('s')], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(arm1_read)).to eq(t(:Integer))
      expect(pass.type_of(arm2_read)).to eq(t(:String))
    end

    it 'Case with multi-class when: LUB of the classes' do
      # def m(x); case x; when Integer, Float; x; end; end
      # Arm's condition: [Integer, Float] → LUB = Numeric. x is Numeric here.
      arm_read = ast::LocalVariableRead.new(:x, 0)
      subj = ast::LocalVariableRead.new(:x, 0)
      w1 = ast::Case::When.new(
        [ast::ConstantRead.new(:Integer), ast::ConstantRead.new(:Float)],
        arm_read,
      )
      m_body = ast::Case.new(subj, [w1], nil)
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::FloatLiteral.new(1.5)], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(arm_read)).to eq(t(:Numeric))
    end
  end

  # Numeric-coercion collapse — the load-bearing dependency for
  # 1-CFA scalability (see docs/analysis-framework-plan.md §4.6.1
  # + §4.8, and memory [[project_ti_subsumes_reachability]]).
  #
  # For `def +(v) = v.is_a?(Integer) ? Intrinsics.integer__plus_(self, v)
  #                                  : __coerce_op__(v, :+)` to be
  # cheap under 1-CFA `(self:Integer, v:Integer)`, the else-branch
  # must collapse to divergent — otherwise TI walks
  # `v.coerce(self).send(:+, b)` per context and 1-CFA blows up
  # combinatorially.
  #
  # Two mechanisms make collapse work:
  #   1. Predicate narrowing pushes an unreachable-shaped type
  #      (⊥ / NORETURN) into an arm.
  #   2. Divergent-receiver dispatch (task #244) short-circuits any
  #      call chain rooted on a ⊥/NORETURN receiver.
  #
  # The lattice has two divergent-marker values, both join-identity,
  # different in meaning (see type_lattice.rb):
  #   - BOTTOM   ⊥ — "no data yet; may rise" / "unreached in this context"
  #   - NORETURN — "provably diverges" (raise/throw/return)
  # Predicate narrowing produces BOTTOM for an unsatisfiable arm.
  # Divergent-mm-dispatch produces NORETURN. `.divergent?` = `bottom? ||
  # noreturn?` — either is enough to stop TI exploration downstream,
  # which is what the coercion collapse needs.
  #
  # This block empirically documents where the collapse fires today
  # and where the gap is (Tier-1 has no negative is_a? narrowing).
  describe 'predicate + Never routing collapse (numeric-coercion enabler)' do
    it 'And of disjoint is_a? facts → truthy arm receiver narrows to ⊥ and dispatch is divergent' do
      # def m(x); if x.is_a?(Integer) && x.is_a?(String); x.no_such_op; end; end
      # meet(Integer, String) = ⊥ (disjoint). Truthy arm sees x:⊥.
      # x.no_such_op dispatches on ⊥ → short-circuit to ⊥ at
      # transfer_method_call line 822. Not the same as noreturn — the
      # arm is unreached, TI doesn't walk it.
      then_dispatch = ast::MethodCall.new(:no_such_op, ast::LocalVariableRead.new(:x, 0), [], [])
      pred = ast::And.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], []),
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:String)], []),
      )
      methods = narrow_scenario(pred, then_dispatch, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(then_dispatch).divergent?).to be true
    end

    it 'nil? truthy arm on non-nullable non-nil receiver — NilClass mm-dispatch → noreturn' do
      # def m(x); if x.nil?; x.no_such_op_on_nilclass; end; end
      # caller: x:Integer (non-nullable). nil? truthy → x narrows to NilClass.
      # NilClass#no_such_op → not on chain → mm → canonical noreturn.
      # Distinct from the ⊥ collapse above: dispatch actually happens on a
      # real class (NilClass), just resolves to a divergent method.
      then_dispatch = ast::MethodCall.new(:no_such_op_on_nilclass, ast::LocalVariableRead.new(:x, 0), [], [])
      pred = ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], [])
      methods = narrow_scenario(pred, then_dispatch, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(then_dispatch).noreturn?).to be true
    end

    it 'nil? falsy arm on non-nullable NilClass receiver — falsy narrows to ⊥ and dispatch is divergent' do
      # def m(x); if x.nil?; nil; else; x.no_such_op; end; end
      # caller: x:NilClass. build_nil_narrow returns falsy=⊥ when current
      # is exactly NilClass (line 486-488). Dispatch in else arm on ⊥ →
      # short-circuit → ⊥.
      else_dispatch = ast::MethodCall.new(:no_such_op, ast::LocalVariableRead.new(:x, 0), [], [])
      pred = ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], [])
      methods = narrow_scenario(pred, ast::NilLiteral::NIL, else_dispatch, caller_arg_type: :NilClass)
      pass = run_pass(methods)
      expect(pass.type_of(else_dispatch).divergent?).to be true
    end

    it 'nil? truthy arm on nullable receiver — NilClass mm-dispatch → noreturn' do
      # def m(x); if x.nil?; x.no_such_int_op; end; end
      # Two callers → x:Integer? (nullable). Truthy narrow → x:NilClass.
      # NilClass# lookup for :no_such_int_op → not found → mm → noreturn.
      then_dispatch = ast::MethodCall.new(:no_such_int_op, ast::LocalVariableRead.new(:x, 0), [], [])
      pred = ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], [])
      m_body = ast::If.new(pred, then_dispatch, ast::NilLiteral::NIL)
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(then_dispatch).noreturn?).to be true
    end

    it 'is_a?(K) truthy arm on typed context — narrowing keeps x at K (baseline for the GAP below)' do
      # def m(x); if x.is_a?(Integer); use_x; end; end
      # caller: x:Integer. Truthy narrow: x stays Integer (already ⊑ K
      # per build_class_narrow line 476: subsumes-check keeps the more
      # precise of current and K). Sanity baseline for the GAP test —
      # proves narrowing produces the expected concrete type in the
      # truthy arm before we assert on the falsy arm.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      methods = narrow_scenario(pred, x_read, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(x_read)).to eq(t(:Integer))
    end

    it 'is_a?(K) falsy arm on already-K typed context narrows to ⊥' do
      # def m(x); if x.is_a?(Integer); nil; else; x; end; end
      # caller: x:Integer. Negative narrowing: falsy = Integer \ Integer
      # = ⊥. Any dispatch on x in the else arm short-circuits — this
      # is the mechanism the numeric-coercion coerce branch relies on
      # to disappear under 1-CFA `(self:Integer, v:Integer)` context.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      methods = narrow_scenario(pred, ast::NilLiteral::NIL, x_read, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(x_read).divergent?).to be true
    end

    it 'is_a?(K) falsy arm on mixed Integer/Float callers narrows to Float via 1-CFA per-context precision' do
      # def m(x); if x.is_a?(Integer); nil; else; x; end; end
      # Callers push Integer and Float.
      #
      # Under 0-CFA (transfer-of-LUB): body walks once with x:Numeric.
      # Falsy would be "Numeric minus Integer" — Tier-1's flat lattice
      # can't express set difference, so falsy stays Numeric.
      #
      # Under 1-CFA (LUB-of-transfers): each caller runs separately.
      #   Integer-context: is_a?(Integer) falsy → x = Integer \ Integer = ⊥.
      #   Float-context:   is_a?(Integer) falsy → x = Float (disjoint).
      #   LUB(⊥, Float) = Float. Sound AND finer than 0-CFA.
      #
      # The 1-CFA precision win falls out of running the contexts
      # separately — LUB-of-transfers ⊑ transfer-of-LUB by
      # monotonicity, always, and often strictly.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      m_body = ast::If.new(pred, ast::NilLiteral::NIL, x_read)
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::FloatLiteral.new(1.5)], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(x_read)).to eq(t(:Float))
    end

    it 'is_a?(K) truthy arm on disjoint typed context narrows to ⊥' do
      # def m(x); if x.is_a?(String); x; end; end
      # caller: x:Integer. Truthy = Integer ∩ String = ⊥ (disjoint) —
      # is_a?(String) is provably false, the truthy arm is unreachable.
      x_read = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:String)], [])
      methods = narrow_scenario(pred, x_read, ast::NilLiteral::NIL, caller_arg_type: :Integer)
      pass = run_pass(methods)
      expect(pass.type_of(x_read).divergent?).to be true
    end

    it 'is_a?(K) on nullable receiver: nil goes to falsy when NilClass ⊄ K' do
      # def m(x); if x.is_a?(Integer); truthy_read; else; falsy_read; end; end
      # Mixed callers → x:Integer?. NilClass ⊄ Integer → nil goes to
      # the falsy arm. Truthy: Integer (nullable stripped).
      # Falsy: NilClass (non-null Integer part narrows to ⊥, nil part
      # survives).
      truthy_read = ast::LocalVariableRead.new(:x, 0)
      falsy_read  = ast::LocalVariableRead.new(:x, 0)
      pred = ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], [])
      m_body = ast::If.new(pred, truthy_read, falsy_read)
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(truthy_read)).to eq(t(:Integer))
      expect(pass.type_of(falsy_read)).to eq(t(:NilClass))
    end

    it 'mirrors Integer#+ shape — coerce branch collapses when every caller pushes v:Integer' do
      # def Integer#plus(v)
      #   if v.is_a?(Integer)
      #     v                      # truthy: v is Integer here
      #   else
      #     v.coerce(self)         # else path: v is ⊥ under negative narrowing
      #                            #   → dispatch on ⊥ receiver short-circuits
      #                            #   → the whole coerce chain never gets walked
      #                            #   → this is what makes 1-CFA affordable
      #   end
      # end
      #
      # Foo#call1 and Foo#call2: two callers both dispatch Integer#plus
      # with an Integer arg. Tier-2 param propagation joins Integer ⊔
      # Integer = Integer at [:param, :Integer, :plus, :v]. Method self
      # is Integer via ctx.class_flat.
      #
      # 0-CFA suffices here because the join across all callsites for `v`
      # is still Integer. This is the case the empirical splat oracle
      # from ti-v2-splat-experiment showed dominates real programs
      # (~96% of methods are context-insensitive at 0-CFA); the
      # numeric-coercion pattern is one of the ~4% context-worthy shapes
      # but only when at least one caller passes a non-Integer.
      truthy_v = ast::LocalVariableRead.new(:v, 0)
      else_v   = ast::LocalVariableRead.new(:v, 0)
      coerce_call = ast::MethodCall.new(:coerce, else_v, [ast::SelfLiteral::SELF], [])
      plus_body = ast::If.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:v, 0), [ast::ConstantRead.new(:Integer)], []),
        truthy_v,
        coerce_call,
      )
      call1 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(1), [ast::IntegerLiteral.from(2)], [])
      call2 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(3), [ast::IntegerLiteral.from(4)], [])
      methods = {
        [:Integer, :plus] => make_method(plus_body, required_params: [:v]),
        [:Foo, :call1]    => make_method(call1),
        [:Foo, :call2]    => make_method(call2),
      }
      pass = run_pass(methods)
      # Truthy arm: v narrows to Integer.
      expect(pass.type_of(truthy_v)).to eq(t(:Integer))
      # Else arm: v narrows to ⊥ (Integer \ Integer). The read is
      # divergent, and the coerce dispatch inherits divergence via the
      # divergent-receiver short-circuit in transfer_method_call.
      expect(pass.type_of(else_v).divergent?).to be true
      expect(pass.type_of(coerce_call).divergent?).to be true
    end

    it 'mirrors Integer#+ shape — heteromorphic Integer/Float callers each collapse independently under 1-CFA' do
      # Same shape as monomorphic test but Foo#call2 passes a Float.
      # This is the coerce-shaped case the numeric-coercion pattern
      # exists to handle.
      #
      # 1-CFA fires two separate analyses:
      #   [Integer, Integer] context: truthy=Integer, else v=⊥ (collapse).
      #   [Integer, Float]   context: truthy=⊥ (disjoint), else v=Float.
      # LUB across contexts on else_v: LUB(⊥, Float) = Float.
      # LUB across contexts on truthy_v: LUB(Integer, ⊥) = Integer.
      #
      # 0-CFA would collapse both into a single body walk with
      # v:Numeric — truthy=Integer, else=Numeric. Strictly coarser on
      # the else arm.
      truthy_v = ast::LocalVariableRead.new(:v, 0)
      else_v   = ast::LocalVariableRead.new(:v, 0)
      coerce_call = ast::MethodCall.new(:coerce, else_v, [ast::SelfLiteral::SELF], [])
      plus_body = ast::If.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:v, 0), [ast::ConstantRead.new(:Integer)], []),
        truthy_v,
        coerce_call,
      )
      call1 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(1), [ast::IntegerLiteral.from(2)], [])
      call2 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(3), [ast::FloatLiteral.new(1.5)], [])
      methods = {
        [:Integer, :plus] => make_method(plus_body, required_params: [:v]),
        [:Foo, :call1]    => make_method(call1),
        [:Foo, :call2]    => make_method(call2),
      }
      pass = run_pass(methods)
      expect(pass.type_of(truthy_v)).to eq(t(:Integer))
      # 1-CFA precision reveal: else arm narrows to Float, not Numeric.
      # The Integer-context contributes ⊥, only the Float-context
      # contributes a real value. LUB drops the coarse Numeric answer.
      expect(pass.type_of(else_v)).to eq(t(:Float))
    end

    it 'per-context precision: heteromorphic Integer#+ callers get distinct return contexts' do
      # Same setup as the LUB test above; this asserts on the per-
      # context MethodNode returns to verify the 1-CFA machinery isn't
      # just producing the same joined analysis under different keys.
      plus_body = ast::If.new(
        ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:v, 0), [ast::ConstantRead.new(:Integer)], []),
        ast::LocalVariableRead.new(:v, 0),
        ast::MethodCall.new(:coerce, ast::LocalVariableRead.new(:v, 0), [ast::SelfLiteral::SELF], []),
      )
      call1 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(1), [ast::IntegerLiteral.from(2)], [])
      call2 = ast::MethodCall.new(:plus, ast::IntegerLiteral.from(3), [ast::FloatLiteral.new(1.5)], [])
      methods = {
        [:Integer, :plus] => make_method(plus_body, required_params: [:v]),
        [:Foo, :call1]    => make_method(call1),
        [:Foo, :call2]    => make_method(call2),
      }
      pass = run_pass(methods)
      engine = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }
      int_ctx   = [t(:Integer), t(:Integer)].freeze
      float_ctx = [t(:Integer), t(:Float)].freeze
      int_return   = engine.values[described_class.method_node(:Integer, :plus, int_ctx)]
      float_return = engine.values[described_class.method_node(:Integer, :plus, float_ctx)]
      # Integer-context: truthy arm returns Integer. Else arm is ⊥ (v
      # narrows to Integer \ Integer = ⊥). Method return = Integer.
      expect(int_return).to eq(t(:Integer))
      # Float-context: truthy arm is ⊥ (Float ∩ Integer = ∅). Else arm
      # types via coerce which the shim hierarchy doesn't define →
      # method_missing → noreturn. Method return = noreturn.
      expect(float_return.noreturn?).to be true
    end
  end

  describe 'early-exit narrowing (surviving-arm env persists past the If)' do
    it 'return-if-nil? — post-If x is non-nullable' do
      # def m(x); return "no" if x.nil?; x; end
      # (with x arriving as Integer? from mixed callers)
      then_body = ast::Return.new(ast::StringLiteral.from('no'))
      post_read = ast::LocalVariableRead.new(:x, 0)
      m_body = ast::Sequence.new([
        ast::If.new(
          ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], []),
          then_body,
          nil,   # implicit-nil else
        ),
        post_read,
      ])
      # Two callers so x's param joins Integer ∪ NilClass = Integer?.
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      # Truthy arm (Return) is divergent (⊥). Falsy arm survives with
      # x narrowed to non-nullable Integer. install_surviving_narrowing
      # keeps that on ctx.narrowings for post-If code.
      expect(pass.type_of(post_read)).to eq(t(:Integer))
    end

    it 'raise-if-not-integer — post-If x is Integer' do
      # def m(x); raise unless x.is_a?(Integer); x; end
      # `unless` desugars to `if !`, but the parser might use a different
      # AST shape. Test with: if x.is_a?(Integer); else raise; end;
      raise_call = ast::IntrinsicCall.new(:kernel_raise, [
        ast::NilLiteral::NIL, ast::NilLiteral::NIL, ast::NilLiteral::NIL,
        ast::NilLiteral::NIL, ast::NilLiteral::NIL,
      ])
      post_read = ast::LocalVariableRead.new(:x, 0)
      m_body = ast::Sequence.new([
        ast::If.new(
          ast::MethodCall.new(:is_a?, ast::LocalVariableRead.new(:x, 0), [ast::ConstantRead.new(:Integer)], []),
          ast::NilLiteral::NIL,  # truthy: no-op
          raise_call,             # falsy: raise (noreturn)
        ),
        post_read,
      ])
      caller_body = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      methods = {
        [:Foo, :m]      => make_method(m_body, required_params: [:x]),
        [:Foo, :caller] => make_method(caller_body),
      }
      pass = run_pass(methods)
      # Truthy arm: nil (survives).
      # Falsy arm: raise (noreturn — divergent).
      # Install: truthy narrowing (x is Integer per is_a?) persists post-If.
      # post_read: x is Integer.
      expect(pass.type_of(post_read)).to eq(t(:Integer))
    end

    it 'both arms survive → pre-If narrowings restored' do
      # def m(x); if x.nil?; nil; else; nil; end; x; end
      # Both arms non-divergent → no early-exit narrowing.
      # Post-If: x still has pre-If type (Integer? here).
      post_read = ast::LocalVariableRead.new(:x, 0)
      m_body = ast::Sequence.new([
        ast::If.new(
          ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], []),
          ast::NilLiteral::NIL,
          ast::NilLiteral::NIL,
        ),
        post_read,
      ])
      c1 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      c2 = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::NilLiteral::NIL], [])
      methods = {
        [:Foo, :m]  => make_method(m_body, required_params: [:x]),
        [:Foo, :c1] => make_method(c1),
        [:Foo, :c2] => make_method(c2),
      }
      pass = run_pass(methods)
      # Nothing installed post-If. post_read sees env's Integer?.
      expect(pass.type_of(post_read)).to eq(t(:Integer, nullable: true))
    end

    it 'both arms diverge → nothing installed (pre-If env restored)' do
      # def m(x); if x.nil?; return "a"; else return "b"; end; end
      # Both arms Return → both divergent. No survivor. Nothing to install.
      m_body = ast::If.new(
        ast::MethodCall.new(:nil?, ast::LocalVariableRead.new(:x, 0), [], []),
        ast::Return.new(ast::StringLiteral.from('a')),
        ast::Return.new(ast::StringLiteral.from('b')),
      )
      caller_body = ast::MethodCall.new(:m, ast::SelfLiteral::SELF, [ast::IntegerLiteral.from(1)], [])
      methods = {
        [:Foo, :m]      => make_method(m_body, required_params: [:x]),
        [:Foo, :caller] => make_method(caller_body),
      }
      pass = run_pass(methods)
      # Both Returns contribute String → method returns String.
      key = described_class.method_node(:Foo, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value).to eq(t(:String))
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
      # is empty, so nothing to push onto. Method has no callers under
      # this test's world, so its return stays at ⊥ (unreached).
      body = ast::Break.new(ast::IntegerLiteral.from(1))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      key = described_class.method_node(:Foo, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value.bottom?).to be true
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

  describe 'Case' do
    def case_when(conds, body)
      ast::Case::When.new(conds, body)
    end

    it 'joins all when-arm body types with the else' do
      # case x; when 1 then 1; when 2 then 1.5; else "s"; end
      #   → LUB(Integer, Float, String) = LUB(Numeric, String) = Object
      subj = ast::LocalVariableRead.new(:x, 0)
      w1 = case_when([ast::IntegerLiteral.from(1)], ast::IntegerLiteral.from(1))
      w2 = case_when([ast::IntegerLiteral.from(2)], ast::FloatLiteral.new(1.5))
      body = ast::Case.new(subj, [w1, w2], ast::StringLiteral.from('s'))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Object))
    end

    it 'no-else makes the result nullable (silent nil fall-through)' do
      # case x; when 1 then 42; end  → Integer? (nullable)
      subj = ast::LocalVariableRead.new(:x, 0)
      w = case_when([ast::IntegerLiteral.from(1)], ast::IntegerLiteral.from(42))
      body = ast::Case.new(subj, [w], nil)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer, nullable: true))
    end

    it 'both arms same-typed → no widening (like If)' do
      # case x; when 1 then 1; else 2; end  → Integer
      subj = ast::LocalVariableRead.new(:x, 0)
      w = case_when([ast::IntegerLiteral.from(1)], ast::IntegerLiteral.from(1))
      body = ast::Case.new(subj, [w], ast::IntegerLiteral.from(2))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'subject-less case (case; when cond then …) still types correctly' do
      # case; when true then 1; else 2.0; end  → LUB(Integer, Float) = Numeric
      w = case_when([ast::TrueLiteral::TRUE], ast::IntegerLiteral.from(1))
      body = ast::Case.new(nil, [w], ast::FloatLiteral.new(2.0))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Numeric))
    end
  end

  describe 'And / Or' do
    it 'And is LUB(left, right)' do
      # 1 && 1.5  → LUB(Integer, Float) = Numeric
      body = ast::And.new(ast::IntegerLiteral.from(1), ast::FloatLiteral.new(1.5))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Numeric))
    end

    it 'Or is LUB(left, right)' do
      # 1 || 1.5  → LUB(Integer, Float) = Numeric
      body = ast::Or.new(ast::IntegerLiteral.from(1), ast::FloatLiteral.new(1.5))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Numeric))
    end

    it 'Or of nil-typed left with Integer right → nullable Integer' do
      # nil || 42  → NilClass ∪ Integer = Integer?
      body = ast::Or.new(ast::NilLiteral::NIL, ast::IntegerLiteral.from(42))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer, nullable: true))
    end

    it 'And of same-typed both arms → no widening' do
      body = ast::And.new(ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end
  end

  describe 'Rescue' do
    def rescue_clause(exceptions, body, var_name: nil)
      ast::RescueClause.new(exceptions, var_name, var_name ? 0 : nil, body)
    end

    it 'body-only (no rescue clauses) types as body' do
      body = ast::IntegerLiteral.from(1)
      rescued = ast::Rescue.new(body, [], nil, nil)
      methods = { [:Foo, :m] => make_method(rescued) }
      pass = run_pass(methods)
      expect(pass.type_of(rescued)).to eq(t(:Integer))
    end

    it 'body + one rescue → LUB' do
      # begin; 1; rescue; 1.5; end  →  Numeric
      body = ast::IntegerLiteral.from(1)
      clause = rescue_clause([], ast::FloatLiteral.new(1.5))
      rescued = ast::Rescue.new(body, [clause], nil, nil)
      methods = { [:Foo, :m] => make_method(rescued) }
      pass = run_pass(methods)
      expect(pass.type_of(rescued)).to eq(t(:Numeric))
    end

    it 'else replaces body contribution' do
      # begin; 1; else "s"; rescue; 1.5; end  →  LUB("s", 1.5) = LUB(String, Float) = Object
      body = ast::IntegerLiteral.from(1)
      else_body = ast::StringLiteral.from('s')
      clause = rescue_clause([], ast::FloatLiteral.new(1.5))
      rescued = ast::Rescue.new(body, [clause], else_body, nil)
      methods = { [:Foo, :m] => make_method(rescued) }
      pass = run_pass(methods)
      expect(pass.type_of(rescued)).to eq(t(:Object))
    end

    it 'multiple rescue clauses each contribute' do
      # begin; 1; rescue A; "a"; rescue B; 1.5; end → LUB(Integer, String, Float)
      body = ast::IntegerLiteral.from(1)
      c1 = rescue_clause([ast::ConstantRead.new(:StandardError)], ast::StringLiteral.from('a'))
      c2 = rescue_clause([ast::ConstantRead.new(:StandardError)], ast::FloatLiteral.new(1.5))
      rescued = ast::Rescue.new(body, [c1, c2], nil, nil)
      methods = { [:Foo, :m] => make_method(rescued) }
      pass = run_pass(methods)
      expect(pass.type_of(rescued)).to eq(t(:Object))
    end

    it 'ensure body is walked but does not contribute to type' do
      # begin; 1; ensure "cleanup"; end  → Integer, not LUB(Integer, String)
      body = ast::IntegerLiteral.from(1)
      ens = ast::StringLiteral.from('cleanup')
      rescued = ast::Rescue.new(body, [], nil, ens)
      methods = { [:Foo, :m] => make_method(rescued) }
      pass = run_pass(methods)
      expect(pass.type_of(rescued)).to eq(t(:Integer))
      # But ensure's subtree type is still cached.
      expect(pass.type_of(ens)).to eq(t(:String))
    end
  end

  describe 'Range / Regexp / InterpolatedString literals' do
    it 'RangeLiteral types as Range and walks endpoints' do
      # (1..2)  → Range; child types cached
      lo = ast::IntegerLiteral.from(1)
      hi = ast::IntegerLiteral.from(2)
      body = ast::RangeLiteral.new(lo, hi, false)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Range))
      expect(pass.type_of(lo)).to eq(t(:Integer))
      expect(pass.type_of(hi)).to eq(t(:Integer))
    end

    it 'RegexpLiteral types as Regexp' do
      body = ast::RegexpLiteral.new('foo', 0)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Regexp))
    end

    it 'InterpolatedString types as String and walks interpolated parts' do
      # "#{42}" → String
      interp = ast::IntegerLiteral.from(42)
      body = ast::InterpolatedString.new([interp])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:String))
      expect(pass.type_of(interp)).to eq(t(:Integer))
    end
  end

  describe 'Yield / Lambda / definitions' do
    it 'Yield types as ⊤ and walks args' do
      # yield 42 — block return not typed at Tier 1
      arg = ast::IntegerLiteral.from(42)
      body = ast::Yield.new([arg])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
      expect(pass.type_of(arg)).to eq(t(:Integer))
    end

    it 'Lambda types as Proc' do
      lam_body = ast::IntegerLiteral.from(1)
      body = ast::Lambda.new([], [], nil, [], [], [], nil, nil, [], lam_body)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Proc))
    end

    it 'MethodDef types as Symbol' do
      # def m; end  →  :m
      body = ast::MethodDef.new(:m, nil, [], [], nil, [], [], [], nil, nil, [], ast::NilLiteral::NIL)
      methods = { [:Foo, :outer] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Symbol))
    end

    it 'ClassDef types as ⊤ (last-expression-of-body, unknown at Tier 1)' do
      body = ast::ClassDef.new(:C, [], nil, ast::NilLiteral::NIL)
      methods = { [:Foo, :outer] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end

    it 'ModuleDef types as ⊤' do
      body = ast::ModuleDef.new(:M, [], ast::NilLiteral::NIL)
      methods = { [:Foo, :outer] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
    end

    it 'MethodAlias types as NilClass' do
      body = ast::MethodAlias.new(:new_name, :old_name)
      methods = { [:Foo, :outer] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:NilClass))
    end
  end

  describe 'Super' do
    it 'resolves via the ancestor chain from ONE class up' do
      # class Numeric; def m; 42; end; end
      # class Integer < Numeric; def m; super; end; end
      # Integer#m calls super → Numeric#m which returns Integer.
      parent_body = ast::IntegerLiteral.from(42)
      super_body = ast::Super.new([], nil, forwarding: false)
      methods = {
        [:Numeric, :m] => make_method(parent_body),
        [:Integer, :m] => make_method(super_body),
      }
      pass = run_pass(methods)
      # Integer#m return type = Numeric#m return type = Integer.
      key = described_class.method_node(:Integer, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value).to eq(t(:Integer))
    end

    it 'returns ⊤ when there is no matching method above' do
      # Numeric#m has no ancestor with :m defined (Object/BasicObject don't have :m)
      super_body = ast::Super.new([], nil, forwarding: false)
      methods = { [:Numeric, :m] => make_method(super_body) }
      pass = run_pass(methods)
      key = described_class.method_node(:Numeric, :m)
      engine_value = Frozone::Compiler::Analysis::Engine.new(pass).tap { |e| e.run }.values[key]
      expect(engine_value.top?).to be true
    end
  end

  describe 'Assignments' do
    it 'AttributeWrite returns the last arg (the RHS value)' do
      # obj.foo = 42  →  Integer
      recv = ast::SelfLiteral::SELF
      body = ast::AttributeWrite.new(:foo=, recv, [ast::IntegerLiteral.from(42)], {})
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'safe-nav AttributeWrite widens to nullable' do
      # obj&.foo = 42  →  Integer? (nil when receiver is nil)
      recv = ast::SelfLiteral::SELF
      body = ast::AttributeWrite.new(:foo=, recv, [ast::IntegerLiteral.from(42)], {}, safe_nav: true)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer, nullable: true))
    end

    it 'ConstantWrite returns the RHS value' do
      # C = 3.14  →  Float
      body = ast::ConstantWrite.new(:C, ast::FloatLiteral.new(3.14))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float))
    end

    it 'MultipleAssignment returns the RHS' do
      # a, b = [1, 2]  →  Array (the raw RHS value_node)
      arr = ast::ArrayLiteral.new([])
      body = ast::MultipleAssignment.new([[:local, :a, 0], [:local, :b, 0]], arr)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Array))
    end

    it 'IndexOperatorWrite falls through to ⊤ (unknown operator result)' do
      # arr[i] += 1  — unknown existing arr[i] type × unknown +
      recv = ast::SelfLiteral::SELF
      idx = ast::IntegerLiteral.from(0)
      val = ast::IntegerLiteral.from(1)
      body = ast::IndexOperatorWrite.new(:+, recv, [idx], val)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
      # But its children get typed.
      expect(pass.type_of(val)).to eq(t(:Integer))
    end

    it 'CallOrWrite falls through to ⊤' do
      # obj.x ||= 42
      recv = ast::SelfLiteral::SELF
      val = ast::IntegerLiteral.from(42)
      body = ast::CallOrWrite.new(:x, :x=, recv, val)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).top?).to be true
      expect(pass.type_of(val)).to eq(t(:Integer))
    end
  end

  describe 'Wave-5 long tail' do
    it 'InstanceVariableWrite returns the RHS' do
      body = ast::InstanceVariableWrite.new(:@x, ast::IntegerLiteral.from(1))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'ClassVariableWrite returns the RHS' do
      body = ast::ClassVariableWrite.new(:@@x, ast::FloatLiteral.new(1.5))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Float))
    end

    it 'GlobalVariableWrite returns the RHS' do
      body = ast::GlobalVariableWrite.new(:"$x", ast::IntegerLiteral.from(42))
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'SplatArg is transparent to its value node' do
      inner = ast::IntegerLiteral.from(42)
      body = ast::SplatArg.new(inner)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      # SplatArg passes through — Integer here (would actually be
      # Array-of-ints at runtime, but Tier 1's job is to type the
      # call-site view; splat handling is call-site's problem).
      expect(pass.type_of(body)).to eq(t(:Integer))
    end

    it 'BlockArg is transparent to its value node' do
      inner = ast::SymbolLiteral.from(:to_s)
      body = ast::BlockArg.new(inner)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:Symbol))
    end

    it 'DefinedExpr types as nullable String' do
      body = ast::DefinedExpr.new(:local, :x)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:String, nullable: true))
    end

    it 'DefinedConstant types as nullable String' do
      body = ast::DefinedConstant.new(:Foo)
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body)).to eq(t(:String, nullable: true))
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

    it 'unknown receiver → LUB across all classes for method_name' do
      # `some_var.foo` where some_var is ⊤. Under receiver-cone dispatch,
      # this is the LUB across every class's :foo. No class in this
      # spec's hierarchy has :foo → routes to method_missing → noreturn.
      # Noreturn is join-identity, so LUB = noreturn.
      recv = ast::LocalVariableRead.new(:x, 0)  # x is undefined → ⊤
      call = ast::MethodCall.new(:foo, recv, [], [])
      methods = { [:Foo, :m] => make_method(call) }
      pass = run_pass(methods)
      expect(pass.type_of(call).noreturn?).to be true
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

    it 'returns noreturn when the method is not found anywhere on the ancestor chain' do
      # No `unknown_method` defined anywhere → routes to canonical
      # BasicObject#method_missing which raises → noreturn.
      recv = ast::LocalVariableWrite.new(:x, 0,
        ast::IntrinsicCall.new(:integer__plus_, [
          ast::IntegerLiteral.from(1), ast::IntegerLiteral.from(2)
        ]))
      call = ast::MethodCall.new(:unknown_method, ast::LocalVariableRead.new(:x, 0), [], [])
      body = ast::MethodCall.new(:noop, nil, [recv, call], [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(call).noreturn?).to be true
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

    it 'nullable receiver adds NilClass to the dispatch cone' do
      # x : Integer? (via `cond ? int : nil`). Integer#bar returns
      # Integer; NilClass#bar returns String. Dispatch cone must LUB
      # both — result is the class LUB of Integer + String = Object.
      # Without the nullable-cone fix, only Integer#bar would be
      # consulted and the call would type as Integer, silently missing
      # the nil path.
      integer_bar_body = ast::IntegerLiteral.from(1)
      nil_bar_body     = ast::StringLiteral.from('nope')

      # x = cond ? some_int : nil  →  Integer?
      int_expr = ast::IntrinsicCall.new(:integer__plus_,
                                        [ast::IntegerLiteral.from(1),
                                         ast::IntegerLiteral.from(2)])
      w = ast::LocalVariableWrite.new(:x, 0,
        ast::If.new(ast::TrueLiteral::TRUE, int_expr, ast::NilLiteral::NIL))
      r = ast::LocalVariableRead.new(:x, 0)
      call = ast::MethodCall.new(:bar, r, [], [])
      body = ast::MethodCall.new(:noop, nil, [w, call], [])

      methods = {
        [:Integer, :bar]  => make_method(integer_bar_body),
        [:NilClass, :bar] => make_method(nil_bar_body),
        [:Foo, :m]        => make_method(body),
      }
      pass = run_pass(methods)
      expect(pass.type_of(call)).to eq(t(:Object))
    end

    it 'nullable receiver: missing method on NilClass side contributes noreturn (absorbed)' do
      # x : Integer?. Integer#bar returns Integer; NilClass has no bar
      # (falls through to method_missing → noreturn). LUB(Integer,
      # noreturn) = Integer. Observable proof that the NilClass side
      # was actually consulted: swap Integer#bar out (leaving only
      # NilClass path) and the result becomes noreturn.
      integer_bar_body = ast::IntegerLiteral.from(1)
      int_expr = ast::IntrinsicCall.new(:integer__plus_,
                                        [ast::IntegerLiteral.from(1),
                                         ast::IntegerLiteral.from(2)])
      w = ast::LocalVariableWrite.new(:x, 0,
        ast::If.new(ast::TrueLiteral::TRUE, int_expr, ast::NilLiteral::NIL))
      r = ast::LocalVariableRead.new(:x, 0)
      call = ast::MethodCall.new(:bar, r, [], [])
      body = ast::MethodCall.new(:noop, nil, [w, call], [])
      methods = {
        [:Integer, :bar] => make_method(integer_bar_body),
        [:Foo, :m]       => make_method(body),
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

    it 'types AoT-forbidden intrinsics as NORETURN (execute-time invariant)' do
      # module_define_method mutates the class method table, which is
      # frozen at execute time under closed-world AoT. Its return
      # annotation (:Symbol) documents the load-phase behavior; at
      # execute time it must raise.
      body = ast::IntrinsicCall.new(:module_define_method, [])
      methods = { [:Foo, :m] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).noreturn?).to be true
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
      # No :new registered on any class in this spec's hierarchy →
      # missing-method fallback → noreturn.
      w = ast::LocalVariableWrite.new(:cls, 0, ast::ConstantRead.new(:Foo))
      r = ast::LocalVariableRead.new(:cls, 0)
      call = ast::MethodCall.new(:new, r, [], [])
      body = ast::MethodCall.new(:noop, nil, [w, call], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(call).noreturn?).to be true
    end

    it 'does not peek for methods other than .new / .allocate' do
      # Foo.some_class_method — receiver is a ConstantRead but the
      # method isn't a class-value primitive, so no peek. No class has
      # :some_class_method → noreturn via missing-method fallback.
      body = ast::MethodCall.new(:some_class_method, ast::ConstantRead.new(:Foo), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).noreturn?).to be true
    end

    it 'does not peek when the ConstantRead name is unknown' do
      # NoSuchClass.new — receiver is a ConstantRead but the name
      # doesn't match any class we know about → no peek, fall through
      # to normal dispatch. No :new registered → noreturn.
      body = ast::MethodCall.new(:new, ast::ConstantRead.new(:NoSuchClass), [], [])
      methods = { [:Bar, :make] => make_method(body) }
      pass = run_pass(methods)
      expect(pass.type_of(body).noreturn?).to be true
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

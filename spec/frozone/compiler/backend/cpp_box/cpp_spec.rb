require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# Pure-function tests for `Cpp` (the cpp-string-from-AST-node side of
# the box-first emitter). Cpp is testable in isolation because it
# holds nothing except the per-compilation registries (user_classes /
# user_constants) and produces strings — no buffer, no I/O.

C = Frozone::Compiler::Backend::CppBox::Cpp unless defined?(C)
A = Frozone::Ast unless defined?(A)
V = Frozone::Vm unless defined?(V)

# AST factory helpers — many AST classes have private `new` (singleton
# pattern) or non-trivial signatures. Centralise to keep specs terse.
module AstFactory
  module_function

  def int(n)   = A::IntegerLiteral.from(n)
  def lvr(n)   = A::LocalVariableRead.new(n, 0)
  def lvw(n, value_node) = A::LocalVariableWrite.new(n, 0, value_node)
  def ivr(n)   = A::InstanceVariableRead.new(n)
  def ivw(n, value_node) = A::InstanceVariableWrite.new(n, value_node)
  def cr(n)    = A::ConstantRead.new(n)
  def call(name, receiver, args = [])
    A::MethodCall.new(name, receiver, args, [], nil)
  end
  def aw(name, recv, args)
    A::AttributeWrite.new(name, recv, args, [])
  end
  def arr(elems) = A::ArrayLiteral.new(elems)
  def seq(nodes) = A::Sequence.new(nodes)
  def and_(l, r) = A::And.new(l, r)
  def or_(l, r)  = A::Or.new(l, r)
end

RSpec.describe Frozone::Compiler::Backend::CppBox::Cpp do
  include AstFactory

  let(:cpp) { described_class.new(user_classes: {}, user_constants: {}) }
  let(:locals) { Set.new }

  describe ".method_name" do
    it "maps Ruby operators to m_* via OP_NAMES" do
      expect(described_class.method_name(:+)).to eq("m_plus")
      expect(described_class.method_name(:-)).to eq("m_minus")
      expect(described_class.method_name(:<)).to eq("m_lt")
      expect(described_class.method_name(:==)).to eq("m_eq_q")
      expect(described_class.method_name(:[])).to eq("m_aref")
      expect(described_class.method_name(:[]=)).to eq("m_aset")
      expect(described_class.method_name(:"-@")).to eq("m_neg")
      expect(described_class.method_name(:"<=>")).to eq("m_spaceship")
    end

    it "mangles ? / ! / = suffixes" do
      expect(described_class.method_name(:nil?)).to eq("m_nil_q")
      expect(described_class.method_name(:empty?)).to eq("m_empty_q")
      expect(described_class.method_name(:compact!)).to eq("m_compact_b")
      expect(described_class.method_name(:foo=)).to eq("m_foo_set")
    end

    it "passes plain identifiers through with m_ prefix" do
      expect(described_class.method_name(:size)).to eq("m_size")
      expect(described_class.method_name(:to_s)).to eq("m_to_s")
      expect(described_class.method_name(:fib)).to eq("m_fib")
    end
  end

  describe ".expression_node?" do
    it "is false for Return / Sequence (statement-only shapes)" do
      expect(described_class.expression_node?(A::Return.new(nil))).to eq(false)
      expect(described_class.expression_node?(seq([]))).to eq(false)
    end

    it "is true for value-bearing nodes (including If — emits as ternary)" do
      expect(described_class.expression_node?(int(42))).to eq(true)
      expect(described_class.expression_node?(A::NilLiteral::NIL)).to eq(true)
      expect(described_class.expression_node?(A::If.new(nil, nil, nil))).to eq(true)
    end
  end

  describe "#from_expr — literals" do
    it "IntegerLiteral → boxed Integer with LL suffix" do
      expect(cpp.from_expr(int(42), locals)).to eq("(new Integer(42LL))")
    end

    it "IntegerLiteral preserves negative literals" do
      expect(cpp.from_expr(int(-1), locals)).to eq("(new Integer(-1LL))")
    end

    it "FloatLiteral → boxed Float" do
      node = A::FloatLiteral.new(3.14)
      expect(cpp.from_expr(node, locals)).to eq("(new Float(3.14))")
    end

    it "FloatLiteral preserves negative + scientific notation" do
      expect(cpp.from_expr(A::FloatLiteral.new(-0.5), locals)).to eq("(new Float(-0.5))")
    end

    it "NilLiteral → nil_instance() helper" do
      expect(cpp.from_expr(A::NilLiteral::NIL, locals)).to eq("nil_instance()")
    end

    it "TrueLiteral → true_instance()" do
      expect(cpp.from_expr(A::TrueLiteral::TRUE, locals)).to eq("true_instance()")
    end

    it "FalseLiteral → false_instance()" do
      expect(cpp.from_expr(A::FalseLiteral::FALSE, locals)).to eq("false_instance()")
    end

    it "SelfLiteral → this" do
      expect(cpp.from_expr(A::SelfLiteral::SELF, locals)).to eq("this")
    end
  end

  describe "#from_expr — local variables" do
    it "LocalVariableRead emits the bare name" do
      expect(cpp.from_expr(lvr(:total), locals)).to eq("total")
    end

    it "LocalVariableWrite reassignment when name already in locals" do
      locals << "total"
      expect(cpp.from_expr(lvw(:total, int(0)), locals)).to eq("(total = (new Integer(0LL)))")
    end

    it "LocalVariableWrite expr-position decl raises EmissionError (eager fail)" do
      expect { cpp.from_expr(lvw(:fresh, int(0)), locals) }
        .to raise_error(C::EmissionError, /scope-hoisting/)
    end
  end

  describe "#from_expr — instance variables" do
    it "InstanceVariableRead emits this->iv_<name>" do
      expect(cpp.from_expr(ivr(:@v), locals)).to eq("this->iv_v")
    end

    it "InstanceVariableWrite emits assignment via this->iv_<name>" do
      expect(cpp.from_expr(ivw(:@count, int(7)), locals)).to eq("(this->iv_count = (new Integer(7LL)))")
    end
  end

  describe "#from_expr — method calls" do
    it "binary operator dispatches via m_<op>" do
      expect(cpp.from_expr(call(:<, lvr(:n), [int(2)]), locals)).to eq("n->m_lt((new Integer(2LL)))")
    end

    it "puts (no receiver) emits ruby_puts shim" do
      expect(cpp.from_expr(call(:puts, nil, [int(42)]), locals)).to eq("ruby_puts((new Integer(42LL)))")
    end

    it "bare call (no receiver) dispatches through this->m_<name>" do
      expect(cpp.from_expr(call(:fib, nil, [int(20)]), locals)).to eq("this->m_fib((new Integer(20LL)))")
    end
  end

  describe "#from_expr — .new on class constants" do
    let(:user_class) { instance_double(V::ClassObject, name: :Box) }
    let(:cpp) { described_class.new(user_classes: { Box: user_class }, user_constants: {}) }

    it "user-class .new emits direct C++ instantiation" do
      expect(cpp.from_expr(call(:new, cr(:Box), [int(42)]), locals)).to eq("(new Box((new Integer(42LL))))")
    end

    it "Universe-seeded class .new (Array) also routes through new" do
      expect(cpp.from_expr(call(:new, cr(:Array), []), locals)).to eq("(new Array())")
    end
  end

  describe "#from_expr — ConstantPath (Foo::Bar)" do
    it "raises EmissionError when unregistered (eager fail)" do
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      expect { cpp.from_expr(path, locals) }
        .to raise_error(C::EmissionError, /Foo::Bar/)
    end

    it "deeply nested Foo::Bar::Baz raises with full path in message" do
      foo = A::ConstantRead.new(:Foo)
      foo_bar = A::ConstantPath.new(foo, :Bar)
      foo_bar_baz = A::ConstantPath.new(foo_bar, :Baz)
      expect { cpp.from_expr(foo_bar_baz, locals) }
        .to raise_error(C::EmissionError, /Foo::Bar::Baz/)
    end

    it "registered ConstantPath resolves to flattened k_<flat>() accessor" do
      obj = instance_double(V::ObjectObject)
      cpp = described_class.new(user_classes: {}, user_constants: { Foo_Bar: obj })
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      expect(cpp.from_expr(path, locals)).to eq("k_Foo_Bar()")
    end

    it "RootNamespaceNode parent (`::Foo`) drops the root and uses bare name" do
      root = A::RootNamespaceNode::INSTANCE
      path = A::ConstantPath.new(root, :Foo)
      expect { cpp.from_expr(path, locals) }
        .to raise_error(C::EmissionError, /Foo/)
    end

    it "ConstantPath.new(args) instantiates the flattened class name" do
      user_class = instance_double(V::ClassObject, name: :Foo_Bar)
      cpp = described_class.new(user_classes: { Foo_Bar: user_class }, user_constants: {})
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      call = A::MethodCall.new(:new, path, [int(7)], [], nil)
      expect(cpp.from_expr(call, locals)).to eq("(new Foo_Bar((new Integer(7LL))))")
    end
  end

  describe "#from_expr — ConstantRead value position" do
    it "registered user-constant resolves to k_<NAME>() accessor" do
      obj = instance_double(V::ObjectObject)
      cpp = described_class.new(user_classes: {}, user_constants: { OBJ: obj })
      expect(cpp.from_expr(cr(:OBJ), locals)).to eq("k_OBJ()")
    end

    it "user-class constant resolves to (&Foo_CLASS) eigenclass singleton" do
      user_class = instance_double(V::ClassObject, name: :Box)
      cpp = described_class.new(user_classes: { Box: user_class }, user_constants: {})
      expect(cpp.from_expr(cr(:Box), locals)).to eq("(&Box_CLASS)")
    end

    it "Universe-seeded class constant resolves to (&Foo_CLASS)" do
      expect(cpp.from_expr(cr(:Integer), locals)).to eq("(&Integer_CLASS)")
      expect(cpp.from_expr(cr(:Array), locals)).to eq("(&Array_CLASS)")
    end

    it "raises EmissionError on unresolved constant (eager fail)" do
      expect { cpp.from_expr(cr(:Unknown), locals) }
        .to raise_error(C::EmissionError, /Unknown/)
    end
  end

  describe "#from_expr — collection literals" do
    it "ArrayLiteral emits initializer-list ctor" do
      expect(cpp.from_expr(arr([int(1), int(2)]), locals)).to eq("(new Array({(new Integer(1LL)), (new Integer(2LL))}))")
    end

    it "empty ArrayLiteral" do
      expect(cpp.from_expr(arr([]), locals)).to eq("(new Array({}))")
    end

    it "HashLiteral emits initializer-list ctor of pairs" do
      sym_a = A::SymbolLiteral.from(:a)
      sym_b = A::SymbolLiteral.from(:b)
      node = A::HashLiteral.new([[sym_a, int(1)], [sym_b, int(2)]])
      expect(cpp.from_expr(node, locals)).to eq(
        '(new Hash({{intern("a"), (new Integer(1LL))}, {intern("b"), (new Integer(2LL))}}))'
      )
    end

    it "empty HashLiteral" do
      expect(cpp.from_expr(A::HashLiteral.new([]), locals)).to eq("(new Hash({}))")
    end

    it "HashLiteral skips **splat entries (key=nil)" do
      node = A::HashLiteral.new([[A::SymbolLiteral.from(:a), int(1)], [nil, lvr(:other)]])
      expect(cpp.from_expr(node, locals)).to eq(
        '(new Hash({{intern("a"), (new Integer(1LL))}}))'
      )
    end
  end

  describe "#from_expr — Symbol" do
    it "SymbolLiteral emits intern() call" do
      expect(cpp.from_expr(A::SymbolLiteral.from(:foo), locals)).to eq('intern("foo")')
    end

    it "SymbolLiteral escapes embedded quotes/backslashes" do
      # Pathological case — Ruby does allow these via :"..." syntax.
      expect(cpp.from_expr(A::SymbolLiteral.from(:"a\"b"), locals)).to include('intern(')
    end
  end

  describe "#from_expr — String" do
    it "StringLiteral emits (new String(\"...\", n)) with bytesize" do
      node = A::StringLiteral.from("hello")
      expect(cpp.from_expr(node, locals)).to eq('(new String("hello", 5))')
    end

    it "StringLiteral escapes embedded quotes" do
      node = A::StringLiteral.from('he said "hi"')
      expect(cpp.from_expr(node, locals)).to include('he said \\"hi\\"')
    end

    it "StringLiteral escapes newline + tab" do
      node = A::StringLiteral.from("a\nb\tc")
      expect(cpp.from_expr(node, locals)).to eq('(new String("a\\nb\\tc", 5))')
    end

    it "StringLiteral encodes high bytes as octal escapes" do
      node = A::StringLiteral.from((+"\xC3\xA9").force_encoding("ASCII-8BIT"))
      result = cpp.from_expr(node, locals)
      expect(result).to include('\\303')
      expect(result).to include('\\251')
    end
  end

  describe "#from_expr — If (ternary in expression position)" do
    it "ternary `cond ? a : b` emits C++ ternary" do
      cond = lvr(:c)
      a = int(1)
      b = int(2)
      node = A::If.new(cond, a, b)
      expect(cpp.from_expr(node, locals)).to eq("(truthy(c) ? ((new Integer(1LL))) : ((new Integer(2LL))))")
    end

    it "if without else defaults else to nil_instance" do
      cond = lvr(:c)
      a = int(1)
      node = A::If.new(cond, a, nil)
      expect(cpp.from_expr(node, locals)).to eq("(truthy(c) ? ((new Integer(1LL))) : (nil_instance()))")
    end

    it "if without then defaults then to nil_instance" do
      cond = lvr(:c)
      b = int(2)
      node = A::If.new(cond, nil, b)
      expect(cpp.from_expr(node, locals)).to eq("(truthy(c) ? (nil_instance()) : ((new Integer(2LL))))")
    end
  end

  describe "#from_expr — Case (lambda + early-return)" do
    it "case-with-subject emits subject-binding lambda + m_case_eq dispatch" do
      subj = lvr(:x)
      whens = [A::Case::When.new([int(1)], int(10)), A::Case::When.new([int(2)], int(20))]
      node = A::Case.new(subj, whens, int(0))
      result = cpp.from_expr(node, locals)
      expect(result).to include("auto* _subj = x")
      expect(result).to include("(new Integer(1LL))->m_case_eq(_subj)")
      expect(result).to include("return (new Integer(10LL))")
      expect(result).to include("return (new Integer(0LL))")
    end

    it "case-without-subject treats conditions as truthy tests directly" do
      whens = [A::Case::When.new([lvr(:c1)], int(1)), A::Case::When.new([lvr(:c2)], int(2))]
      node = A::Case.new(nil, whens, nil)
      result = cpp.from_expr(node, locals)
      expect(result).not_to include("_subj")
      expect(result).to include("truthy(c1)")
      expect(result).to include("truthy(c2)")
      expect(result).to include("return nil_instance()")  # default else
    end

    it "multi-condition when (when A, B, C) joins with ||" do
      subj = lvr(:x)
      whens = [A::Case::When.new([int(1), int(2), int(3)], int(99))]
      node = A::Case.new(subj, whens, nil)
      result = cpp.from_expr(node, locals)
      expect(result.scan(/m_case_eq/).size).to eq(3)
      expect(result).to include(" || ")
    end
  end

  describe "#from_expr — short-circuit operators" do
    it "And lambda-wraps to evaluate left once + short-circuit right" do
      result = cpp.from_expr(and_(lvr(:n), lvr(:m)), locals)
      expect(result).to include("auto* _l = n")
      expect(result).to include("truthy(_l) ? (m) : _l")
    end

    it "Or returns first truthy or last" do
      result = cpp.from_expr(or_(lvr(:a), lvr(:b)), locals)
      expect(result).to include("truthy(_l) ? _l : (b)")
    end
  end

  describe "#from_expr — Sequence (parenthesized exprs)" do
    it "single-node Sequence renders as parenthesized expr" do
      expect(cpp.from_expr(seq([int(7)]), locals)).to eq("((new Integer(7LL)))")
    end

    it "multi-node Sequence renders as comma-operator" do
      expect(cpp.from_expr(seq([int(1), int(2)]), locals)).to eq("((new Integer(1LL)), (new Integer(2LL)))")
    end
  end

  describe "#from_expr — AttributeWrite (arr[k] = v)" do
    it "emits m_aset vtable call" do
      expect(cpp.from_expr(aw(:[]=, lvr(:a), [int(0), int(99)]), locals)).to eq("a->m_aset((new Integer(0LL)), (new Integer(99LL)))")
    end
  end

  describe "#from_expr — UNHANDLED eager fail" do
    it "unknown node type raises EmissionError" do
      stub = Object.new
      def stub.is_a?(_); false; end
      def stub.class; Class.new { def name = "FakeNode" }.new; end
      expect { cpp.from_expr(stub, locals) }
        .to raise_error(C::EmissionError, /unhandled AST node/)
    end
  end
end

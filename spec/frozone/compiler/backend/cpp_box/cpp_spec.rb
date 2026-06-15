require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/emitter'

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
    it "maps Ruby operators to op_* via OP_NAMES" do
      expect(described_class.method_name(:+)).to eq("op_plus")
      expect(described_class.method_name(:-)).to eq("op_minus")
      expect(described_class.method_name(:<)).to eq("op_lt")
      expect(described_class.method_name(:==)).to eq("op_eq_q")
      expect(described_class.method_name(:[])).to eq("op_aref")
      expect(described_class.method_name(:[]=)).to eq("op_aset")
      expect(described_class.method_name(:"-@")).to eq("op_neg")
      expect(described_class.method_name(:"<=>")).to eq("op_spaceship")
    end

    it "mangles ? / ! / = suffixes with mm_ prefix" do
      expect(described_class.method_name(:nil?)).to eq("mm_nil_q")
      expect(described_class.method_name(:empty?)).to eq("mm_empty_q")
      expect(described_class.method_name(:compact!)).to eq("mm_compact_bang")
      expect(described_class.method_name(:foo=)).to eq("mm_foo_eq")
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
    it "IntegerLiteral resolves to interned cache (&_f_i_<N>) singleton" do
      # Was `(new Integer(42LL))` — emitter now interns small / common
      # Integer literals at AOT time and references the cached
      # `_f_i_<N>` singleton instead of allocating a new boxed Integer
      # at every call site. `n` prefix on the value marks negative.
      expect(cpp.from_expr(int(42), locals)).to eq("(&_f_i_42)")
    end

    it "IntegerLiteral preserves negative literals via _f_i_n<N>" do
      expect(cpp.from_expr(int(-1), locals)).to eq("(&_f_i_n1)")
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
    it "LocalVariableRead emits the l_<name> mangled identifier" do
      # Was bare `total` — emitter now prefixes user locals with `l_`
      # to dodge collisions with universal-protocol params (`args`,
      # `kwargs`, `block`) and C++ keywords. See MethodEmitter.
      expect(cpp.from_expr(lvr(:total), locals)).to eq("l_total")
    end

    it "LocalVariableWrite reassignment when name already in locals" do
      locals << "total"
      expect(cpp.from_expr(lvw(:total, int(0)), locals)).to eq("(l_total = (&_f_i_0))")
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
      expect(cpp.from_expr(ivw(:@count, int(7)), locals)).to eq("(this->iv_count = (&_f_i_7))")
    end
  end

  describe "#from_expr — method calls" do
    # Note: emitter elides `, nullptr, nullptr` for the kwargs+block
    # default args — the universal vtable signature is
    # `m_X(Array* args = &EMPTY_ARGS, Hash* kwargs = nullptr, Proc*
    # block = nullptr)`, so trailing defaults are taken from the
    # signature rather than spelled at call sites.
    it "binary operator dispatches via op_<op> (defaults elided)" do
      expect(cpp.from_expr(call(:<, lvr(:n), [int(2)]), locals))
        .to eq("l_n->op_lt(univ, (new Array({(&_f_i_2)})))")
    end

    it "puts (no receiver) emits ruby_puts wrapped to return nil_instance" do
      expect(cpp.from_expr(call(:puts, nil, [int(42)]), locals))
        .to eq("(ruby_puts((&_f_i_42)), nil_instance())")
    end

    it "bare call (no receiver) dispatches through this->m_<name>" do
      expect(cpp.from_expr(call(:fib, nil, [int(20)]), locals))
        .to eq("this->m_fib(univ, (new Array({(&_f_i_20)})))")
    end
  end

  describe "#from_expr — .new on class constants" do
    let(:user_class) { instance_double(V::ClassObject, name: :Box) }
    let(:cpp) { described_class.new(user_classes: { Box: user_class }, user_constants: {}) }

    it "user-class .new emits direct C++ instantiation" do
      expect(cpp.from_expr(call(:new, cr(:Box), [int(42)]), locals))
        .to eq("(&Box_CLASS)->m_new(univ, (new Array({(&_f_i_42)})))")
    end

    it "Universe-seeded class .new (Array) — empty args fully elided" do
      expect(cpp.from_expr(call(:new, cr(:Array), []), locals))
        .to eq("(&Array_CLASS)->m_new(univ)")
    end
  end

  describe "#from_expr — ConstantPath (Foo::Bar)" do
    it "raises EmissionError when the parent constant is unregistered" do
      # Resolution attempts the parent's own resolution first
      # (`from_constant_read(:Foo)`); the unresolved-Foo error
      # surfaces before the `Foo::Bar` path even gets to its own
      # check. The error mentions the first-failing leaf rather
      # than the full path.
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      expect { cpp.from_expr(path, locals) }
        .to raise_error(C::EmissionError, /unresolved constant :Foo/)
    end

    it "deeply nested Foo::Bar::Baz still surfaces parent-resolution failure" do
      foo = A::ConstantRead.new(:Foo)
      foo_bar = A::ConstantPath.new(foo, :Bar)
      foo_bar_baz = A::ConstantPath.new(foo_bar, :Baz)
      expect { cpp.from_expr(foo_bar_baz, locals) }
        .to raise_error(C::EmissionError, /unresolved constant :Foo/)
    end

    it "registered ConstantPath resolves to flattened k_<flat>() accessor" do
      obj = instance_double(V::ObjectObject)
      cpp = described_class.new(user_classes: {}, user_constants: { Foo_Bar: obj })
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      expect(cpp.from_expr(path, locals)).to eq("k_Foo_Bar()")
    end

    it "RootNamespaceNode parent (`::Foo`) raises with absolute-path message" do
      root = A::RootNamespaceNode::INSTANCE
      path = A::ConstantPath.new(root, :Foo)
      # Absolute paths can't fall back to runtime c_X dispatch (no
      # parent receiver to dispatch on), so they hard-fail with
      # the path in the message.
      expect { cpp.from_expr(path, locals) }
        .to raise_error(C::EmissionError, /unresolved path Foo/)
    end

    it "ConstantPath.new(args) instantiates the flattened class name" do
      user_class = instance_double(V::ClassObject, name: :Foo_Bar)
      cpp = described_class.new(user_classes: { Foo_Bar: user_class }, user_constants: {})
      foo = A::ConstantRead.new(:Foo)
      path = A::ConstantPath.new(foo, :Bar)
      call = A::MethodCall.new(:new, path, [int(7)], [], nil)
      expect(cpp.from_expr(call, locals)).to eq("(&Foo_Bar_CLASS)->m_new(univ, (new Array({(&_f_i_7)})))")
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
      expect(cpp.from_expr(arr([int(1), int(2)]), locals))
        .to eq("(new Array({(&_f_i_1), (&_f_i_2)}))")
    end

    it "empty ArrayLiteral" do
      expect(cpp.from_expr(arr([]), locals)).to eq("(new Array({}))")
    end

    it "HashLiteral emits initializer-list ctor of pairs" do
      sym_a = A::SymbolLiteral.from(:a)
      sym_b = A::SymbolLiteral.from(:b)
      node = A::HashLiteral.new([[sym_a, int(1)], [sym_b, int(2)]])
      expect(cpp.from_expr(node, locals)).to eq(
        '(new Hash({{intern("a"), (&_f_i_1)}, {intern("b"), (&_f_i_2)}}))'
      )
    end

    it "empty HashLiteral" do
      expect(cpp.from_expr(A::HashLiteral.new([]), locals)).to eq("(new Hash({}))")
    end

    it "HashLiteral skips **splat entries (key=nil)" do
      node = A::HashLiteral.new([[A::SymbolLiteral.from(:a), int(1)], [nil, lvr(:other)]])
      expect(cpp.from_expr(node, locals)).to eq(
        '(new Hash({{intern("a"), (&_f_i_1)}}))'
      )
    end
  end

  describe "#from_expr — Yield" do
    it "yield with no args uses the arity-specialized call0 slot (#167)" do
      node = A::Yield.new([])
      expect(cpp.from_expr(node, locals)).to eq("_block->call0()")
    end

    it "yield with one arg uses the arity-specialized call1 slot (#167)" do
      node = A::Yield.new([int(42)])
      expect(cpp.from_expr(node, locals))
        .to eq("_block->call1((&_f_i_42))")
    end
  end

  describe "#from_expr — splat in call args" do
    it "single SplatArg passes the value via splat_to_array (to_a coercion)" do
      arr = lvr(:arr)
      splat = A::SplatArg.new(arr)
      node = A::MethodCall.new(:collect, nil, [splat], [], nil)
      expect(cpp.from_expr(node, locals))
        .to eq("this->m_collect(univ, splat_to_array(l_arr))")
    end

    it "mixed positional + splat flattens into a fresh Array via lambda" do
      arr = lvr(:arr)
      node = A::MethodCall.new(:foo, nil, [int(1), A::SplatArg.new(arr), int(5)], [], nil)
      result = cpp.from_expr(node, locals)
      expect(result).to include("this->m_foo(")
      expect(result).to include("Array* _r = new Array()")
      expect(result).to include("_r->data.push_back((&_f_i_1))")
      expect(result).to include("for (auto* _e : splat_to_array(l_arr)->data) _r->data.push_back(_e)")
      expect(result).to include("_r->data.push_back((&_f_i_5))")
    end
  end

  describe "#from_expr — block-bearing call" do
    it "wraps block as Proc lambda and passes as trailing arg" do
      # from_block_as_proc renders the block body via emit.capture
      # and the body's exprs need to call back into emit.cpp, so
      # the Cpp instance needs an Emit and the Emit needs to know
      # this Cpp. Production wires this in Emitter.generate; spec
      # threads it manually here.
      emitter = Frozone::Compiler::Backend::CppBox::Emitter.new
      emitter.instance_variable_set(:@cpp, cpp)
      cpp.emit = emitter
      blk = A::Block.new(
        [:n], [], nil, [],     # required, optional, rest, post
        [], [], nil, nil,      # kw, opt-kw, kw-rest, block
        false, [],             # auto_splat, locals
        call(:puts, nil, [lvr(:n)])  # body
      )
      thrice = A::MethodCall.new(:thrice, nil, [], [], blk)
      result = cpp.from_expr(thrice, locals)
      expect(result).to include("this->m_thrice(")
      # Block has 1 required positional param + no kw / opt / rest /
      # captured deref — eligible for Proc1 specialization (#167).
      # The lambda parameter IS `l_n` directly; no `__blkargs__`
      # unpack needed. Captures `this` POINTER by value (`[&, this]`),
      # locals by ref — so Procs stored on ivars don't dangle.
      # See pitfalls #1.
      expect(result).to include("(new Proc1([&, this](BO* l_n) -> BO*")
      expect(result).to include("return")
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
    # Arms get `static_cast<BO*>(...)` wrappers so the C++
    # ternary's type-deduction picks a common type when the two arms
    # are distinct pointer types (Integer* vs Nil*, etc.).
    it "ternary `cond ? a : b` emits C++ ternary with BO* casts" do
      cond = lvr(:c)
      a = int(1)
      b = int(2)
      node = A::If.new(cond, a, b)
      expect(cpp.from_expr(node, locals))
        .to eq("(truthy(l_c) ? static_cast<BO*>((&_f_i_1)) : static_cast<BO*>((&_f_i_2)))")
    end

    it "if without else defaults else to nil_instance" do
      cond = lvr(:c)
      a = int(1)
      node = A::If.new(cond, a, nil)
      expect(cpp.from_expr(node, locals))
        .to eq("(truthy(l_c) ? static_cast<BO*>((&_f_i_1)) : static_cast<BO*>(nil_instance()))")
    end

    it "if without then defaults then to nil_instance" do
      cond = lvr(:c)
      b = int(2)
      node = A::If.new(cond, nil, b)
      expect(cpp.from_expr(node, locals))
        .to eq("(truthy(l_c) ? static_cast<BO*>(nil_instance()) : static_cast<BO*>((&_f_i_2)))")
    end
  end

  describe "#from_expr — Case (lambda + early-return)" do
    # Case lowering routes through LambdaEmitter, which needs the
    # emitter wired up so body_as_block can reach back to cpp. Mirrors
    # the block-bearing-call test's scaffold (#from_expr — block-bearing
    # call), same pattern.
    before do
      emitter = Frozone::Compiler::Backend::CppBox::Emitter.new
      emitter.instance_variable_set(:@cpp, cpp)
      cpp.emit = emitter
    end

    it "case-with-subject emits subject-binding stmt-expr + op_case_eq dispatch" do
      subj = lvr(:x)
      whens = [A::Case::When.new([int(1)], int(10)), A::Case::When.new([int(2)], int(20))]
      node = A::Case.new(subj, whens, int(0))
      result = cpp.from_expr(node, locals)
      # Subject is precomputed once into _subj (shape-agnostic — both IILE
      # and stmt_expr emit it the same way).
      expect(result).to include("auto* _subj = l_x")
      # Each `when` runs the case-eq via op_case_eq(univ, new Array({_subj})).
      expect(result).to include("(&_f_i_1)->op_case_eq(univ, new Array({_subj}))")
      # The arm values appear regardless of form (return v in IILE,
      # ternary arm in stmt_expr).
      expect(result).to include("(&_f_i_10)")
      expect(result).to include("(&_f_i_0)")
    end

    it "case-without-subject treats conditions as truthy tests directly" do
      whens = [A::Case::When.new([lvr(:c1)], int(1)), A::Case::When.new([lvr(:c2)], int(2))]
      node = A::Case.new(nil, whens, nil)
      result = cpp.from_expr(node, locals)
      expect(result).not_to include("_subj")
      expect(result).to include("truthy(l_c1)")
      expect(result).to include("truthy(l_c2)")
      # No explicit `else` → falls through to nil_instance() as the
      # default value (IILE: `return nil_instance();`, stmt_expr:
      # `nil_instance()` as ternary's terminal else).
      expect(result).to include("nil_instance()")
    end

    it "multi-condition when (when A, B, C) joins with ||" do
      subj = lvr(:x)
      whens = [A::Case::When.new([int(1), int(2), int(3)], int(99))]
      node = A::Case.new(subj, whens, nil)
      result = cpp.from_expr(node, locals)
      expect(result.scan(/op_case_eq/).size).to eq(3)
      expect(result).to include(" || ")
    end
  end

  describe "#from_expr — short-circuit operators" do
    it "And lambda-wraps to evaluate left once + short-circuit right" do
      result = cpp.from_expr(and_(lvr(:n), lvr(:m)), locals)
      expect(result).to include("auto* _l = l_n")
      expect(result).to include("truthy(_l) ? (l_m) : _l")
    end

    it "Or returns first truthy or last" do
      result = cpp.from_expr(or_(lvr(:a), lvr(:b)), locals)
      expect(result).to include("truthy(_l) ? _l : (l_b)")
    end
  end

  describe "#from_expr — Sequence (parenthesized exprs)" do
    it "single-node Sequence renders as parenthesized expr" do
      expect(cpp.from_expr(seq([int(7)]), locals)).to eq("((&_f_i_7))")
    end

    it "multi-node Sequence renders as comma-operator" do
      expect(cpp.from_expr(seq([int(1), int(2)]), locals)).to eq("((&_f_i_1), (&_f_i_2))")
    end
  end

  describe "#from_expr — AttributeWrite (arr[k] = v)" do
    it "emits op_aset vtable call (defaults elided)" do
      expect(cpp.from_expr(aw(:[]=, lvr(:a), [int(0), int(99)]), locals))
        .to eq("l_a->op_aset(univ, new Array({(&_f_i_0), (&_f_i_99)}))")
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

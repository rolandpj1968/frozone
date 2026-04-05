require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/type_inference'

TI = Frozone::Compiler::TypeInference

RSpec.describe Frozone::Compiler::TypeInference do
  # Helper: build a minimal TI instance (no user code).
  def ti(user_methods: {}, user_classes: {}, execute_block: nil, constants: {})
    TI.new(user_methods: user_methods, user_classes: user_classes,
           execute_block: execute_block, constants: constants)
  end

  # Helper: parse a Ruby snippet and return its AST.
  # Pass locals: to tell Prism which names are local variables (not method calls).
  def parse(code, locals: [])
    Frozone::Vm::Parser.new(code, outer_locals: locals).ast
  end

  # Helper: parse a method body, build TI, run it, and return the env.
  # The method is registered as top-level :test_method.
  def infer_method(code, params: [], constants: {})
    scope = Frozone::Vm::Core::OBJECT_CLASS
    body = parse(code, locals: params)
    method = make_method(scope, :test_method, body: body, required_params: params)
    t = ti(user_methods: { test_method: method }, constants: constants)
    t.run
  end

  # Helper: parse an execute block + optional methods, run TI, return env.
  def infer_execute(code, methods: {}, constants: {})
    body = parse(code)
    block = Frozone::Ast::Block.new(
      [], [], nil, [],   # required, optional, rest, post params
      [], [], nil, nil,  # kw params, block_param
      false, [], body    # auto_splat, locals, body
    )
    t = ti(user_methods: methods, execute_block: block, constants: constants)
    t.run
  end

  # =====================================================================
  # join— lattice operations
  # =====================================================================

  describe "#join" do
    let(:t) { ti }

    context "identity" do
      it ":unknown is the identity element" do
        expect(t.join(:unknown, :i64)).to eq(:i64)
        expect(t.join(:f64, :unknown)).to eq(:f64)
        expect(t.join(:unknown, :unknown)).to eq(:unknown)
      end
    end

    context "same type" do
      it "returns the type unchanged" do
        expect(t.join(:i64, :i64)).to eq(:i64)
        expect(t.join(:f64, :f64)).to eq(:f64)
        expect(t.join({class: :String}, {class: :String})).to eq({class: :String})
      end
    end

    context "numeric widening" do
      it "i64 joinf64 → Numeric" do
        result = t.join(:i64, :f64)
        expect(result).to be_a(Hash)
        expect(result[:class]).to eq(:Numeric)
      end

      it "f64 joini64 → Numeric (commutative)" do
        expect(t.join(:f64, :i64)).to eq(t.join(:i64, :f64))
      end
    end

    context "NilClass preserves nullable" do
      it "NilClass joinX → X with nullable" do
        result = t.join({class: :NilClass}, {class: :String})
        expect(result[:class]).to eq(:String)
        expect(result[:nullable]).to eq(true)
      end

      it "X joinNilClass → X with nullable (commutative)" do
        result = t.join({class: :Integer}, {class: :NilClass})
        expect(result[:class]).to eq(:Integer)
        expect(result[:nullable]).to eq(true)
      end

      it "NilClass join:i64 → Integer with nullable" do
        result = t.join({class: :NilClass}, :i64)
        expect(result[:class]).to eq(:Integer)
        expect(result[:nullable]).to eq(true)
      end
    end

    context "nullable preservation through same-class join" do
      it "(X|Nil) join(X|Nil) → (X|Nil)" do
        a = {class: :Node, nullable: true}
        b = {class: :Node, nullable: true}
        result = t.join(a, b)
        expect(result[:class]).to eq(:Node)
        expect(result[:nullable]).to eq(true)
      end

      it "(X|Nil) joinX → (X|Nil)" do
        a = {class: :String, nullable: true}
        b = {class: :String}
        result = t.join(a, b)
        expect(result[:class]).to eq(:String)
        expect(result[:nullable]).to eq(true)
      end

      it "X join(X|Nil) → (X|Nil)" do
        a = {class: :String}
        b = {class: :String, nullable: true}
        result = t.join(a, b)
        expect(result[:class]).to eq(:String)
        expect(result[:nullable]).to eq(true)
      end
    end

    context "nullable preservation with collection params" do
      it "Array(i64)|Nil joinArray(i64)|Nil preserves nullable and elem" do
        a = {class: :Array, elem: :i64, nullable: true}
        b = {class: :Array, elem: :i64, nullable: true}
        result = t.join(a, b)
        expect(result[:class]).to eq(:Array)
        expect(result[:elem]).to eq(:i64)
        expect(result[:nullable]).to eq(true)
      end
    end

    context "LCA for different classes" do
      it "Integer joinString → Object" do
        result = t.join({class: :Integer}, {class: :String})
        expect(result[:class]).to eq(:Object)
      end

      it "Integer joinFloat → Numeric" do
        result = t.join({class: :Integer}, {class: :Float})
        expect(result[:class]).to eq(:Numeric)
      end

      it "File joinString → Object" do
        result = t.join({class: :File}, {class: :String})
        expect(result[:class]).to eq(:Object)
      end
    end

    context "array type widening" do
      it "array_i64 joinarray_f64 → Array" do
        result = t.join(:array_i64, :array_f64)
        expect(result).to be_a(Hash)
        expect(result[:class]).to eq(:Array)
      end

      it "array_i64 joini64 → Object (array vs scalar)" do
        result = t.join(:array_i64, :i64)
        expect(result).to be_a(Hash)
        # Array meets Integer → Object
        expect(result[:class]).to eq(:Object)
      end
    end
  end

  # =====================================================================
  # infer_expr — expression-level type inference
  # =====================================================================

  describe "#infer_expr" do
    context "literals" do
      it "integer → :i64" do
        env = infer_method("42")
        # The return slot should be :i64
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "float → :f64" do
        env = infer_method("3.14")
        expect(env[[:return, :test_method]]).to eq(:f64)
      end

      it "nil → NilClass" do
        env = infer_method("nil")
        expect(env[[:return, :test_method]]).to eq({class: :NilClass})
      end

      it "true → TrueClass" do
        env = infer_method("true")
        expect(env[[:return, :test_method]]).to eq({class: :TrueClass})
      end

      it "string → String" do
        env = infer_method("'hello'")
        expect(env[[:return, :test_method]]).to eq({class: :String})
      end

      it "symbol → Symbol" do
        env = infer_method(":foo")
        expect(env[[:return, :test_method]]).to eq({class: :Symbol})
      end
    end

    context "array literals" do
      it "empty array → Array (no elem)" do
        env = infer_method("[]")
        ret = env[[:return, :test_method]]
        expect(ret[:class]).to eq(:Array)
        expect(ret[:elem]).to be_nil
      end

      it "[1, 2, 3] → Array with elem :i64" do
        env = infer_method("[1, 2, 3]")
        ret = env[[:return, :test_method]]
        expect(ret[:class]).to eq(:Array)
        expect(ret[:elem]).to eq(:i64)
      end

      it "[1.0, 2.0] → Array with elem :f64" do
        env = infer_method("[1.0, 2.0]")
        ret = env[[:return, :test_method]]
        expect(ret[:class]).to eq(:Array)
        expect(ret[:elem]).to eq(:f64)
      end

      it "[1, 2.0] → Array with elem Numeric" do
        env = infer_method("[1, 2.0]")
        ret = env[[:return, :test_method]]
        expect(ret[:class]).to eq(:Array)
        expect(ret[:elem]).to be_a(Hash)
        expect(ret[:elem][:class]).to eq(:Numeric)
      end
    end

    context "arithmetic" do
      it "i64 + i64 → i64" do
        env = infer_method("1 + 2")
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "f64 + f64 → f64" do
        env = infer_method("1.0 + 2.0")
        expect(env[[:return, :test_method]]).to eq(:f64)
      end

      it "i64 + f64 → f64" do
        env = infer_method("1 + 2.0")
        expect(env[[:return, :test_method]]).to eq(:f64)
      end

      it "i64 * i64 → i64" do
        env = infer_method("3 * 4")
        expect(env[[:return, :test_method]]).to eq(:i64)
      end
    end

    context "local variable assignment" do
      it "tracks local types through assignment" do
        env = infer_method("x = 42\nx")
        expect(env[[:local, :test_method, :x]]).to eq(:i64)
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "local widened by multiple assignments" do
        env = infer_method("x = 42\nx = 3.14\nx")
        expect(env[[:local, :test_method, :x]]).to be_a(Hash)
        expect(env[[:local, :test_method, :x]][:class]).to eq(:Numeric)
      end

      it "local tracks nil assignment" do
        env = infer_method("x = nil\nx")
        expect(env[[:local, :test_method, :x]]).to eq({class: :NilClass})
      end
    end

    context "logical operators" do
      it "Or node infers joinof both sides" do
        t = ti
        t.instance_variable_set(:@_expr_cache, {})
        left = parse("1").nodes.first   # IntegerLiteral
        right = parse("2.0").nodes.first # FloatLiteral
        or_node = Frozone::Ast::Or.new(left, right)
        result = t.send(:infer_expr, or_node, TI::TOP_LEVEL_CTX)
        expect(result).to be_a(Hash)
        expect(result[:class]).to eq(:Numeric)
      end
    end

    context "comparisons" do
      it "== does not crash (result may be unknown)" do
        env = infer_method("1 == 2")
        ret = env[[:return, :test_method]]
        expect(ret).to be_nil.or be_a(Hash).or be_a(Symbol)
      end
    end

    context "built-in method returns" do
      it "Random#rand → :f64 (no args)" do
        env = infer_method("r = Random.new(42)\nr.rand")
        expect(env[[:return, :test_method]]).to eq(:f64)
      end

      it "Random#rand(n) → :i64" do
        env = infer_method("r = Random.new(42)\nr.rand(100)")
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "to_i → :i64" do
        env = infer_method("3.14.to_i")
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "to_f → :f64" do
        env = infer_method("42.to_f")
        expect(env[[:return, :test_method]]).to eq(:f64)
      end
    end
  end

  # =====================================================================
  # Functional: call-site propagation
  # =====================================================================

  describe "call-site type propagation" do
    it "propagates argument types to method params" do
      scope = Frozone::Vm::Core::OBJECT_CLASS
      body = parse("n", locals: [:n])
      method = make_method(scope, :identity, body: body, required_params: [:n])

      env = infer_execute("identity(42)", methods: { identity: method })
      expect(env[[:param, :identity, 0]]).to eq(:i64)
      expect(env[[:return, :identity]]).to eq(:i64)
    end

    it "widens params from multiple call sites" do
      scope = Frozone::Vm::Core::OBJECT_CLASS
      body = parse("n", locals: [:n])
      method = make_method(scope, :echo, body: body, required_params: [:n])

      env = infer_execute("echo(42)\necho(3.14)", methods: { echo: method })
      param_type = env[[:param, :echo, 0]]
      expect(param_type).to be_a(Hash)
      expect(param_type[:class]).to eq(:Numeric)
    end

    it "infers return type from body" do
      scope = Frozone::Vm::Core::OBJECT_CLASS
      body = parse("n + 1", locals: [:n])
      method = make_method(scope, :inc, body: body, required_params: [:n])

      env = infer_execute("inc(42)", methods: { inc: method })
      expect(env[[:return, :inc]]).to eq(:i64)
    end

    it "infers return type from explicit return inside block" do
      scope = Frozone::Vm::Core::OBJECT_CLASS
      # loop { return 42 } — the explicit return inside the block
      body = parse("loop { return 42 }")
      method = make_method(scope, :loopy, body: body)

      t = ti(user_methods: { loopy: method })
      env = t.run
      expect(env[[:return, :loopy]]).to eq(:i64)
    end

    it "propagates return type through callers" do
      scope = Frozone::Vm::Core::OBJECT_CLASS
      getter_body = parse("42")
      getter = make_method(scope, :get_val, body: getter_body)

      user_body = parse("x = get_val\nx", locals: [:x])
      user = make_method(scope, :use_val, body: user_body)

      env = infer_execute("use_val", methods: { get_val: getter, use_val: user })
      expect(env[[:return, :get_val]]).to eq(:i64)
      expect(env[[:return, :use_val]]).to eq(:i64)
    end
  end

  # =====================================================================
  # Functional: constant typing
  # =====================================================================

  describe "constant typing" do
    it "types integer constants" do
      int_obj = Frozone::Vm::IntegerObject.new(42)
      env = infer_execute("1", constants: { ANSWER: int_obj })
      expect(env[[:const, :ANSWER]]).to eq(:i64)
    end

    it "types float constants" do
      float_obj = Frozone::Vm::FloatObject.new(3.14)
      env = infer_execute("1", constants: { PI: float_obj })
      expect(env[[:const, :PI]]).to eq(:f64)
    end
  end

  # =====================================================================
  # Constructor context sensitivity
  # =====================================================================

  describe "constructor context sensitivity" do
    it "excludes NilClass contexts from ivar typing" do
      t = ti
      env = t.env
      # Simulate two calling contexts: insert passes :f64, splay! passes NilClass
      env.join!([:constructor_param, :Node, 0, :insert], :f64)
      env.join!([:constructor_param, :Node, 0, :"splay!"], {class: :NilClass})

      result = t.send(:best_constructor_param_types, :Node, 1)
      expect(result).to eq([:f64])
    end

    it "merges non-nil contexts normally" do
      t = ti
      env = t.env
      env.join!([:constructor_param, :Pt, 0, :make_pt], :f64)
      env.join!([:constructor_param, :Pt, 0, :make_pt2], :i64)

      result = t.send(:best_constructor_param_types, :Pt, 1)
      expect(result[0]).to be_a(Hash)
      expect(result[0][:class]).to eq(:Numeric)
    end

    it "defers when all contexts are nil (returns :unknown)" do
      t = ti
      env = t.env
      env.join!([:constructor_param, :Dummy, 0, :foo], {class: :NilClass})

      result = t.send(:best_constructor_param_types, :Dummy, 1)
      expect(result[0]).to eq(:unknown)
    end
  end

  # =====================================================================
  # TypeEnv
  # =====================================================================

  describe TI::TypeEnv do
    let(:t) { ti }
    let(:env) { t.env }

    it "returns nil for unset slots" do
      expect(env[[:local, :foo, :x]]).to be_nil
    end

    it "join! stores and returns changed" do
      expect(env.join!([:local, :foo, :x], :i64)).to be true
      expect(env[[:local, :foo, :x]]).to eq(:i64)
    end

    it "join! returns false when unchanged" do
      env.join!([:local, :foo, :x], :i64)
      expect(env.join!([:local, :foo, :x], :i64)).to be false
    end

    it "join! computes LCA of i64 and f64 as Numeric" do
      env.join!([:local, :foo, :x], :i64)
      env.join!([:local, :foo, :x], :f64)
      result = env[[:local, :foo, :x]]
      expect(result).to be_a(Hash)
      expect(result[:class]).to eq(:Numeric)
    end

    it "join! with NilClass adds nullable" do
      env.join!([:local, :foo, :x], {class: :String})
      env.join!([:local, :foo, :x], {class: :NilClass})
      result = env[[:local, :foo, :x]]
      expect(result[:class]).to eq(:String)
      expect(result[:nullable]).to eq(true)
    end
  end
end

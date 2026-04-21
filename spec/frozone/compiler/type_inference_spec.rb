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
    let(:ty) { Frozone::Compiler::Type }

    context "identity" do
      it "bottom is the identity element" do
        expect(t.join(ty::BOTTOM, ty::I64)).to eq(ty::I64)
        expect(t.join(ty::F64, ty::BOTTOM)).to eq(ty::F64)
        expect(t.join(ty::BOTTOM, ty::BOTTOM)).to eq(ty::BOTTOM)
      end
    end

    context "same type" do
      it "returns the type unchanged" do
        expect(t.join(ty::I64, ty::I64)).to eq(ty::I64)
        expect(t.join(ty::F64, ty::F64)).to eq(ty::F64)
        expect(t.join(ty::STRING, ty::STRING)).to eq(ty::STRING)
      end
    end

    context "numeric LCA" do
      it "i64 join f64 → f64 (Ruby numeric widening)" do
        expect(t.join(ty::I64, ty::F64)).to eq(ty::F64)
      end

      it "f64 join i64 → Numeric (commutative)" do
        expect(t.join(ty::F64, ty::I64)).to eq(t.join(ty::I64, ty::F64))
      end
    end

    context "NilClass preserves nullable" do
      it "NilClass join X → X with nullable" do
        result = t.join(ty::NIL_CLASS, ty::STRING)
        expect(result.class_name).to eq(:String)
        expect(result).to be_nullable
      end

      it "X join NilClass → X with nullable (commutative)" do
        result = t.join(ty::INTEGER, ty::NIL_CLASS)
        expect(result.class_name).to eq(:Integer)
        expect(result).to be_nullable
      end

      it "NilClass join i64 → Integer with nullable" do
        result = t.join(ty::NIL_CLASS, ty::I64)
        expect(result.class_name).to eq(:Integer)
        expect(result).to be_nullable
      end
    end

    context "nullable preservation through same-class join" do
      it "(X|Nil) join (X|Nil) → (X|Nil)" do
        a = ty.of(:Node, nullable: true)
        b = ty.of(:Node, nullable: true)
        result = t.join(a, b)
        expect(result.class_name).to eq(:Node)
        expect(result).to be_nullable
      end

      it "(X|Nil) join X → (X|Nil)" do
        a = ty.of(:String, nullable: true)
        result = t.join(a, ty::STRING)
        expect(result.class_name).to eq(:String)
        expect(result).to be_nullable
      end

      it "X join (X|Nil) → (X|Nil)" do
        b = ty.of(:String, nullable: true)
        result = t.join(ty::STRING, b)
        expect(result.class_name).to eq(:String)
        expect(result).to be_nullable
      end
    end

    context "nullable preservation with collection params" do
      it "Array(i64)|Nil join Array(i64)|Nil preserves nullable and elem" do
        a = ty.new(:class_type, class_name: :Array, elem: ty::I64, nullable: true)
        b = ty.new(:class_type, class_name: :Array, elem: ty::I64, nullable: true)
        result = t.join(a, b)
        expect(result.class_name).to eq(:Array)
        expect(result.elem).to eq(ty::I64)
        expect(result).to be_nullable
      end
    end

    context "LCA for different classes" do
      it "Integer join String → Object" do
        expect(t.join(ty::INTEGER, ty::STRING).class_name).to eq(:Object)
      end

      it "Integer join Float → Float (Ruby numeric widening)" do
        expect(t.join(ty::INTEGER, ty::FLOAT)).to eq(ty::F64)
      end

      it "File join String → Object" do
        expect(t.join(ty.of(:File), ty::STRING).class_name).to eq(:Object)
      end
    end

    context "array type LCA" do
      it "ARRAY_I64 join ARRAY_F64 → Array(Numeric)" do
        result = t.join(ty::ARRAY_I64, ty::ARRAY_F64)
        expect(result.class_name).to eq(:Array)
      end

      it "ARRAY_I64 join I64 → Object (array vs scalar)" do
        result = t.join(ty::ARRAY_I64, ty::I64)
        expect(result.class_name).to eq(:Object)
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

      it "[1, 2.0] → Array with elem :f64 (Ruby numeric widening)" do
        env = infer_method("[1, 2.0]")
        ret = env[[:return, :test_method]]
        expect(ret[:class]).to eq(:Array)
        expect(ret[:elem]).to eq(:f64)
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

    # =====================================================================
    # Integer-bounds tracking and propagation through arithmetic.
    # =====================================================================

    context "integer bounds" do
      let(:ty) { Frozone::Compiler::Type }

      # Helper: infer a single expression and return the bounded Type
      # for the return slot.
      def return_type(code)
        env = infer_method(code)
        env.type_of([:return, :test_method])
      end

      describe "literal propagation" do
        it "small literal → bounded [v, v]" do
          expect(return_type("42").int_bounds).to eq([42, 42])
        end

        it "negative literal → bounded [v, v]" do
          expect(return_type("-10").int_bounds).to eq([-10, -10])
        end

        it "large literal still bounded" do
          expect(return_type("1_000_000").int_bounds).to eq([1_000_000, 1_000_000])
        end
      end

      describe "narrowest_int_type" do
        it "[0, 255] → UInt8" do
          expect(ty.i64_bounded(0, 255).narrowest_int_type).to eq("UInt8")
        end

        it "[0, 256] → UInt16" do
          expect(ty.i64_bounded(0, 256).narrowest_int_type).to eq("UInt16")
        end

        it "[-1, 1] → Int8" do
          expect(ty.i64_bounded(-1, 1).narrowest_int_type).to eq("Int8")
        end

        it "[-100, 1000] → Int16" do
          expect(ty.i64_bounded(-100, 1000).narrowest_int_type).to eq("Int16")
        end

        it "unbounded I64 → nil" do
          expect(ty::I64.narrowest_int_type).to be_nil
        end
      end

      describe "arithmetic propagation" do
        it "10 + 20 → [30, 30]" do
          expect(return_type("10 + 20").int_bounds).to eq([30, 30])
        end

        it "50 - 12 → [38, 38]" do
          expect(return_type("50 - 12").int_bounds).to eq([38, 38])
        end

        it "7 * 8 → [56, 56]" do
          expect(return_type("7 * 8").int_bounds).to eq([56, 56])
        end

        it "100 % 3 → [0, 2] (Ruby modulo, divisor positive)" do
          expect(return_type("100 % 3").int_bounds).to eq([0, 2])
        end

        it "0xff & 0x0f → [0, 15]" do
          expect(return_type("0xff & 0x0f").int_bounds).to eq([0, 15])
        end

        it "0x80 | 0x40 → [128, 255] (next-pow2 widening)" do
          expect(return_type("0x80 | 0x40").int_bounds).to eq([128, 255])
        end

        it "0x05 << 3 → [40, 40]" do
          expect(return_type("0x05 << 3").int_bounds).to eq([40, 40])
        end

        it "0x100 >> 4 → [16, 16]" do
          expect(return_type("0x100 >> 4").int_bounds).to eq([16, 16])
        end

        it "(1 + 2) * (3 - 1) → [6, 6] (nested propagation)" do
          expect(return_type("(1 + 2) * (3 - 1)").int_bounds).to eq([6, 6])
        end

        it "subtraction with mixed signs: 5 - 8 → [-3, -3]" do
          expect(return_type("5 - 8").int_bounds).to eq([-3, -3])
        end

        it "multiplication of negative: -2 * 3 → [-6, -6]" do
          expect(return_type("-2 * 3").int_bounds).to eq([-6, -6])
        end
      end

      describe "bail-out cases (drop to unbounded)" do
        it "loop accumulator drops to unbounded I64" do
          # n.times { x += 1 } — TI can't bound x without loop analysis,
          # so the local should NOT have tight bounds at exit.
          env = infer_method("x = 0\n10.times { x += 1 }\nx")
          x_ty = env.type_of([:local, :test_method, :x])
          # The local should be Type::I64 (no tracked bounds), or at
          # most loosely bounded — definitely NOT [10, 10] (which would
          # be unsound without loop bound analysis).
          expect(x_ty.int_bounds).to(satisfy { |b| b.nil? || (b[0] != 10 || b[1] != 10) })
        end

        it "constant array of literal numerics: bounds union via join" do
          # The array literal should compute its elem bounds as the join
          # of element bounds, which is the union of [v, v] singletons.
          ti_env = infer_method("[0, 1, 2, 3, 255]")
          arr_ty = ti_env.type_of([:return, :test_method])
          expect(arr_ty.elem.int_bounds).to eq([0, 255])
        end

        it "array with mixed bounds: [-100, 0, 1000]" do
          ti_env = infer_method("[-100, 0, 1000]")
          expect(ti_env.type_of([:return, :test_method]).elem.int_bounds).to eq([-100, 1000])
        end
      end

      describe "locals deliberately drop bounds" do
        # Locals never carry bounds — without loop-bound analysis the
        # tracked-bounds-on-a-local would be unsound for any code that
        # later writes to it inside a loop. See docs/int-soundness.md.
        # Per-expression propagation through pure arithmetic on
        # literals still works (the previous block) — only the
        # local-variable slot is intentionally bounds-free.

        it "x = 10; x → unbounded I64 (bounds stripped at local-write)" do
          expect(return_type("x = 10\nx").int_bounds).to be_nil
        end

        it "x = 10; x + 1 → unbounded I64 (x is now unbounded)" do
          # Loses precision compared to the literal-only case `10 + 1`,
          # but is sound: x could be reassigned in a loop after this.
          expect(return_type("x = 10\nx + 1").int_bounds).to be_nil
        end

        it "literal arithmetic still tracks bounds" do
          expect(return_type("(10 + 1) * 2").int_bounds).to eq([22, 22])
        end
      end
    end

    context "local variable assignment" do
      it "tracks local types through assignment" do
        env = infer_method("x = 42\nx")
        expect(env[[:local, :test_method, :x]]).to eq(:i64)
        expect(env[[:return, :test_method]]).to eq(:i64)
      end

      it "local widened by multiple assignments" do
        # Int ∪ Float → Float (Ruby numeric widening).
        env = infer_method("x = 42\nx = 3.14\nx")
        expect(env[[:local, :test_method, :x]]).to eq(:f64)
      end

      it "local tracks nil assignment" do
        env = infer_method("x = nil\nx")
        expect(env[[:local, :test_method, :x]]).to eq({class: :NilClass})
      end
    end

    context "logical operators" do
      it "Or node infers join of both sides (Int ∪ Float → Float)" do
        t = ti
        t.instance_variable_set(:@_expr_cache, {})
        left = parse("1").nodes.first   # IntegerLiteral
        right = parse("2.0").nodes.first # FloatLiteral
        or_node = Frozone::Ast::Or.new(left, right)
        result = t.send(:infer_expr, or_node, TI::TOP_LEVEL_CTX)
        expect(result).to eq(Frozone::Compiler::Type::F64)
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
      # Ruby numeric widening: Int ∪ Float → Float (see TypeEnv#join!).
      expect(env[[:param, :echo, 0]]).to eq(:f64)
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
      env.join!([:constructor_param, :Node, 0, :insert], :f64)
      env.join!([:constructor_param, :Node, 0, :"splay!"], {class: :NilClass})

      result = t.send(:best_constructor_param_types, :Node, 1)
      expect(result).to eq([Frozone::Compiler::Type::F64])
    end

    it "merges non-nil contexts normally" do
      t = ti
      env = t.env
      env.join!([:constructor_param, :Pt, 0, :make_pt], :f64)
      env.join!([:constructor_param, :Pt, 0, :make_pt2], :i64)

      # Ruby numeric widening: Int ∪ Float → Float (see TypeEnv#join!).
      result = t.send(:best_constructor_param_types, :Pt, 1)
      expect(result[0]).to eq(Frozone::Compiler::Type::F64)
    end

    it "defers when all contexts are nil (returns bottom)" do
      t = ti
      env = t.env
      env.join!([:constructor_param, :Dummy, 0, :foo], {class: :NilClass})

      result = t.send(:best_constructor_param_types, :Dummy, 1)
      expect(result[0]).to eq(Frozone::Compiler::Type::BOTTOM)
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

    it "join! widens i64 and f64 to f64 (Ruby numeric widening)" do
      # Ruby semantics: mixing Int and Float arithmetic yields Float. The
      # cpp backend renders Numeric as int64_t, so the historical LCA-to-
      # Numeric result silently truncated Float assignments. Float-on-join
      # is the semantically correct widening.
      env.join!([:local, :foo, :x], :i64)
      env.join!([:local, :foo, :x], :f64)
      result = env[[:local, :foo, :x]]
      expect(result).to eq(:f64)
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

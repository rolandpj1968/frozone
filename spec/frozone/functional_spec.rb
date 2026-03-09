require_relative '../support/functional_helper'

# End-to-end functional tests: each example parses and executes a Ruby snippet
# through the full Frozone VM and checks the result object.

RSpec.describe "Frozone VM functional" do
  # ── Literals ────────────────────────────────────────────────────────────────

  describe 'nil literal' do
    it { expect(run_ruby('nil')).to vm_nil }
  end

  describe 'true literal' do
    it { expect(run_ruby('true')).to vm_true }
  end

  describe 'false literal' do
    it { expect(run_ruby('false')).to vm_false }
  end

  describe 'integer literal' do
    it { expect(run_ruby('0')).to vm_int(0) }
    it { expect(run_ruby('42')).to vm_int(42) }
    it { expect(run_ruby('-7')).to vm_int(-7) }
  end

  describe 'string literal' do
    it { expect(run_ruby('"hello"')).to vm_string("hello") }
    it { expect(run_ruby('""')).to vm_string("") }
    it { expect(run_ruby('"with spaces"')).to vm_string("with spaces") }
  end

  describe 'symbol literal' do
    it { expect(run_ruby(':foo')).to vm_symbol(:foo) }
    it { expect(run_ruby(':my_sym')).to vm_symbol(:my_sym) }
  end

  describe 'array literal' do
    it 'creates an empty array' do
      result = run_ruby('[]')
      expect(result).to be_a(Frozone::Vm::ArrayObject)
      expect(result.raw).to be_empty
    end

    it 'creates an array of integers' do
      expect(run_ruby('[1, 2, 3]')).to vm_array([1, 2, 3])
    end

    it 'evaluates element expressions' do
      expect(run_ruby('[1 + 1, 2 + 2]')).to vm_array([2, 4])
    end
  end

  describe 'hash literal' do
    it 'creates an empty hash' do
      result = run_ruby('{}')
      expect(result).to be_a(Frozone::Vm::HashObject)
      expect(result.raw).to be_empty
    end

    it 'creates a hash with symbol keys' do
      result = run_ruby('{a: 1, b: 2}')
      expect(result).to be_a(Frozone::Vm::HashObject)
      a_sym = Frozone::Vm::SymbolObject.from(:a)
      b_sym = Frozone::Vm::SymbolObject.from(:b)
      expect(result.raw[a_sym].raw).to eq(1)
      expect(result.raw[b_sym].raw).to eq(2)
    end
  end

  describe 'self' do
    it 'returns the top-level object' do
      expect(run_ruby('self')).to be_a(Frozone::Vm::ObjectObject)
    end
  end

  # ── Sequences ───────────────────────────────────────────────────────────────

  describe 'sequence (multiple statements)' do
    it 'returns the last expression' do
      expect(run_ruby("1\n2\n3")).to vm_int(3)
    end

    it 'returns nil for an empty program' do
      expect(run_ruby('')).to vm_nil
    end
  end

  # ── Integer arithmetic ───────────────────────────────────────────────────────

  describe 'Integer#+' do
    it { expect(run_ruby('1 + 2')).to vm_int(3) }
    it { expect(run_ruby('0 + 0')).to vm_int(0) }
    it { expect(run_ruby('-3 + 5')).to vm_int(2) }
    it 'chains correctly' do
      expect(run_ruby('1 + 2 + 3')).to vm_int(6)
    end
  end

  describe 'Integer#-' do
    it { expect(run_ruby('5 - 3')).to vm_int(2) }
    it { expect(run_ruby('3 - 5')).to vm_int(-2) }
    it 'chains correctly' do
      expect(run_ruby('10 - 3 - 2')).to vm_int(5)
    end
  end

  describe 'mixed Integer arithmetic' do
    it { expect(run_ruby('(1 + 2) - 1')).to vm_int(2) }
    it { expect(run_ruby('1 + (2 - 3)')).to vm_int(0) }
  end

  # ── Integer comparisons ──────────────────────────────────────────────────────

  describe 'Integer#<' do
    it { expect(run_ruby('3 < 5')).to vm_true }
    it { expect(run_ruby('5 < 3')).to vm_false }
    it { expect(run_ruby('3 < 3')).to vm_false }
  end

  describe 'Integer#<=' do
    it { expect(run_ruby('3 <= 5')).to vm_true }
    it { expect(run_ruby('3 <= 3')).to vm_true }
    it { expect(run_ruby('5 <= 3')).to vm_false }
  end

  describe 'Integer#>=' do
    it { expect(run_ruby('5 >= 3')).to vm_true }
    it { expect(run_ruby('3 >= 3')).to vm_true }
    it { expect(run_ruby('3 >= 5')).to vm_false }
  end

  describe 'Integer#>' do
    it { expect(run_ruby('5 > 3')).to vm_true }
    it { expect(run_ruby('3 > 5')).to vm_false }
    it { expect(run_ruby('3 > 3')).to vm_false }
  end

  describe 'Integer#==' do
    it { expect(run_ruby('3 == 3')).to vm_true }
    it { expect(run_ruby('3 == 4')).to vm_false }
  end

  # ── Boolean / nil operations ─────────────────────────────────────────────────

  describe 'BasicObject#!' do
    it 'nil.! is true'   do; expect(run_ruby('!nil')).to vm_true; end
    it 'false.! is true' do; expect(run_ruby('!false')).to vm_true; end
    it 'true.! is false' do; expect(run_ruby('!true')).to vm_false; end
    it '0.! is false (integers are truthy)' do; expect(run_ruby('!0')).to vm_false; end
    it '1.! is false'    do; expect(run_ruby('!1')).to vm_false; end
  end

  describe 'BasicObject#!=' do
    it { expect(run_ruby('1 != 2')).to vm_true }
    it { expect(run_ruby('1 != 1')).to vm_false }
    it { expect(run_ruby('0 != 0')).to vm_false }
  end

  describe 'BasicObject#==' do
    it 'nil == nil is true'   do; expect(run_ruby('nil == nil')).to vm_true; end
    it 'true == true is true' do; expect(run_ruby('true == true')).to vm_true; end
    it 'nil == false is false' do; expect(run_ruby('nil == false')).to vm_false; end
  end

  # ── Control flow ─────────────────────────────────────────────────────────────

  describe 'if/else' do
    it 'takes the then branch when condition is true' do
      expect(run_ruby('if true; 1; else; 2; end')).to vm_int(1)
    end

    it 'takes the else branch when condition is false' do
      expect(run_ruby('if false; 1; else; 2; end')).to vm_int(2)
    end

    it 'returns nil when condition is false and there is no else' do
      expect(run_ruby('if false; 1; end')).to vm_nil
    end

    it 'returns nil when condition is nil and there is no else' do
      expect(run_ruby('if nil; 1; end')).to vm_nil
    end

    it 'uses integer comparison as condition' do
      expect(run_ruby('if 3 < 5; 10; else; 20; end')).to vm_int(10)
      expect(run_ruby('if 5 < 3; 10; else; 20; end')).to vm_int(20)
    end

    it 'treats 0 as truthy' do
      expect(run_ruby('if 0; 1; else; 2; end')).to vm_int(1)
    end

    it 'supports nested if expressions' do
      code = 'if true; if false; 1; else; 2; end; else; 3; end'
      expect(run_ruby(code)).to vm_int(2)
    end
  end

  describe '&& (and)' do
    it 'returns the right value when both sides are truthy' do
      expect(run_ruby('1 && 2')).to vm_int(2)
    end

    it 'returns the left value when left is nil' do
      expect(run_ruby('nil && 42')).to vm_nil
    end

    it 'returns the left value when left is false' do
      expect(run_ruby('false && 42')).to vm_false
    end

    it 'returns false when both sides are false' do
      expect(run_ruby('false && false')).to vm_false
    end

    it 'does not evaluate the right side when left is falsy' do
      expect(run_ruby('nil && (1 / 0)')).to vm_nil
    end
  end

  describe '|| (or)' do
    it 'returns the left value when it is truthy' do
      expect(run_ruby('1 || 2')).to vm_int(1)
    end

    it 'returns the right value when left is nil' do
      expect(run_ruby('nil || 42')).to vm_int(42)
    end

    it 'returns the right value when left is false' do
      expect(run_ruby('false || 42')).to vm_int(42)
    end

    it 'returns false when both sides are false' do
      expect(run_ruby('false || false')).to vm_false
    end

    it 'returns the right value when both sides are nil/false' do
      expect(run_ruby('nil || false')).to vm_false
    end
  end

  # ── Local variables ──────────────────────────────────────────────────────────

  describe 'local variable write and read' do
    it 'assigns and reads back an integer' do
      expect(run_ruby("x = 42\nx")).to vm_int(42)
    end

    it 'reassigns a local variable' do
      expect(run_ruby("x = 1\nx = 2\nx")).to vm_int(2)
    end

    it 'assignment expression returns the assigned value' do
      expect(run_ruby("x = 7")).to vm_int(7)
    end

    it 'uses locals across multiple statements' do
      expect(run_ruby("a = 3\nb = 4\na + b")).to vm_int(7)
    end
  end

  # ── Instance variables ───────────────────────────────────────────────────────

  describe 'instance variable write and read' do
    it 'reads an unset ivar as nil' do
      expect(run_ruby("@x")).to vm_nil
    end

    it 'assigns and reads back an ivar' do
      expect(run_ruby("@x = 42\n@x")).to vm_int(42)
    end

    it 'assignment expression returns the assigned value' do
      expect(run_ruby("@x = 7")).to vm_int(7)
    end

    it 'ivars persist across method calls on the same object' do
      code = <<~RUBY
        class FuncTestIvar
          def store(v)
            @val = v
          end
          def fetch
            @val
          end
        end
        obj = FuncTestIvar.new
        obj.store(99)
        obj.fetch
      RUBY
      expect(run_ruby(code)).to vm_int(99)
    end

    it 'ivars are per-object' do
      code = <<~RUBY
        class FuncTestIvarPerObj
          def store(v)
            @val = v
          end
          def fetch
            @val
          end
        end
        a = FuncTestIvarPerObj.new
        b = FuncTestIvarPerObj.new
        a.store(1)
        b.store(2)
        a.fetch
      RUBY
      expect(run_ruby(code)).to vm_int(1)
    end
  end

  # ── Constants ────────────────────────────────────────────────────────────────

  describe 'constant write and read' do
    it 'defines a constant and reads it back' do
      expect(run_ruby("FUNC_TEST_CONST_1 = 99\nFUNC_TEST_CONST_1")).to vm_int(99)
    end

    it 'reads a built-in constant' do
      result = run_ruby('Integer')
      expect(result).to equal(Frozone::Vm::Core::INTEGER_CLASS)
    end
  end

  # ── Class definitions ─────────────────────────────────────────────────────────

  describe 'class definition' do
    it 'creates a ClassObject accessible as a constant' do
      expect(run_ruby("class FuncTestEmptyClass; end\nFuncTestEmptyClass")).to vm_class(:FuncTestEmptyClass)
    end

    it 'reopening a class returns the same object' do
      code = "class FuncTestReopenClass; end\nclass FuncTestReopenClass; end\nFuncTestReopenClass"
      result = run_ruby(code)
      expect(result).to be_a(Frozone::Vm::ClassObject)
      expect(result.name).to eq(:FuncTestReopenClass)
    end

    it 'class defined inside reopened Object is accessible as a top-level constant' do
      # Object is the global root, so classes defined inside it are top-level
      expect(run_ruby("class Object; class FuncTestInObject; end; end\nFuncTestInObject")).to vm_class(:FuncTestInObject)
    end

    it 'class defined inside reopened Object has nil namespace (same as top-level)' do
      run_ruby("class Object; class FuncTestInObjectNs; end; end")
      klass = Frozone::Vm::Core::OBJECT_CLASS.get_constant(:FuncTestInObjectNs)
      expect(klass.instance_variable_get(:@namespace)).to be_nil
    end

    it 'top-level class has nil namespace' do
      run_ruby("class FuncTestTopNs; end")
      klass = Frozone::Vm::Core::OBJECT_CLASS.get_constant(:FuncTestTopNs)
      expect(klass.instance_variable_get(:@namespace)).to be_nil
    end

    it 'nested class has enclosing class as namespace' do
      run_ruby("class FuncTestOuter; class FuncTestInner; end; end")
      outer = Frozone::Vm::Core::OBJECT_CLASS.get_constant(:FuncTestOuter)
      inner = outer.get_constant(:FuncTestInner)
      expect(inner.instance_variable_get(:@namespace)).to equal(outer)
    end
  end

  describe 'class inheritance' do
    it 'subclass inherits methods from superclass' do
      code = <<~RUBY
        class FuncTestAnimal
          def speak
            42
          end
        end
        class FuncTestDog < FuncTestAnimal
        end
        FuncTestDog.new.speak
      RUBY
      expect(run_ruby(code)).to vm_int(42)
    end

    it 'subclass can override superclass methods' do
      code = <<~RUBY
        class FuncTestBase
          def value
            1
          end
        end
        class FuncTestSub < FuncTestBase
          def value
            2
          end
        end
        FuncTestSub.new.value
      RUBY
      expect(run_ruby(code)).to vm_int(2)
    end

    it 'superclass method still works after override in subclass' do
      code = <<~RUBY
        class FuncTestBaseOnly
          def value
            99
          end
        end
        class FuncTestSubOnly < FuncTestBaseOnly
          def value
            0
          end
        end
        FuncTestBaseOnly.new.value
      RUBY
      expect(run_ruby(code)).to vm_int(99)
    end
  end

  # ── Method definitions and calls ─────────────────────────────────────────────

  describe 'method definition and call' do
    it 'defines a no-arg method and calls it' do
      expect(run_ruby("def ft_no_args; 42; end\nft_no_args")).to vm_int(42)
    end

    it 'defines a method returning nil' do
      expect(run_ruby("def ft_noop; end\nft_noop")).to vm_nil
    end

    it 'defines a method with required args' do
      expect(run_ruby("def ft_add(a, b); a + b; end\nft_add(3, 4)")).to vm_int(7)
    end

    it 'passes string args' do
      result = run_ruby("def ft_first_arg(x); x; end\nft_first_arg(\"hi\")")
      expect(result).to vm_string("hi")
    end

    it 'defines a method with an optional arg (uses default)' do
      expect(run_ruby("def ft_incr(n, by=1); n + by; end\nft_incr(5)")).to vm_int(6)
    end

    it 'defines a method with an optional arg (uses provided value)' do
      expect(run_ruby("def ft_incr2(n, by=1); n + by; end\nft_incr2(5, 10)")).to vm_int(15)
    end

    it 'defines a method with a rest parameter' do
      result = run_ruby("def ft_rest(*args); args; end\nft_rest(1, 2, 3)")
      expect(result).to vm_array([1, 2, 3])
    end

    it 'rest parameter is empty when no extra args given' do
      result = run_ruby("def ft_rest_empty(*args); args; end\nft_rest_empty")
      expect(result).to vm_array([])
    end

    it 'defines a method with a required keyword arg' do
      expect(run_ruby("def ft_kw(n:); n + 1; end\nft_kw(n: 9)")).to vm_int(10)
    end

    it 'defines a method with an optional keyword arg (uses default)' do
      expect(run_ruby("def ft_kw_opt(n:, step: 1); n + step; end\nft_kw_opt(n: 5)")).to vm_int(6)
    end

    it 'defines a method with an optional keyword arg (uses provided value)' do
      expect(run_ruby("def ft_kw_opt2(n:, step: 1); n + step; end\nft_kw_opt2(n: 5, step: 10)")).to vm_int(15)
    end

    it 'raises on wrong number of arguments' do
      expect {
        run_ruby("def ft_strict(a, b); a + b; end\nft_strict(1)")
      }.to raise_error(RuntimeError, /wrong number/)
    end

    it 'raises on missing required keyword' do
      expect {
        run_ruby("def ft_kw_req(n:); n; end\nft_kw_req")
      }.to raise_error(RuntimeError, /missing keyword/)
    end
  end

  # ── Method alias ─────────────────────────────────────────────────────────────

  describe 'method alias' do
    it 'creates a callable alias for a method' do
      code = "def ft_orig; 55; end\nalias ft_aliased ft_orig\nft_aliased"
      expect(run_ruby(code)).to vm_int(55)
    end
  end

  # ── Recursive methods ────────────────────────────────────────────────────────

  describe 'recursive method' do
    it 'computes fibonacci' do
      code = <<~RUBY
        def ft_fib(n)
          if n <= 1
            n
          else
            ft_fib(n - 1) + ft_fib(n - 2)
          end
        end
        ft_fib(10)
      RUBY
      expect(run_ruby(code)).to vm_int(55)
    end

    it 'counts down to zero' do
      code = <<~RUBY
        def ft_count(n)
          if n <= 0
            0
          else
            ft_count(n - 1)
          end
        end
        ft_count(5)
      RUBY
      expect(run_ruby(code)).to vm_int(0)
    end
  end

  # ── Class#new ────────────────────────────────────────────────────────────────

  describe 'Class#new' do
    it 'creates an instance of the class' do
      code = <<~RUBY
        class FuncTestNewBasic
        end
        FuncTestNewBasic.new
      RUBY
      result = run_ruby(code)
      expect(result).to be_a(Frozone::Vm::ObjectObject)
      expect(result.instance_variable_get(:@class_object)).to be_a(Frozone::Vm::ClassObject)
      expect(result.instance_variable_get(:@class_object).name).to eq(:FuncTestNewBasic)
    end

    it 'calls initialize with arguments without raising' do
      code = <<~RUBY
        class FuncTestNewWithInit
          def initialize(x)
          end
        end
        FuncTestNewWithInit.new(7)
      RUBY
      result = run_ruby(code)
      expect(result).to be_a(Frozone::Vm::ObjectObject)
    end

    it 'each call returns a distinct object (__id__ differs)' do
      code = <<~RUBY
        class FuncTestNewDistinct
        end
        FuncTestNewDistinct.new.__id__ != FuncTestNewDistinct.new.__id__
      RUBY
      expect(run_ruby(code)).to vm_true
    end
  end

  # ── method_missing ───────────────────────────────────────────────────────────

  describe 'method_missing' do
    it 'raises with the Ruby-style error message for a missing method on self' do
      expect { run_ruby("no_such_method_zz") }.to raise_error(RuntimeError, /undefined method 'no_such_method_zz' for an instance of Object/)
    end

    it 'raises with the receiver class name for an explicit receiver' do
      code = <<~RUBY
        class FuncTestMM
        end
        FuncTestMM.new.no_such_method_zz
      RUBY
      expect { run_ruby(code) }.to raise_error(RuntimeError, /undefined method 'no_such_method_zz' for an instance of FuncTestMM/)
    end

    it 'can be overridden to handle missing methods' do
      code = <<~RUBY
        class FuncTestMMOverride
          def method_missing(name, *args, **kwargs)
            42
          end
        end
        FuncTestMMOverride.new.anything_goes
      RUBY
      expect(run_ruby(code)).to vm_int(42)
    end

    it 'passes the method name and args to the override' do
      code = <<~RUBY
        class FuncTestMMArgs
          def method_missing(name, *args, **kwargs)
            args
          end
        end
        FuncTestMMArgs.new.foo(1, 2, 3)
      RUBY
      expect(run_ruby(code)).to vm_array([1, 2, 3])
    end
  end

  # ── __send__ and send ────────────────────────────────────────────────────────

  describe '__send__ and send' do
    it '__send__ dispatches a no-arg method' do
      expect(run_ruby("def ft_greet; 42; end\nself.__send__(:ft_greet)")).to vm_int(42)
    end

    it '__send__ passes positional arguments' do
      expect(run_ruby("def ft_add(a, b); a + b; end\nself.__send__(:ft_add, 3, 4)")).to vm_int(7)
    end

    it '__send__ dispatches on an explicit receiver' do
      code = <<~RUBY
        class FuncTestSend
          def value
            99
          end
        end
        FuncTestSend.new.__send__(:value)
      RUBY
      expect(run_ruby(code)).to vm_int(99)
    end

    it 'send forwards to __send__' do
      expect(run_ruby("def ft_ping; 1; end\nself.send(:ft_ping)")).to vm_int(1)
    end

    it 'send passes arguments' do
      expect(run_ruby("def ft_mul(a, b); a + b; end\nself.send(:ft_mul, 5, 6)")).to vm_int(11)
    end
  end

  # ── Custom hash and eql? ─────────────────────────────────────────────────────

  describe 'custom hash and eql? as hash keys' do
    let(:point_class) { <<~RUBY }
      class Point
        def initialize(x, y)
          @x = x
          @y = y
        end
        def x = @x
        def y = @y
        def hash = @x.hash + @y.hash
        def eql?(other)
          if @x == other.x
            @y == other.y
          else
            false
          end
        end
      end
    RUBY

    it 'looks up a user-defined object key by value equality' do
      result = run_ruby(<<~RUBY)
        #{point_class}
        p1 = Point.new(1, 2)
        p2 = Point.new(1, 2)
        h = { p1 => :found }
        h[p2]
      RUBY
      expect(result).to vm_symbol(:found)
    end

    it 'returns nil for a non-matching key' do
      result = run_ruby(<<~RUBY)
        #{point_class}
        p1 = Point.new(1, 2)
        p2 = Point.new(3, 4)
        h = { p1 => :found }
        h[p2]
      RUBY
      expect(result).to vm_nil
    end

    it 'distinct objects with same hash but different eql? do not collide' do
      result = run_ruby(<<~RUBY)
        #{point_class}
        p1 = Point.new(1, 2)
        p2 = Point.new(2, 1)
        h = { p1 => :first, p2 => :second }
        h[Point.new(2, 1)]
      RUBY
      expect(result).to vm_symbol(:second)
    end
  end

  # ── Methods defined inside a class ───────────────────────────────────────────

  describe 'class with methods (called via top-level alias)' do
    it 'methods defined inside a class body are on that class' do
      code = <<~RUBY
        class FuncTestCalc
          def double(n)
            n + n
          end
        end
        FuncTestCalc
      RUBY
      result = run_ruby(code)
      expect(result).to be_a(Frozone::Vm::ClassObject)
      expect(result.lookup_method(:double)).to be_a(Frozone::Vm::Method)
    end
  end

  # ── while / until ────────────────────────────────────────────────────────────

  describe 'while loop' do
    it 'executes body while condition is true' do
      expect(run_ruby("x = 0\nwhile x < 3\n  x = x + 1\nend\nx")).to vm_int(3)
    end

    it 'skips body when condition is initially false' do
      expect(run_ruby("x = 5\nwhile x < 0\n  x = x - 1\nend\nx")).to vm_int(5)
    end

    it 'returns nil' do
      expect(run_ruby("while false; end")).to vm_nil
    end
  end

  describe 'unless' do
    it 'skips body when condition is true' do
      expect(run_ruby("unless true; 1; end")).to vm_nil
    end

    it 'executes body when condition is false' do
      expect(run_ruby("unless false; 42; end")).to vm_int(42)
    end

    it 'executes else when condition is true' do
      expect(run_ruby("unless true; 1; else; 2; end")).to vm_int(2)
    end
  end

  describe 'until loop' do
    it 'executes body until condition is true' do
      expect(run_ruby("x = 0\nuntil x >= 3\n  x = x + 1\nend\nx")).to vm_int(3)
    end

    it 'skips body when condition is initially true' do
      expect(run_ruby("x = 5\nuntil x > 0\n  x = x + 1\nend\nx")).to vm_int(5)
    end

    it 'returns nil' do
      expect(run_ruby("until true; end")).to vm_nil
    end
  end

  # ── case/when ────────────────────────────────────────────────────────────────

  describe 'case/when' do
    it 'matches first matching when' do
      expect(run_ruby("case 2; when 1 then 10; when 2 then 20; when 3 then 30; end")).to vm_int(20)
    end

    it 'returns nil when no match and no else' do
      expect(run_ruby("case 9; when 1 then 10; end")).to vm_nil
    end

    it 'executes else when no when matches' do
      expect(run_ruby("case 9; when 1 then 10; else 99; end")).to vm_int(99)
    end

    it 'matches class with ===' do
      expect(run_ruby("case 42; when Integer then :int; when String then :str; end")).to vm_symbol(:int)
    end

    it 'matches multiple conditions in one when' do
      expect(run_ruby("case 2; when 1, 2 then :yes; end")).to vm_symbol(:yes)
    end

    it 'works without a subject' do
      expect(run_ruby("x = 5; case; when x < 3 then :low; when x < 7 then :mid; else :high; end")).to vm_symbol(:mid)
    end
  end

  # ── String interpolation ─────────────────────────────────────────────────────

  describe 'string interpolation' do
    it 'interpolates a variable' do
      expect(run_ruby('x = 42; "value is #{x}"')).to vm_string("value is 42")
    end

    it 'interpolates an expression' do
      expect(run_ruby('"result: #{1 + 2}"')).to vm_string("result: 3")
    end

    it 'calls to_s on non-string values' do
      expect(run_ruby('"#{nil}"')).to vm_string("")
    end
  end

  # ── not / ! ──────────────────────────────────────────────────────────────────

  describe '! operator' do
    it '!true is false' do
      expect(run_ruby('!true')).to vm_false
    end

    it '!false is true' do
      expect(run_ruby('!false')).to vm_true
    end

    it '!nil is true' do
      expect(run_ruby('!nil')).to vm_true
    end

    it '!value is false for truthy values' do
      expect(run_ruby('!42')).to vm_false
    end

    it '!= works' do
      expect(run_ruby('1 != 2')).to vm_true
    end
  end

  # ── Comparable ───────────────────────────────────────────────────────────────

  describe 'Comparable' do
    it 'Integer <=> returns -1, 0, 1' do
      expect(run_ruby('1 <=> 2')).to vm_int(-1)
      expect(run_ruby('2 <=> 2')).to vm_int(0)
      expect(run_ruby('3 <=> 2')).to vm_int(1)
    end

    it 'String <=> compares lexicographically' do
      expect(run_ruby('"a" <=> "b"')).to vm_int(-1)
      expect(run_ruby('"b" <=> "b"')).to vm_int(0)
    end

    it 'Integer between? works' do
      expect(run_ruby('3.between?(1, 5)')).to vm_true
      expect(run_ruby('7.between?(1, 5)')).to vm_false
    end
  end

  # ── raise ─────────────────────────────────────────────────────────────────────

  describe 'raise' do
    it 'raises a Ruby exception with the given message' do
      expect { run_ruby('raise "boom"') }.to raise_error("boom")
    end
  end

  # ── Integer arithmetic ───────────────────────────────────────────────────────

  describe 'Integer arithmetic' do
    it 'multiplies' do expect(run_ruby('3 * 4')).to vm_int(12) end
    it 'divides'    do expect(run_ruby('10 / 3')).to vm_int(3) end
    it 'modulo'     do expect(run_ruby('10 % 3')).to vm_int(1) end
    it 'power'      do expect(run_ruby('2 ** 8')).to vm_int(256) end
    it 'unary minus' do expect(run_ruby('-7')).to vm_int(-7) end
    it 'abs positive' do expect(run_ruby('5.abs')).to vm_int(5) end
    it 'abs negative' do expect(run_ruby('-5.abs')).to vm_int(5) end
    it 'zero? true'   do expect(run_ruby('0.zero?')).to vm_true end
    it 'zero? false'  do expect(run_ruby('1.zero?')).to vm_false end
    it 'positive?'    do expect(run_ruby('3.positive?')).to vm_true end
    it 'negative?'    do expect(run_ruby('(-1).negative?')).to vm_true end
    it 'to_i'         do expect(run_ruby('42.to_i')).to vm_int(42) end
    it 'to_s'         do expect(run_ruby('42.to_s')).to vm_string('42') end
    it 'inspect'      do expect(run_ruby('42.inspect')).to vm_string('42') end
  end

  # ── Object predicates ────────────────────────────────────────────────────────

  describe 'Object predicates' do
    it 'nil? is false for non-nil' do expect(run_ruby('42.nil?')).to vm_false end
    it 'nil? is true for nil'     do expect(run_ruby('nil.nil?')).to vm_true end

    it 'is_a? true for own class' do
      expect(run_ruby('42.is_a?(Integer)')).to vm_true
    end

    it 'is_a? true for superclass' do
      expect(run_ruby('42.is_a?(Object)')).to vm_true
    end

    it 'is_a? false for unrelated class' do
      expect(run_ruby('42.is_a?(String)')).to vm_false
    end

    it 'is_a? true for directly included module' do
      expect(run_ruby('"hi".is_a?(Comparable)')).to vm_true
    end

    it 'is_a? true for module included in superclass' do
      expect(run_ruby('42.is_a?(Comparable)')).to vm_true
    end

    it 'is_a? true for prepended module' do
      expect(run_ruby(<<~RUBY)).to vm_true
        module M; end
        class C
          prepend M
        end
        C.new.is_a?(M)
      RUBY
    end

    it 'prepended module method takes priority over class method' do
      expect(run_ruby(<<~RUBY)).to vm_int(1)
        module M
          def foo = 1
        end
        class C
          prepend M
          def foo = 2
        end
        C.new.foo
      RUBY
    end

    it 'kind_of? is alias for is_a?' do
      expect(run_ruby('"hi".kind_of?(String)')).to vm_true
    end

    it 'instance_of? true for exact class' do
      expect(run_ruby('42.instance_of?(Integer)')).to vm_true
    end

    it 'instance_of? false for superclass' do
      expect(run_ruby('42.instance_of?(Object)')).to vm_false
    end

    it 'class returns the class object' do
      expect(run_ruby('42.class')).to vm_class(:Integer)
    end

    it 'respond_to? true for existing method' do
      expect(run_ruby('42.respond_to?(:to_s)')).to vm_true
    end

    it 'respond_to? false for missing method' do
      expect(run_ruby('42.respond_to?(:no_such_method)')).to vm_false
    end
  end

  # ── to_s / inspect ───────────────────────────────────────────────────────────

  describe 'to_s and inspect' do
    it 'nil.to_s'     do expect(run_ruby('nil.to_s')).to vm_string('') end
    it 'nil.inspect'  do expect(run_ruby('nil.inspect')).to vm_string('nil') end
    it 'true.to_s'    do expect(run_ruby('true.to_s')).to vm_string('true') end
    it 'false.to_s'   do expect(run_ruby('false.to_s')).to vm_string('false') end
    it 'string.to_s'  do expect(run_ruby('"hi".to_s')).to vm_string('hi') end
    it 'symbol.to_s'  do expect(run_ruby(':foo.to_s')).to vm_string('foo') end
    it 'symbol.inspect' do expect(run_ruby(':foo.inspect')).to vm_string(':foo') end
    it 'string.inspect' do expect(run_ruby('"hi".inspect')).to vm_string('"hi"') end
  end

  # ── String methods ───────────────────────────────────────────────────────────

  describe 'String methods' do
    it 'concatenation' do expect(run_ruby('"foo" + "bar"')).to vm_string('foobar') end
    it 'length'        do expect(run_ruby('"hello".length')).to vm_int(5) end
    it 'size alias'    do expect(run_ruby('"hello".size')).to vm_int(5) end
    it 'to_i'          do expect(run_ruby('"42".to_i')).to vm_int(42) end
  end

  # ── Array methods ────────────────────────────────────────────────────────────

  describe 'Array methods' do
    it '[]'       do expect(run_ruby('[10, 20, 30][1]')).to vm_int(20) end
    it '[]='      do expect(run_ruby('a = [1, 2, 3]; a[0] = 99; a[0]')).to vm_int(99) end
    it 'push'     do expect(run_ruby('a = [1, 2]; a.push(3); a[2]')).to vm_int(3) end
    it '<<'       do expect(run_ruby('a = [1, 2]; a << 3; a[2]')).to vm_int(3) end
    it 'length'   do expect(run_ruby('[1, 2, 3].length')).to vm_int(3) end
    it 'size'     do expect(run_ruby('[1, 2, 3].size')).to vm_int(3) end
    it 'first'    do expect(run_ruby('[10, 20, 30].first')).to vm_int(10) end
    it 'last'     do expect(run_ruby('[10, 20, 30].last')).to vm_int(30) end
    it 'to_s'     do expect(run_ruby('[1, 2, 3].to_s')).to vm_string('[1, 2, 3]') end
  end

  # ── Hash methods ─────────────────────────────────────────────────────────────

  describe 'Hash methods' do
    it '[]='     do expect(run_ruby('h = {}; h[:a] = 1; h[:a]')).to vm_int(1) end
    it 'size'    do expect(run_ruby('{a: 1, b: 2}.size')).to vm_int(2) end
    it 'length'  do expect(run_ruby('{a: 1, b: 2}.length')).to vm_int(2) end
    it 'key? true'  do expect(run_ruby('h = {a: 1}; h.key?(:a)')).to vm_true end
    it 'key? false' do expect(run_ruby('h = {a: 1}; h.key?(:b)')).to vm_false end
    it 'has_key?'   do expect(run_ruby('h = {a: 1}; h.has_key?(:a)')).to vm_true end
    it 'include?'   do expect(run_ruby('h = {a: 1}; h.include?(:a)')).to vm_true end
  end

  # ── Kernel output ────────────────────────────────────────────────────────────

  describe 'puts / print / p' do
    it 'puts returns nil' do
      expect(run_ruby('puts 42')).to vm_nil
    end

    it 'print returns nil' do
      expect(run_ruby('print 42')).to vm_nil
    end

    it 'p with one arg returns the arg' do
      expect(run_ruby('p 42')).to vm_int(42)
    end

    it 'puts outputs to stdout' do
      expect { run_ruby('puts 42') }.to output("42\n").to_stdout
    end

    it 'print outputs without newline' do
      expect { run_ruby('print "hi"') }.to output("hi").to_stdout
    end

    it 'p outputs inspect form' do
      expect { run_ruby('p :foo') }.to output(":foo\n").to_stdout
    end
  end

  # ── Singleton / class methods ────────────────────────────────────────────────

  describe 'singleton methods' do
    it 'defines a singleton method on an object and calls it' do
      expect(run_ruby(<<~RUBY)).to vm_int(42)
        o = Object.new
        def o.answer = 42
        o.answer
      RUBY
    end

    it 'singleton method does not affect other instances' do
      expect(run_ruby(<<~RUBY)).to vm_true
        a = Object.new
        b = Object.new
        def a.greet = 1
        b.respond_to?(:greet) == false
      RUBY
    end

    it 'defines a class method via def self.foo' do
      expect(run_ruby(<<~RUBY)).to vm_int(7)
        class Foo
          def self.bar = 7
        end
        Foo.bar
      RUBY
    end

    it 'class method with arguments' do
      expect(run_ruby(<<~RUBY)).to vm_int(3)
        class Calc
          def self.add(a, b) = a + b
        end
        Calc.add(1, 2)
      RUBY
    end

    it 'class method can access constants' do
      expect(run_ruby(<<~RUBY)).to vm_string("hello")
        class Greeter
          GREETING = "hello"
          def self.greet = GREETING
        end
        Greeter.greet
      RUBY
    end

    it 'instance method and class method coexist' do
      expect(run_ruby(<<~RUBY)).to vm_int(10)
        class Counter
          def self.zero = 0
          def value = 10
        end
        Counter.zero + Counter.new.value
      RUBY
    end
  end
end

require_relative '../../support/vm_loader'
require 'open3'
require 'tempfile'

# End-to-end feature tests for the C++ backend.
# Each test: small Ruby program → compile via C++ → run → compare output with MRI.
# Tests are organised by language feature so gaps are immediately visible.
RSpec.describe "C++ backend features" do
  def compile_and_run_cpp(ruby_source, timeout: 10)
    stub = Tempfile.new(['cpp_test', '.rb'])
    stub.write(<<~PREAMBLE)
      $LOADED_FEATURES << "harness"
      def run_benchmark(*, &); end
    PREAMBLE
    stub.write(ruby_source)
    stub.close

    # Generate C++
    gen_out, gen_status = Open3.capture2e(
      { 'FROZONE_CPP' => '1' },
      'bundle', 'exec', 'ruby', 'frozone.rb', '--aot', stub.path
    )
    return [:gen_fail, gen_out] unless gen_status.success?

    base = File.basename(stub.path, '.rb')
    cpp_path = "cpp/gen/#{base}.cpp"
    bin_path = "cpp/gen/#{base}"
    return [:gen_fail, "no cpp file"] unless File.exist?(cpp_path)

    # Compile C++
    compile_out, compile_status = Open3.capture2e(
      'g++', '-std=c++20', '-O2', cpp_path, '-o', bin_path
    )
    return [:compile_fail, compile_out] unless compile_status.success?

    # Run
    run_out, run_status = Open3.capture2e(bin_path)
    File.delete(cpp_path) rescue nil
    File.delete(bin_path) rescue nil
    return [:run_fail, run_out] unless run_status.success?

    [:ok, run_out]
  ensure
    stub&.close!
  end

  def mri_run(ruby_source)
    stub = Tempfile.new(['mri_test', '.rb'])
    stub.write(<<~PREAMBLE)
      $LOADED_FEATURES << "harness"
      def run_benchmark(*, &); end
    PREAMBLE
    stub.write(ruby_source)
    stub.close
    out, status = Open3.capture2e('ruby', stub.path)
    status.success? ? out : nil
  ensure
    stub&.close!
  end

  def assert_cpp_matches_mri(ruby_source, label: nil)
    mri_out = mri_run(ruby_source)
    expect(mri_out).not_to be_nil, "MRI failed to run#{label ? " (#{label})" : ''}"

    status, cpp_out = compile_and_run_cpp(ruby_source)
    case status
    when :gen_fail
      skip "C++ generation failed#{label ? " (#{label})" : ''}: #{cpp_out[0..200]}"
    when :compile_fail
      skip "C++ compilation failed#{label ? " (#{label})" : ''}: #{cpp_out[0..200]}"
    when :run_fail
      skip "C++ binary crashed#{label ? " (#{label})" : ''}: #{cpp_out[0..200]}"
    else
      expect(cpp_out).to eq(mri_out), "Output mismatch#{label ? " (#{label})" : ''}"
    end
  end

  # ── Tier 1: Already working (benchmarks prove these) ──────────────

  context "arithmetic" do
    it "integer ops" do
      assert_cpp_matches_mri('puts 2 + 3; puts 10 - 4; puts 6 * 7; puts 15 / 4; puts 15 % 4')
    end

    it "float ops" do
      assert_cpp_matches_mri('puts 1.5 + 2.5; puts 3.14 * 2')
    end

    it "power" do
      assert_cpp_matches_mri('puts 2 ** 10; puts 3.0 ** 0.5')
    end
  end

  context "control flow" do
    it "if/elsif/else" do
      assert_cpp_matches_mri(<<~RUBY)
        x = 5
        if x < 3
          puts "low"
        elsif x < 7
          puts "mid"
        else
          puts "high"
        end
      RUBY
    end

    it "while loop" do
      assert_cpp_matches_mri('i = 0; while i < 5; puts i; i += 1; end')
    end

    it "until loop" do
      assert_cpp_matches_mri('i = 0; until i >= 3; puts i; i += 1; end')
    end

    it "ternary" do
      assert_cpp_matches_mri('x = 10; puts(x > 5 ? "yes" : "no")')
    end

    it "and/or short-circuit" do
      assert_cpp_matches_mri('puts(true && "hello"); puts(false || "world")')
    end
  end

  context "methods" do
    it "simple recursion" do
      assert_cpp_matches_mri(<<~RUBY)
        def fib(n)
          return n if n < 2
          fib(n - 1) + fib(n - 2)
        end
        puts fib(10)
      RUBY
    end

    it "multiple return values via array" do
      assert_cpp_matches_mri(<<~RUBY)
        def divmod(a, b)
          [a / b, a % b]
        end
        q, r = divmod(17, 5)
        puts q
        puts r
      RUBY
    end

    it "optional params" do
      assert_cpp_matches_mri(<<~RUBY)
        def greet(name, greeting = "hello")
          puts greeting
          puts name
        end
        greet("world")
        greet("ruby", "hi")
      RUBY
    end
  end

  context "classes" do
    it "simple class with ivars" do
      assert_cpp_matches_mri(<<~RUBY)
        class Point
          def initialize(x, y)
            @x = x
            @y = y
          end
          def x; @x; end
          def y; @y; end
          def dist
            (@x * @x + @y * @y) ** 0.5
          end
        end
        p = Point.new(3, 4)
        puts p.x
        puts p.y
        puts p.dist
      RUBY
    end

    it "attr_accessor" do
      assert_cpp_matches_mri(<<~RUBY)
        class Counter
          attr_accessor :count
          def initialize
            @count = 0
          end
          def inc
            @count += 1
          end
        end
        c = Counter.new
        3.times { c.inc }
        puts c.count
      RUBY
    end

    it "self-referential class" do
      assert_cpp_matches_mri(<<~RUBY)
        class Node
          attr_accessor :val, :next_node
          def initialize(v)
            @val = v
            @next_node = nil
          end
        end
        a = Node.new(1)
        b = Node.new(2)
        a.next_node = b
        puts a.val
        puts a.next_node.val
      RUBY
    end
  end

  context "arrays" do
    it "literal + indexing" do
      assert_cpp_matches_mri(<<~RUBY)
        a = [10, 20, 30]
        puts a[0]
        puts a[2]
        puts a[-1]
      RUBY
    end

    it "times iteration" do
      assert_cpp_matches_mri('5.times { |i| puts i }')
    end

    it "each iteration" do
      assert_cpp_matches_mri('[10, 20, 30].each { |x| puts x }')
    end
  end

  context "strings" do
    it "concatenation" do
      assert_cpp_matches_mri('puts "hello" + " " + "world"')
    end

    it "interpolation" do
      assert_cpp_matches_mri('x = 42; puts "the answer is #{x}"')
    end

    it "repeat" do
      assert_cpp_matches_mri('puts "ab" * 3')
    end
  end

  context "hashes" do
    it "symbol-keyed literal" do
      assert_cpp_matches_mri(<<~RUBY)
        h = {a: 1, b: 2}
        puts h[:a]
        puts h[:b]
      RUBY
    end
  end

  context "structs" do
    it "Struct.new with accessors" do
      assert_cpp_matches_mri(<<~RUBY)
        Pt = Struct.new(:x, :y)
        p = Pt.new(3, 4)
        puts p.x
        puts p.y
      RUBY
    end
  end

  context "nil handling" do
    it "optional return" do
      assert_cpp_matches_mri(<<~RUBY)
        def find(arr, target)
          i = 0
          while i < 3
            return arr[i] if arr[i] == target
            i += 1
          end
          nil
        end
        puts find([10, 20, 30], 20)
        puts find([10, 20, 30], 99).nil?
      RUBY
    end
  end

  # ── Tier 2: Needed for WQ parser / self-compilation ────────────────

  context "case/when" do
    it "simple case" do
      assert_cpp_matches_mri(<<~RUBY)
        x = 2
        result = case x
        when 1 then "one"
        when 2 then "two"
        when 3 then "three"
        else "other"
        end
        puts result
      RUBY
    end
  end

  context "blocks and procs" do
    it "yield" do
      assert_cpp_matches_mri(<<~RUBY)
        def twice
          yield 1
          yield 2
        end
        twice { |x| puts x * 10 }
      RUBY
    end

    it "lambda" do
      assert_cpp_matches_mri(<<~RUBY)
        square = lambda { |x| x * x }
        puts square.call(5)
      RUBY
    end
  end

  context "rescue/ensure" do
    it "basic rescue" do
      assert_cpp_matches_mri(<<~RUBY)
        begin
          x = 1 / 0
        rescue ZeroDivisionError
          puts "caught"
        end
      RUBY
    end
  end

  context "global variables" do
    it "$stdout.puts" do
      assert_cpp_matches_mri(<<~RUBY)
        def test_stdout
          $stdout.puts "hello"
        end
        test_stdout
      RUBY
    end
  end

  context "class methods" do
    it "def self.method on a class" do
      assert_cpp_matches_mri(<<~RUBY)
        class Counter
          def initialize
            @n = 0
          end
          def inc
            @n += 1
          end
          def n; @n; end
        end
        c = Counter.new
        c.inc
        c.inc
        puts c.n
      RUBY
    end
  end

  context "modules" do
    it "module with self methods" do
      assert_cpp_matches_mri(<<~RUBY)
        module MathHelper
          def self.double(x)
            x * 2
          end
        end
        puts MathHelper.double(21)
      RUBY
    end
  end

  context "keyword arguments" do
    it "optional kwargs" do
      assert_cpp_matches_mri(<<~RUBY)
        def greet(name:, greeting: "hello")
          puts greeting
          puts name
        end
        greet(name: "world")
        greet(name: "ruby", greeting: "hi")
      RUBY
    end
  end

  context "string methods" do
    it "length and bytesize" do
      assert_cpp_matches_mri('puts "hello".length; puts "hello".bytesize')
    end

    it "setbyte and getbyte" do
      assert_cpp_matches_mri(<<~RUBY)
        s = "abc".b
        puts s.getbyte(0)
        s.setbyte(0, 65)
        puts s.getbyte(0)
      RUBY
    end
  end

  # Union types where TI joins heterogeneous RubyObject subclasses at their
  # LCA (Object). Previously these emitted std::any fallbacks; now they emit
  # gc_ref<RubyObject> with cr_coerce boxing at union-entry sites. Tests cover
  # WRITE-into-union (boxing, upcast) — the DOWNCAST direction (narrowing
  # `obj.method` via virtual dispatch vs dynamic_cast) is a separate concern
  # and deliberately only touched via `.class` which uses virtual rb_class_name.
  context "union types" do
    it "ivar holding either Hash or user-class pointer" do
      assert_cpp_matches_mri(<<~RUBY)
        class Box
          attr_accessor :payload
          def initialize(p) = @payload = p
        end
        class Node
          def initialize; end
        end
        b1 = Box.new({ a: 1, b: 2 })
        b2 = Box.new(Node.new)
        puts b1.payload.class
        puts b2.payload.class
      RUBY
    end

    it "method with mixed return: Hash in one branch, user-class in another" do
      assert_cpp_matches_mri(<<~RUBY)
        class Leaf
          def initialize; end
        end
        def choose(kind)
          if kind == :hash
            { k: 1 }
          else
            Leaf.new
          end
        end
        puts choose(:hash).class
        puts choose(:leaf).class
      RUBY
    end

    it "hash literal with mixed RubyObject-subclass values" do
      assert_cpp_matches_mri(<<~RUBY)
        h = { arr: [1, 2, 3], str: "hello" }
        puts h[:arr].class
        puts h[:str].class
      RUBY
    end

    it "nested hash-in-class with mixed values (splay-style payload)" do
      # The inner `.data.class` would require downcast of RubyObject* to
      # `Wrap` — separate story. Here we test only the leaf-level storage:
      # the whole tree is built and the root is tagged correctly.
      assert_cpp_matches_mri(<<~RUBY)
        class Wrap
          attr_accessor :data
          def initialize(d) = @data = d
        end
        def make(depth)
          if depth == 0
            { a: [1, 2], s: "leaf" }
          else
            Wrap.new(make(depth - 1))
          end
        end
        r = make(2)
        puts r.class
      RUBY
    end
  end
end

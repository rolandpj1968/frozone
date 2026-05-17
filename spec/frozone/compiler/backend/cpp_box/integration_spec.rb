require 'tempfile'
require 'open3'
require 'fileutils'
require 'etc'

# Integration tests for box-first: end-to-end pipeline check.
# For each test stub:
#   1. Generate cpp via `frozone --aot bench/stubs/<stub>.rb` with
#      FROZONE_CPP=1 + FROZONE_BOX_FIRST=1.
#   2. Compile the generated cpp with g++ + Boehm.
#   3. Run the binary; assert stdout matches expected.
#
# Locks regressions across the whole pipeline. If a test fails, it
# could be: emitter bug, runtime header bug, or compile-time C++ bug.
# All would land in the same place — the binary's stdout.
#
# Run via: bundle exec rspec spec/frozone/compiler/backend/cpp_box/integration_spec.rb

PROJECT_ROOT = File.expand_path('../../../../..', __dir__)
GEN_DIR      = File.join(PROJECT_ROOT, 'cpp', 'gen', 'box')
ONIGMO_DIR   = File.join(PROJECT_ROOT, 'vendor', 'Onigmo', '_install')
ONIGMO_INC   = File.join(ONIGMO_DIR, 'include')
ONIGMO_LIB   = File.join(ONIGMO_DIR, 'lib', 'libonigmo.a')

# Dispatch-feature matrix. Each test runs once per mode (4 modes
# total) so codegen regressions in either natural-args or leaf-
# dispatch surface in CI rather than waiting for a perf run.
EXEC_MODES = {
  baseline: {},
  natural:  { 'FROZONE_NATURAL_ARGS' => '1' },
  leaf:     { 'FROZONE_LEAF_DISPATCH' => '1' },
  both:     { 'FROZONE_NATURAL_ARGS' => '1', 'FROZONE_LEAF_DISPATCH' => '1' },
}.freeze

def run_box_first(stub_name, env_extras: {})
  stub_path = "bench/stubs/#{stub_name}.rb"
  cpp_path  = File.join(GEN_DIR, "#{stub_name}.cpp")

  Dir.chdir(PROJECT_ROOT) do
    # Wipe prior per-stub artefacts so a previous run's leftover .cpp
    # files don't sneak into this stub's compile glob. Per-class hpps
    # in class/ are also rewritten so we drop the whole subdir.
    FileUtils.rm_rf(Dir.glob(File.join(GEN_DIR, "#{stub_name}*")))
    FileUtils.rm_rf(File.join(GEN_DIR, 'class'))

    env = { 'FROZONE_CPP' => '1', 'FROZONE_BOX_FIRST' => '1' }.merge(env_extras)
    out, status = Open3.capture2e(env, 'bundle', 'exec', 'ruby', 'frozone.rb', '--aot', stub_path)
    raise "frozone --aot failed for #{stub_name}:\n#{out}" unless status.success?
    raise "expected #{cpp_path} to exist after generation" unless File.exist?(cpp_path)

    # Layouts split (project_layouts_split.md) emits per-stub
    # multi-file gen: <stub>.cpp + <stub>_main.cpp + <stub>_static.cpp +
    # <stub>_universe.cpp + <stub>_int_literals.cpp + <stub>_class_*.cpp
    # plus <stub>_*.hpp + class/*.hpp. All .cpp files must be compiled
    # together; headers come along via #include.
    cpp_files = Dir.glob(File.join(GEN_DIR, "#{stub_name}*.cpp")).sort
    raise "no .cpp files for #{stub_name}" if cpp_files.empty?

    bin = Tempfile.new(["box_#{stub_name}_", ''])
    bin.close
    begin
      # Onigmo is required by box_first.hpp (Regexp support); -std=c++20
      # for designated-init in the array_at helper. Was -std=c++17
      # without Onigmo flags — both broke after Regexp landed.
      # -O0: integration spec asserts on stdout, not runtime perf.
      # Parallel compile: each .cpp → .o in its own g++ process via a
      # thread pool, then a single link step. g++ itself is single-
      # threaded per TU, so the win comes from fan-out across stubs that
      # emit many per-class .cpp files.
      parallel = ENV.fetch('JOBS', Etc.nprocessors.to_s).to_i
      queue = Queue.new
      cpp_files.each { |f| queue << f }
      errors = []
      mutex = Mutex.new
      o_files = []

      Array.new(parallel) do
        Thread.new do
          loop do
            cpp = queue.pop(true) rescue break
            o_path = cpp.sub(/\.cpp\z/, '.o')
            out, status = Open3.capture2e(
              'g++', '-std=c++20', '-O0', '-c', cpp,
              '-I', ONIGMO_INC, '-o', o_path
            )
            mutex.synchronize do
              if status.success?
                o_files << o_path
              else
                errors << "g++ -c failed for #{cpp}:\n#{out}"
              end
            end
          end
        end
      end.each(&:join)

      raise errors.first unless errors.empty?

      link_args = ['g++', '-std=c++20', '-O0', *o_files.sort,
                   ONIGMO_LIB, '-lgc', '-o', bin.path]
      link_out, link_status = Open3.capture2e(*link_args)
      raise "g++ link failed for #{stub_name}:\n#{link_out}" unless link_status.success?

      run_out, run_status = Open3.capture2e(bin.path)
      raise "run of #{stub_name} exited non-zero (#{run_status.exitstatus}):\n#{run_out}" unless run_status.success?
      run_out
    ensure
      File.unlink(bin.path) if File.exist?(bin.path)
    end
  end
end

RSpec.describe 'box-first end-to-end' do
  # Each mode wires a different env into run_box_first via the shared
  # `env_extras` let. The expectations themselves are dispatch-feature
  # agnostic — they assert program stdout, which must match in every
  # mode. If natural-args or leaf-dispatch breaks a stub, the mode
  # context shows up in the rspec failure.
  shared_examples 'box-first stubs' do
    it 'recursively computes 3 × fib(35)' do
      expect(run_box_first('fib', env_extras: env_extras).strip).to eq('27682395')
    end

  it 'instantiates a user class and dispatches its instance methods' do
    expect(run_box_first('box_test', env_extras: env_extras).strip).to eq("42\n84")
  end

  it 'reads ivars in a tight while loop via a class-instance constant' do
    expect(run_box_first('getivar', env_extras: env_extras).strip).to eq('50000')
  end

  it 'manipulates Arrays — literals, indexing (incl negative), push, first/last' do
    expect(run_box_first('array_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[5 10 30 50 6 99 10 99]
    )
  end

  it 'solves nq_solve(8) using bitwise ops, Array.new, And, and arr[k]= writes' do
    expect(run_box_first('nqueens_small', env_extras: env_extras).strip).to eq('92')
  end

  it 'dispatches Hash via Symbol AND Integer keys with mutation and has_key?' do
    expect(run_box_first('hash_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[10 20 30 3 100 200 300 3 99 4 true false]
    )
  end

  it 'arithmetics on Float and uses Float as a hash key by value' do
    expect(run_box_first('float_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[4.0 3.75 1.0 1.6666666666666667 true true -1.5 half one_tenth]
    )
  end

  it 'concatenates Strings, indexes, hashes by content, queries empty?' do
    expect(run_box_first('string_test', env_extras: env_extras).split("\n")).to eq([
      'hello world',
      'hello there',
      '3', '3',
      'true', 'false', 'true',
      'h', 'o',
      '1', '2',
      'true', 'false',
    ])
  end

  it 'evaluates if-as-expression (ternary) and if-as-implicit-return' do
    expect(run_box_first('ternary_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[small small pos 105 small big huge]
    )
  end

  it 'dispatches case/when with subject, multi-condition, and subject-less form' do
    expect(run_box_first('case_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[A C F low mid high neg zero pos]
    )
  end

  it 'dispatches def self.X through the eigenclass, including polymorphism on a Class variable' do
    expect(run_box_first('class_method_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[42 0 99]
    )
  end

  it 'yields to a block and closes over enclosing locals' do
    expect(run_box_first('block_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[1 2 3 42 6]
    )
  end

  it 'passes a splat-arg through to a method with *rest param' do
    expect(run_box_first('splat_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[5 10 2 99]
    )
  end

  it 'concatenates interpolated strings with Integer#to_s coercion' do
    expect(run_box_first('selfcompile_more', env_extras: env_extras).strip).to eq('loaded 42 ast nodes')
  end

  it 'validates positional arity at every method body entry' do
    expect(run_box_first('arity_test', env_extras: env_extras).strip.split("\n")).to eq([
      'wrong number of arguments (given 0, expected 1)',
      'wrong number of arguments (given 2, expected 1)',
      '42',
      'wrong number of arguments (given 0, expected 1..2)',
      'wrong number of arguments (given 3, expected 1..2)',
      '799',
      '708',
      'wrong number of arguments (given 0, expected 1+)',
      '10',
      '13',
    ])
  end

  it 'lowers required-kw methods to natural-arity positional dispatch' do
    expect(run_box_first('kw_test', env_extras: env_extras).strip.split("\n")).to eq(%w[50 307 307 411 411 411])
  end

  it 'dispatches kw-bearing methods via UNSET sentinel slot' do
    expect(run_box_first('kw_unset_test', env_extras: env_extras).strip.split("\n")).to eq([
      '15', '109',
      '10', '6',
      '103', '106', '53', '56',
      '1060', '1080', '1139',
      '25', '27', '12', '12',
      '35', '37',                              # splat
      '19',                                    # kw_splat
      '1123', '1193', '1528', '1598',          # multi opt kws
      '[hi-alice!]', '[hi-alice?]',            # super
      '15',                                    # recursive
      '342', '399',                            # default-via-method
      'missing keyword: :must',                # direct missing required kw
      'missing keyword: :must',                # via send
      'unknown keyword: :bogus',               # direct unknown kw
      'unknown keyword: :bogus',               # via send
      '[:Z, :X, :Y]',                          # kw value eval — source order
    ])
  end

  it 'dispatches per-arity overloads for methods with optional positionals' do
    expect(run_box_first('multi_arity_test', env_extras: env_extras).strip.split("\n")).to eq([
      '111', '103', '6',
      '1024', '1060', '1059',
      '111', '103', '6',
      '117', '115', '24',
      '500', '11',
      'wrong number of arguments (given 2, expected 1)',
      'wrong number of arguments (given 1, expected 2)',
      '111', '103', '6',                              # splat
      '[hi-alice!]', '[hi-alice?]',                   # super with multi-arity
      '15', '12',                                     # Hop arities 1, 2
      'wrong number of arguments (given 3, expected 1..2)',
      '6',                                            # Hap arity 3
      'wrong number of arguments (given 1, expected 3)',
      'wrong number of arguments (given 2, expected 3)',
      '8', '7',                                       # Stepper arities 1, 2
      'wrong number of arguments (given 3, expected 1..2)',
      '347', '345',                                   # FastStepper arities 2, 3
      'wrong number of arguments (given 1, expected 2..3)',
      'wrong number of arguments (given 0, expected 1..2)',  # class-specific (out-of-class)
      'wrong number of arguments (given 3, expected 1..2)',  # class-specific (in family)
      '15',                                           # Walker.walk(5)
      '311', '322',                                   # default-via-method
    ])
  end

  it 'leaf-dispatch: positive/negative coverage + natural-args mix' do
    # Behavior is identical in all 4 modes — the gateway and the
    # universal VT slot produce the same observable result.
    expect(run_box_first('leaf_dispatch_test', env_extras: env_extras).strip.split("\n")).to eq([
      '42',           # LeafCalc#double — single-def leaf (positive)
      'leaf',         # LeafCalc#label — multi-def vs Thread#label in core (negative)
      'P',            # Parent#kind — Parent not a leaf (Child overrides) (negative)
      'C',            # Child#kind — multi-def with Parent
      'animal-noise', # Animal#speak — multi-leaf with Robot (negative)
      'beep',         # Robot#speak — multi-leaf with Animal
      'Hi, alice',    # Greeter#greet — natural-args optional positional
      'Yo, bob',      # Greeter#greet — natural-args explicit prefix
    ])
  end
  end  # shared_examples

  EXEC_MODES.each do |mode_name, env|
    context "[mode=#{mode_name}]" do
      let(:env_extras) { env }
      include_examples 'box-first stubs'
    end
  end
end

# Structural verification for leaf-dispatch codegen. Behavior tests
# above catch "the gateway dispatches correctly". This catches "the
# gateway is silently a no-op" — e.g. compute_leaf_dispatch_table
# regresses to returning empty, behavior tests still pass because the
# universal VT slot still works.
RSpec.describe 'box-first leaf-dispatch codegen' do
  def gen_leaf_test(env_extras)
    Dir.chdir(PROJECT_ROOT) do
      FileUtils.rm_rf(Dir.glob(File.join(GEN_DIR, 'leaf_dispatch_test*')))
      FileUtils.rm_rf(File.join(GEN_DIR, 'class'))
      env = { 'FROZONE_CPP' => '1', 'FROZONE_BOX_FIRST' => '1' }.merge(env_extras)
      out, status = Open3.capture2e(env, 'bundle', 'exec', 'ruby', 'frozone.rb',
                                    '--aot', 'bench/stubs/leaf_dispatch_test.rb')
      raise "gen failed:\n#{out}" unless status.success?
      File.read(File.join(GEN_DIR, 'leaf_dispatch_test.cpp'))
    end
  end

  def gateway_target(gen_cpp, cpp_name)
    # Returns the C++ class name from the typeid() comparison after a
    # `BasicObject* BasicObject::<cpp_name>(...) {` line, or nil if
    # the cpp_name has no out-of-line gateway body.
    return nil unless gen_cpp =~ /^BasicObject\* BasicObject::#{Regexp.escape(cpp_name)}\(Array\*[^\n]*\n\s*if \(typeid\(\*this\) == typeid\(([A-Za-z0-9_]+)\)\)/m
    Regexp.last_match(1)
  end

  context 'with LEAF=1 only (natural-args off)' do
    it 'emits typeid gateways for single-def-leaf names and skips non-leaf / multi-def' do
      cpp = gen_leaf_test('FROZONE_LEAF_DISPATCH' => '1')
      expect(gateway_target(cpp, 'm_double')).to eq('LeafCalc')      # single-def leaf — positive
      expect(gateway_target(cpp, 'm_greet')).to eq('Greeter')        # single-def leaf — positive (NA off)
      expect(gateway_target(cpp, 'm_label')).to be_nil               # multi-def vs Thread#label
      expect(gateway_target(cpp, 'm_kind')).to be_nil                # parent not a leaf
      expect(gateway_target(cpp, 'm_speak')).to be_nil               # multi-leaf
    end
  end

  context 'with LEAF=1 + NA=1' do
    it 'cedes natural-args-eligible names to NA, leaving the leaf table for the residue' do
      cpp = gen_leaf_test('FROZONE_LEAF_DISPATCH' => '1', 'FROZONE_NATURAL_ARGS' => '1')
      # In our stub, every user method that would have been leaf-eligible
      # is also natural-args eligible (pure positional / optional positional),
      # so the leaf table for THIS stub is empty under NA=1 — NA wins.
      # That's the Phase A composition rule.
      expect(gateway_target(cpp, 'm_double')).to be_nil  # natural-args claims it (pure positional)
      expect(gateway_target(cpp, 'm_greet')).to be_nil   # natural-args claims it (optional positional)
      expect(gateway_target(cpp, 'm_label')).to be_nil
      expect(gateway_target(cpp, 'm_kind')).to be_nil
      expect(gateway_target(cpp, 'm_speak')).to be_nil
    end
  end

  context 'with LEAF=0 (baseline)' do
    it 'emits no leaf-dispatch gateways at all' do
      cpp = gen_leaf_test({})
      expect(cpp).not_to include('Leaf-dispatch gateways')
      expect(gateway_target(cpp, 'm_double')).to be_nil
      expect(gateway_target(cpp, 'm_greet')).to be_nil
    end
  end
end

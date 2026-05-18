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

# Stubs bundled into the unified binary. Each is wrapped in
# `module Stub_<name>` by tools/build_unified_stub.rb. The behaviour
# `it` blocks for these stubs read their section from one binary run
# per mode (~2 min/mode) instead of paying ~30s gen+compile per stub.
# selfcompile_more stays standalone (heavy require chain).
UNIFIED_STUBS = %w[
  arity_test array_test attrw_test block_test box_test case_test
  class_method_test fib float_test getivar hash_test iow_test
  kw_test kw_unset_test leaf_dispatch_test multi_arity_test
  nqueens_small random_test splat_test string_test super_test
  ternary_test
].freeze

# Cache: env_extras (sorted-array form) → { stub_name => stdout-section }.
# Persists across `it` blocks in one rspec process so each mode only
# builds + runs the unified binary once.
$UNIFIED_CACHE = {}

def unified_sections(env_extras)
  key = env_extras.sort.to_a
  return $UNIFIED_CACHE[key] if $UNIFIED_CACHE.key?(key)

  Dir.chdir(PROJECT_ROOT) do
    out, status = Open3.capture2e('ruby', 'tools/build_unified_stub.rb', *UNIFIED_STUBS)
    raise "build_unified_stub.rb failed:\n#{out}" unless status.success?
    File.write('bench/stubs/_unified.rb', out)
  end

  stdout = run_box_first('_unified', env_extras: env_extras)

  # Parse `=== <name> ===` ... `=== /<name> ===` boundaries.
  sections = {}
  cur_name = nil
  cur_buf  = nil
  stdout.each_line do |line|
    if (m = line.match(/^=== ([\w-]+) ===\n?$/))
      cur_name = m[1]
      cur_buf  = +""
    elsif (m = line.match(%r{^=== /([\w-]+) ===\n?$}))
      raise "section end #{m[1]} mismatches start #{cur_name}" if m[1] != cur_name
      sections[cur_name] = cur_buf
      cur_name = cur_buf = nil
    elsif cur_buf
      cur_buf << line
    end
  end
  raise "unterminated section: #{cur_name}" if cur_name

  $UNIFIED_CACHE[key] = sections
end

def unified_stub_out(stub, env_extras:)
  sec = unified_sections(env_extras)[stub]
  raise "no section #{stub.inspect} in unified output (have: #{unified_sections(env_extras).keys})" if sec.nil?
  sec
end

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
      expect(unified_stub_out('fib', env_extras: env_extras).strip).to eq('27682395')
    end

  it 'instantiates a user class and dispatches its instance methods' do
    expect(unified_stub_out('box_test', env_extras: env_extras).strip).to eq("42\n84")
  end

  it 'reads ivars in a tight while loop via a class-instance constant' do
    expect(unified_stub_out('getivar', env_extras: env_extras).strip).to eq('50000')
  end

  it 'manipulates Arrays — literals, indexing (incl negative), push, first/last' do
    expect(unified_stub_out('array_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[5 10 30 50 6 99 10 99]
    )
  end

  it 'solves nq_solve(8) using bitwise ops, Array.new, And, and arr[k]= writes' do
    expect(unified_stub_out('nqueens_small', env_extras: env_extras).strip).to eq('92')
  end

  it 'dispatches Hash via Symbol AND Integer keys with mutation and has_key?' do
    expect(unified_stub_out('hash_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[10 20 30 3 100 200 300 3 99 4 true false]
    )
  end

  it 'arithmetics on Float and uses Float as a hash key by value' do
    expect(unified_stub_out('float_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[4.0 3.75 1.0 1.6666666666666667 true true -1.5 half one_tenth]
    )
  end

  it 'concatenates Strings, indexes, hashes by content, queries empty?' do
    expect(unified_stub_out('string_test', env_extras: env_extras).split("\n")).to eq([
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
    expect(unified_stub_out('ternary_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[small small pos 105 small big huge]
    )
  end

  it 'dispatches case/when with subject, multi-condition, and subject-less form' do
    expect(unified_stub_out('case_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[A C F low mid high neg zero pos]
    )
  end

  it 'dispatches def self.X through the eigenclass, including polymorphism on a Class variable' do
    expect(unified_stub_out('class_method_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[42 0 99]
    )
  end

  it 'yields to a block and closes over enclosing locals' do
    expect(unified_stub_out('block_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[1 2 3 42 6]
    )
  end

  it 'passes a splat-arg through to a method with *rest param' do
    expect(unified_stub_out('splat_test', env_extras: env_extras).strip.split("\n")).to eq(
      %w[5 10 2 99]
    )
  end

  it 'concatenates interpolated strings with Integer#to_s coercion' do
    expect(run_box_first('selfcompile_more', env_extras: env_extras).strip).to eq('loaded 42 ast nodes')
  end

  it 'validates positional arity at every method body entry' do
    expect(unified_stub_out('arity_test', env_extras: env_extras).strip.split("\n")).to eq([
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
    expect(unified_stub_out('kw_test', env_extras: env_extras).strip.split("\n")).to eq(%w[50 307 307 411 411 411])
  end

  it 'dispatches kw-bearing methods via UNSET sentinel slot' do
    expect(unified_stub_out('kw_unset_test', env_extras: env_extras).strip.split("\n")).to eq([
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
    expect(unified_stub_out('multi_arity_test', env_extras: env_extras).strip.split("\n")).to eq([
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

  it 'seeds Random correctly and reproduces MT19937 sequence' do
    # Bug history: intrinsic_random_new allocated `new Random()` directly
    # without invoking m_initialize, so universe.rb's MT19937 class state
    # (seed_, mt_[]) stayed zero — every `Random.new(seed).rand` returned
    # 0.0 forever. Splay benchmark hung (insert_new_node's collision-
    # avoidance loop spun on every find matching the root 0.0).
    expect(unified_stub_out('random_test', env_extras: env_extras).strip.split("\n")).to eq([
      '0.3745401188473625',
      '0.9507143064099162',
      '0.7319939418114051',
      '0.5986584841970366',
      '0.15601864044243652',
      '123', '0',
      'ok-distinct', 'ok-bounded',
    ])
  end

  it 'lowers attribute-write (obj.attr = val) correctly under NA + baseline' do
    # Sister of the IOW bug: from_attribute_write Array-wraps the
    # setter arg unconditionally. attr_accessor / single-arg `name=`
    # setters are NA-eligible — if the wrap mis-dispatches, the Array
    # ends up assigned as the ivar value instead of its first element.
    expect(unified_stub_out('attrw_test', env_extras: env_extras).strip.split("\n")).to eq(%w[
      10 99 42 hello! 84 10
    ])
  end

  it 'lowers super(...) correctly under NA + baseline' do
    # Sister of the IOW bug: from_method_call's super branch Array-
    # wraps super args unconditionally — risky when the parent's
    # method has only an NA slot.
    expect(unified_stub_out('super_test', env_extras: env_extras).strip.split("\n")).to eq([
      'hi: animal (dog)',
      '33',
      'hi: animal',
      '[yo: animal]',
      '10', '20', '30',
    ])
  end

  it 'lowers IndexOperatorWrite (s[i] -= 1) correctly under NA + baseline' do
    # Bug history: under FROZONE_NATURAL_ARGS=1, the IOW lowering
    # Array-wrapped the operator arg (`op_minus(new Array({1}))`) but
    # Integer's only op_minus slot was the NA-sig one which did
    # static_cast<Integer*>(arg)->raw_ — reading garbage from the
    # Array's memory. Surfaced as silently-wrong fannkuchredux output.
    expect(unified_stub_out('iow_test', env_extras: env_extras).strip.split("\n")).to eq([
      '[0, 1, 1, 2]',
      '[15, 17, 60, 10, 1]',
      '[15, 511, 170, 1020, 31]',
      '["hello world"]',
      '[11, 22, 33]',
      '[7, 40]',
      '[[1, 12], [2, 4]]',
    ])
  end

  it 'leaf-dispatch: positive/negative coverage + natural-args mix' do
    # Behavior is identical in all 4 modes — the gateway and the
    # universal VT slot produce the same observable result.
    expect(unified_stub_out('leaf_dispatch_test', env_extras: env_extras).strip.split("\n")).to eq([
      '42',           # LeafCalc#double — single-def leaf (Phase A positive)
      'leaf',         # LeafCalc#label — K=2 with Thread::Backtrace::Location (Phase B positive)
      'P',            # Parent#kind — Parent not a leaf (Child overrides) (negative)
      'C',            # Child#kind — multi-def with Parent
      'animal-noise', # Animal#speak — multi-leaf with Robot (Phase B positive)
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
    targets = gateway_targets(gen_cpp, cpp_name)
    targets&.first
  end

  def gateway_targets(gen_cpp, cpp_name)
    # Returns the array of C++ class names from the K-way typeid OR-chain
    # in the gateway body for `cpp_name`, or nil if no gateway body
    # exists. Body shape:
    #   BasicObject* BasicObject::<cpp_name>(Array*, Hash*, BasicObject*) {
    #     if (typeid(*this) == typeid(X)) { ... }
    #     if (typeid(*this) == typeid(Y)) { ... }
    #     return mm_dispatch(...);
    #   }
    # The closing `}` for the function is at column 0; nested if-block
    # closes are indented — anchor on `^\}` to bound the body precisely.
    # Ruby /m = dotall (. matches \n); we want the OPPOSITE — line-by-line
    # lazy expansion — so omit /m. ^ and $ are line-anchored by default.
    return nil unless gen_cpp =~ /^BasicObject\* BasicObject::#{Regexp.escape(cpp_name)}\(Array\*[^\n]*\{\n((?:.*\n)*?)^\}/
    body = Regexp.last_match(1)
    body.scan(/typeid\(\*this\) == typeid\(([A-Za-z0-9_]+)\)/).flatten
  end

  context 'with LEAF=1 only (natural-args off)' do
    it 'emits single-def and K-way leaf gateways; skips non-leaf' do
      cpp = gen_leaf_test('FROZONE_LEAF_DISPATCH' => '1')
      expect(gateway_target(cpp, 'm_double')).to eq('LeafCalc')      # single-def leaf — positive
      expect(gateway_target(cpp, 'm_greet')).to eq('Greeter')        # single-def leaf — positive (NA off)
      # Phase B: multi-def-all-leaf → K-way OR-chain. Order is
      # iteration-dependent (set/hash) so use match_array.
      expect(gateway_targets(cpp, 'm_speak')).to match_array(%w[Animal Robot])
      # `label` is also defined on Thread::Backtrace::Location (core) —
      # itself a leaf, so K=2 admissible under Phase B.
      expect(gateway_targets(cpp, 'm_label')).to match_array(%w[LeafCalc Thread_Backtrace_Location])
      expect(gateway_target(cpp, 'm_kind')).to be_nil                # parent not a leaf
    end
  end

  context 'with LEAF=1 + NA=1' do
    it 'cedes natural-args-eligible names to NA, leaving the leaf table for the residue' do
      cpp = gen_leaf_test('FROZONE_LEAF_DISPATCH' => '1', 'FROZONE_NATURAL_ARGS' => '1')
      # Under NA=1, pure-positional / optional-positional names are
      # claimed by natural-args first; leaf-dispatch covers what's left.
      # `m_speak` (no args) is pure-positional → NA claims it.
      expect(gateway_target(cpp, 'm_double')).to be_nil
      expect(gateway_target(cpp, 'm_greet')).to be_nil
      expect(gateway_target(cpp, 'm_speak')).to be_nil
      expect(gateway_target(cpp, 'm_label')).to be_nil
      expect(gateway_target(cpp, 'm_kind')).to be_nil
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

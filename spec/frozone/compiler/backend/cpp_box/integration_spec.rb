require 'tempfile'
require 'open3'

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
GEN_DIR      = File.join(PROJECT_ROOT, 'cpp', 'gen')

def run_box_first(stub_name)
  stub_path = "bench/stubs/#{stub_name}.rb"
  cpp_path  = File.join(GEN_DIR, "#{stub_name}.cpp")

  Dir.chdir(PROJECT_ROOT) do
    env = { 'FROZONE_CPP' => '1', 'FROZONE_BOX_FIRST' => '1' }
    out, status = Open3.capture2e(env, 'bundle', 'exec', 'ruby', 'frozone.rb', '--aot', stub_path)
    raise "frozone --aot failed for #{stub_name}:\n#{out}" unless status.success?
    raise "expected #{cpp_path} to exist after generation" unless File.exist?(cpp_path)

    bin = Tempfile.new(["box_#{stub_name}_", ''])
    bin.close
    begin
      compile_out, compile_status = Open3.capture2e(
        'g++', '-std=c++17', '-O2', cpp_path, '-lgc', '-o', bin.path
      )
      raise "g++ compile failed for #{stub_name}:\n#{compile_out}" unless compile_status.success?

      run_out, run_status = Open3.capture2e(bin.path)
      raise "run of #{stub_name} exited non-zero (#{run_status.exitstatus}):\n#{run_out}" unless run_status.success?
      run_out
    ensure
      File.unlink(bin.path) if File.exist?(bin.path)
    end
  end
end

RSpec.describe 'box-first end-to-end' do
  it 'recursively computes 3 × fib(35)' do
    expect(run_box_first('fib').strip).to eq('27682395')
  end

  it 'instantiates a user class and dispatches its instance methods' do
    expect(run_box_first('box_test').strip).to eq("42\n84")
  end

  it 'reads ivars in a tight while loop via a class-instance constant' do
    expect(run_box_first('getivar').strip).to eq('50000')
  end

  it 'manipulates Arrays — literals, indexing (incl negative), push, first/last' do
    expect(run_box_first('array_test').strip.split("\n")).to eq(
      %w[5 10 30 50 6 99 10 99]
    )
  end

  it 'solves nq_solve(8) using bitwise ops, Array.new, And, and arr[k]= writes' do
    expect(run_box_first('nqueens_small').strip).to eq('92')
  end

  it 'dispatches Hash via Symbol AND Integer keys with mutation and has_key?' do
    expect(run_box_first('hash_test').strip.split("\n")).to eq(
      %w[10 20 30 3 100 200 300 3 99 4 true false]
    )
  end

  it 'arithmetics on Float and uses Float as a hash key by value' do
    # Note: %g output differs from Ruby's puts (drops trailing .0,
    # uses 6-digit default precision). Cosmetic — semantics correct.
    expect(run_box_first('float_test').strip.split("\n")).to eq(
      %w[4 3.75 1 1.66667 true true -1.5 half one_tenth]
    )
  end

  it 'concatenates Strings, indexes, hashes by content, queries empty?' do
    expect(run_box_first('string_test').split("\n")).to eq([
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
    expect(run_box_first('ternary_test').strip.split("\n")).to eq(
      %w[small small pos 105 small big huge]
    )
  end

  it 'dispatches case/when with subject, multi-condition, and subject-less form' do
    expect(run_box_first('case_test').strip.split("\n")).to eq(
      %w[A C F low mid high neg zero pos]
    )
  end

  it 'dispatches def self.X through the eigenclass, including polymorphism on a Class variable' do
    expect(run_box_first('class_method_test').strip.split("\n")).to eq(
      %w[42 0 99]
    )
  end

  it 'yields to a block and closes over enclosing locals' do
    expect(run_box_first('block_test').strip.split("\n")).to eq(
      %w[1 2 3 42 6]
    )
  end

  it 'passes a splat-arg through to a method with *rest param' do
    expect(run_box_first('splat_test').strip.split("\n")).to eq(
      %w[5 10 2 99]
    )
  end
end

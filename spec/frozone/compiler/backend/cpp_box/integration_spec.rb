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
  it 'fib — recursive arithmetic + while loop + puts' do
    expect(run_box_first('fib').strip).to eq('27682395')
  end

  it 'box_test — user class with ivar + method dispatch' do
    expect(run_box_first('box_test').strip).to eq("42\n84")
  end

  it 'getivar — class instance constant + while loop + ivar reads' do
    expect(run_box_first('getivar').strip).to eq('50000')
  end

  it 'array_test — Array literal + indexing + .push + .first/.last' do
    expect(run_box_first('array_test').strip.split("\n")).to eq(
      %w[5 10 30 50 6 99 10 99]
    )
  end

  it 'nqueens_small — Array.new + bitwise ops + And + AttributeWrite' do
    expect(run_box_first('nqueens_small').strip).to eq('92')
  end
end

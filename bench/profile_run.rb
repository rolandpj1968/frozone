require 'stackprof'

# Profile Frozone's MRI-level execution while running the fib benchmark inside Frozone
# We use the scaled-down fib(20) benchmark to get enough samples without taking too long

$LOAD_PATH.unshift File.expand_path('..', __dir__)
require_relative '../lib/frozone/vm/vm'

bench_script = <<~RUBY
  def fib(n)
    return n if n < 2
    fib(n-1) + fib(n-2)
  end

  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  5.times { fib(20) }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts (elapsed / 5 * 1_000).to_s + " ms/iter"
RUBY

profile = StackProf.run(mode: :cpu, interval: 500) do
  vm = Frozone::Vm::Vm.new(scripts: [bench_script], argv: [], verbose: false, parser: :prism)
  vm.run
end

StackProf::Report.new(profile).print_text(false, 20)

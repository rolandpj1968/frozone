# Frozone-compatible yjit-bench harness shim.
# Iterates N times (matching bench/harness.rb) and prints timing.
def run_benchmark(n = 1, **, &block)
  n = (ENV['BENCH_N'] || n).to_i
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { block.call }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts "#{elapsed / n * 1_000} ms/iter"
end

def make_shareable(x) = x

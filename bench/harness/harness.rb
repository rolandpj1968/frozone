# Frozone-compatible yjit-bench harness shim
def run_benchmark(_n = 1, **, &block)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  block.call
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts "#{(elapsed * 1000).round(2)} ms/iter"
end

def make_shareable(x) = x

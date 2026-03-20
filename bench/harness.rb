def run_benchmark(n)
  n = (ENV['BENCH_N'] || n).to_i
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts "#{elapsed / n * 1_000} ms/iter"
end

def make_shareable(x) = x

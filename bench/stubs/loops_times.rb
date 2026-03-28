$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/loops-times'

Frozone.compile! do
  # Correctness check (same as benchmark's own check)
  u = U; r = R
  a = Array.new(10000, 0)
  4_000.times do |i|
    4_000.times do |j|
      a[i] += j % u
    end
    a[i] += r
  end
  raise "loops_times: a[7] = #{a[7]}, expected 8007" unless a[7] == 8007

  run_benchmark(10) do
    u = U; r = R
    a = Array.new(10000, 0)
    4_000.times do |i|
      4_000.times do |j|
        a[i] += j % u
      end
      a[i] += r
    end
  end
end

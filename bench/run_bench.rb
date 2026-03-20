# Runner: loads harness.rb then the benchmark file specified as ARGV[0]
harness_path = File.expand_path('harness.rb', __dir__)
bench_path = File.expand_path(ARGV[0])

load harness_path
load bench_path

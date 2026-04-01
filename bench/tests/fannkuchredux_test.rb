$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/fannkuchredux/benchmark'
sum, flips = fannkuch(N)
raise "fannkuch(9): sum=#{sum} flips=#{flips}, expected 8629 30" unless sum == 8629 && flips == 30
puts "fannkuchredux: OK"

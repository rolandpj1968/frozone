$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
require_relative '../benchmarks/sudoku'
mr, mc = sd_genmat
HARD20.each { |line| sd_solve(mr, mc, line) }
puts "sudoku: OK"

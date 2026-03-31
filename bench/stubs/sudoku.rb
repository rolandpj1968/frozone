$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
require_relative '../benchmarks/sudoku'

# Under --aot, everything below is compiled to Crystal.
mr, mc = sd_genmat
20.times do
  HARD20.each do |line|
    sd_solve(mr, mc, line)
  end
end

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
def make_shareable(x); x; end
require_relative '../benchmarks/sudoku'

Frozone.compile! do
  mr, mc = sd_genmat
  run_benchmark(20) do
    HARD20.each do |line|
      sd_solve(mr, mc, line)
    end
  end
end

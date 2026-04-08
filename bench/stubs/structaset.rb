$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/structaset'

obj = TheClass.new(1, 2, 3, 1)
850.times { set_value_loop(obj) }
puts obj.levar

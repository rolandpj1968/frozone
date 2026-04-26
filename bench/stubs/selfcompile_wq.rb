$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

require_relative '../../lib/frozone/vm/wq_parser'

puts "loaded wq parser"

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

require_relative '../../lib/frozone/ast/integer_literal'

# Execute-phase: just exercise the loaded class
puts "loaded"

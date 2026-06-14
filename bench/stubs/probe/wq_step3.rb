$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

puts "step 1: about to instantiate"
parser = Parser::Ruby40.new
puts "step 2: instantiated"
parser.diagnostics.consumer = nil
puts "step 3: consumer nil"
parser.diagnostics.all_errors_are_fatal = false
puts "step 4: errors not fatal"
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
puts "step 5: buf created"
ast = parser.parse(buf)
puts "step 6: parsed: #{ast.class}"
puts ast.to_sexp if ast
puts "step 7: done"

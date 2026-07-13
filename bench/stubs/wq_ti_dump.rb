$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../lib/frozone/vm/wq_parser'

Frozone.compile! do
  parser = Parser::Ruby40.new
  parser.diagnostics.consumer = nil
  parser.diagnostics.all_errors_are_fatal = false
  buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
  ast = parser.parse(buf)
  puts ast.to_sexp if ast
end

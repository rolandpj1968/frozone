$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

errors = []
parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |diag|
  errors << "diag: #{diag.message}"
}
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")

ast = parser.parse(buf)
puts "ast.nil?: #{ast.nil?}"
puts "errors: #{errors.size}"
errors.each { |e| puts e }
puts "ast: #{ast.class}" if ast
puts ast.to_sexp if ast

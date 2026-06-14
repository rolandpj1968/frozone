$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

# Catch the exception with class + message to pinpoint what's nil.
parser = Parser::Ruby40.new
parser.diagnostics.consumer = nil
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "x = 1")

begin
  ast = parser.parse(buf)
  puts ast ? ast.to_sexp : "ast: nil"
rescue => e
  puts "EXC: #{e.class}: #{e.message}"
end

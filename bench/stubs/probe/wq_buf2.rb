$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |diag| puts "diag: #{diag.message}" }
parser.diagnostics.all_errors_are_fatal = false
parser.lexer.source_buffer = buf

# Try to print the lexer's @source_pts size to check if source got loaded.
puts "source_pts class: #{parser.lexer.source_pts.class}"
puts "source_pts size: #{parser.lexer.source_pts.size}" if parser.lexer.respond_to?(:source_pts)

tok = parser.next_token
puts "tok class: #{tok.class}"
if tok.is_a?(Array) && tok.length == 2
  puts "tok[0]: #{tok[0]}  (false means $eof or $error)"
  inner = tok[1]
  puts "inner class: #{inner.class}"
  if inner.is_a?(Array)
    puts "inner[0]: #{inner[0]}"
  end
end

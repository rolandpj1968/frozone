$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
puts "name: #{buf.name}"
puts "source.length: #{buf.source.length}"
puts "source: #{buf.source}"

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |diag| puts "diag: #{diag.message}" }
parser.diagnostics.all_errors_are_fatal = false
parser.lexer.source_buffer = buf
puts "lexer ready"
tok = parser.next_token
puts "tok class: #{tok.class}"
if tok.is_a?(Array)
  puts "tok len: #{tok.length}"
  puts "tok[0]: #{tok[0]}"
end

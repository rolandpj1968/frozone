$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

class Parser::Lexer
  def cs; @cs; end
  def p; @p; end
  def token_queue; @token_queue; end
end

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

q_size_before = parser.lexer.token_queue.size
puts "q.size before: #{q_size_before}"
tok = parser.next_token
puts "tok[0]: #{tok[0]}"
q_size_after = parser.lexer.token_queue.size
puts "q.size after: #{q_size_after}"
puts "q after: #{parser.lexer.token_queue.inspect[0..200]}"

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

15.times do |i|
  before_cs = parser.lexer.cs
  before_p = parser.lexer.p
  q_size = parser.lexer.token_queue.size
  tok = parser.next_token
  type = tok[0]
  after_cs = parser.lexer.cs
  after_p = parser.lexer.p
  puts "i=#{i}: cs #{before_cs}->#{after_cs}, p #{before_p}->#{after_p}, q.size #{q_size} type=#{type}"
  break if type == false || type.nil?
end

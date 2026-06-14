$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

class Parser::Lexer
  def cs; @cs; end
  def p; @p; end
  def ts; @ts; end
  def te; @te; end
end

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

puts "before: cs=#{parser.lexer.cs}, p=#{parser.lexer.p}, ts=#{parser.lexer.ts}, te=#{parser.lexer.te}"
tok = parser.next_token
puts "after:  cs=#{parser.lexer.cs}, p=#{parser.lexer.p}, ts=#{parser.lexer.ts}, te=#{parser.lexer.te}"
puts "tok[0]: #{tok[0]}"

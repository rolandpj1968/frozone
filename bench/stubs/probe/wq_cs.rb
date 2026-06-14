$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

class Parser::Lexer
  def cs; @cs; end
  def p; @p; end
  def source_pts_size; @source_pts ? @source_pts.size : -1; end
end

parser = Parser::Ruby40.new
puts "after new: cs=#{parser.lexer.cs}, p=#{parser.lexer.p}, src_pts_size=#{parser.lexer.source_pts_size}"

buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf
puts "after src=buf: cs=#{parser.lexer.cs}, p=#{parser.lexer.p}, src_pts_size=#{parser.lexer.source_pts_size}"

tok = parser.next_token
puts "after advance: cs=#{parser.lexer.cs}, p=#{parser.lexer.p}"
puts "tok[0]: #{tok[0]}"

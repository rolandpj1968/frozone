$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

class Parser::Lexer
  def emit_integer; @emit_integer; end
  def num_xfrm; @num_xfrm; end
end

parser = Parser::Ruby40.new
puts "emit_integer class: #{parser.lexer.emit_integer.class}"
puts "emit_integer truthy: #{!parser.lexer.emit_integer.nil?}"
puts "num_xfrm class: #{parser.lexer.num_xfrm.class}"

# Try calling emit_integer manually
puts "trying emit_integer.call(\"1\", 5)..."
result = parser.lexer.emit_integer.call("1", 5)
puts "result: #{result}"

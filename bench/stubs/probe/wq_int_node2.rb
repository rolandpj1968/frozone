$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

tok = parser.next_token
inner = tok[1]
puts "inner[0] (value): #{inner[0]}"
puts "inner[1] (range) class: #{inner[1].class}"

builder = Parser::Builders::Default.new
builder.parser = parser
node = builder.integer(inner)
puts "node.loc class: #{node.loc.class}"
puts "node.loc.nil?: #{node.loc.nil?}"
if node.loc && !node.loc.nil?
  expr = node.loc.expression
  puts "expr class: #{expr.class}"
  puts "expr nil?: #{expr.nil?}"
end

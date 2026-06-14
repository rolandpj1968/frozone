$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

# Get the first token (an integer)
tok = parser.next_token
puts "tok 0 type: #{tok[0]}"

# Manually call builder.integer to build the AST node
# tok in parser is [value, range], not [type, [value, range]]
inner = tok[1]
puts "inner is Array: #{inner.is_a?(Array)}, len: #{inner.length}"

builder = Parser::Builders::Default.new
builder.parser = parser
node = builder.integer(inner)
puts "node class: #{node.class}"
puts "node.loc class: #{node.loc.class}"
puts "node.loc nil?: #{node.loc.nil?}"
if node.loc && !node.loc.nil?
  puts "node.loc.expression class: #{node.loc.expression.class}"
  puts "node.loc.expression nil?: #{node.loc.expression.nil?}"
end

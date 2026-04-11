# A/B test: WQ parser s-expression comparison.
#
# Load phase: require the WQ parser (whitequark parser gem).
# Execute phase: parse stdin as Ruby source, print the s-expression.
#
# Usage:
#   cat some_file.rb | crystal/wq_ab_test       # compiled
#   cat some_file.rb | bundle exec ruby frozone.rb bench/stubs/wq_ab_test.rb  # interpreted

require_relative '../../lib/frozone/vm/wq_parser'

source = $stdin.read
parser = Parser::Ruby40.new
parser.diagnostics.consumer = nil
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(stdin)", source: source)
ast = parser.parse(buf)
puts ast.to_sexp if ast

$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

10.times do |i|
  tok = parser.next_token
  break if tok.nil?
  type = tok[0]
  puts "tok #{i}: type=#{type} (Class=#{type.class})"
  break if type == false
end

$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

parser = Parser::Ruby40.new
parser.diagnostics.consumer = lambda { |d| puts "diag: #{d.message}" }
parser.diagnostics.all_errors_are_fatal = false
buf = Parser::Source::Buffer.new("(test)", source: "1 + 2")
parser.lexer.source_buffer = buf

5.times do |i|
  tok = parser.next_token
  type = tok[0]
  puts "tok #{i}: type=#{type}"
  if type != false && tok.is_a?(Array) && tok.length >= 2
    payload = tok[1]
    if payload.is_a?(Array) && payload.length >= 2
      val = payload[0]
      range = payload[1]
      puts "  value: #{val.class}"
      puts "  range: #{range.class}"
      puts "  range nil?: #{range.nil?}"
      if range && !range.nil?
        puts "  range respond_to?(:expression): #{range.respond_to?(:expression)}"
      end
    end
  end
  break if type == false
end

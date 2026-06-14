$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

parser = Parser::Ruby40.new
lexer_class = parser.lexer.class
puts "lexer class: #{lexer_class}"
puts "lex_en_line_begin: #{lexer_class.lex_en_line_begin}"
puts "lex_start: #{lexer_class.lex_start}"
puts "lex_error: #{lexer_class.lex_error}"

$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

cls = Parser::Lexer
keys = cls.send :_lex_trans_keys
spans = cls.send :_lex_key_spans
offsets = cls.send :_lex_index_offsets
indicies = cls.send :_lex_indicies
targs = cls.send :_lex_trans_targs
actions = cls.send :_lex_trans_actions
from_state = cls.send :_lex_from_state_actions
to_state = cls.send :_lex_to_state_actions
eof_trans = cls.send :_lex_eof_trans

[508, 510, 516, 528, 520].each do |s|
  puts "state #{s}: from=#{from_state[s]}, to=#{to_state[s]}, eof=#{eof_trans[s]}, span=#{spans[s]}, lo=#{keys[s<<1]}, hi=#{keys[(s<<1)+1]}"
end

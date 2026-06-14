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
to_state = cls.send :_lex_to_state_actions

probes = [[710, 49], [508, 32], [508, 49], [516, 43], [516, 32]]
probes.each do |triple|
  state = triple[0]
  ch = triple[1]
  keys_off = state << 1
  inds = offsets[state]
  slen = spans[state]
  hi = keys[keys_off + 1]
  lo = keys[keys_off]
  in_range = slen > 0 && lo <= ch && ch <= hi
  trans = in_range ? indicies[inds + ch - lo] : indicies[inds + slen]
  new_state = targs[trans]
  action = actions[trans]
  puts "#{state}+#{ch}: in_range=#{in_range} trans=#{trans} new_state=#{new_state} action=#{action}"
end
puts "to_state[508] = #{to_state[508]}"
puts "to_state[516] = #{to_state[516]}"

$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

cls = Parser::Lexer
indicies = cls.send :_lex_indicies
targs = cls.send :_lex_trans_targs
actions = cls.send :_lex_trans_actions

# After first iteration: trans=1108, new_state=710
# Action ID:
puts "action[1108]: #{actions[1108]}"

# What does the lexer do after p=1? Read source_pts[1] = ' ' (32).
# Look up next trans...
state = 710
keys = cls.send :_lex_trans_keys
spans = cls.send :_lex_key_spans
offsets = cls.send :_lex_index_offsets

# At state 710 with input 32 (space):
ch = 32
keys_off = state << 1
hi = keys[keys_off + 1]
lo = keys[keys_off]
puts "lo=#{lo}, hi=#{hi}, ch=32 in range: #{lo <= ch && ch <= hi}"
inds = offsets[state]
slen = spans[state]
trans = (slen > 0 && lo <= ch && ch <= hi) ? indicies[inds + ch - lo] : indicies[inds + slen]
puts "trans for ' ': #{trans}, new_state: #{targs[trans]}, action: #{actions[trans]}"

# Try '+'
ch = 43
trans = (slen > 0 && lo <= ch && ch <= hi) ? indicies[inds + ch - lo] : indicies[inds + slen]
puts "trans for '+': #{trans}, new_state: #{targs[trans]}, action: #{actions[trans]}"

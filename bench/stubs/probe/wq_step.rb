$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

cls = Parser::Lexer
keys = cls.send :_lex_trans_keys
spans = cls.send :_lex_key_spans
offsets = cls.send :_lex_index_offsets
indicies = cls.send :_lex_indicies
targs = cls.send :_lex_trans_targs

# Manual simulation: state=710, char='1' (49).
state = 710
ch = 49
keys_off = state << 1
inds = offsets[state]
slen = spans[state]
hi = keys[keys_off + 1]
lo = keys[keys_off]
in_range = slen > 0 && lo <= ch && ch <= hi
puts "in_range: #{in_range}"
trans = if in_range
  indicies[inds + ch - lo]
else
  indicies[inds + slen]
end
puts "trans: #{trans}"
puts "trans class: #{trans.class}"
new_state = targs[trans]
puts "new_state: #{new_state}"
puts "new_state class: #{new_state.class}"

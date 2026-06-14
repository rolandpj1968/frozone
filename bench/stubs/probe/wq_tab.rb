$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

cls = Parser::Lexer
keys = cls.send :_lex_trans_keys
puts "keys class: #{keys.class}"
puts "keys size: #{keys.size}"
puts "keys[0]: #{keys[0]}"
puts "keys[1]: #{keys[1]}"
puts "keys[1420]: #{keys[1420]}"

spans = cls.send :_lex_key_spans
puts "spans class: #{spans.class}"
puts "spans size: #{spans.size}"
puts "spans[710]: #{spans[710]}"

offsets = cls.send :_lex_index_offsets
puts "offsets size: #{offsets.size}"
puts "offsets[710]: #{offsets[710]}"

indicies = cls.send :_lex_indicies
puts "indicies size: #{indicies.size}"

# Manually do the first iteration: state=710, source_pts[0]=49 ('1')
state = 710
keys_off = state << 1
puts "keys_off: #{keys_off}"
puts "keys[keys_off]: #{keys[keys_off]} (lo)"
puts "keys[keys_off+1]: #{keys[keys_off+1]} (hi)"
puts "wide=49 falls in [#{keys[keys_off]}, #{keys[keys_off+1]}]?: #{keys[keys_off] <= 49 && 49 <= keys[keys_off+1]}"

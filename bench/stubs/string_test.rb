$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

a = "hello"
b = "world"

# Concat (immutable)
c = a + " " + b
puts c                  # hello world

# Mutating <<
a << " there"
puts a                  # hello there

# Length (codepoints) and bytesize
puts "abc".length        # 3
puts "abc".bytesize      # 3

# Comparison
puts "abc" == "abc"      # true
puts "abc" == "abd"      # false
puts "abc" < "abd"       # true

# Indexing — single byte/char as new String
puts "hello"[0]          # h
puts "hello"[-1]         # o

# Hash key with String
h = { "foo" => 1, "bar" => 2 }
puts h["foo"]            # 1
puts h["bar"]            # 2

# String#empty?
puts "".empty?           # true
puts "x".empty?          # false

# ASCII-only fast path + cache-invalidation behaviour. has_non_ascii()
# is cached on String for perf (#161 fix); ensure the cache invalidates
# correctly on `<<` mutation, including the ASCII→non-ASCII transition
# that would otherwise silently keep using the bytewise indexing path.

# Codepoint indexing on multibyte: lib/core/4.0/string.rb's String#[]
# routes via has_non_ascii() to pick byte- vs codepoint-aware index.
puts "héllo"[0]                # h
puts "héllo"[1]                # é (codepoint at index 1, bytes 1–2)
puts "héllo"[2]                # l
puts "héllo".length            # 5 codepoints

# Mutate an ASCII string with a non-ASCII byte sequence — cache must
# invalidate so subsequent indexing uses codepoint semantics.
m = "abc"
m[0]                            # warm the cache via an ASCII access
m << "é"
puts m[3]                       # é (NOT a stray utf-8 continuation byte)
puts m.length                   # 4 codepoints

# ASCII << ASCII keeps the fast path correct (invalidate-to-unknown,
# next has_non_ascii recompute returns ASCII-only again).
asc = "x"
asc[0]                          # warm cache
asc << "y"
asc << "z"
puts asc[1]                     # y
puts asc[2]                     # z
puts asc.length                 # 3

# UTF-8 char→byte search cache (#161): same lifecycle, but for the
# str_char_to_byte position cache (cp_cache_idx_, cp_cache_byte_).
# Sequential forward access is the hot case; backward and post-mutation
# must reset cleanly.
seq = "abéde"
puts seq[0]                     # a  (cache → (0, 0))
puts seq[1]                     # b  (cache → (1, 1) — advance from prior)
puts seq[2]                     # é  (cache → (2, 2) — advance through ASCII)
puts seq[3]                     # d  (cache → (3, 4) — é spans bytes 2–3)
puts seq[4]                     # e  (cache → (4, 5))
# Now go backward — cache idx > requested, must restart from 0.
puts seq[1]                     # b   (cache reset → (1, 1))
puts seq[3]                     # d   (forward advance from (1,1) → (3, 4))
# Mutation must invalidate cp_cache so post-mutation indexing is correct.
mut2 = "ab"
mut2[1]                         # b   (warm cache to something past 0)
mut2 << "éde"
puts mut2[2]                    # é   (cache invalidated → walk from 0)
puts mut2[4]                    # e   (forward from cache)
puts mut2.length                # 5

# String#unpack — only the C* (raw byte array) and U* (UTF-8
# codepoint array) formats are supported in box-first today.

bytes = "abc".unpack('C*')
puts bytes.size
bytes.each { |b| puts b }

# UTF-8: → is U+2192 (3-byte sequence E2 86 92)
codepoints = "→ok".unpack('U*')
puts codepoints.size
codepoints.each { |c| puts c }

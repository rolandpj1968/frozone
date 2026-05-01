# Box-first C++ string-literal escaping.
#
# `cpp_string_literal(s)` turns a Ruby String into a C++ string-literal
# expression — escapes the C++-special bytes (`"`, `\`, control chars)
# and renders the rest as printable ASCII or octal escapes (`\NNN`).
#
# Used by every emit site that produces a `(new String(...))`. The
# byte-level `each_byte` (vs `each_char`) keeps things encoding-
# agnostic — we emit the underlying bytes verbatim and let the C++
# compiler treat the literal as a `const char*` (length passed
# separately to the String ctor).
#
# Mixed into Cpp so call sites stay `cpp_string_literal(s)` (no
# namespace change).

module Frozone
  module Compiler
    module Backend
      module CppBox
        module StringEscape
          def cpp_string_literal(s)
            buf = +'"'
            s.each_byte do |b|
              case b
              when 0x22 then buf << '\\"'
              when 0x5C then buf << '\\\\'
              when 0x0A then buf << '\\n'
              when 0x0D then buf << '\\r'
              when 0x09 then buf << '\\t'
              when 0x00 then buf << '\\0'
              when 0x20..0x7E then buf << b.chr
              else buf << '\\' << format('%03o', b)
              end
            end
            buf << '"'
          end
        end
      end
    end
  end
end

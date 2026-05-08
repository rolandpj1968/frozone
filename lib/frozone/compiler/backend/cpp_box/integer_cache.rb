# Box-first Integer literal interning.
#
# Every unique IntegerLiteral value seen during emission becomes one
# shared static `Integer` instance, referenced by address (`(&_f_i_N)`).
# Without interning, the wq parser stub emits `(new Integer(805LL))`
# 6K+ times (lexer state-machine constants), drowning cc1plus.
#
# Negative values get `_f_i_n<abs>` so they're still valid C++
# identifiers.
#
# Big Integer-only Arrays (above INT_ARRAY_THRESHOLD elements) get
# specialised to a raw `int64_t[]` table emitted via
# `write_raw_int_arrays` plus a runtime build call — cuts source size
# and cc1plus parse time vs emitting `(&_f_i_X), ` per element.
#
# Mixed into Cpp so call sites stay `intern_int(v)` /
# `int_literal_name(v)` (no namespace change).

module Frozone
  module Compiler
    module Backend
      module CppBox
        module IntegerCache
          # Above this size (number of elements), an Integer-only Array
          # gets specialised to a raw int64_t[] table + runtime build.
          # Small arrays stay as `(new Array({...}))` brace-init —
          # the per-element overhead doesn't matter at small N.
          INT_ARRAY_THRESHOLD = 8

          # Return a reference to the interned Integer for `value`.
          # Each unique value becomes one named static `_f_i_<N>` (with
          # negatives prefixed `_f_i_n<abs>`). The decls are emitted by
          # write_int_literals after class defs are complete.
          def intern_int(value)
            @int_literals[value] = true unless @int_literals.key?(value)
            "(&#{int_literal_name(value)})"
          end

          def int_literal_name(value) = value >= 0 ? "_f_i_#{value}" : "_f_i_n#{-value}"

          # Emit the raw int64_t[] tables collected during static-state
          # capture. Each goes after Integer is complete (so the runtime
          # `build_int_array` helper can construct Integer instances).
          def write_raw_int_arrays(emit)
            return if @raw_int_arrays.empty?
            emit.line "// Raw int64_t tables for large Integer-only Arrays —"
            emit.line "// build_int_array() boxes them into Array+Integer at static-init"
            emit.line "// time. Cuts source size and cc1plus parse time vs emitting"
            emit.line "// each element as `(&_f_i_X), `."
            @raw_int_arrays.each_with_index do |values, idx|
              # `inline` instead of `static const` so the layouts header
              # can host these arrays — single definition across TUs that
              # need to take addresses of (&__TBL_INT_X__[N]) etc.
              emit.line "inline const int64_t __TBL_INT_#{idx}__[#{values.size}] = {#{values.join(",")}};"
            end
            emit.blank
          end

          # Emit the named static decls. Positioned after all class
          # definitions (Integer must be complete to call its ctor).
          # Each is its own variable — cc1plus parses each
          # independently, much cheaper than one big array initializer
          # for the wq parser scale (~thousands of unique literals).
          # `inline` (C++17 inline variable) so the layouts header can
          # include them without ODR clashes — multiple TUs see the
          # same single definition. Required so per-class TUs and the
          # universe TU can reference (&_f_i_N) when emitting accessor
          # bodies that use Integer literals.
          def write_int_literals(emit)
            return if @int_literals.empty?
            emit.line "// Interned Integer literals — every unique IntegerLiteral and"
            emit.line "// IntegerObject in the program graph maps to one shared inline"
            emit.line "// instance. Direct named inlines (rather than an array) so"
            emit.line "// cc1plus parses each as an independent declaration."
            @int_literals.each_key do |value|
              emit.line "inline Integer #{int_literal_name(value)}(#{value}LL);"
            end
            emit.blank
          end
        end
      end
    end
  end
end

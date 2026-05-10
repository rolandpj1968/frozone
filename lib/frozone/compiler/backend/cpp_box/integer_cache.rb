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
          # EXTERN decls only — the storage definitions live in
          # write_raw_int_array_defs (a dedicated .cpp). Per-TU
          # only parses the extern decls, not thousands of int
          # literals.
          def write_raw_int_array_decls(emit)
            return if @raw_int_arrays.empty?
            emit.line "// Raw int64_t tables for large Integer-only Arrays —"
            emit.line "// extern decls only; storage in frozone_int_literals.cpp."
            @raw_int_arrays.each_with_index do |values, idx|
              emit.line "extern const int64_t __TBL_INT_#{idx}__[#{values.size}];"
            end
            emit.blank
          end

          def write_raw_int_array_defs(emit)
            return if @raw_int_arrays.empty?
            emit.line "// Raw int64_t tables — single TU's worth of storage."
            @raw_int_arrays.each_with_index do |values, idx|
              emit.line "const int64_t __TBL_INT_#{idx}__[#{values.size}] = {#{values.join(",")}};"
            end
            emit.blank
          end

          # Backwards-compat alias for write_raw_int_arrays callers
          # (now routes to write_raw_int_array_decls + _defs split).
          def write_raw_int_arrays(emit)
            write_raw_int_array_decls(emit)
          end

          # Emit just the EXTERN DECLARATIONS — `extern Integer _f_i_N;`
          # — to a header that every TU pulls in. Forward decl of
          # Integer (in base.hpp) suffices for extern decls. Per-TU
          # parse cost is negligible: ~thousands of cheap one-liners.
          # The actual storage definitions go to their own .cpp via
          # write_int_literal_defs.
          def write_int_literal_decls(emit)
            return if @int_literals.empty?
            emit.line "// Interned Integer literals — extern decls only."
            emit.line "// Storage definitions live in a dedicated .cpp so per-TU"
            emit.line "// compile cost stays small (no per-TU constructor calls)."
            @int_literals.each_key do |value|
              emit.line "extern Integer #{int_literal_name(value)};"
            end
            emit.blank
          end

          # Emit the storage DEFINITIONS — `Integer _f_i_N(NLL);` —
          # to a single .cpp. Needs Integer to be a complete type
          # (Integer's hpp must be included by the consuming TU).
          # One TU's worth of Integer-constructor calls; not paid by
          # other TUs.
          def write_int_literal_defs(emit)
            return if @int_literals.empty?
            emit.line "// Interned Integer literal storage — single definition."
            @int_literals.each_key do |value|
              emit.line "Integer #{int_literal_name(value)}(#{value}LL);"
            end
            emit.blank
          end
        end
      end
    end
  end
end

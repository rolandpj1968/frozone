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
# Small-int runtime cache: the literal pool is ALWAYS pre-seeded with
# every value in SMALL_INT_RANGE (regardless of whether source code
# references it). A parallel `__SMALL_INTS__[]` LUT of pointers lets
# `boxed_int(v)` return a pre-allocated `&_f_i_<v>` for values in
# range without `new`, falling back to `new Integer(v)` for big
# values. Used by arithmetic intrinsics — matches the interpreter's
# IntegerObject.from() caching and keeps GC heat down on tight loops
# (1+1+1+…).
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

          # Range of values pre-seeded into the literal pool AND made
          # available via the runtime `__SMALL_INTS__[]` LUT used by
          # boxed_int(). 256 statics → ~16KB. Positive-only — negatives
          # earn nothing in the bench suite (fib/sudoku/nqueens/blurhash);
          # most hot paths are loop counters and small unsigned bitmasks.
          # Extending to 1023 helped sudoku ~8% but was noise elsewhere;
          # keep minimal until a wider workload justifies the memory.
          SMALL_INT_RANGE = (0..255)

          # Seed @int_literals with every value in SMALL_INT_RANGE so
          # the corresponding _f_i_<N> statics are guaranteed to exist.
          # Called once at cache init.
          def seed_small_int_literals
            SMALL_INT_RANGE.each { |n| @int_literals[n] = true }
          end

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

          # Emit the small-int LUT extern decl + boxed_int inline helper
          # to the same header that has the _f_i_<N> externs. Every
          # intrinsic TU includes this header (via frozone_all.hpp), so
          # `boxed_int(v)` is available everywhere — replaces direct
          # `new Integer(v)` in arithmetic / coerce sites.
          def write_small_int_lut_decls(emit)
            emit.line "// Small-int runtime cache — LUT of pointers into the"
            emit.line "// _f_i_<N> pool. boxed_int(v) returns a pre-allocated"
            emit.line "// instance when |v| <= SMALL_INT_MAX, else `new Integer(v)`."
            emit.line "constexpr int64_t SMALL_INT_MIN = #{SMALL_INT_RANGE.min};"
            emit.line "constexpr int64_t SMALL_INT_MAX = #{SMALL_INT_RANGE.max};"
            emit.line "constexpr int64_t SMALL_INT_LUT_SIZE = #{SMALL_INT_RANGE.size};"
            emit.line "extern Integer* const __SMALL_INTS__[SMALL_INT_LUT_SIZE];"
            emit.blank
            emit.line "inline BasicObject* boxed_int(int64_t v) {"
            emit.line "  if (v >= SMALL_INT_MIN && v <= SMALL_INT_MAX) {"
            emit.line "    return __SMALL_INTS__[v - SMALL_INT_MIN];"
            emit.line "  }"
            emit.line "  return new Integer(v);"
            emit.line "}"
            emit.blank
          end

          # Emit the small-int LUT storage definition — one TU pays for
          # the table; everyone else just sees the extern.
          def write_small_int_lut_defs(emit)
            emit.line "// Small-int LUT — pointers into the _f_i_<N> pool."
            emit.line "Integer* const __SMALL_INTS__[SMALL_INT_LUT_SIZE] = {"
            SMALL_INT_RANGE.each_slice(16) do |chunk|
              emit.line "  " + chunk.map { |n| "&#{int_literal_name(n)}" }.join(", ") + ","
            end
            emit.line "};"
            emit.blank
          end
        end
      end
    end
  end
end

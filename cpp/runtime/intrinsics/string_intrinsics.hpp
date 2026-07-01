// String-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_STRING_INTRINSICS_HPP
#define FROZONE_STRING_INTRINSICS_HPP


#include "../intrinsics_helpers.hpp"

namespace Ruby {

// --- character <-> byte offset mapping (UTF-8 aware) -------------------
// Character ↔ byte index helpers — defined in string_intrinsics.cpp.
// TU-local: only intrinsic_string_X bodies need them.
std::size_t str_char_to_byte(const String* s, std::int64_t char_idx);
std::int64_t str_byte_to_char(const String* s, std::size_t byte_off);

BasicObject* intrinsic_string_index(BasicObject* self_, BasicObject* sub, BasicObject* offset);

// `String#[](idx, len = :__unset__)` — substring extraction.
// Character-indexed for UTF-8 (byte-indexed for BINARY), matching MRI.
// Integer/Range/Regexp/String idx supported. Negative idx counts from
// end. Without len, a single character; with len, len characters from
// idx (clamped). Returns nil if idx out of range.
BasicObject* intrinsic_string_slice(BasicObject* self_, BasicObject* idx, BasicObject* len);

// `String#[]=` via string_store(self, idx, rest), where rest is [value]
// or [length, value]. Character-indexed for UTF-8 (byte-indexed for
// BINARY/pure-ASCII). Handles Integer, Integer+length, Range, and
// String (substring) idx; Regexp/other deferred (loud). The Ruby
// wrapper String#[]= performs the frozen check before calling.
BasicObject* intrinsic_string_store(BasicObject* self_, BasicObject* idx, BasicObject* rest_);

// `String#split(sep, limit)` — separator: nil (whitespace), String,
// or Regexp (deferred). limit: :__unset__/nil → all, Integer → at
// most that many parts. nil sep collapses consecutive whitespace and
// trims; String sep does byte-find loop; Regexp sep aborts for now.
BasicObject* intrinsic_string_split(BasicObject* self_, BasicObject* sep, BasicObject* limit);

// `String#chars` — Array of 1-byte Strings. ASCII-safe; UTF-8
// multibyte chars come back as separate bytes (good enough for most
// parsing; full UTF-8 char-grouping can come later).
// `String#tr(from, to)` — byte-level translation table (ASCII only,
// no Unicode codepoint awareness). MRI semantics:
//  - "a-z" expands to abcdefghijklmnopqrstuvwxyz
//  - leading "^" negates (translate everything NOT in from_str)
//  - to shorter than from: extra from-chars map to to's last char
//  - to empty: delete those bytes
// Optparse uses the simplest form ("_" -> "-"); fuller MRI conformance
// (Unicode chars, multi-byte ranges) is a follow-up.
BasicObject* intrinsic_string_tr_raw(BasicObject* self_, BasicObject* from_, BasicObject* to_);

// `String#initialize(str, encoding)` — copy bytes from `str` into
// self. The third arg (encoding) is handled by a separate
// `force_encoding` call right after in lib/core/4.0/string.rb#L26,
// so we ignore it here. Returns nil (intrinsic contract; the Ruby
// wrapper returns self).
BasicObject* intrinsic_string_initialize(BasicObject* self_, BasicObject* str_, BasicObject* /*encoding_*/);

// `String#replace(other)` — overwrite self's bytes/encoding with
// other's, return self. Mutates self in place; both String#replace
// (lib/core/4.0/string.rb:58) and the __bang__ wrapper used by tr! /
// upcase! / downcase! lower to this single intrinsic.
BasicObject* intrinsic_string_replace(BasicObject* self_, BasicObject* other_);

BasicObject* intrinsic_string_chars(BasicObject* self_);

// String#encoding / #force_encoding — read/write the String's
// 2-value `enc` field. BINARY is identified by the Encoding's @name
// being "ASCII-8BIT" (string-content comparison, since the runtime
// Encoding instance for Encoding::BINARY differs from the snapshot
// kernel k_Encoding_BINARY() — two different `new Encoding()` calls
// during load phase).
BasicObject* intrinsic_string_encoding(BasicObject* self_);
BasicObject* intrinsic_string_force_encoding(BasicObject* self_, BasicObject* enc);

// `String#inspect` — quoted with C-style escapes for non-printable
// bytes. Mirrors cpp_string_literal: \n, \r, \t, \\, \", \NNN.
BasicObject* intrinsic_string_inspect(BasicObject* self_);

// `String#%(args)` / `Kernel#format(self, args)` / `sprintf` — minimal
// impl covering only the patterns the WQ parser uses today:
//   %{key}    — Hash-keyed substitution (parser's :error template style)
//   %s        — to_s of next positional arg (Array)
//   %d        — to_s of next Integer positional arg
//   %%        — literal '%'
// Anything else passes through unchanged + a stderr warning. Widen
// when a real test case demands more (precision/width/flags etc.).
BasicObject* intrinsic_string_format(BasicObject* self_, BasicObject* args);

// `String#hash` — FNV-1a 64-bit over bytes. Identity-stable for the
// process lifetime; close enough for Hash key behaviour.
BasicObject* intrinsic_string_hash(BasicObject* self_);

// `String#count(*selectors)` — count bytes in self that match the
// intersection of byte-sets derived from each selector argument.
// `args_obj` is the Array produced by `__str_args__(*args)` at the
// call site (each element coerced to a String via `__coerce_to_str__`).
// First-cut byte-level semantics — does not handle Ruby's `^foo`
// negation, `a-z` ranges, or `\\` escapes; covers the common ASCII
// case mspec init paths exercise. Grow per concrete spec failure.
BasicObject* intrinsic_string_count_raw(BasicObject* self_, BasicObject* args_obj);

// ---- Array ---------------------------------------------------------

// `Array#to_s` / `Array#inspect` — `[a, b, c]` form. Calls m_inspect
// on each element. `[]` for empty.
BasicObject* intrinsic_array_to_s(BasicObject* self_);

// `Array#unshift(*elems)` / `Array#prepend` — splat folds into a single
// elems Array per the IntrinsicCall splat convention (cpp.rb:from_intrinsic_call).
// Inserts elems' contents at index 0 in source order: `[].unshift(1, 2)` → [1, 2].
BasicObject* intrinsic_array_unshift(BasicObject* self_, BasicObject* elems);

// `Array#[]=(i, val)` — single-index assignment. `i` is the integer
// index (Ruby-side coerce_to_int already applied). Negative i wraps
// from the end. Out-of-range i grows the array, padding with nil.
BasicObject* intrinsic_array_index_write(BasicObject* self_, BasicObject* i, BasicObject* val);

// `Array#[]=(start, length) = val` — slice assignment. start/length
// already int-coerced on the Ruby side. val is an Array (or nil for
// the delete-slice case). Replaces self.data[start, length] with val's
// elements; if start is past the end, extends with nils.
BasicObject* intrinsic_array_slice_write(BasicObject* self_, BasicObject* start, BasicObject* length, BasicObject* val);

// `Array#sample` (no random:) — pick one element using the process's
// global PRNG. Returns nil for empty. Random source override is
// handled Ruby-side; this is the no-source fast path.
BasicObject* intrinsic_array_sample(BasicObject* self_);

// `Array#sample(n)` (no random:) — pick n distinct elements. n is
// already int-coerced and clamped to [0, length] on the Ruby side.
// Returns a new Array of n elements (Fisher-Yates partial shuffle).
BasicObject* intrinsic_array_sample_n(BasicObject* self_, BasicObject* n);

// `Array#initialize(size_or_array, fill, &block)`. The Ruby wrapper
// (lib/core/4.0/array.rb) already validates args, performs
// __coerce_to_int__ on size, and routes the to_ary path. We see exactly
// one of these shapes:
//   * size_or_array is Array  → copy its data into self
//   * size_or_array is Integer + block nil → fill n slots with `fill`
//   * size_or_array is Integer + block Proc → call block(i) for i in 0..n-1
//   * size_or_array is nil    → leave self empty
// Returns self.
BasicObject* intrinsic_array_initialize(BasicObject* self_, BasicObject* size_or_array,
                                        BasicObject* fill, BasicObject* block);

// `String#upcase(*opts)` / `#downcase` / `#swapcase` / `#capitalize`
// — Unicode-aware case mapping. Routes through Onigmo's
// onigenc_unicode_case_map (the same code MRI uses internally), so we
// get the full Unicode 11 case tables, ß→SS, Greek-sigma context,
// case-folding-only forms, plus the :turkic and :lithuanian locale
// tailorings. Args is the splat-wrapped Array of symbols.
//
// Returns a freshly-allocated String (these methods don't mutate self
// in MRI; the `!` siblings are pure-Ruby wrappers that swap bytes via
// String#replace).
BasicObject* intrinsic_string_upcase_opts(BasicObject* self_, BasicObject* opts);
BasicObject* intrinsic_string_downcase_opts(BasicObject* self_, BasicObject* opts);
BasicObject* intrinsic_string_swapcase_opts(BasicObject* self_, BasicObject* opts);
BasicObject* intrinsic_string_capitalize_opts(BasicObject* self_, BasicObject* opts);

// `String#append_as_bytes(*args)` / `String#append_bytes(*args)` —
// extend self's byte vector with bytes drawn from each arg without any
// encoding validation. String arg → its bytes appended verbatim;
// Integer arg → low byte (`arg & 0xFF`). Self's encoding is preserved.
// Ruby wrapper passes the splat args through as a single Array.
// append_as_bytes and append_bytes have the same semantics here; the
// Ruby surface difference is encoding-flag bookkeeping handled outside.
BasicObject* intrinsic_string_append_as_bytes(BasicObject* self_, BasicObject* args);
BasicObject* intrinsic_string_append_bytes(BasicObject* self_, BasicObject* args);

// `String#bytesplice(idx, len, replacement)` — byte-indexed splice.
// Replaces self.bytes[idx, len] with replacement.bytes (a String).
// MRI's full signature (range form, source-substring form) is not
// implemented; callers that pass anything other than three args
// (Integer, Integer, String) get a not-implemented abort. The Ruby
// wrapper handles the frozen check before calling.
BasicObject* intrinsic_string_bytesplice(BasicObject* self_, BasicObject* args);

// `String#match(pattern)` — same as Regexp#match with self/str swapped.
BasicObject* intrinsic_string_match(BasicObject* self_, BasicObject* pat);

// `String#match(pattern, pos)`.
BasicObject* intrinsic_string_match_pos(BasicObject* self_, BasicObject* pat, BasicObject* pos);

// ---- Symbol --------------------------------------------------------

// `Symbol#to_s` — Symbol::name_ is a const char* set by intern();
// wrap into a fresh String.
BasicObject* intrinsic_symbol_to_s(BasicObject* self_);

// ---- String (cont.) ------------------------------------------------

// `String#to_sym` — interns the byte-buffer as a Symbol. intern()
// requires NUL-terminated; copy into a std::string for the lookup.
BasicObject* intrinsic_string_to_sym(BasicObject* self_);

// `String#to_i(base)` — std::strtoll on the byte buffer. Empty /
// non-numeric prefix returns 0 (matches MRI). Stub: doesn't handle
// 0x/0b/0o prefixes for base==0; widen as needed.
BasicObject* intrinsic_string_to_i_base(BasicObject* self_, BasicObject* base);

// ---- String (Tier-B continuation) ----------------------------------
//
// All intrinsics here cast via static_cast<String*> on String args
// — the Ruby wrappers in lib/core/4.0/string.rb run __coerce_to_str__
// upstream (or the call site is `v.is_a?(String) ? Intrinsics.X(self, v)`
// guarded), so by the intrinsic boundary the args are guaranteed
// String. Where Integer args are accepted (offsets, codepoints), the
// same guarantee holds via __coerce_to_int__.

BasicObject* intrinsic_string_dup(BasicObject* self_);
BasicObject* intrinsic_string_clone(BasicObject* self_, BasicObject* /*freeze*/);

BasicObject* intrinsic_string_eql(BasicObject* self_, BasicObject* other);

BasicObject* intrinsic_string_concat(BasicObject* self_, BasicObject* other);

BasicObject* intrinsic_string_concat_codepoint(BasicObject* self_, BasicObject* cp);

BasicObject* intrinsic_string_dedup(BasicObject* self_);

BasicObject* intrinsic_string_byteindex(BasicObject* self_, BasicObject* sub, BasicObject* offset = nullptr);

BasicObject* intrinsic_string_byterindex(BasicObject* self_, BasicObject* sub, BasicObject* offset = nullptr);

BasicObject* intrinsic_string_byteslice(BasicObject* self_, BasicObject* idx, BasicObject* len);

BasicObject* intrinsic_string_ord(BasicObject* self_);

BasicObject* intrinsic_string_oct(BasicObject* self_);

BasicObject* intrinsic_string_rindex(BasicObject* self_, BasicObject* sub, BasicObject* offset);

BasicObject* intrinsic_string_each_line(BasicObject* self_, BasicObject* sep, BasicObject* /*limit*/);

BasicObject* intrinsic_string_dump(BasicObject* self_);

BasicObject* intrinsic_string_grapheme_clusters(BasicObject* self_);

BasicObject* intrinsic_string_slice_bang(BasicObject* self_, BasicObject* idx, BasicObject* len);

// Aborts for genuinely complex Tier-B cases — these have non-trivial
// semantics (Unicode tables, Complex parser, format-string parser)
// that nothing in self-host frozone exercises. Each gets a loud
// message naming the unsupported intrinsic.
BasicObject* intrinsic_string_tr_s(BasicObject* /*s*/, BasicObject* /*from*/, BasicObject* /*to*/);
BasicObject* intrinsic_string_unpack1(BasicObject* /*s*/, BasicObject* /*fmt*/, BasicObject* /*offset*/);
BasicObject* intrinsic_string_undump(BasicObject* /*s*/);
BasicObject* intrinsic_string_crypt(BasicObject* /*s*/, BasicObject* /*salt*/);
BasicObject* intrinsic_string_scrub(BasicObject* /*s*/, BasicObject* /*replacement*/, BasicObject* /*block*/);
BasicObject* intrinsic_string_unicode_normalize(BasicObject* /*s*/, BasicObject* /*form*/);
BasicObject* intrinsic_string_unicode_normalized_q(BasicObject* /*s*/, BasicObject* /*form*/);
BasicObject* intrinsic_string_to_c(BasicObject* /*s*/);

}  // namespace Ruby

#endif  // FROZONE_STRING_INTRINSICS_HPP

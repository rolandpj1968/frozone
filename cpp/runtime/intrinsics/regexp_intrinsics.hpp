// Regexp-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_REGEXP_INTRINSICS_HPP
#define FROZONE_REGEXP_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Regexp --------------------------------------------------------

// `Regexp.escape(str)` — backslash-escape regex metacharacters so the
// result matches the input as a literal pattern.
BasicObject* intrinsic_regexp_escape(BasicObject* str);

// ---- Regexp / MatchData --------------------------------------------

// `re.inspect` — `/source/`. Options stripped; full MRI form
// `(?-mix:...)` not implemented.
BasicObject* intrinsic_regexp_inspect(BasicObject* self_);

// `re.to_s` — same surface as inspect.
BasicObject* intrinsic_regexp_to_s(BasicObject* self_);

// `Regexp.new(pattern, options, kw_opts)` — class arg comes first
// (eigenclass-side intrinsic), pattern is String, options is Integer
// or nil, kw_opts ignored.
BasicObject* intrinsic_regexp_new(BasicObject* /*klass*/, BasicObject* pat, BasicObject* opts, BasicObject* /*kw*/);

// `re =~ str` — Integer byte-offset of first match, or nil. Sets $~.
BasicObject* intrinsic_regexp_match_index(BasicObject* self_, BasicObject* str);

// `re.match(str, pos)` — MatchData or nil. Sets $~.
BasicObject* intrinsic_regexp_match(BasicObject* self_, BasicObject* str, BasicObject* pos);

// `Regexp.last_match` / `Regexp.last_match(n)` — read $~ or capture n.
// nil arg → return $~ itself; Integer arg → return capture n.
BasicObject* intrinsic_regexp_last_match(BasicObject* n);

// `MatchData#to_a` — Array of all captures (including capture 0 = full
// match). Each capture is a String (or nil if unmatched optional group).
BasicObject* intrinsic_match_data_to_a(BasicObject* self_);

// `MatchData#captures` — Array of captures EXCLUDING capture 0.
BasicObject* intrinsic_match_data_captures(BasicObject* self_);

// `MatchData#pre_match` — substring of original string before match.
BasicObject* intrinsic_match_data_pre_match(BasicObject* self_);

// `MatchData#post_match` — substring of original string after match.
BasicObject* intrinsic_match_data_post_match(BasicObject* self_);

// `MatchData#match_length(n)` — byte length of capture n.
BasicObject* intrinsic_match_data_match_length(BasicObject* self_, BasicObject* n);

}  // namespace Ruby

#endif  // FROZONE_REGEXP_INTRINSICS_HPP

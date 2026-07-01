// Regexp-category intrinsic definitions. Declarations live in
// regexp_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "regexp_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Regexp --------------------------------------------------------

// `Regexp.escape(str)` — backslash-escape regex metacharacters so the
// result matches the input as a literal pattern.
BasicObject* intrinsic_regexp_escape(BasicObject* str) {
  auto* _s = static_cast<String*>(str);
  std::string _buf;
  _buf.reserve(_s->bytes.size());
  for (auto _b : _s->bytes) {
    switch (_b) {
      case '\\': case '.': case '+': case '*': case '?':
      case '(': case ')': case '[': case ']': case '{': case '}':
      case '|': case '^': case '$': case '#':
        _buf.push_back('\\');
        _buf.push_back(static_cast<char>(_b));
        break;
      case ' ':  _buf += "\\ "; break;
      case 0x0A: _buf += "\\n"; break;
      case 0x0D: _buf += "\\r"; break;
      case 0x09: _buf += "\\t"; break;
      case 0x0C: _buf += "\\f"; break;
      case 0x0B: _buf += "\\v"; break;
      default: _buf.push_back(static_cast<char>(_b));
    }
  }
  return new String(_buf.data(), _buf.size());
}

// ---- Regexp / MatchData --------------------------------------------

// `Regexp.new(pattern, options, kw_opts)` — class arg comes first
// (eigenclass-side intrinsic), pattern is String, options is Integer
// or nil, kw_opts ignored.
BasicObject* intrinsic_regexp_new(BasicObject* /*klass*/, BasicObject* pat, BasicObject* opts, BasicObject* /*kw*/) {
  auto* _re = new Regexp();
  auto* _a = new Array({
      pat,
      (opts == nil_instance() ? static_cast<BasicObject*>(boxed_int(0)) : opts),
  });
  _re->m_initialize(univ, _a);
  return _re;
}

// `re =~ str` — Integer byte-offset of first match, or nil. Sets $~.
BasicObject* intrinsic_regexp_match_index(BasicObject* self_, BasicObject* str) {
  auto* _md = regexp_match_helper(self_, str, 0);
  return _md ? static_cast<BasicObject*>(boxed_int(_md->captures_[0].first)) : nil_instance();
}

// `re.match(str, pos)` — MatchData or nil. Sets $~.
BasicObject* intrinsic_regexp_match(BasicObject* self_, BasicObject* str, BasicObject* pos) {
  auto* _md = regexp_match_helper(self_, str, static_cast<Integer*>(pos)->raw_);
  return _md ? static_cast<BasicObject*>(_md) : nil_instance();
}

// `Regexp.last_match` / `Regexp.last_match(n)` — read $~ or capture n.
// nil arg → return $~ itself; Integer arg → return capture n.
BasicObject* intrinsic_regexp_last_match(BasicObject* n) {
  BasicObject* _md = g_last_match();
  if (n == nil_instance() || n == nullptr) return _md;
  if (_md == nullptr || _md == nil_instance()) return nil_instance();
  return matchdata_cap(_md, static_cast<Integer*>(n)->raw_);
}

}  // namespace Ruby

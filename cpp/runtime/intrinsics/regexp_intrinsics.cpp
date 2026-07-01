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

// `MatchData#to_a` — Array of all captures (including capture 0 = full
// match). Each capture is a String (or nil if unmatched optional group).
BasicObject* intrinsic_match_data_to_a(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _a = new Array();
  _a->data.reserve(_md->captures_.size());
  for (std::size_t i = 0; i < _md->captures_.size(); i++) {
    _a->data.push_back(matchdata_cap(_md, static_cast<std::int64_t>(i)));
  }
  return _a;
}

// `MatchData#captures` — Array of captures EXCLUDING capture 0.
BasicObject* intrinsic_match_data_captures(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _a = new Array();
  if (_md->captures_.size() > 1) {
    _a->data.reserve(_md->captures_.size() - 1);
    for (std::size_t i = 1; i < _md->captures_.size(); i++) {
      _a->data.push_back(matchdata_cap(_md, static_cast<std::int64_t>(i)));
    }
  }
  return _a;
}

// `MatchData#pre_match` — substring of original string before match.
BasicObject* intrinsic_match_data_pre_match(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _s = static_cast<String*>(_md->iv_string);
  std::int64_t _b = _md->captures_[0].first;
  if (_b < 0) _b = 0;
  return new String(reinterpret_cast<const char*>(_s->bytes.data()), static_cast<std::size_t>(_b));
}

// `MatchData#post_match` — substring of original string after match.
BasicObject* intrinsic_match_data_post_match(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _s = static_cast<String*>(_md->iv_string);
  std::int64_t _e = _md->captures_[0].second;
  if (_e < 0) _e = static_cast<std::int64_t>(_s->bytes.size());
  return new String(reinterpret_cast<const char*>(_s->bytes.data() + _e),
                    _s->bytes.size() - static_cast<std::size_t>(_e));
}

// `MatchData#match_length(n)` — byte length of capture n.
BasicObject* intrinsic_match_data_match_length(BasicObject* self_, BasicObject* n) {
  auto* _md = static_cast<MatchData*>(self_);
  std::int64_t _i = static_cast<Integer*>(n)->raw_;
  auto [_b, _e] = _md->captures_[_i];
  return boxed_int(_e - _b);
}


}  // namespace Ruby

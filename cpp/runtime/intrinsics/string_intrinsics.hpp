// String-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_STRING_INTRINSICS_HPP
#define FROZONE_STRING_INTRINSICS_HPP

inline BasicObject* intrinsic_string_index(BasicObject* self_, BasicObject* sub, BasicObject* offset) {
  auto* _s = static_cast<String*>(self_);
  std::int64_t _hsize = static_cast<std::int64_t>(_s->bytes.size());
  std::int64_t _off = 0;
  if (offset != intern("__unset__") && offset != nil_instance()) {
    _off = static_cast<Integer*>(offset)->raw_;
  }
  if (_off < 0) _off = std::max<std::int64_t>(0, _hsize + _off);
  if (_off > _hsize) return nil_instance();
  if (sub->m_class() == reinterpret_cast<BasicObject*>(&Regexp_CLASS)) {
    auto* _md = regexp_match_helper(sub, _s, _off);
    if (!_md) return nil_instance();
    return new Integer(_md->captures_[0].first);
  }
  if (sub->m_class() != reinterpret_cast<BasicObject*>(&String_CLASS)) {
    std::fprintf(stderr, "[frozone-box-first] string_index: non-String/Regexp sub not yet supported\n");
    std::abort();
  }
  auto* _sub = static_cast<String*>(sub);
  std::int64_t _nsize = static_cast<std::int64_t>(_sub->bytes.size());
  if (_nsize == 0) return new Integer(_off);
  if (_off + _nsize > _hsize) return nil_instance();
  for (std::int64_t _i = _off; _i + _nsize <= _hsize; _i++) {
    if (std::memcmp(&_s->bytes[_i], _sub->bytes.data(), _nsize) == 0) {
      return new Integer(_i);
    }
  }
  return nil_instance();
}

// Map a character index to a byte offset honouring the string's
// encoding. For BINARY, character index == byte index. For UTF-8, walk
// codepoints (a continuation byte matches 10xxxxxx). char_idx is
// clamped to [0, length]; char_idx == length returns bytes.size().
inline std::size_t str_char_to_byte(const String* s, std::int64_t char_idx) {
  std::int64_t n = static_cast<std::int64_t>(s->bytes.size());
  if (char_idx <= 0) return 0;
  if (s->enc == String::BINARY) return static_cast<std::size_t>(char_idx > n ? n : char_idx);
  std::size_t bo = 0;
  std::int64_t ci = 0;
  while (bo < s->bytes.size() && ci < char_idx) {
    bo++;
    while (bo < s->bytes.size() && (s->bytes[bo] & 0xC0) == 0x80) bo++;
    ci++;
  }
  return bo;
}

// `String#[](idx, len = :__unset__)` — substring extraction.
// Character-indexed for UTF-8 (byte-indexed for BINARY), matching MRI.
// Integer/Range/Regexp/String idx supported. Negative idx counts from
// end. Without len, a single character; with len, len characters from
// idx (clamped). Returns nil if idx out of range.
inline BasicObject* intrinsic_string_slice(BasicObject* self_, BasicObject* idx, BasicObject* len) {
  auto* _s = static_cast<String*>(self_);
  // Regexp idx: return the matched substring (or capture group via len).
  if (auto* _re = dynamic_cast<Regexp*>(idx)) {
    OnigRegion* _region = onig_region_new();
    const UChar* _p = _s->bytes.data();
    int _r = onig_search(_re->compiled_, _p, _p + _s->bytes.size(),
                         _p, _p + _s->bytes.size(),
                         _region, ONIG_OPTION_NONE);
    if (_r < 0) { onig_region_free(_region, 1); return nil_instance(); }
    int _grp = 0;
    if (len && len != intern("__unset__") && len != nil_instance()) {
      if (auto* _g = dynamic_cast<Integer*>(len)) _grp = static_cast<int>(_g->raw_);
    }
    if (_grp < 0 || _grp >= _region->num_regs ||
        _region->beg[_grp] < 0 || _region->end[_grp] < 0) {
      onig_region_free(_region, 1);
      return nil_instance();
    }
    auto* _out = new String();
    _out->bytes.assign(_p + _region->beg[_grp], _p + _region->end[_grp]);
    _out->enc = _s->enc;
    onig_region_free(_region, 1);
    return _out;
  }
  // Range idx: byte slice [begin, end) (or [begin, end] depending on
  // exclude_end_). Negative bounds count from end. Out-of-range begin
  // returns nil; out-of-range end clamps.
  if (auto* _rng = dynamic_cast<Range*>(idx)) {
    auto to_int = [](BasicObject* v, std::int64_t dflt) -> std::int64_t {
      if (!v || v == nil_instance()) return dflt;
      auto* _i = dynamic_cast<Integer*>(v);
      return _i ? _i->raw_ : dflt;
    };
    std::int64_t _clen = _s->length();
    std::int64_t _b = to_int(_rng->begin_, 0);
    std::int64_t _e = to_int(_rng->end_, _clen);
    if (_b < 0) _b += _clen;
    if (_e < 0) _e += _clen;
    if (_b < 0 || _b > _clen) return nil_instance();
    if (!_rng->exclude_end_) _e += 1;
    if (_e > _clen) _e = _clen;
    if (_e < _b) _e = _b;
    std::size_t _bb = str_char_to_byte(_s, _b);
    std::size_t _eb = str_char_to_byte(_s, _e);
    auto* _r2 = new String();
    _r2->bytes.assign(_s->bytes.begin() + _bb, _s->bytes.begin() + _eb);
    _r2->enc = _s->enc;
    return _r2;
  }
  // String idx: return idx if it's a substring of self, else nil.
  if (auto* _ss = dynamic_cast<String*>(idx)) {
    auto _it = std::search(_s->bytes.begin(), _s->bytes.end(),
                           _ss->bytes.begin(), _ss->bytes.end());
    if (_it == _s->bytes.end() && !_ss->bytes.empty()) return nil_instance();
    auto* _out = new String();
    _out->bytes = _ss->bytes;
    _out->enc = _ss->enc;
    return _out;
  }
  if (idx->m_class() != reinterpret_cast<BasicObject*>(&Integer_CLASS)) {
    std::fprintf(stderr, "[frozone-box-first] string_slice: non-Integer/Range/Regexp/String idx not yet supported (got %s)\n",
                 idx->ruby_class_name());
    std::abort();
  }
  std::int64_t _ix = static_cast<Integer*>(idx)->raw_;
  std::int64_t _clen = _s->length();
  if (_ix < 0) _ix += _clen;
  if (_ix < 0 || _ix > _clen) return nil_instance();
  if (len == intern("__unset__")) {
    if (_ix == _clen) return nil_instance();
    std::size_t _bs = str_char_to_byte(_s, _ix);
    std::size_t _be = str_char_to_byte(_s, _ix + 1);
    auto* _r = new String();
    _r->bytes.assign(_s->bytes.begin() + _bs, _s->bytes.begin() + _be);
    _r->enc = _s->enc;
    return _r;
  }
  std::int64_t _ln = static_cast<Integer*>(len)->raw_;
  if (_ln < 0) return nil_instance();
  std::int64_t _end_char = _ix + _ln;
  if (_end_char > _clen) _end_char = _clen;
  std::size_t _bs = str_char_to_byte(_s, _ix);
  std::size_t _be = str_char_to_byte(_s, _end_char);
  auto* _r = new String();
  _r->bytes.assign(_s->bytes.begin() + _bs, _s->bytes.begin() + _be);
  _r->enc = _s->enc;
  return _r;
}

// `String#split(sep, limit)` — separator: nil (whitespace), String,
// or Regexp (deferred). limit: :__unset__/nil → all, Integer → at
// most that many parts. nil sep collapses consecutive whitespace and
// trims; String sep does byte-find loop; Regexp sep aborts for now.
inline BasicObject* intrinsic_string_split(BasicObject* self_, BasicObject* sep, BasicObject* limit) {
  auto* _s = static_cast<String*>(self_);
  std::int64_t _hsize = static_cast<std::int64_t>(_s->bytes.size());
  std::int64_t _max = (limit == intern("__unset__") || limit == nil_instance())
                          ? -1
                          : static_cast<Integer*>(limit)->raw_;
  auto* _r = new Array();
  if (sep == nil_instance()) {
    std::int64_t _i = 0;
    while (_i < _hsize) {
      while (_i < _hsize && std::isspace(_s->bytes[_i])) _i++;
      if (_i >= _hsize) break;
      std::int64_t _start = _i;
      while (_i < _hsize && !std::isspace(_s->bytes[_i])) _i++;
      auto* _p = new String();
      _p->bytes.assign(_s->bytes.begin() + _start, _s->bytes.begin() + _i);
      _r->data.push_back(_p);
      if (_max > 0 && static_cast<std::int64_t>(_r->data.size()) >= _max - 1) {
        auto* _rest = new String();
        _rest->bytes.assign(_s->bytes.begin() + _i, _s->bytes.end());
        _r->data.push_back(_rest);
        return _r;
      }
    }
    return _r;
  }
  if (sep->m_class() != reinterpret_cast<BasicObject*>(&String_CLASS)) {
    std::fprintf(stderr, "[frozone-box-first] string_split: non-String/nil sep not yet supported\n");
    std::abort();
  }
  auto* _sep = static_cast<String*>(sep);
  std::int64_t _slen = static_cast<std::int64_t>(_sep->bytes.size());
  if (_slen == 0) {
    for (std::int64_t _i = 0; _i < _hsize; _i++) {
      auto* _p = new String();
      _p->bytes.push_back(_s->bytes[_i]);
      _r->data.push_back(_p);
    }
    return _r;
  }
  std::int64_t _start = 0;
  std::int64_t _i = 0;
  while (_i + _slen <= _hsize) {
    if (std::memcmp(&_s->bytes[_i], _sep->bytes.data(), _slen) == 0) {
      auto* _p = new String();
      _p->bytes.assign(_s->bytes.begin() + _start, _s->bytes.begin() + _i);
      _r->data.push_back(_p);
      _i += _slen;
      _start = _i;
      if (_max > 0 && static_cast<std::int64_t>(_r->data.size()) >= _max - 1) break;
    } else {
      _i++;
    }
  }
  auto* _last = new String();
  _last->bytes.assign(_s->bytes.begin() + _start, _s->bytes.end());
  _r->data.push_back(_last);
  return _r;
}

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
inline BasicObject* intrinsic_string_tr_raw(BasicObject* self_, BasicObject* from_, BasicObject* to_) {
  auto* _s = static_cast<String*>(self_);
  auto* _f = static_cast<String*>(from_);
  auto* _t = static_cast<String*>(to_);
  // Expand from-pattern (handle leading ^ and a-z ranges) to a byte set.
  bool negate = false;
  std::size_t fi = 0;
  if (!_f->bytes.empty() && _f->bytes[0] == '^') { negate = true; fi = 1; }
  std::vector<std::uint8_t> from_set;
  while (fi < _f->bytes.size()) {
    std::uint8_t b = _f->bytes[fi];
    if (fi + 2 < _f->bytes.size() && _f->bytes[fi + 1] == '-') {
      std::uint8_t hi = _f->bytes[fi + 2];
      if (b <= hi) { for (int c = b; c <= hi; ++c) from_set.push_back(static_cast<std::uint8_t>(c)); }
      fi += 3;
    } else { from_set.push_back(b); fi += 1; }
  }
  // Expand to-pattern (no negation, but ranges allowed) to a byte vector.
  std::vector<std::uint8_t> to_seq;
  std::size_t ti = 0;
  while (ti < _t->bytes.size()) {
    std::uint8_t b = _t->bytes[ti];
    if (ti + 2 < _t->bytes.size() && _t->bytes[ti + 1] == '-') {
      std::uint8_t hi = _t->bytes[ti + 2];
      if (b <= hi) { for (int c = b; c <= hi; ++c) to_seq.push_back(static_cast<std::uint8_t>(c)); }
      ti += 3;
    } else { to_seq.push_back(b); ti += 1; }
  }
  auto* _r = new String();
  _r->enc = _s->enc;
  _r->bytes.reserve(_s->bytes.size());
  for (auto b : _s->bytes) {
    bool match;
    std::int64_t idx = -1;
    if (negate) {
      match = true;
      for (auto fb : from_set) if (b == fb) { match = false; break; }
    } else {
      match = false;
      for (std::size_t i = 0; i < from_set.size(); ++i) {
        if (from_set[i] == b) { match = true; idx = static_cast<std::int64_t>(i); break; }
      }
    }
    if (!match) { _r->bytes.push_back(b); continue; }
    if (to_seq.empty()) continue;  // delete
    std::uint8_t mapped;
    if (negate || idx < 0 || idx >= static_cast<std::int64_t>(to_seq.size())) {
      mapped = to_seq.back();
    } else {
      mapped = to_seq[idx];
    }
    _r->bytes.push_back(mapped);
  }
  return _r;
}

// `String#initialize(str, encoding)` — copy bytes from `str` into
// self. The third arg (encoding) is handled by a separate
// `force_encoding` call right after in lib/core/4.0/string.rb#L26,
// so we ignore it here. Returns nil (intrinsic contract; the Ruby
// wrapper returns self).
inline BasicObject* intrinsic_string_initialize(BasicObject* self_, BasicObject* str_, BasicObject* /*encoding_*/) {
  auto* _s = static_cast<String*>(self_);
  auto* _o = static_cast<String*>(str_);
  _s->bytes = _o->bytes;
  _s->enc = _o->enc;
  _s->length_cache_ = -1;
  return nil_instance();
}

// `String#replace(other)` — overwrite self's bytes/encoding with
// other's, return self. Mutates self in place; both String#replace
// (lib/core/4.0/string.rb:58) and the __bang__ wrapper used by tr! /
// upcase! / downcase! lower to this single intrinsic.
inline BasicObject* intrinsic_string_replace(BasicObject* self_, BasicObject* other_) {
  auto* _s = static_cast<String*>(self_);
  auto* _o = static_cast<String*>(other_);
  _s->bytes = _o->bytes;
  _s->enc = _o->enc;
  _s->length_cache_ = -1;
  return _s;
}

inline BasicObject* intrinsic_string_chars(BasicObject* self_) {
  auto* _s = static_cast<String*>(self_);
  auto* _r = new Array();
  _r->data.reserve(_s->bytes.size());
  for (auto _b : _s->bytes) {
    auto* _c = new String();
    _c->bytes.push_back(_b);
    _r->data.push_back(_c);
  }
  return _r;
}

// `String#inspect` — quoted with C-style escapes for non-printable
// bytes. Mirrors cpp_string_literal: \n, \r, \t, \\, \", \NNN.
inline BasicObject* intrinsic_string_inspect(BasicObject* self_) {
  auto* _s = static_cast<String*>(self_);
  std::string _buf;
  _buf.reserve(_s->bytes.size() + 2);
  _buf.push_back('"');
  for (auto _b : _s->bytes) {
    switch (_b) {
      case 0x22: _buf += "\\\""; break;
      case 0x5C: _buf += "\\\\"; break;
      case 0x0A: _buf += "\\n";  break;
      case 0x0D: _buf += "\\r";  break;
      case 0x09: _buf += "\\t";  break;
      case 0x00: _buf += "\\0";  break;
      default:
        if (_b >= 0x20 && _b <= 0x7E) {
          _buf.push_back(static_cast<char>(_b));
        } else {
          char _tmp[5];
          std::snprintf(_tmp, sizeof(_tmp), "\\%03o", _b);
          _buf += _tmp;
        }
    }
  }
  _buf.push_back('"');
  return new String(_buf.data(), _buf.size());
}

// `String#%(args)` / `Kernel#format(self, args)` / `sprintf` — minimal
// impl covering only the patterns the WQ parser uses today:
//   %{key}    — Hash-keyed substitution (parser's :error template style)
//   %s        — to_s of next positional arg (Array)
//   %d        — to_s of next Integer positional arg
//   %%        — literal '%'
// Anything else passes through unchanged + a stderr warning. Widen
// when a real test case demands more (precision/width/flags etc.).
inline BasicObject* intrinsic_string_format(BasicObject* self_, BasicObject* args) {
  auto* _tmpl = static_cast<String*>(self_);
  auto* _hash = (args->m_class() == reinterpret_cast<BasicObject*>(&Hash_CLASS))
                    ? static_cast<Hash*>(args) : nullptr;
  auto* _arr  = (args->m_class() == reinterpret_cast<BasicObject*>(&Array_CLASS))
                    ? static_cast<Array*>(args) : nullptr;
  std::string _out;
  _out.reserve(_tmpl->bytes.size());
  std::size_t _pos_idx = 0;
  std::size_t i = 0;
  auto append_to_s = [&](BasicObject* v) {
    auto* _s = v->m_to_s();
    if (_s->m_class() == reinterpret_cast<BasicObject*>(&String_CLASS)) {
      auto* _ss = static_cast<String*>(_s);
      _out.append(reinterpret_cast<const char*>(_ss->bytes.data()), _ss->bytes.size());
    }
  };
  while (i < _tmpl->bytes.size()) {
    if (_tmpl->bytes[i] != '%' || i + 1 >= _tmpl->bytes.size()) {
      _out.push_back(static_cast<char>(_tmpl->bytes[i]));
      i++;
      continue;
    }
    auto next = _tmpl->bytes[i + 1];
    if (next == '{') {
      std::size_t end = _tmpl->bytes.size();
      for (std::size_t j = i + 2; j < _tmpl->bytes.size(); j++) {
        if (_tmpl->bytes[j] == '}') { end = j; break; }
      }
      if (end < _tmpl->bytes.size()) {
        std::string _key(reinterpret_cast<const char*>(&_tmpl->bytes[i + 2]), end - (i + 2));
        if (_hash) {
          auto _it = _hash->data.find(intern(_key.c_str()));
          if (_it != _hash->data.end()) append_to_s(_it->second);
        }
        i = end + 1;
        continue;
      }
    }
    if (next == '%') { _out.push_back('%'); i += 2; continue; }
    if (next == 's' || next == 'd') {
      if (_arr && _pos_idx < _arr->data.size()) {
        append_to_s(_arr->data[_pos_idx++]);
      } else if (!_arr) {
        // single non-Array arg → bind to first %s/%d
        if (_pos_idx == 0) { append_to_s(args); _pos_idx++; }
      }
      i += 2;
      continue;
    }
    // Unrecognised — pass through verbatim.
    _out.push_back('%');
    _out.push_back(static_cast<char>(next));
    i += 2;
  }
  return new String(_out.data(), _out.size());
}

// `String#hash` — FNV-1a 64-bit over bytes. Identity-stable for the
// process lifetime; close enough for Hash key behaviour.
inline BasicObject* intrinsic_string_hash(BasicObject* self_) {
  auto* _s = static_cast<String*>(self_);
  std::uint64_t _h = 0xcbf29ce484222325ULL;
  for (auto _b : _s->bytes) {
    _h ^= _b;
    _h *= 0x100000001b3ULL;
  }
  return new Integer(static_cast<std::int64_t>(_h));
}

// ---- Array ---------------------------------------------------------

// `Array#to_s` / `Array#inspect` — `[a, b, c]` form. Calls m_inspect
// on each element. `[]` for empty.
inline BasicObject* intrinsic_array_to_s(BasicObject* self_) {
  auto* _a = static_cast<Array*>(self_);
  std::string _buf;
  _buf.push_back('[');
  for (std::size_t _i = 0; _i < _a->data.size(); _i++) {
    if (_i) _buf += ", ";
    auto* _ins = _a->data[_i]->m_inspect();
    if (_ins && _ins->m_class() == reinterpret_cast<BasicObject*>(&String_CLASS)) {
      auto* _str = static_cast<String*>(_ins);
      _buf.append(reinterpret_cast<const char*>(_str->bytes.data()), _str->bytes.size());
    }
  }
  _buf.push_back(']');
  return new String(_buf.data(), _buf.size());
}

// `String#match(pattern)` — same as Regexp#match with self/str swapped.
inline BasicObject* intrinsic_string_match(BasicObject* self_, BasicObject* pat) {
  auto* _md = regexp_match_helper(pat, self_, 0);
  return _md ? static_cast<BasicObject*>(_md) : nil_instance();
}

// `String#match(pattern, pos)`.
inline BasicObject* intrinsic_string_match_pos(BasicObject* self_, BasicObject* pat, BasicObject* pos) {
  auto* _md = regexp_match_helper(pat, self_, static_cast<Integer*>(pos)->raw_);
  return _md ? static_cast<BasicObject*>(_md) : nil_instance();
}

// ---- Symbol --------------------------------------------------------

// `Symbol#to_s` — Symbol::name_ is a const char* set by intern();
// wrap into a fresh String.
inline BasicObject* intrinsic_symbol_to_s(BasicObject* self_) {
  const char* _n = static_cast<Symbol*>(self_)->name_;
  return new String(_n, std::strlen(_n));
}

// `Symbol#inspect` — `:foo`. Prepends a colon, builds a String.
// Doesn't quote names with special characters yet (`:"foo bar"`);
// good enough for normal identifiers.
inline BasicObject* intrinsic_symbol_inspect(BasicObject* self_) {
  const char* _n = static_cast<Symbol*>(self_)->name_;
  std::size_t _len = std::strlen(_n);
  auto* _r = new String();
  _r->bytes.reserve(_len + 1);
  _r->bytes.push_back(':');
  for (std::size_t _i = 0; _i < _len; ++_i) {
    _r->bytes.push_back(static_cast<std::uint8_t>(_n[_i]));
  }
  return _r;
}

// ---- String (cont.) ------------------------------------------------

// `String#to_sym` — interns the byte-buffer as a Symbol. intern()
// requires NUL-terminated; copy into a std::string for the lookup.
inline BasicObject* intrinsic_string_to_sym(BasicObject* self_) {
  auto* _s = static_cast<String*>(self_);
  std::string _buf(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  return intern(_buf.c_str());
}

// `String#to_i(base)` — std::strtoll on the byte buffer. Empty /
// non-numeric prefix returns 0 (matches MRI). Stub: doesn't handle
// 0x/0b/0o prefixes for base==0; widen as needed.
inline BasicObject* intrinsic_string_to_i_base(BasicObject* self_, BasicObject* base) {
  auto* _s = static_cast<String*>(self_);
  if (_s->bytes.empty()) return new Integer(0);
  std::string _buf(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  int _b = static_cast<int>(static_cast<Integer*>(base)->raw_);
  char* _end = nullptr;
  long long _v = std::strtoll(_buf.c_str(), &_end, _b);
  return new Integer(static_cast<std::int64_t>(_v));
}

// ---- String (Tier-B continuation) ----------------------------------
//
// Box-first carries no `frozen_` bit on String yet, so freeze/frozen
// preserve method-chaining shape but don't actually track freezing —
// matches the behaviour of `chilled?` (always false). Real freeze
// tracking is a follow-up; the gap is captured in
// project_string_encoding_specialization.md / object_id_parity.md
// neighbourhood as another mutability nuance.
//
// All intrinsics here cast via static_cast<String*> on String args
// — the Ruby wrappers in lib/core/4.0/string.rb run __coerce_to_str__
// upstream (or the call site is `v.is_a?(String) ? Intrinsics.X(self, v)`
// guarded), so by the intrinsic boundary the args are guaranteed
// String. Where Integer args are accepted (offsets, codepoints), the
// same guarantee holds via __coerce_to_int__.

inline BasicObject* intrinsic_string_freeze(BasicObject* self_) {
  // No frozen_ bit yet; preserve `s.freeze.length` chain shape.
  return self_;
}
inline BasicObject* intrinsic_string_frozen(BasicObject* /*self_*/) {
  return false_instance();
}

inline BasicObject* intrinsic_string_dup(BasicObject* self_) {
  auto* s = static_cast<String*>(self_);
  auto* r = new String();
  r->bytes = s->bytes;
  r->enc = s->enc;
  return r;
}
inline BasicObject* intrinsic_string_clone(BasicObject* self_, BasicObject* /*freeze*/) {
  // freeze: nil/true/false — we don't track frozen state, so just dup.
  return intrinsic_string_dup(self_);
}

inline BasicObject* intrinsic_string_eql(BasicObject* self_, BasicObject* other) {
  auto* a = static_cast<String*>(self_);
  auto* b = static_cast<String*>(other);
  if (a->bytes.size() != b->bytes.size()) return false_instance();
  return boxed_bool(a->enc == b->enc &&
                    std::memcmp(a->bytes.data(), b->bytes.data(), a->bytes.size()) == 0);
}

inline BasicObject* intrinsic_string_concat(BasicObject* self_, BasicObject* other) {
  auto* s = static_cast<String*>(self_);
  auto* o = static_cast<String*>(other);
  s->bytes.insert(s->bytes.end(), o->bytes.begin(), o->bytes.end());
  s->length_cache_ = -1;
  return s;
}

inline BasicObject* intrinsic_string_concat_codepoint(BasicObject* self_, BasicObject* cp) {
  // cp is an Integer codepoint — encode as UTF-8 onto self.
  auto* s = static_cast<String*>(self_);
  int64_t c = static_cast<Integer*>(cp)->raw_;
  if (c < 0x80) {
    s->bytes.push_back(static_cast<uint8_t>(c));
  } else if (c < 0x800) {
    s->bytes.push_back(static_cast<uint8_t>(0xC0 | (c >> 6)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | (c & 0x3F)));
  } else if (c < 0x10000) {
    s->bytes.push_back(static_cast<uint8_t>(0xE0 | (c >> 12)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | ((c >> 6) & 0x3F)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | (c & 0x3F)));
  } else if (c < 0x110000) {
    s->bytes.push_back(static_cast<uint8_t>(0xF0 | (c >> 18)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | ((c >> 12) & 0x3F)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | ((c >> 6) & 0x3F)));
    s->bytes.push_back(static_cast<uint8_t>(0x80 | (c & 0x3F)));
  } else {
    std::fprintf(stderr, "[box-first] string_concat_codepoint: U+%llX out of range\n",
                 static_cast<long long>(c));
    std::abort();
  }
  s->length_cache_ = -1;
  return s;
}

inline BasicObject* intrinsic_string_dedup(BasicObject* self_) {
  // No string interning yet — `-"foo"` returns self. MRI dedups
  // frozen string literals; box-first can layer this on later.
  return self_;
}

inline BasicObject* intrinsic_string_byteindex(BasicObject* self_, BasicObject* sub, BasicObject* offset = nullptr) {
  auto* s = static_cast<String*>(self_);
  auto* p = static_cast<String*>(sub);
  int64_t off = 0;
  if (offset && offset != nil_instance() && offset != intern("__unset__")) {
    off = static_cast<Integer*>(offset)->raw_;
  }
  int64_t hsize = static_cast<int64_t>(s->bytes.size());
  if (off < 0) off = std::max<int64_t>(0, hsize + off);
  if (off > hsize) return nil_instance();
  if (p->bytes.empty()) return new Integer(off);
  for (int64_t i = off; i + static_cast<int64_t>(p->bytes.size()) <= hsize; ++i) {
    if (std::memcmp(s->bytes.data() + i, p->bytes.data(), p->bytes.size()) == 0) {
      return new Integer(i);
    }
  }
  return nil_instance();
}

inline BasicObject* intrinsic_string_byterindex(BasicObject* self_, BasicObject* sub, BasicObject* offset = nullptr) {
  auto* s = static_cast<String*>(self_);
  auto* p = static_cast<String*>(sub);
  int64_t hsize = static_cast<int64_t>(s->bytes.size());
  int64_t psize = static_cast<int64_t>(p->bytes.size());
  int64_t end_pos = hsize;
  if (offset && offset != nil_instance() && offset != intern("__unset__")) {
    end_pos = static_cast<Integer*>(offset)->raw_;
    if (end_pos < 0) end_pos += hsize;
  }
  if (end_pos > hsize - psize) end_pos = hsize - psize;
  if (psize == 0) return new Integer(end_pos < 0 ? 0 : end_pos);
  for (int64_t i = end_pos; i >= 0; --i) {
    if (std::memcmp(s->bytes.data() + i, p->bytes.data(), psize) == 0) {
      return new Integer(i);
    }
  }
  return nil_instance();
}

inline BasicObject* intrinsic_string_byteslice(BasicObject* self_, BasicObject* idx, BasicObject* len) {
  auto* s = static_cast<String*>(self_);
  int64_t hsize = static_cast<int64_t>(s->bytes.size());
  int64_t i = static_cast<Integer*>(idx)->raw_;
  if (i < 0) i += hsize;
  if (i < 0 || i > hsize) return nil_instance();
  int64_t n = (len == nil_instance()) ? 1 : static_cast<Integer*>(len)->raw_;
  if (n < 0) return nil_instance();
  if (i + n > hsize) n = hsize - i;
  return new String(reinterpret_cast<const char*>(s->bytes.data() + i), static_cast<std::size_t>(n));
}

inline BasicObject* intrinsic_string_ord(BasicObject* self_) {
  auto* s = static_cast<String*>(self_);
  if (s->bytes.empty()) {
    std::fprintf(stderr, "[box-first] String#ord: empty string\n");
    std::abort();
  }
  // Decode first UTF-8 codepoint (BINARY → first byte).
  uint8_t b = s->bytes[0];
  if (s->enc == String::BINARY || b < 0x80) return new Integer(b);
  int n = (b < 0xC0) ? 1 : (b < 0xE0) ? 2 : (b < 0xF0) ? 3 : 4;
  int64_t cp = b & ((1 << (7 - n)) - 1);
  for (int j = 1; j < n && j < static_cast<int>(s->bytes.size()); ++j) {
    cp = (cp << 6) | (s->bytes[j] & 0x3F);
  }
  return new Integer(cp);
}

inline BasicObject* intrinsic_string_oct(BasicObject* self_) {
  // Ruby `oct` parses octal by default but also recognises 0x/0b/0o
  // prefixes — actually returns 0 if the prefix doesn't match the
  // implied base. Use strtoll with base=0 (auto-detect) but default
  // to octal when no prefix.
  auto* s = static_cast<String*>(self_);
  std::string str(reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
  // Skip leading whitespace.
  std::size_t i = 0;
  while (i < str.size() && std::isspace(static_cast<unsigned char>(str[i]))) ++i;
  if (i >= str.size()) return new Integer(0);
  std::string sub = str.substr(i);
  // Default to octal — prefix the digits with 0 if no prefix present.
  bool has_prefix = sub.size() >= 2 &&
                    (sub[0] == '0' && (sub[1] == 'x' || sub[1] == 'X' ||
                                       sub[1] == 'b' || sub[1] == 'B' ||
                                       sub[1] == 'o' || sub[1] == 'O' ||
                                       sub[1] == 'd' || sub[1] == 'D'));
  int base = has_prefix ? 0 : 8;
  if (!has_prefix && (sub[0] == '+' || sub[0] == '-')) {
    if (sub.size() >= 3 &&
        (sub[1] == 'x' || sub[1] == 'X' || sub[1] == 'b' || sub[1] == 'B' || sub[1] == 'o' || sub[1] == 'O')) {
      base = 0;
      // Need to handle e.g. "+0x10" — but strtoll accepts "+0x10" with base=0.
    }
  }
  char* endp = nullptr;
  long long v = std::strtoll(sub.c_str(), &endp, base);
  return new Integer(v);
}

inline BasicObject* intrinsic_string_rindex(BasicObject* self_, BasicObject* sub, BasicObject* offset) {
  // Reuse byterindex semantics; rindex is essentially the same for
  // ASCII and BINARY, and "good enough" for UTF-8 in practice
  // (codepoint vs byte position divergence is the soundness gap).
  return intrinsic_string_byterindex(self_, sub, offset);
}

inline BasicObject* intrinsic_string_each_line(BasicObject* self_, BasicObject* sep, BasicObject* /*limit*/) {
  // Returns Array<String>. The Ruby wrapper does the block.call iteration;
  // the intrinsic just produces the line array.
  auto* s = static_cast<String*>(self_);
  std::string sep_str = (sep == nil_instance()) ? std::string("\n") : fs_detail::str_of(sep);
  Array* arr = new Array();
  if (sep_str.empty()) {
    // Paragraph mode (sep="") splits on \n\n+; defer to simple newline
    // for now — uncommon in self-host frozone code.
    sep_str = "\n";
  }
  std::string buf(reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
  std::size_t pos = 0;
  while (pos < buf.size()) {
    std::size_t hit = buf.find(sep_str, pos);
    if (hit == std::string::npos) {
      arr->data.push_back(fs_detail::string_of(buf.substr(pos)));
      break;
    }
    std::size_t end = hit + sep_str.size();
    arr->data.push_back(fs_detail::string_of(buf.substr(pos, end - pos)));
    pos = end;
  }
  return arr;
}

inline BasicObject* intrinsic_string_dump(BasicObject* self_) {
  // Dump format mirrors inspect but escapes ALL non-ASCII as \xNN
  // (no UTF-8 passthrough) and ensures the output is round-trippable
  // via undump. We share the inspect helper's escaping with the
  // tighter "non-ASCII → \xNN" rule here.
  auto* s = static_cast<String*>(self_);
  std::string out;
  out.reserve(s->bytes.size() + 2);
  out.push_back('"');
  for (auto b : s->bytes) {
    switch (b) {
      case '"':  out.append("\\\""); break;
      case '\\': out.append("\\\\"); break;
      case '\n': out.append("\\n");  break;
      case '\r': out.append("\\r");  break;
      case '\t': out.append("\\t");  break;
      case '\0': out.append("\\0");  break;
      default:
        if (b >= 0x20 && b < 0x7F) {
          out.push_back(static_cast<char>(b));
        } else {
          char buf[5];
          std::snprintf(buf, sizeof(buf), "\\x%02X", b);
          out.append(buf);
        }
    }
  }
  out.push_back('"');
  return new String(out.data(), out.size());
}

inline BasicObject* intrinsic_string_grapheme_clusters(BasicObject* self_) {
  // True grapheme cluster boundaries need a Unicode database (UAX #29).
  // Approximate as codepoints — correct for ASCII and most common
  // text; wrong for combining marks, emoji ZWJ sequences, etc. Track
  // as soundness gap in MRI parity index when self-host hits a real
  // grapheme-aware case.
  auto* s = static_cast<String*>(self_);
  Array* arr = new Array();
  std::size_t i = 0;
  while (i < s->bytes.size()) {
    uint8_t b = s->bytes[i];
    int n = (b < 0x80) ? 1 : (b < 0xC0) ? 1 : (b < 0xE0) ? 2 : (b < 0xF0) ? 3 : 4;
    if (i + n > s->bytes.size()) n = static_cast<int>(s->bytes.size() - i);
    arr->data.push_back(new String(reinterpret_cast<const char*>(s->bytes.data() + i), static_cast<std::size_t>(n)));
    i += n;
  }
  return arr;
}

inline BasicObject* intrinsic_string_slice_bang(BasicObject* self_, BasicObject* idx, BasicObject* len) {
  // Destructive slice — extract substring and remove it from self.
  auto* s = static_cast<String*>(self_);
  int64_t hsize = static_cast<int64_t>(s->bytes.size());
  int64_t i = static_cast<Integer*>(idx)->raw_;
  if (i < 0) i += hsize;
  if (i < 0 || i > hsize) return nil_instance();
  int64_t n = (len == nil_instance() || len == intern("__unset__"))
                 ? 1 : static_cast<Integer*>(len)->raw_;
  if (n < 0) return nil_instance();
  if (i + n > hsize) n = hsize - i;
  String* out = new String(reinterpret_cast<const char*>(s->bytes.data() + i), static_cast<std::size_t>(n));
  s->bytes.erase(s->bytes.begin() + i, s->bytes.begin() + i + n);
  s->length_cache_ = -1;
  return out;
}

// Aborts for genuinely complex Tier-B cases — these have non-trivial
// semantics (Unicode tables, Complex parser, format-string parser)
// that nothing in self-host frozone exercises. Each gets a loud
// message naming the unsupported intrinsic.
inline BasicObject* intrinsic_string_tr_s(BasicObject* /*s*/, BasicObject* /*from*/, BasicObject* /*to*/) {
  std::fprintf(stderr, "[box-first] string_tr_s not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_unpack1(BasicObject* /*s*/, BasicObject* /*fmt*/, BasicObject* /*offset*/) {
  std::fprintf(stderr, "[box-first] string_unpack1 not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_undump(BasicObject* /*s*/) {
  std::fprintf(stderr, "[box-first] string_undump not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_crypt(BasicObject* /*s*/, BasicObject* /*salt*/) {
  std::fprintf(stderr, "[box-first] string_crypt not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_scrub(BasicObject* /*s*/, BasicObject* /*replacement*/, BasicObject* /*block*/) {
  std::fprintf(stderr, "[box-first] string_scrub not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_unicode_normalize(BasicObject* /*s*/, BasicObject* /*form*/) {
  std::fprintf(stderr, "[box-first] string_unicode_normalize not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_unicode_normalized_q(BasicObject* /*s*/, BasicObject* /*form*/) {
  std::fprintf(stderr, "[box-first] string_unicode_normalized? not yet supported\n"); std::abort();
}
inline BasicObject* intrinsic_string_to_c(BasicObject* /*s*/) {
  // Complex construction not yet wired up — same gap as Integer#to_c.
  throw_not_implemented("String#to_c not yet supported in box-first (Complex class not wired up)");
}
inline BasicObject* intrinsic_string_upto(BasicObject* /*s*/, BasicObject* /*end*/, BasicObject* /*excl*/, BasicObject* /*block*/) {
  std::fprintf(stderr, "[box-first] string_upto not yet supported\n"); std::abort();
}
#endif  // FROZONE_STRING_INTRINSICS_HPP

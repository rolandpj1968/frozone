// Box-first Intrinsics implementations.
//
// `Intrinsics.foo(self, args...)` calls in lib/core/4.0/ Ruby code
// lower to inline C++ calls into this header. Each `Intrinsics.X`
// has a corresponding `Ruby::intrinsic_X(...)` inline function here.
//
// Moved out of intrinsic_lowering.rb's string-emitting Ruby lambdas
// for readability and source-size: each intrinsic body lives ONCE
// here (the optimiser inlines as it sees fit), instead of being
// duplicated at every call site as a self-invoking lambda
// expression. Real C++ syntax — editor highlighting, type checking,
// gdb sees real function names.
//
// Forward-declares with full type signatures — must be included
// AFTER the per-program class structs are complete (String*, Array*,
// etc. are referenced via member access). The emitter inserts the
// include between class definitions and method bodies (see
// class_emitter.rb's write_runtime).
//
// Naming: `intrinsic_<ruby_name>` to keep distinct from runtime
// helpers (intern, splat_to_array, ...) which use bare names.
//
// Closure-style intrinsics (kernel_lambda, kernel_proc,
// kernel_block_given) that reference `_block` in the surrounding
// method's scope STAY in intrinsic_lowering.rb — they aren't pure
// functions of their args.

// NB: This header is `#include`'d INSIDE the gen file's
// `namespace Ruby { ... }` block (see class_emitter.rb), so the
// declarations below land directly in namespace Ruby. Do NOT add a
// `namespace Ruby { ... }` wrapper here — it would create
// `Ruby::Ruby::intrinsic_X` and break callers.

#ifndef FROZONE_INTRINSICS_HPP
#define FROZONE_INTRINSICS_HPP

// ---- String --------------------------------------------------------

// `String#index(sub, offset = :__unset__)` — find first byte-position
// of sub in self. String sub uses byte memcmp; Regexp sub goes through
// onig_search via regexp_match_helper. Negative offset counts from
// end; offset > size returns nil. Empty needle matches at offset.
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

// `String#[](idx, len = :__unset__)` — substring extraction. Integer
// idx only for now (Range/Regexp idx unsupported). Negative idx
// counts from end. Without len, single byte (as 1-char String). With
// len, len bytes from idx (clamped to remaining). Returns nil if idx
// out of range.
inline BasicObject* intrinsic_string_slice(BasicObject* self_, BasicObject* idx, BasicObject* len) {
  auto* _s = static_cast<String*>(self_);
  std::int64_t _size = static_cast<std::int64_t>(_s->bytes.size());
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
    std::int64_t _b = to_int(_rng->begin_, 0);
    std::int64_t _e = to_int(_rng->end_, _size);
    if (_b < 0) _b += _size;
    if (_e < 0) _e += _size;
    if (_b < 0 || _b > _size) return nil_instance();
    if (!_rng->exclude_end_) _e += 1;
    if (_e > _size) _e = _size;
    if (_e < _b) _e = _b;
    auto* _r2 = new String();
    _r2->bytes.assign(_s->bytes.begin() + _b, _s->bytes.begin() + _e);
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
  if (_ix < 0) _ix += _size;
  if (_ix < 0 || _ix > _size) return nil_instance();
  if (len == intern("__unset__")) {
    if (_ix == _size) return nil_instance();
    auto* _r = new String();
    _r->bytes.push_back(_s->bytes[_ix]);
    return _r;
  }
  std::int64_t _ln = static_cast<Integer*>(len)->raw_;
  if (_ln < 0) return nil_instance();
  std::int64_t _avail = std::min(_ln, _size - _ix);
  auto* _r = new String();
  _r->bytes.reserve(_avail);
  for (std::int64_t _k = 0; _k < _avail; _k++) {
    _r->bytes.push_back(_s->bytes[_ix + _k]);
  }
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

// ---- Regexp --------------------------------------------------------

// `Regexp.escape(str)` — backslash-escape regex metacharacters so the
// result matches the input as a literal pattern.
inline BasicObject* intrinsic_regexp_escape(BasicObject* str) {
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

// ---- Hash ----------------------------------------------------------

// `Hash#each { |k, v| ... }` — iterate, calling block with [k, v]
// Array. Returns self. The 2-element Array argument enables `|k, v|`
// destructuring at the block-arg unpacking site.
inline BasicObject* intrinsic_hash_each(BasicObject* self_, BasicObject* block) {
  auto* _h = static_cast<Hash*>(self_);
  auto* _b = static_cast<Proc*>(block);
  for (auto& _kv : _h->data) {
    _b->m_call(new Array({_kv.first, _kv.second}));
  }
  return _h;
}

// `Hash#delete(key)` — remove and return value, or nil if key absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
inline BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key) {
  auto* _h = static_cast<Hash*>(self_);
  auto _it = _h->data.find(key);
  if (_it == _h->data.end()) return nil_instance();
  BasicObject* _v = _it->second;
  _h->data.erase(_it);
  return _v;
}

// `Hash#compare_by_identity` (setter) — switch to pointer-identity
// keys + pointer-hash. The Hasher/KeyEq functors hold a pointer to
// compare_by_identity_; flipping it + rehash(0) redistributes
// existing entries under the new mode. Per MRI: previously-collapsed
// duplicate keys (value-equal but distinct pointers) STAY collapsed.
// Returns self.
inline BasicObject* intrinsic_hash_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  _h->compare_by_identity_ = true;
  _h->data.rehash(0);
  return _h;
}

// `Hash#compare_by_identity?` — true iff the hash is in identity mode.
inline BasicObject* intrinsic_hash_compare_by_identity_q(BasicObject* self_) {
  return boxed_bool(static_cast<Hash*>(self_)->compare_by_identity_);
}

// Reset compare_by_identity flag (used by Hash#replace before copying
// the source hash's mode). MRI doesn't expose a public setter that
// flips the mode back; this is for our Ruby-side replace impl only.
inline BasicObject* intrinsic_hash_reset_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  if (_h->compare_by_identity_) {
    _h->compare_by_identity_ = false;
    _h->data.rehash(0);
  }
  return _h;
}

// Hash default value / default proc — MRI exclusivity: setting one
// clears the other. Setters handle that; getters are direct reads.

inline BasicObject* intrinsic_hash_get_default(BasicObject* self_, BasicObject* /*key*/) {
  // MRI Hash#default(key) ignores key when no default_proc; returns
  // the default value. Used by core/4.0/hash.rb's `[]` lookup miss
  // path (already nil-default unless setter ran).
  return static_cast<Hash*>(self_)->default_value_;
}

inline BasicObject* intrinsic_hash_set_default(BasicObject* self_, BasicObject* val) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_value_ = val;
  _h->default_proc_ = nil_instance();
  return val;
}

inline BasicObject* intrinsic_hash_get_default_proc(BasicObject* self_) {
  return static_cast<Hash*>(self_)->default_proc_;
}

inline BasicObject* intrinsic_hash_set_default_proc(BasicObject* self_, BasicObject* prc) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_proc_ = prc;
  _h->default_value_ = nil_instance();
  return prc;
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

// ---- Integer -------------------------------------------------------

// `Integer#chr(enc = nil)` — single-byte String. 0..255 only.
// Encoding ignored (we treat as raw bytes).
inline BasicObject* intrinsic_integer_chr(BasicObject* self_, BasicObject* /*enc*/) {
  std::int64_t _v = static_cast<Integer*>(self_)->raw_;
  auto* _r = new String();
  if (_v < 0 || _v > 0x10FFFF) {
    // Out of Unicode range — emit replacement char (wraps to byte for now).
    _r->bytes.push_back(static_cast<std::uint8_t>('?'));
    return _r;
  }
  if (_v <= 0x7F) {
    _r->bytes.push_back(static_cast<std::uint8_t>(_v));
  } else if (_v <= 0x7FF) {
    _r->bytes.push_back(static_cast<std::uint8_t>(0xC0 | (_v >> 6)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | (_v & 0x3F)));
  } else if (_v <= 0xFFFF) {
    _r->bytes.push_back(static_cast<std::uint8_t>(0xE0 | (_v >> 12)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | ((_v >> 6) & 0x3F)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | (_v & 0x3F)));
  } else {
    _r->bytes.push_back(static_cast<std::uint8_t>(0xF0 | (_v >> 18)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | ((_v >> 12) & 0x3F)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | ((_v >> 6) & 0x3F)));
    _r->bytes.push_back(static_cast<std::uint8_t>(0x80 | (_v & 0x3F)));
  }
  return _r;
}

// `Integer#bit_length` — bits needed to represent value (excl. sign).
// Negative numbers: bits in ~n. __builtin_clzll gives leading zeros;
// bit_length = 64 - clz.
inline BasicObject* intrinsic_integer_bit_length(BasicObject* self_) {
  std::int64_t _v = static_cast<Integer*>(self_)->raw_;
  std::uint64_t _u = (_v < 0) ? static_cast<std::uint64_t>(~_v) : static_cast<std::uint64_t>(_v);
  if (_u == 0) return new Integer(0);
  return new Integer(64 - __builtin_clzll(_u));
}

// ---- Regexp / MatchData --------------------------------------------

// `re.inspect` — `/source/`. Options stripped for now (full MRI form
// `(?-mix:...)` is a follow-up).
inline BasicObject* intrinsic_regexp_inspect(BasicObject* self_) {
  auto* _r = static_cast<Regexp*>(self_);
  auto* _s = static_cast<String*>(_r->source_);
  std::string _buf;
  _buf.reserve(_s->bytes.size() + 2);
  _buf.push_back('/');
  _buf.append(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  _buf.push_back('/');
  return new String(_buf.data(), _buf.size());
}

// `re.to_s` — same as inspect for now.
inline BasicObject* intrinsic_regexp_to_s(BasicObject* self_) {
  return intrinsic_regexp_inspect(self_);
}

// `Regexp.new(pattern, options, kw_opts)` — class arg comes first
// (eigenclass-side intrinsic), pattern is String, options is Integer
// or nil, kw_opts ignored.
inline BasicObject* intrinsic_regexp_new(BasicObject* /*klass*/, BasicObject* pat, BasicObject* opts, BasicObject* /*kw*/) {
  auto* _re = new Regexp();
  auto* _a = new Array({
      pat,
      (opts == nil_instance() ? static_cast<BasicObject*>(new Integer(0)) : opts),
  });
  _re->m_initialize(_a, nullptr, nullptr);
  return _re;
}

// `re =~ str` — Integer byte-offset of first match, or nil. Sets $~.
inline BasicObject* intrinsic_regexp_match_index(BasicObject* self_, BasicObject* str) {
  auto* _md = regexp_match_helper(self_, str, 0);
  return _md ? static_cast<BasicObject*>(new Integer(_md->captures_[0].first)) : nil_instance();
}

// `re.match(str, pos)` — MatchData or nil. Sets $~.
inline BasicObject* intrinsic_regexp_match(BasicObject* self_, BasicObject* str, BasicObject* pos) {
  auto* _md = regexp_match_helper(self_, str, static_cast<Integer*>(pos)->raw_);
  return _md ? static_cast<BasicObject*>(_md) : nil_instance();
}

// `Regexp.last_match` / `Regexp.last_match(n)` — read $~ or capture n.
// nil arg → return $~ itself; Integer arg → return capture n.
inline BasicObject* intrinsic_regexp_last_match(BasicObject* n) {
  BasicObject* _md = g_last_match();
  if (n == nil_instance() || n == nullptr) return _md;
  if (_md == nullptr || _md == nil_instance()) return nil_instance();
  return matchdata_cap(_md, static_cast<Integer*>(n)->raw_);
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

// `MatchData#to_a` — Array of all captures (including capture 0 = full
// match). Each capture is a String (or nil if unmatched optional group).
inline BasicObject* intrinsic_match_data_to_a(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _a = new Array();
  _a->data.reserve(_md->captures_.size());
  for (std::size_t i = 0; i < _md->captures_.size(); i++) {
    _a->data.push_back(matchdata_cap(_md, static_cast<std::int64_t>(i)));
  }
  return _a;
}

// `MatchData#captures` — Array of captures EXCLUDING capture 0.
inline BasicObject* intrinsic_match_data_captures(BasicObject* self_) {
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
inline BasicObject* intrinsic_match_data_pre_match(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _s = static_cast<String*>(_md->iv_string);
  std::int64_t _b = _md->captures_[0].first;
  if (_b < 0) _b = 0;
  return new String(reinterpret_cast<const char*>(_s->bytes.data()), static_cast<std::size_t>(_b));
}

// `MatchData#post_match` — substring of original string after match.
inline BasicObject* intrinsic_match_data_post_match(BasicObject* self_) {
  auto* _md = static_cast<MatchData*>(self_);
  auto* _s = static_cast<String*>(_md->iv_string);
  std::int64_t _e = _md->captures_[0].second;
  if (_e < 0) _e = static_cast<std::int64_t>(_s->bytes.size());
  return new String(reinterpret_cast<const char*>(_s->bytes.data() + _e),
                    _s->bytes.size() - static_cast<std::size_t>(_e));
}

// `MatchData#match_length(n)` — byte length of capture n.
inline BasicObject* intrinsic_match_data_match_length(BasicObject* self_, BasicObject* n) {
  auto* _md = static_cast<MatchData*>(self_);
  std::int64_t _i = static_cast<Integer*>(n)->raw_;
  auto [_b, _e] = _md->captures_[_i];
  return new Integer(_e - _b);
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

// ---- Object / BasicObject ------------------------------------------

// `Object#dup` — shallow copy. Picks the runtime type by dynamic_cast
// so the new instance has the right vtable; ivars not copied (rare to
// depend on for non-Ruby-defined classes). Real impl would call
// m_initialize_copy.
inline BasicObject* intrinsic_object_dup(BasicObject* self_) {
  if (auto* _s = dynamic_cast<String*>(self_)) {
    auto* _r = new String();
    _r->bytes = _s->bytes;
    return _r;
  }
  if (auto* _a = dynamic_cast<Array*>(self_)) {
    auto* _r = new Array();
    _r->data = _a->data;
    return _r;
  }
  if (auto* _h = dynamic_cast<Hash*>(self_)) {
    auto* _r = new Hash();
    _r->data = _h->data;
    return _r;
  }
  return self_;
}

// `Object#public_send(name, *args, **kwargs, &block)` — reuses m_send
// (public/private distinction not enforced in box-first today).
inline BasicObject* intrinsic_object_public_send(BasicObject* self_, BasicObject* name,
                                                 BasicObject* args, BasicObject* kwargs,
                                                 BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  return self_->m_send(_full, dynamic_cast<Hash*>(kwargs), dynamic_cast<Proc*>(block));
}

// `BasicObject#__send__(name, *args, **kwargs, &block)` — same as
// Object#send (universal protocol doesn't gate by visibility today).
inline BasicObject* intrinsic_basic_object___send__(BasicObject* self_, BasicObject* name,
                                                    BasicObject* args, BasicObject* kwargs,
                                                    BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  return self_->m_send(_full, dynamic_cast<Hash*>(kwargs), dynamic_cast<Proc*>(block));
}

// `BasicObject#method_missing(name, *args)` — default impl raises
// NoMethodError. mm_dispatch already does this when the method is
// unknown; this intrinsic is for explicit `super` chains in user-
// defined method_missing.
[[noreturn]] inline BasicObject* intrinsic_basic_object_method_missing(BasicObject* /*self_*/, BasicObject* name,
                                                                       BasicObject* /*args*/, BasicObject* /*kwargs*/) {
  auto* _n = dynamic_cast<Symbol*>(name);
  const char* _name = _n ? _n->name_ : "<?>";
  std::string _msg = std::string("undefined method '") + _name + "'";
  throw static_cast<Exception*>(
      (&NoMethodError_CLASS)->m_new(new Array({static_cast<BasicObject*>(new String(_msg.data(), _msg.size()))})));
}

// ---- Kernel --------------------------------------------------------

// `catch(tag) { |t| ... }` — wraps the block in try/catch matching on
// ThrownTag's identity tag (Symbols intern, so == is correct). Block
// receives the tag as its sole argument.
inline BasicObject* intrinsic_kernel_catch(BasicObject* /*self_*/, BasicObject* tag, BasicObject* block) {
  try {
    return static_cast<Proc*>(block)->m_call(new Array({tag}));
  } catch (ThrownTag* _t) {
    if (_t->tag_ == tag) return _t->value_;
    throw;
  }
}

// `throw tag, value` — raises a ThrownTag carrying both. Caller
// nil-defaults the value at the Ruby level.
[[noreturn]] inline BasicObject* intrinsic_kernel_throw(BasicObject* /*self_*/, BasicObject* tag, BasicObject* value) {
  throw new ThrownTag(tag, value);
}

// `Kernel#puts(*args)` via send/dynamic dispatch (direct `puts` already
// routes through ruby_puts at the call-site).
inline BasicObject* intrinsic_kernel_puts(BasicObject* /*self_*/, BasicObject* args_arr) {
  auto* _a = splat_to_array(args_arr);
  if (_a->data.empty()) {
    ruby_puts(static_cast<BasicObject*>(nullptr));
  } else {
    for (auto* _e : _a->data) ruby_puts(_e);
  }
  return nil_instance();
}

// `Kernel#print(*args)` — puts without trailing newline. Stub: route
// through ruby_puts (mismatch, but rarely visible).
inline BasicObject* intrinsic_kernel_print(BasicObject* /*self_*/, BasicObject* args_arr) {
  auto* _a = splat_to_array(args_arr);
  for (auto* _e : _a->data) ruby_puts(_e);
  return nil_instance();
}

// `Kernel#rand(n)` — global PRNG. Stub: route through a process-wide
// Random instance (deterministically seeded with 0). Real impl would
// seed with /dev/urandom.
inline BasicObject* intrinsic_kernel_rand(BasicObject* /*self_*/, BasicObject* n) {
  static Random* _g = nullptr;
  if (!_g) {
    _g = new Random();
    Integer _zero(0);
    _g->m_initialize(new Array({static_cast<BasicObject*>(&_zero)}));
  }
  return _g->m_rand(n == nil_instance() ? &EMPTY_ARGS : new Array({n}));
}

// `Kernel#Integer(val, base = nil, exception: true)` — coerce to
// Integer via existing helper.
inline BasicObject* intrinsic_kernel_integer(BasicObject* /*self_*/, BasicObject* val,
                                             BasicObject* /*base*/, BasicObject* /*exception*/) {
  return new Integer(coerce_to_int(val));
}

// `Kernel#Float(val)` — coerce to Float. Fast path for Integer/Float;
// else dispatches to_f.
inline BasicObject* intrinsic_kernel_float(BasicObject* /*self_*/, BasicObject* val) {
  if (auto* _i = dynamic_cast<Integer*>(val)) return new Float(static_cast<double>(_i->raw_));
  if (dynamic_cast<Float*>(val)) return val;
  return val->m_to_f();
}

// `Kernel#raise(msg, message, backtrace, cause)`. Common forms: 1-arg
// (`raise X` or `raise "msg"`) and 2-arg (`raise X, "msg"`); 3+ arg
// backtrace/cause variants are rare and treated the same here.
[[noreturn]] inline BasicObject* intrinsic_kernel_raise(BasicObject* /*self_*/, BasicObject* msg, BasicObject* message,
                                                       BasicObject* /*backtrace*/, BasicObject* /*cause*/) {
  BasicObject* _exc;
  if (auto* _k = dynamic_cast<Class*>(msg)) {
    _exc = (message == nil_instance()) ? _k->m_new() : _k->m_new(new Array({message}));
  } else if (dynamic_cast<Exception*>(msg)) {
    _exc = msg;
  } else {
    _exc = (&RuntimeError_CLASS)->m_new(new Array({msg}));
  }
  throw static_cast<Exception*>(_exc);
}

// ---- Fiber storage -------------------------------------------------

// `Fiber[:k]` — read from process-global storage Hash. Symbols intern
// so identity-keyed access is correct. Direct ->data avoids the
// universal op_aref/op_aset Array allocation.
inline BasicObject* intrinsic_fiber_storage_get(BasicObject* /*self_*/, BasicObject* key) {
  auto& _h = g_fiber_storage()->data;
  auto _it = _h.find(key);
  return (_it == _h.end()) ? nil_instance() : _it->second;
}

// `Fiber[:k] = v` — write to process-global storage Hash.
inline BasicObject* intrinsic_fiber_storage_set(BasicObject* /*self_*/, BasicObject* key, BasicObject* val) {
  g_fiber_storage()->data[key] = val;
  return val;
}

// ---- File ----------------------------------------------------------
//
// Enough of `File.*` to let load_core resolve core/4.0/*.rb paths and
// for evaluate_file to read sources. Heavier ops (chmod, link, stat)
// are still abort-stubs — add as needed.

namespace fs_detail {
  inline std::string str_of(BasicObject* o) {
    auto* _s = static_cast<String*>(o);
    return std::string(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  }
  inline BasicObject* string_of(const std::string& s) {
    return new String(s.data(), s.size());
  }
  // Ruby File.expand_path: ~ expansion + abs join + lexical normalisation.
  // We don't go through realpath (so non-existent components are fine)
  // and we don't follow symlinks — that's File.realpath's job.
  inline std::string expand(const std::string& path, const std::string& dir) {
    std::string p = path;
    if (!p.empty() && p[0] == '~') {
      const char* home = std::getenv("HOME");
      if (home) {
        if (p.size() == 1 || p[1] == '/') p = std::string(home) + p.substr(1);
      }
    }
    std::filesystem::path fp(p);
    if (!fp.is_absolute()) {
      std::filesystem::path base = dir.empty() ? std::filesystem::current_path() : std::filesystem::path(dir);
      if (!base.is_absolute()) base = std::filesystem::current_path() / base;
      fp = base / fp;
    }
    fp = fp.lexically_normal();
    // lexically_normal preserves a trailing slash; Ruby strips it.
    std::string out = fp.string();
    if (out.size() > 1 && out.back() == '/') out.pop_back();
    return out;
  }
}

inline BasicObject* intrinsic_file_expand_path(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  return fs_detail::string_of(fs_detail::expand(fs_detail::str_of(path), _dir));
}

// File.dirname(path, level=1) — strip `level` trailing components.
inline BasicObject* intrinsic_file_dirname(BasicObject* path, BasicObject* level) {
  int64_t lvl = 1;
  if (level && level != nil_instance()) {
    if (auto* i = dynamic_cast<Integer*>(level)) lvl = i->raw_;
  }
  std::filesystem::path p(fs_detail::str_of(path));
  while (lvl-- > 0 && p.has_parent_path()) p = p.parent_path();
  auto d = p.string();
  return fs_detail::string_of(d.empty() ? std::string(".") : d);
}

// File.basename(path, suffix=nil) — strip suffix when given (".rb",
// ".*" matches any extension).
inline BasicObject* intrinsic_file_basename(BasicObject* path, BasicObject* suffix) {
  std::filesystem::path p(fs_detail::str_of(path));
  std::string base = p.filename().string();
  if (suffix && suffix != nil_instance()) {
    std::string sfx = fs_detail::str_of(suffix);
    if (sfx == ".*") {
      auto dot = base.find_last_of('.');
      if (dot != std::string::npos && dot > 0) base.erase(dot);
    } else if (sfx.size() < base.size() && base.compare(base.size() - sfx.size(), sfx.size(), sfx) == 0) {
      base.erase(base.size() - sfx.size());
    }
  }
  return fs_detail::string_of(base);
}

inline BasicObject* intrinsic_file_split(BasicObject* path) {
  std::filesystem::path p(fs_detail::str_of(path));
  auto d = p.parent_path().string();
  if (d.empty()) d = ".";
  return new Array({static_cast<BasicObject*>(fs_detail::string_of(d)),
                    static_cast<BasicObject*>(fs_detail::string_of(p.filename().string()))});
}

inline BasicObject* intrinsic_file_exist(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::exists(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_directory(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_directory(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_file(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_regular_file(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_size(BasicObject* path) {
  std::error_code ec;
  auto sz = std::filesystem::file_size(fs_detail::str_of(path), ec);
  return ec ? nil_instance() : static_cast<BasicObject*>(new Integer(static_cast<int64_t>(sz)));
}

inline BasicObject* intrinsic_file_size_exact(BasicObject* path) {
  return intrinsic_file_size(path);
}

inline BasicObject* intrinsic_file_realpath(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  std::string joined = fs_detail::expand(fs_detail::str_of(path), _dir);
  std::error_code ec;
  auto canon = std::filesystem::canonical(joined, ec);
  return ec ? fs_detail::string_of(joined) : fs_detail::string_of(canon.string());
}

inline BasicObject* intrinsic_file_realdirpath(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  std::string joined = fs_detail::expand(fs_detail::str_of(path), _dir);
  std::error_code ec;
  auto canon = std::filesystem::weakly_canonical(joined, ec);
  return ec ? fs_detail::string_of(joined) : fs_detail::string_of(canon.string());
}

inline BasicObject* intrinsic_file_read(BasicObject* path) {
  std::ifstream f(fs_detail::str_of(path), std::ios::binary);
  if (!f.is_open()) return nil_instance();
  std::stringstream ss;
  ss << f.rdbuf();
  std::string s = ss.str();
  return new String(s.data(), s.size());
}

// Many predicates are simple stat-mode checks; consolidate via helper.
namespace fs_detail {
  inline bool stat_check(BasicObject* path, mode_t mask) {
    struct stat st;
    return ::stat(str_of(path).c_str(), &st) == 0 && (st.st_mode & mask);
  }
}

inline BasicObject* intrinsic_file_readable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), R_OK) == 0);
}
inline BasicObject* intrinsic_file_readable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), R_OK) == 0);
}
inline BasicObject* intrinsic_file_writable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), W_OK) == 0);
}
inline BasicObject* intrinsic_file_writable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), W_OK) == 0);
}
inline BasicObject* intrinsic_file_executable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), X_OK) == 0);
}
inline BasicObject* intrinsic_file_executable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), X_OK) == 0);
}
inline BasicObject* intrinsic_file_owned(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_uid == ::geteuid());
}
inline BasicObject* intrinsic_file_grpowned(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_gid == ::getegid());
}
inline BasicObject* intrinsic_file_zero(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_size == 0);
}
inline BasicObject* intrinsic_file_chardev(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFCHR)); }
inline BasicObject* intrinsic_file_blockdev(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFBLK)); }
inline BasicObject* intrinsic_file_pipe(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFIFO)); }
inline BasicObject* intrinsic_file_socket(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFSOCK)); }
inline BasicObject* intrinsic_file_symlink(BasicObject* path) {
  struct stat st;
  return boxed_bool(::lstat(fs_detail::str_of(path).c_str(), &st) == 0 && S_ISLNK(st.st_mode));
}
inline BasicObject* intrinsic_file_setuid(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISUID)); }
inline BasicObject* intrinsic_file_setgid(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISGID)); }
inline BasicObject* intrinsic_file_sticky(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISVTX)); }
inline BasicObject* intrinsic_file_identical(BasicObject* a, BasicObject* b) {
  struct stat sa, sb;
  if (::stat(fs_detail::str_of(a).c_str(), &sa) != 0) return false_instance();
  if (::stat(fs_detail::str_of(b).c_str(), &sb) != 0) return false_instance();
  return boxed_bool(sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino);
}

#endif

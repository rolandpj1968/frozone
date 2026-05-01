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
  if (idx->m_class() != reinterpret_cast<BasicObject*>(&Integer_CLASS)) {
    std::fprintf(stderr, "[frozone-box-first] string_slice: non-Integer idx not yet supported\n");
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
  if (_v < 0 || _v > 255) {
    std::fprintf(stderr, "[frozone-box-first] integer_chr: value %lld out of byte range\n",
                 static_cast<long long>(_v));
    std::abort();
  }
  auto* _r = new String();
  _r->bytes.push_back(static_cast<std::uint8_t>(_v));
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

#endif

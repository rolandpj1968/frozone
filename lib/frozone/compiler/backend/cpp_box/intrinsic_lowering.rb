# Box-first IntrinsicCall lowering.
#
# `Intrinsics.foo(self, args...)` calls in lib/core/4.0/ Ruby code
# bypass the universal call protocol and lower to direct C++
# specialised to the receiver type encoded in the intrinsic name
# (`array_*` → cast to Array*, `integer__plus_` → cast to Integer*,
# etc.). For closed-world AOT this is exactly the specialisation
# we want — no vtable, no Array allocation for args, no
# static_cast at runtime, just the underlying op.
#
# Templates are explicit per-intrinsic (no name-based heuristic —
# too many edge cases). Each template is a lambda taking the cpp
# expression strings for the receiver and any extra args; returns
# the C++ expression string.
#
# Unknown intrinsic → EmissionError → method body skipped
# (graceful degradation; the method-vtable slot still exists, just
# falls through to mm_dispatch with NoMethodError).
#
# Adding a new intrinsic: add an entry to TEMPLATES below. The
# corresponding `Intrinsics.<name>(...)` Ruby call site must
# already exist in lib/core/4.0/ — we don't generate the
# Intrinsics module, just consume calls into it.

module Frozone
  module Compiler
    module Backend
      module CppBox
        module IntrinsicLowering
          module_function

          # Lower an intrinsic call to a C++ expression string.
          # `name` is the Symbol method name on Intrinsics;
          # `arg_strs` are the already-lowered C++ expression
          # strings for each positional argument (including the
          # receiver as the first arg, per the
          # `Intrinsics.foo(self, x, y)` convention in core/4.0/).
          #
          # Raises Cpp::EmissionError if no template matches or if
          # the template's lambda rejects the arg arity.
          def lower(name, *arg_strs)
            template = TEMPLATES[name]
            raise Cpp::EmissionError, "intrinsic :#{name} not yet supported" unless template
            template.call(*arg_strs)
          rescue ArgumentError => e
            raise Cpp::EmissionError, "intrinsic :#{name}: #{e.message}"
          end

          TEMPLATES = {
            # Array
            array_length: ->(self_) { "(new Integer(static_cast<int64_t>(static_cast<Array*>(#{self_})->data.size())))" },
            array_at: ->(self_, i) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); int64_t _i = static_cast<Integer*>(#{i})->raw_; return (_i < 0 || _i >= (int64_t)_a->data.size()) ? nil_instance() : _a->data[_i]; }())"
            },
            array_push: ->(self_, v) { "(static_cast<Array*>(#{self_})->data.push_back(#{v}), #{self_})" },
            array_replace: ->(self_, other) {
              "(static_cast<Array*>(#{self_})->data = static_cast<Array*>(#{other})->data, #{self_})"
            },
            array_dup: ->(self_) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); Array* _r = new Array(); _r->data = _a->data; return _r; }())"
            },
            array_concat: ->(self_, other) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); auto* _b = static_cast<Array*>(#{other}); _a->data.insert(_a->data.end(), _b->data.begin(), _b->data.end()); return _a; }())"
            },

            # Integer arithmetic — direct unboxed ops on raw_ + box.
            integer__plus_:  ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ + static_cast<Integer*>(#{o})->raw_))" },
            integer__minus_: ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ - static_cast<Integer*>(#{o})->raw_))" },
            integer__star_:  ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ * static_cast<Integer*>(#{o})->raw_))" },
            integer_spaceship: ->(s, o) {
              "(new Integer(static_cast<int64_t>((static_cast<Integer*>(#{s})->raw_ > static_cast<Integer*>(#{o})->raw_) - (static_cast<Integer*>(#{s})->raw_ < static_cast<Integer*>(#{o})->raw_))))"
            },
            float_spaceship: ->(s, o) {
              "(new Integer(static_cast<int64_t>((static_cast<Float*>(#{s})->raw_ > static_cast<Float*>(#{o})->raw_) - (static_cast<Float*>(#{s})->raw_ < static_cast<Float*>(#{o})->raw_))))"
            },

            integer__lt_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ <  static_cast<Integer*>(#{o})->raw_)" },
            integer__gt_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ >  static_cast<Integer*>(#{o})->raw_)" },
            integer__le_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ <= static_cast<Integer*>(#{o})->raw_)" },
            integer__ge_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ >= static_cast<Integer*>(#{o})->raw_)" },

            # Range — direct field access on the C++ struct (begin_,
            # end_, exclude_end_, initialized_).
            range_set: ->(self_, b, e, excl) {
              "([&]() -> BasicObject* { auto* _r = static_cast<Range*>(#{self_}); _r->begin_ = #{b}; _r->end_ = #{e}; _r->exclude_end_ = (#{excl} == true_instance()); _r->initialized_ = true; return nil_instance(); }())"
            },
            range_begin:        ->(self_) { "(static_cast<Range*>(#{self_})->begin_)" },
            range_end:          ->(self_) { "(static_cast<Range*>(#{self_})->end_)" },
            range_exclude_end:  ->(self_) { "boxed_bool(static_cast<Range*>(#{self_})->exclude_end_)" },
            range_initialized_q:->(self_) { "boxed_bool(static_cast<Range*>(#{self_})->initialized_)" },

            # String — direct byte-vector access. encoding/force_encoding
            # are stubs: we return a literal string for `encoding` so
            # core/4.0/ code that passes it through (e.g. reverse +
            # force_encoding(encoding)) doesn't blow up. Real encoding
            # tracking can come back when something needs it.
            # Return the real Encoding::UTF_8 constant (auto-emitted from
            # core/4.0/encoding.rb) — callers expect an Encoding object,
            # not a String, so they can call `ascii_compatible?` etc.
            # Always returning UTF-8 is a Phase 1 stub; real per-string
            # encoding tracking is parity-gaps §6.
            string_encoding: ->(_self_) { "k_Encoding_UTF_8()" },
            string_force_encoding: ->(self_, _enc) { "(#{self_})" },
            # Stub: Encoding.compatible?(a, b) — assume both UTF-8.
            # Real impl checks ASCII-compatible flag, ASCII-only fast
            # path, etc. The WQ parser's lexer needs this for source
            # buffer scanning. Always returning UTF-8 is fine while
            # box-first only sees UTF-8 source files.
            encoding_compatible: ->(_a, _b) { "k_Encoding_UTF_8()" },
            # Stub: assume the byte stream is valid UTF-8 (the WQ parser
            # needs this to gate its source-buffer encoding check).
            # Real walker would scan bytes for UTF-8 validity.
            string_valid_encoding: ->(_self_) { "true_instance()" },

            string_get_byte: ->(self_, i) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_])))"
            },
            string_setbyte: ->(self_, i, b) {
              "(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_] = static_cast<std::uint8_t>(static_cast<Integer*>(#{b})->raw_), #{b})"
            },
            string_bytesize: ->(self_) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes.size())))"
            },
            # `String#to_sym` — interns the string. intern() takes a
            # const char*, so the string must be NUL-terminated. Copy
            # bytes into a std::string for the lookup.
            string_to_sym: ->(self_) {
              "([&]() -> BasicObject* { auto* _s = static_cast<String*>(#{self_}); std::string _buf(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size()); return intern(_buf.c_str()); }())"
            },
            # `Symbol#to_s` — Symbol::name_ is a const char* set by
            # intern(). Wrap into a fresh String.
            symbol_to_s: ->(self_) {
              "([&]() -> BasicObject* { const char* _n = static_cast<Symbol*>(#{self_})->name_; return new String(_n, std::strlen(_n)); }())"
            },
            # `Symbol#inspect` — `:foo`. Prepends a colon, builds a
            # String. Doesn't quote names with special characters yet
            # (`:\"foo bar\"`); good enough for normal identifiers.
            symbol_inspect: ->(self_) {
              "([&]() -> BasicObject* { const char* _n = static_cast<Symbol*>(#{self_})->name_; std::size_t _len = std::strlen(_n); String* _r = new String(); _r->bytes.reserve(_len + 1); _r->bytes.push_back(':'); for (std::size_t _i = 0; _i < _len; ++_i) _r->bytes.push_back(static_cast<std::uint8_t>(_n[_i])); return _r; }())"
            },
            # `String#to_i(base)` — std::strtoll on the byte buffer
            # with the given base. Empty / non-numeric prefix returns 0
            # (matches MRI). Stub: doesn't handle 0x/0b/0o prefixes
            # for base==0, doesn't trim leading whitespace beyond
            # what strtoll's first behaviour gives us; widen as needed.
            string_to_i_base: ->(self_, base) {
              "([&]() -> BasicObject* { auto* _s = static_cast<String*>(#{self_}); if (_s->bytes.empty()) return new Integer(0); std::string _buf(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size()); int _b = static_cast<int>(static_cast<Integer*>(#{base})->raw_); char* _end = nullptr; long long _v = std::strtoll(_buf.c_str(), &_end, _b); return new Integer(static_cast<int64_t>(_v)); }())"
            },

            # Object identity / class — needed by core/4.0 dispatch helpers.
            object_is_a: ->(self_, klass) { "boxed_bool(dynamic_cast<Class*>(#{klass}) != nullptr && #{self_}->m_is_a_q(new Array({#{klass}})) == true_instance())" },
            object_class: ->(self_) { "#{self_}->m_class()" },
            # Kernel#lambda just returns the captured block as a Proc.
            # The Ruby `def lambda(&_block) = Intrinsics.kernel_lambda(self)`
            # form passes self to the intrinsic; the actual block lives
            # in the method's `_block` alias (set up by unpack_params).
            kernel_lambda: ->(_self_) { "static_cast<BasicObject*>(_block)" },
            kernel_proc: ->(_self_) { "static_cast<BasicObject*>(_block)" },
            # `catch(tag) { |t| ... }` — wraps the block in a C++
            # try/catch that pattern-matches on ThrownTag's pointer-
            # identity tag (Symbols intern, so == is correct). Block
            # receives the tag as its sole argument, matching MRI's
            # `catch(:foo) { |t| t == :foo }` semantics.
            kernel_catch: ->(_self_, tag, block) {
              "([&]() -> BasicObject* { try { return static_cast<Proc*>(#{block})->m_call(new Array({#{tag}})); } catch (ThrownTag* _t) { if (_t->tag_ == (#{tag})) return _t->value_; throw; } }())"
            },
            # `throw tag, value` — raises a ThrownTag carrying both.
            # Caller already nil-defaulted the value at the Ruby level
            # (`def throw(tag, value = nil)`).
            kernel_throw: ->(_self_, tag, value) {
              "([&]() -> BasicObject* { throw new ThrownTag(#{tag}, #{value}); }())"
            },
            basic_object__equal_equal_: ->(s, o) { "boxed_bool(#{s} == #{o})" },
            basic_object___id__: ->(s) { "(new Integer(reinterpret_cast<int64_t>(#{s})))" },

            # ---- Regexp / MatchData ----------------------------------
            # Most lower to direct field access on Regexp* / MatchData*.
            # Match operations route through the regexp_match_helper
            # KernelFn so $~ side-effects + capture-snapshot stay in
            # one place.
            regexp_source:  ->(self_) { "(static_cast<Regexp*>(#{self_})->source_)" },
            regexp_options: ->(self_) { "(new Integer(static_cast<Regexp*>(#{self_})->options_))" },
            regexp_newly_created_q: ->(self_) { "boxed_bool(!static_cast<Regexp*>(#{self_})->initialized_)" },
            regexp_encoding: ->(_self_) { %((new String("UTF-8", 5))) },
            regexp_inspect: ->(self_) {
              # `/source/`. Options stripped for now — adequate for debug
              # output; full MRI form (with /i/m/x flags) is a follow-up.
              "([&]() -> BasicObject* { auto* _r = static_cast<Regexp*>(#{self_}); auto* _s = static_cast<String*>(_r->source_); std::string _buf; _buf.reserve(_s->bytes.size() + 2); _buf.push_back('/'); _buf.append(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size()); _buf.push_back('/'); return new String(_buf.data(), _buf.size()); }())"
            },
            regexp_to_s: ->(self_) {
              # Delegate to inspect for now (MRI's #to_s emits `(?-mix:...)`
              # which we don't reproduce yet).
              "([&]() -> BasicObject* { auto* _r = static_cast<Regexp*>(#{self_}); auto* _s = static_cast<String*>(_r->source_); std::string _buf; _buf.reserve(_s->bytes.size() + 2); _buf.push_back('/'); _buf.append(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size()); _buf.push_back('/'); return new String(_buf.data(), _buf.size()); }())"
            },
            # Regexp.new(class, pattern, options, kw_opts) — class is
            # &Regexp_CLASS, pattern is String, options is Integer or
            # nil, kw_opts is Hash (currently ignored).
            regexp_new: ->(_klass, pat, opts, _kw) {
              "([&]() -> BasicObject* { Regexp* _re = new Regexp(); Array* _a = new Array({#{pat}, ((#{opts}) == nil_instance() ? static_cast<BasicObject*>(new Integer(0)) : (#{opts}))}); _re->m_initialize(_a, nullptr, nullptr); return _re; }())"
            },
            # `re =~ str` — returns Integer of byte-offset, or nil. Sets $~.
            regexp_match_index: ->(self_, str) {
              "([&]() -> BasicObject* { auto* _md = regexp_match_helper(#{self_}, #{str}, 0); return _md ? static_cast<BasicObject*>(new Integer(_md->captures_[0].first)) : nil_instance(); }())"
            },
            # `re.match?(str, pos)` — true/false; doesn't set $~ in MRI,
            # but we set it anyway (cheap, simpler code).
            regexp_match_bool: ->(self_, str, pos) {
              "boxed_bool(regexp_match_helper(#{self_}, #{str}, static_cast<Integer*>(#{pos})->raw_) != nullptr)"
            },
            # `re.match(str, pos)` — returns MatchData or nil. Sets $~.
            regexp_match: ->(self_, str, pos) {
              "([&]() -> BasicObject* { auto* _md = regexp_match_helper(#{self_}, #{str}, static_cast<Integer*>(#{pos})->raw_); return _md ? static_cast<BasicObject*>(_md) : nil_instance(); }())"
            },
            # `Regexp.last_match` / `Regexp.last_match(n)` — read $~ or
            # capture n from $~. Single overload: nil → return $~ itself.
            regexp_last_match: ->(n) {
              "([&]() -> BasicObject* { BasicObject* _md = g_last_match(); if ((#{n}) == nil_instance() || (#{n}) == nullptr) return _md; if (_md == nullptr || _md == nil_instance()) return nil_instance(); return matchdata_cap(_md, static_cast<Integer*>(#{n})->raw_); }())"
            },

            # `String#=~ Regexp` already lowers via regexp_match_index.
            # `String#match` calls `Intrinsics.string_match(str, pattern)`
            # — same operation, mirrored arg order.
            string_match: ->(self_, pat) {
              "([&]() -> BasicObject* { auto* _md = regexp_match_helper(#{pat}, #{self_}, 0); return _md ? static_cast<BasicObject*>(_md) : nil_instance(); }())"
            },
            string_match_pos: ->(self_, pat, pos) {
              "([&]() -> BasicObject* { auto* _md = regexp_match_helper(#{pat}, #{self_}, static_cast<Integer*>(#{pos})->raw_); return _md ? static_cast<BasicObject*>(_md) : nil_instance(); }())"
            },
            string_match_q: ->(self_, pat, pos) {
              "boxed_bool(regexp_match_helper(#{pat}, #{self_}, ((#{pos}) == nil_instance() ? 0 : static_cast<Integer*>(#{pos})->raw_)) != nullptr)"
            },
            string_unpack: ->(self_, fmt, _offset) { "string_unpack_helper(#{self_}, #{fmt})" },

            string_gsub: ->(self_, pat, repl, block) {
              "string_gsub_helper(#{self_}, #{pat}, #{repl}, dynamic_cast<Proc*>(#{block}))"
            },
            # `sub` reuses gsub for now — fine when the pattern only
            # matches once. WQ doesn't call sub yet, so an exact `sub`
            # impl can wait.
            string_sub: ->(self_, pat, repl, block) {
              "string_gsub_helper(#{self_}, #{pat}, #{repl}, dynamic_cast<Proc*>(#{block}))"
            },

            # MatchData accessors. md[N] (Integer N) routes here.
            match_data_index: ->(self_, n) { "matchdata_cap(#{self_}, static_cast<Integer*>(#{n})->raw_)" },
            match_data_size:  ->(self_) { "(new Integer(static_cast<int64_t>(static_cast<MatchData*>(#{self_})->captures_.size())))" },
            match_data_string: ->(self_) { "(static_cast<MatchData*>(#{self_})->iv_string)" },
            match_data_regexp: ->(self_) { "(static_cast<MatchData*>(#{self_})->iv_regexp)" },
            match_data_to_a: ->(self_) {
              "([&]() -> BasicObject* { auto* _md = static_cast<MatchData*>(#{self_}); Array* _a = new Array(); _a->data.reserve(_md->captures_.size()); for (size_t i = 0; i < _md->captures_.size(); i++) _a->data.push_back(matchdata_cap(_md, static_cast<int64_t>(i))); return _a; }())"
            },
            match_data_captures: ->(self_) {
              "([&]() -> BasicObject* { auto* _md = static_cast<MatchData*>(#{self_}); Array* _a = new Array(); if (_md->captures_.size() > 1) { _a->data.reserve(_md->captures_.size() - 1); for (size_t i = 1; i < _md->captures_.size(); i++) _a->data.push_back(matchdata_cap(_md, static_cast<int64_t>(i))); } return _a; }())"
            },
            match_data_pre_match: ->(self_) {
              "([&]() -> BasicObject* { auto* _md = static_cast<MatchData*>(#{self_}); auto* _s = static_cast<String*>(_md->iv_string); int64_t _b = _md->captures_[0].first; if (_b < 0) _b = 0; return new String(reinterpret_cast<const char*>(_s->bytes.data()), static_cast<size_t>(_b)); }())"
            },
            match_data_post_match: ->(self_) {
              "([&]() -> BasicObject* { auto* _md = static_cast<MatchData*>(#{self_}); auto* _s = static_cast<String*>(_md->iv_string); int64_t _e = _md->captures_[0].second; if (_e < 0) _e = static_cast<int64_t>(_s->bytes.size()); return new String(reinterpret_cast<const char*>(_s->bytes.data() + _e), _s->bytes.size() - static_cast<size_t>(_e)); }())"
            },
            match_data_begin: ->(self_, n) { "(new Integer(static_cast<MatchData*>(#{self_})->captures_[static_cast<Integer*>(#{n})->raw_].first))" },
            match_data_end:   ->(self_, n) { "(new Integer(static_cast<MatchData*>(#{self_})->captures_[static_cast<Integer*>(#{n})->raw_].second))" },
            match_data_bytebegin: ->(self_, n) { "(new Integer(static_cast<MatchData*>(#{self_})->captures_[static_cast<Integer*>(#{n})->raw_].first))" },
            match_data_byteend:   ->(self_, n) { "(new Integer(static_cast<MatchData*>(#{self_})->captures_[static_cast<Integer*>(#{n})->raw_].second))" },
            # Stubs — return whole-match for slice forms so md[0,len] /
            # md[range] don't blow up the auto-emitter (each branch of
            # MatchData#[] is emitted regardless of which one runs).
            # Real impl is a follow-up.
            match_data_slice: ->(self_, _i, _len) { "matchdata_cap(#{self_}, 0)" },
            match_data_slice_range: ->(self_, _r) { "matchdata_cap(#{self_}, 0)" },
            match_data_match_length: ->(self_, n) {
              "([&]() -> BasicObject* { auto* _md = static_cast<MatchData*>(#{self_}); int64_t _i = static_cast<Integer*>(#{n})->raw_; auto [_b, _e] = _md->captures_[_i]; return new Integer(_e - _b); }())"
            },
            match_data_named_captures: ->(_self_) { "(new Hash())" },  # stub — empty hash
            match_data_names: ->(_self_) { "(new Array())" },          # stub — empty array
            match_data_values_at_range: ->(_self_, _r, _n) { "(new Array())" },  # stub

            # Hash intrinsics — direct ->data access. Hash class is
            # universe-defined with map_t data; these intrinsics
            # bypass the op_aref/op_aset Array allocation.
            hash_key: ->(self_, k) {
              "boxed_bool(static_cast<Hash*>(#{self_})->data.find(#{k}) != static_cast<Hash*>(#{self_})->data.end())"
            },
            hash_index: ->(self_, k) {
              "([&]() -> BasicObject* { auto* _h = static_cast<Hash*>(#{self_}); auto _it = _h->data.find(#{k}); return (_it == _h->data.end()) ? nil_instance() : _it->second; }())"
            },
            hash_index_write: ->(self_, k, v) {
              "(static_cast<Hash*>(#{self_})->data[#{k}] = #{v})"
            },
            hash_size: ->(self_) {
              "(new Integer(static_cast<int64_t>(static_cast<Hash*>(#{self_})->data.size())))"
            },

            # `BasicObject#__send__(name, *args)` — same dispatch as
            # `Object#send` (universal protocol doesn't gate by
            # visibility today). Routes through m_send.
            basic_object___send__: ->(self_, name, args, kwargs, block) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{args}); Array* _full = new Array(); _full->data.push_back(#{name}); for (auto* _e : _a->data) _full->data.push_back(_e); return (#{self_})->m_send(_full, dynamic_cast<Hash*>(#{kwargs}), dynamic_cast<Proc*>(#{block})); }())"
            },
            # `BasicObject#method_missing(name, *args)` — default
            # impl raises NoMethodError. mm_dispatch already does
            # this when the method is unknown; this intrinsic is
            # for explicit `super` chains in user-defined
            # method_missing.
            basic_object_method_missing: ->(_self_, name, _args, _kwargs) {
              "([&]() -> BasicObject* { Symbol* _n = dynamic_cast<Symbol*>(#{name}); const char* _name = _n ? _n->name_ : \"<?>\"; std::string _msg = std::string(\"undefined method '\") + _name + \"'\"; throw static_cast<Exception*>((&NoMethodError_CLASS)->m_new(new Array({static_cast<BasicObject*>(new String(_msg.data(), _msg.size()))}))); }())"
            },

            # Object protocol stubs — most return nil/false/empty/self
            # to stop downstream nil.foo cascades. Real impls would
            # need per-class metadata or runtime reflection that
            # box-first doesn't track.
            object_dup: ->(self_) {
              # Shallow copy. dynamic_cast picks the runtime type
              # so the new instance has the right vtable; ivars
              # not copied (rare to depend on for non-Ruby-defined
              # classes). Real impl would call m_initialize_copy.
              "([&]() -> BasicObject* { auto* _o = #{self_}; if (auto* _s = dynamic_cast<String*>(_o)) { auto* _r = new String(); _r->bytes = _s->bytes; return _r; } if (auto* _a = dynamic_cast<Array*>(_o)) { auto* _r = new Array(); _r->data = _a->data; return _r; } if (auto* _h = dynamic_cast<Hash*>(_o)) { auto* _r = new Hash(); _r->data = _h->data; return _r; } return _o; }())"
            },
            object_freeze:    ->(self_) { "(#{self_})" },             # stub: no-op (we don't track frozen state)
            object_frozen:    ->(_self_) { "false_instance()" },        # stub: nothing is frozen
            object_methods:   ->(_self_, _all) { "(new Array())" },     # stub: empty list
            object_method:    ->(_self_, _name) { "nil_instance()" },   # stub: no Method object
            object_ivar_get:  ->(_self_, _name) { "nil_instance()" },   # stub: ivars are static fields, not accessible by name
            object_ivar_set:  ->(_self_, _name, val) { "(#{val})" },    # stub: returns the value, doesn't actually set
            object_ivar_defined: ->(_self_, _name) { "false_instance()" },
            object_ivar_remove:  ->(_self_, _name) { "nil_instance()" },
            object_ivar_names:   ->(_self_) { "(new Array())" },        # stub: empty (would need per-class metadata)
            object_public_send:  ->(self_, name, args, kwargs, block) {
              # Reuse m_send dispatch — public/private distinction
              # not enforced in box-first today.
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{args}); Array* _full = new Array(); _full->data.push_back(#{name}); for (auto* _e : _a->data) _full->data.push_back(_e); return (#{self_})->m_send(_full, dynamic_cast<Hash*>(#{kwargs}), dynamic_cast<Proc*>(#{block})); }())"
            },
            object_respond_to: ->(self_, name, _include_all) {
              # Forward to the universal m_respond_to_q — drop
              # include_all (private methods always visible in
              # box-first today; respond_to_q doesn't gate by
              # visibility either).
              "(#{self_})->m_respond_to_q(new Array({#{name}}))"
            },
            object_instance_of: ->(self_, klass) {
              "boxed_bool(#{self_}->m_class() == (#{klass}))"
            },

            # Kernel#puts/print(*args) dispatched as intrinsic — direct
            # `puts` (call-site) routes through ruby_puts already.
            # This path fires when puts is called via send/dynamic
            # dispatch.
            kernel_puts: ->(_self_, args_arr) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{args_arr}); if (_a->data.empty()) { ruby_puts(static_cast<BasicObject*>(nullptr)); } else { for (auto* _e : _a->data) ruby_puts(_e); } return nil_instance(); }())"
            },
            kernel_print: ->(_self_, args_arr) {
              # `print` is `puts` without trailing newline — stub
              # via ruby_puts for now (mismatch, but rarely visible).
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{args_arr}); for (auto* _e : _a->data) ruby_puts(_e); return nil_instance(); }())"
            },
            kernel_rand: ->(_self_, n) {
              # `Kernel#rand` is the global PRNG. Stub: route through
              # a process-wide Random instance (lazily seeded with 0
              # — deterministic, surface-level OK for tests). Real
              # impl would seed with /dev/urandom.
              "([&]() -> BasicObject* { static Random* _g = nullptr; if (!_g) { _g = new Random(); _g->m_initialize(new Array({(&_f_i_0)})); } return _g->m_rand((#{n}) == nil_instance() ? &EMPTY_ARGS : new Array({(#{n})})); }())"
            },
            kernel_block_given: ->(_self_) {
              # Stub: false. We don't propagate _block to here. A
              # real impl would need the calling-method's _block
              # context, which is awkward via the intrinsic boundary.
              "false_instance()"
            },
            kernel_caller: ->(_self_, _start, _length) { "(new Array())" },           # stub: empty backtrace
            kernel_caller_locations: ->(_self_, _start, _length) { "(new Array())" }, # same
            kernel_integer: ->(_self_, val, _base, _exception) {
              # Coerce to Integer via existing helper.
              "(new Integer(coerce_to_int(#{val})))"
            },
            kernel_float: ->(_self_, val) {
              # Coerce to Float — fast path for Integer/Float, else
              # call to_f.
              "([&]() -> BasicObject* { auto* _v = #{val}; if (auto* _i = dynamic_cast<Integer*>(_v)) return new Float(static_cast<double>(_i->raw_)); if (dynamic_cast<Float*>(_v)) return _v; return _v->m_to_f(); }())"
            },

            # `Kernel#raise(msg, message, backtrace, cause)`. Most
            # programs use `raise X` (1-arg) or `raise X, msg`
            # (2-arg); 3+ arg backtrace/cause variants are rare and
            # treated the same here. Skips the "0-arg re-raise"
            # path (would need thread-local current-exception
            # tracking) — a `raise` with no real arg uses the
            # sentinel `:__raise_no_arg__` set by the Ruby default,
            # which we just treat as a fresh RuntimeError.
            kernel_raise: ->(_self_, msg, message, _backtrace, _cause) {
              "([&]() -> BasicObject* { BasicObject* _m = (#{msg}); BasicObject* _msg = (#{message}); BasicObject* _exc; if (auto* _k = dynamic_cast<Class*>(_m)) { _exc = (_msg == nil_instance()) ? _k->m_new() : _k->m_new(new Array({_msg})); } else if (dynamic_cast<Exception*>(_m)) { _exc = _m; } else { _exc = (&RuntimeError_CLASS)->m_new(new Array({_m})); } throw static_cast<Exception*>(_exc); }())"
            },

            # Fiber storage — `Fiber[:k]` / `Fiber[:k] = v`. Backed by
            # a single global Hash* (single-threaded today); identity
            # keys work because Symbols intern. Direct ->data access
            # avoids the universal op_aref/op_aset Array allocation.
            fiber_storage_get: ->(_self_, key) {
              "([&]() -> BasicObject* { auto& _h = g_fiber_storage()->data; auto _it = _h.find(#{key}); return (_it == _h.end()) ? nil_instance() : _it->second; }())"
            },
            fiber_storage_set: ->(_self_, key, val) {
              "(g_fiber_storage()->data[#{key}] = #{val})"
            },
          }.freeze
        end
      end
    end
  end
end

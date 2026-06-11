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
            return template.call(*arg_strs) if template
            # Map Ruby's `?` predicate suffix to C++ `_q` so callers can
            # write `Intrinsics.foo?(...)` naturally and the C++ side
            # uses the canonical `intrinsic_foo_q` name.
            cpp_name = name.to_s.end_with?('?') ? "#{name.to_s.chomp('?')}_q" : name.to_s
            return "intrinsic_#{cpp_name}(#{arg_strs.join(', ')})" if HPP_INTRINSICS.include?(cpp_name.to_sym)
            # Held for implementation (IMPLEMENT_QUEUE): keep as a skip
            # (EmissionError → method_missing) rather than auto-stub, so an
            # exercised one surfaces as a catchable NoMethodError, not a hard
            # abort — and it's tracked as a todo, not "deliberately dead".
            raise Cpp::EmissionError, "intrinsic :#{name} held for implementation (IMPLEMENT_QUEUE)" if IMPLEMENT_QUEUE.include?(cpp_name.to_sym)
            # Default: a reachable intrinsic with no real lowering and not
            # queued for one is deliberately stubbed — compile a method that
            # aborts loudly with the name if reached, never a silent
            # method_missing. Definite, tracked state (scripts/intrinsic_coverage.rb).
            "intrinsic_not_implemented(#{cpp_name.inspect})"
          rescue ArgumentError => e
            raise Cpp::EmissionError, "intrinsic :#{name}: #{e.message}"
          end

          # Reachable intrinsics we INTEND to implement (so stub-by-default
          # doesn't abort them): the value-type data ops + the certain
          # startup-exercised (Fiber[:context] storage) + a couple of
          # load-bearing targets. These stay skip→method_missing until
          # implemented (then they move to a TEMPLATE/HPP). Everything else
          # reachable auto-stubs (loud abort). The benchmark round upgrades
          # demand-proven stubs into this queue / into real impls.
          IMPLEMENT_QUEUE = Set.new(%i[
            fiber_storage_hash fiber_storage_hash_set
            string_append_as_bytes string_append_bytes string_bytesplice
            string_capitalize_opts string_delete_raw
            string_downcase_opts string_squeeze_raw
            string_swapcase_opts string_upcase_opts
            array_clone array_index_write array_initialize array_pack
            array_sample array_sample_n array_slice_write array_unshift
            hash_new hash_transform_keys_bang
            float_gamma float_rationalize float_to_r
            object_clone
          ]).freeze

          # Names with `intrinsic_<name>(...)` definitions in
          # cpp/runtime/intrinsics.hpp. Anything in this set lowers to
          # a direct function call with the args identity-passed. Edit
          # in lockstep with intrinsics.hpp; if you add a function
          # there, add the name here. (TEMPLATES below is for special
          # cases — one-liner inline expressions, closure-using
          # intrinsics that reference _block, helper-renames.)
          HPP_INTRINSICS = Set.new(%i[
            dbg_write
            float_ceil float_floor float_truncate float_round
            float_frexp float_lgamma
            io_raw_write_stdout io_raw_write_stderr
            string_index string_slice string_split string_chars
            string_inspect string_hash string_to_sym string_to_i_base
            string_format string_replace string_store string_initialize string_tr_raw
            string_match string_match_pos string_count_raw
            symbol_to_s symbol_inspect
            regexp_escape regexp_inspect regexp_to_s regexp_new
            regexp_match_index regexp_match regexp_last_match
            match_data_to_a match_data_captures match_data_pre_match
            match_data_post_match match_data_match_length
            hash_each hash_delete
            hash_compare_by_identity hash_compare_by_identity_q
            hash_reset_compare_by_identity
            hash_get_default hash_set_default
            hash_get_default_proc hash_set_default_proc
            array_to_s
            integer_bit_length
            object_dup object_public_send
            basic_object___send__ basic_object_method_missing
            kernel_catch kernel_throw kernel_puts kernel_print
            kernel_rand kernel_integer kernel_float kernel_raise kernel_exit
            process_clock_gettime
            fiber_storage_get fiber_storage_set
            os_stat os_lstat os_access os_realpath os_readlink os_euid os_egid
            os_unlink os_rename os_link os_symlink os_chmod os_truncate
            os_utimes os_mkfifo os_umask os_fnmatch
            file_read
            os_getenv os_setenv os_unsetenv os_environ_pairs
            random_new random_new_seed random_seed random_state
            random_rand random_bytes random_urandom random_marshal_load
            process_pid process_uid process_euid process_gid process_egid
            process_groups process_kill process_clock_getres
            process_wait process_wait2 process_waitall
            process_status_exitstatus process_status_pid process_status_termsig
            dir_pwd dir_chdir dir_home dir_entries dir_glob
            dir_mkdir dir_rmdir dir_exist dir_empty
            dir_open dir_close dir_read dir_seek dir_rewind
            dir_fileno dir_for_fd dir_fchdir dir_chroot dir_mktmpdir
            os_time_now os_localtime os_gmtime os_mktime os_strftime
            time_make time_to_i time_nsec
            time_utc_q time_utc time_utc_offset
            time_dup time_localtime
            time_to_r time_at_raw
            time_new_from_string time_dump time_load time_iso8601
            integer_bitand integer_bitor integer_bitxor
            integer__div_ integer__mod_ integer_fdiv
            integer_lshift integer_rshift integer__pow_
            integer_to_f integer_to_s integer_to_c integer_to_r
            string_freeze string_frozen string_dup string_clone
            string_eql string_concat string_concat_codepoint string_dedup
            string_byteindex string_byterindex string_byteslice
            string_ord string_oct string_rindex string_each_line
            string_dump string_grapheme_clusters string_slice_bang
            string_tr_s string_unpack1 string_undump string_crypt
            string_scrub string_unicode_normalize
            string_unicode_normalized_q string_to_c string_upto
          ]).freeze

          # Intrinsic name → category header for per-TU precise
          # `#include "../../../runtime/intrinsics/<cat>_intrinsics.hpp"`
          # emission in class_emitter.rb. Most names dispatch by prefix
          # (PREFIX_CATEGORY below); the `os_*` block is hand-split since
          # those names span file / env / time / process. Keep in sync
          # when adding entries to HPP_INTRINSICS above.
          HPP_INTRINSIC_CATEGORY = {
            os_stat: :file, os_lstat: :file, os_access: :file,
            os_realpath: :file, os_readlink: :file, os_unlink: :file,
            os_rename: :file, os_link: :file, os_symlink: :file,
            os_chmod: :file, os_truncate: :file, os_utimes: :file,
            os_mkfifo: :file, os_umask: :file, os_fnmatch: :file,
            os_euid: :file, os_egid: :file,
            os_getenv: :env, os_setenv: :env, os_unsetenv: :env,
            os_environ_pairs: :env,
            os_time_now: :time, os_localtime: :time, os_gmtime: :time,
            os_mktime: :time, os_strftime: :time,
          }.freeze

          PREFIX_CATEGORY = {
            "dbg_" => :kernel,
            "fiber_" => :kernel,
            "kernel_" => :kernel,
            "float_" => :float,
            "io_" => :io,
            "string_" => :string,
            "symbol_" => :string,
            "array_" => :string,
            "regexp_" => :regexp,
            "match_" => :regexp,
            "hash_" => :hash,
            "integer_" => :integer,
            "object_" => :object,
            "basic_object_" => :object,
            "process_" => :process,
            "random_" => :random,
            "file_" => :file,
            "dir_" => :dir,
            "time_" => :time,
          }.freeze

          # Returns the category symbol for a given intrinsic name, or
          # nil if the name doesn't lower to an HPP function (TEMPLATE-
          # only intrinsics need no header dep).
          def self.category_for(name)
            sym = name.to_sym
            return nil unless HPP_INTRINSICS.include?(sym)
            return HPP_INTRINSIC_CATEGORY[sym] if HPP_INTRINSIC_CATEGORY.key?(sym)
            s = name.to_s
            PREFIX_CATEGORY.each { |pre, cat| return cat if s.start_with?(pre) }
            nil
          end

          # Unary <cmath> Float→Float intrinsics (Math.* + Float math
          # methods): intrinsic name → C math function. Each lowers to
          # `(new Float(std::FN(recv.raw_)))`. Spliced into TEMPLATES below.
          FLOAT_UNARY_CMATH = %i[
            sqrt cbrt exp log log2 log10 sin cos tan asin acos atan
            sinh cosh tanh asinh acosh atanh expm1 log1p erf erfc
          ].each_with_object({}) { |fn, h|
            h[:"float_#{fn}"] = ->(s) { "(new Float(std::#{fn}(static_cast<Float*>(#{s})->raw_)))" }
          }.freeze

          TEMPLATES = {
            **FLOAT_UNARY_CMATH,
            # Interpreter discriminator — true when the enclosing body is
            # being walked by an interpreter (MRI Frozone, or Frozone²);
            # false when the body is compiled native machine code. Lets
            # shared code (HashObject's KeyWrapper bridge) short-circuit
            # host-Ruby workarounds that only apply during interpretation.
            # NOTE: keyed by the Ruby name (with `?`); the `?`→`_q` transform
            # in `lower` only runs for HPP_INTRINSICS lookups, not TEMPLATES.
            :"interpreted?" => ->(*_) { "false_instance()" },
            # Class — raw allocator that bypasses Ruby-level overrides.
            # `Thread.allocate` raises TypeError, so calling through
            # m_allocate would hit that. m_raw_allocate is a non-Ruby
            # vtable slot on Class that every eigenclass overrides with
            # `return new HostType()`. Used by `def allocate` in class.rb
            # and per-class wrappers (`Thread#__allocate_thread`).
            class_allocate: ->(klass) { "static_cast<Class*>(#{klass})->m_raw_allocate(univ)" },

            # Array
            array_length: ->(self_) { "(new Integer(static_cast<int64_t>(static_cast<Array*>(#{self_})->data.size())))" },
            array_at: ->(self_, i) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); int64_t _i = static_cast<Integer*>(#{i})->raw_; return (_i < 0 || _i >= (int64_t)_a->data.size()) ? nil_instance() : _a->data[_i]; }())"
            },
            array_push: ->(self_, v) { "(static_cast<Array*>(#{self_})->data.push_back(#{v}), #{self_})" },
            # pop/shift: core's __check_frozen__ runs before the intrinsic,
            # so no frozen recheck here. Empty → nil.
            array_pop: ->(self_) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); if (_a->data.empty()) return nil_instance(); BasicObject* _v = _a->data.back(); _a->data.pop_back(); return _v; }())"
            },
            array_shift: ->(self_) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); if (_a->data.empty()) return nil_instance(); BasicObject* _v = _a->data.front(); _a->data.erase(_a->data.begin()); return _v; }())"
            },
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
            integer__mul_:   ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ * static_cast<Integer*>(#{o})->raw_))" },
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
            integer__eq_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ == static_cast<Integer*>(#{o})->raw_)" },
            integer_bitnot:  ->(s) { "(new Integer(~static_cast<Integer*>(#{s})->raw_))" },
            float__mod_:     ->(s, o) { "(new Float(std::fmod(static_cast<Float*>(#{s})->raw_, static_cast<Float*>(#{o})->raw_)))" },
            float_divmod:    ->(s, o) {
              "([&]() -> BasicObject* { double _a = static_cast<Float*>(#{s})->raw_; double _b = static_cast<Float*>(#{o})->raw_; double _q = std::floor(_a / _b); double _r = _a - _q * _b; return (new Array({static_cast<BasicObject*>(new Float(_q)), static_cast<BasicObject*>(new Float(_r))})); }())"
            },
            float_hash:      ->(s) { "(new Integer(static_cast<int64_t>(std::hash<double>{}(static_cast<Float*>(#{s})->raw_))))" },
            float_to_s:      ->(s) {
              "([&]() -> BasicObject* { char _buf[32]; double _v = static_cast<Float*>(#{s})->raw_; if (std::isnan(_v)) return new String(\"NaN\", 3); if (std::isinf(_v)) return new String(_v > 0 ? \"Infinity\" : \"-Infinity\", _v > 0 ? 8 : 9); int _n = std::snprintf(_buf, sizeof(_buf), \"%.17g\", _v); return new String(_buf, _n); }())"
            },

            # Float arithmetic + comparison — unboxed double ops on raw_,
            # reboxed. (+ - * / are usually handled by the typed-operator
            # fast path; these are the dynamic-dispatch fallback bodies.)
            float__plus_:  ->(s, o) { "(new Float(static_cast<Float*>(#{s})->raw_ + static_cast<Float*>(#{o})->raw_))" },
            float__minus_: ->(s, o) { "(new Float(static_cast<Float*>(#{s})->raw_ - static_cast<Float*>(#{o})->raw_))" },
            float__mul_:   ->(s, o) { "(new Float(static_cast<Float*>(#{s})->raw_ * static_cast<Float*>(#{o})->raw_))" },
            float__div_:   ->(s, o) { "(new Float(static_cast<Float*>(#{s})->raw_ / static_cast<Float*>(#{o})->raw_))" },
            float__pow_:   ->(s, o) { "(new Float(std::pow(static_cast<Float*>(#{s})->raw_, static_cast<Float*>(#{o})->raw_)))" },
            float__lt_:    ->(s, o) { "boxed_bool(static_cast<Float*>(#{s})->raw_ <  static_cast<Float*>(#{o})->raw_)" },
            float__le_:    ->(s, o) { "boxed_bool(static_cast<Float*>(#{s})->raw_ <= static_cast<Float*>(#{o})->raw_)" },
            float__ge_:    ->(s, o) { "boxed_bool(static_cast<Float*>(#{s})->raw_ >= static_cast<Float*>(#{o})->raw_)" },
            float__gt_:    ->(s, o) { "boxed_bool(static_cast<Float*>(#{s})->raw_ >  static_cast<Float*>(#{o})->raw_)" },
            float_eq:      ->(s, o) { "boxed_bool(static_cast<Float*>(#{s})->raw_ == static_cast<Float*>(#{o})->raw_)" },
            float_infinity: -> { "(new Float(std::numeric_limits<double>::infinity()))" },
            float_nan:      -> { "(new Float(std::numeric_limits<double>::quiet_NaN()))" },
            # Ruby Float#remainder is truncated (sign of dividend) == C fmod.
            float_remainder: ->(s, o) { "(new Float(std::fmod(static_cast<Float*>(#{s})->raw_, static_cast<Float*>(#{o})->raw_)))" },
            float_atan2:    ->(s, o) { "(new Float(std::atan2(static_cast<Float*>(#{s})->raw_, static_cast<Float*>(#{o})->raw_)))" },
            float_hypot:    ->(s, o) { "(new Float(std::hypot(static_cast<Float*>(#{s})->raw_, static_cast<Float*>(#{o})->raw_)))" },
            float_ldexp:    ->(s, o) { "(new Float(std::ldexp(static_cast<Float*>(#{s})->raw_, static_cast<int>(static_cast<Integer*>(#{o})->raw_))))" },
            # Single-arg math (called from core/4.0/math.rb after _coerce_float).
            float_sqrt: ->(s) { "(new Float(std::sqrt(static_cast<Float*>(#{s})->raw_)))" },
            float_cbrt: ->(s) { "(new Float(std::cbrt(static_cast<Float*>(#{s})->raw_)))" },
            float_exp: ->(s) { "(new Float(std::exp(static_cast<Float*>(#{s})->raw_)))" },
            float_expm1: ->(s) { "(new Float(std::expm1(static_cast<Float*>(#{s})->raw_)))" },
            float_log: ->(s) { "(new Float(std::log(static_cast<Float*>(#{s})->raw_)))" },
            float_log2: ->(s) { "(new Float(std::log2(static_cast<Float*>(#{s})->raw_)))" },
            float_log10: ->(s) { "(new Float(std::log10(static_cast<Float*>(#{s})->raw_)))" },
            float_log1p: ->(s) { "(new Float(std::log1p(static_cast<Float*>(#{s})->raw_)))" },
            float_sin: ->(s) { "(new Float(std::sin(static_cast<Float*>(#{s})->raw_)))" },
            float_cos: ->(s) { "(new Float(std::cos(static_cast<Float*>(#{s})->raw_)))" },
            float_tan: ->(s) { "(new Float(std::tan(static_cast<Float*>(#{s})->raw_)))" },
            float_asin: ->(s) { "(new Float(std::asin(static_cast<Float*>(#{s})->raw_)))" },
            float_acos: ->(s) { "(new Float(std::acos(static_cast<Float*>(#{s})->raw_)))" },
            float_atan: ->(s) { "(new Float(std::atan(static_cast<Float*>(#{s})->raw_)))" },
            float_sinh: ->(s) { "(new Float(std::sinh(static_cast<Float*>(#{s})->raw_)))" },
            float_cosh: ->(s) { "(new Float(std::cosh(static_cast<Float*>(#{s})->raw_)))" },
            float_tanh: ->(s) { "(new Float(std::tanh(static_cast<Float*>(#{s})->raw_)))" },
            float_asinh: ->(s) { "(new Float(std::asinh(static_cast<Float*>(#{s})->raw_)))" },
            float_acosh: ->(s) { "(new Float(std::acosh(static_cast<Float*>(#{s})->raw_)))" },
            float_atanh: ->(s) { "(new Float(std::atanh(static_cast<Float*>(#{s})->raw_)))" },
            float_erf: ->(s) { "(new Float(std::erf(static_cast<Float*>(#{s})->raw_)))" },
            float_erfc: ->(s) { "(new Float(std::erfc(static_cast<Float*>(#{s})->raw_)))" },
            float_next_float: ->(s) { "(new Float(std::nextafter(static_cast<Float*>(#{s})->raw_, std::numeric_limits<double>::infinity())))" },
            float_prev_float: ->(s) { "(new Float(std::nextafter(static_cast<Float*>(#{s})->raw_, -std::numeric_limits<double>::infinity())))" },

            # Range — direct field access on the C++ struct (begin_,
            # end_, exclude_end_, initialized_).
            range_allocate: ->(_klass) { "(new Range())" },

            # Fiber — closed-world box-first is single-threaded, single-
            # fiber. fiber_current returns a singleton main Fiber so
            # Fiber[:context] storage works as a global key/value map
            # (FIBER_STORAGE_GLOBAL backs the storage_get/set lowerings).
            fiber_current: ->(_klass) { "([&]() -> BasicObject* { static Fiber* _main = new Fiber(); return _main; }())" },
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
            # Always returning UTF-8 is a stub; real per-string encoding
            # tracking is a parity-gap follow-up.
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

            # Ruby 4.0 "chilled string" concept (frozen-string-literal
            # deprecation phase). Box-first doesn't model the chilled
            # state — strings are either frozen or mutable. So `+@` on
            # a literal just returns self, matching the mutable case.
            string_chilled_q: ->(_self_) { "false_instance()" },

            # Box-first doesn't model encoding transcoding — strings are
            # treated as UTF-8 (or BINARY for raw bytes). Stub encode to
            # return self; encode! is a no-op returning self. This is
            # incorrect for cross-encoding work but covers the common
            # "same encoding" case core/4.0/ exercises during boot.
            string_encode:      ->(self_, _enc, _src_enc, _opts) { "(#{self_})" },
            string_encode_bang: ->(self_, _enc, _src_enc, _opts) { "(#{self_})" },

            # Module method-visibility intrinsics. In closed-world AOT,
            # method visibility is baked into the snapshot — runtime
            # `private :foo` etc. would re-mutate Vm state we've
            # already captured. Stub to nil so core/4.0/'s `private` /
            # `public` / `protected` methods can be evaluated without
            # aborting; the visibility settings they would have made
            # are already in the snapshot from the pre-AOT load phase.
            module_set_private:    ->(_self_, _recv, _names) { "nil_instance()" },
            module_set_public:     ->(_self_, _recv, _names) { "nil_instance()" },
            module_set_protected:  ->(_self_, _recv, _names) { "nil_instance()" },

            string_get_byte: ->(self_, i) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_])))"
            },
            string_setbyte: ->(self_, i, b) {
              "(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_] = static_cast<std::uint8_t>(static_cast<Integer*>(#{b})->raw_), #{b})"
            },
            string_bytesize: ->(self_) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes.size())))"
            },
            # Stubs for box-first; implement properly later. See aotcompile note.
            string_to_f: ->(self_) {
              "([&]() -> BasicObject* { auto* _s = static_cast<String*>(#{self_}); std::string _str(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size()); double _d = 0.0; try { _d = std::stod(_str); } catch (...) {} return new Float(_d); }())"
            },
            string_to_r: ->(_self_) {
              "(&Rational_CLASS)->m_new(univ, new Array({static_cast<BasicObject*>(new Integer(0)), static_cast<BasicObject*>(new Integer(1))}))"
            },
            # `String#to_sym` — interns the string. intern() takes a
            # const char*, so the string must be NUL-terminated. Copy
            # bytes into a std::string for the lookup.

            # Object identity / class — needed by core/4.0 dispatch helpers.
            object_is_a: ->(self_, klass) { "(#{self_})->mm_is_a_q(univ, new Array({#{klass}}))" },
            object_class: ->(self_) { "#{self_}->m_class(univ)" },
            # Kernel#lambda just returns the captured block as a Proc.
            # The Ruby `def lambda(&_block) = Intrinsics.kernel_lambda(self)`
            # form passes self to the intrinsic; the actual block lives
            # in the method's `_block` alias (set up by unpack_params).
            kernel_lambda: ->(_self_) { "static_cast<BasicObject*>(_block)" },
            kernel_proc: ->(_self_) { "static_cast<BasicObject*>(_block)" },
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
            # `re.match?(str, pos)` — short enough to keep inline; doesn't
            # set $~ in MRI but we set it anyway (cheap, simpler code).
            regexp_match_bool: ->(self_, str, pos) {
              "boxed_bool(regexp_match_helper(#{self_}, #{str}, static_cast<Integer*>(#{pos})->raw_) != nullptr)"
            },
            string_match_q: ->(self_, pat, pos) {
              "boxed_bool(regexp_match_helper(#{pat}, #{self_}, ((#{pos}) == nil_instance() ? 0 : static_cast<Integer*>(#{pos})->raw_)) != nullptr)"
            },
            string_unpack: ->(self_, fmt, _offset) { "string_unpack_helper(#{self_}, #{fmt})" },

            string_gsub: ->(self_, pat, repl, block) {
              "string_gsub_helper(#{self_}, #{pat}, #{repl}, ((#{block}) && (#{block})->mm_is_a_q_direct(&Proc_CLASS) ? static_cast<Proc*>(#{block}) : nullptr))"
            },
            string_scan: ->(self_, pat, block) {
              "string_scan_helper(#{self_}, #{pat}, #{block})"
            },
            # `sub` reuses gsub for now — fine when the pattern only
            # matches once. WQ doesn't call sub yet, so an exact `sub`
            # impl can wait.
            string_sub: ->(self_, pat, repl, block) {
              "string_gsub_helper(#{self_}, #{pat}, #{repl}, ((#{block}) && (#{block})->mm_is_a_q_direct(&Proc_CLASS) ? static_cast<Proc*>(#{block}) : nullptr))"
            },

            # MatchData accessors. md[N] (Integer N) routes here.
            match_data_index: ->(self_, n) { "matchdata_cap(#{self_}, static_cast<Integer*>(#{n})->raw_)" },
            match_data_size:  ->(self_) { "(new Integer(static_cast<int64_t>(static_cast<MatchData*>(#{self_})->captures_.size())))" },
            match_data_string: ->(self_) { "(static_cast<MatchData*>(#{self_})->iv_string)" },
            match_data_regexp: ->(self_) { "(static_cast<MatchData*>(#{self_})->iv_regexp)" },
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
              "([&]() -> BasicObject* { auto* _h = static_cast<Hash*>(#{self_}); BasicObject* _v = #{v}; _h->put(#{k}, _v); return _v; }())"
            },
            hash_size: ->(self_) {
              "(new Integer(static_cast<int64_t>(static_cast<Hash*>(#{self_})->live)))"
            },
            hash_clear: ->(self_) { "(static_cast<Hash*>(#{self_})->clear_kvps(), #{self_})" },


            # Object protocol stubs — most return nil/false/empty/self
            # to stop downstream nil.foo cascades. Real impls would
            # need per-class metadata or runtime reflection that
            # box-first doesn't track.
            object_freeze:    ->(self_) { "(#{self_})" },             # stub: no-op (we don't track frozen state)
            object_frozen:    ->(_self_) { "false_instance()" },        # stub: nothing is frozen
            object_methods:   ->(_self_, _all) { "(new Array())" },     # stub: empty list
            # `obj.method(:name)` — box-first has no Method class, but
            # the only thing optparse / most call sites do with the
            # result is `.to_proc`, so return a Proc that re-dispatches
            # via send. Proc#to_proc returns self, so the chain works.
            # Args coming in are the proc's call args (already an Array).
            object_method: ->(self_, name) {
              "(new Proc([__obj_=#{self_}, __name_=#{name}](Array* __args_, Hash*) -> BasicObject* { Array* _full = new Array(); _full->data.push_back(__name_); for (auto* _e : __args_->data) _full->data.push_back(_e); return __obj_->m_send(univ, _full); }))"
            },
            # Dynamic ivar access has no implementation in box-first —
            # every `@foo` is a dedicated C++ struct field (`this->iv_foo`),
            # not an entry in a name→value hash. There's nothing to index
            # by Symbol. Silent stubs returning nil/false/empty mask
            # genuine dynamic-ivar usage in user code as benign no-ops;
            # abort makes the gap visible. (Closing this gap properly is
            # a real design question — see in-flight discussion.)
            object_ivar_get:     ->(_self_, _name)      { %|([](){ std::fprintf(stderr, "[box-first] unimplemented Object#instance_variable_get — dynamic ivar access not supported\\n"); std::abort(); return nil_instance(); }())| },
            object_ivar_set:     ->(_self_, _name, _v)  { %|([](){ std::fprintf(stderr, "[box-first] unimplemented Object#instance_variable_set — dynamic ivar access not supported\\n"); std::abort(); return nil_instance(); }())| },
            object_ivar_defined: ->(_self_, _name)      { %|([](){ std::fprintf(stderr, "[box-first] unimplemented Object#instance_variable_defined? — dynamic ivar access not supported\\n"); std::abort(); return nil_instance(); }())| },
            object_ivar_remove:  ->(_self_, _name)      { %|([](){ std::fprintf(stderr, "[box-first] unimplemented Object#remove_instance_variable — dynamic ivar access not supported\\n"); std::abort(); return nil_instance(); }())| },
            object_ivar_names:   ->(_self_)             { %|([](){ std::fprintf(stderr, "[box-first] unimplemented Object#instance_variables — dynamic ivar enumeration not supported\\n"); std::abort(); return nil_instance(); }())| },
            object_respond_to: ->(self_, name, _include_all) {
              # Forward to the universal mm_respond_to_q — drop
              # include_all (private methods always visible in
              # box-first today; respond_to_q doesn't gate by
              # visibility either).
              "(#{self_})->mm_respond_to_q(univ, new Array({#{name}}))"
            },
            object_instance_of: ->(self_, klass) {
              "boxed_bool(#{self_}->m_class(univ) == (#{klass}))"
            },

            # kernel_block_given stays inline — would need surrounding-
            # scope _block to be a non-stub. Stub: false.
            kernel_block_given: ->(_self_) { "false_instance()" },
            kernel_caller:           ->(_self_, _start, _length) { "(new Array())" },
            kernel_caller_locations: ->(_self_, _start, _length) { "(new Array())" },
            # Closed-world AOT: every BUILD_FILES file is already
            # compiled in. require / require_relative / load are no-ops
            # at runtime — return false ("already loaded"). Diagnostic
            # warning to stderr so callers know the no-op fired (vs
            # MRI's "actually loaded" semantics) — anything reaching
            # this path at runtime is either a code path the gen
            # missed (BUILD_FILES wasn't computed across it) or genuine
            # dynamic loading the closed-world AOT can't support.
            # String-typed paths print the path; non-string gets a
            # generic message.
            kernel_require: ->(_self_, path) {
              %|([&]() -> BasicObject* { auto* _s = ((#{path}) && &typeid(*(#{path})) == &typeid(String)) ? static_cast<String*>(#{path}) : nullptr; std::fprintf(stderr, "[box-first] kernel_require called at runtime \xe2\x80\x94 closed-world AOT can't dynamically load (%.*s)\\n", _s ? (int)_s->bytes.size() : 18, _s ? reinterpret_cast<const char*>(_s->bytes.data()) : "<non-string path>"); return false_instance(); }())|
            },
            kernel_require_relative: ->(_self_, path) {
              %|([&]() -> BasicObject* { auto* _s = ((#{path}) && &typeid(*(#{path})) == &typeid(String)) ? static_cast<String*>(#{path}) : nullptr; std::fprintf(stderr, "[box-first] kernel_require_relative called at runtime \xe2\x80\x94 closed-world AOT can't dynamically load (%.*s)\\n", _s ? (int)_s->bytes.size() : 18, _s ? reinterpret_cast<const char*>(_s->bytes.data()) : "<non-string path>"); return false_instance(); }())|
            },
            kernel_load: ->(_self_, path, _wrap) {
              %|([&]() -> BasicObject* { auto* _s = ((#{path}) && &typeid(*(#{path})) == &typeid(String)) ? static_cast<String*>(#{path}) : nullptr; std::fprintf(stderr, "[box-first] kernel_load called at runtime \xe2\x80\x94 closed-world AOT can't dynamically load (%.*s)\\n", _s ? (int)_s->bytes.size() : 18, _s ? reinterpret_cast<const char*>(_s->bytes.data()) : "<non-string path>"); return false_instance(); }())|
            },
            # `Frozone::Vm::Vm#initialize(options)` — synthetic stub set
            # up by setup_frozone_land for self-hosting. In box-first AOT
            # the only thing kernel_run_vm does is print "no impl"+exit,
            # so saving @options is wasted work. No-op until the box-first
            # Vm is real (would need parser+evaluator compiled in).
            kernel_vm_initialize: ->(_self_, _options) { "nil_instance()" },
            # `Frozone::Vm::Vm#run` — interpreter entry point, no
            # box-first equivalent yet (would need parser + evaluator
            # compiled in). Print a clear no-impl message and exit so
            # the caller doesn't think the run silently succeeded.
            kernel_run_vm: ->(_self_) {
              %|(std::fprintf(stderr, "[box-first] Frozone::Vm::Vm#run not implemented in box-first AOT (would need parser+evaluator compiled in)\\n"), std::exit(1), nil_instance())|
            },

            # ---- String --------------------------------------------
            # Multi-line bodies live in cpp/runtime/intrinsics.hpp;
            # see HPP_INTRINSICS above for the auto-call list.
            # `Symbol#hash` — Symbols are interned so identity (pointer)
            # equality is the canonical equality; pointer-as-int gives
            # a stable hash. Equivalent to BasicObject#__id__.
            symbol_hash: ->(self_) {
              "(new Integer(reinterpret_cast<int64_t>(#{self_})))"
            },

            # ---- Regexp ---------------------------------------------
            # Stubs — Onigmo can enumerate named groups via onig_foreach_name,
            # but we don't yet expose that. Empty {} / [] are correct for
            # most regexes (no named captures used).
            regexp_named_captures: ->(_self_) { "(new Hash())" },
            regexp_names: ->(_self_) { "(new Array())" },
            # `Integer#hash` — MRI uses a salted hash; we just return
            # the integer itself. Good enough for Hash-key purposes
            # (hashing equal ints to equal hashes is the only invariant).
            integer_hash: ->(self_) {
              "(new Integer(static_cast<Integer*>(#{self_})->raw_))"
            },

            # ---- Module / Class -------------------------------------
            # `Module#name` — class.name returns the qualified Ruby name
            # as a String. ruby_class_name() is auto-emitted on every
            # class struct via with_auto_overrides.
            module_name: ->(self_) {
              "([&]() -> BasicObject* { const char* _n = (#{self_})->ruby_class_name(); return new String(_n, std::strlen(_n)); }())"
            },

            # ---- Proc -----------------------------------------------
            # `Proc#call(*args, **kwargs)` — invoke the lambda. Routes
            # through the universal m_call slot (Proc subclass overrides
            # m_call to invoke its stored function pointer). args is
            # the *args rest_param which MethodEmitter.unpack_params
            # types BasicObject* even though it's always Array at
            # runtime — splat_to_array's m_class() fast-path is the
            # safe coercion (no static_cast). Hash narrowing on kwargs
            # uses typeid (Hash is a leaf class); fall back to
            # &EMPTY_KWARGS so we never pass nullptr.
            proc_call: ->(self_, args, kwargs) {
              "((#{self_})->m_call(univ, splat_to_array(#{args}), [&]() -> Hash* { return ((#{kwargs}) && &typeid(*(#{kwargs})) == &typeid(Hash)) ? static_cast<Hash*>(#{kwargs}) : &EMPTY_KWARGS; }()))"
            },
            # `Proc#arity` — stub returning -1 (variable-arity). We don't
            # track block arity at AOT time; -1 is MRI's default for
            # &-blocks with rest args, and harmless for callers that
            # check arity for warning purposes.
            proc_arity: ->(_self_) { "(new Integer(-1))" },
            # `Proc#lambda?` — stub. We don't distinguish Procs from
            # lambdas (every block becomes a Proc with default-Proc
            # semantics). Returning false matches the more permissive
            # arity behaviour user code typically expects.
            proc_lambda_p: ->(_self_) { "false_instance()" },
          }.freeze
        end
      end
    end
  end
end

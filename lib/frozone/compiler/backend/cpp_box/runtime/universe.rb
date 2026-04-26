# Box-first runtime universe — declarative definitions of the runtime
# Ruby class hierarchy + Kernel free functions.
#
# This file contains DATA, not emission logic. The ClassEmitter
# consumes these structs and produces C++ source. Adding a new runtime
# class = adding a `RubyClass` constant; adding a method to BasicObject's
# universal surface = appending one cpp method name to call_surface
# (computed by the orchestrator from the program's call universe).
#
# Long-term: Integer's overrides (and similar) will come from compiling
# `lib/core/4.0/integer.rb`. The shape this emitter consumes won't
# change — just the source of the bodies.

module Frozone
  module Compiler
    module Backend
      module CppBox
        module Runtime
          # Declarative description of an emitted class.
          #
          # Fields:
          #   name       — C++ class name (in `namespace Ruby`)
          #   parent     — parent class name, or nil for the root
          #   ivars      — array of cpp ivar decl strings ("int64_t raw_;")
          #   members    — array of freeform cpp lines emitted inside the
          #                class body (ctor, ruby_class_name override, etc.)
          #   overrides  — { cpp_method_name => { params: [...], body: cpp } }
          #                each emitted as `BasicObject* name(...) override { body }`
          #   singleton  — if non-nil, file-scope instance variable name
          #                ("NIL_INSTANCE" etc.)
          RubyClass = Struct.new(
            :name, :parent, :ivars, :members, :ctor, :overrides, :singleton,
            :hand_coded_method_names, :eigenclass_overrides, :eigenclass_ivars,
            keyword_init: true
          )

          # Declarative description of a free C++ function emitted at
          # namespace scope alongside the classes.
          #
          # Fields:
          #   name      — cpp function name
          #   signature — cpp signature without the body braces
          #               ("BasicObject* boxed_bool(bool b)")
          #   body      — cpp body, the bit between the braces
          KernelFn = Struct.new(:name, :signature, :body, keyword_init: true)

          # Intrinsic — a C++ free function the compiled-from-Ruby method
          # bodies dispatch into for low-level primitive ops. Same shape
          # as KernelFn but logically distinct: KernelFns are runtime
          # helpers (truthy, ruby_puts, instance accessors); Intrinsics
          # are the unboxed-operation primitives that Ruby `def +(v) =
          # Intrinsics.integer__plus_(self, v)` style methods bottom
          # out into.
          #
          # Currently empty (Integer/etc. method bodies are still
          # hand-coded inline). Populated when we source from core/4.0/.
          IntrinsicFn = Struct.new(:name, :signature, :body, keyword_init: true)

          # ---- Class definitions -----------------------------------

          BASIC_OBJECT = RubyClass.new(
            name: "BasicObject",
            parent: nil,
            members: [
              "// All box-first allocations route through Boehm. Without",
              "// this, plain `new X(...)` uses libc malloc and Boehm never",
              "// collects — instant OOM on any allocation-heavy benchmark.",
              "static void* operator new(std::size_t n) { return GC_MALLOC(n); }",
              "static void operator delete(void*) {}  // Boehm collects",
              "",
              "virtual ~BasicObject() = default;",
              %(virtual const char* ruby_class_name() const { return "BasicObject"; }),
              "// method_missing — base aborts; subclasses can override.",
              "virtual BasicObject* method_missing(const char* method_name) {",
              %(  std::fprintf(stderr, "[box-first] method_missing: %s#%s\\n", ruby_class_name(), method_name);),
              "  std::abort();",
              "}",
              "// Hand-coded m_eq_q / m_hash_value / m_case_eq — these need",
              "// sensible defaults rather than method_missing. m_hash_value",
              "// is C++-internal (returns size_t for std::unordered_map),",
              "// not a Ruby vtable method. m_eq_q and m_case_eq use the",
              "// universal Ruby method signature (Array*, Hash*, Proc*).",
              "virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return boxed_bool(this == array_at(args, 0));",
              "}",
              "virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }",
              "// m_case_eq (===) defaults to m_eq_q per Ruby semantics.",
              "virtual BasicObject* m_case_eq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return m_eq_q(args, kwargs, block);",
              "}",
              "// nil? defaults to false; NilClass overrides to true.",
              "virtual BasicObject* m_nil_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return false_instance();",
              "}",
              "// initialize default — no-op returning self. User classes",
              "// override; eigenclass m_new always invokes this after",
              "// allocating the new instance.",
              "virtual BasicObject* m_initialize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return this;",
              "}",
              "// freeze / frozen? — we don't enforce frozen state, so",
              "// these are no-ops returning self / false. Lots of core",
              "// code calls .freeze on initialization; without these,",
              "// every freeze call hits method_missing.",
              "virtual BasicObject* m_freeze(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return this;",
              "}",
              "virtual BasicObject* m_frozen_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return false_instance();",
              "}",
              "// respond_to? — optimistic default returns true. Real",
              "// answer requires a method-name table per class; without",
              "// this default, every respond_to? in core libs aborts via",
              "// method_missing.",
              "virtual BasicObject* m_respond_to_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return true_instance();",
              "}",
            ],
            # Methods listed here are skipped by the universal-surface
            # emitter — either hand-declared in members above OR
            # auto-emitted by class_emitter as an override (m_class).
            hand_coded_method_names: %w[
              m_eq_q m_hash_value m_case_eq m_nil_q m_initialize
              m_freeze m_frozen_q m_class m_respond_to_q
            ].freeze,
          )

          OBJECT = RubyClass.new(
            name: "Object",
            parent: "BasicObject",
            members: [%(const char* ruby_class_name() const override { return "Object"; })],
          )

          # Class — the metaclass type. Every emitted class Foo has a
          # paired eigenclass `Foo_eigenclass : Class` that holds Foo's
          # class methods (def self.X) as virtuals. The Foo *constant*
          # in user code is a singleton instance of Foo_eigenclass.
          # Class itself is currently empty — class-method defaults
          # (allocate, new, name) will land here when needed.
          CLASS_TYPE = RubyClass.new(
            name: "Class",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "Class"; })],
          )

          NIL_CLASS = RubyClass.new(
            name: "NilClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "NilClass"; })],
            singleton: "NIL_INSTANCE",
            overrides: {
              "m_to_s"  => { params: [], body: %(return new String("", 0);) },
              "m_nil_q" => { params: [], body: "return true_instance();" },
            },
          )

          TRUE_CLASS = RubyClass.new(
            name: "TrueClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "TrueClass"; })],
            singleton: "TRUE_INSTANCE",
            overrides: {
              "m_to_s" => { params: [], body: %(return new String("true", 4);) },
            },
          )

          FALSE_CLASS = RubyClass.new(
            name: "FalseClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "FalseClass"; })],
            singleton: "FALSE_INSTANCE",
            overrides: {
              "m_to_s" => { params: [], body: %(return new String("false", 5);) },
            },
          )

          INTEGER = RubyClass.new(
            name: "Integer",
            parent: "Object",
            ivars: ["int64_t raw_;"],
            members: [
              "Integer() = default;  // for eigenclass m_new (raw_ stays 0-ish)",
              "explicit Integer(int64_t r) : raw_(r) {}",
              %(const char* ruby_class_name() const override { return "Integer"; }),
              "// m_hash_value override — value-based so Integer keys hash",
              "// equal regardless of box identity.",
              "std::size_t m_hash_value() const override { return std::hash<int64_t>()(raw_); }",
            ],
            overrides: {
              "m_plus"     => { params: ["BasicObject* other"], body: "return new Integer(raw_ + static_cast<Integer*>(other)->raw_);" },
              "m_minus"    => { params: ["BasicObject* other"], body: "return new Integer(raw_ - static_cast<Integer*>(other)->raw_);" },
              "m_mul"      => { params: ["BasicObject* other"], body: "return new Integer(raw_ * static_cast<Integer*>(other)->raw_);" },
              "m_div"      => { params: ["BasicObject* other"], body: "return new Integer(raw_ / static_cast<Integer*>(other)->raw_);" },
              "m_mod"      => { params: ["BasicObject* other"], body: "return new Integer(raw_ % static_cast<Integer*>(other)->raw_);" },
              "m_lt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <  static_cast<Integer*>(other)->raw_);" },
              "m_gt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >  static_cast<Integer*>(other)->raw_);" },
              "m_le"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <= static_cast<Integer*>(other)->raw_);" },
              "m_ge"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >= static_cast<Integer*>(other)->raw_);" },
              "m_eq_q"     => { params: ["BasicObject* other"], body: "auto* o = dynamic_cast<Integer*>(other); return boxed_bool(o && raw_ == o->raw_);" },
              "m_ne_q"     => { params: ["BasicObject* other"], body: "auto* o = dynamic_cast<Integer*>(other); return boxed_bool(!o || raw_ != o->raw_);" },
              "m_lshift"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ << static_cast<Integer*>(other)->raw_);" },
              "m_rshift"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ >> static_cast<Integer*>(other)->raw_);" },
              "m_bit_and"  => { params: ["BasicObject* other"], body: "return new Integer(raw_ &  static_cast<Integer*>(other)->raw_);" },
              "m_bit_or"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ |  static_cast<Integer*>(other)->raw_);" },
              "m_bit_xor"  => { params: ["BasicObject* other"], body: "return new Integer(raw_ ^  static_cast<Integer*>(other)->raw_);" },
              "m_neg"      => { params: [],                     body: "return new Integer(-raw_);" },
              "m_to_s"     => {
                params: [],
                body: <<~CPP.chomp,
                  char buf[32];
                  int n = std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(raw_));
                  return new String(buf, static_cast<std::size_t>(n));
                CPP
              },
              "m_to_i"     => { params: [], body: "return this;" },
            },
          )

          # Float — wraps `double raw_`. Same shape as Integer; Float
          # methods don't know about Integer (mixed Integer/Float
          # arithmetic would static_cast wrong and crash). Coercion
          # protocol is a separate concern — defer until a benchmark
          # actually needs mixed numeric types.
          FLOAT = RubyClass.new(
            name: "Float",
            parent: "Object",
            ivars: ["double raw_;"],
            members: [
              "Float() = default;",
              "explicit Float(double r) : raw_(r) {}",
              %(const char* ruby_class_name() const override { return "Float"; }),
              "std::size_t m_hash_value() const override { return std::hash<double>()(raw_); }",
            ],
            overrides: {
              "m_plus"     => { params: ["BasicObject* other"], body: "return new Float(raw_ + static_cast<Float*>(other)->raw_);" },
              "m_minus"    => { params: ["BasicObject* other"], body: "return new Float(raw_ - static_cast<Float*>(other)->raw_);" },
              "m_mul"      => { params: ["BasicObject* other"], body: "return new Float(raw_ * static_cast<Float*>(other)->raw_);" },
              "m_div"      => { params: ["BasicObject* other"], body: "return new Float(raw_ / static_cast<Float*>(other)->raw_);" },
              "m_lt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <  static_cast<Float*>(other)->raw_);" },
              "m_gt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >  static_cast<Float*>(other)->raw_);" },
              "m_le"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <= static_cast<Float*>(other)->raw_);" },
              "m_ge"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >= static_cast<Float*>(other)->raw_);" },
              "m_eq_q"     => { params: ["BasicObject* other"], body: "auto* o = dynamic_cast<Float*>(other); return boxed_bool(o && raw_ == o->raw_);" },
              "m_ne_q"     => { params: ["BasicObject* other"], body: "auto* o = dynamic_cast<Float*>(other); return boxed_bool(!o || raw_ != o->raw_);" },
              "m_neg"      => { params: [],                     body: "return new Float(-raw_);" },
              "m_to_s"     => {
                params: [],
                body: <<~CPP.chomp,
                  char buf[32];
                  int n = std::snprintf(buf, sizeof(buf), "%g", raw_);
                  return new String(buf, static_cast<std::size_t>(n));
                CPP
              },
              "m_to_f"     => { params: [], body: "return this;" },
            },
          )

          # ---- Container types ------------------------------------
          #
          # "Truly core" — bound to native C++ data structure templates.
          # Implementing in pure Ruby would require first implementing
          # the data-structure machinery in pure Ruby, which is where
          # the bootstrap chain ends. So container methods stay as
          # hand-coded shims around C++ data structures (here:
          # std::vector / std::unordered_map keyed on identity for now).

          ARRAY = RubyClass.new(
            name: "Array",
            parent: "Object",
            members: [
              "// Vector uses GcAllocator so the buffer stays scanned by Boehm.",
              "std::vector<BasicObject*, GcAllocator<BasicObject*>> data;",
              "Array() = default;",
              "Array(std::initializer_list<BasicObject*> init) : data(init.begin(), init.end()) {}",
              "// Array.new(size) / Array.new(size, fill)",
              "Array(BasicObject* size, BasicObject* fill = nullptr) {",
              "  int64_t n = static_cast<Integer*>(size)->raw_;",
              "  data.assign(n, fill ? fill : nil_instance());",
              "}",
              %(const char* ruby_class_name() const override { return "Array"; }),
            ],
            overrides: {
              "m_size" => {
                params: [],
                body: "return new Integer(static_cast<int64_t>(data.size()));",
              },
              "m_length" => {
                params: [],
                body: "return new Integer(static_cast<int64_t>(data.size()));",
              },
              "m_empty_q" => {
                params: [],
                body: "return boxed_bool(data.empty());",
              },
              "m_first" => {
                params: [],
                body: "return data.empty() ? nil_instance() : data.front();",
              },
              "m_last" => {
                params: [],
                body: "return data.empty() ? nil_instance() : data.back();",
              },
              "m_aref" => {
                params: ["BasicObject* idx"],
                body: <<~CPP.chomp,
                  int64_t i = static_cast<Integer*>(idx)->raw_;
                  if (i < 0) i += static_cast<int64_t>(data.size());
                  if (i < 0 || i >= static_cast<int64_t>(data.size())) return nil_instance();
                  return data[i];
                CPP
              },
              "m_aset" => {
                params: ["BasicObject* idx", "BasicObject* val"],
                body: <<~CPP.chomp,
                  int64_t i = static_cast<Integer*>(idx)->raw_;
                  if (i < 0) i += static_cast<int64_t>(data.size());
                  if (i >= static_cast<int64_t>(data.size())) data.resize(i + 1, nil_instance());
                  data[i] = val;
                  return val;
                CPP
              },
              "m_push" => {
                params: ["BasicObject* val"],
                body: "data.push_back(val); return this;",
              },
              "m_lshift" => {
                params: ["BasicObject* val"],
                body: "data.push_back(val); return this;",
              },
              # Array.new(size) / Array.new(size, fill) — m_new on the
              # eigenclass dispatches m_initialize after default-
              # constructing. Without this, .new(size, fill) wouldn't
              # populate the storage; only literal `(new Array({...}))`
              # paths work via the internal initializer_list ctor.
              "m_initialize" => {
                params: [],
                body: <<~CPP.chomp,
                  if (args->data.empty()) return this;
                  int64_t n = static_cast<Integer*>(args->data[0])->raw_;
                  BasicObject* fill = args->data.size() >= 2 ? args->data[1] : nil_instance();
                  data.assign(n, fill);
                  return this;
                CPP
              },
            },
          )

          # Symbol — wraps an interned string. Identity-based equality
          # (intern() returns the same Symbol* for the same name) means
          # default m_eq_q (pointer eq) + default m_hash_value (pointer
          # hash) work correctly. Symbol literals emit as `intern("foo")`.
          #
          # The ctor is private — `intern()` is the only friend — so no
          # one can bypass interning and produce a non-canonical Symbol*.
          # Without this, a stray `new Symbol("x")` elsewhere would give
          # a Symbol* that compares unequal to the interned one, silently
          # breaking Hash lookups.
          SYMBOL = RubyClass.new(
            name: "Symbol",
            parent: "Object",
            members: [
              "const char* name_;",
              "private:",
              "  explicit Symbol(const char* name) : name_(name) {}",
              "  friend Symbol* intern(const char* name);",
              "public:",
              %(const char* ruby_class_name() const override { return "Symbol"; }),
            ],
            overrides: {
              "m_to_s"  => { params: [], body: "return new String(name_);" },
              "m_to_sym" => { params: [], body: "return this;" },
            },
            # Symbol's ctor is private — `Symbol.new` is meaningless in
            # Ruby anyway. Override the eigenclass auto-m_new with an
            # explicit abort.
            eigenclass_overrides: {
              "m_new" => {
                params: [],
                body: %(std::fprintf(stderr, "[box-first] Symbol.new not supported — use literals\\n"); std::abort();),
              },
            },
          )

          # String — byte buffer + encoding tag (UTF-8 or BINARY).
          # Logic duped from mainline's RubyString (cpp/runtime/frozone.hpp)
          # — encoding promotion on concat, codepoint-aware length for
          # UTF-8, byte comparison for ordering. Buffer uses GcAllocator
          # so Boehm sees it (otherwise the bytes would leak when Boehm
          # reclaims the String — Boehm doesn't run destructors).
          STRING = RubyClass.new(
            name: "String",
            parent: "Object",
            members: [
              "enum Enc { UTF8 = 0, BINARY = 1 };",
              "std::vector<std::uint8_t, GcAllocator<std::uint8_t>> bytes;",
              "Enc enc = UTF8;",
              "mutable std::int64_t length_cache_ = -1;",
              "",
              "String() = default;",
              "String(const char* s) { if (s) { auto n = std::strlen(s); bytes.assign(s, s + n); } }",
              "String(const char* s, std::size_t n) { bytes.assign(s, s + n); }",
              "String(const char* s, std::size_t n, Enc e) : enc(e) { bytes.assign(s, s + n); }",
              "",
              %(const char* ruby_class_name() const override { return "String"; }),
              "",
              "// Codepoint-aware length for UTF-8 (cached); byte count for BINARY.",
              "std::int64_t length() const {",
              "  if (enc == BINARY) return static_cast<std::int64_t>(bytes.size());",
              "  if (length_cache_ < 0) {",
              "    std::int64_t n = 0;",
              "    for (auto b : bytes) if ((b & 0xC0) != 0x80) n++;",
              "    length_cache_ = n;",
              "  }",
              "  return length_cache_;",
              "}",
              "bool has_non_ascii() const { for (auto b : bytes) if (b >= 0x80) return true; return false; }",
              "",
              "// Hash on byte sequence — equal byte sequences hash equal.",
              "std::size_t m_hash_value() const override {",
              "  std::size_t h = 0xcbf29ce484222325ULL;  // FNV-1a offset",
              "  for (auto b : bytes) { h ^= b; h *= 0x100000001b3ULL; }",
              "  return h;",
              "}",
            ],
            overrides: {
              "m_size"     => { params: [], body: "return new Integer(length());" },
              "m_length"   => { params: [], body: "return new Integer(length());" },
              "m_bytesize" => { params: [], body: "return new Integer(static_cast<std::int64_t>(bytes.size()));" },
              "m_empty_q"  => { params: [], body: "return boxed_bool(bytes.empty());" },
              "m_to_s"     => { params: [], body: "return this;" },
              "m_eq_q"     => {
                params: ["BasicObject* other"],
                body: "auto* o = dynamic_cast<String*>(other); return boxed_bool(o && bytes == o->bytes);",
              },
              "m_ne_q"     => {
                params: ["BasicObject* other"],
                body: "auto* o = dynamic_cast<String*>(other); return boxed_bool(!o || bytes != o->bytes);",
              },
              "m_lt"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes <  static_cast<String*>(other)->bytes);" },
              "m_gt"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes >  static_cast<String*>(other)->bytes);" },
              "m_le"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes <= static_cast<String*>(other)->bytes);" },
              "m_ge"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes >= static_cast<String*>(other)->bytes);" },
              "m_plus"     => {
                params: ["BasicObject* other"],
                body: <<~CPP.chomp,
                  auto* o = static_cast<String*>(other);
                  String* r = new String();
                  r->enc = (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) ? UTF8 : enc;
                  r->bytes.reserve(bytes.size() + o->bytes.size());
                  r->bytes.insert(r->bytes.end(), bytes.begin(), bytes.end());
                  r->bytes.insert(r->bytes.end(), o->bytes.begin(), o->bytes.end());
                  return r;
                CPP
              },
              "m_lshift"   => {
                params: ["BasicObject* other"],
                body: <<~CPP.chomp,
                  auto* o = static_cast<String*>(other);
                  // MRI encoding promotion: BINARY + UTF-8 non-ASCII → UTF-8.
                  if (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) enc = UTF8;
                  bytes.insert(bytes.end(), o->bytes.begin(), o->bytes.end());
                  length_cache_ = -1;
                  return this;
                CPP
              },
              "m_aref"     => {
                params: ["BasicObject* idx"],
                body: <<~CPP.chomp,
                  std::int64_t i = static_cast<Integer*>(idx)->raw_;
                  if (i < 0) i += static_cast<std::int64_t>(bytes.size());
                  if (i < 0 || i >= static_cast<std::int64_t>(bytes.size())) return nil_instance();
                  return new String(reinterpret_cast<const char*>(&bytes[i]), 1, enc);
                CPP
              },
              "m_ord"      => { params: [], body: "return new Integer(bytes.empty() ? 0 : static_cast<std::int64_t>(bytes[0]));" },
              "m_dup"      => {
                params: [],
                body: <<~CPP.chomp,
                  String* r = new String();
                  r->bytes = bytes;
                  r->enc = enc;
                  return r;
                CPP
              },
              "m_b"        => {
                params: [],
                body: <<~CPP.chomp,
                  String* r = new String();
                  r->bytes = bytes;
                  r->enc = BINARY;
                  return r;
                CPP
              },
            },
            hand_coded_method_names: %w[m_hash_value].freeze,
          )

          # Proc — wraps a C++ std::function for block/lambda
          # closures. `m_call(arg)` invokes it. Simple blocks only:
          # arity 0 or 1 (the arg is nil_instance() when yield has no
          # args). Multi-arity / kw_args / block-from-method-object —
          # all deferred. Created at call sites where a block is
          # passed: `foo { |x| ... }` becomes
          #   `(new Proc([&](BasicObject* arg) -> BasicObject* { ... }))`
          # passed as last arg to foo. Methods containing `yield` get
          # an implicit `Proc* _block = nullptr` last param (added by
          # MethodEmitter.build_params).
          PROC = RubyClass.new(
            name: "Proc",
            parent: "Object",
            members: [
              "std::function<BasicObject*(BasicObject*)> fn_;",
              "Proc() = default;",
              "explicit Proc(std::function<BasicObject*(BasicObject*)> f) : fn_(std::move(f)) {}",
              %(const char* ruby_class_name() const override { return "Proc"; }),
            ],
            overrides: {
              "m_call" => { params: ["BasicObject* arg"], body: "return fn_(arg);" },
            },
          )

          # Hash — std::unordered_map keyed by BasicObject* with a
          # custom Hasher (calls m_hash_value via vtable) and KeyEq
          # (calls m_eq_q via vtable). Bucket storage uses GcAllocator
          # so Boehm traces the value pointers.
          HASH = RubyClass.new(
            name: "Hash",
            parent: "Object",
            members: [
              "// Vtable-aware hash + key-equality.",
              "struct Hasher {",
              "  std::size_t operator()(BasicObject* v) const { return v->m_hash_value(); }",
              "};",
              "struct KeyEq {",
              "  bool operator()(BasicObject* a, BasicObject* b) const {",
              "    Array tmp;",
              "    tmp.data.push_back(b);",
              "    return a->m_eq_q(&tmp, nullptr, nullptr) == true_instance();",
              "  }",
              "};",
              "using map_t = std::unordered_map<",
              "  BasicObject*, BasicObject*, Hasher, KeyEq,",
              "  GcAllocator<std::pair<BasicObject* const, BasicObject*>>>;",
              "map_t data;",
              "Hash() = default;",
              "Hash(std::initializer_list<std::pair<BasicObject*, BasicObject*>> init) {",
              "  for (auto& p : init) data.insert(p);",
              "}",
              %(const char* ruby_class_name() const override { return "Hash"; }),
            ],
            overrides: {
              "m_size"   => { params: [], body: "return new Integer(static_cast<int64_t>(data.size()));" },
              "m_length" => { params: [], body: "return new Integer(static_cast<int64_t>(data.size()));" },
              "m_empty_q"=> { params: [], body: "return boxed_bool(data.empty());" },
              "m_aref"   => {
                params: ["BasicObject* k"],
                body: <<~CPP.chomp,
                  auto it = data.find(k);
                  return (it == data.end()) ? nil_instance() : it->second;
                CPP
              },
              "m_aset"   => {
                params: ["BasicObject* k", "BasicObject* v"],
                body: "data[k] = v; return v;",
              },
              "m_include_q" => {
                params: ["BasicObject* k"],
                body: "return boxed_bool(data.find(k) != data.end());",
              },
              "m_has_key_q" => {
                params: ["BasicObject* k"],
                body: "return boxed_bool(data.find(k) != data.end());",
              },
            },
          )

          # Inheritance order. The emitter walks this list to produce
          # forward decls + class bodies + singletons in the right
          # sequence (parent before child, so children's overrides see
          # the parent's vtable layout).
          ALL_CLASSES = [
            BASIC_OBJECT, OBJECT, CLASS_TYPE,
            NIL_CLASS, TRUE_CLASS, FALSE_CLASS,
            INTEGER, FLOAT, ARRAY, SYMBOL, STRING, HASH, PROC
          ].freeze

          # Per-class eigenclass — generated programmatically from each
          # RubyClass entry. Class methods (def self.X) live as virtuals
          # on these. The singleton instance `<Name>_CLASS` is what
          # Ruby code refers to when it writes the bare class name as a
          # value (`Integer`, `Foo`, etc.).
          #
          # Class itself gets an eigenclass too (its eigenclass IS Class
          # itself in a strict Ruby sense, but we mirror the universal
          # pattern — `Class_eigenclass : Class` — so user code that
          # writes `Class` as a value resolves to `&Class_CLASS`).
          def self.eigenclass_for(klass)
            user_overrides = klass.eigenclass_overrides || {}
            # Auto-generate m_new: allocate the instance + dispatch
            # m_initialize via the universal protocol. User-overridable
            # — if a user class defines its own `def self.new`, that
            # takes precedence (same key).
            overrides = user_overrides.dup
            overrides["m_new"] ||= {
              params: [],
              body: <<~CPP.chomp,
                #{klass.name}* obj = new #{klass.name}();
                obj->m_initialize(args, kwargs, block);
                return obj;
              CPP
            }
            RubyClass.new(
              name: "#{klass.name}_eigenclass",
              parent: "Class",
              ivars: (klass.eigenclass_ivars || []).map { |iv| "BasicObject* iv_#{iv} = nullptr;" },
              members: [%(const char* ruby_class_name() const override { return "#{klass.name}"; })],
              overrides: overrides,
              singleton: "#{klass.name}_CLASS",
            )
          end

          ALL_EIGENCLASSES = ALL_CLASSES.map { |k| eigenclass_for(k) }.compact.freeze

          # ---- Free Kernel functions -------------------------------

          # nil_instance / true_instance / false_instance — forward-declared
          # so class bodies can use them without needing the singleton's
          # full type to be in scope (the NilClass→BasicObject conversion
          # requires complete-type visibility, which we don't have inside
          # class member function bodies before NilClass is defined).
          NIL_INSTANCE_FN = KernelFn.new(
            name: "nil_instance",
            signature: "BasicObject* nil_instance()",
            body: "return static_cast<BasicObject*>(&NIL_INSTANCE);",
          )

          TRUE_INSTANCE_FN = KernelFn.new(
            name: "true_instance",
            signature: "BasicObject* true_instance()",
            body: "return static_cast<BasicObject*>(&TRUE_INSTANCE);",
          )

          FALSE_INSTANCE_FN = KernelFn.new(
            name: "false_instance",
            signature: "BasicObject* false_instance()",
            body: "return static_cast<BasicObject*>(&FALSE_INSTANCE);",
          )

          BOXED_BOOL = KernelFn.new(
            name: "boxed_bool",
            signature: "BasicObject* boxed_bool(bool b)",
            body: "return b ? true_instance() : false_instance();",
          )

          TRUTHY = KernelFn.new(
            name: "truthy",
            signature: "bool truthy(BasicObject* o)",
            body: "return o != nil_instance() && o != false_instance();",
          )

          RUBY_PUTS = KernelFn.new(
            name: "ruby_puts",
            signature: "void ruby_puts(BasicObject* o)",
            body: <<~CPP.chomp,
              if (auto* i = dynamic_cast<Integer*>(o))      { std::printf("%lld\\n", static_cast<long long>(i->raw_)); return; }
              if (auto* f = dynamic_cast<Float*>(o))        { std::printf("%g\\n", f->raw_); return; }
              if (auto* s = dynamic_cast<Symbol*>(o))       { std::printf("%s\\n", s->name_); return; }
              if (auto* str = dynamic_cast<String*>(o))     { std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout); std::putchar('\\n'); return; }
              if (o == true_instance())                      { std::printf("true\\n"); return; }
              if (o == false_instance())                     { std::printf("false\\n"); return; }
              if (o == nil_instance())                       { std::printf("\\n"); return; }
              std::printf("(unprintable: %s)\\n", o->ruby_class_name());
            CPP
          )

          # array_at — bridges the forward-decl gap. Method bodies in
          # classes defined BEFORE Array (BasicObject, Object, Integer,
          # Float) need to unpack args via `args->data[i]`, but Array is
          # forward-declared at that point (member access requires
          # complete type). This helper is forward-declared early and
          # defined after Array, so callers see only the signature
          # during class-body parsing.
          ARRAY_AT_FN = KernelFn.new(
            name: "array_at",
            signature: "BasicObject* array_at(Array* a, std::size_t i)",
            body: "return a->data[i];",
          )

          # Symbol interning. Same name → same Symbol* (identity = equality,
          # so default m_eq_q + m_hash_value work). Intern table uses
          # GcAllocator so the symbols stay rooted under Boehm.
          INTERN_FN = KernelFn.new(
            name: "intern",
            signature: "Symbol* intern(const char* name)",
            body: <<~CPP.chomp,
              using Tab = std::unordered_map<std::string, Symbol*,
                std::hash<std::string>, std::equal_to<std::string>,
                GcAllocator<std::pair<const std::string, Symbol*>>>;
              static Tab table;
              auto it = table.find(name);
              if (it != table.end()) return it->second;
              Symbol* s = new Symbol(name);
              table[std::string(name)] = s;
              return s;
            CPP
          )

          ALL_KERNEL_FNS = [
            NIL_INSTANCE_FN, TRUE_INSTANCE_FN, FALSE_INSTANCE_FN,
            BOXED_BOOL, TRUTHY, RUBY_PUTS, INTERN_FN, ARRAY_AT_FN
          ].freeze

          # ---- Intrinsics -----------------------------------------
          #
          # Empty for now. Populated when methods are sourced from
          # core/4.0/ — `def +(v) = Intrinsics.integer__plus_(self, v)`
          # in Ruby compiles to a call into one of these.
          ALL_INTRINSICS = [].freeze
        end
      end
    end
  end
end

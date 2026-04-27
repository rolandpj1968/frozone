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

          # In MRI, BasicObject is intentionally minimal — instance
          # methods are just ==, !=, !, equal?, __id__, __send__,
          # method_missing, instance_eval, instance_exec, plus the
          # singleton_method_* hooks. Everything else (is_a?, class,
          # send, freeze, nil?, respond_to?, dup, to_s, …) lives on
          # Kernel and is mixed into Object. We mirror that — the
          # bodies that need C++ layout awareness (LUT-based is_a?,
          # METHOD_VT-based send, eigenclass-returning class) live on
          # Object, not BasicObject. A user `class Foo < BasicObject`
          # genuinely lacks is_a?, freeze, etc. — `bo.is_a?(...)`
          # falls through to BasicObject's method_missing stub.
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
              "// == default — pointer identity (BasicObject#==).",
              "virtual BasicObject* m_eq_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return boxed_bool(this == array_at(args, 0));",
              "}",
              "// m_hash_value — C++-internal hook for std::unordered_map<BasicObject*,…>.",
              "// Not a Ruby method (Ruby's #hash returns Integer; this returns size_t).",
              "virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }",
              "// equal? — pointer identity (BasicObject#equal?). Distinct from",
              "// `==` which subclasses often override for value equality.",
              "virtual BasicObject* m_equal_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return boxed_bool(this == array_at(args, 0));",
              "}",
              "// __id__ — pointer cast as integer. Closed-world: each",
              "// object has a unique address; that's the id. Note that",
              "// Ruby's #object_id is on Kernel, not BasicObject.",
              "virtual BasicObject* m___id__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return int_box(reinterpret_cast<std::int64_t>(this));",
              "}",
              "// initialize default — no-op returning self. User classes",
              "// override; eigenclass m_new always invokes this after",
              "// allocating the new instance.",
              "virtual BasicObject* m_initialize(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {",
              "  return this;",
              "}",
              "// __class_id__ — closed-world class identity. Returns -1",
              "// for non-class instances (so they hit the false branch in",
              "// the IS_A LUT walker on Object). Class instances override.",
              "virtual int __class_id__() const { return -1; }",
            ],
            # Genuine BasicObject methods. Other intrinsic-style methods
            # (m_class, m_send, m_is_a_q, etc.) live on Object and are
            # listed in OBJECT.hand_coded_method_names.
            hand_coded_method_names: %w[
              m_eq_q m_hash_value m_equal_q m___id__ m_initialize
            ].freeze,
          )

          OBJECT = RubyClass.new(
            name: "Object",
            parent: "BasicObject",
            members: [
              %(const char* ruby_class_name() const override { return "Object"; }),
              "// === defaults to ==. Module/Class override for `Class === obj`.",
              "virtual BasicObject* m_case_eq(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return m_eq_q(args, kwargs, block);",
              "}",
              "// nil? defaults to false; NilClass overrides to true.",
              "virtual BasicObject* m_nil_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return false_instance();",
              "}",
              "// freeze / frozen? — we don't enforce frozen state, so",
              "// these are no-ops returning self / false. Lots of core",
              "// code calls .freeze on initialization; this stays cheap.",
              "virtual BasicObject* m_freeze(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return this;",
              "}",
              "virtual BasicObject* m_frozen_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return false_instance();",
              "}",
              "// object_id — Kernel#object_id. Same value as __id__.",
              "virtual BasicObject* m_object_id(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return m___id__(args, kwargs, block);",
              "}",
              "// is_a? / kind_of? / instance_of? — closed-world LUT. m_is_a_q",
              "// body is emitted out-of-line by class_emitter (write_is_a_lut)",
              "// once all classes are complete.",
              "virtual BasicObject* m_is_a_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;",
              "// send / __send__ — METHOD_VT-based dispatch. Out-of-line body",
              "// emitted by class_emitter (write_send_body) once Array is complete.",
              "virtual BasicObject* m_send(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;",
              "virtual BasicObject* m___send__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override;",
              "virtual BasicObject* m_kind_of_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return m_is_a_q(args, kwargs, block);",
              "}",
              "virtual BasicObject* m_instance_of_q(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) override {",
              "  return boxed_bool(m_class(args, kwargs, block) == array_at(args, 0));",
              "}",
            ],
            hand_coded_method_names: %w[
              m_case_eq m_nil_q m_freeze m_frozen_q m_object_id
              m_class m_respond_to_q m_send m___send__
              m_is_a_q m_kind_of_q m_instance_of_q
            ].freeze,
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
            members: [
              %(const char* ruby_class_name() const override { return "Class"; }),
              "// Each eigenclass holds the class_id of its instance",
              "// class. `Foo_CLASS->instance_class_id_` = cid(Foo).",
              "// Used by m_is_a_q to read the target's id.",
              "int instance_class_id_ = -1;",
            ],
            overrides: {
              # Module#to_s / Class#to_s in MRI return the class name
              # ("Foo"), not the inspect-style #<Class:0x…>. Without this
              # override Object#to_s walks self.class.to_s which calls
              # Class#to_s on the Class_eigenclass — infinite recursion.
              "m_to_s" => {
                params: [],
                body: "const char* _n = ruby_class_name(); return new String(_n, std::strlen(_n));",
              },
              "m_inspect" => {
                params: [],
                body: "const char* _n = ruby_class_name(); return new String(_n, std::strlen(_n));",
              },
            },
            hand_coded_method_names: %w[m_to_s m_inspect].freeze,
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
                params: [],
                body: <<~CPP.chomp,
                  int64_t sz = static_cast<int64_t>(data.size());
                  // 3-arg form: a[start, len] = val → slice replace.
                  // delete_at and friends in core/4.0/ use this pattern.
                  if (args->data.size() == 3) {
                    int64_t start = static_cast<Integer*>(args->data[0])->raw_;
                    int64_t len   = static_cast<Integer*>(args->data[1])->raw_;
                    if (start < 0) start += sz;
                    auto* src = static_cast<Array*>(args->data[2]);
                    int64_t end = std::min(start + len, sz);
                    if (start >= 0) {
                      data.erase(data.begin() + start, data.begin() + end);
                      data.insert(data.begin() + start, src->data.begin(), src->data.end());
                    }
                    return args->data[2];
                  }
                  BasicObject* idx = args->data[0];
                  BasicObject* val = args->data[1];
                  // 2-arg with Range idx: a[begin..end] = ary → slice replace.
                  if (auto* r = dynamic_cast<Range*>(idx)) {
                    int64_t b = r->begin_ ? static_cast<Integer*>(r->begin_)->raw_ : 0;
                    int64_t e = r->end_   ? static_cast<Integer*>(r->end_)->raw_   : sz - 1;
                    if (b < 0) b += sz;
                    if (e < 0) e += sz;
                    int64_t last = r->exclude_end_ ? e - 1 : e;
                    auto* src = static_cast<Array*>(val);
                    if (b >= 0 && last >= b - 1) {
                      data.erase(data.begin() + b, data.begin() + std::min(last + 1, sz));
                      data.insert(data.begin() + b, src->data.begin(), src->data.end());
                    }
                    return val;
                  }
                  int64_t i = static_cast<Integer*>(idx)->raw_;
                  if (i < 0) i += sz;
                  if (i >= sz) data.resize(i + 1, nil_instance());
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
              "m_clear" => { params: [], body: "data.clear(); return this;" },
              "m_pop" => { params: [], body: "if (data.empty()) return nil_instance(); BasicObject* v = data.back(); data.pop_back(); return v;" },
              "m_shift" => { params: [], body: "if (data.empty()) return nil_instance(); BasicObject* v = data.front(); data.erase(data.begin()); return v;" },
              "m_unshift" => { params: ["BasicObject* v"], body: "data.insert(data.begin(), v); return this;" },
              "m_replace" => {
                params: ["BasicObject* other"],
                body: "auto* o = static_cast<Array*>(other); data = o->data; return this;",
              },
              "m_dup" => {
                params: [],
                body: "Array* r = new Array(); r->data = data; return r;",
              },
              "m_concat" => {
                params: ["BasicObject* other"],
                body: "auto* o = static_cast<Array*>(other); data.insert(data.end(), o->data.begin(), o->data.end()); return this;",
              },
              # Array.new(size) / Array.new(size, fill) / Array.new(size) { |i| ... }
              # The block form calls the block n times with each index
              # to populate elements; common in matrix construction.
              "m_initialize" => {
                params: [],
                body: <<~CPP.chomp,
                  if (args->data.empty()) return this;
                  int64_t n = static_cast<Integer*>(args->data[0])->raw_;
                  if (block) {
                    data.reserve(n);
                    for (int64_t i = 0; i < n; i++) {
                      data.push_back(block->m_call((new Array({(new Integer(i))})), nullptr, nullptr));
                    }
                  } else {
                    BasicObject* fill = args->data.size() >= 2 ? args->data[1] : nil_instance();
                    data.assign(n, fill);
                  }
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
              "// AOT-assigned method id (-1 if name doesn't correspond",
              "// to any known method). Populated by intern() against a",
              "// static name→id table built from the call surface.",
              "// Drives m_send (indexes a member-function-pointer",
              "// vtable) and m_respond_to_q (indexes a per-class bool",
              "// array) — both O(1), no string compare.",
              "int method_id_ = -1;",
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

          # Range — begin/end/exclude_end stored directly. Range
          # literals (`a..b`, `a...b`) lower to a direct `new Range()`
          # in expr_emitter — no m_new dispatch needed for the literal.
          # Range.new / .allocate fall through to the eigenclass auto-
          # emitted m_new which allocates + invokes m_initialize from
          # core/4.0/range.rb (which uses the range_* intrinsics below).
          RANGE = RubyClass.new(
            name: "Range",
            parent: "Object",
            members: [
              "BasicObject* begin_ = nullptr;",
              "BasicObject* end_   = nullptr;",
              "bool exclude_end_   = false;",
              "bool initialized_   = false;",
              "Range() = default;",
              %(const char* ruby_class_name() const override { return "Range"; }),
            ],
          )

          # Inheritance order. The emitter walks this list to produce
          # forward decls + class bodies + singletons in the right
          # sequence (parent before child, so children's overrides see
          # the parent's vtable layout).
          ALL_CLASSES = [
            BASIC_OBJECT, OBJECT, CLASS_TYPE,
            NIL_CLASS, TRUE_CLASS, FALSE_CLASS,
            INTEGER, FLOAT, ARRAY, SYMBOL, STRING, HASH, RANGE, PROC
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
              ivars: (klass.eigenclass_ivars || []).map { |iv| "BasicObject* iv_#{iv} = nil_instance();" },
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
              // Class instance — eigenclass's ruby_class_name returns
              // the represented class's name, so this prints e.g. "Object".
              if (dynamic_cast<Class*>(o))                   { std::printf("%s\\n", o->ruby_class_name()); return; }
              std::printf("(unprintable: %s)\\n", o->ruby_class_name());
            CPP
          )

          # build_int_array — runtime helper that turns a static
          # int64_t[] table into an Array of boxed Integers. Used by
          # static-state capture to materialise large Integer-only
          # Arrays (lexer tables) without per-element source-level
          # boilerplate. One-time cost at __init_static_state__.
          BUILD_INT_ARRAY_FN = KernelFn.new(
            name: "build_int_array",
            signature: "Array* build_int_array(const std::int64_t* data, std::size_t n)",
            body: <<~CPP.chomp,
              Array* a = new Array();
              a->data.reserve(n);
              for (std::size_t i = 0; i < n; i++) a->data.push_back(new Integer(data[i]));
              return a;
            CPP
          )

          # int_box — forward-declared helper that constructs an
          # Integer and returns it AS BasicObject*. The BasicObject*
          # return type sidesteps the "incomplete type" issue when
          # called from inline members of BasicObject (Integer is
          # forward-declared at that point; the implicit Integer* →
          # BasicObject* conversion requires complete Integer).
          INT_BOX_FN = KernelFn.new(
            name: "int_box",
            signature: "BasicObject* int_box(std::int64_t v)",
            body: "return new Integer(v);",
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
          # Also assigns the method_id_ at intern time by looking up
          # against METHOD_NAMES (a compile-time array of method
          # names → call-surface index). The id_map is built lazily on
          # first call to keep cc1plus from drowning in template
          # instantiation. Sets method_id_ = -1 for names that aren't
          # known methods.
          INTERN_FN = KernelFn.new(
            name: "intern",
            signature: "Symbol* intern(const char* name)",
            body: <<~CPP.chomp,
              using Tab = std::unordered_map<std::string, Symbol*,
                std::hash<std::string>, std::equal_to<std::string>,
                GcAllocator<std::pair<const std::string, Symbol*>>>;
              static Tab table;
              static const std::unordered_map<std::string, int> id_map = []() {
                std::unordered_map<std::string, int> m;
                m.reserve(METHOD_NAMES_COUNT);
                for (int i = 0; i < METHOD_NAMES_COUNT; ++i) m[METHOD_NAMES[i].name] = METHOD_NAMES[i].id;
                return m;
              }();
              auto it = table.find(name);
              if (it != table.end()) return it->second;
              Symbol* s = new Symbol(name);
              auto mit = id_map.find(name);
              s->method_id_ = (mit != id_map.end()) ? mit->second : -1;
              table[std::string(name)] = s;
              return s;
            CPP
          )

          ALL_KERNEL_FNS = [
            NIL_INSTANCE_FN, TRUE_INSTANCE_FN, FALSE_INSTANCE_FN,
            BOXED_BOOL, TRUTHY, RUBY_PUTS, INTERN_FN, ARRAY_AT_FN,
            BUILD_INT_ARRAY_FN, INT_BOX_FN
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

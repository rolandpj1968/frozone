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
            # When true, this entry's eigenclass will inherit from `Module`
            # rather than `Class` — matching MRI's `Math.class == Module`
            # vs `String.class == Class`. Set on pure Vm::ModuleObject
            # universe entries (Math, …) and on every user-defined module
            # at build_user_class_def time.
            :is_module,
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
              "// m_method_missing — Ruby-overridable virtual that the",
              "// universal-surface m_X stubs dispatch into when no class",
              "// in the receiver's hierarchy overrides m_X. Default body",
              "// (this declaration's out-of-line definition) throws",
              "// NoMethodError; user classes that `def method_missing`",
              "// override it via normal vtable lookup. args is",
              "// `[Symbol.method_name, *original_args]`.",
              "virtual BasicObject* m_method_missing(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance());",
              "// m_const_missing — same shape but for constants (raised",
              "// from Module's c_X overrides). Default throws NameError.",
              "virtual BasicObject* m_const_missing(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance());",
              "// constant_typeerror — BasicObject's default for c_X. Raised",
              "// when the receiver isn't a Module/Class at all (TypeError).",
              "// Distinct from m_const_missing — `nil::FOO` is unrecoverable;",
              "// user-overridable const_missing only fires for actual modules.",
              "virtual BasicObject* constant_typeerror(const char* const_name);",
              "// == default — pointer identity (BasicObject#==).",
              "virtual BasicObject* op_eq_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {",
              "  return boxed_bool(this == array_at(args, 0));",
              "}",
              "// m_hash_value — C++-internal hook for std::unordered_map<BasicObject*,…>.",
              "// Not a Ruby method (Ruby's #hash returns Integer; this returns size_t).",
              "virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }",
              "// equal? — pointer identity (BasicObject#equal?). Distinct from",
              "// `==` which subclasses often override for value equality.",
              "virtual BasicObject* mm_equal_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {",
              "  return boxed_bool(this == array_at(args, 0));",
              "}",
              "// __id__ — pointer cast as integer. Closed-world: each",
              "// object has a unique address; that's the id. Note that",
              "// Ruby's #object_id is on Kernel, not BasicObject.",
              "virtual BasicObject* m___id__(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {",
              "  return int_box(reinterpret_cast<std::int64_t>(this));",
              "}",
              "// initialize default — no-op returning self. User classes",
              "// override; eigenclass m_new always invokes this after",
              "// allocating the new instance.",
              "virtual BasicObject* m_initialize(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) {",
              "  return this;",
              "}",
              "// __class_id__ — closed-world class identity. Returns -1",
              "// for non-class instances (so they hit the false branch in",
              "// the IS_A LUT walker on Object). Class instances override.",
              "virtual int __class_id__() const { return -1; }",
            ],
            # Genuine BasicObject methods. Other intrinsic-style methods
            # (m_class, m_send, mm_is_a_q, etc.) live on Object and are
            # listed in OBJECT.hand_coded_method_names.
            hand_coded_method_names: %w[
              op_eq_q m_hash_value mm_equal_q m___id__ m_initialize
              m_method_missing m_const_missing
            ].freeze,
          )

          OBJECT = RubyClass.new(
            name: "Object",
            parent: "BasicObject",
            members: [
              %(const char* ruby_class_name() const override { return "Object"; }),
              "// Universal per-object metadata. Lives on Object (NOT BasicObject —",
              "// BasicObject stays slot-free for user code that wants the lightweight",
              "// no-metadata semantics). Pre-de-fusion these slots lived on",
              "// Frozone_Vm_ObjectObject and were pulled into NilClass et al. via",
              "// C-form fusion (#63/#64); that made every gen depend on Frozone-",
              "// internal types only present when frozone-AOT was the build root.",
              "// Now Frozone_Vm_ObjectObject : Object inherits these naturally.",
              "BasicObject* iv_class_object = nil_instance();",
              "BasicObject* iv_eigenclass = nil_instance();",
              "BasicObject* iv_instance_variables_hash = nil_instance();",
              "BasicObject* iv_frozen_object = nil_instance();",
              "// === defaults to ==. Module/Class override for `Class === obj`.",
              "virtual BasicObject* op_case_eq(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return op_eq_q(args, kwargs, block);",
              "}",
              "// nil? defaults to false; NilClass overrides to true.",
              "virtual BasicObject* mm_nil_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return false_instance();",
              "}",
              "// freeze / frozen? — we don't enforce frozen state, so",
              "// these are no-ops returning self / false. Lots of core",
              "// code calls .freeze on initialization; this stays cheap.",
              "virtual BasicObject* m_freeze(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return this;",
              "}",
              "virtual BasicObject* mm_frozen_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return false_instance();",
              "}",
              "// object_id — Kernel#object_id. Same value as __id__.",
              "virtual BasicObject* m_object_id(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return m___id__(args, kwargs, block);",
              "}",
              "// is_a? / kind_of? / instance_of? — closed-world LUT. mm_is_a_q",
              "// body is emitted out-of-line by class_emitter (write_is_a_lut)",
              "// once all classes are complete.",
              "virtual BasicObject* mm_is_a_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override;",
              "// send / __send__ — METHOD_VT-based dispatch. Out-of-line body",
              "// emitted by class_emitter (write_send_body) once Array is complete.",
              "virtual BasicObject* m_send(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override;",
              "virtual BasicObject* m___send__(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override;",
              "virtual BasicObject* mm_kind_of_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return mm_is_a_q(args, kwargs, block);",
              "}",
              "virtual BasicObject* mm_instance_of_q(Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()) override {",
              "  return boxed_bool(m_class(args, kwargs, block) == array_at(args, 0));",
              "}",
            ],
            hand_coded_method_names: %w[
              op_case_eq mm_nil_q m_freeze mm_frozen_q m_object_id
              m_class mm_respond_to_q m_send m___send__
              mm_is_a_q mm_kind_of_q mm_instance_of_q
            ].freeze,
          )

          # Class — the metaclass type. Every emitted class Foo has a
          # paired eigenclass `Foo_eigenclass : Class` that holds Foo's
          # class methods (def self.X) as virtuals. The Foo *constant*
          # in user code is a singleton instance of Foo_eigenclass.
          # Class itself is currently empty — class-method defaults
          # (allocate, new, name) will land here when needed.
          # Module is the parent of Class — matches MRI's
          # `Class < Module < Object`. Bar_eigenclass for a Vm::ModuleObject
          # `Bar` has parent: "Module" (instead of "Class"), so
          # `bar.is_a?(Module)` is true and `bar.is_a?(Class)` is false.
          # Module also overrides `c_X` to raise NameError (constant_missing)
          # whereas BasicObject's `c_X` raises TypeError — matches Ruby's
          # `nil::FOO` (TypeError) vs `Module::UNDEF` (NameError) split.
          # Module : Object — matches MRI's `Class < Module < Object`.
          # Pre-de-fusion this was `Module : Frozone_Vm_ModuleObject` so
          # _CLASS singletons could pick up Frozone-Ruby-implemented
          # lookup_method / get_method / instance_methods via the vtable.
          # That bound the gen to a Frozone-internal type only present in
          # frozone-AOT builds. Sub-stubs (fib.rb etc.) failed at
          # `struct Module : Frozone_Vm_ModuleObject` with "expected
          # class-name". Reverted: when frozone is the AOT root,
          # Frozone_Vm_ModuleObject : Module still gets emitted and its
          # methods remain reachable through normal Ruby send; sub-stubs
          # don't dynamically introspect Module so they don't need them.
          MODULE = RubyClass.new(
            name: "Module",
            parent: "Object",
            members: [
              %(const char* ruby_class_name() const override { return "Module"; }),
              "// Class eigenclasses inherit instance_class_id_ from here so",
              "// IS_A LUT lookups uniformly read &Foo_CLASS->instance_class_id_",
              "// whether Foo is a class or a pure module.",
              "int instance_class_id_ = -1;",
            ],
            overrides: {
              # Module#to_s returns the module name. Inherited by Class.
              "m_to_s" => {
                params: [],
                body: "const char* _n = ruby_class_name(); return new String(_n, std::strlen(_n));",
              },
              "m_inspect" => {
                params: [],
                body: "const char* _n = ruby_class_name(); return new String(_n, std::strlen(_n));",
              },
              # Module#ancestors — closed-world: walk the IS_A LUT row
              # for our class id, return matching CLASS_BY_ID entries.
              # Fwd-decl'd by class_emitter so this inline body can see
              # N_CLASSES / IS_A / CLASS_BY_ID before they're defined.
              # Order from the LUT bit-set is class-id order, NOT MRO —
              # callers that only need #include? (Class#>=, etc.) don't
              # care; strict MRO callers need a different path.
              "m_ancestors" => {
                params: [],
                body: <<~CPP.chomp,
                  int my_id = instance_class_id_;
                  Array* r = new Array();
                  if (my_id < 0 || my_id >= N_CLASSES) return r;
                  for (int i = 0; i < N_CLASSES; ++i) {
                    if (IS_A[my_id][i] && CLASS_BY_ID[i]) r->data.push_back(CLASS_BY_ID[i]);
                  }
                  return r;
                CPP
              },
            },
            hand_coded_method_names: %w[m_to_s m_inspect m_ancestors].freeze,
          )

          CLASS_TYPE = RubyClass.new(
            name: "Class",
            parent: "Module",
            members: [
              %(const char* ruby_class_name() const override { return "Class"; }),
            ],
          )

          # NilClass / TrueClass / FalseClass inherit from Object directly.
          # Pre-de-fusion they were `: Frozone_Vm_ObjectObject` (#63/#64) to
          # pick up dispatch/set_ivar/lookup_instance_method via the vtable.
          # That dependency only exists in frozone-AOT builds; sub-stubs
          # don't have Frozone_Vm_ObjectObject in the gen and the inherit
          # was unsatisfiable. The iv_* slots that fusion was carrying are
          # now on Object directly so the fused singletons (NIL_INSTANCE
          # etc.) still have a place to store iv_class_object.
          NIL_CLASS = RubyClass.new(
            name: "NilClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "NilClass"; })],
            singleton: "NIL_INSTANCE",
            overrides: {
              "m_to_s"  => { params: [], body: %(return new String("", 0);) },
              "mm_nil_q" => { params: [], body: "return true_instance();" },
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
              # Integer arithmetic — Float operands promote to Float (Ruby
              # numeric coercion). Without the dynamic_cast, `1 + 1.5`
              # would reinterpret Float's bits as int64 and silently
              # corrupt. Same for ==, <, etc.
              "op_plus"     => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return new Float(static_cast<double>(raw_) + f->raw_); return new Integer(raw_ + static_cast<Integer*>(other)->raw_);" },
              "op_minus"    => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return new Float(static_cast<double>(raw_) - f->raw_); return new Integer(raw_ - static_cast<Integer*>(other)->raw_);" },
              "op_mul"      => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return new Float(static_cast<double>(raw_) * f->raw_); return new Integer(raw_ * static_cast<Integer*>(other)->raw_);" },
              "op_div"      => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return new Float(static_cast<double>(raw_) / f->raw_); return new Integer(raw_ / static_cast<Integer*>(other)->raw_);" },
              "op_mod"      => { params: ["BasicObject* other"], body: "return new Integer(raw_ % static_cast<Integer*>(other)->raw_);" },
              "op_lt"       => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) <  f->raw_); return boxed_bool(raw_ <  static_cast<Integer*>(other)->raw_);" },
              "op_gt"       => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) >  f->raw_); return boxed_bool(raw_ >  static_cast<Integer*>(other)->raw_);" },
              "op_le"       => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) <= f->raw_); return boxed_bool(raw_ <= static_cast<Integer*>(other)->raw_);" },
              "op_ge"       => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) >= f->raw_); return boxed_bool(raw_ >= static_cast<Integer*>(other)->raw_);" },
              "op_eq_q"     => { params: ["BasicObject* other"], body: "if (auto* i = dynamic_cast<Integer*>(other)) return boxed_bool(raw_ == i->raw_); if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) == f->raw_); return false_instance();" },
              "op_ne_q"     => { params: ["BasicObject* other"], body: "if (auto* i = dynamic_cast<Integer*>(other)) return boxed_bool(raw_ != i->raw_); if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(static_cast<double>(raw_) != f->raw_); return true_instance();" },
              "op_lshift"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ << static_cast<Integer*>(other)->raw_);" },
              "op_rshift"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ >> static_cast<Integer*>(other)->raw_);" },
              "op_bit_and"  => { params: ["BasicObject* other"], body: "return new Integer(raw_ &  static_cast<Integer*>(other)->raw_);" },
              "op_bit_or"   => { params: ["BasicObject* other"], body: "return new Integer(raw_ |  static_cast<Integer*>(other)->raw_);" },
              "op_bit_xor"  => { params: ["BasicObject* other"], body: "return new Integer(raw_ ^  static_cast<Integer*>(other)->raw_);" },
              "op_neg"      => { params: [],                     body: "return new Integer(-raw_);" },
              # Integer ** Integer with non-negative exponent stays Integer
              # (small) — anything bigger or Float exponent → Float via std::pow.
              "op_pow"      => {
                params: ["BasicObject* other"],
                body: <<~CPP.chomp,
                  if (auto* i = dynamic_cast<Integer*>(other)) {
                    int64_t e = i->raw_;
                    if (e >= 0 && e < 32) {
                      int64_t r = 1, b = raw_;
                      while (e > 0) { if (e & 1) r *= b; b *= b; e >>= 1; }
                      return new Integer(r);
                    }
                    return new Float(std::pow(static_cast<double>(raw_), static_cast<double>(i->raw_)));
                  }
                  if (auto* f = dynamic_cast<Float*>(other)) {
                    return new Float(std::pow(static_cast<double>(raw_), f->raw_));
                  }
                  return nil_instance();
                CPP
              },
              "m_to_s"     => {
                params: [],
                body: <<~CPP.chomp,
                  char buf[32];
                  int n = std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(raw_));
                  return new String(buf, static_cast<std::size_t>(n));
                CPP
              },
              "m_to_i"     => { params: [], body: "return this;" },
              "m_to_f"     => { params: [], body: "return new Float(static_cast<double>(raw_));" },
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
              "// Coerce a numeric BasicObject* to double — handles the",
              "// Float * Integer / Integer * Float mixed-arithmetic case",
              "// without falling back to Ruby-level coercion.",
              "static double as_double(BasicObject* o) {",
              "  if (auto* f = dynamic_cast<Float*>(o))   return f->raw_;",
              "  if (auto* i = dynamic_cast<Integer*>(o)) return static_cast<double>(i->raw_);",
              "  return 0.0;",
              "}",
            ],
            overrides: {
              "op_plus"     => { params: ["BasicObject* other"], body: "return new Float(raw_ + as_double(other));" },
              "op_minus"    => { params: ["BasicObject* other"], body: "return new Float(raw_ - as_double(other));" },
              "op_mul"      => { params: ["BasicObject* other"], body: "return new Float(raw_ * as_double(other));" },
              "op_div"      => { params: ["BasicObject* other"], body: "return new Float(raw_ / as_double(other));" },
              "op_lt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <  as_double(other));" },
              "op_gt"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >  as_double(other));" },
              "op_le"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ <= as_double(other));" },
              "op_ge"       => { params: ["BasicObject* other"], body: "return boxed_bool(raw_ >= as_double(other));" },
              "op_eq_q"     => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(raw_ == f->raw_); if (auto* i = dynamic_cast<Integer*>(other)) return boxed_bool(raw_ == static_cast<double>(i->raw_)); return false_instance();" },
              "op_ne_q"     => { params: ["BasicObject* other"], body: "if (auto* f = dynamic_cast<Float*>(other)) return boxed_bool(raw_ != f->raw_); if (auto* i = dynamic_cast<Integer*>(other)) return boxed_bool(raw_ != static_cast<double>(i->raw_)); return true_instance();" },
              "op_neg"      => { params: [],                     body: "return new Float(-raw_);" },
              "op_pow"       => { params: ["BasicObject* other"], body: "return new Float(std::pow(raw_, as_double(other)));" },
              "m_floor"    => { params: [], body: "return new Integer(static_cast<int64_t>(std::floor(raw_)));" },
              "m_ceil"     => { params: [], body: "return new Integer(static_cast<int64_t>(std::ceil(raw_)));" },
              "m_round"    => { params: [], body: "return new Integer(static_cast<int64_t>(std::round(raw_)));" },
              "m_truncate" => { params: [], body: "return new Integer(static_cast<int64_t>(std::trunc(raw_)));" },
              "m_abs"      => { params: [], body: "return new Float(std::fabs(raw_));" },
              "m_to_int"   => { params: [], body: "return new Integer(static_cast<int64_t>(std::trunc(raw_)));" },
              "mm_finite_q" => { params: [], body: "return boxed_bool(std::isfinite(raw_));" },
              "mm_infinite_q" => { params: [], body: "if (!std::isinf(raw_)) return nil_instance(); return new Integer(raw_ < 0 ? -1 : 1);" },
              "mm_nan_q"    => { params: [], body: "return boxed_bool(std::isnan(raw_));" },
              "mm_zero_q"   => { params: [], body: "return boxed_bool(raw_ == 0.0);" },
              "mm_negative_q" => { params: [], body: "return boxed_bool(raw_ < 0.0);" },
              "mm_positive_q" => { params: [], body: "return boxed_bool(raw_ > 0.0);" },
              "m_to_s"     => {
                params: [],
                body: <<~CPP.chomp,
                  // Ruby Float#to_s uses shortest round-trippable repr —
                  // try precisions 1..17 and pick the smallest that
                  // sscanfs back to the same double. Then ensure a
                  // decimal point so 4.0.to_s == "4.0".
                  if (std::isnan(raw_)) return new String("NaN", 3);
                  if (std::isinf(raw_)) return new String(raw_ < 0 ? "-Infinity" : "Infinity", raw_ < 0 ? 9 : 8);
                  char buf[64];
                  int n = 0;
                  for (int prec = 1; prec <= 17; prec++) {
                    n = std::snprintf(buf, sizeof(buf), "%.*g", prec, raw_);
                    double r = 0; std::sscanf(buf, "%lf", &r);
                    if (r == raw_) break;
                  }
                  bool has_dot = false;
                  for (int i = 0; i < n; i++) if (buf[i] == '.' || buf[i] == 'e' || buf[i] == 'E') { has_dot = true; break; }
                  if (!has_dot && n + 2 < (int)sizeof(buf)) { buf[n++] = '.'; buf[n++] = '0'; buf[n] = 0; }
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
              "mm_empty_q" => {
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
              "op_aref" => {
                params: [],
                body: <<~CPP.chomp,
                  // MRI Array#[] semantics — three forms, decoded into a
                  // normalised (start, len) pair (with negatives unwound)
                  // before a single slice block. Single-Integer form
                  // returns the element directly; the rest return Arrays.
                  int64_t sz = static_cast<int64_t>(data.size());
                  if (args->data.empty() || args->data.size() > 2) {
                    raise_arity(static_cast<int>(args->data.size()), "1..2");
                  }
                  int64_t start, len;
                  bool slice = true;
                  if (args->data.size() == 2) {
                    start = coerce_to_int(args->data[0]);
                    len   = coerce_to_int(args->data[1]);
                  } else if (args->data[0] && args->data[0]->m_class() == (BasicObject*)(&Range_CLASS)) {
                    auto* r = static_cast<Range*>(args->data[0]);
                    // Beginless `(..n)` → start = 0; endless `(n..)` →
                    // stop = sz. Beginless+endless `(..)` → whole array.
                    int64_t b = (r->begin_ == nil_instance()) ? 0 : coerce_to_int(r->begin_);
                    if (b < 0) b += sz;
                    start = b;
                    if (r->end_ == nil_instance()) {
                      len = sz - b;
                    } else {
                      int64_t e = coerce_to_int(r->end_);
                      if (e < 0) e += sz;
                      len = (r->exclude_end_ ? e : e + 1) - b;
                    }
                  } else {
                    start = coerce_to_int(args->data[0]);
                    len = 1;
                    slice = false;
                  }
                  if (start < 0) start += sz;
                  if (!slice) {
                    return (start < 0 || start >= sz) ? nil_instance() : data[start];
                  }
                  if (start < 0 || start > sz || len < 0) return nil_instance();
                  int64_t stop = std::min(start + len, sz);
                  Array* out = new Array();
                  out->data.reserve(stop - start);
                  for (int64_t i = start; i < stop; i++) out->data.push_back(data[i]);
                  return out;
                CPP
              },
              "op_aset" => {
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
                # Variadic — `a.push(x, y, z)` pushes three; `a.push`
                # with no args is a valid no-op returning self. Trailing
                # kwargs absorb as a positional Hash so that the
                # `arr.push(key: v)` shape (which lowers to a kwargs-
                # carrying call under our universal protocol) matches
                # MRI's "no-kwarg method takes the hash positionally"
                # behaviour.
                params: [],
                body: <<~CPP.chomp,
                  for (auto* v : args->data) data.push_back(v);
                  if (!kwargs->data.empty()) data.push_back(kwargs);
                  return this;
                CPP
              },
              "op_lshift" => {
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
              # Array.new — three call shapes:
              #   Array.new(arr)             — copy elements from arr
              #   Array.new(size [, fill])   — n-element array, default nil
              #   Array.new(size) { |i| ... } — n-element, block-populated
              # The Array-arg case used to UB: the body cast args[0] to
              # Integer* unconditionally, reading vtable+vector bits as
              # int64 → huge garbage size → Boehm OOM. m_class() exact-
              # class compare gates the static_cast.
              "m_initialize" => {
                params: [],
                body: <<~CPP.chomp,
                  if (args->data.empty()) return this;
                  BasicObject* arg0 = args->data[0];
                  if (arg0->m_class() == (BasicObject*)(&Array_CLASS)) {
                    data = static_cast<Array*>(arg0)->data;
                    return this;
                  }
                  int64_t n = static_cast<Integer*>(arg0)->raw_;
                  if (truthy(block)) {
                    auto* _b = static_cast<Proc*>(block);
                    data.reserve(n);
                    for (int64_t i = 0; i < n; i++) {
                      data.push_back(_b->m_call((new Array({(new Integer(i))}))));
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
          # default op_eq_q (pointer eq) + default m_hash_value (pointer
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
              "// vtable) and mm_respond_to_q (indexes a per-class bool",
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
            # Symbol's ctor is private — `Symbol.new` / `Symbol.allocate`
            # are meaningless in Ruby anyway. Override both eigenclass
            # auto-emits with an explicit abort. (The default auto-emit
            # would `new Symbol()`, but Symbol has no default ctor.)
            eigenclass_overrides: {
              "m_new" => {
                params: [],
                body: %(std::fprintf(stderr, "[box-first] Symbol.new not supported — use literals\\n"); std::abort();),
              },
              "m_allocate" => {
                params: [],
                body: %(std::fprintf(stderr, "[box-first] Symbol.allocate not supported — use literals\\n"); std::abort();),
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
              "mm_empty_q"  => { params: [], body: "return boxed_bool(bytes.empty());" },
              "m_to_s"     => { params: [], body: "return this;" },
              "op_eq_q"     => {
                params: ["BasicObject* other"],
                body: "auto* o = dynamic_cast<String*>(other); return boxed_bool(o && bytes == o->bytes);",
              },
              "op_ne_q"     => {
                params: ["BasicObject* other"],
                body: "auto* o = dynamic_cast<String*>(other); return boxed_bool(!o || bytes != o->bytes);",
              },
              "op_lt"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes <  static_cast<String*>(other)->bytes);" },
              "op_gt"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes >  static_cast<String*>(other)->bytes);" },
              "op_le"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes <= static_cast<String*>(other)->bytes);" },
              "op_ge"       => { params: ["BasicObject* other"], body: "return boxed_bool(bytes >= static_cast<String*>(other)->bytes);" },
              "op_plus"     => {
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
              "op_lshift"   => {
                params: ["BasicObject* other"],
                body: <<~CPP.chomp,
                  // MRI String#<<: Integer arg appends the codepoint;
                  // String arg appends bytes (with encoding promotion).
                  if (auto* i = dynamic_cast<Integer*>(other)) {
                    std::int64_t cp = i->raw_;
                    if (cp < 0) {
                      std::fprintf(stderr, "[box-first] String#<<: invalid codepoint %ld\\n", static_cast<long>(cp));
                      std::abort();
                    }
                    if (cp < 0x80 || enc == BINARY) {
                      bytes.push_back(static_cast<std::uint8_t>(cp & 0xFF));
                    } else if (cp < 0x800) {
                      bytes.push_back(static_cast<std::uint8_t>(0xC0 | (cp >> 6)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | (cp & 0x3F)));
                    } else if (cp < 0x10000) {
                      bytes.push_back(static_cast<std::uint8_t>(0xE0 | (cp >> 12)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | ((cp >> 6) & 0x3F)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | (cp & 0x3F)));
                    } else {
                      bytes.push_back(static_cast<std::uint8_t>(0xF0 | (cp >> 18)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | ((cp >> 12) & 0x3F)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | ((cp >> 6) & 0x3F)));
                      bytes.push_back(static_cast<std::uint8_t>(0x80 | (cp & 0x3F)));
                    }
                    length_cache_ = -1;
                    return this;
                  }
                  auto* o = static_cast<String*>(other);
                  if (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) enc = UTF8;
                  bytes.insert(bytes.end(), o->bytes.begin(), o->bytes.end());
                  length_cache_ = -1;
                  return this;
                CPP
              },
              "op_aref"     => {
                params: [],
                body: <<~CPP.chomp,
                  std::int64_t sz = static_cast<std::int64_t>(bytes.size());
                  // 2-arg form: s[start, len] → substring of `len` bytes
                  // starting at `start`. core/4.0/ helpers like Buffer#[]
                  // forward to this (used heavily by blurhash).
                  if (args->data.size() >= 2) {
                    std::int64_t start = static_cast<Integer*>(args->data[0])->raw_;
                    std::int64_t len   = static_cast<Integer*>(args->data[1])->raw_;
                    if (start < 0) start += sz;
                    if (start < 0 || start > sz || len < 0) return nil_instance();
                    std::int64_t end = std::min(start + len, sz);
                    return new String(reinterpret_cast<const char*>(&bytes[0]) + start,
                                      static_cast<std::size_t>(end - start), enc);
                  }
                  // 1-arg form. Delegate non-Integer idx (Range, Regexp,
                  // String) to the generic intrinsic_string_slice — this
                  // override only fast-paths the Integer case. Without
                  // this, `"abc"[0..-1]` static_casts Range to Integer
                  // and returns garbage / nil.
                  BasicObject* idx = args->data[0];
                  if (!dynamic_cast<Integer*>(idx)) {
                    return intrinsic_string_slice(this, idx, intern("__unset__"));
                  }
                  std::int64_t i = static_cast<Integer*>(idx)->raw_;
                  if (i < 0) i += sz;
                  if (i < 0 || i >= sz) return nil_instance();
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
              # Lambdas now take the whole args array — supports blocks
              # with 0, 1, or many params. The lambda body unpacks
              # `args->data[i]` as needed; expr_emitter generates the
              # binding code at the top of each lambda body.
              # std::function for type erasure of the captured lambda.
              # _Base_manager (the captures' heap home) is allocated via
              # global operator new which we override to GC_MALLOC (see
              # box_first.hpp), so captured BasicObject* pointers are
              # Boehm-traced.
              "std::function<BasicObject*(Array*)> fn_;",
              "Proc() = default;",
              "explicit Proc(std::function<BasicObject*(Array*)> f) : fn_(std::move(f)) {}",
              %(const char* ruby_class_name() const override { return "Proc"; }),
            ],
            overrides: {
              "m_call" => { params: [], body: "return fn_(args);" },
            },
          )

          # Hash — std::unordered_map keyed by BasicObject* with a
          # custom Hasher (calls m_hash_value via vtable) and KeyEq
          # (calls op_eq_q via vtable). Bucket storage uses GcAllocator
          # so Boehm traces the value pointers.
          HASH = RubyClass.new(
            name: "Hash",
            parent: "Object",
            members: [
              "// Vtable-aware hash + key-equality with runtime-switchable",
              "// compare_by_identity mode. The functors hold a pointer back",
              "// to the per-Hash flag so flipping it (via",
              "// intrinsic_hash_compare_by_identity) plus rehash(0) takes",
              "// effect on subsequent lookups. MRI semantics: switching to",
              "// identity mode does NOT resurrect entries that were",
              "// previously merged under value-equality (rehash redistributes",
              "// existing entries; collapsed dupes stay collapsed).",
              "bool compare_by_identity_ = false;",
              "// Default value + default proc — MRI exclusivity rule:",
              "// setting one clears the other (handled by the setter",
              "// intrinsics; the getter just reads). Both default to",
              "// nil_instance().",
              "BasicObject* default_value_ = nil_instance();",
              "BasicObject* default_proc_ = nil_instance();",
              "struct Hasher {",
              "  bool* by_identity;",
              "  std::size_t operator()(BasicObject* v) const {",
              "    if (by_identity && *by_identity) return reinterpret_cast<std::size_t>(v);",
              "    return v->m_hash_value();",
              "  }",
              "};",
              "struct KeyEq {",
              "  bool* by_identity;",
              "  bool operator()(BasicObject* a, BasicObject* b) const {",
              "    if (by_identity && *by_identity) return a == b;",
              "    Array tmp;",
              "    tmp.data.push_back(b);",
              "    return a->op_eq_q(&tmp) == true_instance();",
              "  }",
              "};",
              "using map_t = std::unordered_map<",
              "  BasicObject*, BasicObject*, Hasher, KeyEq,",
              "  GcAllocator<std::pair<BasicObject* const, BasicObject*>>>;",
              "map_t data;",
              "Hash() : data(0, Hasher{&compare_by_identity_}, KeyEq{&compare_by_identity_}) {}",
              "Hash(std::initializer_list<std::pair<BasicObject*, BasicObject*>> init)",
              "    : data(0, Hasher{&compare_by_identity_}, KeyEq{&compare_by_identity_}) {",
              "  for (auto& p : init) data.insert(p);",
              "}",
              %(const char* ruby_class_name() const override { return "Hash"; }),
            ],
            overrides: {
              "m_size"   => { params: [], body: "return new Integer(static_cast<int64_t>(data.size()));" },
              "m_length" => { params: [], body: "return new Integer(static_cast<int64_t>(data.size()));" },
              "mm_empty_q"=> { params: [], body: "return boxed_bool(data.empty());" },
              "op_aref"   => {
                params: ["BasicObject* k"],
                body: <<~CPP.chomp,
                  auto it = data.find(k);
                  return (it == data.end()) ? nil_instance() : it->second;
                CPP
              },
              "op_aset"   => {
                params: ["BasicObject* k", "BasicObject* v"],
                body: "data[k] = v; return v;",
              },
              "mm_include_q" => {
                params: ["BasicObject* k"],
                body: "return boxed_bool(data.find(k) != data.end());",
              },
              "mm_has_key_q" => {
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

          # Random — wraps a std::mt19937 PRNG. Random.new(seed) creates
          # an instance; rng.rand returns Float in [0, 1) when called
          # without args, or Integer < n when called with an Integer.
          # Real Ruby supports Float ranges and so on; we'll deal with
          # that when something needs it.
          # Random — MT19937-32 (32-bit Mersenne Twister) with MRI-
          # compatible seeding (init_by_array) and Float construction
          # (53-bit precision via two 32-bit draws). Hand-port of MRI's
          # random.c so `Random.new(seed).rand` produces sequences
          # byte-for-byte identical to MRI. std::mt19937 has the right
          # algorithm but its single-Integer seed path uses init_genrand
          # (no key mixing) where MRI uses init_by_array even for one-
          # element keys, so the post-seed state diverges; rolling our
          # own state is also necessary for next_float's specific bit
          # pack which std::uniform_real_distribution doesn't reproduce.
          RANDOM = RubyClass.new(
            name: "Random",
            parent: "Object",
            members: [
              "uint32_t mt_[624];",
              "int mti_ = 625;       // 625 sentinel = needs refill on first use",
              "uint64_t seed_ = 0;",
              %(const char* ruby_class_name() const override { return "Random"; }),
              # MRI's init_genrand — straight Knuth seed expansion.
              "void mri_init_genrand(uint32_t s) {",
              "  mt_[0] = s;",
              "  for (int j = 1; j < 624; j++) {",
              "    mt_[j] = 1812433253UL * (mt_[j-1] ^ (mt_[j-1] >> 30)) + static_cast<uint32_t>(j);",
              "  }",
              "  mti_ = 624;",
              "}",
              # MRI's init_by_array — what Random.new(seed) actually
              # uses, even for single-Integer seeds. Two mixing passes
              # over the state with key+index folded in.
              "void mri_init_by_array(const uint32_t* key, int key_len) {",
              "  mri_init_genrand(19650218UL);",
              "  int i = 1, j = 0;",
              "  int k = (624 > key_len ? 624 : key_len);",
              "  for (; k; k--) {",
              "    mt_[i] = (mt_[i] ^ ((mt_[i-1] ^ (mt_[i-1] >> 30)) * 1664525UL)) + key[j] + static_cast<uint32_t>(j);",
              "    i++; j++;",
              "    if (i >= 624) { mt_[0] = mt_[623]; i = 1; }",
              "    if (j >= key_len) j = 0;",
              "  }",
              "  for (k = 623; k; k--) {",
              "    mt_[i] = (mt_[i] ^ ((mt_[i-1] ^ (mt_[i-1] >> 30)) * 1566083941UL)) - static_cast<uint32_t>(i);",
              "    i++;",
              "    if (i >= 624) { mt_[0] = mt_[623]; i = 1; }",
              "  }",
              "  mt_[0] = 0x80000000UL;",
              "}",
              # MT19937 next-int32. Refills the 624-element state in
              # batches via the standard recurrence + tempers the
              # output. MATRIX_A=0x9908b0dfUL, UPPER_MASK=0x80000000UL,
              # LOWER_MASK=0x7fffffffUL.
              "uint32_t mri_genrand_int32() {",
              "  static const uint32_t mag01[2] = { 0UL, 0x9908b0dfUL };",
              "  uint32_t y;",
              "  if (mti_ >= 624) {",
              "    int kk;",
              "    for (kk = 0; kk < 624 - 397; kk++) {",
              "      y = (mt_[kk] & 0x80000000UL) | (mt_[kk+1] & 0x7fffffffUL);",
              "      mt_[kk] = mt_[kk + 397] ^ (y >> 1) ^ mag01[y & 0x1UL];",
              "    }",
              "    for (; kk < 624 - 1; kk++) {",
              "      y = (mt_[kk] & 0x80000000UL) | (mt_[kk+1] & 0x7fffffffUL);",
              "      mt_[kk] = mt_[kk + (397 - 624)] ^ (y >> 1) ^ mag01[y & 0x1UL];",
              "    }",
              "    y = (mt_[623] & 0x80000000UL) | (mt_[0] & 0x7fffffffUL);",
              "    mt_[623] = mt_[396] ^ (y >> 1) ^ mag01[y & 0x1UL];",
              "    mti_ = 0;",
              "  }",
              "  y = mt_[mti_++];",
              "  y ^= (y >> 11);",
              "  y ^= (y << 7) & 0x9d2c5680UL;",
              "  y ^= (y << 15) & 0xefc60000UL;",
              "  y ^= (y >> 18);",
              "  return y;",
              "}",
              # MRI Float-in-[0,1): two 32-bit draws give 27+26 = 53
              # bits of precision (full Float mantissa). Specific bit
              # pack — std::uniform_real_distribution uses different
              # shifts and consumes different bits.
              "double mri_next_float() {",
              "  uint32_t a = mri_genrand_int32() >> 5;  // 27 bits",
              "  uint32_t b = mri_genrand_int32() >> 6;  // 26 bits",
              "  return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);",
              "}",
            ],
            overrides: {
              "m_initialize" => {
                params: [],
                body: <<~CPP.chomp,
                  if (!args->data.empty()) {
                    seed_ = static_cast<uint64_t>(static_cast<Integer*>(args->data[0])->raw_);
                  } else {
                    seed_ = static_cast<uint64_t>(std::random_device{}());
                  }
                  // MRI calls init_genrand DIRECTLY for single-Integer
                  // seeds (NOT init_by_array, despite what the random.c
                  // FIXNUM-pack-then-init_by_array codepath suggests —
                  // empirically `Random.new(42).bytes(4).unpack1("V")`
                  // matches `init_genrand(42)`'s first int32 (1608637542),
                  // not init_by_array's). Verified across Ruby 3.2.3 and
                  // 4.0.1. Bigint seeds would need init_by_array; deferred.
                  mri_init_genrand(static_cast<uint32_t>(seed_ & 0xffffffffUL));
                  return this;
                CPP
              },
              "m_rand" => {
                params: [],
                body: <<~CPP.chomp,
                  if (args->data.empty()) {
                    return new Float(mri_next_float());
                  }
                  BasicObject* n = args->data[0];
                  if (auto* i = dynamic_cast<Integer*>(n)) {
                    if (i->raw_ <= 0) return new Float(mri_next_float());
                    // MRI's rand(n): rejection-sample with the
                    // smallest mask that covers (n-1), avoiding the
                    // bias of plain modulo for ranges that don't
                    // divide 2^32. For n that fits in uint32_t.
                    uint32_t lim = static_cast<uint32_t>(i->raw_) - 1;
                    uint32_t mask = lim;
                    mask |= mask >> 1; mask |= mask >> 2;
                    mask |= mask >> 4; mask |= mask >> 8;
                    mask |= mask >> 16;
                    while (true) {
                      uint32_t v = mri_genrand_int32() & mask;
                      if (v <= lim) return new Integer(static_cast<int64_t>(v));
                    }
                  }
                  if (auto* f = dynamic_cast<Float*>(n)) {
                    return new Float(mri_next_float() * f->raw_);
                  }
                  return nil_instance();
                CPP
              },
              "m_seed" => {
                params: [],
                body: "return new Integer(static_cast<int64_t>(seed_));",
              },
            },
          )

          # Regexp — wraps an Onigmo `regex_t*`. Compiled lazily at
          # construction time (m_initialize) from the source String.
          # Onigmo internals are libc-malloc'd, NOT GC_MALLOC'd, so they
          # leak when the Regexp object is collected — acceptable for
          # AOT programs with a small fixed regex set (the WQ parser
          # has ~20). A finalizer pass would close the leak when needed.
          REGEXP = RubyClass.new(
            name: "Regexp",
            parent: "Object",
            members: [
              "BasicObject* source_ = nullptr;          // String*",
              "int64_t options_ = 0;",
              "regex_t* compiled_ = nullptr;            // Onigmo state — libc-malloc",
              "bool initialized_ = false;",
              "Regexp() = default;",
              %(const char* ruby_class_name() const override { return "Regexp"; }),
            ],
            hand_coded_method_names: %w[m_initialize].freeze,
            overrides: {
              # Compile from args[0] (String pattern) + optional args[1]
              # (Integer options bitmask). Sets initialized_ on success;
              # aborts with a stderr message on compile failure (would
              # be a RegexpError in MRI — TODO when exception infra
              # composes cleanly with universe-emitted classes).
              "m_initialize" => {
                params: [],
                body: <<~CPP.chomp,
                  if (args->data.empty()) { return this; }
                  auto* pat = static_cast<String*>(args->data[0]);
                  int64_t opts = 0;
                  if (args->data.size() >= 2) {
                    if (auto* i = dynamic_cast<Integer*>(args->data[1])) opts = i->raw_;
                  }
                  source_ = pat;
                  options_ = opts;
                  OnigOptionType onig_opts = ONIG_OPTION_NONE;
                  if (opts & 1) onig_opts |= ONIG_OPTION_IGNORECASE;
                  if (opts & 2) onig_opts |= ONIG_OPTION_EXTEND;
                  if (opts & 4) onig_opts |= ONIG_OPTION_MULTILINE;
                  OnigErrorInfo einfo;
                  const UChar* p = pat->bytes.data();
                  int r = onig_new(&compiled_, p, p + pat->bytes.size(),
                                   onig_opts, ONIG_ENCODING_UTF8,
                                   ONIG_SYNTAX_RUBY, &einfo);
                  if (r != ONIG_NORMAL) {
                    UChar buf[ONIG_MAX_ERROR_MESSAGE_LEN];
                    onig_error_code_to_str(buf, r, &einfo);
                    std::fprintf(stderr, "[box-first] Regexp compile failed: %s (pattern: %.*s)\\n",
                                 reinterpret_cast<const char*>(buf),
                                 static_cast<int>(pat->bytes.size()), pat->bytes.data());
                    std::abort();
                  }
                  initialized_ = true;
                  return this;
                CPP
              },
            },
          )

          # MatchData — holds a snapshot of an OnigRegion (capture
          # offsets) plus the source string so #pre_match / #post_match
          # / #[] can reconstruct substrings. The OnigRegion itself is
          # freed after copying — the snapshot is GC-managed.
          MATCH_DATA = RubyClass.new(
            name: "MatchData",
            parent: "Object",
            members: [
              # iv_ prefix matches the convention auto-emitter uses for
              # `@string` / `@regexp`. core/4.0/match_data.rb memoises
              # both via `||=`, so they need to be addressable as
              # `this->iv_string` / `this->iv_regexp` on the C++ side.
              "BasicObject* iv_string = nullptr;",
              "BasicObject* iv_regexp = nullptr;",
              "// Capture offsets: data[0] = whole match, data[i] = $i.",
              "// (begin, end) of -1 means \"not matched\" (e.g. an alt branch that didn't fire).",
              "std::vector<std::pair<int64_t, int64_t>, GcAllocator<std::pair<int64_t, int64_t>>> captures_;",
              "MatchData() = default;",
              %(const char* ruby_class_name() const override { return "MatchData"; }),
            ],
          )

          # ThrownTag — payload of `throw tag, value`. Routed through
          # C++ exceptions so the unwind matches Ruby's catch/throw
          # semantics (skip everything between throw and the matching
          # catch). Doesn't derive from Exception — Ruby's `rescue`
          # must NOT intercept throws (MRI keeps these mechanisms
          # separate). Tag comparison at catch time uses pointer
          # identity, which works because Symbols are interned.
          THROWN_TAG = RubyClass.new(
            name: "ThrownTag",
            parent: "Object",
            members: [
              "BasicObject* tag_ = nullptr;",
              "BasicObject* value_ = nullptr;",
              "ThrownTag() = default;",
              "ThrownTag(BasicObject* t, BasicObject* v) : tag_(t), value_(v) {}",
              %(const char* ruby_class_name() const override { return "ThrownTag"; }),
            ],
          )

          # Math — module-like class with singleton methods on its
          # eigenclass. No instances ever allocated (Math.new is invalid
          # in MRI too). PI/E live as static const accessors emitted
          # via the eigenclass-constants path.
          MATH = RubyClass.new(
            name: "Math",
            parent: "Object",
            is_module: true,
            members: [
              %(const char* ruby_class_name() const override { return "Math"; }),
            ],
            eigenclass_overrides: {
              "m_sqrt" => { params: ["BasicObject* x"], body: "return new Float(std::sqrt(Float::as_double(x)));" },
              "m_log"  => { params: ["BasicObject* x"], body: "return new Float(std::log(Float::as_double(x)));" },
              "m_log2" => { params: ["BasicObject* x"], body: "return new Float(std::log2(Float::as_double(x)));" },
              "m_log10"=> { params: ["BasicObject* x"], body: "return new Float(std::log10(Float::as_double(x)));" },
              "m_exp"  => { params: ["BasicObject* x"], body: "return new Float(std::exp(Float::as_double(x)));" },
              "m_sin"  => { params: ["BasicObject* x"], body: "return new Float(std::sin(Float::as_double(x)));" },
              "m_cos"  => { params: ["BasicObject* x"], body: "return new Float(std::cos(Float::as_double(x)));" },
              "m_tan"  => { params: ["BasicObject* x"], body: "return new Float(std::tan(Float::as_double(x)));" },
              "m_asin" => { params: ["BasicObject* x"], body: "return new Float(std::asin(Float::as_double(x)));" },
              "m_acos" => { params: ["BasicObject* x"], body: "return new Float(std::acos(Float::as_double(x)));" },
              "m_atan" => { params: ["BasicObject* x"], body: "return new Float(std::atan(Float::as_double(x)));" },
              "m_atan2"=> { params: ["BasicObject* y", "BasicObject* x"], body: "return new Float(std::atan2(Float::as_double(y), Float::as_double(x)));" },
              "op_pow"  => { params: ["BasicObject* x", "BasicObject* y"], body: "return new Float(std::pow(Float::as_double(x), Float::as_double(y)));" },
              "m_hypot"=> { params: ["BasicObject* x", "BasicObject* y"], body: "return new Float(std::hypot(Float::as_double(x), Float::as_double(y)));" },
              "m_cbrt" => { params: ["BasicObject* x"], body: "return new Float(std::cbrt(Float::as_double(x)));" },
            },
          )

          # Inheritance order. The emitter walks this list to produce
          # forward decls + class bodies + singletons in the right
          # sequence (parent before child, so children's overrides see
          # the parent's vtable layout).
          ALL_CLASSES = [
            BASIC_OBJECT, OBJECT, MODULE, CLASS_TYPE,
            NIL_CLASS, TRUE_CLASS, FALSE_CLASS,
            INTEGER, FLOAT, ARRAY, SYMBOL, STRING, HASH, RANGE, PROC,
            REGEXP, MATCH_DATA, MATH, RANDOM, THROWN_TAG
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
            # Auto-generate m_allocate: same as m_new minus the
            # m_initialize dispatch. MRI Class#allocate creates an
            # uninitialized instance; Ruby idioms (Hash#dup, etc.) call
            # `self.class.allocate` then populate fields manually.
            # User-overridable.
            overrides["m_allocate"] ||= {
              params: [],
              body: "return new #{klass.name}();",
            }
            # Eigenclass MRO mirrors the host class hierarchy:
            #   NoArgument.singleton_class.superclass == Switch.singleton_class
            # Without this chain, `NoArgument.guess` (defined as
            # `def self.guess` on Switch) is invisible to the
            # subclass — every dispatch falls through to NoMethodError.
            # Top-of-tree classes (klass.parent nil) bottom out on
            # `Class` (or `Module` for pure modules) so the C++ vtable
            # still resolves m_new / m_class.
            eigen_parent =
              if klass.parent && !klass.parent.empty?
                "#{klass.parent}_eigenclass"
              else
                klass.is_module ? "Module" : "Class"
              end
            RubyClass.new(
              name: "#{klass.name}_eigenclass",
              parent: eigen_parent,
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
            # Calling-convention invariant (Phase 1): every BasicObject*
            # slot in the universal protocol holds a real Ruby object —
            # never C++ nullptr. Positional args default to &EMPTY_ARGS,
            # kwargs to &EMPTY_KWARGS, block to nil_instance().
            #
            # Singleton invariant (Phase 2): Frozone::Vm::NilObject /
            # FalseObject / TrueObject fuse with the runtime nil/false/
            # true classes, so there's exactly one of each. truthy() is
            # back to its original two-pointer-compare form.
            body: "return o != nil_instance() && o != false_instance();",
          )

          RUBY_PUTS = KernelFn.new(
            name: "ruby_puts",
            signature: "void ruby_puts(BasicObject* o)",
            body: <<~CPP.chomp,
              // `puts` with no args calls ruby_puts(nullptr); MRI prints just a newline.
              if (!o)                                       { std::putchar('\\n'); return; }
              if (auto* i = dynamic_cast<Integer*>(o))      { std::printf("%lld\\n", static_cast<long long>(i->raw_)); return; }
              if (auto* f = dynamic_cast<Float*>(o))        {
                if (std::isnan(f->raw_))      { std::printf("NaN\\n");      return; }
                if (std::isinf(f->raw_))      { std::printf("%sInfinity\\n", f->raw_ < 0 ? "-" : ""); return; }
                // Shortest round-trippable representation (matches Ruby).
                char buf[64];
                int n = 0;
                for (int prec = 1; prec <= 17; prec++) {
                  n = std::snprintf(buf, sizeof(buf), "%.*g", prec, f->raw_);
                  double r = 0; std::sscanf(buf, "%lf", &r);
                  if (r == f->raw_) break;
                }
                bool has_dot = false;
                for (int i = 0; i < n; i++) if (buf[i] == '.' || buf[i] == 'e' || buf[i] == 'E') { has_dot = true; break; }
                if (!has_dot && n + 2 < (int)sizeof(buf)) { buf[n++] = '.'; buf[n++] = '0'; }
                std::fwrite(buf, 1, n, stdout); std::putchar('\\n'); return;
              }
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

          # MRI splat semantics for `*x`: Array → splat as-is; nil → [];
          # Array subclass → splat (memory layout matches); else call
          # x.to_a — if it returns an Array, splat that; otherwise wrap
          # as [x]. No dynamic_cast: m_class() exact-class compare for
          # the hot path, mm_is_a_q (closed-world LUT) for the subclass
          # path, m_to_a vtable dispatch for the coercion path. Two
          # static_casts remain but each is gated by a preceding class
          # proof.
          # Used by all splat lowerings (build_args_array sole-splat,
          # build_args_array mixed-splat, from_array_literal mixed
          # splat). Fixes the wq_parse_rich crash where `name, = *node`
          # in Parser::Builders::Default#assignable was static_cast'ing
          # an AST::Node as Array — UB → SIGSEGV. AST::Node aliases
          # to_a children, so m_to_a returns the children Array.
          SPLAT_TO_ARRAY_FN = KernelFn.new(
            name: "splat_to_array",
            signature: "Array* splat_to_array(BasicObject* x)",
            body: <<~CPP.chomp,
              if (x->m_class() == (BasicObject*)(&Array_CLASS)) return static_cast<Array*>(x);
              if (x == nil_instance()) return new Array();
              if (truthy(x->mm_is_a_q(new Array({(BasicObject*)(&Array_CLASS)})))) {
                return static_cast<Array*>(x);
              }
              BasicObject* coerced = x->m_to_a();
              if (coerced && coerced->m_class() == (BasicObject*)(&Array_CLASS)) {
                return static_cast<Array*>(coerced);
              }
              Array* r = new Array();
              r->data.push_back(x);
              return r;
            CPP
          )

          # Symbol interning. Same name → same Symbol* (identity = equality,
          # so default op_eq_q + m_hash_value work). Intern table uses
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
              // Insert FIRST, then take name_ from the table key
              // (which the unordered_map owns and keeps stable).
              // The caller's `name` pointer may be stack-local (e.g.
              // string_to_sym builds intern() args from a temporary
              // std::string); storing it directly in Symbol::name_
              // leaves a dangling pointer once the caller returns.
              std::string key(name);
              auto [ins_it, _inserted] = table.emplace(std::move(key), nullptr);
              Symbol* s = new Symbol(ins_it->first.c_str());
              auto mit = id_map.find(ins_it->first);
              s->method_id_ = (mit != id_map.end()) ? mit->second : -1;
              ins_it->second = s;
              return s;
            CPP
          )

          # Coerce a BasicObject* to int64_t via Ruby's `to_int` protocol.
          # Integer fast-path is pointer-class compare (avoids dynamic_cast).
          # Anything else: dispatch m_to_int and accept only an Integer
          # result. Failure raises TypeError, matching MRI's
          # `no implicit conversion of <Class> into Integer`.
          COERCE_TO_INT_FN = KernelFn.new(
            name: "coerce_to_int",
            signature: "int64_t coerce_to_int(BasicObject* v)",
            body: <<~CPP.chomp,
              if (v && v->m_class() == (BasicObject*)(&Integer_CLASS)) return static_cast<Integer*>(v)->raw_;
              // Only dispatch m_to_int if the receiver actually responds.
              // Otherwise the universal-vtable fallthrough raises
              // NoMethodError, which masks the TypeError MRI expects
              // (Array#[] with a non-coercible index, etc.).
              if (v && v != nil_instance() && v->mm_respond_to_q(new Array({intern("to_int")})) == true_instance()) {
                BasicObject* r = v->m_to_int();
                if (r && r->m_class() == (BasicObject*)(&Integer_CLASS)) return static_cast<Integer*>(r)->raw_;
              }
              const char* cn = v ? v->ruby_class_name() : "nil";
              std::size_t cnlen = std::strlen(cn);
              static const char prefix[] = "no implicit conversion of ";
              static const char suffix[] = " into Integer";
              String* msg = new String();
              msg->bytes.reserve(sizeof(prefix) - 1 + cnlen + sizeof(suffix) - 1);
              msg->bytes.insert(msg->bytes.end(), prefix, prefix + sizeof(prefix) - 1);
              msg->bytes.insert(msg->bytes.end(), cn, cn + cnlen);
              msg->bytes.insert(msg->bytes.end(), suffix, suffix + sizeof(suffix) - 1);
              Array* mm_args = new Array();
              mm_args->data.push_back(static_cast<BasicObject*>(msg));
              throw static_cast<Exception*>((&TypeError_CLASS)->m_new(mm_args));
            CPP
          )

          # Raise ArgumentError with a wrong-number-of-arguments message.
          # Used by Array#[] (and similar) when the caller passes an
          # arity outside the supported set.
          RAISE_ARITY_FN = KernelFn.new(
            name: "raise_arity",
            signature: "void raise_arity(int got, const char* expected)",
            body: <<~CPP.chomp,
              char buf[128];
              std::size_t n = std::snprintf(buf, sizeof(buf),
                "wrong number of arguments (given %d, expected %s)", got, expected);
              if (n >= sizeof(buf)) n = sizeof(buf) - 1;
              String* msg = new String(buf, n);
              Array* mm_args = new Array();
              mm_args->data.push_back(static_cast<BasicObject*>(msg));
              throw static_cast<Exception*>((&ArgumentError_CLASS)->m_new(mm_args));
            CPP
          )

          # method-missing dispatch — called by every universal-surface
          # m_X stub when no class overrides it. Prepends the symbolised
          # method name to args, then virtual-dispatches to
          # m_method_missing on the receiver. The default
          # m_method_missing on BasicObject throws NoMethodError; user
          # classes that `def method_missing` get an override that
          # supersedes the default via normal vtable lookup.
          MM_DISPATCH_FN = KernelFn.new(
            name: "mm_dispatch",
            signature: "BasicObject* mm_dispatch(BasicObject* recv, Array* args, Hash* kwargs, BasicObject* block, const char* method_name)",
            body: <<~CPP.chomp,
              Array* mm_args = new Array();
              mm_args->data.reserve(args->data.size() + 1);
              mm_args->data.push_back(intern(method_name));
              for (auto* a : args->data) mm_args->data.push_back(a);
              return recv->m_method_missing(mm_args, kwargs, block);
            CPP
          )

          # const-missing dispatch — same shape as mm_dispatch but for
          # `c_X` slots. Called from Module's c_X overrides (BasicObject's
          # default c_X raises TypeError directly without going through
          # this — `nil::FOO` isn't recoverable via const_missing).
          CM_DISPATCH_FN = KernelFn.new(
            name: "cm_dispatch",
            signature: "BasicObject* cm_dispatch(BasicObject* recv, const char* const_name)",
            body: <<~CPP.chomp,
              Array* cm_args = new Array();
              cm_args->data.push_back(intern(const_name));
              return recv->m_const_missing(cm_args);
            CPP
          )

          # Onigmo bootstrap. Called from __init_static_state__ — must
          # run before any onig_new / onig_search.
          INIT_ONIGMO_FN = KernelFn.new(
            name: "init_onigmo",
            signature: "void init_onigmo()",
            body: <<~CPP.chomp,
              static OnigEncoding encs[] = { ONIG_ENCODING_UTF8 };
              onig_initialize(encs, 1);
            CPP
          )

          # Thread-local-ish $~ (last MatchData). Box-first programs
          # are single-threaded today, so a plain global is fine.
          # Defined as a free function so callers don't need to know
          # the variable's location.
          MATCH_DATA_GLOBAL = KernelFn.new(
            name: "g_last_match",
            signature: "BasicObject*& g_last_match()",
            body: <<~CPP.chomp,
              static BasicObject* g = nullptr;
              return g;
            CPP
          )

          # Run a regex against a String at byte offset `pos`. On match,
          # builds a MatchData snapshot, parks it in g_last_match(), and
          # returns it; on no-match returns nullptr (caller decides
          # whether to surface that as nil or false). Centralises the
          # onig_search + region_copy + capture-snapshot dance so the
          # =~ / #match / #match? intrinsics stay one-liners.
          REGEXP_MATCH_FN = KernelFn.new(
            name: "regexp_match_helper",
            signature: "MatchData* regexp_match_helper(BasicObject* re_obj, BasicObject* str_obj, int64_t pos)",
            body: <<~CPP.chomp,
              auto* re = static_cast<Regexp*>(re_obj);
              auto* str = static_cast<String*>(str_obj);
              if (!re->compiled_) return nullptr;
              const UChar* s = str->bytes.data();
              const UChar* end = s + str->bytes.size();
              const UChar* start = s + (pos < 0 ? 0 : (pos > (int64_t)str->bytes.size() ? (int64_t)str->bytes.size() : pos));
              OnigRegion* region = onig_region_new();
              int r = onig_search(re->compiled_, s, end, start, end, region, ONIG_OPTION_NONE);
              if (r < 0) {
                onig_region_free(region, 1);
                g_last_match() = nil_instance();
                return nullptr;
              }
              MatchData* md = new MatchData();
              md->iv_string = str;
              md->iv_regexp = re;
              md->captures_.reserve(region->num_regs);
              for (int i = 0; i < region->num_regs; i++) {
                md->captures_.emplace_back(region->beg[i], region->end[i]);
              }
              onig_region_free(region, 1);
              g_last_match() = md;
              return md;
            CPP
          )

          # String#unpack — minimal impl covering only the formats the
          # WQ parser uses: 'C*' (raw bytes → Array of Integer) and
          # 'U*' (UTF-8 → Array of codepoint Integer). Anything else
          # aborts; full unpack DSL is a follow-up.
          STRING_UNPACK_FN = KernelFn.new(
            name: "string_unpack_helper",
            signature: "BasicObject* string_unpack_helper(BasicObject* self_obj, BasicObject* fmt_obj)",
            body: <<~CPP.chomp,
              auto* self = static_cast<String*>(self_obj);
              auto* fmt  = static_cast<String*>(fmt_obj);
              Array* out = new Array();
              const std::uint8_t* b = self->bytes.data();
              std::size_t n = self->bytes.size();
              if (fmt->bytes.size() == 2 && fmt->bytes[0] == 'C' && fmt->bytes[1] == '*') {
                out->data.reserve(n);
                for (std::size_t i = 0; i < n; i++) out->data.push_back(new Integer(static_cast<int64_t>(b[i])));
                return out;
              }
              if (fmt->bytes.size() == 2 && fmt->bytes[0] == 'U' && fmt->bytes[1] == '*') {
                // Pre-reserve worst case (1 codepoint per byte = ASCII).
                // Without this, push_back grows the vector 0→1→2→4→…→N
                // through ~log2(N) reallocations. Each grow allocates a
                // fresh GcAllocator buffer; the OLD buffer's `_M_start`
                // pointer lingers in registers/stack after grow returns,
                // so Boehm's conservative scan keeps every intermediate
                // buffer alive forever. For Parser_Lexer::source_buffer_set
                // unpacking multi-MB source files via 'U*', sum of
                // intermediate buffers ≈ 2× peak buffer → massive leak
                // (~12 MB/s baseline observed). Reserve eliminates ALL
                // intermediate buffers.
                out->data.reserve(n);
                std::size_t i = 0;
                while (i < n) {
                  std::uint8_t c = b[i];
                  int64_t cp;
                  if (c < 0x80) { cp = c; i += 1; }
                  else if ((c & 0xE0) == 0xC0 && i + 1 < n) {
                    cp = ((int64_t)(c & 0x1F) << 6) | (b[i+1] & 0x3F); i += 2;
                  } else if ((c & 0xF0) == 0xE0 && i + 2 < n) {
                    cp = ((int64_t)(c & 0x0F) << 12) | ((int64_t)(b[i+1] & 0x3F) << 6) | (b[i+2] & 0x3F); i += 3;
                  } else if ((c & 0xF8) == 0xF0 && i + 3 < n) {
                    cp = ((int64_t)(c & 0x07) << 18) | ((int64_t)(b[i+1] & 0x3F) << 12) | ((int64_t)(b[i+2] & 0x3F) << 6) | (b[i+3] & 0x3F); i += 4;
                  } else {
                    cp = c; i += 1;  // tolerate invalid UTF-8 by passing the raw byte
                  }
                  out->data.push_back(new Integer(cp));
                }
                return out;
              }
              std::fprintf(stderr, "[box-first] String#unpack format %.*s not supported (only C* / U*)\\n",
                           static_cast<int>(fmt->bytes.size()), fmt->bytes.data());
              std::abort();
            CPP
          )

          # String#gsub helper. Phase 1: handles String pattern + String
          # replacement only (plain global replace). Regexp pattern and
          # block-form replacement abort — TODO when needed by callers.
          # WQ's only gsub call is `source.gsub("\r\n", "\n")`.
          STRING_GSUB_FN = KernelFn.new(
            name: "string_gsub_helper",
            signature: "BasicObject* string_gsub_helper(BasicObject* self_obj, BasicObject* pat, BasicObject* repl, BasicObject* block)",
            body: <<~CPP.chomp,
              auto* self = static_cast<String*>(self_obj);
              if (!pat) return self;
              if (auto* spat = dynamic_cast<String*>(pat)) {
                if (!repl || repl == nil_instance() || block != nullptr) {
                  std::fprintf(stderr, "[box-first] String#gsub block-form not supported yet\\n");
                  std::abort();
                }
                auto* srepl = static_cast<String*>(repl);
                if (spat->bytes.empty()) return self;
                String* out = new String();
                out->bytes.reserve(self->bytes.size());
                std::size_t i = 0;
                const std::uint8_t* hay = self->bytes.data();
                const std::uint8_t* nee = spat->bytes.data();
                std::size_t hay_n = self->bytes.size();
                std::size_t nee_n = spat->bytes.size();
                while (i + nee_n <= hay_n) {
                  if (std::memcmp(hay + i, nee, nee_n) == 0) {
                    out->bytes.insert(out->bytes.end(), srepl->bytes.begin(), srepl->bytes.end());
                    i += nee_n;
                  } else {
                    out->bytes.push_back(hay[i]);
                    i++;
                  }
                }
                out->bytes.insert(out->bytes.end(), hay + i, hay + hay_n);
                return out;
              }
              std::fprintf(stderr, "[box-first] String#gsub Regexp pattern not supported yet\\n");
              std::abort();
            CPP
          )

          # String#scan helper. Handles both String pattern (literal,
          # non-overlapping search) and Regexp pattern (Onigmo loop).
          # If the regex has no captures, each result is the matched
          # substring; with captures, each result is an Array of capture
          # strings (nil for unmatched captures), excluding the whole
          # match. With a block, yields each result and returns self.
          # Without a block, returns the Array of results. Zero-length
          # matches advance position by 1 to avoid an infinite loop.
          STRING_SCAN_FN = KernelFn.new(
            name: "string_scan_helper",
            signature: "BasicObject* string_scan_helper(BasicObject* self_obj, BasicObject* pat_obj, BasicObject* block_obj)",
            body: <<~CPP.chomp,
              auto* self = static_cast<String*>(self_obj);
              bool has_block = (block_obj && block_obj != nil_instance());
              Proc* block_proc = has_block ? dynamic_cast<Proc*>(block_obj) : nullptr;
              if (has_block && !block_proc) has_block = false;  // defensive
              Array* results = new Array();

              // String pattern: literal non-overlapping search.
              if (auto* spat = dynamic_cast<String*>(pat_obj)) {
                if (spat->bytes.empty()) return has_block ? self_obj : static_cast<BasicObject*>(results);
                const std::uint8_t* hay = self->bytes.data();
                const std::uint8_t* nee = spat->bytes.data();
                std::size_t hay_n = self->bytes.size();
                std::size_t nee_n = spat->bytes.size();
                std::size_t i = 0;
                while (i + nee_n <= hay_n) {
                  if (std::memcmp(hay + i, nee, nee_n) == 0) {
                    BasicObject* match_str = new String(reinterpret_cast<const char*>(nee), nee_n);
                    if (has_block) {
                      block_proc->m_call((new Array({match_str})));
                    } else {
                      results->data.push_back(match_str);
                    }
                    i += nee_n;
                  } else {
                    i++;
                  }
                }
                return has_block ? self_obj : static_cast<BasicObject*>(results);
              }

              // Regexp pattern: onig_search loop.
              if (auto* re = dynamic_cast<Regexp*>(pat_obj)) {
                if (!re->compiled_) return has_block ? self_obj : static_cast<BasicObject*>(results);
                const UChar* s = self->bytes.data();
                std::size_t n = self->bytes.size();
                const UChar* end = s + n;
                OnigRegion* region = onig_region_new();
                MatchData* last_match = nullptr;
                int64_t pos = 0;
                while (pos <= (int64_t)n) {
                  const UChar* start = s + pos;
                  int r = onig_search(re->compiled_, s, end, start, end, region, ONIG_OPTION_NONE);
                  if (r < 0) break;
                  // Snapshot MatchData so $~ tracks the last match.
                  auto* md = new MatchData();
                  md->iv_string = self;
                  md->iv_regexp = re;
                  md->captures_.reserve(region->num_regs);
                  for (int j = 0; j < region->num_regs; j++) {
                    md->captures_.emplace_back(region->beg[j], region->end[j]);
                  }
                  last_match = md;

                  int64_t whole_b = region->beg[0];
                  int64_t whole_e = region->end[0];
                  BasicObject* this_result;
                  if (region->num_regs <= 1) {
                    this_result = new String(reinterpret_cast<const char*>(s + whole_b),
                                             static_cast<std::size_t>(whole_e - whole_b));
                  } else {
                    Array* caps = new Array();
                    caps->data.reserve(region->num_regs - 1);
                    for (int j = 1; j < region->num_regs; j++) {
                      int64_t cb = region->beg[j], ce = region->end[j];
                      if (cb < 0) {
                        caps->data.push_back(nil_instance());
                      } else {
                        caps->data.push_back(new String(reinterpret_cast<const char*>(s + cb),
                                                       static_cast<std::size_t>(ce - cb)));
                      }
                    }
                    this_result = caps;
                  }

                  if (has_block) {
                    block_proc->m_call((new Array({this_result})));
                  } else {
                    results->data.push_back(this_result);
                  }

                  // Zero-length match: step 1 byte to avoid infinite loop.
                  pos = (whole_e == whole_b) ? whole_e + 1 : whole_e;
                }
                onig_region_free(region, 1);
                if (last_match) g_last_match() = last_match;
                return has_block ? self_obj : static_cast<BasicObject*>(results);
              }

              std::fprintf(stderr, "[box-first] String#scan unsupported pattern type: %s\\n",
                           pat_obj ? pat_obj->ruby_class_name() : "(null)");
              std::abort();
            CPP
          )

          # Extract substring for capture index `n` from a MatchData.
          # n=0 → whole match; n>0 → numbered capture. Returns nil for
          # an out-of-range index or an unmatched capture (begin == -1).
          MATCH_DATA_CAP_FN = KernelFn.new(
            name: "matchdata_cap",
            signature: "BasicObject* matchdata_cap(BasicObject* md_obj, int64_t n)",
            body: <<~CPP.chomp,
              if (!md_obj || md_obj == nil_instance()) return nil_instance();
              auto* md = static_cast<MatchData*>(md_obj);
              if (n < 0 || n >= (int64_t)md->captures_.size()) return nil_instance();
              auto [b, e] = md->captures_[n];
              if (b < 0) return nil_instance();
              auto* str = static_cast<String*>(md->iv_string);
              return new String(reinterpret_cast<const char*>(str->bytes.data() + b),
                                static_cast<std::size_t>(e - b));
            CPP
          )

          # Global variable accessors — back GlobalVariableRead /
          # GlobalVariableWrite by the GLOBALS hash that the
          # interpreter's init_globals also writes through. Match-data
          # globals stay special-cased (g_last_match()); everything
          # else routes through these helpers.
          GLOBAL_OR_NIL_FN = KernelFn.new(
            name: "g_global_or_nil",
            signature: "BasicObject* g_global_or_nil(const char* name)",
            body: <<~CPP.chomp,
              Hash* g = static_cast<Hash*>(k_Frozone_Vm_GLOBALS());
              auto it = g->data.find(intern(name));
              return it == g->data.end() ? nil_instance() : it->second;
            CPP
          )

          # Auto-init array-valued globals so `[a] + $LOAD_PATH + b`
          # and `$LOAD_PATH.map { … }` work even before init_globals
          # has populated GLOBALS[$LOAD_PATH]. Mirrors MRI's "$LOAD_PATH
          # is always an Array" guarantee. The fresh ArrayObject is
          # also stored back so subsequent reads see the same instance.
          GLOBAL_ARRAY_FN = KernelFn.new(
            name: "g_global_array",
            signature: "BasicObject* g_global_array(const char* name)",
            body: <<~CPP.chomp,
              Hash* g = static_cast<Hash*>(k_Frozone_Vm_GLOBALS());
              Symbol* key = intern(name);
              auto it = g->data.find(key);
              if (it != g->data.end() && it->second != nil_instance()) return it->second;
              Array* raw = new Array();
              BasicObject* vm_arr = (&Frozone_Vm_ArrayObject_CLASS)->m_new(
                new Array({static_cast<BasicObject*>(raw)}));
              g->data[key] = vm_arr;
              return vm_arr;
            CPP
          )

          GLOBAL_SET_FN = KernelFn.new(
            name: "g_global_set",
            signature: "BasicObject* g_global_set(const char* name, BasicObject* val)",
            body: <<~CPP.chomp,
              Hash* g = static_cast<Hash*>(k_Frozone_Vm_GLOBALS());
              g->data[intern(name)] = val;
              return val;
            CPP
          )

          # Fiber storage — `Fiber[:k]` / `Fiber[:k] = v`. Single-
          # threaded today, so a plain global Hash* suffices.
          # Allocated lazily on first access so static-init order
          # doesn't matter. Symbol identity keys work transparently
          # because Symbols intern (singleton instances per name).
          FIBER_STORAGE_GLOBAL = KernelFn.new(
            name: "g_fiber_storage",
            signature: "Hash* g_fiber_storage()",
            body: <<~CPP.chomp,
              static Hash* g = nullptr;
              if (!g) g = new Hash();
              return g;
            CPP
          )

          ALL_KERNEL_FNS = [
            NIL_INSTANCE_FN, TRUE_INSTANCE_FN, FALSE_INSTANCE_FN,
            BOXED_BOOL, TRUTHY, RUBY_PUTS, INTERN_FN, ARRAY_AT_FN,
            SPLAT_TO_ARRAY_FN,
            BUILD_INT_ARRAY_FN, INT_BOX_FN,
            COERCE_TO_INT_FN, RAISE_ARITY_FN,
            MM_DISPATCH_FN, CM_DISPATCH_FN,
            INIT_ONIGMO_FN, MATCH_DATA_GLOBAL, REGEXP_MATCH_FN, MATCH_DATA_CAP_FN,
            STRING_GSUB_FN, STRING_SCAN_FN, STRING_UNPACK_FN,
            GLOBAL_OR_NIL_FN, GLOBAL_ARRAY_FN, GLOBAL_SET_FN,
            FIBER_STORAGE_GLOBAL,
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

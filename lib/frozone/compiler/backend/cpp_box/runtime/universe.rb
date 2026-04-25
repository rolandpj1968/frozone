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
            ],
            # m_* virtuals get appended from call_surface at emit time.
          )

          OBJECT = RubyClass.new(
            name: "Object",
            parent: "BasicObject",
            members: [%(const char* ruby_class_name() const override { return "Object"; })],
          )

          NIL_CLASS = RubyClass.new(
            name: "NilClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "NilClass"; })],
            singleton: "NIL_INSTANCE",
          )

          TRUE_CLASS = RubyClass.new(
            name: "TrueClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "TrueClass"; })],
            singleton: "TRUE_INSTANCE",
          )

          FALSE_CLASS = RubyClass.new(
            name: "FalseClass",
            parent: "Object",
            members: [%(const char* ruby_class_name() const override { return "FalseClass"; })],
            singleton: "FALSE_INSTANCE",
          )

          INTEGER = RubyClass.new(
            name: "Integer",
            parent: "Object",
            ivars: ["int64_t raw_;"],
            members: [
              "explicit Integer(int64_t r) : raw_(r) {}",
              %(const char* ruby_class_name() const override { return "Integer"; }),
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
            },
          )

          # Inheritance order. The emitter walks this list to produce
          # forward decls + class bodies + singletons in the right
          # sequence (parent before child, so children's overrides see
          # the parent's vtable layout).
          ALL_CLASSES = [
            BASIC_OBJECT, OBJECT, NIL_CLASS, TRUE_CLASS, FALSE_CLASS, INTEGER, ARRAY
          ].freeze

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
              if (auto* i = dynamic_cast<Integer*>(o)) {
                std::printf("%lld\\n", static_cast<long long>(i->raw_));
              } else {
                std::printf("(unprintable: %s)\\n", o->ruby_class_name());
              }
            CPP
          )

          ALL_KERNEL_FNS = [
            NIL_INSTANCE_FN, TRUE_INSTANCE_FN, FALSE_INSTANCE_FN,
            BOXED_BOOL, TRUTHY, RUBY_PUTS
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

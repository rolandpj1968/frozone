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
            :hand_coded_method_names,
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
              "// Hand-coded m_eq_q / m_hash_value — these are special:",
              "// they need sensible *defaults* (pointer identity), not",
              "// method_missing, otherwise Hash key lookup would crash on",
              "// any class without an explicit override. Subclasses with",
              "// value semantics (Integer, Float, String) override.",
              "virtual BasicObject* m_eq_q(BasicObject* other) { return boxed_bool(this == other); }",
              "virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }",
            ],
            # Methods listed here are skipped by the universal-surface
            # emitter (already hand-declared in members above).
            hand_coded_method_names: %w[m_eq_q m_hash_value].freeze,
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

          # Symbol — wraps an interned string. Identity-based equality
          # (intern() returns the same Symbol* for the same name) means
          # default m_eq_q (pointer eq) + default m_hash_value (pointer
          # hash) work correctly. Symbol literals emit as `intern("foo")`.
          SYMBOL = RubyClass.new(
            name: "Symbol",
            parent: "Object",
            members: [
              "const char* name_;",
              "explicit Symbol(const char* name) : name_(name) {}",
              %(const char* ruby_class_name() const override { return "Symbol"; }),
            ],
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
              "    return a->m_eq_q(b) == true_instance();",
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
            BASIC_OBJECT, OBJECT, NIL_CLASS, TRUE_CLASS, FALSE_CLASS,
            INTEGER, ARRAY, SYMBOL, HASH
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
              if (auto* i = dynamic_cast<Integer*>(o))      { std::printf("%lld\\n", static_cast<long long>(i->raw_)); return; }
              if (auto* s = dynamic_cast<Symbol*>(o))       { std::printf("%s\\n", s->name_); return; }
              if (o == true_instance())                      { std::printf("true\\n"); return; }
              if (o == false_instance())                     { std::printf("false\\n"); return; }
              if (o == nil_instance())                       { std::printf("\\n"); return; }
              std::printf("(unprintable: %s)\\n", o->ruby_class_name());
            CPP
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
            BOXED_BOOL, TRUTHY, RUBY_PUTS, INTERN_FN
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

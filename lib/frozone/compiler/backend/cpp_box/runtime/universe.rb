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
            :name, :parent, :ivars, :members, :overrides, :singleton,
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

          # ---- Class definitions -----------------------------------

          BASIC_OBJECT = RubyClass.new(
            name: "BasicObject",
            parent: nil,
            members: [
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
              "m_plus" => {
                params: ["BasicObject* other"],
                body: "return new Integer(raw_ + static_cast<Integer*>(other)->raw_);",
              },
              "m_minus" => {
                params: ["BasicObject* other"],
                body: "return new Integer(raw_ - static_cast<Integer*>(other)->raw_);",
              },
              "m_lt" => {
                params: ["BasicObject* other"],
                body: "return boxed_bool(raw_ < static_cast<Integer*>(other)->raw_);",
              },
            },
          )

          # Inheritance order. The emitter walks this list to produce
          # forward decls + class bodies + singletons in the right
          # sequence (parent before child, so children's overrides see
          # the parent's vtable layout).
          ALL_CLASSES = [
            BASIC_OBJECT, OBJECT, NIL_CLASS, TRUE_CLASS, FALSE_CLASS, INTEGER
          ].freeze

          # ---- Free Kernel functions -------------------------------

          BOXED_BOOL = KernelFn.new(
            name: "boxed_bool",
            signature: "BasicObject* boxed_bool(bool b)",
            body: <<~CPP.chomp,
              return b ? static_cast<BasicObject*>(&TRUE_INSTANCE)
                       : static_cast<BasicObject*>(&FALSE_INSTANCE);
            CPP
          )

          TRUTHY = KernelFn.new(
            name: "truthy",
            signature: "bool truthy(BasicObject* o)",
            body: <<~CPP.chomp,
              return o != static_cast<BasicObject*>(&NIL_INSTANCE)
                  && o != static_cast<BasicObject*>(&FALSE_INSTANCE);
            CPP
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

          ALL_KERNEL_FNS = [BOXED_BOOL, TRUTHY, RUBY_PUTS].freeze
        end
      end
    end
  end
end

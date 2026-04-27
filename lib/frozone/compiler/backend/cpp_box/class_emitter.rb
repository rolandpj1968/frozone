# Box-first C++ backend — class emission.
#
# Generic: walks RubyClass instances + the program's call_surface,
# produces C++ class definitions + singleton instances + Kernel free
# functions. No per-class branching; behaviour is fully data-driven.
# Runtime classes (BasicObject, Integer, etc.) and user-defined classes
# go through the same path.
#
# Emission order (so all references resolve at C++ parse time):
#   1. Forward declarations (all classes + all free functions)
#   2. Class bodies (parent before child)
#   3. Singleton instances (after their classes are complete)
#   4. Free function bodies (after singletons exist)

require_relative 'runtime/universe'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ClassEmitter
          # `classes` is the full list (Runtime::ALL_CLASSES + user
          # classes). `call_surface` is { [cpp_name, arity] => ruby_name }.
          # `kernel_fns` is the full list of free functions to emit
          # (Runtime::ALL_KERNEL_FNS + per-program user-constant accessors).
          # `intrinsics` is the list of low-level primitive ops compiled
          # Ruby methods dispatch into (currently empty; populated when
          # we source from core/4.0/).
          def self.write_runtime(emit, classes:, call_surface:,
                                kernel_fns: Runtime::ALL_KERNEL_FNS,
                                intrinsics: Runtime::ALL_INTRINSICS)
            # Method-id assignment — every cpp_name in the call surface
            # gets a stable integer ID. Drives O(1) dispatch for send
            # and respond_to? (no string compare). Order = call_surface
            # iteration order = insertion order from collect_call_surface.
            method_ids = call_surface.keys.each_with_index.to_h
            responder_sets = compute_responder_sets(classes)
            classes = classes.map { |k| with_auto_overrides(k, responder_sets[k.name] || [], method_ids) }

            # Two-pass: pre-render method bodies + send + kernel into a
            # buffer to populate emit.cpp.int_literals (Integer literal
            # interning), then emit __INT_LIT__ in the correct position
            # (after class struct decls so Integer is complete, before
            # method bodies so they can reference it), then replay the
            # buffered bodies. Static-state-init runs separately later
            # and may discover new literals — those would be missed by
            # this pass; collect them via a second sweep.
            body_buf = emit.capture do
              classes.each { |k| write_class_definitions(emit, k) }
              write_method_vt(emit, method_ids)
              write_send_body(emit, method_ids)
              write_kernel_fn_bodies(emit, kernel_fns)
              write_intrinsic_bodies(emit, intrinsics)
              yield if block_given?
            end

            write_method_id_table(emit, method_ids)
            write_forward_decls(emit, classes, kernel_fns, intrinsics)
            emit.blank
            # Class structs first — declarations only, no method bodies.
            # Bodies go out-of-line below so they see all classes /
            # singletons as complete (handles cross-references like
            # `dynamic_cast<TypeError*>` and `&Module_CLASS` from any
            # method, regardless of class definition order).
            classes.each { |k| write_class(emit, k, call_surface) }
            write_singletons(emit, classes)
            emit.blank
            emit.cpp.write_int_literals(emit)
            emit.cpp.write_raw_int_arrays(emit)
            body_buf.each_line { |l| emit.line l.chomp }
          end

          # Compile-time name → method_id table — emitted as a flat
          # `std::pair<const char*, int>` array. intern() builds an
          # unordered_map from it lazily on first call. (A literal-
          # initialised `unordered_map<std::string, int>` with thousands
          # of entries blows up cc1plus into 16GB+ memory; the flat
          # array compiles in seconds because it's just static data.)
          def self.write_method_id_table(emit, method_ids)
            emit.line "// AOT-assigned method ids — every method name in the program's"
            emit.line "// call surface gets a stable integer index. intern() builds an"
            emit.line "// unordered_map from this array on first call."
            emit.line "struct __NameId__ { const char* name; int id; };"
            emit.line "static const __NameId__ METHOD_NAMES[] = {"
            emit.indented do
              method_ids.each do |cpp_name, id|
                ruby_name = cpp_name_to_ruby(cpp_name)
                c = ruby_name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
                emit.line %({"#{c}", #{id}},  // id #{id}: #{cpp_name})
              end
            end
            emit.line "};"
            emit.line "static constexpr int METHOD_NAMES_COUNT = #{method_ids.size};"
            emit.blank
          end

          # Reverse Cpp.method_name to recover the Ruby name we'd see
          # at runtime as Symbol#name_. `m_X_q` → `X?`, `m_X_set` →
          # `X=`, operator-mangled → operator. Falls back to `m_X` → `X`.
          def self.cpp_name_to_ruby(cpp)
            inv = Cpp::OP_NAMES.invert
            return inv[cpp].to_s if inv.key?(cpp)
            s = cpp.to_s.sub(/^m_/, '')
            s = s.sub(/_q$/, '?')
            s = s.sub(/_set$/, '=')
            s
          end

          # Member-function-pointer table indexed by method_id. Each
          # entry points at the BasicObject:: declaration of the
          # method; calling through it does virtual dispatch on `this`,
          # so subclass overrides resolve correctly.
          def self.write_method_vt(emit, method_ids)
            emit.line "// Member-function-pointer vtable indexed by method_id."
            emit.line "// `(this->*METHOD_VT[id])(args, kw, blk)` does virtual dispatch."
            emit.line "using __MethodFn__ = BasicObject* (BasicObject::*)(Array*, Hash*, Proc*);"
            emit.line "static const __MethodFn__ METHOD_VT[] = {"
            emit.indented do
              method_ids.each do |cpp, id|
                ruby = cpp_name_to_ruby(cpp)
                emit.line "&BasicObject::#{cpp},  // id #{id}: #{ruby}"
              end
            end
            emit.line "};"
            emit.line "static constexpr int METHOD_VT_SIZE = #{method_ids.size};"
            emit.blank
          end

          # Add m_class + m_respond_to_q to every class's overrides.
          # m_class returns the eigenclass singleton (`&Foo_CLASS`).
          # m_respond_to_q indexes a per-class static bool array by
          # Symbol::method_id_. Closed-world means we know exactly
          # which methods each class actually implements; optimistic-
          # true would mislead `if x.respond_to?(:foo); x.foo; end`
          # patterns into dispatching :foo through method_missing.
          def self.with_auto_overrides(klass, responder_ruby_names, method_ids)
            target = klass.name.end_with?("_eigenclass") ? "Class_CLASS" : "#{klass.name}_CLASS"
            overrides = (klass.overrides || {}).dup
            overrides["m_class"] ||= { params: [], body: "return (&#{target});" }
            overrides["m_respond_to_q"] ||= {
              params: [],
              body: respond_to_body(klass.name, responder_ruby_names, method_ids),
            }
            klass.dup.tap { |k| k.overrides = overrides }
          end

          def self.respond_to_body(class_name, responder_ruby_names, method_ids)
            n = method_ids.size
            # Build a bool array, true at indices that this class
            # responds to. Names not in the call surface (orphaned
            # responder names — shouldn't normally happen) are
            # silently ignored.
            bits = Array.new(n, false)
            responder_ruby_names.each do |ruby_name|
              cpp = Frozone::Compiler::Backend::CppBox::Cpp.method_name(ruby_name.to_sym)
              id = method_ids[cpp]
              bits[id] = true if id
            end
            arr_var = "__#{class_name}_responds__"
            bits_lit = bits.map { |b| b ? "1" : "0" }.join(",")
            <<~CPP.chomp
              static const bool #{arr_var}[] = {#{bits_lit}};
              if (args->data.empty()) return false_instance();
              int _id = static_cast<Symbol*>(args->data[0])->method_id_;
              return boxed_bool(_id >= 0 && _id < #{n} && #{arr_var}[_id]);
            CPP
          end

          # Compute per-class responder sets — own overrides + parent's
          # set + BasicObject's hand-coded methods + the auto-emitted
          # ones (m_class, m_respond_to_q themselves). Walks the
          # inheritance chain via klass.parent (string), name-indexed.
          # Returns Ruby names (not cpp_names) for matching against
          # Symbol#name_ at runtime.
          def self.compute_responder_sets(classes)
            base = (Runtime::BASIC_OBJECT.hand_coded_method_names || []).map { |m| cpp_name_to_ruby(m) }
            base += %w[class respond_to?]  # auto-emitted on every class
            registry = classes.each_with_object({}) { |k, h| h[k.name] = k }
            memo = {}
            walk = ->(klass) {
              return memo[klass.name] if memo.key?(klass.name)
              own = (klass.overrides || {}).keys.map { |cpp| cpp_name_to_ruby(cpp) }
              parent_set = klass.parent && registry[klass.parent] ? walk.call(registry[klass.parent]) : []
              memo[klass.name] = (own + parent_set + base).uniq
            }
            classes.each_with_object({}) { |k, h| h[k.name] = walk.call(k) }
          end

          def self.write_forward_decls(emit, classes, kernel_fns, intrinsics)
            classes.each { |k| emit.line "struct #{k.name};" }
            emit.blank
            # Singleton extern declarations — class bodies emitted later
            # contain inline method definitions that reference other
            # classes' eigenclass singletons (`(&Module_CLASS)` etc.).
            # Forward `extern` lets `&NAME_CLASS` resolve before the
            # singleton's actual `inline X NAME_CLASS;` definition; the
            # forward-declared eigenclass type is enough to take its
            # address.
            classes.each do |k|
              next unless k.singleton
              emit.line "extern #{k.name} #{k.singleton};"
            end
            emit.blank
            kernel_fns.each { |fn| emit.line "inline #{fn.signature};" }
            intrinsics.each { |fn| emit.line "inline #{fn.signature};" }
          end

          def self.write_intrinsic_bodies(emit, intrinsics)
            intrinsics.each do |fn|
              emit.line "inline #{fn.signature} {"
              emit.indented { fn.body.each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
            end
          end

          def self.write_class(emit, klass, call_surface)
            inherits = klass.parent ? " : #{klass.parent}" : ""
            emit.line "struct #{klass.name}#{inherits} {"
            emit.indented do
              klass.members&.each { |m| emit.line m }
              klass.ivars&.each { |iv| emit.line iv }
              if klass.name == "BasicObject"
                write_universal_surface(emit, call_surface)
              end
              klass.overrides&.each { |name, _| write_override_decl(emit, name, klass) }
            end
            emit.line "};"
            emit.blank
          end

          # Out-of-line definitions for one class — every override body.
          # Emitted AFTER all classes and singletons are defined;
          # cross-references to other classes and `&Foo_CLASS` resolve
          # cleanly.
          def self.write_class_definitions(emit, klass)
            klass.overrides&.each { |name, spec| write_override_def(emit, klass.name, name, spec) }
          end

          # The universal m_* surface on BasicObject. One slot per unique
          # (cpp_name, arity) tuple — collisions on the same cpp_name
          # with different arities produce distinct C++ methods, all
          # named the same (Ruby method overloading isn't a thing, so
          # this *should* never happen — TODO: warn if it does).
          def self.write_universal_surface(emit, call_surface)
            return if call_surface.empty?
            skip = Runtime::BASIC_OBJECT.hand_coded_method_names || []
            emit.line "// Universal method surface — one slot per name. All Ruby methods take"
            emit.line "// (Array* args, Hash* kwargs, Proc* block) — bodies unpack from args."
            call_surface.each do |cpp_name, ruby_name|
              next if skip.include?(cpp_name)
              emit.line %(virtual BasicObject* #{cpp_name}(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) { return method_missing("#{ruby_name}"); })
            end
            emit.blank
            write_send_dispatch(emit, call_surface)
          end

          # send(:name, *rest, **kw, &blk) — out-of-line definition (it
          # calls Array methods that need Array complete). Declared
          # here, defined after Array is complete.
          def self.write_send_dispatch(emit, call_surface)
            emit.line "// send(:name, *rest, **kw, &blk) — switch over every method"
            emit.line "// name in the call surface; virtual dispatch picks the right"
            emit.line "// override on the actual receiver. Unknown name → method_missing."
            emit.line "virtual BasicObject* m_send(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr);"
            emit.line "virtual BasicObject* m___send__(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr);"
          end

          # Out-of-line m_send / m___send__ body. Single indirect call
          # through the method-vtable indexed by Symbol::method_id_.
          # Negative id (interned name not in call surface) →
          # method_missing.
          def self.write_send_body(emit, _method_ids)
            ["m_send", "m___send__"].each do |fn|
              emit.line "inline BasicObject* BasicObject::#{fn}(Array* args, Hash* kwargs, Proc* block) {"
              emit.indented do
                emit.line %|if (args->data.empty()) { std::fprintf(stderr, "[box-first] send: no method name\\n"); std::abort(); }|
                emit.line "Symbol* _name = static_cast<Symbol*>(args->data[0]);"
                emit.line "int _id = _name->method_id_;"
                emit.line "if (_id < 0 || _id >= METHOD_VT_SIZE) return method_missing(_name->name_);"
                emit.line "Array* _rest = new Array();"
                emit.line "for (std::size_t _i = 1; _i < args->data.size(); _i++) _rest->data.push_back(args->data[_i]);"
                emit.line "return (this->*METHOD_VT[_id])(_rest, kwargs, block);"
              end
              emit.line "}"
              emit.blank
            end
          end

          # Universal override declaration: just the signature, terminated
          # with `;`. Default args (`= nullptr`) live here. BasicObject
          # has no parent virtual so its own auto-emitted m_class can't
          # carry `override`.
          def self.write_override_decl(emit, name, klass)
            override_kw = klass.name == "BasicObject" ? "" : " override"
            emit.line "virtual BasicObject* #{name}(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr)#{override_kw};"
          end

          # Out-of-line override definition. spec[:params] is a list of
          # "BasicObject* <name>" strings — the body wants those
          # extracted from args. Universal protocol auto-generates the
          # unpack lines (`BasicObject* <name> = array_at(args, i);`).
          # User-class overrides pass empty params (their bodies have
          # their own unpacking via MethodEmitter.unpack_params).
          def self.write_override_def(emit, class_name, name, spec)
            emit.line "inline BasicObject* #{class_name}::#{name}(Array* args, Hash* kwargs, Proc* block) {"
            emit.indented do
              (spec[:params] || []).each_with_index do |param_decl, i|
                param_name = param_decl.split(/\s+/).last.delete_prefix('*')
                emit.line "BasicObject* #{param_name} = array_at(args, #{i});"
              end
              spec[:body].each_line { |l| emit.line l.chomp }
            end
            emit.line "}"
            emit.blank
          end

          def self.write_singletons(emit, classes)
            classes.each do |k|
              next unless k.singleton
              emit.line "inline #{k.name} #{k.singleton};"
            end
          end

          def self.write_kernel_fn_bodies(emit, kernel_fns)
            kernel_fns.each do |fn|
              emit.line "inline #{fn.signature} {"
              emit.indented { fn.body.each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
            end
          end
        end
      end
    end
  end
end

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
            classes = classes.map { |k| with_auto_overrides(k) }
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
            classes.each { |k| write_class_definitions(emit, k) }
            write_kernel_fn_bodies(emit, kernel_fns)
            write_intrinsic_bodies(emit, intrinsics)
          end

          # Add m_class to every class's overrides (including
          # BasicObject — its body references &BasicObject_CLASS, an
          # eigenclass singleton that's only complete after all classes
          # are defined). Out-of-line emission handles the ordering.
          def self.with_auto_overrides(klass)
            target = klass.name.end_with?("_eigenclass") ? "Class_CLASS" : "#{klass.name}_CLASS"
            overrides = (klass.overrides || {}).dup
            overrides["m_class"] ||= { params: [], body: "return (&#{target});" }
            klass.dup.tap { |k| k.overrides = overrides }
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

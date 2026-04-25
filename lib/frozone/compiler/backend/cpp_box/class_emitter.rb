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
          def self.emit_runtime(emit, classes:, call_surface:,
                                kernel_fns: Runtime::ALL_KERNEL_FNS,
                                intrinsics: Runtime::ALL_INTRINSICS)
            emit_forward_decls(emit, classes, kernel_fns, intrinsics)
            emit.blank
            classes.each { |k| emit_class(emit, k, call_surface) }
            emit_singletons(emit, classes)
            emit.blank
            emit_kernel_fn_bodies(emit, kernel_fns)
            emit_intrinsic_bodies(emit, intrinsics)
          end

          def self.emit_forward_decls(emit, classes, kernel_fns, intrinsics)
            classes.each { |k| emit.line "struct #{k.name};" }
            emit.blank
            kernel_fns.each { |fn| emit.line "inline #{fn.signature};" }
            intrinsics.each { |fn| emit.line "inline #{fn.signature};" }
          end

          def self.emit_intrinsic_bodies(emit, intrinsics)
            intrinsics.each do |fn|
              emit.line "inline #{fn.signature} {"
              emit.indented { fn.body.each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
            end
          end

          def self.emit_class(emit, klass, call_surface)
            inherits = klass.parent ? " : #{klass.parent}" : ""
            emit.line "struct #{klass.name}#{inherits} {"
            emit.indented do
              klass.members&.each { |m| emit.line m }
              klass.ivars&.each { |iv| emit.line iv }
              emit_ctor(emit, klass) if klass.ctor
              if klass.name == "BasicObject"
                emit_universal_surface(emit, call_surface)
              end
              klass.overrides&.each { |name, spec| emit_override(emit, name, spec) }
            end
            emit.line "};"
            emit.blank
          end

          # The universal m_* surface on BasicObject. One slot per unique
          # (cpp_name, arity) tuple — collisions on the same cpp_name
          # with different arities produce distinct C++ methods, all
          # named the same (Ruby method overloading isn't a thing, so
          # this *should* never happen — TODO: warn if it does).
          def self.emit_universal_surface(emit, call_surface)
            return if call_surface.empty?
            emit.line "// Universal method surface — populated from the program's call universe."
            call_surface.each do |(cpp_name, arity), ruby_name|
              params = (["BasicObject*"] * arity).join(", ")
              emit.line %(virtual BasicObject* #{cpp_name}(#{params}) { return method_missing("#{ruby_name}"); })
            end
          end

          def self.emit_ctor(emit, klass)
            params = klass.ctor[:params].join(", ")
            emit.line "#{klass.name}(#{params}) {"
            emit.indented { klass.ctor[:body].each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          def self.emit_override(emit, name, spec)
            params = spec[:params].join(", ")
            emit.line "BasicObject* #{name}(#{params}) override {"
            emit.indented { spec[:body].each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          def self.emit_singletons(emit, classes)
            classes.each do |k|
              next unless k.singleton
              emit.line "inline #{k.name} #{k.singleton};"
            end
          end

          def self.emit_kernel_fn_bodies(emit, kernel_fns)
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

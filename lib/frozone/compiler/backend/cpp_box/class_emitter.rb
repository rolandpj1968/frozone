# Box-first C++ backend — class emission.
#
# Generic: walks the runtime Universe and the program's call_surface,
# produces C++ class definitions + singleton instances + Kernel free
# functions. No per-class branching; behaviour is fully data-driven.
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
          def self.emit_runtime(emit, call_surface:)
            emit_forward_decls(emit)
            emit.blank
            Runtime::ALL_CLASSES.each { |k| emit_class(emit, k, call_surface) }
            emit_singletons(emit)
            emit.blank
            emit_kernel_fn_bodies(emit)
          end

          def self.emit_forward_decls(emit)
            Runtime::ALL_CLASSES.each { |k| emit.line "struct #{k.name};" }
            emit.blank
            Runtime::ALL_KERNEL_FNS.each { |fn| emit.line "inline #{fn.signature};" }
          end

          def self.emit_class(emit, klass, call_surface)
            inherits = klass.parent ? " : #{klass.parent}" : ""
            emit.line "struct #{klass.name}#{inherits} {"
            emit.indented do
              klass.members&.each { |m| emit.line m }
              klass.ivars&.each { |iv| emit.line iv }
              if klass.name == "BasicObject"
                emit_universal_surface(emit, call_surface)
              end
              klass.overrides&.each { |name, spec| emit_override(emit, name, spec) }
            end
            emit.line "};"
            emit.blank
          end

          # The universal m_* surface on BasicObject. Each entry is a
          # virtual that defaults to method_missing; subclasses override
          # the slots they implement.
          def self.emit_universal_surface(emit, call_surface)
            return if call_surface.empty?
            emit.line "// Universal method surface — populated from the program's call universe."
            call_surface.each do |cpp_name, ruby_name|
              emit.line %(virtual BasicObject* #{cpp_name}(BasicObject*) { return method_missing("#{ruby_name}"); })
            end
          end

          def self.emit_override(emit, name, spec)
            params = spec[:params].join(", ")
            emit.line "BasicObject* #{name}(#{params}) override {"
            emit.indented { spec[:body].each_line { |l| emit.line l.chomp } }
            emit.line "}"
          end

          def self.emit_singletons(emit)
            Runtime::ALL_CLASSES.each do |k|
              next unless k.singleton
              emit.line "inline #{k.name} #{k.singleton};"
            end
          end

          def self.emit_kernel_fn_bodies(emit)
            Runtime::ALL_KERNEL_FNS.each do |fn|
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

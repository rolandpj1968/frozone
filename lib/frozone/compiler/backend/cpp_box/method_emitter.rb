# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Method signatures: `Ruby::BasicObject* method_name(Ruby::BasicObject*
# arg, ...)`. All slots are `Ruby::BasicObject*`; unboxing happens
# later (if at all) via the TI-driven optimisation pass.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class MethodEmitter
          # `emit` is the orchestrator (provides line/indented/etc.).
          # `method` is a Vm::Method. `name` is the Ruby method symbol.
          #
          # Emits a virtual signature with a stub body that returns nil.
          # Real body emission lands in the next step (expr_emitter +
          # this calling into it for the method body).
          def self.emit_user_method(emit, name, method)
            params = (method.required_params || []).map { |p| "BasicObject* #{p}" }.join(", ")
            emit.line "virtual BasicObject* #{name}(#{params}) {"
            emit.indented do
              emit.line "return &NIL_INSTANCE;  // stub body — fills in next step"
            end
            emit.line "}"
          end
        end
      end
    end
  end
end

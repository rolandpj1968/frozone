# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Method signatures: `Ruby::BasicObject* method_name(Ruby::BasicObject*
# arg, ...)`. All slots are `Ruby::BasicObject*`; unboxing happens
# later (if at all) via the TI-driven optimisation pass.
#
# Stage 2 status: scaffold only.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class MethodEmitter
        end
      end
    end
  end
end

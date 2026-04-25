# Box-first C++ backend — expressions: literals, calls, ivar/local r/w,
# control flow.
#
# Every expression evaluates to a `RubyObject*`. Method calls go through
# the C++ virtual vtable on the receiver. Literals box on construction
# (`new Ruby_Integer(1)` etc.).
#
# Stage 2 status: scaffold only.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ExprEmitter
        end
      end
    end
  end
end

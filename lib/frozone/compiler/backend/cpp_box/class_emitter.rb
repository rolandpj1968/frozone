# Box-first C++ backend — class definitions, vtable, ivars, ctor,
# default method_missing.
#
# Each emitted class is `Ruby_X : public RubyObject`. All methods are
# C++ virtual; unimplemented slots default to the base `method_missing`
# (print + abort). Closed-world devirtualisation will prune the vtable
# post-hoc; if it can't, we needed the vtable anyway.
#
# Stage 2 status: scaffold only.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ClassEmitter
        end
      end
    end
  end
end

// Box-first C++ runtime — RubyObject base + vtable shape + singletons.
//
// Parallel to frozone.hpp. The box-first emitter produces code that
// uses ONLY this header (no frozone.hpp). Every value is a Ruby_X*
// derived from RubyObject; method dispatch is C++ virtual.
//
// See memory/project_radical_box_first.md for the pinned plan.
//
// Stage 2 status: scaffold only — RubyObject base + method_missing
// abort stub. No core types yet.

#ifndef FROZONE_BOX_FIRST_HPP
#define FROZONE_BOX_FIRST_HPP

#include <cstdio>
#include <cstdlib>
#include <gc.h>

#define FROZONE_GC_INIT() GC_INIT()

namespace frozone_box {

// Forward declarations for the universal Ruby method surface.
// Closed-world analysis will populate this with every method called
// anywhere in the program. For the scaffold, none.
struct RubyObject;

struct RubyObject {
  virtual ~RubyObject() = default;

  // Class-name accessor for diagnostics. Each derived class overrides.
  virtual const char* ruby_class_name() const { return "RubyObject"; }

  // Default method_missing: print receiver class + method name + abort.
  // Eventually needs to match MRI semantics (raise NoMethodError on
  // BasicObject). For now: print + abort. #thiswillnothappen.
  [[noreturn]] virtual void method_missing(const char* method_name) {
    std::fprintf(stderr,
      "[box-first] method_missing: %s#%s\n",
      ruby_class_name(), method_name);
    std::abort();
  }
};

}  // namespace frozone_box

#endif  // FROZONE_BOX_FIRST_HPP

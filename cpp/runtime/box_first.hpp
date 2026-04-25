// Box-first C++ runtime — Ruby class hierarchy root + vtable shape +
// singletons.
//
// Parallel to frozone.hpp. The box-first emitter produces code that
// uses ONLY this header (no frozone.hpp). Every value is a Ruby::X*
// derived from Ruby::BasicObject; method dispatch is C++ virtual.
//
// Naming: we mirror Ruby's class hierarchy directly into a C++ Ruby::
// namespace. `Ruby::BasicObject` is the actual root (matches Ruby's
// language semantics — Object is a subclass of BasicObject, not the
// root). User class `Foo` → `Ruby::Foo`; nested `Foo::Bar` → `Ruby::Foo::Bar`.
//
// See memory/project_radical_box_first.md for the pinned plan.
//
// Stage 2 status: scaffold only — Ruby::BasicObject + method_missing
// abort stub. No core types yet.

#ifndef FROZONE_BOX_FIRST_HPP
#define FROZONE_BOX_FIRST_HPP

#include <cstdio>
#include <cstdlib>
#include <gc.h>

#define FROZONE_GC_INIT() GC_INIT()

namespace Ruby {

struct BasicObject {
  virtual ~BasicObject() = default;

  // Class-name accessor for diagnostics. Each derived class overrides.
  virtual const char* ruby_class_name() const { return "BasicObject"; }

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

// Ruby's Object — direct child of BasicObject. Carries the bulk of the
// "every Ruby value responds to this" surface (Kernel mixin in MRI).
// For the scaffold: just inherits method_missing.
struct Object : public BasicObject {
  const char* ruby_class_name() const override { return "Object"; }
};

}  // namespace Ruby

#endif  // FROZONE_BOX_FIRST_HPP

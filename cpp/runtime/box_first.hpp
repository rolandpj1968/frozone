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
struct Object : BasicObject {
  const char* ruby_class_name() const override { return "Object"; }
};

// ---- Singleton classes ---------------------------------------------
//
// Nil/True/False have exactly one instance each. Inline static at file
// scope (C++17) so the header self-contains them.

struct NilClass : Object {
  const char* ruby_class_name() const override { return "NilClass"; }
};

struct TrueClass : Object {
  const char* ruby_class_name() const override { return "TrueClass"; }
};

struct FalseClass : Object {
  const char* ruby_class_name() const override { return "FalseClass"; }
};

inline NilClass NIL_INSTANCE;
inline TrueClass TRUE_INSTANCE;
inline FalseClass FALSE_INSTANCE;

inline BasicObject* boxed_bool(bool b) {
  return b ? static_cast<BasicObject*>(&TRUE_INSTANCE)
           : static_cast<BasicObject*>(&FALSE_INSTANCE);
}

// ---- Integer --------------------------------------------------------
//
// Wraps `int64_t raw_`. Methods declared here are hand-written
// placeholders for the spike — the long-term plan is to source these
// from `lib/core/4.0/integer.rb` (compiled to vtable bodies). The
// shape of these signatures is what the compiled output will need to
// match.
//
// Naming convention: `m_<op>` where <op> is the C++-safe alias for the
// Ruby operator name. Initial set: m_plus (+), m_minus (-), m_lt (<).
// Coercion (Integer + Float etc.) deferred — for now assume the other
// operand is also Integer.

struct Integer : Object {
  int64_t raw_;
  explicit Integer(int64_t r) : raw_(r) {}
  const char* ruby_class_name() const override { return "Integer"; }

  virtual BasicObject* m_plus(BasicObject* other) {
    return new Integer(raw_ + static_cast<Integer*>(other)->raw_);
  }
  virtual BasicObject* m_minus(BasicObject* other) {
    return new Integer(raw_ - static_cast<Integer*>(other)->raw_);
  }
  virtual BasicObject* m_lt(BasicObject* other) {
    return boxed_bool(raw_ < static_cast<Integer*>(other)->raw_);
  }
};

}  // namespace Ruby

#endif  // FROZONE_BOX_FIRST_HPP

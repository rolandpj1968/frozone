// Object-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_OBJECT_INTRINSICS_HPP
#define FROZONE_OBJECT_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Object / BasicObject ------------------------------------------

// Pure memberwise shallow copy via m_shallow_dup virtual. Preserves
// frozen state and eigenclass. Object#dup and Object#clone in
// core/4.0/object.rb layer their respective state-reset / state-init
// policies on top.
BasicObject* intrinsic_object_shallow_copy(BasicObject* self_);

// `Object#public_send(name, *args, **kwargs, &block)` — dispatches via
// m_send + sets the PUBLIC_SEND_SENTINEL marker so non-public method
// bodies raise NoMethodError per MRI semantics. The body's prologue
// (emit_visibility_prologue) handles the actual rejection.
BasicObject* intrinsic_object_public_send(BasicObject* self_, BasicObject* name,
                                                 BasicObject* args, BasicObject* kwargs,
                                                 BasicObject* block);

// `BasicObject#__send__(name, *args, **kwargs, &block)` — bypasses
// visibility per MRI semantics. Sets g_caller_self to nullptr so the
// callee body's prologue (if any) treats the dispatch as privileged.
BasicObject* intrinsic_basic_object___send__(BasicObject* self_, BasicObject* name,
                                                    BasicObject* args, BasicObject* kwargs,
                                                    BasicObject* block);

// `BasicObject#method_missing(name, *args)` — default impl raises
// NoMethodError. mm_dispatch already does this when the method is
// unknown; this intrinsic is for explicit `super` chains in user-
// defined method_missing.
[[noreturn]] inline BasicObject* intrinsic_basic_object_method_missing(BasicObject* /*self_*/, BasicObject* name,
                                                                       BasicObject* /*args*/, BasicObject* /*kwargs*/) {
  const char* _name = name->typeid_eq_q<Symbol>() ? static_cast<Symbol*>(name)->name_ : "<?>";
  std::string _msg = std::string("undefined method '") + _name + "'";
  throw static_cast<Exception*>(
      (&NoMethodError_CLASS)->m_new(univ, new Array({static_cast<BasicObject*>(new String(_msg.data(), _msg.size()))})));
}

}  // namespace Ruby

#endif  // FROZONE_OBJECT_INTRINSICS_HPP

// Object-category intrinsic definitions. Declarations live in
// object_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "object_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Object / BasicObject ------------------------------------------

// `Object#dup` — shallow memberwise copy via the runtime-dispatched
// m_shallow_dup hook. Each class auto-generates m_shallow_dup as
// `return new ThisType(*this);` (in class_emitter's auto-overrides),
// so the C++ copy ctor for the receiver's exact runtime type runs.
// std::vector / std::string fields are deep-copied automatically;
// BO* ivars are pointer-shared (correct MRI shallow-dup semantics).
//
// Container classes that need independent storage on top of this
// (Hash with its functor back-pointers; Set with its @hash BO*) chain
// their Ruby `def dup` as `r = super; Intrinsics.X_clone_storage(r); r`
// — super reaches here, the clone_storage step deep-copies storage.
BasicObject* intrinsic_object_dup(BasicObject* self_) {
  return self_->m_shallow_dup(univ);
}

// `Object#public_send(name, *args, **kwargs, &block)` — dispatches via
// m_send + sets the PUBLIC_SEND_SENTINEL marker so non-public method
// bodies raise NoMethodError per MRI semantics. The body's prologue
// (emit_visibility_prologue) handles the actual rejection.
BasicObject* intrinsic_object_public_send(BasicObject* self_, BasicObject* name,
                                                 BasicObject* args, BasicObject* kwargs,
                                                 BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  g_caller_self = PUBLIC_SEND_SENTINEL;
  Hash* _kw = (kwargs && kwargs->typeid_eq_q<Hash>()) ? static_cast<Hash*>(kwargs) : nullptr;
  Proc* _blk = (block && block->mm_is_a_q_direct(&Proc_CLASS)) ? static_cast<Proc*>(block) : nullptr;
  return self_->m_send(univ, _full, _kw, _blk);
}

// `BasicObject#__send__(name, *args, **kwargs, &block)` — bypasses
// visibility per MRI semantics. Sets g_caller_self to nullptr so the
// callee body's prologue (if any) treats the dispatch as privileged.
BasicObject* intrinsic_basic_object___send__(BasicObject* self_, BasicObject* name,
                                                    BasicObject* args, BasicObject* kwargs,
                                                    BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  g_caller_self = nullptr;
  Hash* _kw = (kwargs && kwargs->typeid_eq_q<Hash>()) ? static_cast<Hash*>(kwargs) : nullptr;
  Proc* _blk = (block && block->mm_is_a_q_direct(&Proc_CLASS)) ? static_cast<Proc*>(block) : nullptr;
  return self_->m_send(univ, _full, _kw, _blk);
}


}  // namespace Ruby

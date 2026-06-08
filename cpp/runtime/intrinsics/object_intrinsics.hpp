// Object-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_OBJECT_INTRINSICS_HPP
#define FROZONE_OBJECT_INTRINSICS_HPP


// ---- Object / BasicObject ------------------------------------------

// `Object#dup` — shallow copy. Picks the runtime type by typeid so the
// new instance has the right vtable; ivars not copied (rare to depend
// on for non-Ruby-defined classes). Real impl would call
// m_initialize_copy.
inline BasicObject* intrinsic_object_dup(BasicObject* self_) {
  if (typeid(*self_) == typeid(String)) {
    auto* _s = static_cast<String*>(self_);
    auto* _r = new String();
    _r->bytes = _s->bytes;
    return _r;
  }
  if (typeid(*self_) == typeid(Array)) {
    auto* _a = static_cast<Array*>(self_);
    auto* _r = new Array();
    _r->data = _a->data;
    return _r;
  }
  if (typeid(*self_) == typeid(Hash)) {
    auto* _h = static_cast<Hash*>(self_);
    auto* _r = new Hash();
    _r->data = _h->data;
    return _r;
  }
  return self_;
}

// `Object#public_send(name, *args, **kwargs, &block)` — dispatches via
// m_send + sets the PUBLIC_SEND_SENTINEL marker so non-public method
// bodies raise NoMethodError per MRI semantics. The body's prologue
// (emit_visibility_prologue) handles the actual rejection.
inline BasicObject* intrinsic_object_public_send(BasicObject* self_, BasicObject* name,
                                                 BasicObject* args, BasicObject* kwargs,
                                                 BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  g_caller_self = PUBLIC_SEND_SENTINEL;
  Hash* _kw = (kwargs && typeid(*kwargs) == typeid(Hash)) ? static_cast<Hash*>(kwargs) : nullptr;
  Proc* _blk = (block && block->mm_is_a_q_direct(&Proc_CLASS)) ? static_cast<Proc*>(block) : nullptr;
  return self_->m_send(_full, _kw, _blk);
}

// `BasicObject#__send__(name, *args, **kwargs, &block)` — bypasses
// visibility per MRI semantics. Sets g_caller_self to nullptr so the
// callee body's prologue (if any) treats the dispatch as privileged.
inline BasicObject* intrinsic_basic_object___send__(BasicObject* self_, BasicObject* name,
                                                    BasicObject* args, BasicObject* kwargs,
                                                    BasicObject* block) {
  auto* _a = splat_to_array(args);
  auto* _full = new Array();
  _full->data.push_back(name);
  for (auto* _e : _a->data) _full->data.push_back(_e);
  g_caller_self = nullptr;
  Hash* _kw = (kwargs && typeid(*kwargs) == typeid(Hash)) ? static_cast<Hash*>(kwargs) : nullptr;
  Proc* _blk = (block && block->mm_is_a_q_direct(&Proc_CLASS)) ? static_cast<Proc*>(block) : nullptr;
  return self_->m_send(_full, _kw, _blk);
}

// `BasicObject#method_missing(name, *args)` — default impl raises
// NoMethodError. mm_dispatch already does this when the method is
// unknown; this intrinsic is for explicit `super` chains in user-
// defined method_missing.
[[noreturn]] inline BasicObject* intrinsic_basic_object_method_missing(BasicObject* /*self_*/, BasicObject* name,
                                                                       BasicObject* /*args*/, BasicObject* /*kwargs*/) {
  const char* _name = typeid(*name) == typeid(Symbol) ? static_cast<Symbol*>(name)->name_ : "<?>";
  std::string _msg = std::string("undefined method '") + _name + "'";
  throw static_cast<Exception*>(
      (&NoMethodError_CLASS)->m_new(new Array({static_cast<BasicObject*>(new String(_msg.data(), _msg.size()))})));
}
#endif  // FROZONE_OBJECT_INTRINSICS_HPP

// Hash-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_HASH_INTRINSICS_HPP
#define FROZONE_HASH_INTRINSICS_HPP


// ---- Hash ----------------------------------------------------------

// Hash.new(default, &block) — post Vm::HashObject ≡ Hash fusion. The
// Vm hash_new body uses HashObject.new internally which would recurse
// after fusion. Direct allocation + default-value/proc setup.
inline BasicObject* intrinsic_hash_new(BasicObject* default_val, BasicObject* block) {
  auto* h = new Hash();
  if (block && block != nil_instance()) {
    h->default_proc_ = block;
  } else if (default_val && default_val != nil_instance()) {
    h->default_value_ = default_val;
  }
  return h;
}

// `Hash#each { |k, v| ... }` — iterate, calling block with [k, v]
// Array. Returns self. The 2-element Array argument enables `|k, v|`
// destructuring at the block-arg unpacking site.
inline BasicObject* intrinsic_hash_each(BasicObject* self_, BasicObject* block) {
  auto* _h = static_cast<Hash*>(self_);
  auto* _b = static_cast<Proc*>(block);
  for (auto& _kv : _h->data) {
    _b->m_call(new Array({_kv.first, _kv.second}));
  }
  return _h;
}

// `Hash#delete(key)` — remove and return value, or nil if key absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
inline BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key) {
  auto* _h = static_cast<Hash*>(self_);
  auto _it = _h->data.find(key);
  if (_it == _h->data.end()) return nil_instance();
  BasicObject* _v = _it->second;
  _h->data.erase(_it);
  return _v;
}

// `Hash#compare_by_identity` (setter) — switch to pointer-identity
// keys + pointer-hash. The Hasher/KeyEq functors hold a pointer to
// compare_by_identity_; flipping it + rehash(0) redistributes
// existing entries under the new mode. Per MRI: previously-collapsed
// duplicate keys (value-equal but distinct pointers) STAY collapsed.
// Returns self.
inline BasicObject* intrinsic_hash_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  _h->compare_by_identity_ = true;
  _h->data.rehash(0);
  return _h;
}

// `Hash#compare_by_identity?` — true iff the hash is in identity mode.
inline BasicObject* intrinsic_hash_compare_by_identity_q(BasicObject* self_) {
  return boxed_bool(static_cast<Hash*>(self_)->compare_by_identity_);
}

// Reset compare_by_identity flag (used by Hash#replace before copying
// the source hash's mode). MRI doesn't expose a public setter that
// flips the mode back; this is for our Ruby-side replace impl only.
inline BasicObject* intrinsic_hash_reset_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  if (_h->compare_by_identity_) {
    _h->compare_by_identity_ = false;
    _h->data.rehash(0);
  }
  return _h;
}

// Hash default value / default proc — MRI exclusivity: setting one
// clears the other. Setters handle that; getters are direct reads.

inline BasicObject* intrinsic_hash_get_default(BasicObject* self_, BasicObject* /*key*/) {
  // MRI Hash#default(key) ignores key when no default_proc; returns
  // the default value. Used by core/4.0/hash.rb's `[]` lookup miss
  // path (already nil-default unless setter ran).
  return static_cast<Hash*>(self_)->default_value_;
}

inline BasicObject* intrinsic_hash_set_default(BasicObject* self_, BasicObject* val) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_value_ = val;
  _h->default_proc_ = nil_instance();
  return val;
}

inline BasicObject* intrinsic_hash_get_default_proc(BasicObject* self_) {
  return static_cast<Hash*>(self_)->default_proc_;
}

inline BasicObject* intrinsic_hash_set_default_proc(BasicObject* self_, BasicObject* prc) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_proc_ = prc;
  _h->default_value_ = nil_instance();
  return prc;
}
#endif  // FROZONE_HASH_INTRINSICS_HPP

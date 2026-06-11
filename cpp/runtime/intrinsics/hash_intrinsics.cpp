// Hash-category intrinsic definitions. Declarations live in
// hash_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "hash_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Hash ----------------------------------------------------------

// `Hash#each { |k, v| ... }` — iterate, calling block with [k, v]
// Array. Returns self. The 2-element Array argument enables `|k, v|`
// destructuring at the block-arg unpacking site. Walks the side
// insertion-order vector so the block receives entries in MRI
// insertion-order; tombstoned (nullptr) slots are skipped.
BasicObject* intrinsic_hash_each(BasicObject* self_, BasicObject* block) {
  auto* _h = static_cast<Hash*>(self_);
  auto* _b = static_cast<Proc*>(block);
  for (BasicObject* _k : _h->insertion_order) {
    if (!_k) continue;
    auto _it = _h->data.find(_k);
    if (_it == _h->data.end()) continue;
    _b->m_call(univ, new Array({_k, _it->second}));
  }
  return _h;
}

// `Hash#delete(key)` — remove and return value, or nil if key absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
// erase_key tombstones the insertion_order slot and triggers a compact
// pass if the waste ratio exceeds half.
BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key) {
  auto* _h = static_cast<Hash*>(self_);
  BasicObject* _v = _h->erase_key(key);
  return _v ? _v : nil_instance();
}

// `Hash#compare_by_identity` (setter) — switch to pointer-identity
// keys + pointer-hash. The Hasher/KeyEq functors hold a pointer to
// compare_by_identity_; flipping it + rehash(0) redistributes
// existing entries under the new mode. Per MRI: previously-collapsed
// duplicate keys (value-equal but distinct pointers) STAY collapsed.
// Returns self.
BasicObject* intrinsic_hash_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  _h->compare_by_identity_ = true;
  _h->data.rehash(0);
  _h->order_idx.rehash(0);
  return _h;
}

// `Hash#compare_by_identity?` — true iff the hash is in identity mode.
BasicObject* intrinsic_hash_compare_by_identity_q(BasicObject* self_) {
  return boxed_bool(static_cast<Hash*>(self_)->compare_by_identity_);
}

// Reset compare_by_identity flag (used by Hash#replace before copying
// the source hash's mode). MRI doesn't expose a public setter that
// flips the mode back; this is for our Ruby-side replace impl only.
BasicObject* intrinsic_hash_reset_compare_by_identity(BasicObject* self_) {
  auto* _h = static_cast<Hash*>(self_);
  if (_h->compare_by_identity_) {
    _h->compare_by_identity_ = false;
    _h->data.rehash(0);
    _h->order_idx.rehash(0);
  }
  return _h;
}

// Hash default value / default proc — MRI exclusivity: setting one
// clears the other. Setters handle that; getters are direct reads.

BasicObject* intrinsic_hash_get_default(BasicObject* self_, BasicObject* /*key*/) {
  // MRI Hash#default(key) ignores key when no default_proc; returns
  // the default value. Used by core/4.0/hash.rb's `[]` lookup miss
  // path (already nil-default unless setter ran).
  return static_cast<Hash*>(self_)->default_value_;
}

BasicObject* intrinsic_hash_set_default(BasicObject* self_, BasicObject* val) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_value_ = val;
  _h->default_proc_ = nil_instance();
  return val;
}

BasicObject* intrinsic_hash_get_default_proc(BasicObject* self_) {
  return static_cast<Hash*>(self_)->default_proc_;
}

BasicObject* intrinsic_hash_set_default_proc(BasicObject* self_, BasicObject* prc) {
  auto* _h = static_cast<Hash*>(self_);
  _h->default_proc_ = prc;
  _h->default_value_ = nil_instance();
  return prc;
}


}  // namespace Ruby

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

// `Hash#dup` step 2 — rebuild the internal unordered_map functors on a
// freshly shallow-dup'd Hash so they point at the dup's own
// compare_by_identity_ flag rather than the source's. The default C++
// copy ctor (m_shallow_dup → `new Hash(*this)`) memberwise-copies
// `data` and `order_idx`, but the Hasher/KeyEq inside each map holds a
// `bool* by_identity` back-pointer into the source instance; without
// this step, flipping the dup's compare_by_identity flag would have no
// effect on its own lookups (or worse, would silently track the
// source's flag).
BasicObject* intrinsic_hash_clone_storage(BasicObject* self_) {
  auto* h = static_cast<Hash*>(self_);
  Hash::map_t fresh_data(0, Hash::Hasher{&h->compare_by_identity_},
                            Hash::KeyEq{&h->compare_by_identity_});
  for (auto& kv : h->data) fresh_data.emplace(kv.first, kv.second);
  h->data = std::move(fresh_data);
  Hash::idx_map_t fresh_idx(0, Hash::Hasher{&h->compare_by_identity_},
                                Hash::KeyEq{&h->compare_by_identity_});
  for (auto& kv : h->order_idx) fresh_idx.emplace(kv.first, kv.second);
  h->order_idx = std::move(fresh_idx);
  // insertion_order (plain std::vector<BO*>) and `live` are POD-ish —
  // the memberwise copy already gave the dup its own copies.
  return h;
}

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

// `Hash#delete(key, by_id)` — remove and return value, or nil if absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
// erase_key tombstones the insertion_order slot and triggers a compact
// pass if waste ratio exceeds half. by_id is the per-call compare-by-identity
// mode (caller's @compare_by_identity); the cpp Hash's internal cache must
// match (kept consistent via hash_set_identity_mode).
BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key, BasicObject* /*by_id*/) {
  auto* _h = static_cast<Hash*>(self_);
  BasicObject* _v = _h->erase_key(key);
  return _v ? _v : nil_instance();
}

// Set cpp Hash's internal mode cache + rebuild bucket layout.
// Replaces hash_compare_by_identity / hash_reset_compare_by_identity.
// The canonical @compare_by_identity truth lives at the Ruby layer and is
// threaded through each hash op as a per-call bool param; this intrinsic
// keeps the cpp implementation's internal field consistent. Idempotent.
BasicObject* intrinsic_hash_set_identity_mode(BasicObject* self_, BasicObject* by_id) {
  auto* _h = static_cast<Hash*>(self_);
  bool new_mode = (by_id == true_instance());
  if (_h->compare_by_identity_ == new_mode) return _h;
  _h->compare_by_identity_ = new_mode;
  _h->data.rehash(0);
  _h->order_idx.rehash(0);
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

BasicObject* intrinsic_hash_new(BasicObject* default_val, BasicObject* block) {
  auto* _h = new Hash();
  if (block != nil_instance()) {
    _h->default_proc_ = block;
  } else if (default_val != nil_instance()) {
    _h->default_value_ = default_val;
  }
  return _h;
}

BasicObject* intrinsic_hash_transform_keys_bang(BasicObject* self_, BasicObject* hash_arg,
                                                BasicObject* block) {
  auto* _h = static_cast<Hash*>(self_);
  // Snapshot live (k, v) pairs in insertion order before mutating.
  std::vector<std::pair<BasicObject*, BasicObject*>> _pairs;
  _pairs.reserve(_h->live);
  for (BasicObject* _k : _h->insertion_order) {
    if (!_k) continue;
    auto _it = _h->data.find(_k);
    if (_it == _h->data.end()) continue;
    _pairs.emplace_back(_k, _it->second);
  }
  _h->clear_kvps();
  Proc* _b = (block != nil_instance()) ? static_cast<Proc*>(block) : nullptr;
  Hash* _ha = (hash_arg != nil_instance()) ? static_cast<Hash*>(hash_arg) : nullptr;
  for (auto& _p : _pairs) {
    BasicObject* _nk;
    if (_ha) {
      auto _hit = _ha->data.find(_p.first);
      _nk = (_hit != _ha->data.end()) ? _hit->second : (_b ? _b->call1(_p.first) : _p.first);
    } else if (_b) {
      _nk = _b->call1(_p.first);
    } else {
      _nk = _p.first;
    }
    _h->put(_nk, _p.second);
  }
  return _h;
}


}  // namespace Ruby

// Hash-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_HASH_INTRINSICS_HPP
#define FROZONE_HASH_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Hash ----------------------------------------------------------

// `Hash#dup` step 2 — rebuild unordered_map functors on a freshly
// shallow-dup'd Hash so they point at the dup's own
// compare_by_identity_ flag. See implementation for details.
BasicObject* intrinsic_hash_clone_storage(BasicObject* self_);

// `Hash#each { |k, v| ... }` — iterate, calling block with [k, v]
// Array. Returns self. The 2-element Array argument enables `|k, v|`
// destructuring at the block-arg unpacking site. Walks the side
// insertion-order vector so the block receives entries in MRI
// insertion-order; tombstoned (nullptr) slots are skipped.
BasicObject* intrinsic_hash_each(BasicObject* self_, BasicObject* block);

// `Hash#delete(key, by_id)` — remove and return value, or nil if absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
// by_id is the per-call compare-by-identity mode threaded from the Ruby
// layer (@compare_by_identity); the cpp Hash's internal cache must match.
BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key, BasicObject* by_id);

// Set the cpp Hash's internal mode cache + rebuild bucket layout.
// Canonical truth for compare-by-identity lives at the Ruby layer in
// @compare_by_identity and is threaded through each hash op as a bool
// param; this intrinsic keeps the cpp implementation's internal field
// consistent. Idempotent. Replaces the old hash_compare_by_identity /
// hash_reset_compare_by_identity / hash_compare_by_identity_q triple.
BasicObject* intrinsic_hash_set_identity_mode(BasicObject* self_, BasicObject* by_id);

// Hash default value / default proc — MRI exclusivity: setting one
// clears the other. Setters handle that; getters are direct reads.

BasicObject* intrinsic_hash_get_default(BasicObject* self_, BasicObject* /*key*/);

BasicObject* intrinsic_hash_set_default(BasicObject* self_, BasicObject* val);

BasicObject* intrinsic_hash_get_default_proc(BasicObject* self_);

BasicObject* intrinsic_hash_set_default_proc(BasicObject* self_, BasicObject* prc);

// Hash.new(default=nil, &block) class-method ctor. `default` populates
// default_value_; `block` (Proc* or nil_instance()) populates
// default_proc_. MRI's exclusivity rule: a non-nil block clears the
// default value. A bare `Hash.new` is `(nil, nil)` → both fields nil.
BasicObject* intrinsic_hash_new(BasicObject* default_val, BasicObject* block);

// `Hash#transform_keys!(hash, &block)` — rewrite keys in place. For
// each existing key k, the new key is hash[k] when hash is given and
// has k, otherwise block.call(k) if a block is given, otherwise k
// itself. Values are preserved. Late-binding collisions keep the
// last write per MRI. The Ruby wrapper handles the
// no-args-return-Enumerator case and frozen-check before calling.
BasicObject* intrinsic_hash_transform_keys_bang(BasicObject* self_, BasicObject* hash_arg,
                                                BasicObject* block);

}  // namespace Ruby

#endif  // FROZONE_HASH_INTRINSICS_HPP

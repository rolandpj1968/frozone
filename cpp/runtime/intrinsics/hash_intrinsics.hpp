// Hash-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_HASH_INTRINSICS_HPP
#define FROZONE_HASH_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Hash ----------------------------------------------------------

// `Hash#each { |k, v| ... }` — iterate, calling block with [k, v]
// Array. Returns self. The 2-element Array argument enables `|k, v|`
// destructuring at the block-arg unpacking site. Walks the side
// insertion-order vector so the block receives entries in MRI
// insertion-order; tombstoned (nullptr) slots are skipped.
BasicObject* intrinsic_hash_each(BasicObject* self_, BasicObject* block);

// `Hash#delete(key)` — remove and return value, or nil if key absent.
// Does NOT call the default proc on miss (matches MRI Hash#delete).
// erase_key tombstones the insertion_order slot and triggers a compact
// pass if the waste ratio exceeds half.
BasicObject* intrinsic_hash_delete(BasicObject* self_, BasicObject* key);

// `Hash#compare_by_identity` (setter) — switch to pointer-identity
// keys + pointer-hash. The Hasher/KeyEq functors hold a pointer to
// compare_by_identity_; flipping it + rehash(0) redistributes
// existing entries under the new mode. Per MRI: previously-collapsed
// duplicate keys (value-equal but distinct pointers) STAY collapsed.
// Returns self.
BasicObject* intrinsic_hash_compare_by_identity(BasicObject* self_);

// `Hash#compare_by_identity?` — true iff the hash is in identity mode.
BasicObject* intrinsic_hash_compare_by_identity_q(BasicObject* self_);

// Reset compare_by_identity flag (used by Hash#replace before copying
// the source hash's mode). MRI doesn't expose a public setter that
// flips the mode back; this is for our Ruby-side replace impl only.
BasicObject* intrinsic_hash_reset_compare_by_identity(BasicObject* self_);

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

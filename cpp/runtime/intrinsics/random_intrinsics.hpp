// Random-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_RANDOM_INTRINSICS_HPP
#define FROZONE_RANDOM_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {


BasicObject* intrinsic_random_new_seed(BasicObject* /*receiver*/);

BasicObject* intrinsic_random_new(BasicObject* /*receiver*/, BasicObject* seed);

BasicObject* intrinsic_random_seed(BasicObject* v);

BasicObject* intrinsic_random_state(BasicObject* v);

BasicObject* intrinsic_random_rand(BasicObject* v, BasicObject* n);

BasicObject* intrinsic_random_bytes(BasicObject* v, BasicObject* n_obj);

BasicObject* intrinsic_random_urandom(BasicObject* /*receiver*/, BasicObject* n_obj);

BasicObject* intrinsic_random_marshal_load(BasicObject* /*v*/, BasicObject* /*data*/);

}  // namespace Ruby

#endif  // FROZONE_RANDOM_INTRINSICS_HPP

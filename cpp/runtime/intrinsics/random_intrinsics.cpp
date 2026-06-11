// Random-category intrinsic definitions. Declarations live in
// random_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "random_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

namespace random_detail {
  inline std::mt19937_64& default_rng() {
    static std::mt19937_64 rng{std::random_device{}()};
    return rng;
  }
  inline std::uint64_t fresh_seed() {
    static std::random_device rd;
    return (static_cast<std::uint64_t>(rd()) << 32) | static_cast<std::uint64_t>(rd());
  }
  // (engine, original_seed) keyed by Random*. Original seed is what
  // Random#seed returns — mt19937_64 doesn't expose recoverable seed,
  // so we remember what we initialised with.
  struct Slot { std::mt19937_64 engine; std::uint64_t seed; };
  inline std::unordered_map<BasicObject*, Slot>& per_obj() {
    static std::unordered_map<BasicObject*, Slot> m;
    return m;
  }
  inline Slot& slot_for(BasicObject* v, std::uint64_t default_seed) {
    auto& m = per_obj();
    auto it = m.find(v);
    if (it != m.end()) return it->second;
    return m.emplace(v, Slot{std::mt19937_64{default_seed}, default_seed}).first->second;
  }
  inline std::mt19937_64& rng_for(BasicObject* v) {
    if (v == nil_instance()) return default_rng();
    return slot_for(v, fresh_seed()).engine;
  }
}

BasicObject* intrinsic_random_new_seed(BasicObject* /*receiver*/) {
  // Ruby returns a 128-bit seed; box-first stays 64-bit until users
  // notice (de-intrinsification flagged this is a soundness gap).
  return new Integer(static_cast<int64_t>(random_detail::fresh_seed()));
}

BasicObject* intrinsic_random_new(BasicObject* /*receiver*/, BasicObject* seed) {
  // Default seed comes from the keyword default in random.rb
  // (`seed = Intrinsics.random_new_seed(nil)`), so seed is always an
  // Integer here. Allocate a fresh Random instance and seed its slot.
  // static_cast<Integer*>: Ruby wrapper guarantees seed is Integer or
  // nil; the protocol is one-step removed from user code.
  std::uint64_t s = (seed == nil_instance())
      ? random_detail::fresh_seed()
      : static_cast<std::uint64_t>(static_cast<Integer*>(seed)->raw_);
  // Direct allocation — going through Random_CLASS->m_new would loop
  // because Random.new is itself defined as Intrinsics.random_new
  // in lib/core/4.0/random.rb. The struct has no required init.
  Random* obj = new Random();
  // Seed via m_initialize so universe.rb's MT19937 class state (seed_,
  // mt_[]) is initialised — the user-visible Random#seed / Random#rand
  // dispatch to universe.rb's m_seed / m_rand which read those members.
  // Going through Random_CLASS->m_new would loop (Random.new is itself
  // this intrinsic), so call m_initialize directly on the fresh obj.
  Array* init_args = new Array();
  init_args->data.push_back(seed == nil_instance()
                              ? static_cast<BasicObject*>(new Integer(static_cast<int64_t>(s)))
                              : seed);
  obj->m_initialize(univ, init_args, &EMPTY_KWARGS, nil_instance());
  // Also keep per_obj populated so intrinsic_random_rand (the path
  // used by `Random.rand` class method and any code that calls the
  // intrinsic directly) keeps working too.
  random_detail::per_obj().emplace(obj, random_detail::Slot{std::mt19937_64{s}, s});
  return obj;
}

BasicObject* intrinsic_random_seed(BasicObject* v) {
  if (v == nil_instance()) return new Integer(0);  // default rng has no recoverable seed
  auto& m = random_detail::per_obj();
  auto it = m.find(v);
  return new Integer(it == m.end() ? 0 : static_cast<int64_t>(it->second.seed));
}

BasicObject* intrinsic_random_state(BasicObject* v) {
  return intrinsic_random_seed(v);  // box-first conflates state ≅ seed
}

BasicObject* intrinsic_random_rand(BasicObject* v, BasicObject* n) {
  auto& rng = random_detail::rng_for(v);
  if (n == nil_instance()) {
    std::uniform_real_distribution<double> dist(0.0, 1.0);
    return new Float(dist(rng));
  }
  // m_class() identity check before static_cast — the Ruby wrapper
  // Random#rand passes n through directly, so n could be Integer,
  // Float, Range, or anything else. Branch on the actual class
  // rather than guessing.
  if (n->m_class(univ) == reinterpret_cast<BasicObject*>(&Integer_CLASS)) {
    int64_t bound = static_cast<Integer*>(n)->raw_;
    if (bound <= 0) {
      std::fprintf(stderr, "[box-first] random_rand: bound must be positive\n");
      std::abort();
    }
    std::uniform_int_distribution<int64_t> dist(0, bound - 1);
    return new Integer(dist(rng));
  }
  if (n->m_class(univ) == reinterpret_cast<BasicObject*>(&Float_CLASS)) {
    double bound = static_cast<Float*>(n)->raw_;
    std::uniform_real_distribution<double> dist(0.0, bound);
    return new Float(dist(rng));
  }
  std::fprintf(stderr, "[box-first] random_rand: non-Integer/Float arg not yet supported (got %s)\n",
               n->ruby_class_name());
  std::abort();
}

BasicObject* intrinsic_random_bytes(BasicObject* v, BasicObject* n_obj) {
  // static_cast<Integer*>: random.rb wrapper passes Intrinsics arg
  // through unchanged; the user signed up for the protocol when they
  // called bytes(n) on Random, so n_obj is Integer.
  int64_t n = static_cast<Integer*>(n_obj)->raw_;
  auto& rng = random_detail::rng_for(v);
  String* s = new String();
  s->bytes.resize(n);
  std::uniform_int_distribution<int> dist(0, 255);
  for (int64_t i = 0; i < n; ++i) s->bytes[i] = static_cast<unsigned char>(dist(rng));
  return s;
}

BasicObject* intrinsic_random_urandom(BasicObject* /*receiver*/, BasicObject* n_obj) {
  // static_cast<Integer*>: same protocol as random_bytes — the Ruby
  // wrapper takes an Integer count.
  int64_t n = static_cast<Integer*>(n_obj)->raw_;
  String* s = new String();
  s->bytes.resize(n);
  std::ifstream urandom("/dev/urandom", std::ios::binary);
  if (!urandom) {
    std::fprintf(stderr, "[box-first] random_urandom: /dev/urandom unavailable\n");
    std::abort();
  }
  urandom.read(reinterpret_cast<char*>(s->bytes.data()), n);
  return s;
}

BasicObject* intrinsic_random_marshal_load(BasicObject* /*v*/, BasicObject* /*data*/) {
  // marshal-roundtrip of Random state is exotic and unused by hello.rb
  // / frozone.rb itself. Loud abort until something asks for it.
  std::fprintf(stderr, "[box-first] random_marshal_load not yet supported\n");
  std::abort();
}


}  // namespace Ruby

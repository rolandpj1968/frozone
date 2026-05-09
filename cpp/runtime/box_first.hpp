// Box-first C++ runtime — minimal infrastructural header.
//
// Only carries what's truly invariant across any compiled program:
// libc + Boehm + the GC init macro. Class definitions (BasicObject,
// Object, NilClass, etc.) live in the emitted .cpp file because their
// vtable surface is a function of the program's call universe — known
// only at closed-world analysis time.
//
// Why per-program emission rather than a header-resident base?
//   1. C++ doesn't allow re-opening a class, so we can't add per-program
//      m_* slots to a header-defined BasicObject.
//   2. Anything that derives from a per-program class must itself be
//      per-program (its vtable layout depends on the base).
//   3. Cascading from (1)+(2): everything class-related ends up emitted.
//
// See memory/project_radical_box_first.md for the pinned plan.

#ifndef FROZONE_BOX_FIRST_HPP
#define FROZONE_BOX_FIRST_HPP

#include <cstdio>
#include <cstdlib>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>
#include <unordered_map>
#include <string>
#include <functional>
#include <initializer_list>
#include <atomic>
#include <type_traits>
#include <limits>
#include <cmath>
#include <random>
#include <gc.h>
#include <onigmo.h>
#include <execinfo.h>
#include <filesystem>
#include <sys/stat.h>
#include <unistd.h>
#include <fstream>
#include <sstream>
#include <chrono>

#define FROZONE_GC_INIT() GC_INIT()

// Global operator new/delete override — route ALL C++ heap
// allocations through Boehm so they're GC-tracked and reclaimable.
//
// Why: the gen has many `new T*` style allocations (block-local
// pointer slots, captured locals, etc.) that are NOT BasicObject
// subclasses, so they don't pick up the class-scoped Boehm
// allocator on BasicObject. Without the global override they'd
// leak forever — observed at ~17 MB/sec on hello.rb.
//
// `operator delete` is a no-op: Boehm sweeps when nothing
// references the allocation. STL destructors that "free" via
// delete still run on scope exit; they just hand control back to
// Boehm.
//
// Caveat (the dustman issue): libstdc++.so's *internal* calls to
// `operator new`/`operator delete` (e.g. `std::string::reserve`
// freeing its old buffer) are bound at link time to versioned
// symbols (`_Znwm@GLIBCXX_3.4`, `_ZdlPv@GLIBCXX_3.4`) which the
// dynamic linker resolves to libstdc++.so's own libc-backed
// definitions — NOT to our weak unversioned override. So
// libstdc++.so's own buffer allocations end up in libc malloc,
// and freeing them via libstdc++.so's own `free()` is fine
// (consistent allocator). Trouble arises only when a buffer
// allocated via OUR override (Boehm) reaches libstdc++.so's
// internal `free()` path — observed in `std::filesystem::path::
// operator/=`, which prompted us to sidestep `std::filesystem`
// in `fs_detail` (see intrinsics.hpp). As long as the gen and
// runtime avoid feeding Boehm pointers into libstdc++ internals,
// the override is safe.
inline void* operator new(std::size_t s)             { return GC_MALLOC(s); }
inline void* operator new[](std::size_t s)           { return GC_MALLOC(s); }
inline void  operator delete(void*) noexcept         {}
inline void  operator delete[](void*) noexcept       {}
inline void  operator delete(void*, std::size_t) noexcept {}
inline void  operator delete[](void*, std::size_t) noexcept {}

// Boehm-aware allocator for STL containers. Boehm's conservative
// scanner doesn't trace libc-malloc'd memory by default, so pointers
// stored inside a default-allocated std::vector<BasicObject*> become
// invisible — Boehm collects the boxes prematurely and we segfault.
// Routing the vector's internal buffer through GC_MALLOC keeps those
// pointers traceable.
template<typename T>
struct GcAllocator {
  using value_type = T;
  GcAllocator() = default;
  template<typename U> GcAllocator(const GcAllocator<U>&) noexcept {}
  T* allocate(std::size_t n) { return static_cast<T*>(GC_MALLOC(n * sizeof(T))); }
  void deallocate(T*, std::size_t) noexcept {}  // Boehm collects
};
template<typename A, typename B>
bool operator==(const GcAllocator<A>&, const GcAllocator<B>&) noexcept { return true; }
template<typename A, typename B>
bool operator!=(const GcAllocator<A>&, const GcAllocator<B>&) noexcept { return false; }

// RAII for `ensure` blocks. Constructed at the top of the lambda that
// frames a begin/rescue/ensure expression; the lambda f_ runs on any
// scope exit (normal return, exception propagation through the catch,
// re-throw from a rescue arm). Mirrors Ruby's ensure semantics where
// the block ALWAYS runs after the begin.
template<typename F>
struct EnsureGuard {
  F f_;
  explicit EnsureGuard(F f) : f_(std::move(f)) {}
  ~EnsureGuard() { f_(); }
  EnsureGuard(const EnsureGuard&) = delete;
  EnsureGuard& operator=(const EnsureGuard&) = delete;
};
// CTAD deduction guide so callers can write `EnsureGuard g([&]() {...});`.
template<typename F> EnsureGuard(F) -> EnsureGuard<F>;

namespace Ruby { struct BasicObject; struct Array; }

// ProcFn — type-erased `BasicObject*(Array*)` callable, replacing
// `std::function`. The closure storage is allocated via explicit
// `GC_MALLOC` + placement-new so captured `BasicObject*` pointers
// stay traced by Boehm.
//
// Why not std::function: std::function's internal _Base_manager
// allocates capture buffers via global `operator new`. Even with a
// global override, libstdc++.so's calls bind to the versioned symbol
// `_Znwm@GLIBCXX_3.4` which the dynamic linker resolves to
// libstdc++.so's libc-backed definition — the override is bypassed.
//
// We never delete the closure storage explicitly: Boehm reclaims it
// when the owning Proc becomes unreachable. The captured Fn object
// is destroyed implicitly (no destructor call); for our use case
// this is fine — captures are pointers/values, no resources.
struct ProcFn {
  using Invoker = Ruby::BasicObject* (*)(void* buf, Ruby::Array*);
  Invoker invoke_ = nullptr;
  void* buf_ = nullptr;

  ProcFn() = default;

  template<typename F,
           typename = std::enable_if_t<!std::is_same_v<std::decay_t<F>, ProcFn>>>
  ProcFn(F&& f) {
    using Fn = std::decay_t<F>;
    static_assert(std::is_invocable_r_v<Ruby::BasicObject*, Fn, Ruby::Array*>,
                  "ProcFn callable must have signature BasicObject*(Array*)");
    void* mem = GC_MALLOC(sizeof(Fn));
    new (mem) Fn(std::forward<F>(f));
    buf_ = mem;
    invoke_ = +[](void* b, Ruby::Array* a) -> Ruby::BasicObject* {
      return (*static_cast<Fn*>(b))(a);
    };
  }

  Ruby::BasicObject* operator()(Ruby::Array* a) const { return invoke_(buf_, a); }
  explicit operator bool() const { return invoke_ != nullptr; }
};

// Non-local control flow out of block bodies. Both are NEVER subclasses
// of Ruby::Exception — user `rescue` clauses must not catch them, only
// our compiler-emitted catches do.
//
// BreakException — `break v` inside a block escapes the iterator. Caught
// at the call site of the iterator method (where the block was passed);
// the iterator's call expression evaluates to e.value.
//
// ReturnException — `return v` inside a block escapes the enclosing
// METHOD (Ruby's return-from-block semantics). Carries a target frame
// ID; each method body has a unique `__frame_id__` declared at entry,
// and its catch re-raises if `e.target_frame != __frame_id__`. This
// lets `list.fetch(k) {return nil}` propagate past fetch's own catch
// (whose frame doesn't match) and land at search's catch (whose
// frame does — search created the block).
//
// Lightweight POD types thrown by value, caught by reference. C++ can
// throw any complete type — these don't need a base, no RTTI cost.
struct BreakException  { Ruby::BasicObject* value; };
struct ReturnException { Ruby::BasicObject* value; std::uint64_t target_frame; };

// Per-invocation frame ID. Atomic so concurrent threads don't collide.
// Address-of-stack-local would also work but a counter is portable.
inline std::uint64_t next_frame_id() {
  static std::atomic<std::uint64_t> counter{0};
  return ++counter;
}

#endif  // FROZONE_BOX_FIRST_HPP

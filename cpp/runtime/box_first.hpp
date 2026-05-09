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

// We do NOT override the global `operator new`/`operator delete`.
//
// Boehm coverage instead comes from three targeted entry points:
//   1. BasicObject defines a class-scoped `operator new` that
//      routes through GC_MALLOC. Every Ruby box subclass uses it.
//   2. STL containers that hold BasicObject* pointers (Array data,
//      Hash buckets, Symbol intern table, MatchData captures, …)
//      are parameterised with `GcAllocator<T>`, so their internal
//      buffers are GC_MALLOC-backed.
//   3. `gc_box<T>` (below) and `ProcFn` allocate via explicit
//      GC_MALLOC + placement-new, covering the captured-local
//      cells the codegen emits and the closure storage backing
//      Proc respectively.
//
// Anything else (libstdc++ internals: std::string buffers,
// std::filesystem::path tokenisation, std::stringstream rdbuf,
// parser-internal std::vector<int>) allocates via libc malloc
// inside libstdc++.so and frees via libc free — consistent
// allocator path, no abort risk, no Boehm-tracking concern
// (these buffers don't hold BasicObject* pointers we care about
// reclaiming).
//
// The previous global override caused aborts because libstdc++.so's
// internal calls to `operator new` / `operator delete` are bound at
// link time to versioned symbols (`_Znwm@GLIBCXX_3.4` etc.) which
// the dynamic linker resolves to libstdc++.so's own libc-backed
// definitions — NOT to our weak unversioned override. A buffer
// allocated via our override (Boehm) freed via libstdc++.so's
// internal `free()` path → `free(): invalid pointer` abort
// (originally observed in `std::filesystem::path::operator/=`).

// gc_box<T> — Boehm-allocated single-value cell. Used by the gen
// to box mutable locals that are shared across closure captures
// (so an inner lambda can hold the cell pointer by value and
// outlive the enclosing stack frame). Each emit site looked like
// `new BasicObject*(initial)` previously; the gen now emits
// `gc_box<BasicObject*>(initial)`.
//
// Why not plain `new`: explicit GC_MALLOC + placement-new keeps
// these allocations Boehm-tracked without depending on the
// global operator-new override, which is fragile because
// libstdc++.so's internal `new` calls bind to versioned symbols
// (`_Znwm@GLIBCXX_3.4`) that bypass our weak unversioned
// override. By going direct to GC_MALLOC at every site that
// matters for tracing, we don't need the global override at all.
template<typename T>
inline T* gc_box(T value) {
  T* p = static_cast<T*>(GC_MALLOC(sizeof(T)));
  new (p) T(std::move(value));
  return p;
}

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

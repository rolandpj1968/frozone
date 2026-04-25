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
#include <cstring>
#include <vector>
#include <unordered_map>
#include <string>
#include <functional>
#include <initializer_list>
#include <gc.h>

#define FROZONE_GC_INIT() GC_INIT()

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

#endif  // FROZONE_BOX_FIRST_HPP

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
#include <vector>
#include <initializer_list>
#include <gc.h>

#define FROZONE_GC_INIT() GC_INIT()

#endif  // FROZONE_BOX_FIRST_HPP

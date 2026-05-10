# layouts.hpp split

Box-first emits one `frozone_layouts.hpp` that — until this work — was
a single ~56k-line monolith every translation unit had to `#include`.
At 660+ classes × 1235 TUs that drove most of the build cost:

- 487 MB of `.debug_info` (DWARF emitted per type per TU)
- ~9 min full compile, ~11 GB peak RAM
- Editing one method body: `make` invalidates the PCH and rebuilds everything

This doc tracks the staged split into per-class headers with precise
include chains.

---

## Why per-class .hpps work cleanly

Frozone's universal call protocol means every method signature is

```cpp
BasicObject*(Array* args, Hash* kwargs, BasicObject* block);
```

— `BasicObject*` everywhere, no class types in signatures except as
pointers. Combined with:

- Inheritance is a DAG (topo-sortable: parent struct precedes child)
- Ivars are stored as `BasicObject*` (forward decl suffices)
- Method bodies live in `.cpp`, not inline in headers

…all the apparent struct-definition cycles dissolve. A per-class
header only needs:

```cpp
#pragma once
#include "../frozone_base.hpp"   // forward decls + universal types + tables
#include "<Parent>.hpp"          // for the inheritance struct base

namespace Ruby {
struct Foo : Parent {
  // ivars + method DECLs
};
}  // namespace Ruby
```

The "selective inline-in-header for small leaf-class methods"
follow-up — the manual alternative to LTO discussed elsewhere — is
the place where header cycles WOULD start to bite, because inline
bodies use concrete classes. Defer until base + per-class split is
solid and the codebase has settled.

---

## Staging

### Stage 1 ✅ — extract `frozone_base.hpp`

Commit `2d882a5`.

Move out of `frozone_layouts.hpp` into a new `frozone_base.hpp`:

- Forward declarations (`struct Foo;` for all classes)
- Free-function decls (`ruby_puts`, `intern`, `splat_to_array`,
  `g_global_or_nil`, etc.)
- `METHOD_NAMES` table (~5000 entries)
- IS_A LUT externs + `N_CLASSES` + `CLASS_BY_ID` extern

`frozone_layouts.hpp` continues to exist and opens with
`#include "frozone_base.hpp"`. Per-class TUs unchanged (still
`#include "frozone_layouts.hpp"`). No per-TU compile cost change —
this stage just proves the stream-split mechanics. The new `:base`
emit-stream is the foundation for Stage 2.

### Stage 2 ✅ — per-class `class/<Name>.hpp`

Each class struct emitted to its own `cpp/gen/box/class/<Name>.hpp`:

```cpp
#pragma once
#include "../frozone_base.hpp"
#include "<Parent>.hpp"   // recursive parent chain ascends to BasicObject

namespace Ruby {

struct Foo : Parent {
  // ivars (BasicObject* — forward decls suffice for cross-class refs)
  // method DECLs (universal-protocol signature, no class-by-value)
};

}  // namespace Ruby
```

`frozone_layouts.hpp` becomes a meta-header that `#include`s every
`class/<Name>.hpp` in topo order, then opens its own `namespace Ruby
{ ... }` block for post-class content (int literals, intrinsics impl
include, class-var storage, singletons).

After Stage 2: `frozone_layouts.hpp` shrinks 50k → 2.5k lines (now
mostly meta-includes); 650 per-class hpps in `cpp/gen/box/class/`.

Per-class .cpps still `#include "frozone_layouts.hpp"` for backward
compat — **no per-TU cost win yet**. That comes in Stage 3.

### Stage 3 — precise per-`.cpp` includes (pending)

Each per-class `.cpp` file lists only the class hpps its method
bodies actually reference. Implementation idea: a pre-pass over each
method body walks its AST collecting concrete-type usages
(`static_cast<Foo*>`, `new Bar`, `&Baz_CLASS`, ivar-typed access).
Mechanics mirror `collect_call_surface` (already a similar pre-pass).

Per-`.cpp` shape becomes:

```cpp
#include "class/ThisClass.hpp"
#include "class/UsedFromMethodBodies.hpp"   // computed, not "include the world"
// no #include "frozone_layouts.hpp"

namespace Ruby {
// method bodies
}  // namespace Ruby
```

Win: per-TU compile cost drops from "parse 56k-line monolith" to
"parse parent chain + N referenced classes". DWARF emission scales
with what each TU touches. Incremental rebuilds become surgical
(edit one method body → recompile one TU, often skipping the PCH).

`frozone_layouts.hpp` may stay as a meta-header for emergencies (or
auxiliary files like `frozone_universe.cpp` / `frozone_static.cpp`
that genuinely want the world); at this point it's no longer on the
critical path.

---

## Stream-system mechanics

`Cpp::Emitter` provides `with_stream(name) { ... }` which routes
`emit.line` calls into a named buffer. `lib/frozone/ast/frozone_compile.rb`
maps each named buffer to a file on disk:

| Stream | File |
|---|---|
| `:base` | `cpp/gen/box/frozone_base.hpp` (Stage 1) |
| `:layouts` | `cpp/gen/box/frozone_layouts.hpp` |
| `:default` | `cpp/gen/box/frozone.cpp` |
| `:universe` | `cpp/gen/box/frozone_universe.cpp` |
| `:static` | `cpp/gen/box/frozone_static.cpp` |
| `:main` | `cpp/gen/box/frozone_main.cpp` |
| `:class_<Name>` | `cpp/gen/box/frozone_class_<Name>.cpp` (TU split) |
| `:class_hpp_<Name>` | `cpp/gen/box/class/<Name>.hpp` (Stage 2) |

The `class/` subdirectory is created on demand
(`FileUtils.mkdir_p(File.dirname(path))` in `frozone_compile.rb`).

## Stale-file note

The streams system writes atomically (write-if-different) but does
NOT delete files for streams that no longer exist. After splitting,
stale `frozone_class_*.cpp` or `class/<Name>.hpp` from older runs
can survive unless cleaned up. Either run `git clean cpp/gen/box/`
before each AOT regen, or add a cleanup phase to the build script.
Matters mostly during development; production gets it via fresh
checkout.

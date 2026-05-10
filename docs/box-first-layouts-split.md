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

### Stage 3 Path 1 — pruner-integrated class-ref collection (landed)

`collect_call_surface`'s AST walk now also populates
`host_class_refs[<host_flat>] = Set of referenced classes`, derived
from any `Ast::ConstantRead`/`Ast::ConstantPath` that resolves
through the existing `const_path_to_class` helper (extended to also
recognise universe classes — FloatDomainError, StopIteration, etc.).
Two-host attribution: `host_calls` (m.scopes.last, for existing
call_surface widening) and `host_refs` (the enclosing class whose
methods_table found the method); for overlaid methods both hosts
get the refs.

Per-class `.cpp` emit unions across the host's full ancestor chain
(via `Vm::ClassObject#ancestors_list`) so module-included methods'
refs flow into the including class's include set. Plus the host's
own eigenclass for `&<This>_CLASS` references.

The collected per-`.cpp` precise include set is *emitted* but
currently sits alongside the `frozone_all.hpp` PCH meta-include —
the precise lines are decorative no-ops via `#pragma once`. They
document the dependency set that Stage 4 will switch consumption to.

### Stage 3 Path 2 — `frozone_post.hpp` + `frozone_all.hpp` PCH (landed)

Two structural moves:

1. **`frozone_post.hpp`** extracts the post-class content (int
   literals, raw int arrays, `EMPTY_ARGS`/`EMPTY_KWARGS` storage,
   intrinsics impl include, class-var storage) from
   `frozone_layouts.hpp` into its own header. Pulls in the universal
   value-type hpps that the post-class inline-variable definitions
   need (Integer for int literals, Array for EMPTY_ARGS, etc.).

2. **`frozone_all.hpp`** is a tiny meta-header (`#pragma once` +
   `#include "frozone_base.hpp"` + `#include "frozone_post.hpp"` +
   `#include "frozone_layouts.hpp"`). It's the **PCH cache root**:
   per-class `.cpp` starts with `#include "frozone_all.hpp"` so gcc
   activates `frozone_all.hpp.gch` and the entire universe loads
   from cache. Decouples PCH input from include strategy: when
   `layouts.hpp` eventually goes (Stage 4), we just edit
   `frozone_all.hpp`'s include list — per-class `.cpp` first-include
   line doesn't change.

**Build cost:** unchanged (~9 min full rebuild). PCH efficiency
preserved by routing through `frozone_all.hpp`. The per-class .cpp's
precise includes after `frozone_all.hpp` are decorative no-ops —
they document the precise set Stage 4 will switch to.

### Stage 4 — close the auto-stub gap (pending)

Path 2 attempted to drop `layouts.hpp` from per-class `.cpps` but ran
into the **auto-stub gap**: emitter-generated method bodies reference
classes that don't appear in the AST walk. Examples:

- Universal constant surface: every eigenclass auto-emits `c_X`
  stubs that return `&X_CLASS` for each `X` in the const surface.
  Generated by `inject_module_constant_overrides`, not from user
  AST → `host_class_refs` doesn't see the references.
- `mm_dispatch` fallback bodies on `BasicObject`: reference
  `NoMethodError`, `TypeError` for the default raise paths.
- Hand-coded universe-class methods (in `runtime/universe.rb`):
  literal C++ strings that may reference exotic classes.

Stage 4 closes this by either:

1. **Walking the auto-stub generation** (mirror the AST collection
   for the synthetic bodies as they're generated, populating
   `host_class_refs` from the same point).
2. **Maintaining an explicit augmentation map** for each universe
   class with hand-coded methods (small bounded set, ~24 entries).

Once closed, `frozone_all.hpp` drops the `#include "frozone_layouts.hpp"`
line, the PCH shrinks correspondingly, and per-class `.cpps` parse
just `frozone_all.hpp` (which still has base + post + universal value
types) plus their precise per-class refs. No more 56k-line meta-include
in the per-TU parse.

Win: per-TU compile cost drops substantially. DWARF emission scales
with what each TU touches. Incremental rebuilds become surgical (edit
one method body → recompile one TU, often skipping the PCH).

`frozone_layouts.hpp` itself can stay as a meta-header for
`frozone.cpp`/`frozone_universe.cpp`/`frozone_static.cpp` that
genuinely want the world; at this point it's no longer on the
critical path.

---

## Stream-system mechanics

`Cpp::Emitter` provides `with_stream(name) { ... }` which routes
`emit.line` calls into a named buffer. `lib/frozone/ast/frozone_compile.rb`
maps each named buffer to a file on disk:

| Stream | File |
|---|---|
| `:base` | `cpp/gen/box/frozone_base.hpp` (Stage 1) |
| `:post` | `cpp/gen/box/frozone_post.hpp` (Stage 3 Path 2) |
| `:layouts` | `cpp/gen/box/frozone_layouts.hpp` |
| `:all_hpp` | `cpp/gen/box/frozone_all.hpp` (Stage 3 Path 2 — PCH cache root) |
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

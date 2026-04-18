# GC Design

## Context

The C++ backend currently uses `std::shared_ptr<Impl>` for all user
class instances. This gives correct Ruby reference semantics (aliasing
on copy) but pays atomic refcount traffic on every copy/destroy. The
splay benchmark showed this: 75% of runtime was in `std::any` copy
management before dead-store elimination, and even after, shared_ptr
overhead is the primary cost for allocation-heavy workloads.

Crystal uses Boehm GC (conservative, non-moving, stop-the-world).
It amortises allocation cost better than refcounting — binarytrees is
2x faster in Crystal than C++. But Boehm has its own costs: conservative
scanning (false retention), no compaction (fragmentation), and full
stop-the-world pauses.

Neither is the right long-term answer for Frozone.

## Target: Immix collector

Immix is a mark-region collector with line/block granularity:

- **Blocks** (~32KB): the large allocation unit. Each block is divided
  into **lines** (~128 bytes).
- Allocation bumps a pointer within a line. When a line fills, skip to
  the next free line in the block. When the block fills, request a new
  block from the global pool.
- Collection marks live objects, then reclaims at LINE granularity:
  lines with no live objects are immediately reusable. Blocks where ALL
  lines are free are returned to the global pool.
- **Opportunistic evacuation**: when a block is mostly dead (few live
  lines), the collector can MOVE the surviving objects to a fresh block,
  fully reclaiming the fragmented block. This is optional per-block —
  not a full copying collection.

### Why Immix for Frozone

- **Bump allocation** is nearly free — a pointer increment + bounds
  check. Comparable to stack allocation. shared_ptr's `make_shared`
  calls `operator new` (global heap lock, free-list search) which is
  orders of magnitude more expensive.
- **No refcount traffic** — copies are just pointer copies, no atomic
  increment/decrement. This is the primary shared_ptr cost that makes
  splay and binarytrees slow.
- **Line-granularity reclamation** avoids the fragmentation problems of
  non-moving collectors without requiring a full copying pass.
- **Opportunistic defragmentation** keeps the heap compact without
  worst-case pause times.

## Thread-local allocation buffers (TLABs)

Each thread gets a **thread-local allocation buffer** — a range of
lines within a block that the thread owns exclusively. Allocation is
a local pointer bump with no synchronisation:

```
alloc(size):
  if cursor + size <= tlab_end:
    obj = cursor
    cursor += size
    return obj
  else:
    refill_tlab()  // get new lines from global pool (rare, locked)
    retry
```

This makes allocation effectively free in the fast path — no locks,
no atomics, just a compare + increment. The only synchronisation is
when a TLAB is exhausted and needs refilling from the global block pool.

For single-threaded Frozone (current state), there's one TLAB and zero
synchronisation. When native threads land, each thread gets its own
TLAB — allocation stays lock-free.

## Generational collection

Most objects die young (generational hypothesis). A generational
collector exploits this:

- **Nursery (young generation)**: small, collected frequently. Most
  objects allocated here die before the first collection. Nursery
  collection is fast because it only scans young objects + remembered
  set.
- **Tenured (old generation)**: objects that survive N nursery
  collections get promoted. Collected less frequently (major GC).

The remembered set tracks old→young pointers (created when an old
object's field is mutated to point to a young object). This requires
a **write barrier** on every pointer store:

```
write_barrier(obj, field, new_value):
  *field = new_value
  if obj.old? && new_value.young?:
    remembered_set.add(obj)
```

Frozone's closed-world analysis can **elide write barriers** for
fields that are provably never mutated after construction (immutable
objects, frozen objects, objects whose fields are only set in
`initialize`). This is a significant optimisation — write barriers
have measurable overhead on mutation-heavy code.

## Incremental / concurrent collection

Stop-the-world pauses are proportional to heap size. For real-time
or interactive Ruby programs, this matters. Options:

- **Incremental marking**: mark a fixed number of objects per
  allocation (or per safepoint), spreading the mark phase across
  many mutator time slices. Requires a write barrier to track
  new pointers created during marking (tri-colour invariant).
- **Concurrent marking**: a background GC thread marks objects
  while mutator threads run. Requires careful synchronisation
  but eliminates pause-time proportional to heap size.
- **Concurrent sweeping**: sweep (reclaim) in background after
  marking completes. Simpler than concurrent marking.

Immix is well-suited to incremental/concurrent marking because its
block/line structure gives natural work units — mark one block at
a time, with progress tracked per-block.

## Precise vs conservative

- **Conservative** (Boehm): scans the stack and registers for anything
  that LOOKS like a pointer. Can't move objects (might relocate a
  value that's actually an integer). Retains some garbage (integers
  that happen to look like heap addresses).
- **Precise**: the collector knows exactly which stack slots and object
  fields contain pointers. Can move objects freely (update all pointers).
  Requires a stack map at each safepoint.

Frozone can do **precise collection** because we control the generated
code. At each safepoint, we know exactly which locals are live and
which are pointers (from TI). The emitter generates a stack map:
a bitmap per safepoint indicating which frame slots contain GC roots.

This is where the safepoint infrastructure (loop backedges, method
calls) becomes load-bearing — each safepoint needs a stack map for
precise scanning.

## Frozone's closed-world advantages for GC

1. **Escape analysis**: we know which objects never escape their
   allocating method. These can be **stack-allocated** (zero GC
   cost). Ruby can't do this because any method could capture `self`
   via closure or `ObjectSpace`.

2. **Immutability analysis**: objects whose fields are only set in
   `initialize` and never mutated can skip write barriers entirely.
   Frozen objects too. TI tracks which ivars are ever written outside
   init.

3. **Precise stack maps**: TI knows the type of every local at every
   program point. The emitter generates exact root sets — no
   conservative scanning needed.

4. **Object layout**: TI knows the exact set of ivars per class and
   their types. Objects can be laid out with pointer fields grouped
   together (faster scanning) and primitive fields excluded from
   GC scanning.

5. **Allocation sinking**: if an object is allocated, written to, and
   then only read (never escapes), the allocation can be sunk into
   registers / stack — the object never hits the heap at all. This
   is the ultimate optimisation for short-lived intermediate objects.

## Existing C++ GC frameworks

Before building from scratch, evaluate existing options:

- **libgc (Boehm)**: conservative, non-moving, mature. Crystal uses
  this. Drop-in replacement for malloc — no code changes needed. But
  conservative scanning means no compaction, false retention, and the
  collector can't move objects. Good enough for Crystal but leaves
  performance on the table for a language implementation that controls
  its own object layout.

- **Oilpan** (Chromium/Blink): precise, incremental, concurrent.
  Designed for C++ DOM objects in a browser. Uses trace methods on
  each class (`void trace(Visitor*)`) for precise root enumeration.
  Battle-tested at Google scale. More complex API than Boehm but
  gives precise collection + incremental marking. Worth evaluating
  as a middle ground — we'd implement `trace()` on each generated
  class, which the emitter can auto-generate from the ivar list.

- **SGCL** (Simple Garbage Collection Library): precise, concurrent,
  designed for general C++ use. Less battle-tested than Oilpan but
  simpler API. Uses smart pointer wrappers (`sgcl::gc_ptr<T>`) which
  is closer to our current shared_ptr usage — migration would be
  a type substitution.

The trade-off: using an existing framework is faster to ship but
constrains our design. A custom Immix collector tailored to Frozone's
object model gives the best performance (stack allocation for
non-escaping objects, write barrier elision from immutability analysis,
exact stack maps from TI). The existing frameworks can't exploit
Frozone's closed-world knowledge.

**Pragmatic path**: start with Boehm (drop-in, validates the "no
refcount" hypothesis), then evaluate Oilpan for incremental/precise,
then custom Immix if we need the last 20% from escape analysis and
stack allocation.

## Migration path from shared_ptr

1. **Now**: shared_ptr works, correct, easy to debug. Performance
   is acceptable for compute-heavy benchmarks (fib 63x MRI).
   Allocation-heavy benchmarks pay the refcount tax (binarytrees
   3.9x MRI vs Crystal's 8.1x).

2. **Phase 1 — arena allocator**: replace `make_shared` with a
   simple bump allocator (no GC yet, just leak). Measures the
   allocation-cost ceiling — how fast could we be if allocation
   were free? This validates the TLAB design.

3. **Phase 2 — mark-sweep on arena**: add a mark phase (walk roots,
   mark reachable objects) and sweep (reset arena). No compaction,
   no generations. Proves the safepoint + stack map infrastructure.

4. **Phase 3 — Immix**: line/block structure, opportunistic
   evacuation. Full generational with nursery + tenured.

5. **Phase 4 — incremental/concurrent**: if pause times matter.
   Probably deferred until Frozone targets interactive programs.

## Interaction with concurrency

GC and threading are deeply coupled:

- Safepoints serve both GC (stack scanning) and threads (cooperative
  yield). One infrastructure, two consumers.
- TLABs are per-thread — allocation stays lock-free.
- Write barriers are needed for both generational GC and concurrent
  GC correctness.
- Frozone's escape analysis determines which objects need
  synchronisation (thread-shared) vs which are thread-local (no sync).

The closed-world analysis advantage: we can prove at compile time
that most objects are thread-local, avoiding both synchronisation
overhead AND write-barrier overhead for those objects.

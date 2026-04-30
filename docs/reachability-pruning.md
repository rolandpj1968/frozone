# Reachability pruning — design notes

## Why

Box-first AOT compiles a closed-world snapshot. Without pruning every
`Vm::ClassObject` in `@top_level_scope.constants_table` ships into
every emitted program, plus every method on every such class, plus
every constant. For a 4-line user script that's:

| stage             | cpp LoC | binary  | g++ -O2  |
|-------------------|---------|---------|----------|
| no pruning        | ~480k   | ~64MB   | ~10 min  |
| class-level       | ~140k   | ~25MB   | ~3 min   |
| + method-level    | ~50k    | ~13MB   | ~1 min   |

The remaining ~50k LoC / 13MB are still mostly dead weight — most
of it is the residual surface of "any class with a kept method"
plus the IS_A LUT, METHOD_VT, per-class `respond_to_q` static bool
arrays, ENV / encoding tables, etc. Sections [§Future](#future)
sketch the levers we haven't pulled yet.

Compile time is now in the "tractable iteration loop" range but
still unpleasant. The motivating context is closed-world AOT for
real programs (WQ self-compile, larger benchmarks); class-level
pruning unblocks per-test debug cycles, method-level halves it
again, and there's another order-of-magnitude on the table.

## What's landed

### Class-level reachability (`lib/frozone/compiler/reachability.rb`)

Backend-independent module — Crystal / legacy-cpp can share. A
class is reachable iff:

1. its constant name appears as a `ConstantRead` / `ConstantPath`
   in some reachable AST,
2. it's the class of a value referenced through `@user_constants`
   (the `new XClass()` in `k_<flat>()` accessors), OR
3. it's an ancestor (parent class or included module) of a
   reachable class.

Iterates to fixpoint. Universe classes (BasicObject, Object,
Integer, Array, Hash, Module, Class, Numeric, …) always emit —
they're always reachable since they back the runtime universe.

`@user_classes` after pruning contains only classes that the
program transitively touches. In `bench/stubs/fib.rb`, 56/175
user classes are kept (Time, Set, Complex, Encoding, Errno
subclasses, ObjectSpace, Process, IO, Thread, … all dropped).

### Method-level reachability (`collect_call_surface`)

A method name `cpp_X` is in the call surface iff:

1. some reachable AST node calls `:X` via `MethodCall` /
   `AttributeWrite`,
2. it's an auto-generated dispatch slot (`m_new`, `m_initialize`,
   `m_class`, `m_respond_to_q`, `m_method_missing`,
   `m_const_missing`),
3. it's a hand-coded universe override (`Float#m_round`, etc.) —
   needed so `override` keywords on derived classes type-check
   against BasicObject's universal surface,
4. OR it's the implementation site of a name reached via (1)–(3),
   transitively.

The walk seeds from `@execute_block` + top-level user methods,
schedules every body that implements each newly-discovered name
on a reachable class, and walks those bodies for more calls.
Iterates to fixpoint.

Override emission gates by surface membership at three sites:

- `build_chained_overrides` (user-class method chain emission)
- `overlay_overrides_chained` (universe-class method overlay)
- `overlay_overrides` (eigenclass method overlay)

For chains: the head's `cpp_X` membership decides whether the
whole chain emits — including its `sm_X__from_<Origin>` shadow
slots that `super` walks into. This is sound because a chain is
only used when its head is dispatched.

### Hand-coded oddballs

A handful of methods named `m_X` aren't actually Ruby methods —
they're C++ hooks with non-universal signatures. The canonical
case is `BasicObject::m_hash_value` (returns `std::size_t`,
backs `unordered_map`). These are excluded from the surface even
when listed in `hand_coded_method_names`, otherwise METHOD_VT
emits a member-function-pointer typed against the wrong signature.

## What still ships unconditionally

Things that pruning hasn't touched yet — each is a future lever.

### 1. Class struct shells

Even pruned, every kept class emits its full struct: every ivar,
every member field, every type info. For a class that's reachable
but only one of its methods is called, we still emit the entire
ivar list and per-class metadata. **Bound:** num kept classes ×
average ivar count.

### 2. METHOD_VT entries for unused dispatchers

METHOD_VT is sized to call surface, so it shrinks already. But:
the bodies of `m_send` / `m___send__` index into it. If an
out-of-range id is computed, mm_dispatch fires. We could shrink
further if we knew receiver-side at the send site — that's TI
territory.

### 3. Per-class `m_respond_to_q` static bool arrays

Each class emits a `static const bool __X_responds__[1259] = {…}`
indexed by method_id. With the surface pruned to ~350 methods,
this array shrinks but every kept class still emits its own copy.
Numerically: 100 classes × 350 bytes = ~35KB just for the bit
arrays. Could collapse to a 2D LUT or per-class compact bitset.

### 4. Static-state-init for unused constants

`@user_constants` includes everything in `@top_level_scope.constants_table`
that isn't a class. Encodings, Errno instances, Process group ids,
… most of which the program never references. The accessor
emission is gated by class reachability (we don't emit `k_X()` for
a constant whose class was pruned), but the values themselves
still appear in static-state-init. Need a parallel const-level
reachability pass.

### 5. Universe-class overrides

Hand-coded methods on universe classes (Integer's m_plus etc.)
emit unconditionally — they're in `INTEGER.overrides` and pass
through `with_auto_overrides`. If the call surface excludes
m_plus, we still emit it. Cheap to fix: gate the existing-
overrides emission by surface membership too. Caveat: BasicObject's
universal stubs need m_X to exist on the parent for derived
overrides to type-check, so we'd want `override` keyword gating
to track this correctly (the existing `@call_surface_set` does).

### 6. C-string constant tables (METHOD_NAMES, RUBY_PUTS strings, …)

Tens of KB of `static const __NameId__ METHOD_NAMES[] = {…}`. One
entry per surface method. Already shrinks with the surface but
remains the largest static structure for big programs.

### 7. The full IS_A LUT

`bool IS_A[N_CLASSES][N_CLASSES]`. ~150 × 150 bytes today =
~22.5KB. Most entries are 0. Could trade space for time with a
sparse representation (per-class ancestor list + linear search;
or a bloom filter). Or just drop classes that are never argued to
`is_a?`/`kind_of?`/`===` — those don't need a row.

## Future

### Constant-level reachability

Mirror method-level but for `c_X` slots and `k_<flat>()` accessors.
A constant is reachable iff some reachable AST reads it (via
`ConstantRead`, `ConstantPath`, or `<expr>::CONST` dynamic) OR
it's reached through static-state-init's transitive ivar
population. Bonus: the `c_X` virtual surface on BasicObject
shrinks accordingly.

This composes cleanly with class-level reachability — a kept
class's constants are still pruned individually.

### TI-narrowed surfaces

Today's surface is "any method named `:foo` on any reachable
class". With per-call-site receiver types from TI:

- `recv : Integer` → only `Integer#foo` need survive.
- `recv : Foo | Bar` → only those two.
- Untyped receiver → fall back to surface-wide.

Composes with method-level surface — Stage 1 culls cold names,
Stage 2 culls cold (class, name) pairs.

### Aggressive dead-stripping

Once we trust the analysis, `g++ -ffunction-sections
-fdata-sections` + `ld --gc-sections` would let the linker drop
unused virtuals via reachability through the vtable. C++'s
"virtual implies live" semantics prevents most of that today, but
with tight-enough static prediction + dynamic_cast → static_cast
substitution, link-time GC might recover another chunk.

### Empty shells for unused universe classes

For pruned-pruned closed-world, instead of emitting Numeric's
full struct + every member, emit `struct Numeric : Object {};`
when no path reaches it. The C++ class still exists (so
inheritance + IS_A LUT works) but with zero footprint.
Composes with constant-level pruning — Numeric's class object
references go away too if no caller mentions it.

### Per-method receiver-class specialisation

Today every `m_foo` body emits once per class that defines it.
For a method that's called only on `Integer*`, we could specialise
the body for Integer* — drop the `Array* args` boxing, inline the
receiver type. This is the box-first-optimization §1 line.
Composes orthogonally with reachability.

## When to revisit

Class- and method-level pruning land the first ~6× compile-time
win and unblock the iteration loop. The next wave (constant-level,
TI-narrowed) probably another 2–4× but requires either small bits
of additional analysis (constant-level: cheap) or TI integration
(narrowed surfaces: expensive but other-things-want-this anyway).

Aggressive dead-stripping + empty-shell mode is a separate axis —
makes sense when WQ self-compile is functionally complete and we're
focused on output size.

The IS_A LUT and `respond_to_q` arrays are perennial second-order
costs that only matter for very large programs. Address when total
cpp/binary size becomes a problem at the scale we care about.

# Reachability pruning — design notes

## Why

Box-first AOT compiles a closed-world snapshot. Without pruning every
`Vm::ClassObject` in `@top_level_scope.constants_table` ships into
every emitted program, plus every method on every such class, plus
every constant. For a 4-line user script that's:

| stage                      | cpp LoC | size  | g++ -O2  |
|----------------------------|---------|-------|----------|
| no pruning                 | ~480k   | ~64MB | ~10 min  |
| class-level                | ~140k   | ~25MB | ~3 min   |
| + method-name surface      | ~50k    | ~13MB | ~1 min   |
| + chain-tail super-stubs   | ~30k    |  ~8MB | ~30 s    |
| + self-receiver narrowing  | ~20k    |  ~5MB | ~20 s    |

(Numbers above are for `bench/stubs/fib.rb`; ratios are similar for
larger programs. The original frozone-as-frozone build went 75MB →
47MB → ??? as each pruning stage was added — the last stage hadn't
been profiled at the time of writing.)

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

### Chain-tail super-stub pruning (`build_chained_overrides`,
`overlay_overrides_chained`)

For each method on each class, the chain map walks the MRO head→tail
and emits `m_X` for the head plus `sm_X__from_<Origin>` slots for
every shadowed ancestor body that `super` could land on. Most
methods don't `super`, so the tail slots are dead weight.

Tail-pruning rule: starting from the head, only emit the next
`sm_X__from_<Origin>` when the previous body actually contains an
`Ast::Super` node. Stop the moment a body returns without super-ing.
A head that doesn't `super` collapses the whole chain to a single
override.

Implementation: `body_has_super?` walks an AST stopping at nested
`MethodDef` boundaries (each def has its own chain context). Both
`build_chained_overrides` and `overlay_overrides_chained` thread a
`prev_needs_super` flag through their `entries.each_with_index` loop
and `break` once it goes false. Class-origin entries (which lower
super to qualified `this->Parent::m_X` and don't need a host slot)
still update `prev_needs_super` so the chain-tail rule extends past
them.

Net win on the frozone-as-frozone build: 75MB → 47MB (−38%).
Baseline (delegating-stub Vm, hello.rb target): 20MB → 12MB (−42%).
Sound: a body that doesn't `super` can never reach the next slot.

### Stage 3: self-receiver narrowing (experimental)

Method-name surface answers "is this name called *anywhere*?", but
not "is it called on *this class*?". A bare `to_s` inside `Vm#run`
dispatches through Vm's MRO, never through (e.g.) `MatchData`'s. So
for every method with a self-receiver-only call surface, the
override only needs to live on the host class and its descendants —
not on every class that happens to define a method by that name.

Today's surface tracks per-(cpp-name) two pieces:

- `wide`: any explicit-receiver / `__send__` call site exists for
  this name (receiver type is unknown — keep on every class that
  defines it),
- `selfs`: set of host classes whose self-receiver bodies dispatch
  this name (receiver type is the host's instance — keep only on
  classes reachable from a host's MRO).

Stage 3 keep predicate (`method_keepable_for_class?`): the override
on `klass` survives if the surface entry is `wide`, OR some `host`
in `selfs` has `klass` in its `ancestors_list`. The chain emitters
gate on this in addition to the existing surface-membership check.

Self-call attribution comes from the AST walk: `MethodCall` /
`AttributeWrite` with `receiver_node` nil or `Ast::SelfLiteral`
counts as self; everything else widens. The walker carries a `host`
context per body — top-level execute body's host is `@top_level_scope`
(Object), each user method's host is `m.scopes.last`. Block / Proc /
Lambda bodies inherit `host` from their enclosing method (correct:
inline blocks share self with their enclosing scope).

#### `__send__` widening interaction

Self-receiver narrowing collides with the existing `__send__`
widening pass: that pass force-walks every literal Symbol that names
a real method whenever any of `m_send` / `m___send__` /
`m_public_send` is in the surface. Without modification, a name like
`:search` could be attributed only as a self-call (because the only
direct call is via `el.__send__(:search, ...)`) and get pruned away
from the actual dispatch target.

Fix: in the widening loop, mark every send-target symbol as `wide`
unconditionally — even if previously seen as a self-call. The
fixpoint loop terminates when no filter transitions and no newly-
seen symbols remain. Sound for closed-world AOT: the dispatched
name appears literally somewhere; we just don't know on which
receiver, so wide is correct.

#### Known gaps (unsound today)

The cheap inference covers the common case but not these:

- **`define_method(:foo) { ... }`** — the block becomes
  `Foo#foo`. We see `:foo` as a SymbolLiteral but don't classify
  the surrounding `define_method` as a self-defining-call against
  the host class. If the only call to `foo` is through `define_method`
  bodies dispatched at runtime, narrowing may drop the override.
  Workaround: avoid `define_method` for methods on classes that
  also use the box-first AOT pipeline, or fall back to the
  send-widening route by also calling the method as a literal
  `:foo` somewhere.
- **`instance_eval { ... }`** / **`instance_exec { ... }`** — the
  block runs with a different self. Walking the block with the
  enclosing host attributes its self-calls to the wrong MRO.
  Currently treated as if self were unchanged, so calls inside
  the block may pin the wrong narrow set on their receivers.
- **`obj.method(:foo)`** + later `m.call` / `m.bind(other).call` —
  a Method handle decouples the receiver type from the literal
  symbol. The current `object_method` shim returns a Proc-shim
  that re-dispatches via `m_send`, so the run-time dispatch IS
  through `m_send` (which triggers wide widening), but only if
  `m_send` is itself in the surface — a program that uses Method
  handles but never directly calls send-style would miss it.

Net win on baseline (delegating-stub Vm, hello.rb target):
12MB → 6.6MB on top of chain-tail pruning (−45%). Combined
class + method-name + chain-tail + self-receiver pruning takes
the original 20MB baseline down to 6.6MB (−67% total).

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

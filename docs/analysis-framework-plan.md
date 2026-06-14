# Unified Analysis Framework — Plan

Captures a design discussion on type inference and the bespoke
analyses box-first uses today. The goal is to converge them under
a single abstract-interpretation framework, with TI as the
ultimate (richest) tenant.

This is a roadmap, not a spec. Lots of detail is deferred.

---

## 1. Where we are

box-first does not consume a general type-inference engine. The
crystal-backend's TI exists but is unused on the box-first path.
Instead, several bespoke analyses run per pass:

| Analysis              | Lattice                       | Drives                                          |
|-----------------------|-------------------------------|-------------------------------------------------|
| Initial pruning       | `{Reachable, Unreachable}`    | which classes/methods get emitted vs auto-stubbed |
| NA eligibility        | `{Eligible, NotEligible}`     | NA-direct call emission                          |
| Visibility status     | `{P1, P2, P4}` (3-elt poset) | static raise vs dynamic prologue                 |
| Leaf-class            | `{Leaf, NonLeaf}`             | `final` emission, typeid devirt                  |
| Try-frame necessity   | `{Needed, Skippable}`         | elide control-flow try-frame setup               |
| Type inference (none) | n/a                           | (would drive: dispatch narrowing, container element specialization, BigNum elision, …) |

Each is its own walk over the class graph / method body with its own
fixed-point logic. They share no infrastructure.

## 2. The shared shape

Every one of those analyses is doing the same thing structurally:
**iterate over the call graph, propagate facts through a lattice,
converge to a fixed point**. They differ only in:

1. What lattice the facts live in.
2. What transfer function each AST node applies.
3. What the initial seed is.

That's textbook abstract interpretation (Cousot's framework). The
right move is one engine + a lattice interface + bespoke analyses
as lattice instances.

## 3. Engine sketch

The engine is the orchestrator; the lattice is the pluggable
domain. Roughly:

```ruby
module AnalysisEngine
  # Lattice contract:
  #   bottom, top                     — designated values
  #   join(a, b) → a ⊔ b              — least upper bound
  #   subsumes?(a, b) → bool          — a ⊑ b
  #   widen(prev, curr) → c           — for termination at the limit
  #
  # Result is a Map[ProgramPoint → LatticeValue], computed by
  # iterating transfer functions to fixed point.
end
```

Each bespoke analysis becomes:

```ruby
class ReachabilityAnalysis < AnalysisEngine::Pass
  lattice TwoValueLattice[:Reachable, :Unreachable]
  seed { |entry| entry => :Reachable }
  transfer { |call_site, facts| ... }
end
```

The engine handles: worklist scheduling, dependency tracking,
fixed-point detection, widening on the limit, the answer cache.

### Key separation
- Engine knows nothing about Ruby types or call sites — pure
  abstract interpretation.
- Lattices are domain-specific but minimal — just the algebra.
- Transfer functions are the analysis-specific logic over the AST.

This is what makes the abstraction load-bearing: same engine,
different lattices, different transfers, all reusing the same
termination guarantees and infrastructure.

### Answer cache as API
Codegen never invokes the engine directly. It queries the answer
cache: "what's the type of this expression?" The engine can run
eagerly, lazily, or incrementally — all behind one read interface.

### 3.1 No-`auto` discipline drives TI granularity

Frozone's emitted C++ never uses `auto` (per `[[feedback_no_auto_in_cpp]]`).
TI must commit to a concrete Type at every emission site. The
implication: TI's primary output isn't "type of variable X" or
"return type of method M" — it's `Map<ASTExpressionNode → LatticeValue>`.
Every expression node that produces a value gets a type. Statements
(no value) don't, but their component expressions do.

This actually fits abstract interpretation cleanly. The transfer
function is recursive over the AST:

  type_of(literal)        → the literal's type directly
  type_of(var_read)       → lookup the variable's bound type
  type_of(method_call)    → receiver type × method name × arg types
                            → dispatch targets → return type union
  type_of(if_then_else)   → join of branch types (with guard narrowing)
  type_of(assignment)     → side-effect on var env; expr yields RHS type
  type_of(yield/block)    → block signature applied to arg types
  ...

`type_of(node) = combine(types of children) per node kind`. That's
Hindley-Milner's "Algorithm W" structurally, but over our lattice
instead of an ML-flavored type system.

**Single primitive**: this design collapses every TI query to the
same shape. "What's the receiver type at this call site?" is just
"type of the receiver subexpression of this call node." "What's the
return type of method M?" is "type of M's terminal expression." No
separate query kinds.

**Codegen integration becomes uniform**: every `emit_expr(node)`
call site does `t = ti.type_of(node); emit("#{cpp_for(t)} _tmp = …")`.
No conditional "did TI know? else use Universal" — the lattice
always has an answer (Universal being the legitimate top, not a
fallback). This is exactly what `[[feedback_no_auto_in_cpp]]`
forces: no escape hatch, every emission site has a concrete type.

**Memory cost concern**. A typical Ruby program has tens to hundreds
of thousands of AST expression nodes; cache size scales with that.
Mitigations:

- Don't cache trivials. Literals and simple variable reads are
  O(1) to recompute — leave them off the cache, recompute on
  demand.
- Two storage choices:
  - **Annotate the AST in place** (`node.inferred_type = T`).
    Clean emission ("just read the attr") but mutates the AST and
    couples nodes to the analysis lifecycle.
  - **Side-map keyed by object_id**. Decouples analysis from AST,
    nodes stay immutable, slightly higher per-lookup cost.

Default to the side-map for clean separation. Codegen and analysis
can be developed independently; AST nodes don't need to know
they're being typed.

**Connection to demand-driven analysis**: this design is
demand-driven by construction. Codegen queries `cache[node]`; if
cached, return; if not, recursively compute (which may trigger
re-queries for child nodes, transitive method bodies, etc.). The
engine never needs to be "run" explicitly — it's pulled by the
codegen's emission walk.

## 4. The TI tenant specifically

Type inference is the engine's richest tenant. Design principles
the discussion converged on:

### 4.1 Reachable-only iteration
TI is reachable-only at the method granularity. Reachability and
TI are mutually recursive: analyzing M discovers call sites which
resolve to target methods, which join the worklist. Iterate until
fixed point.

The closed-world snapshot gives us a *concrete* seed — pre-instantiated
top-level objects have known types, not "Universal". The seed is
strong; ⊥ at unreachable points genuinely means "no caller has
arrived here yet."

### 4.2 Three layers of reachability
- **TI is reachable-only at the method granularity**: methods with no
  callers stay at ⊥.
- **Codegen is reachable-only at the class granularity**: classes
  never instantiated need no VTable.
- **Slot emission is exhaustive**: even unreached methods on
  reachable classes get a slot (today, an abort-stub) because
  virtual dispatch through `BasicObject*` must land somewhere.

### 4.3 Convergence and termination
Convergence is **mandatory for soundness** when emitting specialized
code. Premature termination → under-approximated types → unsound
codegen.

The existing TI's iteration limit (hard bail-out) is unsound if it
just stops iterating. The principled fix is *widening*: at the
limit, switch to a widening operator ∇ that forces termination
while staying sound (over-approximate). One round doesn't generally
suffice to propagate widening — iterate with ∇ in place until a
new fixed point. Absorbing top (Universal) means the chain is
finite per program point.

For our lattice:
- Union cap: at size > K, fold to nearest common ancestor.
- Parametric depth cap: `Array<Array<...>>` at depth > D → `Array<Universal>`.
- Recursive types: detect cycle, replace with Universal at the
  recursion point.

### 4.4 Lattice design (Phase 1)
Simplest useful lattice:
- Nominal classes (closed-world finite set).
- Nullable: `T | Nil` first-class — pervasive in Ruby, ignoring it
  forces `Universal` everywhere a maybe-nil flows.
- ⊥ (unreached / no info), ⊤ (Universal).
- Union (small): size-capped, widens to nearest common ancestor.

Not yet:
- Parametric (`Array<T>`) — Phase 2.
- Type variables — Phase 3 (HM).
- Bounded polymorphism, effect typing — later.

### 4.5 Tiered / progressive precision
Most entities resolve to a leaf class (or even `i64`/`f64`) under
the Phase-1 lattice alone. Don't pay for parametric tracking
unless we hit a container that needs it. Don't pay for HM unification
unless we hit a polymorphic iterator.

Rough phasing:
1. **Phase 1**: 0-CFA + simple class lattice. Resolves most entities
   monomorphically. Fast, finite-height, no widening needed.
2. **Phase 2**: For sites Phase 1 left ambiguous, try 1-CFA at
   that specific call site, or add parametric tracking for the
   relevant container.
3. **Phase 3**: HM-style unification + type variables. Automatic
   parametric inference for user-defined iterators (`def collect_keys(h) = h.map { |k, _| k.to_sym }`
   gets inferred without annotation).
4. **Phase 4**: Bounded polymorphism (`<T extends Foo>`), effect
   typing for `@ivar` mutation, interval analysis for BigNum
   elision, k-CFA.

### 4.6 send / public_send filtering
Literal-Symbol `send` is rare in idiomatic code. Most real
`send`/`public_send` are computed-name dispatch tables and
metaprogramming.

A real lever: **filter the union by signature shape**. At the
call site, the (arity, kwarg-keys) is statically known.
Restrict the candidate set to methods whose parameter shape
admits the call shape:
- `obj.send(name, 1, 2, foo: 3, bar: 4)` → only methods with
  2 positionals + `{foo, bar}` keywords. Usually shrinks the
  union dramatically.
- `obj.send(name)` zero-arg → almost no filter. Stays a union.

Structurally similar to the existing NA per-(name, arity)
eligibility tables; same precompute pass, just extended with
required-kwarg sets.

**Watch-outs**: `*args` / `**kwargs` absorb everything;
`method_missing` accepts any shape (still in the union if
reachable); `define_method` at execute phase breaks the universe.

### 4.7 Blocks
For inline non-escaping blocks (the dominant case): polymorphic
signature on the iterator method does the job. Hand-annotate
~30 core methods (`Array#map`, `#select`, `#each_with_index`,
`#flat_map`, `Hash#transform_values`, `Enumerable#inject`, …).

For user-defined iterators, Phase 3 HM inference covers them
automatically — fall out of the same machinery.

Escaping blocks (stored in ivar, passed elsewhere) need points-to
analysis. Separate, bigger lift; deferred.

`Symbol#to_proc` (`&:to_s`) is just `λx. x.to_s` — canonicalize
at AST normalization, same handling as a written-out block.

## 5. Roadmap

Strangler fig pattern applied internally: the bespoke analyses
get strangled by the unified engine one at a time. Each migration
is bounded (re-express as lattice + transfer), measurable (output
parity with the existing pass), and committable independently.

### Phase 0 — Engine skeleton + reachability migration
- Build the engine: worklist, fixed-point, lattice interface,
  widening hook, answer cache.
- Implement a 2-element `Reachability` lattice as the first
  tenant.
- Migrate the initial-pruning pass. Verify byte-for-byte output
  parity (or improvement) against the existing pruner.
- Behavioral regression net: a small benchmark stub set whose
  emitted-method set is enumerated and stable.

Outcome: framework in tree, one analysis migrated, no perf
regression. Proves the abstraction is load-bearing.

### Phase 1 — Migrate the rest of the bespoke set
One per commit:
- NA eligibility → 2-element lattice.
- Leaf-class → 2-element lattice.
- Try-frame necessity → 2-element lattice.
- Visibility status → 3-element poset.

Each migration ships independently. After all five, the
bespoke code is retired.

### Phase 2 — TI lattice v1
Land the type lattice (Phase-1 from §4.4: classes + nullable +
unions). Run as a new analysis. Codegen *starts* querying it for:
- Receiver narrowing at call sites (devirt opportunities).
- Argument types (for NA-direct args layout — pairs with NA
  eligibility).
- Return type propagation (for chains of typed calls).

Codegen continues to fall back to Universal for queries the
lattice can't answer precisely.

### Phase 3 — Parametric containers
Add `Array<T>`, `Hash<K,V>` to the lattice. Hand-annotated
signatures for core iterators kick in. Container element-type
specialization in codegen (e.g., `Array<Integer>` → unboxed
`std::vector<int64_t>`).

### Phase 4 — HM-style polymorphism
Type variables + unification + generalization. User-defined
parametric methods get automatic inference. Hand annotations
become optional optimization (skip re-analysis for stable
core methods).

### Phase 5 — Beyond
- Bounded polymorphism for `is_a?` discrimination.
- Effect typing for `@ivar` mutation soundness ([[project_ti_soundness]] gap).
- Interval analysis for BigNum elision proofs ([[project_int_soundness]]).
- k-CFA at hot polymorphic call sites.
- Points-to for escaping blocks.

## 6. Risks and open questions

- **Engine performance**: an N-method codebase with K analyses
  is N×K fixed-point iterations in the worst case. Sharing the
  call-graph traversal across analyses (one pass, many lattice
  facts per node) is probably essential. Worth measuring early.
- **Snapshot/mutation soundness**: existing [[project_ti_soundness]]
  gap (Array element typing ignores `push`/`<<`). The new engine
  should not inherit this. Effect typing in Phase 5 is the proper
  fix; until then, the lattice for `Array<T>` should explicitly
  widen to `Array<Universal>` if any mutating method on `Array<T>`
  is reachable for `T`.
- **Widening operator choice**: the simplest is "widen everything
  unstable to Universal" — sound and trivially terminates but
  loses precision aggressively. Per-construct widening (cap union
  size, cap parametric depth) is the practical compromise.
- **`method_missing` taint**: any `send` with non-resolvable name
  against a class with `method_missing` reachable taints the
  whole `method_missing` body as reachable. Can't be more
  precise without runtime feedback.
- **Closed-world enforcement at execute phase**: `define_method`,
  `class_eval`, `prepend` at execute phase break the closed-world
  assumption. Must be statically rejected by the compiler.

## 7. Why this is worth doing

The bespoke analyses today work, but each one has its own
soundness story (mostly empirical, not provable), its own
termination story (mostly "we tested it didn't loop"), and its
own integration boundary with codegen. Adding a sixth bespoke
analysis (TI) just compounds the situation.

A unified framework gives:
- **One soundness argument** (Cousot's framework + per-lattice
  monotonicity), not six.
- **One termination guarantee** (engine-provided widening), not
  six.
- **One integration surface** (the answer cache), not six.
- **A natural home for new analyses** as we discover them
  (BigNum elision, effect tracking, points-to, …).

The Phase 0 cost is real but bounded. The Phase 1 migrations
are mechanical. The wins compound from Phase 2 onward.

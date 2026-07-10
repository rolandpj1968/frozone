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

#### Empirical validation (2026-07-07)

A splat-then-classify experiment on ti-v2 (preserved on branch
`ti-v2-splat-experiment`) built ground-truth for the "when does
context sensitivity actually pay off?" question. YOLO-splat every
method to every descendant leaf class, run TI, then group the
splatted copies by source method: **uniform** across all copies =
context-insensitive (0-CFA suffices), **diverse** = context
sensitivity buys something.

On `bench/stubs/fib.rb`:

- 390 splat families total.
- 341 uniform (0-CFA already captures all useful precision).
- 49 diverse (context sensitivity matters).
- Refined-oracle estimate (restrict "diverse" to reached-only
  leaves) tightens to ~14 truly class-parametric families.

Read-through: **0-CFA already extracts ~96% of the useful
per-method precision on this workload**. The remaining ~4% is the
frontier where 1-CFA / receiver-context specialization pays off —
`tap`, `dup`, `clone`, `initialize_dup`, and the coerce-shaped
arithmetic methods (see §4.6.1).

Implication: don't spend a full pass generating 1-CFA answers for
every method. Run 0-CFA cheaply everywhere; introduce 1-CFA
context only for classifier-selected diverse candidates. See §4.8
for how this collapses into a single pass whose context axis
widens per-method.

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

Structurally similar to the existing NA per(-name, arity)
eligibility tables; same precompute pass, just extended with
required-kwarg sets.

**Watch-outs**: `*args` / `**kwargs` absorb everything;
`method_missing` accepts any shape (still in the union if
reachable); `define_method` at execute phase breaks the universe.

### 4.6.1 Value-constrained lattice for Symbol-dispatched sends
The coerce protocol motivates a lattice extension that goes
beyond shape filtering. Empirical driver:

```ruby
class Integer
  def +(v) = v.is_a?(Integer) ? Intrinsics.integer__plus_(self, v)
                              : __coerce_op__(v, :+)
  def -(v) = v.is_a?(Integer) ? Intrinsics.integer__minus_(self, v)
                              : __coerce_op__(v, :-)
  # ...
end

class Numeric
  private
  def __coerce_op__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)  # ← polymorphic, TI stuck at ⊤
  end
end
```

TI at Tier 1 flow-insensitive lands at ⊤ for every arithmetic
method, because the else-branch's `__coerce_op__` calls
`.send(op, b)` with an opaque `op`.

**Extension**: extend the lattice with a *value constraint* on
`Type(concrete, nullable)`:

```
Type(concrete, nullable, value_set?)
```

Where `value_set` is either:
- A small `Set` of specific Symbol values (`{:+, :-, :*, :/}`), or
- ⊤_value (unconstrained; the normal case).

Callsite propagation: `SymbolLiteral(:+)` pushes
`{Symbol, {:+}}` (singleton) to the callee's param. Multiple
callers with different literals join to a union set:
`LUB({:+}, {:-}, {:*}) = {Symbol, {:+, :-, :*}}`.
Collapse to ⊤_value when the set grows past a threshold or
merges with an unconstrained Symbol.

Consumer at `.send(op, args)`:
- If `op`'s value_set is a singleton `{:+}` → rewrite AST-level
  to `recv.+(args)`. Normal TI runs on the direct call.
- If `op` is a small set → unfold into one call per possible
  symbol, LUB the return types.
- If ⊤_value → fall back to today's shape-filter approach or
  stay at ⊤.

**The receiver-type catch.** Even with `op = {:+, :-}`,
`a.send(op, b)` still needs `a` to have a resolvable type.
Under the coerce protocol, `a` is one of Integer/Float/Rational/
Complex — a *sum* over Numeric subclasses. Numeric itself has
no `.+`, so the send-unfold on `op` alone doesn't close the
loop without either:
- Sum types over class hierarchies (Integer|Float|Rational|
  Complex), unfold the send twice (per receiver × per symbol);
- Or a narrower return-type annotation on `Numeric#coerce` that
  says "returns a matched-subclass pair".

Value-constrained Symbol is orthogonal to but complementary
with sum types.

**Wider applicability**. Same lattice extension covers other
Symbol-driven patterns Ruby leans on:
- `throw`/`catch` with tagged Symbols
- `case x; when :foo; ...` on Symbols
- `respond_to?(:name)` with literal Symbol
- `attr_reader :name` at define time
- Struct accessors

**Relationship with 1-CFA**. Under 0-CFA (flow-insensitive,
context-insensitive), the value_set at `__coerce_op__`'s
:op param is the *union* across every caller — so `{:+, :-,
:*, :/, :%, ...}`. Sound but imprecise: send unfolds to a
LUB across all those.

Under 1-CFA context sensitivity, each callsite of
`__coerce_op__` has its own analysis context; the :op param
is a *singleton* per context. Then send rewrites to a direct
call with the exact symbol, and TI produces the concrete
return per-context.

1-CFA at codegen time forces a specialization decision:
- **Clone-and-specialize**: emit `__coerce_op___plus`,
  `__coerce_op___minus`, etc. — one C++ symbol per context.
  Callers dispatch directly to the specialization.
- **Keep universal**: emit one body with the ⊤-value union
  (accept the LUB precision).

The **inlining route is redundant with LTO** — once
`.send(literal, ...)` is rewritten to `.literal(...)` at
codegen, LTO handles physical inlining based on the callee's
static-type visibility. AOT specialization pays off only
when 1-CFA context is genuinely needed to keep the value_set
singleton per site.

**Layering with predicate narrowing**. Value-constrained
lattice and predicate narrowing (Tier-2 `is_a?` splits) are
orthogonal. Predicate narrowing alone gets fib to Integer
because the truthy branch is Integer and the caller never
reaches the else-branch under a typed argument. Value
constraints add precision for the send-heavy patterns where
narrowing doesn't apply. Suggested order:
1. Predicate narrowing (unblocks the immediate `is_a?`-guarded
   arithmetic on typed callsites).
2. Value-constrained Symbol lattice + `.send(literal, ...)`
   rewrite (unblocks coerce and other symbol-tag patterns).
3. Sum types over Numeric subclasses (closes the coerce-return
   loop, generalises union results).
4. 1-CFA + specialization emit (per-callsite context; needed
   only where 0-CFA leaves a set that we want to keep
   singleton).

#### Status update (2026-07-10)

Predicate narrowing landed (tasks #243, #247) together with the
Never lattice element and Never-routing on missing dispatches
(#244). Ordering above rearranged in the light of subsequent
empirical work — the operative triangle for numeric coercion is
now understood as:

1. **1-CFA on all params (including self)** — the enabler.
   Without it, `v` in `Integer#+`'s body is the ⊤-union of every
   type callers pass; `v.is_a?(Integer)` is unprovable; the
   coerce branch is always live. Nothing else works without this.
2. **`is_a?` / predicate partial-eval** — already implemented via
   #243 + #244 + #247, but only pays off IF 1-CFA gives us a
   typed context. In `(self:Integer, v:Integer)`, `v.is_a?(Integer)`
   narrows the else-branch's `v` to Never; Never-routing kills
   the whole `v.coerce(self).send(op, b)` chain. Load-bearing for
   scalability: without else-collapse, TI would explore every
   hypothetical `.coerce` return path per context and 1-CFA blows
   up combinatorially.
3. **Value-constrained Symbol lattice** — needed for slow-path
   specialization (heteromorphic coerce, `respond_to?(:name)`,
   Struct accessors, `send(:name, ...)` metaprogramming). Bounded
   lattice — the closed-world Symbol universe is finite.

The doc's original layering had (1) predicate narrowing → (2)
value-constrained Symbol → (4) 1-CFA. The empirical read is that
(1) alone was insufficient for the hot arithmetic path because
`v` is still ⊤ without 1-CFA; the predicate has nothing to bite
on. 1-CFA is the enabler, not the closer. Value-constrained
Symbol becomes a slow-path completion once the hot path
collapses.

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

### 4.8 TI subsumes ReachabilityPass (accepted 2026-07-10)

The current 0-CFA-flavored ReachabilityPass is not worth running
as a distinct analysis body. Two empirical inputs drive this:

- **Marginal pruning value is small**: 0-CFA method-level
  reachability eliminates only ~10% of methods beyond what
  class-level naive reachability keeps. The main win from
  reachability came from the class-level and constant-level
  culls (documented in `reachability-pruning.md`); the
  method-level 0-CFA delta on top is modest.
- **0-CFA is already inside TI**: TI's fixpoint IS a 0-CFA
  computation — it walks the same call graph, resolves dispatch
  through the same receiver types, and now that Never routing
  (task #244) is in place, a call site that dispatches to Never
  contributes zero transfer calls to its target. That target
  drops out automatically. The reachability set is a derived
  query on TI:

      reachable_methods = { m | engine.transfer_count[m] > 0 }

**Concrete shape**:

- What survives of ReachabilityPass: the **seed** side —
  class-level walk, constant walk, `RubyClass.uses:`, top-level
  entry, hoisted class bodies. These populate TI's initial
  worklist. This is a small pre-pass, not a full analysis.
- The **analysis body** — method-name-surface accumulation,
  Stage-3 self-receiver narrowing, super-tail pruning — retires.
  TI subsumes it. What Stage-3 self-receiver narrowing computed
  by hand ("bare `foo` inside host's body dispatches through
  host's MRO") falls out of TI's cone dispatch (see §4.1 receiver
  narrowing).
- **Codegen consumers** (elision, override emission gating,
  Vtable pruning) migrate to reading TI's derived reachability
  answer instead of the current ReachabilityPass's `@call_surface_set`.

**Path to 1-CFA as key-space widening of the same pass**:

- Today: TI keys analysis nodes by `method_node`. That's 0-CFA —
  one abstract call per method regardless of caller.
- Extension: TI keys by `(method_node, context)`.
    - `context = ()` unit → behaves identically to 0-CFA. Every
      method starts here.
    - `context = (self_type, arg_types)` when a classifier says
      the method's TI result is context-dependent (the ~14
      diverse families from §4.5's empirical validation).
- Same engine, same lattice, same monotone-join clamp. Wider key
  space. The classifier from the splat experiment carries over
  wholesale and can be scored against the same oracle.

**Property**: 0-CFA and 1-CFA are modes of one pass, selected
per-method by the classifier. No architectural fork; adding
context sensitivity does not require a second analysis engine.

**What this replaces**: the earlier "Phase 2 — 1-CFA at
ambiguous sites" bullet under §4.5 read as if it were a separate
engine invocation per site. It isn't — it's this same pass with a
per-method context axis.

## 5. Roadmap

Strangler fig pattern applied internally: the bespoke analyses
get strangled by the unified engine one at a time. Each migration
is bounded (re-express as lattice + transfer), measurable (output
parity with the existing pass), and committable independently.

### Phase 0 — Engine skeleton + reachability migration ✅
- Build the engine: worklist, fixed-point, lattice interface,
  widening hook, answer cache. **Landed** — `lib/frozone/compiler/analysis/engine.rb`.
- Implement a 2-element `Reachability` lattice as the first
  tenant. **Landed**, then **superseded by §4.8**: TI subsumes
  ReachabilityPass rather than running it as an independent
  tenant. Reachability's seed pieces (class-level, constant walk,
  `uses:` declarations, top-level entry) remain as TI's initial
  worklist; its analysis body retires.
- Behavioral regression net: analysis specs green throughout
  the ti-v2 landings.

### Phase 1 — Migrate the rest of the bespoke set — partial
Landed in various forms as engine passes or elided by TI:
- NA eligibility → still a bespoke precompute; migration deferred.
- Leaf-class → precomputed via TypeLattice descendants map (§4.1).
- Try-frame necessity → still bespoke.
- Visibility status → still bespoke.

Priority now sits with §4.8 + numeric-coercion 1-CFA rather than
squeezing the remaining bespoke passes into the engine — they
work as-is and the compounding wins are further downstream.

### Phase 2 — TI lattice v1 ✅
Landed on ti-v2 (task #228 umbrella and #231–#251 waves):
- Type lattice with classes + nullable + descendant cone (§4.4).
- `TypeInferencePass` with full AST coverage (Sequence,
  divergent jumps, loops, Case, And/Or, Rescue, RangeLiteral,
  RegexpLiteral, InterpolatedString, calls, definitions,
  assignments, ivar/gvar/cvar writes, MatchWrite, defined?,
  splat/block-arg).
- Tier-2 narrowing: `is_a?` / predicate on `If`, And/Or/Case
  consumers, early-exit narrowing.
- Never lattice element + Never routing on missing dispatches.
- Receiver-cone dispatch (LUB across type cone instead of ⊤
  short-circuit).
- Authentic method_missing routing.
- Nullable normalization (T? = T when NilClass ⊑ T).
- Engine dual-check (:eager and :snapshot modes converge to
  same LFP — soundness oracle).

Codegen consumption is the next lift.

### Phase 2.5 — TI subsumes Reachability + numeric-coercion 1-CFA — NEXT

Per §4.8: retire the 0-CFA ReachabilityPass analysis body; TI's
transfer counts become the reachability answer. Then extend TI's
node key space from `method_node` to `(method_node, context)`,
gated by the splat-oracle classifier.

Numeric coercion (§4.6.1) is the empirical driver: getting the
Integer+Integer hot path to native ops requires 1-CFA on all
params (including self) so the `is_a?(Integer)` guard collapses
via Never routing (already implemented) and the coerce branch
dies at analysis time.

Concrete steps:
1. Verify #243+#244+#247 already collapse the else-branch on
   `Integer#+ (self:Integer, v:Integer)` — before building new
   machinery.
2. Merge TI + ReachabilityPass — retire the analysis body, keep
   the seed.
3. Introduce `(method_node, context)` keying in TI — start with
   unit context (identity), classifier-widen selected methods to
   param-type-tuple context.
4. Value-constrained Symbol lattice for slow-path specialization
   (§4.6.1 body).

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

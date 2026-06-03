# Box-first Method Visibility

Design for honoring Ruby's `private` / `protected` semantics in box-first
AOT-compiled code, without polluting method bodies with visibility
checks and without adding cost to the common public-call path.

## Principle

Visibility is a **call-site syntax** property, not a method-table
property. Ruby's check is decided by the *shape* of the call —
implicit receiver vs explicit receiver — not by where in the class
hierarchy the call lives. This factors cleanly:

- Per-method visibility metadata is consulted only by *explicit-receiver
  call-site codegen*.
- Implicit-recv call sites do pure VT dispatch, never touch visibility.
- Method bodies stay bare. The visibility of `def foo` is a property
  of `foo`'s callers, not of `foo` itself.

## Per-name visibility patterns (closed world)

For each method name X, classify by the set of visibilities its defs
carry across the closed world:

- **P1 — all public.** Default. Nothing extra anywhere.
- **P2 — all private.** Pure call-site decision.
- **P3 — all protected.** Pure call-site decision.
- **P4 — mixed across classes.** Originally claimed empirically rare;
  the survey says otherwise (see below).

## Empirical observations (Frozone self-compile, 2026-06-03)

The Stage 1 survey shows reality differs significantly from the
source-grep estimates:

```
P1=1829 public, P2=353 private, P3=52 protected, P4=48 mixed
```

P4 is non-trivial and the universal-slot caller_self machinery is
**mandatory**, not a contingency.

But the apparent diversity of P4 collapses once you look at *distinct
method bodies* per name. Three patterns explain almost all P4:

### Pattern 1 — Kernel-shadowing (≈20 names, dominant)

```
puts:  private=51 public=1
  private: Kernel + 50 Kernel-including classes
  public: IO
```

The 51 private entries all point to the *same* Kernel method body (private
as defined). The single public entry is a *separate* method body on IO
(or Binding / Fiber / Thread for similar names). Two distinct bodies per
name, flattened across many tables.

Names matching this pattern: `puts, print, printf, putc, gets, readline,
readlines, loop, select, eval, exit, local_variables, set_trace_func,
singleton_method_added, method_missing, warn, abort, load, raise`.

This isn't a Ruby quirk — it's the standard interaction between Kernel
(private-by-default convenience) and explicit IO-like classes that define
their own public version.

### Pattern 2 — FileUtils-style (≈10 names)

```
chmod, chown, copy, copy_file, link, remove_file, ...
  private: FileUtils
  public: FileUtils_Entry_ (or Dir / File / IO)
```

Two distinct method bodies per name, each with a single fixed visibility.

### Pattern 3 — Frozone-internal accidental (≈10 names)

```
evaluate:   private=1 public=77
  private: Frozone_Vm_Vm
  public:  every AST node
populate_kw_params, populate_params: 1 private + 1 public
marshal_dump, marshal_load:          private on Rational/Complex,
                                     public on our Vm wrappers
```

These are accidental name collisions in our own code. Could be cleaned
up by renaming (e.g. `Vm#evaluate` → `Vm#run_ast`) to avoid the P4
classification entirely. TI would also collapse these — once receivers
are statically typed, the universal-slot fallback isn't needed.

### Codegen implication

The infrastructure scales with **distinct method bodies**, not
(class, name) pairs. Each P4 name has typically 2–3 distinct bodies,
each with a single fixed visibility known at compile time. At a call
site:

- **Known receiver type** → resolve via Ruby's method lookup → find
  the body → know its visibility → emit the appropriate check.
- **Unknown receiver type** (universal slot) → can't statically
  resolve → need the 4th-arg `caller_self` because the body that
  runs at runtime could be any of the 2–3 candidates.

So 48 P4 names ≠ 48 special cases — most reduce to the same handful
of patterns, handled by one rule.

## Call-site codegen rules

Three call-site flavors visible in the AST:
- **implicit-recv** (`foo`)
- **explicit-self** (`self.foo`)
- **explicit-other** (`bar.foo`)

For each combination of pattern × flavor:

| pattern | implicit | explicit-self | explicit-other |
|---------|----------|---------------|----------------|
| P1 public  | call | call | call |
| P2 private | call | call | `if (recv == cs) call(); else raise_private;` |
| P3 protected | call | call | `if (cs->mm_kind_of_q(recv->m_class())) call(); else raise_protected;` |
| P4 mixed   | call | call | universal-slot path (see below) |

Where `cs` is `current_self_local` — the C++ local binding for `self`
in the enclosing emitted method body. Both operands of the runtime
check are call-site locals; no caller-self threading through method
bodies.

For statically-resolvable receivers (NA-eligible, or known-receiver-
type at the call site), the resolved target's visibility is known at
compile time and we pick the appropriate row directly.

## Universal-slot path (P4)

When the receiver type is unknown at the call site (universal slot
dispatch), the target method's visibility isn't statically known.
Two design choices:

- **(a) Method-body prologue.** Universal slot ABI gains a 4th VT
  parameter `BasicObject* caller_self`. Public method bodies ignore
  it — one wasted register, no branch, optimiser-friendly. Non-public
  bodies check it in their prologue.
- **(b) Vis-table at dispatch entry.** m_dispatch consults a per-class
  visibility table at universal-slot entry and decides.

We pick **(a)**. The universal slot is already paying for
name-based dispatch, exception-based control flow, full args/kwargs/
block boxing — one extra register vanishes in the noise. (a) keeps
the check colocated with the body's own visibility metadata, which
is where conceptual ownership lives.

The survey shows this path is required — 48 P4 names exist in
Frozone's self-compile closed world, dominated by the Kernel-shadow
pattern. Stage 3 is mandatory, not contingent.

Universal-slot ABI:

```cpp
virtual BasicObject* m_X(
    Array* args = &EMPTY_ARGS,
    Hash* kwargs = &EMPTY_KWARGS,
    BasicObject* block = nil_instance(),
    BasicObject* caller_self = nil_instance()  // new
) = 0;
```

NA slots are unaffected — NA only fires when receiver type is known
statically, so visibility is known too and the check is at the call
site.

## Reflective dispatch

`send` / `__send__` bypass visibility. `public_send`, `method`,
`Module#public_method_defined?` etc. respect it. These all flow
through reflective-dispatch paths that consume the per-class
visibility table directly.

## Where the visibility data comes from

The MRI Frozone interpreter already tracks per-method visibility
authentically (the language specs pass). For box-first AOT, the
loader populates a `(class_id, method_name) → {public, private,
protected}` table at compile time from the same source. This table
drives:
- Call-site codegen (the four rows above).
- Reflective dispatch.
- The universal-slot prologue emission (P4 method bodies that
  consult `caller_self`).

## What we deliberately don't do

- **No visibility check inside the method body for P1/P2/P3 names.**
  Those are pure call-site decisions; the body is bare.
- **No caller-self threading for P1/P2/P3 universal slots.** The 4th
  arg is only emitted when at least one P4 name exists in the closed
  world.
- **No TI-based proof-of-receiver-equality at call sites.** For
  explicit-other private calls we always emit the runtime `recv ==
  cs` check. TI elision is an optional later optimisation.
- **No relaxation for "obviously OK" calls** (e.g. "protected called
  from sibling instance of same class"). Authenticity over cleverness
  for the Rails target.

---

## Test plan (rspec)

The integration_spec format (single closed world, end-to-end
compile-and-run) is the natural home. New stub: `bench/stubs/
visibility_test.rb`.

Coverage matrix — every visibility × call-flavor cell, with
MRI-matching outcome:

```ruby
# Visibility patterns
class Pub
  def m; :pub; end
end

class Priv
  def call_implicit; m; end
  def call_explicit_self; self.m; end
  def call_explicit_other(other); other.m; end
  private
  def m; :priv; end
end

class Prot
  def call_implicit; m; end
  def call_explicit_self; self.m; end
  def call_explicit_other(other); other.m; end
  protected
  def m; :prot; end
end

class ProtSubcaller < Prot
  def sibling_call(other); other.m; end  # same hierarchy
end

class Mixed1
  def foo; :pub_foo; end  # X public here
end
class Mixed2
  def call_explicit(obj); obj.foo; end
  private
  def foo; :priv_foo; end  # X private here — P4
end
```

Assertions to cover:
- `Pub.new.m == :pub` and all explicit forms succeed.
- `Priv#call_implicit == :priv`; `#call_explicit_self == :priv`;
  `#call_explicit_other(Priv.new)` raises NoMethodError (private).
- `Priv.new.m` raises NoMethodError (explicit recv from outside).
- `Prot#call_implicit == :prot`; `#call_explicit_self == :prot`;
  `#call_explicit_other(Prot.new) == :prot` (sibling).
- `Prot.new.m` raises NoMethodError (protected, caller not in class).
- `ProtSubcaller#sibling_call(Prot.new) == :prot` (kind_of? succeeds).
- `Mixed2.new.call_explicit(Mixed1.new) == :pub_foo` (Mixed1's foo
  is public, even though Mixed2's foo is private — call-site sees
  the target's visibility).
- `Mixed2.new.call_explicit(Mixed2.new)` raises (private on Mixed2).
- `send` ignores visibility on all three; `public_send` respects it.
- `respond_to?(:m, false)` returns false for private/protected; with
  `true` returns true.

Each assertion runs end-to-end (compile to .cpp → g++ → run binary)
and compares stdout to a captured MRI baseline.

---

## Implementation plan

Staged so each step is independently testable. Numbers map to task
list items.

### Stage 1 — Per-(class, name) visibility table

- Walk the closed-world class set at compile time, extract each def's
  declared visibility. The interpreter's ModuleObject already tracks
  this; we read it after the load phase.
- Emit a compile-time constant table (`VISIBILITY_TABLE`) keyed by
  (class_id, method_name_id).
- Add `def visibility_of(class_id, name)` codegen helper.
- Add diagnostic: report per-pattern (P1/P2/P3/P4) counts at gen-time
  so we can verify Frozone has zero P4 and exactly two P3 entries.

### Stage 2 — Call-site classification + emission for P1/P2/P3

- Codegen for explicit-recv MethodCall consults `visibility_of(target
  class if known, name)`:
  - P1 public → emit call as today.
  - P2 private → emit `if (recv == current_self_local) call(); else
    raise_private(name);`.
  - P3 protected → emit `if (current_self_local->mm_kind_of_q(recv->
    m_class())) call(); else raise_protected(name);`.
- Implicit-recv calls and self.foo calls are unchanged (pure VT
  dispatch, no check).
- New runtime helpers `raise_private_call`, `raise_protected_call`.
- Verify Frozone self-compile and integration spec stays green.
- Run new `visibility_test.rb`.

### Stage 3 — P4 universal-slot caller_self thread (mandatory)

Stage 1 survey confirmed 48 P4 names in Frozone self-compile, so this
stage is required.

- Extend universal-slot VT signature with `BasicObject* caller_self =
  nil_instance()` 4th arg.
- Every call site at universal-slot dispatch passes
  `current_self_local`.
- Non-public method bodies on P4 names emit a prologue that consults
  `caller_self` and compares against the body's known visibility.
- Public method bodies ignore the new arg (one wasted register, no
  branch).

The optimisation path is *renaming our own P4 collisions*. About 10
of the 48 P4 names (`evaluate`, `populate_params`, etc.) are
accidental name clashes in Frozone-internal code. Renaming them to
something distinct (`Vm#evaluate` → `Vm#run_ast`, etc.) would drop
them from P4 entirely. TI would also dissolve them once available.

### Stage 4 — Reflective dispatch wiring

- `Object#send` / `__send__`: bypass visibility, dispatch directly
  (already the case; verify).
- `Object#public_send`: consult `visibility_of` before dispatch, raise
  if non-public.
- `Object#method` / `Module#instance_method`: visibility filter.
- `Module#public_method_defined?` / `private_method_defined?` /
  `protected_method_defined?`: read the table.
- `respond_to?(name, include_private)`: visibility-aware.

### Stage 5 — `attr_accessor` and post-hoc declarations

- `attr_accessor` / `attr_reader` / `attr_writer` emit defs at module-
  body level whose visibility tracks the current `private`/`protected`
  scope. The interpreter already does this; the AOT walker needs to
  capture the resulting visibility into the table.
- `private :foo` / `protected :foo` / `public :foo` (post-hoc setters):
  mutate the table at compile time, before the table is frozen for
  codegen.
- `private_class_method` / `public_class_method`: same for singleton
  methods.

### Stage 6 — Closed-world ruby-spec runner (optional, follow-up)

- Build a thin runner that takes a ruby-spec file, generates a single-
  TU closed-world build, runs it, captures output for comparison to
  MRI. This is the proper authenticity proof. Currently file-by-file
  compile is onerous; the practical fix is a pre-compiled runtime
  shared lib + per-spec thin gen so each spec compiles in seconds,
  not minutes.

---

## Tracking

- #116 (pending) — covers Stages 1-4. Re-scope to reference this doc.
- New task — Stage 5 (`attr_accessor` + post-hoc visibility).
- New task — Stage 6 (closed-world ruby-spec runner). Optional.
- `visibility_test.rb` (Stage 2 deliverable) — created during Stage 2.

# Frozone Type Lattice

Formal specification of the type domain used by the whole-program type
inference engine (`lib/frozone/compiler/type_inference.rb`).

---

## 1. Lattice structure

The type lattice **(L, ⊑, ⊔, ⊥)** is a join-semilattice with bottom:

| Symbol | Meaning |
|--------|---------|
| **⊥** (`unknown`) | Bottom — not yet analysed; the initial value for every slot |
| **⊤** (`BasicObject`) | Top — no useful type information remains |
| **⊔** (`join`) | Join / least upper bound — widens toward ⊤ |
| **⊑** | Subtype: `a ⊑ b` iff `a ⊔ b = b` (a is at least as precise as b) |

The analysis is a **forward abstract interpretation** (Cousot & Cousot, POPL
1977): types flow from producers (literals, constructors, returns) to
consumers (params, locals, ivars) through the program's control flow graph.
The join operator widens at merge points. Because L has finite height and ⊔
is monotonic, the fixed-point iteration terminates.

> **Naming.** The code method is `TypeInference#join` and `TypeEnv#join!`,
> matching the lattice-theoretic term for least upper bound.

---

## 2. Type elements

Every type in L is one of the following forms:

### 2.1 Bottom

```
⊥  ≡  :unknown
```

Identity element for ⊔. Represents "no information yet". Slots initialise
to ⊥ and can only move upward.

### 2.2 Unboxed scalars

```
i64    — Crystal Int64, sits below {class: Integer}
f64    — Crystal Float64, sits below {class: Float}
```

These are the most precise numeric types. They represent values that can
live in CPU registers with no heap allocation.

Subtype ordering:

```
i64  ⊑  {class: Integer}  ⊑  {class: Numeric}  ⊑  {class: Object}  ⊑  ⊤
f64  ⊑  {class: Float}    ⊑  {class: Numeric}  ⊑  {class: Object}  ⊑  ⊤
```

### 2.3 Class types

```
{class: C}                         — instance of class C (or subclass)
{class: C, exact: true}            — exactly class C (no subclasses)
{class: C, nullable: true}         — C | nil
{class: C, exact: true, nullable: true}  — exactly C | nil
```

The `class` field is a Ruby Symbol naming the class. The class hierarchy
provides the partial order: `{class: A} ⊑ {class: B}` iff A is a
descendant of B (or A = B).

**Exactness.** `exact: true` means "this value was produced by `C.new`
directly — it is exactly class C, not a subclass". This enables direct
method dispatch in Crystal (no union types, no vtable). Constructors always
produce exact types. Parameters and ivar reads generally do not (unless the
class is a leaf in the closed world — no subclasses exist).

**Nullability.** `nullable: true` means "this slot may hold nil". Produced
when `NilClass` joins with any other class type:

```
⊔(NilClass, {class: C}) = {class: C, nullable: true}
```

Nullable is sticky through same-class joins:

```
⊔({class: C, nullable: true}, {class: C}) = {class: C, nullable: true}
```

In Crystal, nullable types emit as `Ruby_C | RubyNil` or `Ruby_C?`.

### 2.4 Parameterised types (collections)

Arrays and Hashes carry recursive type parameters:

```
{class: Array}                              — Array with unknown elements
{class: Array, elem: τ}                     — Array(τ) where τ ∈ L
{class: Hash}                               — Hash with unknown key/value types
{class: Hash, key: κ, val: ν}               — Hash(κ, ν) where κ, ν ∈ L
```

Parameters are **covariant** — `Array(A) ⊑ Array(B)` iff `A ⊑ B`. The
join of two parameterised types with the same base class merges parameters
element-wise:

```
⊔(Array(A), Array(B)) = Array(⊔(A, B))
```

When one side has a parameter and the other doesn't, the parameter is
**preserved** — "absent" means "not yet observed", not "unknowable". This
lets empty arrays (`[]`) acquire element types when values are pushed later:

```
⊔({class: Array}, {class: Array, elem: i64}) = {class: Array, elem: i64}
```

Nesting is recursive:

```
{class: Array, elem: {class: Array, elem: i64}}   — Array(Array(Int64))
```

### 2.5 Unboxed arrays

```
array_i64  ⊑  {class: Array, elem: i64}  ⊑  {class: Array}
array_f64  ⊑  {class: Array, elem: f64}  ⊑  {class: Array}
```

These represent `Array(Int64)` / `Array(Float64)` that can be emitted as
native Crystal arrays with no boxing. They are subtypes of parameterised
Array types. Only promoted when escape analysis confirms the array doesn't
leak to untyped contexts.

---

## 3. Join rules

The join operator `⊔(a, b)` implements the least upper bound:

| a | b | ⊔(a, b) | Rule |
|---|---|---------|------|
| ⊥ | τ | τ | Bottom identity |
| τ | τ | τ | Idempotent |
| i64 | i64 | i64 | Same scalar |
| i64 | f64 | {class: Numeric} | Numeric widening |
| i64 | {class: Integer} | {class: Integer} | Unbox → box |
| f64 | {class: Float} | {class: Float} | Unbox → box |
| i64 | {class: String} | {class: Object} | Unrelated → LCA |
| {class: A} | {class: B} | {class: LCA(A,B)} | Hierarchy LCA |
| NilClass | {class: C} | {class: C, nullable: true} | Nullable |
| {class: C, nullable: true} | {class: C} | {class: C, nullable: true} | Nullable sticky |
| Array(A) | Array(B) | Array(⊔(A,B)) | Recursive param merge |
| Array | Array(A) | Array(A) | Absent param → take present |

**LCA computation** walks the Ruby class hierarchy (VM-snapshot ancestors for
user classes, hardcoded `BUILTIN_ANCESTORS` for built-in classes). The
hierarchy is pre-computed at TI construction time and cached.

**Commutativity and associativity** are required for soundness (order of
merge at join points must not matter). The current implementation satisfies
both — verified by the spec suite's commutative tests.

---

## 4. Slot system

The TI tracks types in **slots** — `[kind, context, name]` tuples addressing
every typeable location in the program:

| Kind | Key | What it tracks |
|------|-----|---------------|
| `:local` | `[mkey, name]` | Local variable type |
| `:param` | `[mkey, index]` | Method parameter type (from call sites) |
| `:return` | `[mkey]` | Method return type |
| `:ivar` | `[class, name]` | Instance variable type |
| `:const` | `[name]` | Constant type |
| `:array_elem` | `[mkey, name]` | Native array element type |
| `:block_param` | `[mkey, name]` | Block parameter type |
| `:kwparam` | `[mkey, name]` | Keyword argument type |
| `:constructor_param` | `[class, index, caller]` | 1-CFA constructor param |

Where `mkey` is either a Symbol (top-level method) or `[class, method]`
pair (instance/class method).

**TypeEnv** stores the mapping from slots to types. `join!(slot, type)`
computes `⊔(current, type)` and returns true if the slot changed —
driving the fixed-point iteration.

---

## 5. Context sensitivity (1-CFA)

### 5.1 The problem

Context-insensitive TI merges all call sites to the same constructor:

```ruby
Node.new(key, value)    # in insert: key is Float64
Node.new(nil, nil)      # in splay!: sentinel
```

Global merge: `⊔(f64, NilClass)` → `{class: Float, nullable: true}` → all
`@key` ivars widen to `RubyObject`, destroying unboxing.

### 5.2 1-CFA constructor specialisation

Key constructor params by calling context (Shivers, PLDI 1988):

```
[:constructor_param, Node, 0, :insert]  → f64
[:constructor_param, Node, 0, :splay!]  → NilClass
```

When propagating ivar types from constructor params, `best_constructor_param_types`
collects all contexts and **excludes NilClass-only** contexts — these are
sentinel constructions that shouldn't widen the real ivar types.

### 5.3 Precision recovery

The sentinel context produces `NilClass` for all params → excluded entirely.
The real context produces `f64` → ivars are typed as unboxed `Float64`.
Hot-loop comparisons emit as native `Float64 <` instead of virtual dispatch.

**Measured impact:** splay benchmark structaref 1m35s → 1.1s (90× speedup).

### 5.4 Explosion bounds

1-CFA on constructors only (not general method calls) bounds the number of
contexts to `|classes| × |constructor_call_sites|`. In practice, 1–3
instantiations per class. A depth limit prevents recursive specialisation
(`Node<Node<Node<T>>>`).

### 5.5 Relationship to generic extraction

Constructor specialisation is implicit **parametric polymorphism extraction**:

```
Node.new(Float64, String)   →  Node<Float64, String>
Node.new(nil, nil)          →  Node<NilClass, NilClass>
```

The type parameters are never declared — they're inferred from constructor
call sites. This is analogous to:
- Julia's runtime method specialisation per concrete argument tuple
- MLton's whole-program monomorphisation of ML polymorphism
- C++ template instantiation / Rust monomorphisation

---

## 6. Fixed-point algorithm

```
initialise all slots to ⊥

repeat (max 10 iterations):
  changed = false

  # Phase 1: interprocedural argument propagation
  for each method body and execute block:
    for each call site f(args...):
      for each arg a_i:
        changed |= meet!([:param, f, i], infer_expr(a_i))
    for each ClassName.new(args...):
      changed |= meet!([:constructor_param, C, i, caller], infer_expr(a_i))

  clear expr cache   # prevent stale :unknown from phase 1

  # Phase 2: intraprocedural local propagation
  for each method and execute block:
    for each local assignment x = rhs:
      changed |= meet!([:local, mkey, x], infer_expr(rhs))
    return_type = infer_body_return(body)
    changed |= meet!([:return, mkey], return_type)

  clear expr cache   # prevent stale cached types

  # Phase 3: class instance propagation
  for each user class:
    propagate constructor params → ivar types
    for each instance method:
      propagate locals and returns (as in Phase 2)

  break unless changed
```

**Convergence.** The lattice has finite height (bounded by the class hierarchy
depth plus collection nesting depth). Each iteration can only widen slots
(never narrow). Therefore the algorithm terminates in at most `h × |slots|`
iterations, where `h` is the lattice height. In practice, 3–5 iterations
suffice for all current benchmarks.

**Expr cache clearing** between phases is essential. Phase 1 may cache
`:unknown` for expressions whose types are refined by Phase 2. Without
clearing, stale cache entries prevent convergence.

---

## 7. Expression typing rules

`infer_expr(node, ctx)` computes the type of an AST expression:

| Expression | Type rule |
|-----------|-----------|
| `42` | `i64` |
| `3.14` | `f64` |
| `nil` | `{class: NilClass}` |
| `true` | `{class: TrueClass}` |
| `"str"` | `{class: String}` |
| `:sym` | `{class: Symbol}` |
| `[a, b, c]` | `{class: Array, elem: ⊔(type(a), type(b), type(c))}` |
| `{k => v}` | `{class: Hash, key: type(k), val: type(v)}` |
| `x` (local) | `env[[:local, mkey, x]]` or `env[[:param, mkey, i]]` |
| `@x` (ivar) | `env[[:ivar, class, :@x]]` |
| `C` (const) | `env[[:const, C]]` |
| `x = e` | `type(e)` (also updates local slot) |
| `if p then t else e` | `⊔(type(t), type(e))` |
| `a + b` | numeric widening: `i64 + i64 → i64`, `i64 + f64 → f64` |
| `a.to_f` | `f64` (explicit coercion) |
| `C.new(...)` | `{class: C}` |
| `Math.sqrt(x)` | `f64` |
| `arr[i]` | `elem(type(arr))` |
| `arr.length` | `i64` |
| `f(args)` | `env[[:return, f]]` |
| `obj.m(args)` | `env[[:return, [class(obj), m]]]` |

---

## 8. Invariants and soundness

1. **Monotonicity.** `join!(slot, τ)` only widens: if the slot was σ,
   the new value is `⊔(σ, τ) ⊒ σ`. Slots never move downward.

2. **Termination.** Finite lattice height + monotonicity → fixed point
   reached in bounded iterations.

3. **Soundness.** Every inferred type is an *upper bound* on the set of
   runtime values that can inhabit the slot. The codegen can safely assume
   the inferred type — if TI says `i64`, the value is always an `Int64`
   at runtime. Unsoundness would mean emitting code that crashes on a
   value the TI didn't predict.

4. **Precision vs soundness tradeoff.** `:unknown` (⊥) is always sound
   but useless — the codegen falls back to `RubyObject`. The TI aims to
   push slots as far below ⊤ as possible while remaining sound. 1-CFA
   recovers precision at constructor join points where context-insensitive
   analysis would widen too eagerly.

5. **Completeness.** The TI is **not** complete — there exist programs
   where runtime types are more precise than the TI can infer. This is
   expected (Rice's theorem). The fixed-point iteration cap (10) also
   means very deep chains may not fully converge, though this hasn't
   been observed in practice.

---

## 9. Implementation mapping

| Formal concept | Code |
|---------------|------|
| L (lattice) | Symbols `:unknown`, `:i64`, `:f64`, `:array_i64`, `:array_f64` and frozen Hashes `{class: C, ...}` |
| ⊔ (join) | `TypeInference#join(a, b)` |
| ⊥ (bottom) | `:unknown` |
| ⊤ (top) | `{class: :BasicObject}` |
| Slot | `[kind, context, name]` Array keys in `TypeEnv#slots` |
| join! | `TypeEnv#join!(slot, type)` — returns true if changed |
| infer_expr | `TypeInference#infer_expr_uncached(node, ctx)` |
| 1-CFA key | `[:constructor_param, class, index, caller_method]` |
| Fixed point | `TypeInference#run(iterations: 10)` |
| Expr cache | `@_expr_cache` — `[node, method_key] → type`, cleared between phases |

### 9.1 Future: Type value object

The current representation uses a mix of Symbols and frozen Hashes. A
dedicated `Type` value object would make the lattice operations more
discoverable and type-safe:

```ruby
class Type
  # Constructors
  Type.bottom                              # :unknown
  Type.i64                                 # unboxed Int64
  Type.f64                                 # unboxed Float64
  Type.of(class_name, exact: false, nullable: false)
  Type.array(elem: Type.bottom)
  Type.hash(key: Type.bottom, val: Type.bottom)

  # Lattice operations
  def join(other)   # least upper bound
  def <=(other)     # subtype check: self ⊑ other

  # Queries
  def bottom?       # :unknown
  def raw?          # i64 or f64
  def numeric?      # raw or boxed Integer/Float/Numeric
  def nullable?
  def exact?
  def class_name    # Symbol
  def elem          # for arrays
  def key, val      # for hashes
end
```

This is a mechanical refactoring — every `ty.is_a?(Hash) && ty[:class]`
becomes `ty.class_type?`, every `NUMERIC_TYPES.include?(ty)` becomes
`ty.raw?`. The lattice semantics are unchanged.

The trade-off is churn vs clarity. The current Symbols-and-Hashes
representation works and is tested. A `Type` class adds a layer of
indirection but makes the lattice contract explicit and self-documenting.
The refactoring is worthwhile when the TI grows — more type forms, more
lattice operations, more places that inspect types — because each new
feature is one method instead of a scattered pattern match.

---

## 10. References

- Patrick Cousot and Radhia Cousot. "Abstract Interpretation: A Unified
  Lattice Model for Static Analysis of Programs by Construction or
  Approximation of Fixpoints." POPL 1977.

- Olin Shivers. "Control-Flow Analysis in Scheme." PLDI 1988. Also: "Control-Flow Analysis of Higher-Order Languages; or Taming Lambda." PhD thesis, CMU-CS-91-145, 1991.

- Robin Milner. "A Theory of Type Polymorphism in Programming." JCSS 17, 1978.

- Craig Chambers and David Ungar. "Customization: Optimizing Compiler
  Technology for SELF, a Dynamically-Typed Object-Oriented Programming
  Language." PLDI 1989.

- Jeff Bezanson et al. "Julia: A Fresh Approach to Numerical Computing."
  SIAM Review 59(1), 2017.

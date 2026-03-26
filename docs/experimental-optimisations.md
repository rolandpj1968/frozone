# Experimental Optimisations

This document tracks optimisation experiments for the Frozone AOT Crystal backend —
what was tried, what worked, and what didn't.

---

## 1. Condition simplification (implemented)

### Idea
When a comparison operator (`<`, `<=`, `>`, `>=`, `==`, `!=`) appears as the condition
of an `if`/`while`/`until`, emit it as a bare Crystal `Bool` instead of wrapping in
`RubyBool` and calling `.truthy?`:

```crystal
# Before
if (a < b) ? RUBY_TRUE : RUBY_FALSE).truthy?
# After
if (a < b)
```

### Status
Implemented in `CrystalCodegen#emit_truthy`. The `SnapshotCodegen` subclass overrides
`comparison_op_call?` to add a soundness guard: the optimisation is suppressed if the
user has overridden the comparison operator on `Integer`, `Float`, or `String` (checked
against the settled VM method table at compile time).

### Impact
Eliminates two allocation-equivalent operations per comparison in tight loops. Not yet
benchmarked in isolation.

---

## 2. Constant hoisting for `RubyInteger` literals (not implemented)

### Idea
Hoist frequently-used integer literals (e.g. `RubyInteger.new(1_i64)`) to module-level
constants so Crystal sees a single shared allocation per unique value instead of one
per call-site visit:

```crystal
_LIT_1 = RubyInteger.new(1_i64)
# ... later ...
n = (n - _LIT_1)
```

### Experiment
Manually tested on `fib` (20 iterations). Debug build: ~12% improvement. Release build:
negligible — LLVM constant-folds the allocations away. Struct layout means `RubyInteger`
is likely stack-allocated in release anyway.

### Status
Not worth implementing until we have unboxed arithmetic (see §3). Revisit after §3.

---

## 3. Unboxed locals (implemented)

### Idea
When type inference can prove that a local variable always holds an `Int64` (or `Float64`),
emit it as a bare Crystal `Int64` without `RubyInteger` wrapping. Re-box only at the point
of heterogeneous dispatch (e.g. passing to a method typed `RubyObject`).

### Soundness caveat — BigInt promotion ⚠️
Ruby integers auto-promote from 64-bit fixnum to arbitrary-precision `BigInt` on overflow.
Unboxed `Int64` locals silently truncate on overflow rather than promoting. This is
**correct for all practical benchmark workloads** (loop counters, array indices, sizes
never exceed `Int64::MAX`), but is technically unsound for general Ruby.

**TODO**: Before shipping this as a production feature, add a guard: only unbox a local
when we can statically bound its range within `Int64` (e.g. loop counter from 0 to a
literal or inferred-small bound), OR emit a range-check at the assignment and fall back
to a boxed slow path. For now we accept the unsoundness as a known limitation of the
AOT backend.

### Implementation
Two-phase fixed-point inference in `SnapshotCodegen#infer_local_types`:
1. Seed from literal assignments (`IntegerLiteral → :i64`, `FloatLiteral → :f64`)
2. Expand: type any local whose ALL assignments are uniformly typed (propagates through
   assignments like `_iopw_i0 = j` when `j` is already typed)
3. Narrow: evict any local with an inconsistent assignment
4. Repeat until stable

Emit changes:
- `emit_local_var_write`: uses `emit_raw` for typed RHS → no `RubyInteger.new` wrapper
- `emit_local_var_read` (boxed context): boxes typed locals with `RubyInteger.new(...)`
- `emit_method_call` / `emit_attribute_write` for `[]` / `[]=`: passes bare `Int64` index
- `emit_index_op_write` (`ci[j] += ...` pattern): emits index temp as bare `Int64`
- `emit_truthy` for comparisons: uses `.to_i64`/`.to_f64` on untyped sides
- `RubyObject#[](Int64)` / `#[]=(Int64, RubyObject)` added to Crystal runtime for dispatch

### Benchmark impact (release build, N=200 matmul 20 iters)
| Benchmark | Before | After | Speedup |
|-----------|--------|-------|---------|
| matmul    | 1109 ms/iter | 386 ms/iter | **2.9×** |
| nbody     | ~350 ms/iter | 111 ms/iter | **~3×** |
| fib       | ~4 ms/iter | 3.2 ms/iter | ~1.2× |

The dominant win is eliminating `RubyInteger.new(1_i64)` heap allocation per inner loop
iteration, plus using the `RubyArray#[](Int64)` overload which bypasses polymorphic
dispatch on the index.

Note: fib's modest gain here is because the method parameters are still typed as
`RubyObject` — the recursion allocates a `RubyInteger` per call. Section §8 (method
type specialisation) eliminates this.

---

## 4. Call-site type inference for method parameters (implemented, partial)

### Idea
Forward dataflow over the execute block: infer Crystal types for literals and arithmetic
results, propagate through local variable assignments, then narrow method parameter
declarations at call sites.

### Status
Implemented in `SnapshotCodegen#infer_call_site_types`. Currently handles:
- Integer/Float/String/Symbol/Bool literals → concrete types
- Arithmetic (`+`, `-`, `*`, `**`) on same-type operands → same type
- Comparison ops on typed operands → `RubyBool`
- Local variable read after typed assignment

Not yet handled:
- Multi-block / loop-carried types (locals reset to `RubyObject` after first iteration)
- Method return types (would require full interprocedural analysis)
- Receiver type narrowing for instance method dispatch

---

## 5. Natural form overloads (implemented in Crystal runtime)

### Idea
`RubyInteger` already has overloads like `+(other : RubyInteger) : RubyInteger`. When
Crystal can see that both operands are `RubyInteger`, it selects the narrow overload and
the return type is `RubyInteger` without union pollution.

### Status
Already present in `crystal/src/ruby_integer.cr` for `+`, `-`, `*`, `/`, `%`, `**`,
`<`, `<=`, `>`, `>=`, `==`. No action needed — Crystal selects the right overload
automatically once call-site inference provides typed arguments.

---

## 6. `RubyArray` block initializer / constructor cleanup (implemented)

### Idea
`RubyArray.new(n) { |i| ... }` was polluting type inference because the internal `each`
iterator returned `Int32` (index) rather than `RubyObject`. Crystal inferred
`Int32 | RubyObject` for array element slots.

### Fix
Rewrote `RubyArray.new(count, &block)` using an explicit `while` loop with a
`RubyInteger` index. Crystal now infers element slots as `RubyObject` only.

### Status
Implemented in `crystal/src/ruby_array.cr`. Confirmed fixes `matmul` compilation.

---

## 7. `RubySymbol#length` return type (implemented)

### Issue
`RubySymbol#length` returned `Int32` (Crystal `String#size`). Since `RubyObject#length`
is abstract and all implementors' return types are unioned, this caused Crystal to infer
`Int32 | RubyInteger` for all `.length` dispatch, preventing the `RubyInteger` natural
form overloads from firing.

### Fix
Changed `RubySymbol#length` to return `RubyInteger.new(@name.size.to_i64)`.

### Status
Implemented in `crystal/src/ruby_symbol.cr`.

---

## 8. Method type specialisation — raw Int64/Float64 overloads (implemented)

### Idea
When a user-defined method is always called with raw-typed arguments (e.g. `Int64`), and
its body can be proven to return a raw numeric type, emit a second Crystal overload with
bare `Int64`/`Float64` param and return types alongside the normal `RubyObject` overload.
Crystal's overload resolution picks the fast path when args are typed; the boxed overload
remains for polymorphic dispatch.

```crystal
# Specialised overload — pure Int64 arithmetic, no allocations
def fib(n : Int64) : Int64
  if n < 2_i64
    return n
  end
  return fib(n - 1_i64) + fib(n - 2_i64)
end

# Boxed fallback — still present for RubyObject dispatch
def fib(n : RubyInteger) : RubyObject
  ...
end
```

### Implementation
Three-pass pre-analysis in `SnapshotCodegen`:
1. **`collect_raw_call_sites`** — walks the execute block (with unboxed-local types
   active); for each free call where ALL args are raw-typed (`:i64`/`:f64`), records the
   per-param raw types. Only methods with consistent types across all call sites qualify.
2. **`collect_typed_method_returns`** — tentatively assigns the return type (same raw type
   as params for same-type methods), then verifies by seeding `@typed_locals` with the
   param types and calling `infer_body_return_type`. Self-recursive calls work because the
   tentative return type is already set when the body is walked.
3. **`body_all_raw_safe?`** — guards specialisation: only emits the raw overload when the
   entire body is composed of arithmetic/comparison ops, typed locals, and calls to other
   specialised methods. Prevents emitting a broken raw version that tries to pass `Int64`
   to a `RubyObject` receiver.

**Emit**: `emit_specialized_vm_method` emits the raw overload using `emit_raw_body`, which
recurses through structural nodes (If, Sequence, Return, LocalVariableWrite) and delegates
to `emit_raw` for all expressions. At call sites in the execute block (and inside raw
bodies), `emit_method_call` detects a specialised target with all-raw args and routes to
the `Int64` overload.

**Soundness**: The specialised body only fires for self-contained arithmetic/recursive
methods. Any method that calls into polymorphic dispatch (method on a `RubyObject` receiver)
fails `body_all_raw_safe?` and falls back to the boxed version.

### Benchmark impact (release build, fib(20) 3 iters)
| Benchmark | Before §8 | After §8 | Speedup |
|-----------|-----------|----------|---------|
| fib(20)   | 3.2 ms/iter | **0.04 ms/iter** | **~80×** |

The gain is total elimination of `RubyInteger` allocations from the recursion and removal
of polymorphic `+`/`<` dispatch. Crystal/LLVM can now inline and optimise the pure
`Int64` recursion.

### Scope
Currently limited to top-level methods. Instance methods and methods with optional/rest
params are not specialised. Extension to class methods (typed ivars) is tracked as §9.

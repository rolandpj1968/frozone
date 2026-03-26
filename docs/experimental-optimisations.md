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

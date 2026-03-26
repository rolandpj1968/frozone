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

## 3. Unboxed arithmetic (planned)

### Idea
When type inference can prove that a local variable always holds an `Int64` (or `Float64`),
emit it as a bare Crystal `Int64` without `RubyInteger` wrapping. Re-box only at the point
of heterogeneous dispatch (e.g. passing to a method typed `RubyObject`).

### Expected impact
This is the highest-leverage optimisation for numeric benchmarks. `fib`, `matmul`, `nbody`
spend the majority of their time in `RubyInteger#+`/`*` / `RubyFloat#+`/`*`. Unboxing
would bring performance within striking distance of native Crystal.

### Approach
1. Extend `infer_expr_type` to return `Int64` / `Float64` for arithmetic on proven-integer
   operands.
2. Emit locals typed `Int64` when all assignments have inferred type `Int64`.
3. Emit arithmetic directly: `a + b` instead of `a.__add__(b)`.
4. Insert `RubyInteger.new(x)` at box points (method calls typed `RubyObject`, array
   insertion, return from `RubyObject`-typed methods).

### Status
Not yet started. Prerequisite: stable call-site type inference (§ type inference below).

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

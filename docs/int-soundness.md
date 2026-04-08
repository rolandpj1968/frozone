# Integer Overflow Soundness in Frozone-Compiled Code

*Status: 2026-04-08. Latent bug, not yet manifest. Tracked, not fixed.*

This document describes a known soundness gap in Frozone's AOT
compilation pipeline: **Frozone emits raw `Int64` arithmetic for
loop-carried integer locals without proving that the loop never
produces a value outside `Int64` range.** Today's benchmarks happen
to never overflow, so the gap doesn't manifest. Real-world Ruby
code with growing accumulators (cryptographic hashes, factorials,
counters in long-running loops) would silently produce wrong answers.

## The gap

Frozone's type inference (`lib/frozone/compiler/type_inference.rb`)
assigns `Type::I64` to a local whenever:

1. Its initial value is an integer literal that fits in `Int64`, AND
2. Every operation that writes to it is integer arithmetic returning
   another integer.

The codegen (`lib/frozone/compiler/codegen.rb`) then emits raw
`Int64` arithmetic in the compiled body for any local TI calls
`Type::I64`. For a loop like:

```ruby
x = 1
n.times { x *= 2 }
puts x
```

TI sees `x = 1` (literal Int) and `x *= 2` (Int * Int → Int) and
concludes `x : Int64`. The compiled body becomes a tight loop of
`Int64 *= 2`. For `n = 64` this overflows; for `n = 1000` it's
firmly in Bignum territory in MRI but in compiled Frozone it just
wraps (or panics in `--debug`).

The compiler has silently introduced a soundness bug. **Ruby
integers are unbounded; Frozone's compiled `Int64` is not.**

## Why it hasn't bitten

1. The benchmark suite doesn't actually exercise overflow.
2. Crystal `--release` `Int64` arithmetic *wraps* without raising,
   so wrong answers come out without crashes.
3. We added output verification to `bench_smoke` recently
   (commit 42c9e40), but the smoke benchmarks themselves still don't
   overflow — the verification only catches DCE / typo regressions.
4. Nobody has shipped Frozone-compiled code into anything resembling
   production yet.

## What real code would expose

These idioms would produce wrong answers under the current
compilation pipeline:

- **Cryptographic hashes / mixers**: `h = h * 31 + c` accumulates
  without bound. MRI promotes to Bignum; Frozone wraps.
- **`factorial(n)` for `n > 20`**: `Int64::MAX / 21 ≈ 4.4e17`, so
  `factorial(21) = 21!` overflows mid-computation.
- **Bit-packed counters that exceed Int64**: rare today, but if we
  later add narrower live-value typing (`Int8`/`Int16`/`Int32`),
  this becomes a per-narrowed-type problem at every width.
- **Any user code that relies on Ruby's transparent Int → Bignum
  promotion** as a correctness contract.

## The honest framing — two compilation modes

The right long-term position is to expose the trust/proof choice as
an explicit compilation flag.

| Mode | Semantics | When to use |
|---|---|---|
| **`--unsafe-int64`** (today's behaviour, future-flag-gated) | Trust every `Int`-typed local. Emit raw `Int64` ops. Crystal `--release` wraps silently; `--debug` may panic. | Benchmarks. Microbenchmark validation. Code we've audited by hand. The minority case where speed beats correctness. |
| **`--sound-ints`** (the eventual default) | TI must *prove* a local stays in `Int64` via bounds analysis + loop-bound analysis. Anything not provably bounded falls back to boxed `RubyInteger`, which the runtime promotes to `BigInt` as needed. | Distribution. Real-world code. Anything we can't audit. The default for non-benchmark uses. |

The transition isn't binary. As TI gets smarter about integer
bounds, more locals graduate from "Int64 by trust" to "Int64 by
proof", and the `--unsafe-int64` dependency shrinks. Eventually
`--sound-ints` becomes the default and `--unsafe-int64` is the
opt-out for benchmark microoptimisation.

## What loop-bound analysis would look like

The actual sound mode requires propagating integer bounds across
loop iterations. Sketch:

1. **Loop scoping in TI** — recognise `while` / `until` / `for` /
   `n.times` / `range.each` / `array.each` as loop scopes that need
   fixed-point iteration of the bounds lattice.

2. **Loop-carried local detection** — a local is loop-carried if
   it's read from outside the loop and written inside (i.e. its
   def-use chain crosses the back-edge). Loop-carried locals need
   special handling; non-loop-carried locals can keep simple bounds
   propagation.

3. **Loop iteration count** — for some loop forms we can statically
   bound the iteration count:
    - `n.times { ... }` runs `n` times where `n`'s bounds may
      themselves be tracked.
    - `(a..b).each { ... }` runs `b - a + 1` times (or 0 if `b < a`).
    - `array.each { ... }` runs `array.size` times where the size
      may be statically known for literal arrays.
    - `while cond` is conservatively unbounded unless `cond` can be
      analysed.

4. **Loop summary** — given iteration count `[k_min, k_max]` and a
   per-iteration update `x_new = f(x_old)`, compute the union of
   `f^k(x_initial)` for `k ∈ [k_min, k_max]`. For monotone updates
   (`x += c` with constant `c`) this is a single closed-form
   calculation (`x_initial + c * k`). For non-monotone updates we
   widen aggressively or bail out.

5. **Bail-out fallback** — any local whose bounds can't be proven
   stays as boxed `RubyInteger`, costing one allocation per write
   but keeping correctness.

This is a multi-day project at minimum. The right place in the
pipeline is between TI's existing range propagation
(`type_inference.rb` `propagate_int_bounds`, added in commit
9c2e162 + follow-ons) and the codegen decision to emit raw `Int64`
vs boxed `RubyInteger`.

## Cheap intermediate steps (could land before loop-bound analysis)

These don't make the code sound but improve the failure mode.

### Fail-loud mode

Emit Crystal's overflow-raising operators (or explicit guards) for
raw `Int64` arithmetic in compiled bodies. The compiled binary
starts *raising* on overflow instead of silently wrapping. Doesn't
fix the bug but makes its symptoms *visible and debuggable* in
development. Slower, but strictly more correct than today's
silent-wrap.

### Defined-wrap mode

Emit Crystal's wrapping operators (`&+`, `&-`, `&*`) explicitly so
the compiled output's wrap-around behaviour is *defined* rather
than depending on the Crystal build flag. `--debug` builds and
`--release` builds would at least produce the same answers in the
unsafe path.

These two are alternatives, not stages. Pick one.

## Recommended sequence

1. **Storage-narrowing** (commit 9c2e162's bounds work, plus follow-on
   codegen consumers) — pure perf/memory win, no soundness implication
   because storage is never live in arithmetic. Doable now.
2. **Fail-loud unsafe mode** as the cheap correctness floor — surfaces
   any latent overflow in existing benchmarks if we missed one. ~1 hour
   of work; useful as a development sanity check.
3. **Loop-bound analysis** as the real fix. Multi-day. Unlocks
   `--sound-ints` as a distinct mode and starts the gradual
   transition.

## How this surfaced

While sketching the storage-narrowing optimisation, the user noticed
that the bounds-tracking work being added had a much deeper
implication: the *existing* `Int64` emission depends on the same
kind of bounds proof that narrowing requires. We've been getting
away with it in benchmarks but the gap is real.

The conversation that produced this document is preserved in the
session log around 2026-04-08 evening; the headline insight was
"loop bounds aren't just an optimisation enabler for narrower
types; they're a *correctness prerequisite* for the entire raw-Int64
emission story Frozone already does".

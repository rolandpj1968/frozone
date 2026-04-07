# Larger Benchmarks and Self-Compilation Assessment

*Status: 2026-04-07, commit 84e88b0*

This document assesses two related questions:

1. **Where is Frozone's AOT compiler in terms of compiling larger Ruby programs**, beyond the existing micro-benchmark suite?
2. **What's left before Frozone can compile *itself*** — true self-hosting via the AOT pipeline (Frozone³, in the staging language).

These are related because the compiler is itself the most demanding "larger Ruby program" we have on hand: ~28 KLOC of MRI-Ruby across 136 files, exercising every dynamic-dispatch corner of the language, plus ~19 KLOC of Frozone-Ruby in `lib/core/4.0/`.

---

## 1. Larger benchmarks: what we cover and what we don't

### Current benchmark suite (26 benchmarks)

The `bench/benchmarks/` directory has 26 files. All compile end-to-end and run:

| Category | Benchmarks | Frozone status |
|---|---|---|
| **Numeric/control-flow** | `fib`, `loops_times`, `cfunc_itself`, `ruby_xor` | ✓ excellent (12–63× MRI) |
| **Float-heavy numerics** | `nbody`, `matmul`, `blurhash` | ✓ excellent (10–63× MRI) |
| **Array-bound** | `nqueens`, `binarytrees`, `fannkuchredux`, `sudoku` | ✓ good (2.4–29× MRI) |
| **OO-heavy** | `splay`, `attr_accessor`, `respond_to`, `getivar`, `setivar`, `object_new`, `object_new_initialize` | ✓ working, splay GC-bound |
| **Dispatch micro-bench** | `keyword_args`, `send_rubyfunc_block` | ✓ working |
| **String** | `str_concat` | ✓ working |
| **Struct** | `structaref`, `structaset` | structaref ✓; structaset broken (`Struct.new(...)` codegen bug) |

**Coverage gaps in this suite**:

- **No Hash-heavy benchmark**. Hash dispatch goes through `KeyWrapper#hash` which routes via `Fiber[:context]` — currently the slowest path in the VM. We have no benchmark exercising this.
- **No Regex/String-processing benchmark**. We compile `String` methods through pure Frozone-Ruby plus regex primitives, but nothing stress-tests it (e.g. JSON parsing, log parsing, simple template rendering).
- **No exception-throwing benchmark**. `raise`/`rescue` paths exist but are uncovered for perf.
- **No `eval`/metaprogramming benchmark**. AOT can't compile these — they're a hard exclusion, but worth documenting which idioms force interpreter fallback.

### Real-world workloads not yet attempted

These are the obvious next-step "larger benchmark" targets, ranked by tractability:

1. **rubyspec subsuites as integration tests** (low-hanging). The `bundle exec rake core` runner currently runs the VM in interpreter mode. Running it through `Frozone.compile!` would exercise the full library surface in a way no micro-benchmark can. Estimated work: a `rake core_compiled` task that AOTs each spec file. Blockers: spec files use `eval`, `method_missing`, runtime `class_eval` — many spec files would compile-fail. But many would also pass, and the failures would be a high-quality compiler bug list.

2. **optcarrot (NES emulator)**. The traditional Ruby JIT benchmark. ~5 KLOC of mostly numeric/array Ruby. Would expose: bitwise operations on large integer ranges, hot-loop dispatch, mutable buffer arrays. Probably needs `Array#pack`/`unpack` to work end-to-end. Realistic target.

3. **The Frozone compiler itself** (see Section 2 below). This is by far the largest pure-Ruby program we have access to and the best stress test for the compiler. Self-compilation is its own milestone.

4. **Sinatra "hello world"**. Includes Rack, IO, regexp routing, hash dispatch. Probably blocked by `eval` in Sinatra's DSL and by missing IO intrinsics in compiled mode. Aspirational.

5. **rails console boot**. Definitively out of reach. Listed for completeness — too much `eval`, autoload, DSL metaprogramming.

### Recommended next step for "larger benchmarks"

A `rake bench:large` task that AOT-compiles and runs **the full benchmark suite plus a small set of new benchmarks** chosen to fill the coverage gaps:

- A Hash-keyed lookup loop (1M `h[key]` operations on 10K-key hash with various key types: Symbol, String, Integer)
- A regex/scan loop (parse 1MB log file with anchored regex, count matches)
- A `raise`/`rescue` loop (10K exceptions thrown and caught)

Cost: ~half a day to write three benchmarks plus the rake task. Value: closes the perf-coverage gap and gives a pre-commit "no regression" net for non-numeric code.

---

## 2. Self-compilation status

### Memory note vs reality

The standing memory note (`project_self_compile_assessment.md`, dated 2026-03-30) said:

| Metric | Memory note (8 days ago) | Current (this assessment) | Change |
|---|---|---|---|
| `instance_variable_get` count | 273 | **26** | **−90%** |
| `Fiber[:context]` total | ~79 | 79 | unchanged |
| Compiler proper `instance_variable_get` | unknown | **0** | — |
| Compiler proper `Fiber[:context]` | unknown | **3** (in ast/) | — |

The "65–70% ready" headline figure in the memory note is no longer the right framing. The big `instance_variable_get` purge has happened — every `lib/frozone/compiler/*.rb` file is now reflection-free.

### Where the remaining blockers actually live

**Compiler-proper blockers** (these are the real self-compile gating items):

- `lib/frozone/ast/frozone_compile.rb` — 6 `instance_variable_get` uses, all walking Vm::Scope/Vm::ClassObject internals to extract method tables, constants tables, slots. **Fix: add public accessors to those VM classes.** ~1 hour.
- `lib/frozone/ast/string_literal.rb` — 1 use, accessing internal `@value`. **Fix: add accessor.** Trivial.
- `lib/frozone/ast/constant_write.rb` — 6 uses on Vm::ClassObject for the `@temporary_name`/`@cached_name_str` cache. **Fix: add accessors or refactor caching.** ~30 min.

**Total compiler-proper reflection cleanup: ~2 hours.**

**Runtime intrinsics** (`lib/frozone/vm/intrinsics/`) account for 39 of the 79 `Fiber[:context]` uses. These are NOT a self-compile blocker — they live in the VM runtime that gets *replaced* by Crystal-native code in the compiled binary. The intrinsics module is the hand-off point where compiled Frozone-Ruby calls down into a Crystal runtime; that runtime can use whatever Crystal idioms it likes. As long as the compiler can be told "this method is an intrinsic primitive", its body never needs to compile.

**VM core** (`lib/frozone/vm/*.rb` excluding intrinsics) — 37 of the 79 `Fiber[:context]` uses, mostly in `hash_object.rb` (KeyWrapper dispatch), `array_object.rb`, `vm.rb`, `fiber_object.rb`. These DO need to compile if we want `Frozone³` (the compiler running as a native binary that itself compiles Ruby). The Fiber-context pattern is `Fiber[:context]` → "current execution context" — replacing it with an explicit thread-local or a global singleton is mechanical but touches a lot of files.

### What runs as compiled vs what doesn't

The compilation pipeline today is:

```
Ruby source → Prism (MRI) → Frozone AST → Frozone.compile! → Crystal source → crystal build → native binary
```

The `--aot` mode already does the right thing: it splits "load phase" (parsing, class definition, method registration) from "execute phase" (the actual benchmark loop). Only the execute phase is compiled. The load phase runs in the MRI host once at compile time and bakes its results into the Crystal source as data tables.

This means:

- **Parser code runs at compile time only** — no need to compile Prism or our wq_parser.
- **Class definition / hierarchy setup runs at compile time only** — no need to compile `lib/core/4.0/hierarchy.rb` etc.
- **Intrinsics get replaced** — primitive operations (string concat, integer arithmetic) get emitted as Crystal source directly, not as method calls into compiled intrinsic bodies.

**The compiler itself sits squarely in "execute phase"** if we want self-hosting. That's where the gating items above apply.

### Realistic self-compile roadmap

**Phase A — compile a tiny program from a Frozone subset** (~1 day)
- Goal: `bundle exec ruby frozone.rb --aot frozone_compile.rb` produces a native binary that compiles `puts "hello"` to Crystal.
- Required: ~2 hours of accessor cleanup + ~6 hours of sketching the compiler-as-Frozone-program entry point + intrinsic registration.
- Outcome: proves the loop closes. Real `Frozone²` (Frozone running compiled Frozone) demo.

**Phase B — Fiber-context replacement in VM core** (~2 days)
- Goal: kill all `Fiber[:context]` uses in `lib/frozone/vm/*.rb` by introducing an explicit `ExecutionContext` parameter or thread-local.
- Touches: hash_object.rb, array_object.rb, kernel_intrinsics.rb, fiber_object.rb, vm.rb, helpers.rb.
- Risk: high — `Fiber[:context]` is the implicit dispatch context for hash key comparison, custom `==` definitions, etc. Needs careful audit.

**Phase C — KeyWrapper compile-time dispatch** (~1 day)
- Currently `Hash[key]` resolves to `KeyWrapper.new(key).hash` which dispatches via `Fiber[:context]`. For known-typed keys (Symbol, String, Integer), the compiler should specialise.
- Already partially done for spec compile via `cr_call_args` per-arg typing.

**Phase D — module ancestor flattening** (~1.5 days)
- Today the runtime walks ancestor chains for method lookup. Compiled code should have method tables flattened per concrete class.
- This is the project_module_flattening memory note. It's blocking more than self-compile alone — also affects performance of any heavily-modular code.

**Phase E — full Frozone compiler in compiled form** (~unknown, "weeks")
- Compile every `lib/frozone/compiler/*.rb` and `lib/frozone/ast/*.rb` file, link against the compiled VM, run the result on a test program.
- Expect a long tail of edge cases: `Marshal.dump`, complex `case`/pattern matches, `Comparable` mixin, exception class hierarchies.

**Total optimistic estimate to first compiled-Frozone-compiles-hello-world: ~1 day** (Phase A only). This is a useful, demoable milestone.

**Total optimistic estimate to compiled-Frozone-compiles-the-fib-benchmark: ~5–7 days** (Phases A + B + C). This is the real self-hosting bar.

**Phase D and E** can be tackled separately afterwards as compiler perf and completeness work, not gating items.

### What's NOT a blocker (despite earlier assessments)

- `instance_variable_get` in compiler — already cleaned up.
- Missing native types — `Type::I64`, `Type::F64`, `Type::ARRAY_*` are stable.
- Type inference — production-ready, has been the load-bearing part of the compiler for months.
- Codegen architecture — the functional `cr()` rewrite landed in 0fcf181 and the dispatcher pattern is stable.
- Crystal output formatting — works modulo small bugs (the recent elsif indent fix being one).
- Test coverage — 756 RSpec specs, all green; 96.6% core ruby-spec; 99.4% language ruby-spec.

---

## Recommendation

**Don't pursue self-compilation as a goal in itself right now.** The reasons it's tempting are real (genuine validation, removes the MRI dependency for distribution, makes the compiler binary native-fast), but the immediate compiler perf wins from the splay investigation (skip scrub_utf8 for ASCII literals, constant-fold symbol literals, native arrays in Hash literals) will help every benchmark and every future user *including the future compiled compiler*. They are the more impactful next steps.

**Do pursue Phase A** as a one-day spike whenever it feels timely — it produces a satisfying demo and proves the architecture, with low investment and low risk. The reflection cleanup it requires is good hygiene anyway.

**Defer Phases B–E** until either (a) we have a concrete need to distribute Frozone without an MRI dependency, or (b) the compiler is demonstrably slow enough during interactive use to warrant a native-binary compiler.

The most valuable "larger benchmark" work right now is:

1. **A `rake bench:large` task** with three new benchmarks covering Hash, regex, and exceptions — closes the coverage gap.
2. **Investigate the binarytrees regression** (2.29s → 3.7s, ~60% slowdown sometime since 2026-04-01).
3. **Try optcarrot** as a stretch goal — it's the right size for a mid-term integration test.

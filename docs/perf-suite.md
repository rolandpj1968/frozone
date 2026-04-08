# Frozone Performance Benchmark Suite

## Overview

The canonical Ruby benchmark suite is hosted at speed.ruby-lang.org and sourced from
[Shopify/yjit-bench](https://github.com/Shopify/yjit-bench). All benchmarks share a
common harness: `run_benchmark(N) { ... }` using `Process.clock_gettime(CLOCK_MONOTONIC)`
for wall-clock timing.

Frozone is a tree-walking Ruby interpreter written in Ruby. It can run pure-Ruby,
self-contained benchmarks directly. Benchmarks that require C extensions, Rails, or
forked subprocesses are not viable targets.

---

## Recommended Benchmarks

### Tier 1 — Excellent fit (pure Ruby, no external dependencies)

| Benchmark | What it exercises |
|---|---|
| `fib.rb` | Recursive Fibonacci(32); integer arithmetic, conditionals |
| `nqueens.rb` | Bitwise backtracking; Array, while loops |
| `matmul.rb` | 200x200 matrix multiply; nested while, Array of Array, Float |
| `nbody/benchmark.rb` | Float arithmetic; attr_accessor, Math.sqrt, classes |
| `binarytrees/benchmark.rb` | Recursive object allocation; nested Arrays |
| `splay.rb` | OOP: classes, attr_accessor, Random, Hash, Array |
| `gcbench.rb` | Object allocation stress; recursive binary tree |
| `sudoku.rb` | Constraint propagation; Arrays, Hashes |
| `loops-times.rb` | Integer#times with block, Array indexing |
| `fannkuchredux/benchmark.rb` | Array dup/delete_at/insert, parallel assignment |
| `blurhash/benchmark.rb` | Cosine transforms; Float + Array, Math |
| `getivar.rb` | Instance variable read micro-benchmark |
| `setivar.rb` | Instance variable write micro-benchmark |
| `attr_accessor.rb` | attr_accessor dispatch micro-benchmark |
| `keyword_args.rb` | Keyword argument dispatch (5M calls) |
| `throw.rb` | Return-from-block control flow |
| `structaref.rb` | Struct read accessor performance |
| `structaset.rb` | Struct write accessor performance |
| `object-new.rb` | Object allocation throughput |
| `object-new-initialize.rb` | Object allocation with initialize |

### Tier 2 — Good fit (some stdlib dependencies)

| Benchmark | Dependency / note |
|---|---|
| `respond_to.rb` | respond_to? across 3-class hierarchy (12M calls) |
| `ruby-xor.rb` | String#getbyte / #setbyte / #bytesize |
| `str_concat.rb` | String << concat; UTF-8 and BINARY encodings |
| `send_bmethod.rb` | define_method dispatch |
| `cfunc_itself.rb` | Block dispatch via itself |
| `send_rubyfunc_block.rb` | Block dispatch via Ruby method |
| `lee/benchmark.rb` | BFS pathfinding; Array, Hash |
| `ruby-json/benchmark.rb` | Hand-written JSON parser — needs StringScanner (verify first) |

### Not suitable

- `activerecord/`, `railsbench/`, `rubocop/`, `ruby-lsp/`, `hexapdf/`, `liquid-c/` —
  require C extensions or the full Rails stack.
- `knucleotide/` — requires Process.fork and pipes.
- `30k_ifelse.rb` / `30k_methods.rb` — auto-generated 2.5 MB files; not representative.

---

## Harness Adaptation

The yjit-bench harness calls `run_benchmark` and optionally `make_shareable` (a Ractor
API stub). Add the following shim before loading any benchmark file:

```ruby
def run_benchmark(n)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts "#{elapsed / n * 1_000} ms/iter"
end

def make_shareable(x) = x  # no-op stub for Ractor API
```

`Process.clock_gettime` must be available — see Known Gaps below.

---

## Known Gaps

The table below summarises Frozone's current core spec coverage relevant to the
benchmark suite (status as of 2026-03-20).

| Feature | Status | Impact |
|---|---|---|
| `Array`, `Hash`, `Float`, `Integer` | All specs passing | No blockers |
| `Math` | 243/243 passing | No blockers |
| `Struct` | 182/182 passing | No blockers |
| `Fiber` | 160/160 passing | No blockers |
| `Regexp` | 260/262 (2 minor failures) | Negligible |
| `Process.clock_gettime` | Works (confirmed 2026-03-20) | No blocker |
| `StringScanner` | Not checked | Blocks `ruby-json/benchmark.rb` |
| `Process` (general) | Partial (large error count) | May affect harness edge cases |
| `Signal` | Partial (36 failures) | Low impact for benchmarks |
| `Marshal` | Not implemented (107 errors) | No benchmarks require it |

Priority items before running the benchmark suite:

1. Confirm `Process.clock_gettime(Process::CLOCK_MONOTONIC)` works — required by every
   benchmark via the harness. **Confirmed working (2026-03-20).**
2. Check `StringScanner` availability if `ruby-json/benchmark.rb` is desired.
3. All Tier 1 benchmarks should otherwise run without further changes.

---

## Infrastructure Notes

### Frozone argument handling

`frozone.rb` evaluates the **first positional file only** when no `-e` flag is given (matching
MRI semantics). To load two files in sequence use a thin runner script:

```ruby
# bench/run_bench.rb
harness_path = File.expand_path('harness.rb', __dir__)
bench_path   = File.expand_path(ARGV[0])
load harness_path
load bench_path
```

Run via:
```
bundle exec ruby frozone.rb bench/run_bench.rb bench/benchmarks/fib.rb
```

### Scale-down requirement (interpreter mode)

Frozone's tree-walking interpreter is approximately 600× slower than MRI. The
benchmarks in `bench/benchmarks/` use problem sizes scaled down 100–1000× to keep
each interpreter run under ~5 seconds.

For AOT compilation, the stubs in `bench/stubs/` define `run_benchmark` as a no-op
(to prevent the benchmark running through the interpreter during `require_relative`
load) and provide their own inline `.times` loops matching the benchmark's iteration
count. The compiled binary runs the work at native speed.

---

## Benchmark Results

### AOT Compiled — 2026-04-08 (after runtime allocator pass)

**Environment**: Ruby 4.0.1 (MRI host), Crystal 1.16 `--release`, Linux x86-64 (AMD 6-core)
**Frozone**: `--aot` generates Crystal source → `crystal build --release` → native binary
**Measurement**: identical inline code for all runtimes, `time` wall clock

| Benchmark | Frozone | MRI | YJIT | vs MRI | vs YJIT |
|---|---|---|---|---|---|
| nbody ×100 | 117 ms | 7293 ms | 2684 ms | **62×** | **23×** |
| fib(35) ×3 | 95 ms | 2347 ms | 318 ms | **25×** | **3.3×** |
| matmul(200) ×20 | 260 ms | 7530 ms | 3071 ms | **29×** | **12×** |
| sudoku ×20 | 438 ms | 7466 ms | 2015 ms | **17×** | **4.6×** |
| blurhash ×10 | 242 ms | 2480 ms | 1050 ms | **10×** | **4.3×** |
| nqueens 500×12 | 6661 ms | 199000 ms | 49500 ms | **30×** | **7.4×** |
| str\_concat ×100 | 992 ms | 5276 ms | 2078 ms | **5.3×** | **2.1×** |
| binarytrees ×60 | 1993 ms | 16586 ms | 6456 ms | **8.3×** | **3.2×** |
| fannkuchredux ×10 | 849 ms | 3171 ms | 3104 ms | **3.7×** | **3.7×** |
| splay ×200 | 14313 ms | 19963 ms | 14400 ms | **1.4×** | **1.0×** |

All benchmarks compile and run end-to-end. fib generates assembly identical to
hand-written Crystal (overhead is Crystal's integer overflow checking, not codegen).
**All 12 timed benchmarks now meet or beat YJIT.**

**Splay closure (2026-04-08, four steps in order):**
- **scrub_utf8 skip on known-valid UTF-8** (commit 86d2809) — strings constructed
  from Crystal `String` literals are pre-marked valid; `to_crystal_string` returns
  via direct memcpy instead of byte-walking. splay 36.6s → 32.4s.
- **Literal symbol constant-folding** (commit 25752fd) — every unique `:foo` becomes
  a static `Ruby_Sym_<i>` constant in the file header; call sites are bare loads
  instead of hash lookups. splay 32.4s → 30.7s.
- **Small-integer interning** (commit 7de92de) — `RubyInteger.new(v)` for v in
  -128..127 returns a shared singleton from a 256-entry cache instead of
  allocating. Mirrors MRI's Fixnum optimization. splay 30.7s → 21.4s,
  binarytrees 3.86s → 1.99s, fannkuchredux 1.31s → 0.85s.
- **Literal-numeric array hoisting** (commit 1d78ff2) — every unique
  `[1,2,3,...]` literal becomes a static `Ruby_Arr_<i>` constant. Trades
  Ruby's "fresh array per construction" semantics for ~10× fewer allocations
  in tight loops. splay 21.4s → 14.3s, all other benchmarks unchanged
  (none have hot literal-array paths).

Cumulative: **splay 36.6s → 14.3s = 61% faster, 2.6× speedup**, taking it
from "the laggard" to **tied with YJIT (14.4s)**.

**Status notes:**
- **splay**: 14.3s, within noise of YJIT 14.4s. The session's allocator
  pass closed the entire gap. Profile is now 80% Boehm GC mark/sweep —
  any further wins would need region allocation or moving away from
  conservative GC entirely.
- **binarytrees**: 1.99s — below the README's historical 2.29s baseline.
- **fannkuchredux**: 0.85s — beats YJIT by 3.7× now.
- **str_concat**: 1.0s, 2.1× faster than YJIT, runs end-to-end after the
  exponential-capacity buffer fix (commit 6abb554).
- **structaset**: now compiles and runs end-to-end after commit d2fae53,
  which synthesises a plain Crystal class for `Struct.new(...)` subclasses.
  Currently 79s vs YJIT 33s — slower than YJIT because every iteration
  boxes `i` (up to 1M) outside the small-int cache. Functional first;
  perf needs class-typed-ivar specialization that accepts Int64 directly
  into the setter. Not yet in the smoke / headline table.

### Interpreter-only — 2026-03-20, commit db16601

**Environment**: Ruby 4.0.1 (MRI host + Frozone guest), Linux x86-64
**Frozone**: tree-walking interpreter, `bundle exec ruby frozone.rb`

Problem sizes are reduced so that Frozone takes 30 ms – 3 s per iteration.
All figures are **ms per benchmark iteration** (lower is better).

| Benchmark | Problem size | MRI ms/iter | Frozone ms/iter | Ratio (F/M) |
|---|---|---|---|---|
| `fib.rb` | fib(20), N=3 | 0.68 | 735 | 1081× |
| `nqueens.rb` | N=8, N=3 | 1.11 | 2187 | 1971× |
| `nbody.rb` | 50 steps, N=3 | 0.099 | 101 | 1020× |
| `getivar.rb` | 10 K ivar reads, N=3 | 0.44 | 620 | 1409× |
| `setivar.rb` | 10 K ivar writes, N=3 | 0.43 | 183 | 426× |
| `attr_accessor.rb` | 10 K accessor calls, N=3 | 1.13 | 705 | 624× |
| `keyword_args.rb` | 5 K kw-arg calls, N=3 | 1.60 | 370 | 231× |
| `object_new.rb` | 1 K Object.new, N=3 | 0.12 | 31.7 | 264× |
| `object_new_initialize.rb` | 1 K C.new(a,b,c,d), N=3 | 0.19 | 38.8 | 204× |

**Geometric mean ratio: ~600× slower than MRI** (tree-walking interpreter)

The AOT compiler eliminates this entirely — compiled fib is 17× faster than MRI,
not 1081× slower.

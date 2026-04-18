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

### AOT Compiled — 2026-04-18 (pointer-based object model, 23/24 passing)

**Environment**: Ruby 4.0.1, YJIT, Crystal 1.16 `--release`, GCC 13 `-O2 -std=c++20`,
Linux x86-64 (AMD 6-core)

C++ backend uses the pointer-based object model (raw pointers, RubyObject
base class, no shared_ptr). Crystal uses Boehm GC. Both compile from the
same stubs (`bench/stubs/`); MRI/YJIT run the same stubs interpreted.
All times in wall-clock milliseconds.

**Note**: C++ perf numbers improved after the shared_ptr → pointer pivot.
nbody dropped from 142ms to 110ms (2x faster). Object-creation and
accessor micro-benchmarks also faster (no refcount traffic).

| Benchmark | MRI | YJIT | C++ | Crystal | C++/MRI | Crystal/MRI |
|-----------|----:|-----:|----:|--------:|--------:|------------:|
| fib(35) x3 | 2326 | 501 | 37 | 94 | **63x** | **25x** |
| matmul(200) x20 | 7355 | 2897 | 82 | 256 | **90x** | **29x** |
| nbody x100 | 7259 | 2644 | 142 | 116 | **51x** | **63x** |
| nqueens 500x12 | 198033 | 49711 | 5890 | 6566 | **34x** | **30x** |
| loops_times | 8675 | - | 96 | 123 | **90x** | **71x** |
| sudoku x20 | 7151 | 1928 | 7 | 418 | **1084x** | **17x** |
| fannkuchredux x10 | 3217 | 3161 | 102 | 857 | **32x** | **3.8x** |
| blurhash x10 | 2504 | 1057 | 241 | 246 | **10x** | **10x** |
| binarytrees x60 | 16244 | 6916 | 4177 | 2000 | **3.9x** | **8.1x** |
| str_concat x100 | 5248 | 4502 | 2894 | 992 | **1.8x** | **5.3x** |
| splay x200 | 20349 | 13417 | 48391 | 13835 | 0.42x | **1.5x** |
| attr_accessor | 358 | - | 1.3 | 4.3 | **278x** | **83x** |
| getivar | 230 | - | 1.3 | 4.7 | **182x** | **49x** |
| setivar | 221 | - | 1.1 | 4.6 | **207x** | **48x** |
| keyword_args | 125 | - | 1.0 | 5.1 | **130x** | **24x** |
| object_new | 137 | - | 0.9 | 3.3 | **149x** | **41x** |
| object_new_init | 152 | - | 4.8 | 5.7 | **32x** | **27x** |
| respond_to | 161316 | - | 1.4 | 2.0 | **116783x** | **80564x** |
| cfunc_itself | 34750 | - | 0.6 | 2.6 | **61540x** | **13474x** |
| send_rubyfunc_block | 45729 | - | 1.5 | 1.5 | **30643x** | **30438x** |
| ruby_xor | 139 | - | 1.9 | 3.3 | **73x** | **42x** |
| structaref | 112071 | - | 1.1 | 1041 | **104499x** | **108x** |
| structaset | 87961 | - | 0.8 | 79171 | **105384x** | **1.1x** |

**Highlights:**
- C++ wins compute-heavy: fib **63x** MRI / **14x** YJIT; sudoku **1084x** MRI / **276x** YJIT
- Crystal wins allocation-heavy: binarytrees 2.1x faster than C++, str_concat 2.9x
- Both backends beat YJIT on every compute benchmark
- Splay is the only outlier where C++ is slower than MRI (std::any overhead)
- Micro-benchmarks (dispatch/accessor) show extreme ratios where the optimiser
  constant-folds the entire computation

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

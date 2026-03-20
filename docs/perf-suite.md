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
| `Process.clock_gettime` | Needed for harness timing | Must be verified / added |
| `StringScanner` | Not checked | Blocks `ruby-json/benchmark.rb` |
| `Process` (general) | Partial (large error count) | May affect harness edge cases |
| `Signal` | Partial (36 failures) | Low impact for benchmarks |
| `Marshal` | Not implemented (107 errors) | No benchmarks require it |

Priority items before running the benchmark suite:

1. Confirm `Process.clock_gettime(Process::CLOCK_MONOTONIC)` works — required by every
   benchmark via the harness.
2. Check `StringScanner` availability if `ruby-json/benchmark.rb` is desired.
3. All Tier 1 benchmarks should otherwise run without further changes.

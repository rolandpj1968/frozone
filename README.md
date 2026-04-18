<p align="center">
  <img src="docs/frozone.jpg" alt="Frozone" width="200">
</p>

# Frozone

A Ruby VM implemented in Ruby — and an AoT compiler from Ruby to native binaries via [Crystal](https://crystal-lang.org/).

The goal of Frozone is to explore the opportunity of a **two-phase approach**: let a full-featured interpreter handle the dynamic load phase (metaprogramming, `require`s, runtime-computed constants), then compile the settled, closed-world result to efficient native code.

## Two Modes

**Interpreter:** parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. Pure tree-walking interpreter targeting Ruby 4.0 semantics. An alternative pure-Ruby parser front-end (`--parser=wq`) uses a [fork of whitequark/parser](https://github.com/rolandpj1968/parser) updated for Ruby 4.0, making the interpreter pure Ruby end-to-end (no C extensions required).

**Compiler:** snapshots the settled VM state after the interpreter's load phase and emits Crystal source, which compiles to a native binary. Metaprogramming, `require`s, and constants are resolved by the interpreter; the compiler sees a fully settled world.

## Status (v4.0.4)

**Interpreter** spec compliance (ruby/spec run through the Frozone tree-walking interpreter):

| | Passing | Total | Rate |
|---|---:|---:|---:|
| ruby/spec language | 2615 | 2630 | 99.4% |
| ruby/spec core | 22708 | 22913 | 99.1% |
| ruby/spec library | 1979 | 2467 | 80% |
| RSpec unit tests | 649 | 649 | 100% |

**Self-hosting:** Frozone runs itself (Frozone²) with no shims or special infrastructure. The full language spec suite passes through Frozone² with identical results. See [docs/self-hosting.md](docs/self-hosting.md).

See [docs/spec-status.md](docs/spec-status.md) for detailed breakdowns, [docs/interpreter.md](docs/interpreter.md) for VM architecture, [docs/compilation.md](docs/compilation.md) for the AoT compiler.

### Compiler Benchmarks

Apples-to-apples wall-clock time (identical workload, Ruby 4.0.1, Crystal `--release`):

| Benchmark | Frozone | MRI | YJIT | vs MRI | vs YJIT |
|-----------|---------|-----|------|--------|---------|
| loops\_times | 13 ms | 836 ms | 266 ms | **65×** | **21×** |
| nbody ×100 | 117 ms | 7293 ms | 2684 ms | **62×** | **23×** |
| matmul(200) ×20 | 260 ms | 7530 ms | 3071 ms | **29×** | **12×** |
| nqueens 500×12 | 6661 ms | 199000 ms | 49500 ms | **30×** | **7.4×** |
| fib(35) ×3 | 95 ms | 2347 ms | 318 ms | **25×** | **3.3×** |
| sudoku ×20 | 438 ms | 7466 ms | 2015 ms | **17×** | **4.6×** |
| structaref ×850 | 1100 ms | 113000 ms | 10619 ms | **103×** | **10×** |
| blurhash ×10 | 242 ms | 2480 ms | 1050 ms | **10×** | **4.3×** |
| str\_concat ×100 | 992 ms | 5276 ms | 2078 ms | **5.3×** | **2.1×** |
| binarytrees ×60 | 1993 ms | 16586 ms | 6456 ms | **8.3×** | **3.2×** |
| fannkuchredux ×10 | 849 ms | 3171 ms | 3104 ms | **3.7×** | **3.7×** |
| splay ×200 | 14313 ms | 19963 ms | 14400 ms | **1.4×** | **1.0×** |

All benchmarks compile and run end-to-end (AOT → Crystal → native binary). **All 12 timed benchmarks now meet or beat YJIT.** Splay was the only laggard last cycle (36.6s vs YJIT's 14.4s); a 4-step allocator pass — UTF-8 scrub skip, literal symbol fold, small-integer interning, literal-array hoisting — closed the gap entirely. Splay is now within noise of YJIT.

structaset (`TheClass = Struct.new(:v0, :v1, :v2, :levar)`) was a long-standing build failure: Frozone's Struct subclass machinery uses `define_method` blocks (`Vm::DefinedMethod`) which the codegen couldn't emit. Now resolved by synthesising a plain Crystal class with positional initialize and per-member accessors directly from the class's `@members` ivar. End-to-end functional; not yet in the headline table because it's still slower than YJIT (79s vs 33s) on the per-iteration boxing path.

Key compiler features: whole-program type inference with 1-CFA constructor specialisation, `emit_raw_expr` boxing-free typed overloads, class-typed parameter devirtualisation, native `Array(Int64)`/`Array(Float64)` ivar and constant promotion, compile-time `respond_to?`/`is_a?` folding, and kwargs in typed overloads. See [docs/compilation.md](docs/compilation.md) for architecture.

### C++ Backend

A parallel C++ backend shares the same **TypeInference** engine as Crystal.
Invoked via `FROZONE_CPP=1 bundle exec ruby frozone.rb --aot <script>`.
**20 of 24 benchmarks** pass end-to-end on the shared TI (no ad-hoc type
inference). Output lives in `cpp/gen/`, built with `g++ -O2 -std=c++20`.

The C++ backend uses a **pointer-based object model**: user classes inherit
from `RubyObject` (matching Ruby's class hierarchy rooted at `BasicObject`),
objects are heap-allocated raw pointers (nil = nullptr), and Ruby's reference
semantics come for free. No `shared_ptr`, no refcount traffic. Memory
management via Boehm GC (opt-in) or the [Dustman](https://github.com/rolandpj1968/dustman)
precise collector (in development).

| Bench | C++ | Crystal | Winner |
|-------|----:|--------:|--------|
| fib | 0.04s | 0.09s | **C++ 2.6×** |
| matmul | 0.08s | 0.25s | **C++ 3.1×** |
| nbody | 0.11s | 0.12s | **C++ 1.1×** |
| nqueens | 5.89s | 6.57s | **C++ 1.1×** |
| sudoku | 0.007s | 0.42s | **C++ 60×** |
| binarytrees | 4.18s | 2.00s | Crystal 2.1× |
| str_concat | 2.89s | 0.99s | Crystal 2.9× |

C++ wins compute-heavy (no type-system translation tax). Crystal wins
allocation-heavy (Boehm GC amortises better). Both backends beat YJIT on
every compute benchmark. See [docs/cpp-backend.md](docs/cpp-backend.md)
for architecture and the full benchmark table.

### AoT Compilation

```bash
# Explicit compile block
bundle exec ruby frozone.rb bench/stubs/fib.rb
# => Frozone.compile!: wrote crystal/fib.cr

# --aot mode: auto-detect load/execute boundary (no source modification needed)
bundle exec ruby frozone.rb --aot -r bench/test_harness.rb bench/specs/language_spec_small.rb
# => Frozone.compile!: wrote crystal/language_spec_small.cr

# Compile and run
cd crystal && crystal build fib.cr --release -o fib && ./fib
```

## Quick Start

```bash
# Prerequisites: Ruby 4.0.1 (rbenv install 4.0.1)
git clone --recursive https://github.com/rolandpj1968/frozone.git
cd frozone && bundle install

# Run
bundle exec ruby frozone.rb -e "puts 'hello from Frozone'"

# Test
bundle exec rspec                        # unit tests
bundle exec rake language                # ruby/spec language suite
bundle exec rake core                    # ruby/spec core suite
```

## Documentation

**Interpreter:**
- [docs/interpreter.md](docs/interpreter.md) — VM architecture, parsers
- [docs/self-hosting.md](docs/self-hosting.md) — Frozone², Frozone³, pure-Ruby path, performance
- [docs/spec-status.md](docs/spec-status.md) — detailed ruby/spec results (interpreter)

**Compiler:**
- [docs/compilation.md](docs/compilation.md) — AoT compiler architecture, type inference, benchmarks
- [docs/cpp-backend.md](docs/cpp-backend.md) — C++ backend: pointer-based object model, shared TI, Boehm GC
- [docs/cpp-object-model.md](docs/cpp-object-model.md) — C++ object model design (RubyBasicObject hierarchy)
- [docs/type-lattice.md](docs/type-lattice.md) — formal type lattice specification
- [docs/optimisations.md](docs/optimisations.md) — per-optimization flag reference
- [docs/gc-design.md](docs/gc-design.md) — GC design: Immix, TLABs, generational, precise collection
- [docs/perf-suite.md](docs/perf-suite.md) — benchmark suite and dual-backend performance data

## Architecture

```
lib/frozone/vm/          VM runtime (ClassObject, Method, Frame, Context, intrinsics)
lib/frozone/ast/         AST nodes evaluated by the tree-walker
lib/frozone/compiler/    AoT compiler (Codegen, TypeInference, CrystalEmitter, CppEmitter)
lib/frozone/vm/parser.rb Prism-based front-end
lib/frozone/vm/wq_parser.rb  whitequark parser front-end (self-hostable path)
lib/core/4.0/            Ruby stdlib in Ruby — parsed at VM startup, compilable as user code
crystal/src/             Crystal runtime (RubyObject, RubyInteger, RubyString, etc.)
cpp/runtime/frozone.hpp  C++ runtime (RubyBasicObject, RubyObject, RubyString, etc.)
cpp/gen/                 Generated C++ source files
bench/stubs/             Compilation stubs for benchmarks
bench/specs/             Compilable spec files
spec/                    RSpec unit tests + ruby-spec integration
```

## Acknowledgements

Frozone builds on the shoulders of several projects and people:

- **[Natalie](https://github.com/natalie-lang/natalie)** — a Ruby implementation that compiles to C++. Natalie demonstrated that a full Ruby implementation could target a compiled language, and its architecture was a key inspiration for Frozone's two-phase (interpret-then-compile) approach.
- **[Chris Coetzee](https://github.com/chriscz)** (`chriscz`) — for the insight that [Crystal](https://crystal-lang.org/) is a better compilation target than C++ for a Ruby compiler. Crystal's Ruby-like syntax and type system make the generated code readable and the type mapping natural, which proved essential for debugging and iterating on the compiler.
- **[Crystal](https://crystal-lang.org/)** — the compilation backend. Crystal's type inference, union types, and struct value types make it an ideal target for ahead-of-time Ruby compilation.
- **[Prism](https://github.com/ruby/prism)** — Ruby's official parser, used as Frozone's primary front-end.
- **[whitequark/parser](https://github.com/whitequark/parser)** ([Frozone fork](https://github.com/rolandpj1968/parser)) — alternative pure-Ruby parser enabling self-hosting without C extensions.

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

Two AOT backends: **Crystal** (24/24 passing, Boehm GC) and **C++** (20/24 passing, pointer-based object model). Both share the same TypeInference engine.

| Benchmark | Crystal | C++ | MRI | YJIT | Best/MRI | Best/YJIT |
|-----------|--------:|----:|----:|-----:|---------:|----------:|
| fib(35) ×3 | 94 | **37** | 2326 | 501 | **63×** | **14×** |
| matmul(200) ×20 | 256 | **82** | 7355 | 2897 | **90×** | **35×** |
| nbody ×100 | **116** | 110 | 7259 | 2644 | **66×** | **24×** |
| nqueens 500×12 | 6566 | **5890** | 198033 | 49711 | **34×** | **8.4×** |
| loops\_times | **123** | 96 | 8675 | — | **90×** | — |
| sudoku ×20 | 418 | **7** | 7151 | 1928 | **1021×** | **276×** |
| blurhash ×10 | **246** | 241 | 2504 | 1057 | **10×** | **4.4×** |
| fannkuchredux ×10 | 857 | **102** | 3217 | 3161 | **32×** | **31×** |
| binarytrees ×60 | **2000** | 4177 | 16244 | 6916 | **8.1×** | **3.5×** |
| str\_concat ×100 | **992** | 2894 | 5248 | 4502 | **5.3×** | **4.5×** |
| splay ×200 | **13835** | 15231 | 20349 | 13417 | **1.5×** | **1.0×** |

All times in wall-clock milliseconds. **Both backends beat YJIT on every compute benchmark.** C++ wins compute-heavy (fib 63× MRI, sudoku 1021× MRI); Crystal wins allocation-heavy (Boehm GC amortises better than C++'s current allocator).

The C++ backend uses a **pointer-based object model**: user classes inherit
from `RubyObject` (matching Ruby's `BasicObject` hierarchy), objects are
heap-allocated raw pointers (nil = nullptr), no refcount traffic. Memory
management via Boehm GC (opt-in) or [Dustman](https://github.com/rolandpj1968/dustman)
(a standalone precise Immix GC, in development).

See [docs/cpp-backend.md](docs/cpp-backend.md) for C++ architecture,
[docs/perf-suite.md](docs/perf-suite.md) for the full benchmark table with
all 24 benchmarks including micro-benchmarks.

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

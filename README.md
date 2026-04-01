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
| fib(35) ×3 | 139 ms | 2347 ms | 318 ms | **17×** | **2.3×** |
| sudoku ×20 | 430 ms | 7466 ms | 2015 ms | **17×** | **4.7×** |
| matmul(200) ×20 | 248 ms | 7530 ms | 3071 ms | **30×** | **12×** |
| binarytrees ×60 | 2285 ms | 16586 ms | 7225 ms | **7.3×** | **3.2×** |
| loops\_times | 14 ms | 836 ms | 266 ms | **60×** | **19×** |
| fannkuchredux ×10 | 3773 ms | 3171 ms | 3194 ms | 0.8× | **0.8×** |
| splay ×200 | 35130 ms | 19963 ms | 13923 ms | 0.6× | 0.4× |
| blurhash ×10 | 7057 ms | 2480 ms | 1050 ms | 0.4× | 0.1× |

26 of 26 yjit-bench benchmarks compile to Crystal. The table above shows the 8 with matched iteration harnesses for apples-to-apples comparison; the remaining 18 (getivar, setivar, attr\_accessor, keyword\_args, object\_new, etc.) are micro-benchmarks that complete in <5 ms — too fast to meaningfully time against MRI's ~30 ms startup overhead. 5 benchmarks faster than YJIT; fannkuchredux at parity (native Array(Int64) from Range#to\_a promotion).

Key compiler features: whole-program type inference with array element propagation from `<<`/push, nested `Array(Array(T))` promotion, compile-time `respond_to?`/`is_a?` folding, symbol-indexed `respond_to?` dispatch, and typed method overloads with Crystal tuple multi-return. See [docs/compilation.md](docs/compilation.md) for architecture.

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
- [docs/optimisations.md](docs/optimisations.md) — per-optimization flag reference

## Architecture

```
lib/frozone/vm/          VM runtime (ClassObject, Method, Frame, Context, intrinsics)
lib/frozone/ast/         AST nodes evaluated by the tree-walker
lib/frozone/compiler/    AoT compiler (Codegen, TypeInference, CrystalEmitter, CrystalTypeMapper)
lib/frozone/vm/parser.rb Prism-based front-end
lib/frozone/vm/wq_parser.rb  whitequark parser front-end (self-hostable path)
lib/core/4.0/            Ruby stdlib in Ruby — parsed at VM startup, compilable as user code
crystal/src/             Crystal runtime (RubyObject, RubyInteger, RubyString, etc.)
bench/stubs/             Compilation stubs for benchmarks
bench/specs/             Compilable spec files
spec/                    RSpec unit tests + ruby-spec integration
```

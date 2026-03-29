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

Measured on Ruby 4.0.1 vs Crystal `--release` build (same workload per benchmark):

| Benchmark | MRI | YJIT | Frozone→Crystal | vs MRI | vs YJIT |
|-----------|-----|------|-----------------|--------|---------|
| fib(20) | 0.87 ms | 0.53 ms | 0.04 ms | **22×** | **13×** |
| nqueens(8) | 0.87 ms | 1.31 ms | 0.05 ms | **17×** | **26×** |
| nbody 20k | 167 ms | 58 ms | 1.76 ms | **95×** | **33×** |
| matmul(200) | 581 ms | 272 ms | 21.3 ms | **27×** | **13×** |
| getivar 50K | 0.28 ms | 0.28 ms | 0.01 ms | **28×** | **28×** |
| setivar 50K | 0.27 ms | 0.25 ms | <0.01 ms | **>27×** | **>25×** |
| attr\_accessor | 0.72 ms | 0.72 ms | 0.01 ms | **72×** | **72×** |
| loops\_times | 791 ms | 196 ms | 10.9 ms | **73×** | **18×** |
| binarytrees(14) | 292 ms | 115 ms | 31 ms | **9.4×** | **3.7×** |
| keyword\_args | 1.0 ms | 2.2 ms | 1.97 ms | 0.5× | 1.1× |
| gcbench | 1751 ms | 558 ms | 158 ms | **11×** | **3.5×** |
| respond\_to | 162 ms | 15 ms | 0.3 ms | **540×** | **50×** |
| ruby-xor | 97 ms | 19 ms | 53 ms | **1.8×** | 0.4× |
| fannkuchredux | 311 ms | 311 ms | 176 ms | **1.8×** | **1.8×** |
| blurhash | 234 ms | 102 ms | 662 ms | 0.4× | 0.2× |
| splay | 87 ms | 60 ms | 179 ms | 0.5× | 0.3× |

22 compiled benchmarks. `respond_to?` uses compile-time constant folding (closed-world method lookup resolved at compile time). See [docs/compilation.md](docs/compilation.md) for architecture.

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

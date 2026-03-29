# Frozone

A Ruby VM implemented in Ruby — and an AOT compiler from Ruby to native binaries via [Crystal](https://crystal-lang.org/).

## Two Modes

**Interpreter:** parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. Pure tree-walking interpreter targeting Ruby 4.0 semantics.

**Compiler:** snapshots the settled VM state after the interpreter's load phase and emits Crystal source, which compiles to a native binary. Metaprogramming, `require`s, and constants are resolved by the interpreter; the compiler sees a fully settled world.

## Status (v4.0.2)

**Interpreter** spec compliance (ruby/spec run through the Frozone tree-walking interpreter):

| | Passing | Total | Rate |
|---|---:|---:|---:|
| ruby/spec language | 2615 | 2630 | 99.4% |
| ruby/spec core | 22708 | 22913 | 99.1% |
| ruby/spec library | 1979 | 2467 | 80% |
| RSpec unit tests | 649 | 649 | 100% |

See [docs/spec-status.md](docs/spec-status.md) for detailed breakdowns.

### Compiler Benchmarks

Numeric/accessor/tree benchmarks compiled to Crystal are **3.7-95x faster than YJIT**:

| Benchmark | vs MRI | vs YJIT |
|-----------|--------|---------|
| fib(20) | 22x | 13x |
| nbody 20k | 95x | 33x |
| attr_accessor | 72x | 72x |
| loops_times | 73x | 18x |
| nqueens(8) | 17x | 26x |
| binarytrees(14) | 9.4x | 3.7x |

22 compiled benchmarks total. See [docs/compilation.md](docs/compilation.md) for full results and architecture.

### AOT Compilation

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

- [docs/compilation.md](docs/compilation.md) — AOT compiler architecture, type inference, benchmarks
- [docs/optimisations.md](docs/optimisations.md) — per-optimization flag reference
- [docs/spec-status.md](docs/spec-status.md) — detailed ruby/spec results
- [docs/interpreter.md](docs/interpreter.md) — VM architecture, parsers, self-hosting

## Architecture

```
lib/frozone/vm/          VM runtime (ClassObject, Method, Frame, Context, intrinsics)
lib/frozone/ast/         AST nodes evaluated by the tree-walker
lib/frozone/compiler/    AOT compiler (SnapshotCodegen, TypeInference, CrystalCodegen)
lib/frozone/vm/parser.rb Prism-based front-end
lib/frozone/vm/wq_parser.rb  whitequark parser front-end (self-hostable path)
lib/core/4.0/            Ruby stdlib in Ruby — parsed at VM startup, compilable as user code
crystal/src/             Crystal runtime (RubyObject, RubyInteger, RubyString, etc.)
bench/stubs/             Compilation stubs for benchmarks
bench/specs/             Compilable spec files
spec/                    RSpec unit tests + ruby-spec integration
```

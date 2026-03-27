# Frozone

A Ruby VM implemented in Ruby — and an AOT compiler from Ruby to native binaries via [Crystal](https://crystal-lang.org/).

**Interpreter:** parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

**Compiler:** `Frozone.compile!` snapshots the settled VM state after the load phase and emits Crystal source, which is then compiled to a native binary. The load/execute split is explicit — metaprogramming, `require`s, and runtime-computed constants are all resolved by the interpreter before compilation begins.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2615/2630** ruby/spec language examples,
including full pattern matching support.

Core library spec coverage: **22805/23020 passing (99.0%)** — all modules now measured;
`io`, `process` have OS-level gaps; `mutex`/`thread` use cooperative scheduling with some edge-case gaps;
`tracepoint` is intentionally unimplemented (deep introspection, low priority);
hanging/blocking specs excluded via `SKIP_SPEC_FILES` in `Rakefile`.

### Frozone² — Self-hosting (sort of)

Frozone can run itself:

```
bundle exec ruby frozone.rb --parser=wq frozone.rb --parser=wq -e "puts 'hello from frozone²'"
# => hello from frozone²
```

Works with both parsers (Prism is the default):

```
bundle exec ruby frozone.rb frozone.rb -e "puts 'hello from frozone²'"
# => hello from frozone²
```

**The cheat:** when `frozone.rb` loads inside the outer Frozone, the inner
`Frozone::Vm::Vm` class is replaced by a thin proxy that routes all evaluation
back to the outer Frozone's own MRI-backed evaluator via a `kernel_run_vm`
intrinsic. All Frozone source files are pre-stubbed in the inner Frozone's
`$LOADED_FEATURES` so `require` calls inside Frozone's own code are no-ops —
the inner Frozone never actually loads `lib/core/4.0/` or its own VM
infrastructure. The inner `frozone.rb` detects it is running inside Frozone via
`RUBY_DESCRIPTION.start_with?('frozone')` (`$is_inner = true`) and skips
AstCache initialization.

In effect, Frozone² is the outer Frozone's evaluator wearing a thin Frozone-land
costume. True self-hosting — where the inner Frozone runs its own AST evaluator
on its own class objects, with all core methods implemented in pure Frozone-Ruby
— would require the core library (`String`, `Array`, `Hash`, …) to be fully
de-intrinsified. That is the goal of the ongoing de-intrinsification work.

### AOT Compilation to Crystal

`Frozone.compile!` is the AOT compilation hook. A bench stub looks like this:

```ruby
# bench/stubs/matmul.rb
$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end          # silence harness during load phase
require_relative '../benchmarks/matmul'   # settles methods and constants

Frozone.compile! do
  run_benchmark(20) do
    a = matgen(N)
    b = matgen(N)
    _c = matmul(a, b)
  end
end
```

Running this through the Frozone interpreter:

```bash
bundle exec ruby frozone.rb bench/stubs/matmul.rb
# => Frozone.compile!: wrote crystal/matmul.cr
```

Then compile and run natively:

```bash
cd crystal && crystal build matmul.cr -o matmul && ./matmul
# => 2758.19 ms/iter
```

**How it works:**

1. The interpreter runs the *load phase* normally — class definitions, `require`s, and constant assignments settle into the VM's object model.
2. When `Frozone.compile!` is reached, the block is **not** evaluated. Instead, `SnapshotCodegen` walks the settled VM state (method tables, constant table) and emits Crystal source.
3. User-defined methods and constants are identified by `source_location` — everything from `lib/core/4.0/` and `lib/frozone/` is excluded (it maps to the Crystal runtime in `crystal/src/`).
4. The block body becomes the Crystal `main` — the execute phase.

The Crystal runtime (`crystal/src/`) provides `RubyObject`, `RubyInteger`, `RubyFloat`, `RubyString`, `RubyArray`, `RubyHash`, etc. as value types with full operator dispatch. Type inference specialises numeric-heavy inner loops to raw Crystal arithmetic, eliminating boxing overhead.

### Benchmark Results

Measured on Ruby 4.0.1 vs Crystal `--release` build (same workload per benchmark):

| Benchmark | MRI | YJIT | Frozone→Crystal | vs MRI | vs YJIT |
|-----------|-----|------|-----------------|--------|---------|
| fib(20) | 0.87 ms | 0.53 ms | 0.03 ms | **29×** | **18×** |
| nqueens(8) | 0.87 ms | 1.31 ms | 0.08 ms | **11×** | **16×** |
| nbody 20k | 167 ms | 58 ms | 1.11 ms | **150×** | **52×** |
| matmul(200) | 581 ms | 272 ms | 14.3 ms | **41×** | **19×** |
| getivar 50K | 0.28 ms | 0.28 ms | 0.01 ms | **28×** | **28×** |
| setivar 50K | 0.27 ms | 0.25 ms | <0.01 ms | **>27×** | **>25×** |
| binarytrees(14) | 292 ms | 115 ms | 278 ms | 1.1× | 0.4× |
| loops\_times | 791 ms | 196 ms | 366 ms | **2.2×** | 0.5× |
| attr\_accessor | 0.72 ms | 0.72 ms | 1.28 ms | 0.6× | 0.6× |
| keyword\_args | 1.0 ms | 2.2 ms | 3.14 ms | 0.3× | 0.7× |
| splay | 87 ms | 60 ms | 180 ms | 0.5× | 0.3× |

**Pure arithmetic** (fib, nqueens, nbody, matmul, getivar, setivar) is fully specialised to raw Crystal types — 10–150× faster than MRI. **Object-heavy** benchmarks (splay, binarytrees, attr\_accessor, keyword\_args) go through `RubyObject` polymorphic dispatch and are currently slower than YJIT; these show where the Crystal runtime needs optimisation (inlining accessors, devirtualising monomorphic call sites, etc.).

### Parsers

Frozone ships two independent front-ends that produce the same AST:

| Parser | Gem | Status |
|--------|-----|--------|
| **Prism** (default) | `prism` (Ruby stdlib) | 2620/2630 — 3F 7E |
| **WqParser** (`--parser=wq`) | `parser` gem (whitequark/parser fork) | ~2618/2630 — similar |

Switch parsers with `PARSER=wq bundle exec rake language` or `--parser=wq` on the CLI.

The WqParser uses a [fork of whitequark/parser](https://github.com/rolandpj1968/parser) that adds Ruby 4.0 parsing support (the upstream gem targets Ruby 3.x only).

The WqParser's two extra errors are fundamental whitequark lexer limitations:
- `mod::ἍBB` — non-ASCII uppercase identifiers are not recognised as constants (the whitequark lexer is ASCII-only; Prism uses Ruby's own Unicode-aware lexer)
- The same `-e` magic-comment edge case as Prism

Both parsers are otherwise at full parity on the language spec suite.

## Setup

### Prerequisites

- **Ruby 4.0.1** — the `.ruby-version` file pins this. Install via [rbenv](https://github.com/rbenv/rbenv) or your preferred version manager:
  ```bash
  rbenv install 4.0.1
  ```

### Clone

The repo has two submodules:
- `spec/ruby-spec` — the [ruby/spec](https://github.com/ruby/spec) test suite
- `vendor/parser` — a [fork of whitequark/parser](https://github.com/rolandpj1968/parser) with Ruby 4.0 parsing support

Clone with `--recursive` to get both:

```bash
git clone --recursive https://github.com/rolandpj1968/frozone.git
cd frozone
```

If you already cloned without `--recursive`:
```bash
git submodule update --init --recursive
```

### Install gems

```bash
bundle install
```

### Smoke test

```bash
bundle exec ruby frozone.rb -e "puts 'hello from Frozone'"
# => hello from Frozone
```

### Running specs

```bash
bundle exec rspec                        # 652 RSpec unit tests (0 failures)
bundle exec rake language                # ruby/spec language suite (~2630 examples)
bundle exec rake core                    # ruby/spec core suite (~22000 examples, parallel)
bundle exec rake language:NAME           # single language spec, e.g. rake language:string
bundle exec rake core:NAME               # single core spec, e.g. rake core:array
```

Switch to the WqParser front-end with `--parser=wq` or `PARSER=wq`:
```bash
PARSER=wq bundle exec rake language
bundle exec ruby frozone.rb --parser=wq -e "puts 'hello'"
```

### Architecture

- **`lib/frozone/vm/`** — VM runtime: `ClassObject`, `ModuleObject`, `Method`, `Frame`, `Context`, intrinsics
- **`lib/frozone/ast/`** — AST node types evaluated by the tree-walker
- **`lib/frozone/vm/parser.rb`** — Prism-based front-end
- **`lib/frozone/vm/wq_parser.rb`** — whitequark `parser`-based front-end (self-hostable path)
- **`lib/core/4.0/`** — Ruby standard library implemented in Ruby, parsed at VM startup

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Prism parser: 2615 / 2630 passing** — as of 2026-03-24 (v4.0.1)

Specs with 100% pass rate:
`alias`, `and`, `array`, `assignments`, `BEGIN`, `block`, `break`, `case`, `class`,
`comment`, `constants`, `defined`, `def`, `delegation`, `encoding`, `END`, `ensure`,
`file`, `for`, `hash`, `heredoc`, `if`, `it_parameter`, `keyword_arguments`,
`lambda`, `line`, `loop`, `match`, `metaclass`, `method`, `module`, `next`, `not`,
`numbered_parameters`, `numbers`, `optional_assignments`, `order`, `or`,
`precedence`, `private`, `proc`, `range`, `redo`, `regexp`, `rescue`,
`reserved_keywords`, `retry`, `return`, `safe_navigator`, `safe`, `send`,
`singleton_class`, `source_encoding`, `string`, `super`, `symbol`, `throw`,
`undef`, `unless`, `until`, `variables`, `while`, `yield`

Remaining failures:

| Spec | Result | Notes |
|------|--------|-------|
| magic_comment | 10 failures | stdin magic comment tests (no stdin support in spec runner) |
| class_variable | 1 failure | class variable overtaken in ancestor edge case |
| execution | 1 failure | `$LOAD_PATH` sitelibdir `@gem_prelude_index` |
| predefined | 1 failure | `$LOAD_PATH.resolve_feature_path` for `.so` files |
| pattern_matching | 3 errors | refinements + deconstruct edge cases |

**WqParser:** similar pass rate (2 additional errors for non-ASCII constant lexing)

Switch parsers with `PARSER=wq bundle exec rake language` or `--parser=wq` on the CLI.

WqParser-specific differences (whitequark lexer limitations):

| Spec | Prism | WqParser | Notes |
|------|-------|----------|-------|
| constants | 100/100 | 99/100 | `mod::ἍBB` — non-ASCII uppercase not lexed as constant |

## ruby/spec Core Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) core specs.
Run with `bundle exec rake core` (or `rake core:NAME` for a single module).
Core specs run in parallel (`JOBS=N`, default: nprocessors).

**Overall: 22708 / 22913 passing (99.1%)** — as of 2026-03-27 (Prism parser; slow modules run individually)

`tracepoint` intentionally unimplemented (deep VM introspection; moot before compilation).

Hanging specs (blocking IO, threading primitives, GC-dependent) are excluded via `SKIP_SPEC_FILES` in `Rakefile`.
`io` has partial coverage due to blocking/pipe spec exclusions.

Modules with 100% pass rate:
`array`, `basicobject`, `binding`, `builtin_constants`, `class`, `comparable`, `complex`, `conditionvariable`, `data`, `dir`,
`encoding`, `enumerable`, `enumerator`, `env`, `exception`, `false`, `fiber`, `filetest`, `float`, `gc`,
`hash`, `integer`, `main`, `marshal`, `matchdata`, `math`, `method`, `mutex`, `nil`, `numeric`,
`objectspace`, `proc`, `queue`, `random`, `range`, `rational`, `regexp`, `set`,
`signal`, `string`, `struct`, `symbol`, `systemexit`, `threadgroup`, `time`, `true`, `unboundmethod`, `warning`

| Module | Examples | Passing | Failures | Errors | Notes |
|---|---:|---:|---:|---:|---|
| argf | 148 | 12 | 10 | 126 | ARGF not fully implemented |
| file | 940 | 935 | 0 | 5 | OS-level file ops; socket specs need io/wait C ext |
| io | 1048 | 1036 | 3 | 9 | blocking/pipe/buffer specs skipped; OS-level gaps |
| kernel | 2741 | 2718 | 17 | 6 | spawn, format edge cases; require/require_relative symlinks fixed |
| module | 1058 | 1051 | 7 | 0 | |
| process | 86 | 44 | 0 | 42 | OS-level process ops |
| refinement | 25 | 24 | 0 | 1 | |
| sizedqueue | 21 | 20 | 1 | 0 | blocking specs excluded (hang under cooperative scheduling) |
| thread | 227 | 220 | 7 | 0 | cooperative threading; remaining edge cases |
| tracepoint | 75 | — | 5 | 71 | intentionally unimplemented |

## ruby/spec Library Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) library specs.
Run with `bundle exec rake library` (or `rake library:NAME` for a single module).

**Overall: 1979 / 2467 passing (80%)** — as of 2026-03-27 (Prism parser)

Many modules report 0 examples because they require C extensions or unavailable gems.
`getoptlong`, `irb`, `mkmf`, `objectspace`, `prime` timed out in the parallel runner.
`delegate` has hanging specs excluded via `SKIP_LIBRARY_SPEC_FILES` in `Rakefile`.

### Modules with 0 examples

| Category | Modules |
|---|---|
| **C extensions** (`.so` not loadable) | bigdecimal, fiddle, ipaddr, net-http, openssl, resolv, ripper, socket, syslog, win32ole, yaml, zlib |
| **Pure-Ruby stdlib gems** (not bundled) | drb, net-ftp, openstruct |
| **Platform/version guards** | readline (`with_feature :readline`) |

Modules with 100% pass rate:
`abbrev`, `base64`, `English`, `expect`, `find`, `logger`, `matrix`, `observer`, `optionparser`, `pathname`, `pp`,
`random`, `rbconfig`, `securerandom`, `shellwords`, `singleton`, `stringscanner`, `time`, `tmpdir`, `uri`, `weakref`

| Module | Examples | Passing | Failures | Errors | Notes |
|---|---:|---:|---:|---:|---|
| cgi | 43 | 38 | 3 | 2 | partial C extension dependency |
| coverage | 10 | — | 1 | 52 | Coverage module not implemented |
| csv | 33 | 32 | 1 | 0 | |
| date | 295 | 59 | 65 | 171 | date_core C extension; partial pure-Ruby support |
| datetime | 114 | 38 | 2 | 74 | date_core C extension; partial pure-Ruby support |
| delegate | 68 | 66 | 2 | 0 | |
| digest | 7 | — | 5 | 3 | C extension (SHA/MD5) |
| erb | 53 | 49 | 0 | 4 | partial C extension dependency |
| etc | 39 | 3 | 6 | 30 | C extension |
| io-wait | 28 | 3 | 5 | 20 | IO wait/nonblock not implemented |
| monitor | 12 | 6 | 2 | 4 | cooperative threading edge cases |
| open3 | 4 | 0 | 0 | 4 | subprocess piping |
| rubygems | 2 | 0 | 0 | 2 | |
| stringio | 670 | 668 | 0 | 2 | 2 unavoidable errors (getch/getpass need `io/console` C extension) |
| tempfile | 46 | 24 | 5 | 17 | temp file/dir race conditions |
| thread | 2 | 0 | 2 | 0 | threading primitives |
| timeout | 7 | 3 | 0 | 4 | |

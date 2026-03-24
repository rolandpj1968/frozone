# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2615/2630** ruby/spec language examples,
including full pattern matching support.

Core library spec coverage: **20449/20886 passing (97.9%)** — excluding timed-out modules;
`io`, `process`, `mutex` still have failures (concurrency/OS-level features);
`tracepoint` is intentionally unimplemented (deep introspection, low priority);
`argf`, `conditionvariable`, `integer`, `io`, `numeric`, `thread` timed out in parallel runner.

### Frozone² — Self-hosting (sort of)

Frozone can run itself:

```
bundle exec ruby frozone.rb --parser=wq frozone.rb --parser=wq -e "puts 'hello from frozone²'"
# => hello from frozone²
```

**The cheat:** when `frozone.rb` loads inside the outer Frozone, the inner
`Frozone::Vm::Vm` class is replaced by a thin proxy that routes all evaluation
back to the outer Frozone's own MRI-backed evaluator via a `kernel_run_vm`
intrinsic. All Frozone source files are pre-stubbed in the inner Frozone's
`$LOADED_FEATURES` so `require` calls inside Frozone's own code are no-ops —
the inner Frozone never actually loads `lib/core/4.0/` or its own VM
infrastructure.

In effect, Frozone² is the outer Frozone's evaluator wearing a thin Frozone-land
costume. True self-hosting — where the inner Frozone runs its own AST evaluator
on its own class objects, with all core methods implemented in pure Frozone-Ruby
— would require the core library (`String`, `Array`, `Hash`, …) to be fully
de-intrinsified. That is the goal of the ongoing de-intrinsification work.

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

**Overall: 20449 / 20886 passing (97.9%)** — as of 2026-03-24 (Prism parser, parallel run)

`conditionvariable`, `integer`, `io`, `numeric`, `thread` timed out in parallel runner (excluded from totals).
`tracepoint` intentionally unimplemented (deep VM introspection; moot before compilation).

Modules with 100% pass rate:
`binding`, `builtin_constants`, `class`, `comparable`, `complex`, `data`, `dir`,
`enumerable`, `false`, `float`, `gc`, `hash`, `main`, `marshal`, `matchdata`,
`math`, `method`, `nil`, `proc`, `queue`, `range`, `rational`, `regexp`, `set`,
`signal`, `symbol`, `systemexit`, `threadgroup`, `true`, `warning`

| Module | Examples | Passing | Failures | Errors | Notes |
|---|---:|---:|---:|---:|---|
| argf | 148 | 8 | 10 | 130 | ARGF not fully implemented |
| array | 2961 | 2960 | 0 | 1 | |
| basicobject | 178 | 177 | 1 | 0 | |
| encoding | 631 | 616 | 11 | 4 | transcoding edge cases |
| enumerator | 423 | 422 | 0 | 1 | |
| env | 239 | 237 | 2 | 0 | |
| exception | 248 | 247 | 1 | 0 | |
| fiber | 170 | 160 | 2 | 8 | scheduler/blocking API |
| file | 939 | 933 | 0 | 6 | OS-level file ops |
| filetest | 88 | 87 | 0 | 1 | |
| kernel | 2701 | 2606 | 30 | 65 | I/O, spawn, format edge cases |
| module | 1058 | 1049 | 8 | 1 | |
| mutex | 25 | 16 | 5 | 4 | threading primitives |
| objectspace | 112 | 111 | 1 | 0 | |
| process | 86 | 32 | 12 | 42 | OS-level process ops |
| random | 87 | 84 | 0 | 3 | |
| refinement | 25 | 24 | 0 | 1 | |
| sizedqueue | 129 | 128 | 1 | 0 | |
| string | 3976 | 3974 | 2 | 0 | dedup/interning unimplemented |
| struct | 182 | 181 | 1 | 0 | |
| time | 774 | 773 | 1 | 0 | |
| tracepoint | 75 | — | 5 | 71 | intentionally unimplemented |
| unboundmethod | 86 | 80 | 3 | 3 | |

## ruby/spec Library Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) library specs.
Run with `bundle exec rake library` (or `rake library:NAME` for a single module).

**Overall: 249 / 386 passing** — as of 2026-03-24 (Prism parser)

Many modules report 0 examples because they require C extensions (openssl, bigdecimal, etc.) that Frozone cannot load.
`delegate`, `expect`, `mkmf`, `objectspace`, `stringio`, `weakref` timed out in the parallel runner.

Modules with 100% pass rate:
`find`, `optionparser`, `pp`, `random`, `securerandom`, `shellwords`, `singleton`

| Module | Examples | Passing | Failures | Errors | Notes |
|---|---:|---:|---:|---:|---|
| English | 26 | 25 | 1 | 0 | |
| date | 6 | 0 | 0 | 6 | date gem not available |
| etc | 39 | 2 | 6 | 31 | C extension |
| io-wait | 28 | 3 | 5 | 20 | IO wait/nonblock not implemented |
| open3 | 4 | 0 | 0 | 4 | subprocess piping |
| pathname | 70 | 25 | 21 | 24 | Pathname not fully implemented |
| rbconfig | 16 | 14 | 1 | 1 | |
| rubygems | 2 | 0 | 0 | 2 | |
| thread | 2 | 0 | 2 | 0 | threading primitives |
| time | 8 | 0 | 0 | 8 | time library edge cases |
| timeout | 7 | 3 | 0 | 4 | |
| uri | 97 | 96 | 0 | 1 | |

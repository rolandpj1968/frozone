# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2613/2630** ruby/spec language examples,
including full pattern matching support.

Core library spec coverage: **20912 / 21890 passing (95.5%)** — all modules run;
`io`, `process`, `mutex` still have failures (concurrency/OS-level features);
`tracepoint` is intentionally unimplemented (deep introspection, low priority);
`argf`, `conditionvariable`, `thread` excluded (hang at native level).

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

**Prism parser: 2613 / 2630 passing** — as of 2026-03-24 (v4.0.1)

Pattern matching is now fully implemented. Remaining failures/errors:

| Spec | Result | Notes |
|------|--------|-------|
| class_variable | 1 failure | class variable overtaken in ancestor edge case |
| execution | 1 failure | `$LOAD_PATH` sitelibdir `@gem_prelude_index` |
| predefined | 1 failure | `$LOAD_PATH.resolve_feature_path` for `.so` files |
| magic_comment | 1 error | magic comment in `-e` argument |
| pattern_matching | 5 errors | refinements + deconstruct edge cases |
| source_encoding | 2 errors | UTF-16 BOM with invalid byte sequence |

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

**Overall: 20912 / 21890 passing (95.5%)** — as of 2026-03-24 (Prism parser, parallel run)

`argf`, `conditionvariable`, `thread` excluded from the parallel runner (hang at native level).
`tracepoint` intentionally unimplemented (deep VM introspection; moot before compilation).

| Module | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| argf | (excluded) | — | — | — |
| array | 2925 | 2925 | 0 | 0 |
| basicobject | 178 | 178 | 0 | 0 |
| binding | 58 | 58 | 0 | 0 |
| builtin_constants | 27 | 27 | 0 | 0 |
| class | 54 | 54 | 0 | 0 |
| comparable | 54 | 54 | 0 | 0 |
| complex | 186 | 186 | 0 | 0 |
| conditionvariable | (excluded) | — | — | — |
| data | 92 | 92 | 0 | 0 |
| dir | 151 | 151 | 0 | 0 |
| encoding | 221 | 206 | 11 | 4 |
| enumerable | 574 | 574 | 0 | 0 |
| enumerator | 423 | 422 | 0 | 1 |
| env | 239 | 237 | 2 | 0 |
| exception | 248 | 247 | 1 | 0 |
| false | 13 | 13 | 0 | 0 |
| fiber | 160 | 160 | 0 | 0 |
| file | 939 | 933 | 0 | 6 |
| filetest | 88 | 87 | 0 | 1 |
| float | 328 | 328 | 0 | 0 |
| gc | 41 | 41 | 0 | 0 |
| hash | 633 | 633 | 0 | 0 |
| integer | 603 | 603 | 0 | 0 |
| io | 1009 | 265 | 239 | 505 |
| kernel | 2449 | 2412 | 23 | 14 |
| main | 27 | 27 | 0 | 0 |
| marshal | 713 | 713 | 0 | 0 |
| matchdata | 186 | 186 | 0 | 0 |
| math | 243 | 243 | 0 | 0 |
| method | 223 | 223 | 0 | 0 |
| module | 1058 | 1051 | 6 | 1 |
| mutex | 25 | 16 | 5 | 4 |
| nil | 27 | 27 | 0 | 0 |
| numeric | 338 | 338 | 0 | 0 |
| objectspace | 112 | 112 | 0 | 0 |
| proc | 302 | 302 | 0 | 0 |
| process | 86 | 17 | 18 | 51 |
| queue | 24 | 24 | 0 | 0 |
| random | 87 | 84 | 0 | 3 |
| range | 459 | 459 | 0 | 0 |
| rational | 159 | 159 | 0 | 0 |
| refinement | 25 | 24 | 0 | 1 |
| regexp | 264 | 264 | 0 | 0 |
| set | 179 | 179 | 0 | 0 |
| signal | 52 | 52 | 0 | 0 |
| sizedqueue | 129 | 128 | 1 | 0 |
| string | 3976 | 3976 | 0 | 0 |
| struct | 182 | 181 | 1 | 0 |
| symbol | 330 | 330 | 0 | 0 |
| systemexit | 6 | 6 | 0 | 0 |
| thread | (excluded) | — | — | — |
| threadgroup | 8 | 8 | 0 | 0 |
| time | 774 | 773 | 1 | 0 |
| tracepoint | (unimplemented) | — | — | — |
| true | 13 | 13 | 0 | 0 |
| unboundmethod | 86 | 83 | 0 | 3 |
| warning | 29 | 29 | 0 | 0 |

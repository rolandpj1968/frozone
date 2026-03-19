# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2519/2520** ruby/spec language examples.
Pattern matching is not yet implemented (excluded from the count above).

Core library spec coverage: **16176 / 17482 passing (92.5%)** across 47 of 58 core modules
(11 modules hang indefinitely due to unimplemented Thread/Mutex/IO concurrency primitives).

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
| **Prism** (default) | `prism` (Ruby stdlib) | 2519/2520 — 0F 1E |
| **WqParser** (`--parser=wq`) | `parser` gem (whitequark/parser fork) | 2518/2520 — 0F 2E |

Switch parsers with `PARSER=wq bundle exec rake language` or `--parser=wq` on the CLI.

The WqParser uses a [fork of whitequark/parser](https://github.com/rolandpj1968/parser) that adds Ruby 4.0 parsing support (the upstream gem targets Ruby 3.x only).

The WqParser's two extra errors are fundamental whitequark lexer limitations:
- `mod::ἍBB` — non-ASCII uppercase identifiers are not recognised as constants (the whitequark lexer is ASCII-only; Prism uses Ruby's own Unicode-aware lexer)
- The same `-e` magic-comment edge case as Prism

Both parsers are otherwise at full parity on the language spec suite.

### Architecture

- **`lib/frozone/vm/`** — VM runtime: `ClassObject`, `ModuleObject`, `Method`, `Frame`, `Context`, intrinsics
- **`lib/frozone/ast/`** — AST node types evaluated by the tree-walker
- **`lib/frozone/vm/parser.rb`** — Prism-based front-end
- **`lib/frozone/vm/wq_parser.rb`** — whitequark `parser`-based front-end (self-hostable path)
- **`lib/core/4.0/`** — Ruby standard library implemented in Ruby, parsed at VM startup

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Prism parser: 2519 / 2520 passing** — as of 2026-03-19 (v4.0.1)

All 58 language specs pass perfectly except:

| Spec | Result | Notes |
|------|--------|-------|
| magic_comment | 53/54 (1 error) | magic comment in `-e` argument (not implemented) |
| pattern_matching | excluded | not yet implemented |

**WqParser: 2518 / 2520 passing** — as of 2026-03-19 (v4.0.1)

Switch parsers with `PARSER=wq bundle exec rake language` or `--parser=wq` on the CLI.

Additional WqParser differences (both are whitequark lexer limitations):

| Spec | Prism | WqParser | Notes |
|------|-------|----------|-------|
| constants | 100/100 | 99/100 | `mod::ἍBB` — non-ASCII uppercase not lexed as constant |
| magic_comment | 53/54 | 53/54 | same `-e` edge case as Prism |

## ruby/spec Core Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) core specs.
Run with `bundle exec rake core` (or `rake core:NAME` for a single module).
Core specs run in parallel (`JOBS=N`, default: nprocessors).

**Overall: 16176 / 17482 passing (92.5%)** — as of 2026-03-19 (Prism parser, 47 of 58 modules measured)

Note: Negative "passing" counts indicate errors exceed examples (mspec counts some errors as extra failures).
`(hangs)` = module hangs indefinitely (Thread/Mutex/IO/concurrent primitives not yet implemented).

| Module | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| argf | 105 | -28 | 3 | 130 |
| array | 2925 | 2920 | 5 | 0 |
| basicobject | 178 | 178 | 0 | 0 |
| binding | (hangs) | — | — | — |
| builtin_constants | 27 | 27 | 0 | 0 |
| class | 54 | 54 | 0 | 0 |
| comparable | 54 | 54 | 0 | 0 |
| complex | 186 | 186 | 0 | 0 |
| conditionvariable | 11 | -1 | 2 | 10 |
| data | 92 | 92 | 0 | 0 |
| dir | 338 | 133 | 27 | 178 |
| encoding | 631 | 595 | 25 | 11 |
| enumerable | 574 | 574 | 0 | 0 |
| enumerator | (hangs) | — | — | — |
| env | 239 | 239 | 0 | 0 |
| exception | 248 | 245 | 3 | 0 |
| false | 13 | 13 | 0 | 0 |
| fiber | 163 | 163 | 0 | 0 |
| file | 796 | 465 | 60 | 271 |
| filetest | (hangs) | — | — | — |
| float | 328 | 323 | 5 | 0 |
| gc | 41 | 41 | 0 | 0 |
| hash | 633 | 633 | 0 | 0 |
| integer | 603 | 555 | 48 | 0 |
| io | (hangs) | — | — | — |
| kernel | (hangs) | — | — | — |
| main | 27 | 27 | 0 | 0 |
| marshal | 110 | -3 | 6 | 107 |
| matchdata | 186 | 186 | 0 | 0 |
| math | 243 | 243 | 0 | 0 |
| method | 223 | 223 | 0 | 0 |
| module | 982 | 975 | 2 | 5 |
| mutex | (hangs) | — | — | — |
| nil | 27 | 27 | 0 | 0 |
| numeric | 338 | 338 | 0 | 0 |
| objectspace | 112 | 112 | 0 | 0 |
| proc | 303 | 303 | 0 | 0 |
| process | 205 | 3 | 69 | 133 |
| queue | (hangs) | — | — | — |
| random | 87 | 87 | 0 | 0 |
| range | 459 | 457 | 0 | 2 |
| rational | 159 | 156 | 3 | 0 |
| refinement | (hangs) | — | — | — |
| regexp | 262 | 260 | 2 | 0 |
| set | 179 | 179 | 0 | 0 |
| signal | 52 | 5 | 36 | 11 |
| sizedqueue | (hangs) | — | — | — |
| string | 3976 | 3973 | 3 | 0 |
| struct | (hangs) | — | — | — |
| symbol | 330 | 330 | 0 | 0 |
| systemexit | 6 | 6 | 0 | 0 |
| thread | (hangs) | — | — | — |
| threadgroup | (hangs) | — | — | — |
| time | 772 | 704 | 61 | 7 |
| tracepoint | 75 | -1 | 5 | 71 |
| true | 13 | 13 | 0 | 0 |
| unboundmethod | 86 | 82 | 0 | 4 |
| warning | 31 | 30 | 0 | 1 |

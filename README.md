# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2620/2630** ruby/spec language examples,
including full pattern matching support.

Core library spec coverage: **15587 / 16761 passing (93.0%)** across 49 of 58 core modules
(9 modules time out due to Thread/Mutex/IO concurrency or codec primitives not yet implemented).

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

### Architecture

- **`lib/frozone/vm/`** — VM runtime: `ClassObject`, `ModuleObject`, `Method`, `Frame`, `Context`, intrinsics
- **`lib/frozone/ast/`** — AST node types evaluated by the tree-walker
- **`lib/frozone/vm/parser.rb`** — Prism-based front-end
- **`lib/frozone/vm/wq_parser.rb`** — whitequark `parser`-based front-end (self-hostable path)
- **`lib/core/4.0/`** — Ruby standard library implemented in Ruby, parsed at VM startup

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Prism parser: 2620 / 2630 passing** — as of 2026-03-21 (v4.0.1)

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

**Overall: 15587 / 16761 passing (93.0%)** — as of 2026-03-21 (Prism parser, 49 of 58 modules measured)

Note: Negative "passing" counts indicate errors exceed examples (mspec counts some errors as extra failures).
`(timeout)` = module times out in parallel runner (Thread/Mutex/IO/codec concurrency not yet implemented).

| Module | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| argf | 101 | -36 | 3 | 134 |
| array | 2925 | 2925 | 0 | 0 |
| basicobject | 178 | 176 | 2 | 0 |
| binding | 58 | 56 | 1 | 1 |
| builtin_constants | 27 | 27 | 0 | 0 |
| class | 54 | 54 | 0 | 0 |
| comparable | 54 | 54 | 0 | 0 |
| complex | 186 | 186 | 0 | 0 |
| conditionvariable | 11 | 5 | 3 | 3 |
| data | 92 | 92 | 0 | 0 |
| dir | 21 | -61 | 0 | 82 |
| encoding | (timeout) | — | — | — |
| enumerable | 574 | 572 | 0 | 2 |
| enumerator | (timeout) | — | — | — |
| env | 239 | 239 | 0 | 0 |
| exception | 248 | 240 | 8 | 0 |
| false | 13 | 13 | 0 | 0 |
| fiber | (timeout) | — | — | — |
| file | 465 | -162 | 19 | 608 |
| filetest | 31 | -38 | 0 | 69 |
| float | 328 | 328 | 0 | 0 |
| gc | 41 | 41 | 0 | 0 |
| hash | 633 | 633 | 0 | 0 |
| integer | 603 | 603 | 0 | 0 |
| io | (timeout) | — | — | — |
| kernel | (timeout) | — | — | — |
| main | 27 | 21 | 4 | 2 |
| marshal | 713 | 689 | 12 | 12 |
| matchdata | 186 | 185 | 1 | 0 |
| math | 243 | 243 | 0 | 0 |
| method | 223 | 222 | 1 | 0 |
| module | 980 | 942 | 18 | 20 |
| mutex | 24 | 12 | 10 | 2 |
| nil | 27 | 27 | 0 | 0 |
| numeric | 338 | 338 | 0 | 0 |
| objectspace | 112 | 111 | 1 | 0 |
| proc | 302 | 299 | 3 | 0 |
| process | (timeout) | — | — | — |
| queue | (timeout) | — | — | — |
| random | 87 | 82 | 2 | 3 |
| range | 459 | 459 | 0 | 0 |
| rational | 159 | 159 | 0 | 0 |
| refinement | 25 | 19 | 1 | 5 |
| regexp | 264 | 264 | 0 | 0 |
| set | 179 | 179 | 0 | 0 |
| signal | 52 | 5 | 36 | 11 |
| sizedqueue | (timeout) | — | — | — |
| string | 3976 | 3974 | 1 | 1 |
| struct | 182 | 181 | 1 | 0 |
| symbol | 330 | 330 | 0 | 0 |
| systemexit | 6 | 6 | 0 | 0 |
| thread | (timeout) | — | — | — |
| threadgroup | 8 | 0 | 1 | 7 |
| time | 774 | 771 | 1 | 2 |
| tracepoint | 75 | -1 | 5 | 71 |
| true | 13 | 13 | 0 | 0 |
| unboundmethod | 86 | 82 | 0 | 4 |
| warning | 29 | 28 | 0 | 1 |

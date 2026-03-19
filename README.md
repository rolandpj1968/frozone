# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2519/2520** ruby/spec language examples
(0 failures, 1 error — the sole error is an unimplemented `-e` magic-comment edge case).
Pattern matching is not yet implemented (excluded from the count above).

Core library spec coverage: **15730 / 17463 passing (90.1%)** across 47 of 58 core modules
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

**Prism parser: 2519 / 2520 passing** (0 failures, 1 error) — as of 2026-03-15 (v4.0.0)

Remaining 1 error: magic comment in a `-e` argument (not implemented).
Pattern matching excluded (not yet implemented).

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 30 | 0 | 0 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 38 | 38 | 0 | 0 |
| BEGIN | 7 | 7 | 0 | 0 |
| block | 165 | 165 | 0 | 0 |
| break | 39 | 39 | 0 | 0 |
| case | 47 | 47 | 0 | 0 |
| class | 45 | 45 | 0 | 0 |
| class_variable | 14 | 14 | 0 | 0 |
| comment | 1 | 1 | 0 | 0 |
| constants | 100 | 100 | 0 | 0 |
| def | 73 | 73 | 0 | 0 |
| defined | 255 | 255 | 0 | 0 |
| delegation | 14 | 14 | 0 | 0 |
| encoding | 6 | 6 | 0 | 0 |
| END | 14 | 14 | 0 | 0 |
| ensure | 31 | 31 | 0 | 0 |
| execution | 6 | 6 | 0 | 0 |
| file | 6 | 6 | 0 | 0 |
| for | 27 | 27 | 0 | 0 |
| hash | 40 | 40 | 0 | 0 |
| heredoc | 16 | 16 | 0 | 0 |
| if | 52 | 52 | 0 | 0 |
| it_parameter | 15 | 15 | 0 | 0 |
| keyword_arguments | 23 | 23 | 0 | 0 |
| lambda | 69 | 69 | 0 | 0 |
| line | 6 | 6 | 0 | 0 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 53 | 0 | 1 |
| match | 7 | 7 | 0 | 0 |
| metaclass | 21 | 21 | 0 | 0 |
| method | 168 | 168 | 0 | 0 |
| module | 16 | 16 | 0 | 0 |
| next | 35 | 35 | 0 | 0 |
| not | 10 | 10 | 0 | 0 |
| numbered_parameters | 13 | 13 | 0 | 0 |
| numbers | 22 | 22 | 0 | 0 |
| optional_assignments | 74 | 74 | 0 | 0 |
| or | 15 | 15 | 0 | 0 |
| order | 5 | 5 | 0 | 0 |
| pattern_matching | — | 0 | — | — |
| precedence | 32 | 32 | 0 | 0 |
| predefined | 172 | 172 | 0 | 0 |
| private | 7 | 7 | 0 | 0 |
| proc | 40 | 40 | 0 | 0 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 5 | 0 | 0 |
| regexp | 25 | 25 | 0 | 0 |
| rescue | 59 | 59 | 0 | 0 |
| retry | 3 | 3 | 0 | 0 |
| return | 43 | 43 | 0 | 0 |
| safe | 1 | 1 | 0 | 0 |
| safe_navigator | 13 | 13 | 0 | 0 |
| send | 76 | 76 | 0 | 0 |
| singleton_class | 53 | 53 | 0 | 0 |
| source_encoding | 6 | 6 | 0 | 0 |
| string | 39 | 39 | 0 | 0 |
| super | 61 | 61 | 0 | 0 |
| symbol | 14 | 14 | 0 | 0 |
| throw | 10 | 10 | 0 | 0 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 119 | 119 | 0 | 0 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 39 | 0 | 0 |

### WqParser (whitequark `parser` gem fork)

**WqParser: 2518 / 2520 passing** (0 failures, 2 errors) — as of 2026-03-15 (v4.0.0)

Differences from Prism (both are whitequark lexer limitations):

| Spec | Prism | WqParser | Notes |
|------|-------|----------|-------|
| constants | 100/100 | 99/100 | `mod::ἍBB` — non-ASCII uppercase not lexed as constant |
| magic_comment | 53/54 | 53/54 | same `-e` edge case as Prism |
| variables | 119/119 | 119/119 | `ἍBB = 1` in method body correctly raises SyntaxError |
| All others | identical | identical | |

## ruby/spec Core Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) core specs.
Run with `bundle exec rake core` (or `rake core:NAME` for a single module).
Core specs run in parallel (`JOBS=N`, default: nprocessors).

**Overall: 15730 / 17463 passing (90.1%)** — as of 2026-03-19 (Prism parser, 47 of 58 modules measured)

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
| time | 753 | 258 | 184 | 311 |
| tracepoint | 75 | -1 | 5 | 71 |
| true | 13 | 13 | 0 | 0 |
| unboundmethod | 86 | 82 | 0 | 4 |
| warning | 31 | 30 | 0 | 1 |

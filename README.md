# Frozone

A Ruby VM implemented in Ruby. Parses Ruby source via the [Prism](https://github.com/ruby/prism) gem and evaluates the resulting AST directly. No compilation step — pure tree-walking interpreter.

## Project Status (v4.0.1)

Frozone targets Ruby 4.0 semantics and passes **2519/2520** ruby/spec language examples
(0 failures, 1 error — the sole error is an unimplemented `-e` magic-comment edge case).
Pattern matching is not yet implemented (excluded from the count above).

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

**Overall: ~8442 / ~13244 passing** (~64%) — as of 2026-03-18 (Prism parser, excludes timed-out modules)

Note: Negative "passing" counts indicate errors exceed examples (mspec counts some errors as extra failures).
`—` = not yet run (hangs/timeout); `(TO)` = suite times out.

| Module | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| argf | 84 | -53 | 3 | 134 |
| array | — (TO) | — | — | — |
| basicobject | 178 | 111 | 41 | 26 |
| binding | 53 | 23 | 7 | 23 |
| builtin_constants | 27 | 27 | 0 | 0 |
| class | 45 | 22 | 18 | 5 |
| comparable | 54 | 54 | 0 | 0 |
| complex | 176 | 23 | 57 | 96 |
| conditionvariable | — | — | — | — |
| data | 77 | 0 | 4 | 73 |
| dir | 309 | 103 | 50 | 156 |
| encoding | 552 | -45 | 23 | 574 |
| enumerable | 574 | 574 | 0 | 0 |
| enumerator | — (TO) | — | — | — |
| env | 239 | 138 | 95 | 6 |
| exception | 247 | 231 | 8 | 8 |
| false | 13 | 13 | 0 | 0 |
| fiber | 168 | 26 | 77 | 65 |
| file | 781 | -60 | 190 | 651 |
| filetest | — | — | — | — |
| float | 328 | 323 | 5 | 0 |
| gc | 33 | -10 | 4 | 39 |
| hash | 633 | 633 | 0 | 0 |
| integer | — | — | — | — |
| io | — | — | — | — |
| kernel | — (TO) | — | — | — |
| main | 27 | 4 | 11 | 12 |
| marshal | 110 | -3 | 6 | 107 |
| matchdata | 186 | 83 | 23 | 80 |
| math | 243 | 108 | 71 | 64 |
| method | 223 | 211 | 8 | 4 |
| module | 1061 | 973 | 25 | 63 |
| mutex | — (TO) | — | — | — |
| nil | 27 | 27 | 0 | 0 |
| numeric | 327 | -28 | 95 | 260 |
| objectspace | 112 | 10 | 10 | 92 |
| proc | 294 | 212 | 54 | 28 |
| process | — (TO) | — | — | — |
| queue | 88 | -3 | 13 | 78 |
| random | 48 | 20 | 4 | 24 |
| range | — (TO) | — | — | — |
| rational | 159 | 156 | 3 | 0 |
| refinement | 25 | 0 | 0 | 25 |
| regexp | 265 | 76 | 57 | 132 |
| set | — (TO) | — | — | — |
| signal | 10 | -42 | 6 | 46 |
| sizedqueue | 129 | 0 | 16 | 113 |
| string | 3976 | 3973 | 3 | 0 |
| struct | 182 | 181 | 1 | 0 |
| symbol | 330 | 330 | 0 | 0 |
| systemexit | 6 | 6 | 0 | 0 |
| thread | — (TO) | — | — | — |
| threadgroup | 5 | -3 | 0 | 8 |
| time | 668 | -60 | 164 | 564 |
| tracepoint | 73 | -1 | 4 | 70 |
| true | 13 | 13 | 0 | 0 |
| unboundmethod | 86 | 66 | 11 | 9 |
| warning | — (TO) | — | — | — |

# ruby/spec Status (Interpreter)

These results are from running ruby/spec through the Frozone **tree-walking interpreter**.
Compiler spec coverage is tracked separately via `--aot` compiled test files (see [compilation.md](compilation.md)).

## Language Specs

Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).
`PARSER=wq` switches to the WqParser frontend; default is Prism.

| Parser | Examples | Passing | Failures | Errors | Pass rate |
|---|---:|---:|---:|---:|---:|
| Prism  | 2630 | 2612 | 15 | 3 | 99.32% |
| WQ     | 2168 | 2152 | 15 | 1 | 99.27% (of those that loaded) |

— as of 2026-05-06.

WqParser rejects 462 spec files at load (file-level LOAD_ERROR) due to stricter encoding handling — most are constant-name and symbol literals with non-ASCII characters. Files that load run on roughly the same code paths.

Specs with 100% pass rate (Prism):
`alias`, `and`, `array`, `assignments`, `BEGIN`, `block`, `break`, `case`, `class`,
`comment`, `constants`, `defined`, `def`, `delegation`, `encoding`, `END`, `ensure`,
`file`, `for`, `hash`, `heredoc`, `if`, `it_parameter`, `keyword_arguments`,
`lambda`, `line`, `loop`, `match`, `metaclass`, `method`, `module`, `next`, `not`,
`numbered_parameters`, `numbers`, `optional_assignments`, `order`, `or`,
`precedence`, `private`, `proc`, `range`, `redo`, `regexp`, `rescue`,
`reserved_keywords`, `retry`, `return`, `safe_navigator`, `safe`, `send`,
`singleton_class`, `source_encoding`, `string`, `super`, `symbol`, `throw`,
`undef`, `unless`, `until`, `variables`, `while`, `yield`

Remaining failures (both parsers):

| Spec | Result | Notes |
|------|--------|-------|
| magic_comment | 10 failures | stdin magic comment tests (no stdin support in spec runner) |
| class_variable | 1 failure | class variable overtaken in ancestor edge case |
| execution | 1 failure | `$LOAD_PATH` sitelibdir `@gem_prelude_index` |
| predefined | 1 failure | `$LOAD_PATH.resolve_feature_path` for `.so` files |
| pattern_matching | 3 errors (Prism) / 1 (WQ) | refinements + deconstruct edge cases |

## Core Specs

Run with `bundle exec rake core` (or `rake core:NAME` for a single module).
Core specs run in parallel (`JOBS=N`, default: nprocessors).

| Parser | Examples | Passing | Failures | Errors | Pass rate |
|---|---:|---:|---:|---:|---:|
| Prism  | 22960 | 22627 | 77  | 256 | 98.55% |
| WQ     | 22468 | 22081 | 116 | 271 | 98.27% |

— as of 2026-05-06.

`tracepoint` intentionally unimplemented (deep VM introspection; moot before compilation). `argf` specs require a `argf` helper method we don't ship — those 126 errors are structural, not interpreter bugs. Hanging specs (blocking IO, threading primitives, GC-dependent) excluded via `SKIP_SPEC_FILES` in `Rakefile`.

Modules with 100% pass rate (Prism):
`array`, `basicobject`, `binding`, `builtin_constants`, `class`, `comparable`, `data`, `dir`,
`encoding`, `env`, `false`, `fiber`, `filetest`, `float`, `gc`, `hash`, `integer`, `main`,
`matchdata`, `math`, `method`, `mutex`, `nil`, `numeric`, `objectspace`, `proc`, `queue`,
`random`, `range`, `regexp`, `set`, `signal`, `struct`, `symbol`, `systemexit`,
`threadgroup`, `time`, `true`, `unboundmethod`, `warning`

Modules with non-trivial residual issues (Prism / WQ):

| Module | Prism (E/F) | WQ (E/F) | Notes |
|---|---:|---:|---|
| argf | 126 / 10 | 126 / 10 | `argf` helper method missing from our snapshot of ruby-spec |
| complex | 9 / 7 | 9 / 7 | Complex coercion edges |
| enumerable | 0 / 2 | 0 / 2 | inject + grouping edges |
| enumerator | 1 / 1 | 1 / 1 | |
| exception | 1 / 0 | 2 / 1 | |
| file | 5 / 0 | 5 / 0 | OS-level file ops; socket specs need io/wait C ext |
| io | 9 / 3 | 9 / 2 | blocking/pipe/buffer specs skipped; OS-level gaps |
| kernel | 7 / 17 | 13 / 23 | spawn, format edge cases |
| marshal | 1 / 2 | 1 / 2 | |
| module | 0 / 11 | 1 / 37 | WQ: extra method-visibility edges |
| rational | 0 / 3 | 0 / 3 | |
| refinement | 1 / 0 | 1 / 0 | |
| sizedqueue | 0 / 1 | 0 / 1 | blocking specs excluded (cooperative scheduling) |
| string | 24 / 2 | 27 / 7 | encoding edges; WQ skips 414 examples at load |
| thread | 1 / 9 | 1 / 9 | cooperative threading edge cases |
| tracepoint | 71 / 5 | 71 / 5 | intentionally unimplemented |

## Library Specs

Run with `bundle exec rake library` (or `rake library:NAME` for a single module).

**Overall: 1979 / 2467 passing (80%)** — as of 2026-03-29

Many modules report 0 examples because they require C extensions or unavailable gems.

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
| stringio | 670 | 668 | 0 | 2 | getch/getpass need `io/console` C extension |
| tempfile | 46 | 24 | 5 | 17 | temp file/dir race conditions |

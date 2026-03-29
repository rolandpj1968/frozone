# ruby/spec Status (Interpreter)

These results are from running ruby/spec through the Frozone **tree-walking interpreter**.
Compiler spec coverage is tracked separately via `--aot` compiled test files (see [compilation.md](compilation.md)).

## Language Specs

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

### WqParser

Similar pass rate (2 additional errors for non-ASCII constant lexing).
Switch with `PARSER=wq bundle exec rake language` or `--parser=wq`.

| Spec | Prism | WqParser | Notes |
|------|-------|----------|-------|
| constants | 100/100 | 99/100 | `mod::ἍBB` — non-ASCII uppercase not lexed as constant |

## Core Specs

Run with `bundle exec rake core` (or `rake core:NAME` for a single module).
Core specs run in parallel (`JOBS=N`, default: nprocessors).

**Overall: 22708 / 22913 passing (99.1%)** — as of 2026-03-27

`tracepoint` intentionally unimplemented (deep VM introspection; moot before compilation).
Hanging specs (blocking IO, threading primitives, GC-dependent) excluded via `SKIP_SPEC_FILES` in `Rakefile`.

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
| kernel | 2741 | 2718 | 17 | 6 | spawn, format edge cases |
| module | 1058 | 1051 | 7 | 0 | |
| process | 86 | 44 | 0 | 42 | OS-level process ops |
| refinement | 25 | 24 | 0 | 1 | |
| sizedqueue | 21 | 20 | 1 | 0 | blocking specs excluded (cooperative scheduling) |
| thread | 227 | 220 | 7 | 0 | cooperative threading; remaining edge cases |
| tracepoint | 75 | — | 5 | 71 | intentionally unimplemented |

## Library Specs

Run with `bundle exec rake library` (or `rake library:NAME` for a single module).

**Overall: 1979 / 2467 passing (80%)** — as of 2026-03-27

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

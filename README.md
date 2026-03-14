# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 2511 / 2520 passing** (0 failures, 9 errors) — as of 2026-03-14

Remaining 9 errors are unimplemented features: `BEGIN` (5), `return` inside `BEGIN` (1), Fiber-local `$!`/`$@` (2), Big5 magic comment encoding (1).

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 30 | 0 | 0 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 38 | 38 | 0 | 0 |
| BEGIN | 7 | 2 | 0 | 5 |
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
| predefined | 172 | 170 | 0 | 2 |
| private | 7 | 7 | 0 | 0 |
| proc | 40 | 40 | 0 | 0 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 5 | 0 | 0 |
| regexp | 25 | 25 | 0 | 0 |
| rescue | 59 | 59 | 0 | 0 |
| retry | 3 | 3 | 0 | 0 |
| return | 43 | 42 | 0 | 1 |
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

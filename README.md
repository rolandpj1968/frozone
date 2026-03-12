# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 1473 / 2240 passing** (371 failures, 396 errors) — as of 2026-03-12

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 15 | 6 | 9 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 38 | 19 | 15 | 4 |
| BEGIN | 7 | 0 | 1 | 6 |
| block | 165 | 141 | 18 | 6 |
| break | 39 | 22 | 9 | 8 |
| case | 47 | 36 | 8 | 3 |
| class | 45 | 22 | 17 | 6 |
| class_variable | 14 | 8 | 4 | 2 |
| comment | 0 | 0 | 0 | 0 |
| constants | 100 | 59 | 22 | 19 |
| def | 73 | 64 | 4 | 5 |
| defined | 255 | 232 | 10 | 13 |
| delegation | 14 | 9 | 3 | 2 |
| encoding | 6 | 1 | 3 | 2 |
| END | 14 | 0 | 9 | 5 |
| ensure | 31 | 18 | 4 | 9 |
| execution | 6 | 0 | 6 | 0 |
| file | 5 | 2 | 1 | 2 |
| for | 27 | 0 | 0 | 27 |
| hash | 8 | 5 | 2 | 1 |
| heredoc | 16 | 14 | 2 | 0 |
| if | 52 | 36 | 8 | 8 |
| it_parameter | 0 | 0 | 0 | 0 |
| keyword_arguments | 23 | 11 | 6 | 6 |
| lambda | 6 | 0 | 2 | 4 |
| line | 5 | 1 | 1 | 3 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 0 | 0 | 54 |
| match | 7 | 2 | 0 | 5 |
| metaclass | 21 | 14 | 7 | 0 |
| method | 63 | 41 | 1 | 21 |
| module | 16 | 5 | 8 | 3 |
| next | 35 | 32 | 2 | 1 |
| not | 10 | 10 | 0 | 0 |
| numbered_parameters | 13 | 4 | 6 | 3 |
| numbers | 22 | 8 | 1 | 13 |
| optional_assignments | 74 | 68 | 2 | 4 |
| or | 15 | 12 | 3 | 0 |
| order | 5 | 5 | 0 | 0 |
| pattern_matching | 0 | 0 | 0 | 0 |
| precedence | 32 | 26 | 3 | 3 |
| predefined | 172 | 37 | 88 | 47 |
| private | 7 | 6 | 0 | 1 |
| proc | 36 | 35 | 0 | 1 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 3 | 1 | 1 |
| regexp | 0 | 0 | 0 | 0 |
| rescue | 59 | 37 | 14 | 8 |
| retry | 3 | 2 | 1 | 0 |
| return | 27 | 7 | 1 | 19 |
| safe | 0 | 0 | 0 | 0 |
| safe_navigator | 13 | 3 | 2 | 8 |
| send | 76 | 63 | 3 | 10 |
| singleton_class | 53 | 32 | 20 | 1 |
| source_encoding | 6 | 0 | 0 | 6 |
| string | 34 | 20 | 5 | 9 |
| super | 61 | 44 | 4 | 13 |
| symbol | 0 | 0 | 0 | 0 |
| throw | 10 | 7 | 2 | 1 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 119 | 93 | 21 | 5 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 25 | 10 | 4 |

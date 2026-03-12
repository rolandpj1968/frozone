# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 1949 / 2443 passing** (283 failures, 211 errors) — as of 2026-03-12

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 17 | 6 | 7 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 38 | 27 | 9 | 2 |
| BEGIN | 7 | 2 | 0 | 5 |
| block | 165 | 162 | 0 | 3 |
| break | 39 | 34 | 5 | 0 |
| case | 47 | 39 | 6 | 2 |
| class | 45 | 32 | 7 | 6 |
| class_variable | 14 | 9 | 3 | 2 |
| comment | 1 | 1 | 0 | 0 |
| constants | 100 | 72 | 22 | 6 |
| def | 73 | 65 | 3 | 5 |
| defined | 255 | 235 | 6 | 14 |
| delegation | 14 | 11 | 3 | 0 |
| encoding | 6 | 2 | 4 | 0 |
| END | 14 | 0 | 9 | 5 |
| ensure | 31 | 30 | 1 | 0 |
| execution | 6 | 0 | 6 | 0 |
| file | 5 | 5 | 0 | 0 |
| for | 27 | 25 | 0 | 2 |
| hash | 8 | 6 | 2 | 0 |
| heredoc | 16 | 16 | 0 | 0 |
| if | 52 | 38 | 11 | 3 |
| it_parameter | 15 | 2 | 4 | 9 |
| keyword_arguments | 23 | 16 | 2 | 5 |
| lambda | 69 | 55 | 12 | 2 |
| line | 5 | 3 | 0 | 2 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 8 | 8 | 38 |
| match | 7 | 2 | 0 | 5 |
| metaclass | 21 | 15 | 6 | 0 |
| method | 168 | 151 | 9 | 8 |
| module | 16 | 11 | 2 | 3 |
| next | 35 | 33 | 2 | 0 |
| not | 10 | 10 | 0 | 0 |
| numbered_parameters | 13 | 10 | 0 | 3 |
| numbers | 22 | 9 | 0 | 13 |
| optional_assignments | 74 | 72 | 2 | 0 |
| or | 15 | 15 | 0 | 0 |
| order | 5 | 5 | 0 | 0 |
| pattern_matching | — | 0 | — | — |
| precedence | 32 | 29 | 0 | 3 |
| predefined | 172 | 68 | 79 | 25 |
| private | 7 | 7 | 0 | 0 |
| proc | 40 | 40 | 0 | 0 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 5 | 0 | 0 |
| regexp | 1 | 0 | 0 | 1 |
| rescue | 59 | 56 | 3 | 0 |
| retry | 3 | 3 | 0 | 0 |
| return | 43 | 36 | 3 | 4 |
| safe | 1 | 1 | 0 | 0 |
| safe_navigator | 13 | 13 | 0 | 0 |
| send | 76 | 74 | 0 | 2 |
| singleton_class | 53 | 40 | 13 | 0 |
| source_encoding | 6 | 2 | 2 | 2 |
| string | 34 | 24 | 7 | 3 |
| super | 61 | 48 | 4 | 9 |
| symbol | 1 | 0 | 0 | 1 |
| throw | 10 | 8 | 2 | 0 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 119 | 114 | 4 | 1 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 36 | 3 | 0 |

# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 1862 / 2425 passing** (323 failures, 240 errors) — as of 2026-03-12

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 32 | 15 | 8 | 9 |
| and | 12 | 10 | 2 | 0 |
| array | 25 | 22 | 3 | 0 |
| assignments | 40 | 27 | 6 | 7 |
| BEGIN | 9 | 0 | 1 | 8 |
| block | 175 | 154 | 8 | 13 |
| break | 41 | 33 | 5 | 3 |
| case | 49 | 37 | 9 | 3 |
| class | 47 | 31 | 9 | 7 |
| class_variable | 16 | 8 | 5 | 3 |
| comment | 3 | 0 | 0 | 3 |
| constants | 102 | 71 | 25 | 6 |
| def | 75 | 64 | 8 | 3 |
| defined | 257 | 232 | 9 | 16 |
| delegation | 16 | 11 | 5 | 0 |
| encoding | 8 | 1 | 5 | 2 |
| END | 16 | 0 | 9 | 7 |
| ensure | 32 | 18 | 5 | 9 |
| execution | 8 | 0 | 8 | 0 |
| file | 8 | 3 | 2 | 3 |
| for | 29 | 24 | 2 | 3 |
| hash | 10 | 6 | 4 | 0 |
| heredoc | 18 | 14 | 4 | 0 |
| if | 54 | 36 | 9 | 9 |
| it_parameter | 2 | 0 | 0 | 2 |
| keyword_arguments | 25 | 14 | 6 | 5 |
| lambda | 71 | 44 | 16 | 11 |
| line | 8 | 2 | 3 | 3 |
| loop | 9 | 7 | 0 | 2 |
| magic_comment | 56 | 8 | 0 | 48 |
| match | 9 | 2 | 0 | 7 |
| metaclass | 23 | 15 | 8 | 0 |
| method | 158 | 141 | 10 | 7 |
| module | 18 | 11 | 4 | 3 |
| next | 37 | 33 | 4 | 0 |
| not | 12 | 10 | 2 | 0 |
| numbered_parameters | 15 | 4 | 7 | 4 |
| numbers | 24 | 8 | 3 | 13 |
| optional_assignments | 76 | 72 | 4 | 0 |
| or | 17 | 12 | 5 | 0 |
| order | 7 | 5 | 2 | 0 |
| pattern_matching | — | 0 | — | — |
| precedence | 40 | 32 | 5 | 3 |
| predefined | 169 | 58 | 72 | 39 |
| private | 9 | 6 | 1 | 2 |
| proc | 42 | 38 | 3 | 1 |
| range | 7 | 5 | 2 | 0 |
| redo | 7 | 3 | 1 | 3 |
| regexp | 2 | 0 | 0 | 2 |
| rescue | 60 | 50 | 6 | 4 |
| retry | 5 | 2 | 2 | 1 |
| return | 45 | 33 | 6 | 6 |
| safe | 3 | 1 | 2 | 0 |
| safe_navigator | 15 | 12 | 3 | 0 |
| send | 76 | 72 | 4 | 0 |
| singleton_class | 55 | 39 | 13 | 3 |
| source_encoding | 8 | 2 | 0 | 6 |
| string | 36 | 22 | 8 | 6 |
| super | 63 | 48 | 9 | 6 |
| symbol | 2 | 0 | 0 | 2 |
| throw | 12 | 7 | 4 | 1 |
| undef | 10 | 8 | 2 | 0 |
| unless | 8 | 6 | 2 | 0 |
| until | 30 | 28 | 2 | 0 |
| variables | 121 | 115 | 1 | 5 |
| while | 39 | 37 | 2 | 0 |
| yield | 41 | 35 | 6 | 0 |

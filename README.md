# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 1948 / 2425 passing** (315 failures, 162 errors) — as of 2026-03-12

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 17 | 6 | 7 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 22 | 0 | 1 |
| assignments | 38 | 27 | 5 | 6 |
| BEGIN | 7 | 1 | 1 | 5 |
| block | 173 | 169 | 2 | 2 |
| break | 39 | 33 | 5 | 1 |
| case | 47 | 39 | 6 | 2 |
| class | 45 | 32 | 7 | 6 |
| class_variable | 14 | 9 | 3 | 2 |
| comment | 1 | 1 | 0 | 0 |
| constants | 100 | 72 | 22 | 6 |
| def | 73 | 66 | 4 | 3 |
| defined | 255 | 232 | 9 | 14 |
| delegation | 14 | 11 | 3 | 0 |
| encoding | 6 | 2 | 4 | 0 |
| END | 14 | 0 | 9 | 5 |
| ensure | 30 | 30 | 0 | 0 |
| execution | 6 | 0 | 6 | 0 |
| file | 6 | 4 | 1 | 1 |
| for | 27 | 24 | 1 | 2 |
| hash | 8 | 6 | 2 | 0 |
| heredoc | 16 | 15 | 1 | 0 |
| if | 52 | 38 | 11 | 3 |
| it_parameter | 0 | 0 | 0 | 0 |
| keyword_arguments | 23 | 14 | 4 | 5 |
| lambda | 69 | 56 | 8 | 5 |
| line | 6 | 4 | 0 | 2 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 8 | 8 | 38 |
| match | 7 | 2 | 0 | 5 |
| metaclass | 21 | 15 | 6 | 0 |
| method | 156 | 144 | 9 | 3 |
| module | 16 | 11 | 2 | 3 |
| next | 35 | 33 | 2 | 0 |
| not | 10 | 10 | 0 | 0 |
| numbered_parameters | 13 | 9 | 1 | 3 |
| numbers | 22 | 9 | 0 | 13 |
| optional_assignments | 74 | 72 | 2 | 0 |
| or | 15 | 15 | 0 | 0 |
| order | 5 | 5 | 0 | 0 |
| pattern_matching | — | 0 | — | — |
| precedence | 38 | 34 | 1 | 3 |
| predefined | 167 | 67 | 77 | 23 |
| private | 7 | 6 | 0 | 1 |
| proc | 40 | 38 | 1 | 1 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 3 | 1 | 1 |
| regexp | 1 | 0 | 0 | 1 |
| rescue | 58 | 56 | 2 | 0 |
| retry | 3 | 2 | 1 | 0 |
| return | 43 | 33 | 4 | 6 |
| safe | 1 | 1 | 0 | 0 |
| safe_navigator | 13 | 13 | 0 | 0 |
| send | 74 | 73 | 0 | 1 |
| singleton_class | 53 | 39 | 13 | 1 |
| source_encoding | 6 | 2 | 2 | 2 |
| string | 34 | 25 | 7 | 2 |
| super | 61 | 48 | 4 | 9 |
| symbol | 1 | 0 | 0 | 1 |
| throw | 10 | 7 | 2 | 1 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 119 | 116 | 2 | 1 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 35 | 4 | 0 |

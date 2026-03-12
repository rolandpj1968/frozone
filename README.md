# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 1947 / 2545 passing** (322 failures, 276 errors) — as of 2026-03-12

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 15 | 6 | 9 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 42 | 27 | 7 | 8 |
| BEGIN | 7 | 0 | 1 | 6 |
| block | 175 | 158 | 8 | 9 |
| break | 39 | 22 | 12 | 5 |
| case | 48 | 38 | 8 | 2 |
| class | 45 | 31 | 7 | 7 |
| class_variable | 14 | 8 | 4 | 2 |
| comment | 1 | 0 | 0 | 1 |
| constants | 100 | 72 | 22 | 6 |
| def | 74 | 64 | 7 | 3 |
| defined | 258 | 232 | 12 | 14 |
| delegation | 14 | 11 | 3 | 0 |
| encoding | 6 | 1 | 3 | 2 |
| END | 14 | 0 | 9 | 5 |
| ensure | 31 | 19 | 3 | 9 |
| execution | 6 | 0 | 6 | 0 |
| file | 6 | 4 | 1 | 1 |
| for | 27 | 23 | 1 | 3 |
| hash | 41 | 38 | 2 | 1 |
| heredoc | 16 | 13 | 3 | 0 |
| if | 52 | 36 | 8 | 8 |
| it_parameter | 15 | 15 | 0 | 0 |
| keyword_arguments | 23 | 14 | 4 | 5 |
| lambda | 15 | 6 | 2 | 7 |
| line | 6 | 2 | 2 | 2 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 0 | 0 | 54 |
| match | 7 | 2 | 0 | 5 |
| metaclass | 21 | 15 | 6 | 0 |
| method | 84 | 67 | 2 | 15 |
| module | 16 | 11 | 2 | 3 |
| next | 35 | 33 | 2 | 0 |
| not | 10 | 10 | 0 | 0 |
| numbered_parameters | 14 | 6 | 5 | 3 |
| numbers | 22 | 7 | 2 | 13 |
| optional_assignments | 74 | 72 | 2 | 0 |
| or | 15 | 12 | 3 | 0 |
| order | 5 | 5 | 0 | 0 |
| pattern_matching | 113 | 0 | 0 | 113 |
| precedence | 38 | 32 | 3 | 3 |
| predefined | 174 | 42 | 86 | 46 |
| private | 7 | 6 | 0 | 1 |
| proc | 38 | 36 | 1 | 1 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 4 | 0 | 1 |
| regexp | 26 | 25 | 0 | 1 |
| rescue | 59 | 44 | 11 | 4 |
| retry | 3 | 1 | 1 | 1 |
| return | 43 | 33 | 7 | 3 |
| safe | 1 | 1 | 0 | 0 |
| safe_navigator | 13 | 13 | 0 | 0 |
| send | 76 | 74 | 2 | 0 |
| singleton_class | 53 | 37 | 14 | 2 |
| source_encoding | 6 | 0 | 0 | 6 |
| string | 40 | 26 | 8 | 6 |
| super | 61 | 46 | 5 | 10 |
| symbol | 14 | 13 | 0 | 1 |
| throw | 10 | 6 | 3 | 1 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 120 | 96 | 11 | 13 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 36 | 3 | 0 |

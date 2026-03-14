# Frozone

Ruby VM in two stages - load, execute.

Load stage: partial evaluation of source code to define all modules/classes and methods.

Execute stage: compilation of closed-world code-base.

## ruby/spec Language Spec Status

Tested against [ruby/spec](https://github.com/ruby/spec) language specs.
Run with `bundle exec rake language` (or `rake language:NAME` for a single spec).

**Overall: 2483 / 2520 passing** (12 failures, 25 errors) — as of 2026-03-14

| Spec | Examples | Passing | Failures | Errors |
|---|---:|---:|---:|---:|
| alias | 30 | 30 | 0 | 0 |
| and | 10 | 10 | 0 | 0 |
| array | 23 | 23 | 0 | 0 |
| assignments | 38 | 38 | 0 | 0 |
| BEGIN | 7 | 2 | 0 | 5 |
| block | 165 | 165 | 0 | 0 |
| break | 39 | 38 | 0 | 1 |
| case | 47 | 47 | 0 | 0 |
| class | 45 | 45 | 0 | 0 |
| class_variable | 14 | 14 | 0 | 0 |
| comment | 1 | 1 | 0 | 0 |
| constants | 100 | 100 | 0 | 0 |
| def | 73 | 73 | 0 | 0 |
| defined | 255 | 254 | 0 | 1 |
| delegation | 14 | 14 | 0 | 0 |
| encoding | 6 | 6 | 0 | 0 |
| END | 14 | 14 | 0 | 0 |
| ensure | 31 | 30 | 1 | 0 |
| execution | 6 | 6 | 0 | 0 |
| file | 6 | 5 | 1 | 0 |
| for | 27 | 27 | 0 | 0 |
| hash | 40 | 40 | 0 | 0 |
| heredoc | 16 | 16 | 0 | 0 |
| if | 52 | 52 | 0 | 0 |
| it_parameter | 15 | 15 | 0 | 0 |
| keyword_arguments | 23 | 17 | 6 | 0 |
| lambda | 69 | 69 | 0 | 0 |
| line | 6 | 6 | 0 | 0 |
| loop | 7 | 7 | 0 | 0 |
| magic_comment | 54 | 45 | 0 | 9 |
| match | 7 | 7 | 0 | 0 |
| metaclass | 21 | 21 | 0 | 0 |
| method | 168 | 166 | 2 | 0 |
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
| predefined | 172 | 168 | 0 | 4 |
| private | 7 | 7 | 0 | 0 |
| proc | 40 | 40 | 0 | 0 |
| range | 5 | 5 | 0 | 0 |
| redo | 5 | 5 | 0 | 0 |
| regexp | 25 | 25 | 0 | 0 |
| rescue | 59 | 57 | 2 | 0 |
| retry | 3 | 3 | 0 | 0 |
| return | 43 | 41 | 0 | 2 |
| safe | 1 | 1 | 0 | 0 |
| safe_navigator | 13 | 13 | 0 | 0 |
| send | 76 | 76 | 0 | 0 |
| singleton_class | 53 | 53 | 0 | 0 |
| source_encoding | 6 | 6 | 0 | 0 |
| string | 39 | 39 | 0 | 0 |
| super | 61 | 61 | 0 | 0 |
| symbol | 14 | 14 | 0 | 0 |
| throw | 10 | 9 | 0 | 1 |
| undef | 8 | 8 | 0 | 0 |
| unless | 6 | 6 | 0 | 0 |
| until | 28 | 28 | 0 | 0 |
| variables | 119 | 119 | 0 | 0 |
| while | 37 | 37 | 0 | 0 |
| yield | 39 | 39 | 0 | 0 |

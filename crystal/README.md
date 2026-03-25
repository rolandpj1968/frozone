# frozone-crystal

Crystal runtime types for the [Frozone](https://github.com/rolandpj1968/frozone) Ruby VM compiler backend.
Implements Ruby value semantics (`RubyString`, `RubySymbol`, `RubyInteger`, ...) in Crystal as
groundwork for compiling Frozone to native code.

## Structure

- `src/ruby_string.cr` — `RubyString` with encoding-aware byte storage (~18 primitives)
- `src/ruby_symbol.cr` — `RubySymbol` with class-level intern table
- `src/ruby_integer.cr` — `RubyInteger` with auto-promotion from `Int64` to `BigInt`
- `src/encoding/` — MRI-compatible encoding conversion tables (see below)
- `enc/trans/` — Source encoding definition files (from MRI Ruby, see attribution)
- `tool/` — Code-generation tools

## Encoding Tables

The encoding conversion table source files in `enc/trans/` and `tool/transcode-tblgen.rb` are
copied from the [ruby/ruby](https://github.com/ruby/ruby) repository at commit
`d01875d6dd24a3f630b52dc26b3898d74ab9fe77` (2026-03-19).

These files are Copyright (C) 1993-2013 Yukihiro Matsumoto and are used under the
[BSD 2-Clause License](enc/BSDL) (Ruby's BSDL), which is compatible with this project's MIT license.

To check for upstream changes or re-sync the encoding files:

```sh
tool/sync-mri-encoding.sh --check   # report diffs vs current ruby/ruby HEAD
tool/sync-mri-encoding.sh           # overwrite with current ruby/ruby HEAD
```

## License

frozone-crystal is MIT licensed. See [LICENSE](LICENSE).

The encoding table source files in `enc/` are BSD 2-Clause licensed. See [enc/BSDL](enc/BSDL).

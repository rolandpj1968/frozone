# Closed-world AOT load/execute split

Frozone box-first AOT splits a Ruby program into two phases for compilation:

- **Load phase** — runs in the **interpreter** at AOT-compile time. Its effects (class hierarchy, method definitions, constants, loaded files) populate the closed-world model the compiler then emits C++ for.
- **Execute phase** — gets **compiled** by box-first. The resulting native binary, when run, performs only the work expressible against the universe load phase already established.

This document is the design for handling load/execute correctly across realistic Ruby code, including conditional requires, conditional class definitions, idempotent runtime requires, and gems pulled via Bundler.

## Status

- Current implementation: a top-level walk in `Frozone::Vm::Vm#aot_load_phase_node?` (lib/frozone/vm/vm.rb). First node that isn't a require / class def / module def / method def / attr_* / top-level constant write / `$LOAD_PATH` mutation flips the splitter into "execute phase forever". Works for simple, well-shaped files; insufficient for production-real Ruby (and for Frozone itself).
- This document describes the planned model.

## Design

The model is **strict by default + Zeitwerk-style enumerate roots opt-in**, with a `BUILD_FILES` set that defines the closed world and is enforced at execute-phase emission.

### 1. Build manifest

A user-supplied manifest (file or build config) declares which directories should be *eager-loaded*. Each root is a directory; AOT-build walks the glob `<root>/**/*.rb` and, before any user code runs, `require`s every file it finds.

```
# Sketch — exact syntax TBD
eager_load_roots:
  - lib/frozone                             # Frozone's own source
  - vendor/parser/lib                       # vendored parser gem
  - <gem path>/ast-*/lib                    # ast gem
  - <gem path>/racc-*/lib                   # racc runtime
```

The convention follows Zeitwerk's eager-load: each `.rb` is `require`d in some order; const_missing handles forward references between files. Cycles are flagged.

### 2. Strict load-phase semantics for code outside roots

Files NOT under an eager-load root are subject to the simple top-level walk we have today, BUT with stricter rules:

- `if`, `case`, `begin/rescue`, etc. that contain class / module / method / require / top-level const defs are **flagged at AOT-build time** as closed-world violations. The user must:
  - lift the def to top-level (so it's unconditionally part of load phase), OR
  - move the file under an eager-load root (so its definitions are baked unconditionally), OR
  - explicitly annotate `# frozone:eager-load` on the conditional block to opt that block in (rare; for non-root code).
- No silent fall-through: any conditional definition not inside a recognised eager-load context is an error.

### 3. BUILD_FILES set

During load phase (eager-load + the strict top-level walk), every file the interpreter actually loads gets its **canonical realpath** added to a `BUILD_FILES` set. Frozone already maintains `FILE_REALPATH_CACHE`; this is the seed.

After load phase finishes, BUILD_FILES is closed: it's the universe of source files baked into the binary.

### 4. Execute-phase enforcement

Before emitting C++, walk the execute-phase AST and **fail hard** at compile time on any of these:

- **`require 'x'` / `require_relative 'x'` / `load`**:
  - Resolve `x` to a candidate full path the same way Ruby would (`$LOAD_PATH` for require, calling-file directory for require_relative).
  - If candidate ∈ BUILD_FILES → emit no-op (a tiny `$LOADED_FEATURES`-aware check returns `false` like idempotent require, matching Ruby semantics). The runtime call is harmless.
  - If candidate ∉ BUILD_FILES → fail at compile time: `"runtime require for file not in build: <x> at <file>:<line>"`.
- **Class / module / method / top-level const defs in execute phase**: should not appear (the splitter / strict load mode would have caught them); if they do (e.g. user wrote `class Foo` inside a method body), fail hard.
- **`defined?(X)` / `const_defined?`**:
  - If X is in the closed-world class/const table → fold to `true` at compile time.
  - If X is not → fold to `false` with a warning, OR fail hard (configurable). Default: fail hard. The combination of (idempotent require) + (defined? folds to true) means `require 'json' unless defined?(JSON)` works correctly when JSON is in BUILD_FILES.
- **`define_method` / `define_singleton_method` / `alias_method` / `undef_method` / `remove_const` / `const_set`**: fail hard unless the call's effect is provably load-time-only (rare). The eager-load pass already executed these where applicable.

### 5. Why this works

- **Eager-load roots make the closed world explicit**. The user declares "this directory is the build"; the AOT-build walks it and loads every file. No conditional logic to interpret. This is exactly Zeitwerk's eager-load.
- **Strict mode catches accidental closed-world violations** in code the user didn't put under an eager-load root. The user has to commit: either include it in a root, or refactor to remove the conditional def.
- **Idempotent runtime require pattern works**. `require 'json' unless defined?(JSON)`:
  - JSON is in BUILD_FILES (loaded via an eager-load root or top-level require) → `defined?(JSON)` folds to `true` → `unless true` removes the require. Ruby semantics preserved.
  - JSON isn't in BUILD_FILES → fail hard. The user has to either include json in the build, or refactor.
- **Gems work as expected**. Gem source files are in BUILD_FILES if (a) listed under an eager-load root via their gem path, or (b) reached via top-level require during load phase. Same uniform mechanism.
- **Closed-world contract is explicit**: after the split point, the class/method/file universe is fixed. The runtime binary cannot grow it.

### 6. What this still does NOT solve

- **Build-flag-driven definitions** (`if ENV['DBG']; class DebugTrace; end`): under strict mode, this is an error. The user has to commit to a build flavor at AOT time. (Equivalent to `./configure` in C-land.)
- **Cross-version compatibility shims** (`if RUBY_VERSION >= '3.4'; ...`): same — flag, user picks. Often resolvable by always taking the latest-Ruby branch.
- **Runtime-loaded plugins** (`Dir.glob('plugins/*').each { |f| require f }`): fundamentally violates closed-world. User has to enumerate explicitly via the manifest.

These are where the user pays for closed-world AOT directly: it gives ahead-of-time guarantees in exchange for ahead-of-time decisions.

## Implementation order

The first two steps are the closed-world enforcement minimum; (3)–(5) tighten precision and ergonomics.

1. **BUILD_FILES collection during load phase**. Wire from FILE_REALPATH_CACHE; surface as `Frozone::Vm::Vm#build_files`.
2. **Execute-phase pre-emission AST walk**. Reject:
   - require / require_relative / load whose candidate path is not in BUILD_FILES (hard fail with file:line);
   - class / module / method / top-level const defs that survived into execute phase (hard fail).
   The compiled gen never gets emitted if violations are found.
3. **`defined?` constant-folding** using closed-world class/const table. For folded `true`, the surrounding `if` / `unless` simplifies and the require call is dropped.
4. **Eager-load-roots config + walker**. Read manifest; glob `<root>/**/*.rb`; require each in some order during load phase. Surface cycles + load failures as build errors.
5. **Strict-mode flagging** for conditional definitions outside eager-load roots. Each flag is build-error by default; `# frozone:eager-load` annotation on a block opts that block in to eager evaluation.

The split lets us self-compile Frozone gradually: (1)–(2) catch real bugs immediately; (4)–(5) take the manifest+strict model from theory to practice.

## Realised closed world for Frozone self-compile

Looking at Frozone's Gemfile + actual requires (lib/frozone/vm/parser.rb, lib/frozone/vm/wq_parser.rb, lib/frozone/vm/dual_parser.rb), the practical closed world is:

| Component | Source | Approx files |
|---|---|---|
| Frozone | `lib/frozone/**/*.rb` | ~150 |
| Parser frontend (wq) | `vendor/parser/lib/parser/**/*.rb` | ~50 |
| AST | `ast` gem | ~5 |
| Racc runtime | `racc` gem | ~5 |
| Optparse | stdlib | ~3 |

Order ~200 files. Frozone uses prism by default (Ruby 4.x stdlib) with optional `--parser=wq`. For self-compile we can pick either; wq is fully vendored and avoids the prism stdlib's C-extension surface.

## See also

- `feedback_fail_early_compiler.md` (memory) — the project-wide stance that informs the fail-hard defaults here.
- `feedback_uniform_lambda_lowering.md` (memory) — analogous "Ruby semantics first; pay the cost where it falls; optimize later" attitude.
- `bench/stubs/wq_parse_rich.rb` — the immediate motivation; its 8/8 success demonstrated runtime-side machinery, which now needs the load/execute discipline to scale to compiling Frozone itself.
- Zeitwerk's `Loader#eager_load` — the precedent for the manifest+walk model.

# Closed-world AOT load/execute split

Frozone box-first AOT splits a Ruby program into two phases for compilation:

- **Load phase** — runs in the **interpreter** at AOT-compile time. Its effects (class hierarchy, method definitions, constants, loaded files) populate the closed-world model the compiler then emits C++ for.
- **Execute phase** — gets **compiled** by box-first. The resulting native binary, when run, performs only the work expressible against the universe load phase already established.

This document is the design for handling load/execute correctly across realistic Ruby code, including conditional requires, conditional class definitions, and idempotent runtime requires.

## Status

- Current implementation: a top-level walk in `Frozone::Vm::Vm#aot_load_phase_node?` (lib/frozone/vm/vm.rb). First node that isn't a require / class def / module def / method def / attr_* / top-level constant write / `$LOAD_PATH` mutation flips the splitter into "execute phase forever". Works for simple, well-shaped files; insufficient for production-real Ruby.
- This document describes the planned model, not what's currently emitted.

## What today's splitter misses

```ruby
# Conditional require
if FOO
  require 'a'
end

# Conditional class def
class Bar
  CONST = ENV['DBG'] ? X : Y
end

# Loop-defined methods
class Baz
  (1..10).each { |i| define_method("m_#{i}") { i } }
end

# Computed-path require
require_relative File.basename(file)

# Idempotent guard (very common)
require 'json' unless defined?(JSON)
```

`frozone.rb` itself is in this category — it has a runtime branch that conditionally requires the wq parser:

```ruby
if options[:parser] == :wq
  require_relative 'lib/frozone/vm/wq_parser'
  Frozone::Vm.send(:remove_const, :Parser)
  Frozone::Vm::Parser = Frozone::Vm::WqParser
end
```

The current splitter sees the `if` as execute-phase, so the `require_relative` runs at runtime, but at runtime the closed-world binary doesn't know how to load arbitrary files. Closed-world violation.

## Design

### 1. Load phase: augmented interpreter

The interpreter runs the load phase **plus** instruments the evaluation to surface decisions that compromise the closed-world contract:

- **Environment reads in conditions** that affect class/require/method/const decisions:
  - `ARGV`, `ENV`, `IO`, `defined?` of an unknown name, `$LOADED_FEATURES`, `RUBY_VERSION`, `Process.*`, time/random sources.
  - When a load-time conditional's predicate touches any of these, we know the path taken depends on the AOT-time environment, not the runtime environment of the produced binary.
- **Conditional class/require/method/const defs** where the condition isn't a compile-time-known constant.
- **Name clashes**: same constant or class (re-)defined more than once. The eager-load model takes the union of branches; clashes are the user-visible failure case.
- **Reflective metaprogramming on non-trivial input**: `eval`, `instance_eval`, `class_eval`, `define_method` with computed names, `const_set`, `remove_const`, `alias_method`, `undef_method`.
- **Eager-load of conditional branches**: when an `if` / `case` / `begin` body contains class/module/method/const/require effects, we run **all** branches' definition-effecting code regardless of which branch the predicate selects. Both arms get their definitions baked in. The user-visible defaults to "everything that could exist, exists." Flags surface where this is imprecise.

Each flag is a warning by default. `FROZONE_BOX_HARD_FAIL=1` (or equivalent) promotes warnings to errors so a CI build fails when the closed-world contract is silently weakened.

### 2. Build artifact: BUILD_FILES set

During load phase, every file the interpreter actually loads (every `require` / `require_relative` / `load` that resolved successfully) gets its **canonical realpath** added to a `BUILD_FILES` set.

Frozone already maintains `FILE_REALPATH_CACHE` per-loaded-file (vm.rb), which is the seed.

After load phase finishes, `BUILD_FILES` is closed: it is the universe of source files baked into the binary.

### 3. Execute phase: closed-world enforcement

Before emission, walk the execute-phase AST and **fail hard** at compile time on any of these:

- **`require 'x'` / `require_relative 'x'` / `load`**:
  - Resolve `x` to a candidate full path the same way Ruby would (`$LOAD_PATH` search for `require`, calling-file directory for `require_relative`).
  - If candidate ∈ BUILD_FILES → emit no-op (a tiny `$LOADED_FEATURES`-aware check returns `false` like idempotent require, matching Ruby semantics). The runtime call is harmless.
  - If candidate ∉ BUILD_FILES → fail at compile time: `"runtime require for file not in build: <x> at <file>:<line>"`.
- **Class / module / method / top-level const defs in execute phase**: should not appear (the splitter would have caught them); if they do (e.g. user wrote `class Foo` inside a method body), fail hard.
- **`defined?(X)` / `const_defined?`**:
  - If X is in the closed-world class/const table → fold to `true` at compile time.
  - If X is not → fold to `false` with a warning, OR fail hard (configurable). Default: fail hard (the user almost always didn't mean it).
- **`define_method` / `define_singleton_method` / `alias_method` / `undef_method` / `remove_const` / `const_set`**: fail hard unless the call's effect is provably load-time-only (rare). The augmented interpreter's load-phase pass already executed these where applicable.

### 4. Why this works

- **Eager-load is safe by default**. Every branch's class/method definitions are present in the closed world; flags surface imprecision.
- **Idempotent runtime require pattern works**. `require 'json' unless defined?(JSON)`:
  - If JSON is in BUILD_FILES → `defined?(JSON)` folds to `true` at compile time → `unless true` removes the require → no-op. Ruby semantics preserved.
  - If JSON isn't in BUILD_FILES → fail hard. User has to either (a) include json in the build by triggering it from load phase, or (b) refactor.
- **Closed-world contract is explicit**: after the split point, the class/method/file universe is fixed. The runtime binary cannot grow it.
- **Fail-hard catches real bugs**. A `require` for a file that wasn't eagerly loaded means the user forgot to include it OR the condition depends on AOT-time environment data — both deserve loud signal, not silent fallthrough to a runtime error.

### 5. What this still does NOT solve

- **Build-flag-driven definitions** (`if ENV['DBG']; class DebugTrace; end`): augmented interpreter flags but the user must decide which path to commit to. The compiler can't know which the runtime want; the contract requires this be resolved at build time.
- **Cross-version compatibility shims** (`if RUBY_VERSION >= '3.4'; ...`): same shape — flag, user picks.
- **Runtime-loaded plugins** (`Dir.glob('plugins/*').each { |f| require f }`): fundamentally violates closed-world. User has to enumerate explicitly.

These cases are where the user pays for closed-world AOT directly: it gives ahead-of-time guarantees in exchange for ahead-of-time decisions.

## Implementation order

The first two steps are the closed-world enforcement minimum; (3)–(5) tighten diagnostic precision.

1. **BUILD_FILES collection during eager-load**. Wire from FILE_REALPATH_CACHE (or comparable per-load tracking). Surface as `Frozone::Vm::Vm#build_files`.
2. **Execute-phase pre-emission AST walk**. Reject:
   - require / require_relative / load whose candidate path is not in BUILD_FILES (hard fail with file:line);
   - class / module / method / top-level const defs that survived into execute phase (hard fail).
   The compiled gen never gets emitted if violations are found.
3. **`defined?` constant-folding** using closed-world class/const table. For folded `true`, the surrounding `if` / `unless` simplifies and the require call is dropped.
4. **Augmented-interpreter flagging** for environment reads and conditional defs. Reports collected during load phase; user decides which to fix.
5. **Eager-load of conditional branches** containing class / require / method / const definition effects. Treat them as load-phase regardless of condition.

Performance-cost note: this all runs at AOT time, not in the produced binary. The runtime binary just gets cleaner code and earlier failures.

## Open questions

- **Conditional require where the right answer depends on per-build configuration** (e.g. the `frozone.rb --parser=wq` switch). Likely solution: a build-config file (or env var) read by the load-phase splitter that fixes which branches to take. Currently both-branches-eagerly is the simplest default; the "pick one" model is a follow-up.
- **`autoload`**: under closed-world, every autoload registration becomes an unconditional `require`. Implementation is straightforward but enumerating autoloads requires scanning all classes after load.
- **Frozen-string warnings, deprecation notices, etc. in load phase**: these are typically harmless side effects but the augmented interpreter should categorize them as benign vs flag-worthy.

## See also

- `feedback_fail_early_compiler.md` — the project-wide stance that informs the fail-hard defaults here.
- `feedback_uniform_lambda_lowering.md` — analogous "Ruby semantics first; pay the cost where it falls; optimize later" attitude.
- `bench/stubs/wq_parse_rich.rb` — was the immediate motivation; its 8/8 success demonstrated the runtime-side machinery, which now needs the load/execute discipline to scale to compiling Frozone itself.

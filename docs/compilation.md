# Frozone AoT Compiler

Frozone compiles Ruby to native binaries via [Crystal](https://crystal-lang.org/)
(which compiles through LLVM).
Numeric benchmarks run **13–95× faster than YJIT**; closed-world optimisations
like `respond_to?` constant folding achieve **540× faster than MRI**.

| Highlight | vs MRI | vs YJIT |
|-----------|--------|---------|
| fib(20) | 22× | 13× |
| nbody 20k | 95× | 33× |
| attr_accessor 50K | 72× | 72× |
| loops_times | 73× | 18× |
| respond_to? (6M calls) | 540× | 50× |

Full benchmark table in [README.md](../README.md).

## How it works

The approach is **closed-world ahead-of-time (AoT) compilation** targeting
Crystal as an intermediate language. This is deliberately different from JIT
and general AoT — the differences are worth understanding.

**The key architectural insight — split load and execute:**
Most Ruby programs have two naturally distinct phases: a *load phase* where
classes are defined, modules included, gems initialised, and DSLs evaluated;
and an *execute phase* where the actual work happens. The Frozone compiler
exploits this split: the **Frozone interpreter runs the load phase normally**,
handling all dynamic Ruby (`define_method`, `include`, DSL evaluations,
everything). Once the load phase is complete and the object model is fully
settled, the compiler **snapshots that state as the closed world** and
translates it to Crystal. The execute phase then runs as a native binary with
no interpreter overhead. This means the closed-world constraint applies only
to the execute phase — which well-written programs, and Rails apps in
production mode, already satisfy.

---

### Closed-world AoT vs JIT

A **JIT compiler** (like YJIT in MRI, or TruffleRuby's Graal backend) compiles
Ruby at runtime, inside a running interpreter. It observes actual types at
runtime (type profiling), generates native code for hot paths, and falls back
to the interpreter for cold or polymorphic paths. The full Ruby object model
remains available at runtime — `eval`, `define_method`, `class_eval`, dynamic
`const_set` all work exactly as in the interpreter. JIT is maximally compatible
but requires a complete interpreter as a foundation, is complex to implement
correctly, and the generated code must handle deoptimisation (falling back to
the interpreter when type assumptions are violated).

A **closed-world AoT compiler** takes a fixed snapshot of the entire program
at compile time and compiles everything in one shot. There is no interpreter
fallback, no runtime deoptimisation, no type profiling. What you gain is:

- **Simpler implementation** — no runtime type profiling, no deoptimisation
  machinery, no interpreter to maintain in parallel
- **Better peak performance** — the compiler can make global optimisations
  that a JIT cannot (Crystal's own type inference does this for us for free)
- **Smaller runtime** — no interpreter overhead in the binary
- **Predictable performance** — no JIT warm-up, no GC pauses from code
  compilation, no tier transitions

What you give up:

- **Dynamic features** — `eval` with runtime strings, fully dynamic
  `define_method`, `class_eval` with strings, `method_missing` as a catch-all
  for truly unknown methods (see below for how each is handled)
- **Incremental loading** — you cannot `require` a file at runtime that wasn't
  part of the closed world at compile time
- **Compatibility** — some Ruby programs genuinely require dynamic features
  and simply cannot be compiled; others use dynamic features in ways that are
  statically analysable (the common case)

---

### The closed-world assumption

The **closed-world assumption** is the central constraint: at compile time, the
compiler sees the complete set of classes, modules, methods, and constants that
will ever exist. Nothing new is defined at runtime.

In practice this means:
- All `require` calls are resolved at compile time; every loaded file is part
  of the closed world
- Class/module definitions are final — `class Foo` opens Foo exactly the set
  of times visible in the source
- Method definitions are final — no `define_method` with a runtime-computed
  name, no `method_missing` as an open-ended proxy (it can appear in the
  source but must be handled specially)
- Constants are effectively immutable after the program starts

This rules out some Ruby idioms (metaprogramming-heavy DSLs, plugin systems
that load code at runtime) but covers the overwhelming majority of real Ruby
programs, including Frozone itself.

---

### Why Crystal as the intermediate language

Rather than generating bytecode or machine code directly, Frozone compiles
Ruby to Crystal source. Crystal then takes it from there. This is sometimes
called **transpilation** or using Crystal as a *pretty-printer backend*.

The key insight is that Crystal *is* Ruby with a static type system bolted on.
Its syntax is almost identical; its semantics (classes, modules, inheritance,
blocks, closures, exceptions) map directly to Ruby's. A Ruby `class Foo < Bar`
becomes a Crystal `class Foo < Bar`. A Ruby `def foo(x); x + 1; end` becomes
a Crystal `def foo(x); x + 1; end`. The structural transformation is trivial.

The **hard parts of compilation** — type inference, optimisation, register
allocation, native code generation, garbage collection — are all handled by
`crystal build`. We get a world-class optimising compiler for free.

The **new work** is the semantic layer: closed-world analysis, the proxy class
hierarchy (`RubyObject` and friends), ivar scanning, `respond_to?` bitsets,
constant resolution. This work is required regardless of backend and is not
wasted if a different backend (LLVM IR, bytecode VM) is added later.

---

### The split strategy: load → compile → execute

The closed-world requirement sounds strict, but most Ruby programs — including
Rails apps — already have a natural two-phase structure:

1. **Load phase:** `require` files, define classes and modules, include
   modules, run class-level code. DSLs fire, `attr_accessor` expands, gems
   register themselves, configuration is evaluated.
2. **Execute phase:** do the actual work — handle requests, process jobs,
   run the main loop.

The split strategy exploits this:

```
Ruby source
    ↓  (Frozone interpreter — load phase runs normally)
Stable object model  ← closed world snapshot point
    ↓  (CrystalCodegen — compile the snapshot)
Crystal source
    ↓  (crystal build)
Native binary  ← execute phase runs here at full speed
```

**The Frozone interpreter runs the load phase.** All the dynamic Ruby that
makes metaprogramming work — `define_method`, `class_eval` with blocks,
`include`, `extend`, `attr_accessor` expansion, DSL method definition — happens
exactly as it does today in the interpreter. The interpreter's job is to fully
evaluate the load phase and produce a stable, settled object model.

**The compiler snapshots the result.** At the snapshot point, all classes,
modules, methods, and constants are known. This settled state IS the closed
world. The compiler translates it to Crystal. Dynamic method definitions from
the load phase appear as ordinary `def` statements in the Crystal output —
the compiler never has to understand what `has_many` means; it just sees the
methods it produced.

**The execute phase runs natively.** No interpreter in the loop. The binary
links against the `crystal/` runtime library and runs at full Crystal speed.

**When is load "done"?** For a simple script it is obvious: the top-level
statements run sequentially and there is no distinction. For a server
application, the snapshot point is after all initialisation is complete and
before the main event loop starts. For Rails this is after
`Rails.application.initialize!` returns. Frozone would call a user-defined
hook (or detect the end of `require`-time execution) to trigger the compile.

This strategy makes the closed-world constraint much less restrictive in
practice. The constraint applies only to the *execute phase* — and well-written
applications are largely static by then.


### Rails — the raison d'etre

Ruby's rise is inseparable from Rails. If the Frozone compiler cannot compile
Rails apps, or at least a large fraction of them, it is an interesting
research project rather than a practical tool. So it is worth understanding
Rails carefully.

**The good news: Rails production mode is already eager and static**

Rails has two loading modes:
- **Development mode:** files are loaded lazily via Zeitwerk as constants are
  first referenced. Classes can be reloaded between requests. Very dynamic.
- **Production mode** (`config.eager_load = true`): all files are loaded
  upfront before the first request via `Rails.application.eager_load!`. After
  `Rails.application.initialize!` returns, the object model is fully settled
  and does not change during request handling.

The Frozone compiler targets production mode. The split strategy's snapshot
point is after `initialize!`. In this mode, Rails already behaves like a
closed world for the execute phase.

**Metaprogramming at load time — handled by the interpreter**

Rails' DSL is metaprogramming-heavy but all of it fires at load time:

```ruby
class Post < ApplicationRecord
  has_many :comments           # → define_method :comments, :comments=, ...
  belongs_to :user             # → define_method :user, :user=, :user_id, ...
  scope :published, -> { where(published: true) }  # → defines .published
  validates :title, presence: true
  before_save :normalise_title
end
```

Under the split strategy, the Frozone interpreter evaluates all of this during
the load phase. `has_many :comments` fires, `define_method` runs, and the
resulting methods are added to the `Post` class object. By the snapshot point,
`Post` has concrete `#comments`, `#comments=`, `#user`, `#user=` etc. methods.
The compiler sees ordinary methods and translates them as such. It never needs
to understand what `has_many` means.

Concerns/validations/callbacks become arrays of proc objects stored in class
ivars, exactly as they are in MRI. The interpreter captures this state; the
compiler preserves it.

**Database schema discovery**

ActiveRecord discovers column types from the database at load time:
`Post.column_names` returns the actual columns of the `posts` table. This
means the closed world depends on the DB schema.

In practice this is already solved by Rails itself: `db/schema.rb` is the
authoritative schema definition, committed to the repository, updated after
every migration. The Frozone compiler reads `db/schema.rb` at compile time
to determine column types — no live database connection needed.

The recompilation trigger is: any time `db/schema.rb` changes (i.e., after a
migration), rebuild the compiled binary. This is the same trigger as
`bundle install` (Gemfile.lock changes → rebuild). CI/CD handles it naturally.

**Zeitwerk autoloading**

Modern Rails uses Zeitwerk for autoloading. In production mode,
`Rails.application.eager_load!` calls Zeitwerk's `eager_load` which walks
the autoload paths and `require`s every file. By the snapshot point, all
application classes are loaded. Zeitwerk's autoloading machinery is not needed
in the compiled binary — it is a load-phase tool.

**Request-time concerns**

After the snapshot point, a Rails app handling requests should be essentially
static. Some areas to audit:

| Pattern | Status | Mitigation |
|---------|--------|-----------|
| `has_many`/`belongs_to` | Load time only ✓ | Interpreter handles it |
| `scope` definitions | Load time only ✓ | Interpreter handles it |
| `validates`/`callbacks` | Load time only ✓ | Interpreter handles it |
| Zeitwerk autoloading | Production eager-loads ✓ | Full load before snapshot |
| DB schema discovery | `schema.rb` at compile time ✓ | No live DB needed |
| `method_missing` for `find_by_*` | Removed in Rails 6 ✓ | N/A |
| Some gems using `class_eval` per request | Rare ⚠ | Audit required |
| `Kernel#pp` / `ObjectSpace` in gems | Development only ⚠ | Strip from compiled binary |
| Hot reloading | Development only — not a target | Compiled = production |

Modern Rails (>= 6 with Zeitwerk) is cleaner than old Rails. The main risk is
third-party gems that do request-time class manipulation — these need to be
audited. Most popular gems (Devise, Pundit, Sidekiq, ActiveJob) are
load-time-only and will work correctly.

**Rails as the ultimate correctness test**

Just as Frozone's self-compilation (compiling the interpreter itself) is the
correctness test for the compiler infrastructure, compiling a real Rails app
is the correctness test for the split strategy and the full closed-world
approach. A "hello world" Rails API app with a single model and controller
is a realistic near-term target:

```
bundle exec frozone compile --mode=rails app/
    → snapshot after Rails.application.initialize!
    → Crystal codegen
    → crystal build
    → ./myapp  (handles requests, 0 interpreter overhead)
```

This would be a significant result.


### Limitations and non-goals

| Feature | Status |
|---------|--------|
| `eval(string)` | Prohibited or handled via static-interpolate analysis |
| `require` at runtime | Not supported; all files compiled together |
| `define_method` with runtime name | Not supported |
| `class_eval` / `module_eval` with string | Not supported |
| `method_missing` as open-ended proxy | Requires generated `case` dispatch |
| `send` with dynamic string | Requires generated `case` dispatch |
| `const_get` with dynamic string | Requires generated `case` dispatch |
| Threads | Crystal fibers; cooperative model preserved |
| Bignum arithmetic | `RubyInteger` wraps Crystal's `BigInt` |
| Encoding | Crystal's PCRE2 regex (vs Oniguruma); common subset identical |
| `ObjectSpace` | Not available (no interpreter object graph) |
| Continuations / `callcc` | Not supported |

The first compilation target is **Frozone itself** — if the Frozone interpreter
compiles cleanly under these constraints, we have high confidence the approach
is sound for real-world programs.

---


## `Frozone.compile!` — the working pipeline (as of 2026-03)

The snapshot-based compilation pipeline is implemented and working end-to-end.

### The stub pattern

A bench stub:
```ruby
# bench/stubs/matmul.rb
$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end          # silence harness during load phase
require_relative '../benchmarks/matmul'   # settles methods and constants

Frozone.compile! do
  run_benchmark(20) do
    a = matgen(N)
    b = matgen(N)
    _c = matmul(a, b)
  end
end
```

Running through the Frozone interpreter generates Crystal source; `crystal
build` then produces a native binary:

```bash
bundle exec ruby frozone.rb bench/stubs/matmul.rb
# => Frozone.compile!: wrote crystal/matmul.cr
cd crystal && crystal build matmul.cr -o matmul && ./matmul
```

### `SnapshotCodegen` — VM-state-driven Crystal emission

`lib/frozone/compiler/snapshot_codegen.rb` inherits from `CrystalCodegen`
(AST-to-Crystal expression emitter) and adds a top-level driver that walks the
*settled VM state* rather than raw source AST:

1. Walk `Vm::Core::OBJECT_CLASS`'s constant and method tables
2. Filter by `source_location` — exclude `lib/core/4.0/` and `lib/frozone/`
   (these map to the Crystal runtime in `crystal/src/`) and the stub file itself
3. Emit user-defined classes (with their user-defined methods)
4. Emit user-defined top-level methods
5. Emit settled non-class constants (e.g. `N = 200` → `Ruby_N = RubyInteger.new(200_i64)`)
6. Emit the `Frozone.compile!` block body as Crystal `main`

`Vm::Method` duck-types as `Ast::MethodDef` (same ivar names), so
`emit_param_list` works on VM method objects directly.

### The Crystal runtime (`crystal/src/`)

The current runtime provides fully-boxed Ruby value types:

| Crystal class | Ruby type |
|---|---|
| `RubyObject` | abstract base (all values) |
| `RubyInteger` | Integer (wraps `Int64`) |
| `RubyFloat` | Float (wraps `Float64`) |
| `RubyString` | String |
| `RubySymbol` | Symbol |
| `RubyArray` | Array |
| `RubyHash` | Hash |
| `RubyNil` | NilClass (singleton `RUBY_NIL`) |
| `RubyBool` | TrueClass/FalseClass (singletons `RUBY_TRUE`/`RUBY_FALSE`) |
| `RubyRange` | Range |
| `RubyClassProxy` | class objects (for `.class`, `.is_a?`, etc.) |

### Benchmark results (matmul, N=200)

| | ms/iter |
|---|---:|
| Frozone interpreted | ~31,700 |
| Frozone→Crystal compiled (fully boxed) | 2,758 |
| MRI Ruby | 524 |

The compiled path is ~11.5x faster than interpreted with zero type
optimisation. Every integer and float is heap-allocated as a `RubyObject`;
unboxing is the main remaining performance work.


## Type inference

### Overview

The compiler has two complementary type inference layers:

1. **Whole-program TypeInference** (`lib/frozone/compiler/type_inference.rb`,
   ~1100 lines) — forward dataflow analysis over the settled VM state.
2. **Method-body literal inference** (`infer_local_types` in
   `snapshot_codegen.rb`) — fixed-point pass seeding types from literal
   assignments.

Both run before code emission. Their results are unpacked into codegen lookup
maps that drive all downstream optimisations.

### Type lattice

The TI uses a type lattice where lower = more specific:

```
:unknown                   — bottom (not yet analysed)

:i64  :f64                 — unboxed Crystal numerics
:array_i64  :array_f64     — typed arrays (Array(Int64), etc.)
{class: :Node}             — user-defined class instance
{class: :Integer}          — boxed Integer (wider than :i64)
{class: :Array, elem: ...} — Array with element type
{class: :Object}           — top of Ruby hierarchy
```

`meet(a, b)` computes the LCA (least common ancestor) by walking the VM's
class hierarchy. Unboxed types widen to their boxed class before LCA:
`meet(:i64, :f64)` → `{class: :Numeric}`. `:unknown` is the identity.

### Slots

Everything the TI tracks is a "slot" — a `[kind, context, name]` tuple:

| Slot | Example | Meaning |
|------|---------|---------|
| `[:local, :fib, :n]` | local `n` in method `fib` | Variable type |
| `[:local, nil, :a]` | local `a` in execute block | Variable type |
| `[:param, :fib, 0]` | first param of `fib` | Inferred param type |
| `[:return, :fib]` | return value of `fib` | Return type |
| `[:ivar, :Planet, :@x]` | ivar `@x` of class `Planet` | Instance variable type |
| `[:const, :N]` | constant `N` | Constant type |
| `[:array_elem, :solve, :cr]` | array `cr` in `solve` | Element type |
| `[:block_param, :solve, :i]` | block param `i` | Block param type |

### Fixed-point iteration

The TI runs 3 iterations (configurable):

**Round 1** — seed from literals, propagate through immediate arithmetic:
- Integer/float/string/nil/true/false literals → precise types
- `x = 1 + 2` → `x` is `:i64`
- Method calls with typed args → typed params → typed returns
- Ivar assignments from constructor params → typed ivars

**Round 2** — return types feed callers:
- `fib(n)` returns `:i64` → callers of `fib` now see `:i64` at call sites
- Array element types propagate through `Array.new(n) { block }`

**Round 3** — one more hop for recursion / indirect propagation:
- Recursive methods see their own return type
- Transitive type flow stabilises

### How results flow into codegen

After TI runs, `SnapshotCodegen.run_type_inference` unpacks the slot map into
per-flag lookup structures:

| TI slot → | Codegen map | Gated by flag |
|-----------|-------------|---------------|
| `:local` scalars | `@ti_locals` → `@typed_locals` | `unbox_locals` |
| `:local` classes | `@ti_class_locals` → `@current_class_locals` | `devirtualize` |
| `:local` arrays | `@ti_local_array_elems` | `native_arrays` |
| `:param` | `@inferred_params` | `call_site_types` |
| `:return` | `@typed_method_returns`, `@instance_method_raw_returns` | `method_specialization`, `raw_returns` |
| `:ivar` | `@typed_ivars` | `typed_ivars` |
| `:array_elem` | `@ti_arrays` → `@typed_array_locals` | `native_arrays` |
| `:block_param` | `@ti_block_params` | `native_iteration` |
| `:const` | `@const_raw_types` | `unbox_locals` |

Each flag gates whether its map is populated; when the flag is off, the map
stays empty and the optimisation naturally doesn't fire.

### Self is a strong clue

When emitting a method defined on class `Foo`, `self` is always *at least*
`Ruby_Foo` — and for leaf classes (no subclasses in the closed world), `self`
is *exactly* `Ruby_Foo`. This makes instance variable types directly inferable
from the class definition without a general type inferencer:

- `initialize` fixes ivar types: `@x = x * DAYS_PER_YEAR` where `x : Float64`
  → `@x : Float64`
- Methods on a leaf class can emit `@x` as `Float64` directly — no
  `RubyObject` boxing needed for the ivar load or store

For non-leaf classes, `self` is a `Ruby_Foo | Ruby_Bar | ...` union — Crystal's
type inference handles this naturally once the types are emitted correctly.

**Literals are always exact:**
- `1`, `200`, `-1` → `Int64`
- `1.0`, `0.01` → `Float64`
- `"string"` → `RubyString`
- `true`/`false`/`nil` → `RubyBool`/`RubyNil`

**Return types of known methods:**
- `Integer#+`, `Integer#*`, etc. → `Int64` when both args are `Int64`
- `Float#+`, `Float#*`, etc. → `Float64` when both args are `Float64`
- `Array#length`, `Array#size` → `Int64`

### The inference algorithm (implemented)

Type inference is implemented in two complementary layers:

1. **Whole-program TypeInference** (`type_inference.rb`): forward dataflow
   over the settled VM state. Tracks locals, params, ivars, returns, array
   elements, and constants as a type lattice (`:unknown` → class-typed →
   scalar `:i64`/`:f64`). Three fixed-point iterations. Results are unpacked
   into per-flag codegen lookup maps.

2. **Method-body literal inference** (`infer_local_types`): fixed-point
   pass over method ASTs seeding types from literal assignments, then
   propagating through arithmetic and local variable assignments.

The combined inference enables 13 optimisation passes (see
`docs/optimisations.md`) producing 10-200x speedups over unoptimised
output on numeric benchmarks.

### Achieved payoff

For numeric benchmarks, the inner loops reduce to native `Int64`/`Float64`
arithmetic with no allocation. Results (Crystal `--release` vs MRI):

- fib(20): **22x faster than MRI**, 13x faster than YJIT
- nbody: **95x faster than MRI**, 33x faster than YJIT
- loops_times: **73x faster than MRI**, 18x faster than YJIT
- attr_accessor: **72x faster than MRI/YJIT**

Mixed benchmarks (binarytrees, sudoku) are 3-9x faster than MRI.
Object-heavy benchmarks (splay) remain slower than YJIT due to
Crystal's union dispatch overhead vs YJIT's inline caches.

---

## Compiled spec testing

The `--aot` flag enables compiling spec-like files without source modification:

```bash
frozone --aot bench/specs/language_spec_small.rb          # auto-detect load/execute boundary
frozone --aot -r bench/test_harness.rb some_spec.rb       # pre-load test harness
```

A minimal mspec-compatible test harness (`bench/test_harness.rb`) provides
`describe`/`it`/`should` for compiled specs. 35+ tests pass through
compilation (Array, Integer, String, language constructs, respond_to?, is_a?).

### Next steps for compiled spec coverage

- **instance_eval support** — needed for real mspec (blocks run with rebound self)
- **Broader Ruby constructs** — exception handling, more class patterns
- **Real ruby-spec files** — the goal is `frozone --aot` on actual ruby-spec files

---

## Future compiler ideas

### Compile-time erasure: `respond_to?`, `is_a?`, `send`

Three of Ruby's most-called reflective methods can be resolved at compile time
in the closed world.

**`respond_to?` — per-class bit array**

1. Collect all method names across all classes → assign each a unique index (0..N).
2. Per class, emit a compact bit array of size N — bit `i` is set if that class
   has method `i`.
3. Each method-name Symbol carries its index as a cached field (interned
   singletons, so one extra integer per unique method name).
4. `obj.respond_to?(:foo)` compiles to `self.class.respond_to_table[foo.method_index]`
   — O(1), no string comparison, no hash lookup.
5. With a literal symbol argument AND known receiver type, the compiler can
   **constant-fold** the entire call to `true` or `false` — zero runtime cost.

**`is_a?` — same technique**

1. Collect all classes/modules → assign each a unique index.
2. Per class, emit a bit array of "is this class/module in my ancestor chain?".
3. `obj.is_a?(Foo)` compiles to `self.class.isa_table[Foo.class_index]` — O(1).
4. With a literal class AND known receiver type → constant-fold.

**`send(:method_name)` — direct call erasure**

`send` with a literal Symbol argument can be replaced with a direct method call
at compile time. The compiler knows the method exists (closed world), knows
visibility, and can emit the direct call — eliminating the dynamic dispatch
overhead entirely. This is particularly valuable in `lib/core/4.0/` where `send`
is used to call private methods (e.g., `n.send(:coerce, self)` in Integer).

**Impact:** The `respond_to` benchmark (6M calls) compiles to 0.3ms with constant
folding — 540x faster than MRI, 50x faster than YJIT. All `respond_to?` calls
resolve to `true`/`false` at compile time.

### Module flattening

At compile time, resolve all `include`/`prepend` into concrete per-class method
tables. The interpreter keeps the real module hierarchy; the compiler flattens
before emission. Benefits: simpler TI (no module lookup chains), unambiguous ivar
ownership, handles Crystal's lack of prepend support. Kernel methods map to the
Crystal runtime, so duplication explosion is limited to user-defined modules.

### String encoding specialization

Most Ruby programs use UTF-8 or ASCII-8BIT exclusively. TI can track string
encoding through the program. For ASCII-only strings: `length == bytesize`,
`reverse` is byte reversal, `[]` is byte indexing, `==`/`<=>` are raw byte
comparisons. Eliminating encoding guards from hot paths enables direct Crystal
`Bytes` operations with no `RubyString` wrapper overhead.

---

For detailed pre-implementation design exploration (dispatch architecture,
singleton classes, vtable analysis, eval strategies, constant lookup, etc.),
see [compilation-design-notes.md](compilation-design-notes.md).

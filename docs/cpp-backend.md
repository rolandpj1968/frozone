# C++ Backend

Frozone has two parallel AOT compiler backends: **Crystal** (the primary
production path) and **C++** (exploratory, invoked via `FROZONE_CPP=1`).

```bash
# Generate C++ source + build + run
FROZONE_CPP=1 bundle exec ruby frozone.rb --aot bench/stubs/fib.rb
g++ -O2 -std=c++20 cpp/gen/fib.cpp -o cpp/gen/fib
./cpp/gen/fib

# Or run the whole benchmark suite through the C++ backend
bundle exec rake bench_cpp
```

## Status

**20 of 24 benchmarks pass** end-to-end. The gap versus Crystal is narrow
and feature-scoped:

| Benchmark | Status | Blocker |
|-----------|--------|---------|
| setivar | MISMATCH | Ruby nil vs int64_t 0 — would need variant-typed locals |
| splay | FAIL | Hash literals, string interpolation, MT19937 exact-match, heterogeneous return types |
| structaset | FAIL | `Struct.new` generates methods with `Vm::DefinedMethod` bodies not yet emitted |
| blurhash | FAIL | `module` emission (modules as namespaces), nested modules, `File.read` load-time I/O |

Per-benchmark wall-clock vs Crystal `--release` (both AOT, compute-heavy vs
allocation-heavy split):

| Bench | C++ -O2 | Crystal | Winner |
|-------|--------:|--------:|--------|
| fib | 0.03s | 0.09s | **C++ 3.0×** |
| matmul | 0.04s | 0.25s | **C++ 6.2×** |
| nqueens | 4.97s | 6.54s | **C++ 1.3×** |
| loops_times | 0.10s | 0.14s | **C++ 1.4×** |
| binarytrees | 4.09s | 2.00s | Crystal 2.0× |
| str_concat | 2.78s | 1.00s | Crystal 2.8× |

C++ wins compute-heavy (`std::shared_ptr` atomic refcount doesn't kick in);
Crystal wins allocation-heavy (Boehm GC amortises better than per-object
refcount traffic). For most compute benchmarks the runtime is within noise.

## Why a second backend?

The original roadmap (see [backend strategy memory](../.claude/projects/-home-rolandpj-src-frozone/memory/project_backend_strategy.md)) had Crystal as the bootstrap backend and LLVM IR as the eventual target. C++ landed as a **pragmatic intermediate**.

### Crystal friction points

Crystal's type system imposes constraints the closed-world Frozone type
inference can see around but can't *tell* Crystal about. Each such mismatch
burns codegen complexity. Examples:

| Category | Crystal constraint | Frozone TI knows better |
|----------|-------------------|------------------------|
| Return type unions | All subtypes in `RubyObject+` must have compatible return types | Concrete type at each call site |
| Block capture | `break` illegal in captured `&block`; only in `yield` blocks | Iteration pattern (loop vs each) is known |
| Constant resolution | `::` is strict lexical, no ancestor walk | Module erasure + full ancestor chain |
| Primitive type width | `Int32` for `<=>`, `Bool` for `==` | Track `RubyInteger`/`RubyBool` uniformly |
| Nullable ivars | Can't flow-narrow `@ivar` through if-checks | Control-flow guarantees known |
| Int32/UInt64 | Literal `0` ambiguous between overloads | Exact type at each use known |
| Exception hierarchy | `message : String?` forced on Exception subclasses | Our exceptions have `RubyObject` messages |
| Bool/RubyBool | Crystal methods return `Bool`, ours return `RubyBool` | Uniform `RubyBool` everywhere |

`codegen.rb` + `crystal_emitter.rb` + supporting files total ~5000 LOC,
a significant fraction of which is working around these mismatches.

### Why C++ (not LLVM IR)

- **Same optimiser as Crystal** (LLVM, via Clang/GCC) — no perf left on the table.
- **Our own type system** via C++20 templates. No union-dispatch limits,
  no `Int32`-for-`<=>`, no nullable-ivar flow-narrowing.
- **Full header-only runtime** via `<memory>`, `<vector>`, `<charconv>`,
  `<cstdint>` — no runtime library to write and maintain.
- **Faster iteration** than LLVM IR — no ABI boilerplate, no runtime
  primitives reimplementation, C++ stdlib gives us vectors/shared_ptrs/strings.
- **~1000 lines of emitter** (`cpp_emitter.rb`) vs estimated 5-10× for
  LLVM IR. Easier to prototype, easier to throw away if it doesn't work out.

## Architecture

### User class lowering

Ruby user classes are emitted as shared_ptr-wrapping value types:

```cpp
struct Ruby_Planet {
  struct Impl {
    double iv_x, iv_y, iv_z;
    double iv_vx, iv_vy, iv_vz;
    double iv_mass;
  };
  std::shared_ptr<Impl> p;

  Ruby_Planet() = default;                     // nil (or 0-arg initialize)
  Ruby_Planet(const RubyNil&) {}               // implicit nil conversion
  Ruby_Planet(auto x, auto y, auto z, /*...*/) // main initialize
    : p(std::make_shared<Impl>()) {
    p->iv_x = x;  p->iv_y = y;  p->iv_z = z;
    // ...
  }
  // methods access ivars via p->iv_*
  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
```

Copying the wrapper aliases Impl via `shared_ptr` — Ruby's object-reference
semantics drop out naturally. `b = bodies[i]; b.set_x(v)` mutates the shared
element. Self-referential ivars (`Node.@left` of type `Ruby_Node`) store as
`shared_ptr<Impl>` with auto wrap/unwrap via constructor and conversion
operator overloads.

### Type inference

Lightweight TI without Frozone's main `TypeInference` engine (which is
Crystal-tuned). A 3-iteration fixpoint over:

- `@_class_ivar_types` — per-class ivar types inferred from all assignments.
- `@_class_method_return_types` — per-class method return types from
  `infer_method_return_type` (walks explicit returns).
- `@_top_level_method_return_types` — same for free functions.
- `@_ctor_param_types` — call-site arg types for each class's constructor.
- `@_method_call_arg_types` — call-site arg types per method name (setters
  propagate to ivars: `node.left = other` infers `@left: Ruby_Node`).

`local_decl_type` dispatches on AST node type:
- Literals (Float/String/True/False) → obvious primitive
- `Or`/`And` → right-operand type (typical `x || @default`)
- `LocalVariableRead` → look-ahead to writes in method body
- `InstanceVariableRead` → `@_class_ivar_types` lookup
- `MethodCall` on known receiver class → `@_class_method_return_types`
- `ArrayLiteral` → `RubyArray<elem_type>`
- Recursion-depth guard (max 5) to break cycles

### Local hoisting

Matches Ruby's method-wide local scope against C++'s block scope:

- Known primitive/class type → `TYPE name = default;` at method top
- Unknown but decltype-safe RHS → `std::decay_t<decltype(rhs)> name{};`
- Otherwise falls through to per-site `auto name = expr;`

This lets `tmp = current.left` inside a nested `if`-branch remain visible
outside that branch (where Ruby would see it but C++ wouldn't).

### Runtime

Minimal C++ header in every generated file:

- `RubyNil` — universal-convertible sentinel (implicit conversion to
  int64_t/double/bool/RubyString/shared_ptr<T>/any T via fallback template)
- `RubyString` — `vector<uint8_t>`-backed mutable byte string (ord, bytesize,
  get_byte/set_byte, operator<<, comparisons, dup_)
- `RubyArray<T>` — `shared_ptr<vector<T>>` (cheap copy, growable via `<<`;
  supports `.dup_()`, `.delete_at()`, `.insert()`, `.slice_assign()`, `.join()`)
- `RubyTree` — shared-ownership binary tree (for 2-element ArrayLiterals
  that look like tree nodes via heuristic — binarytrees)
- `Ruby_Object` — empty placeholder for `Object.new`
- `Ruby_Random` — MT19937 stub matching Ruby's 53-bit `.rand()` format
- `ruby_class_name<T>()` / `ruby_class(x)` — `.class` dispatch via templates
- `ruby_to_s<T>(v)` — `.to_s` for primitives
- `ruby_puts<T>(v)` — Ruby-format output (shortest round-trip for floats,
  `true`/`false` for bool, `[e1, e2]` for arrays)
- `ruby_nil_q(x)` — type-dispatched nil check
- `ruby_range_to_a(lo, hi, exclusive)` — `(0..n).to_a` emission target

## Known gaps

- **Modules** — `module Blurhash; def self.foo; end; end` needs namespace
  emission (or flat prefixed names with lexical scope resolution).
  Blocks blurhash.
- **Hash literals** — `{a: 1, b: 2}`. Needs a RubyHash runtime and type
  inference. Blocks splay (inner), would help wider Ruby programs.
- **String interpolation** — `"prefix #{expr}"` concatenation with to_s.
- **Variant locals** — `last = nil; last = int; last = string` would need
  a tagged-union local type. Matters for setivar's nil-printing.
- **Struct.new** — auto-generates a class whose methods are
  `Vm::DefinedMethod` (closures over field indices). Our emitter walks
  `Vm::Method` bodies only.
- **MT19937 exact matching** — stub is algorithmically close but not
  byte-identical to Ruby's RNG. Matters for splay's exact-match output.

## When to switch to LLVM IR

The C++ backend has been ergonomic through 20 benchmarks. It will hit
one of:

- A Ruby feature that doesn't fit C++ templates cleanly (true method-
  missing, fully dynamic receiver dispatch)
- Performance requirements where `std::shared_ptr` atomic refcount is the
  bottleneck (hot allocation paths like binarytrees-at-scale)
- Complexity exceeding what a focused emitter can support (~2000 LOC?)

At that point LLVM IR becomes the target. The front-end
(parser → AST → TI → module erasure) stays identical; only the emitter
changes. Until then, C++ is buying substantial runway with a fraction of
the cost of a real IR emitter.

## Files

- [`lib/frozone/compiler/cpp_emitter.rb`](../lib/frozone/compiler/cpp_emitter.rb) — ~2000 LOC emitter
- [`cpp/gen/`](../cpp/gen/) — generated `.cpp` files (binaries gitignored)
- [`bench/stubs/`](../bench/stubs/) — benchmark stubs run through the emitter
- [`Rakefile`](../Rakefile) — `rake bench_cpp` task runs all 24 benchmarks

# C++ Backend

Frozone has two parallel AOT compiler backends: **Crystal** and **C++**.
Both generate native binaries from the same front-end (parser, AST, module
erasure). The C++ backend is invoked via `FROZONE_CPP=1`.

```bash
# Generate C++ source + build + run
FROZONE_CPP=1 bundle exec ruby frozone.rb --aot bench/stubs/fib.rb
g++ -O2 -std=c++20 cpp/gen/fib.cpp -o cpp/gen/fib
./cpp/gen/fib

# Or run the whole benchmark suite through the C++ backend
bundle exec rake bench_cpp
```

## Status

**24 of 24 benchmarks pass** end-to-end (MRI-parity verified output).

## Performance — 2026-04-17

**Environment**: Ruby 4.0.1, YJIT, Crystal 1.16 `--release`, GCC 13 `-O2 -std=c++20`,
Linux x86-64 (AMD 6-core)

All times are wall-clock milliseconds. C++ and Crystal run the same
AOT-compiled benchmark stubs; MRI and YJIT run the same stubs interpreted.

### Compute-intensive benchmarks

| Benchmark | MRI | YJIT | C++ | Crystal | C++/MRI | C++/YJIT |
|-----------|----:|-----:|----:|--------:|--------:|---------:|
| fib(35) x3 | 2326 | 501 | 37 | 94 | **63x** | **14x** |
| matmul(200) x20 | 7355 | 2897 | 82 | 256 | **90x** | **35x** |
| nbody x100 | 7259 | 2644 | 142 | 116 | **51x** | **19x** |
| nqueens 500x12 | 198033 | 49711 | 5890 | 6566 | **34x** | **8.4x** |
| loops_times | 8675 | - | 96 | 123 | **90x** | - |
| sudoku x20 | 7151 | 1928 | 7 | 418 | **1084x** | **276x** |
| fannkuchredux x10 | 3217 | 3161 | 102 | 857 | **32x** | **31x** |
| blurhash x10 | 2504 | 1057 | 241 | 246 | **10x** | **4.4x** |

### Allocation / GC-intensive benchmarks

| Benchmark | MRI | YJIT | C++ | Crystal | C++/MRI | C++/YJIT |
|-----------|----:|-----:|----:|--------:|--------:|---------:|
| binarytrees x60 | 16244 | 6916 | 4177 | 2000 | **3.9x** | **1.7x** |
| str_concat x100 | 5248 | 4502 | 2894 | 992 | **1.8x** | **1.6x** |
| splay x200 | 20349 | 13417 | 48391 | 13835 | 0.42x | 0.28x |

### Micro-benchmarks (dispatch / accessor overhead)

| Benchmark | MRI | C++ | Crystal | C++/MRI |
|-----------|----:|----:|--------:|--------:|
| attr_accessor | 358 | 1.3 | 4.3 | **278x** |
| getivar | 230 | 1.3 | 4.7 | **182x** |
| setivar | 221 | 1.1 | 4.6 | **207x** |
| keyword_args | 125 | 1.0 | 5.1 | **130x** |
| object_new | 137 | 0.9 | 3.3 | **149x** |
| object_new_init | 152 | 4.8 | 5.7 | **32x** |
| structaref | 112071 | 1.1 | 1041 | **104499x** |
| structaset | 87961 | 0.8 | 79171 | **105384x** |
| respond_to | 161316 | 1.4 | 2.0 | **116783x** |
| cfunc_itself | 34750 | 0.6 | 2.6 | **61540x** |
| send_rubyfunc_block | 45729 | 1.5 | 1.5 | **30643x** |
| ruby_xor | 139 | 1.9 | 3.3 | **73x** |

### Summary

**C++ wins compute** — fib 63x MRI / 14x YJIT; sudoku 1084x MRI / 276x YJIT.
Micro-benchmarks that reduce to constant-folded loops show extreme ratios
(100,000x+) because the C++ optimiser eliminates the entire computation.

**C++ beats Crystal on compute** — fib 2.6x, matmul 3.1x, fannkuchredux 8.4x,
sudoku 63x faster. C++20 `auto` templates + GCC optimisation outperform
Crystal's monomorphic dispatch on these workloads.

**Crystal wins allocation-heavy** — binarytrees 2.1x, str_concat 2.9x.
Boehm GC amortises better than `std::shared_ptr` atomic refcount.
Splay is 3.5x slower in C++ due to `std::any` overhead on heterogeneous
payload types.

**Both backends beat YJIT** on every compute benchmark. Allocation-heavy
benchmarks are competitive (C++ 1.6-1.7x YJIT; Crystal 3.2-4.5x YJIT).

## Why a second backend?

The original roadmap had Crystal as the bootstrap backend and LLVM IR
as the eventual target. C++ landed as a **pragmatic intermediate**.

### The core framing -- "the quiet translation war"

> Crystal's type-system opinions aren't our type-system opinions, and
> building atop them means we're running a quiet translation war.

Crystal isn't a neutral IR. It's an opinionated high-level language
with a type system designed for *Crystal-native* code: monomorphic
dispatch, closed unions, compile-time null-safety, unboxed primitives
(`Int32` for `<=>`). Each of those decisions is internally consistent
for *Crystal's* goals and is the right choice for Crystal-the-language.

They are the *wrong* choices for a Ruby execution target. Ruby is
dynamically typed, uniform-object, open-dispatch, nil-everywhere. Every
decision Crystal made for speed-and-safety shows up as a translation
tax for us.

Each friction point (table below) is "a quiet battle Crystal is winning
on its terms that we have to work around on ours":

- Crystal wants `<=>` to return `Int32` because boxed is expensive
  -- we have to unbox/rebox at call sites.
- Crystal wants single-dispatch with closed unions
  -- we have to emit every possible overload.
- Crystal wants `String?` to force explicit nil-handling
  -- we have to lie about nullability.

Each was Crystal's deliberate evolution, not oversight. We're paying
the integration cost of riding atop a language whose goals only
partially overlap with ours.

Crystal is a superb language. Just not for this use case.

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

- **Same optimiser as Crystal** (LLVM, via Clang/GCC) -- no perf left on the table.
- **Our own type system** via C++20 templates. No union-dispatch limits,
  no `Int32`-for-`<=>`, no nullable-ivar flow-narrowing.
- **Full header-only runtime** via `<memory>`, `<vector>`, `<charconv>`,
  `<cstdint>` -- no runtime library to write and maintain.
- **Faster iteration** than LLVM IR -- no ABI boilerplate, no runtime
  primitives reimplementation, C++ stdlib gives us vectors/shared_ptrs/strings.
- **~2000 lines of emitter** (`cpp_emitter.rb`) vs estimated 5-10x for
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

Copying the wrapper aliases Impl via `shared_ptr` -- Ruby's object-reference
semantics drop out naturally. `b = bodies[i]; b.set_x(v)` mutates the shared
element. Self-referential ivars (`Node.@left` of type `Ruby_Node`) store as
`shared_ptr<Impl>` with auto wrap/unwrap via constructor and conversion
operator overloads.

### Module lowering

Ruby modules emit as C++ structs with a global instance:

```cpp
struct Ruby_Blurhash {
  auto encode_rb(auto width, auto height, auto pixels, ...) { ... }
};
static Ruby_Blurhash Blurhash;
```

The global instance lets `Blurhash.encode_rb(...)` work with C++ member-call
syntax. Nested modules (e.g. `Blurhash::Ruby`) get their own struct + instance.
Classes inside modules are promoted to top-level (emitted before the module).

### Struct.new subclasses

`Struct.new(:v0, :v1, :v2)` creates a class at load time via `define_method`.
The emitter detects Struct subclasses by walking the parent chain, extracts
member names from the VM's `@members` class ivar, and generates a plain C++
struct with typed fields, a parameterised constructor, and getter/setter
methods.

### Heterogeneous types -- std::any

When type inference detects incompatible types in the same position (e.g.
a method returning `Hash | PayloadNode`, or an ivar storing both), the
emitter uses `std::any` for type erasure. A `ruby_to_opt<T>()` helper
handles nullable primitives via `std::optional<T>`.

### Type inference

Lightweight TI without Frozone's main `TypeInference` engine (which is
Crystal-tuned). A 3-iteration fixpoint over:

- `@_class_ivar_types` -- per-class ivar types inferred from all assignments,
  including `@list[i] = val` element-type widening.
- `@_class_method_return_types` -- per-class method return types from
  `infer_method_return_type` (walks explicit returns + If-as-expression).
- `@_top_level_method_return_types` -- same for free functions.
- `@_ctor_param_types` -- call-site arg types for each class's constructor.
- `@_method_call_arg_types` -- call-site arg types per method name, with
  cross-method parameter propagation and local variable tracking.

### Local hoisting

Matches Ruby's method-wide local scope against C++'s block scope:

- Known primitive/class type -> `TYPE name = default;` at method top
- Unknown but decltype-safe RHS -> `std::decay_t<decltype(rhs)> name{};`
- Otherwise falls through to per-site `auto name = expr;`

### Runtime

Single-header C++ runtime (`cpp/runtime/frozone.hpp`):

- `RubyNil` -- universal-convertible sentinel (int64_t/double/bool/string/shared_ptr/any T)
- `RubyString` -- `vector<uint8_t>`-backed byte string (UTF-8/BINARY encoding,
  ord, concat, slice, operator+/*, comparisons)
- `RubyArray<T>` -- `shared_ptr<vector<T>>` (cheap copy, growable, fetch/delete_at/insert/join)
- `RubyHash<K,V>` -- insertion-ordered hash (std::list + std::unordered_map)
- `RubySymbol` -- interned `const char*` with pointer equality
- `RubyTree` -- shared-ownership binary tree (binarytrees heuristic)
- `Ruby_Random` -- shared_ptr-wrapped MT19937 (matches MRI's 53-bit .rand())
- `ruby_nil_q(x)` -- type-dispatched nil check (C++20 `requires` for user classes)
- `ruby_to_opt<T>(v)` -- safe assignment to `std::optional<T>` locals

## When to switch to LLVM IR

The C++ backend is ergonomic through 24 benchmarks. It will hit one of:

- A Ruby feature that doesn't fit C++ templates cleanly (true method-missing,
  fully dynamic receiver dispatch)
- Performance requirements where `std::shared_ptr` atomic refcount is the
  bottleneck (splay's 3.5x slowdown vs Crystal is the canary)
- Complexity exceeding what a focused emitter can support (~2500 LOC?)

At that point LLVM IR becomes the target. The front-end
(parser -> AST -> TI -> module erasure) stays identical; only the emitter
changes.

## Files

- [`lib/frozone/compiler/cpp_emitter.rb`](../lib/frozone/compiler/cpp_emitter.rb) -- ~2200 LOC emitter
- [`cpp/runtime/frozone.hpp`](../cpp/runtime/frozone.hpp) -- ~460 LOC runtime header
- [`cpp/gen/`](../cpp/gen/) -- generated `.cpp` files (binaries gitignored)
- [`bench/stubs/`](../bench/stubs/) -- benchmark stubs run through the emitter
- [`Rakefile`](../Rakefile) -- `rake bench_cpp` task runs all 24 benchmarks

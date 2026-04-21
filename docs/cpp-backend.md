# C++ Backend

Frozone has two parallel AOT compiler backends: **Crystal** and **C++**.
Both generate native binaries from the same front-end (parser, AST, module
erasure) and share the same **TypeInference** engine. The C++ backend is
invoked via `FROZONE_CPP=1`.

```bash
# Generate C++ source + build + run
FROZONE_CPP=1 bundle exec ruby frozone.rb --aot bench/stubs/fib.rb
g++ -O2 -std=c++20 cpp/gen/fib.cpp -o cpp/gen/fib
./cpp/gen/fib

# With Boehm GC (for allocation-heavy benchmarks)
g++ -O2 -std=c++20 -DFROZONE_USE_BOEHM_GC cpp/gen/fib.cpp -lgc -o cpp/gen/fib

# With Dustman GC (precise, see below for build)
g++ -O2 -std=c++20 -DFROZONE_USE_DUSTMAN_GC \
    -I vendor/dustman/include \
    cpp/gen/fib.cpp vendor/dustman/build/libdustman.a -o cpp/gen/fib

# Run the whole benchmark suite
bundle exec rake bench_cpp              # no GC (raw new, leaks)
bundle exec rake bench_cpp_dustman      # via Dustman; builds the lib first
```

### Dustman GC — build HOWTO

Dustman is vendored as a git submodule at `vendor/dustman`
(https://github.com/rolandpj1968/dustman). It is a precise, moving,
generational GC — see [docs/gc-design.md](gc-design.md).

**Prerequisites:** a C++17 compiler (GCC 7+ / Clang 5+), `cmake` (≥ 3.14),
`ninja`. On Debian/Ubuntu: `apt install cmake ninja-build`.

```bash
# One-time after clone (if you didn't pass --recursive)
git submodule update --init vendor/dustman

# Build the static library (Release mode, no tests/benchmarks)
bundle exec rake dustman:build          # → vendor/dustman/build/libdustman.a

# Clean
bundle exec rake dustman:clean
```

The rake task pins to whatever revision is recorded in the submodule
(currently `v0.3.1`). To experiment against a different Dustman tag:

```bash
cd vendor/dustman && git checkout v0.3.0 && cd -
bundle exec rake dustman:clean dustman:build
bundle exec rake bench_cpp_dustman
```

## Status

**23 of 24 benchmarks pass** end-to-end (MRI-parity verified output).
The remaining failure (blurhash) is a class name collision in the TI cache.
**33/33 language feature tests pass** (arithmetic, control flow, classes,
modules, case/when, yield/blocks, lambda, rescue/ensure, etc.).

## Architecture

### Object model — pointer-based with Ruby class hierarchy

User classes inherit from `RubyObject` (which inherits from `RubyBasicObject`,
matching Ruby's actual class hierarchy). Objects are heap-allocated and
referenced by raw pointer. Nil is `nullptr`.

```cpp
// RubyBasicObject → RubyObject → user classes
struct Ruby_Planet : public RubyObject {
  double iv_x = 0.0, iv_y = 0.0, iv_z = 0.0;
  double iv_vx = 0.0, iv_vy = 0.0, iv_vz = 0.0;
  double iv_mass = 0.0;

  Ruby_Planet(auto x, auto y, auto z, ...) {
    iv_x = x; iv_y = y; iv_z = z;
    // ...
  }

  double x() { return iv_x; }
  void set_x(double v) { iv_x = v; }

  const char* rb_class_name() const override { return "Planet"; }
};

Ruby_Planet* p = new Ruby_Planet(3.0, 4.0, 0.0, ...);
Ruby_Planet* q = p;    // pointer copy = Ruby reference semantics
q->set_x(5.0);        // mutates through alias
// p->x() == 5.0 ✓
```

This gives Ruby's reference semantics naturally: copying a pointer aliases
the same object. No `shared_ptr`, no refcount traffic, no deep cloning.
Self-referential fields (e.g. `Node.@left` of type `Ruby_Node`) are just
`Ruby_Node*` pointers.

### Previous design (shared_ptr) and why we moved away

The original design wrapped each class in a `shared_ptr<Impl>` for reference
semantics. This worked but paid atomic refcount on every copy/destroy —
half the runtime for nbody. The pointer-based model eliminated this:
**nbody 226ms → 110ms (2x faster)**.

### Shared TypeInference

The C++ backend uses the **same TypeInference engine** as the Crystal backend.
`TypeInference.new(...)..run` produces a `TypeEnv` with typed slots for
locals, ivars, method returns, and params. Both backends consume the same
type information; only the lowering differs.

```
TypeInference.run → TypeEnv (generic, backend-independent)
                      ↓
          ty.to_cpp    → "double"         (C++ backend)
          ty.to_crystal → "Float64"       (Crystal backend)
```

The `Type#to_cpp` method renders the type lattice to C++ type strings:

| TI Type | C++ lowering |
|---------|-------------|
| `:i64` | `int64_t` |
| `:f64` | `double` |
| `:i64, nullable` | `std::optional<int64_t>` |
| `class: :Planet` | `Ruby_Planet*` |
| `class: :Planet, nullable` | `Ruby_Planet*` (nullptr = nil) |
| `class: :Object` (LCA) | `RubyObject*` (virtual dispatch) |
| `class: :String` | `RubyString` (value type) |
| `class: :Array, elem: :f64` | `RubyArray<double>` (value type) |
| `:bottom` | `auto` |

A small amount of ad-hoc TI remains as fallback for cases the shared TI
doesn't cover yet (module-nested class ivar types, nullable return detection).
This is being eliminated incrementally.

### Memory management — Boehm GC

`RubyBasicObject::operator new` routes through `GC_MALLOC` when
`-DFROZONE_USE_BOEHM_GC` is defined. All subclasses inherit GC allocation
automatically. Without the flag, standard `new`/`delete` is used (objects
leak, fine for benchmarks that don't allocate heavily).

This is the same GC that Crystal uses. The long-term plan is a custom Immix
collector (see [gc-design.md](gc-design.md)), but Boehm validates the
"no refcount" hypothesis at zero engineering cost.

### Class hierarchy

```
RubyBasicObject                    ← vtable root, operator new → GC_MALLOC
  └── RubyObject                   ← adds Kernel (default parent for user classes)
        ├── Ruby_Planet            ← user class (generated)
        ├── Ruby_Node              ← user class
        └── Ruby_TheClass          ← Struct.new subclass (generated)
```

Classes that inherit from `BasicObject` directly in Ruby are emitted as
`struct Ruby_X : public RubyBasicObject`.

### Method dispatch

**Monomorphic** (TI proves concrete type): direct call via `->`.
```cpp
// TI says p is Ruby_Planet*
p->x()                         // direct, no vtable
```

**Polymorphic** (TI gives LCA): virtual dispatch via `RubyObject*`.

**Nil check**: `ruby_nil_q(ptr)` → `ptr == nullptr` for pointer types.

### Module emission

Ruby modules emit as C++ structs with a global instance:
```cpp
struct Ruby_Blurhash {
  auto encode_rb(auto width, auto height, auto pixels, ...) { ... }
};
static Ruby_Blurhash Blurhash;
// Call: Blurhash.encode_rb(204, 204, ARRAY)
```

### Exception handling

`begin/rescue/ensure` maps to `try/catch`. Exception classes inherit from
`RubyException` (which extends `std::exception`):
```cpp
try { ... }
catch (Ruby_ZeroDivisionError& e) { ... }
```

Integer division by zero throws `Ruby_ZeroDivisionError` via `ruby_div()`.

### Runtime

Single-header C++ runtime (`cpp/runtime/frozone.hpp`):

- `RubyBasicObject` / `RubyObject` — class hierarchy with virtual dispatch
- `RubyString` — `vector<uint8_t>`-backed byte string
- `RubyArray<T>` — `shared_ptr<vector<T>>` (value type, cheap copy)
- `RubyHash<K,V>` — insertion-ordered hash
- `RubySymbol` — interned `const char*`
- `Ruby_Random` — shared_ptr-wrapped MT19937
- `RubyException` hierarchy — RuntimeError, ZeroDivisionError, TypeError, etc.
- `ruby_nil_q(x)` — type-dispatched nil check (nullptr for pointers)
- `ruby_div` / `ruby_mod` — safe integer division
- `FROZONE_GC_INIT()` — Boehm GC initialization (no-op without flag)

## Why a second backend?

### The core framing -- "the quiet translation war"

> Crystal's type-system opinions aren't our type-system opinions, and
> building atop them means we're running a quiet translation war.

Crystal's decisions (monomorphic dispatch, closed unions, compile-time
null-safety, unboxed `Int32` for `<=>`) are right for Crystal but wrong
for a Ruby execution target. Ruby is dynamically typed, uniform-object,
open-dispatch, nil-everywhere.

C++ with our own object model gives us full control: the generated code
matches Ruby semantics directly, without a translation layer.

### Crystal friction points

| Category | Crystal constraint | C++ eliminates it |
|----------|-------------------|-------------------|
| Return type unions | All subtypes must agree | `auto` return deduction |
| Block capture | `break` rules differ | Lambda params |
| Nullable ivars | Flow-narrowing fails | `nullptr` is natural |
| Primitive boxing | `Int32` for `<=>` | Raw `int64_t` everywhere |
| Bool/RubyBool | Crystal `Bool` vs ours | `bool` directly |

## Feature test suite

33 per-feature tests (`spec/frozone/compiler/cpp_features_spec.rb`) covering:
arithmetic, control flow (if/while/until/ternary/case-when), methods
(recursion, optional params, kwargs, yield, lambda), classes (ivars,
attr_accessor, self-referential, class methods, class variables), arrays,
strings, hashes, structs, modules, rescue/ensure, nil handling.

## Self-compilation status

The self-host smoke test generates 20K lines of C++ (62 user classes).
The emitter hangs for methods with >5000 AST nodes (Lexer#advance: 12,354
nodes) — mitigated by skipping hoisting for large methods. Current compile
error count: ~5600 (down from 7300), primarily from UNSUPPORTED AST nodes
and builtin types not yet inheriting from RubyObject.

## Files

- [`lib/frozone/compiler/cpp_emitter.rb`](../lib/frozone/compiler/cpp_emitter.rb) — ~2500 LOC emitter
- [`lib/frozone/compiler/type.rb`](../lib/frozone/compiler/type.rb) — `Type#to_cpp` rendering
- [`lib/frozone/compiler/type_inference.rb`](../lib/frozone/compiler/type_inference.rb) — shared TI engine
- [`cpp/runtime/frozone.hpp`](../cpp/runtime/frozone.hpp) — ~520 LOC runtime header
- [`cpp/gen/`](../cpp/gen/) — generated `.cpp` files
- [`spec/frozone/compiler/cpp_features_spec.rb`](../spec/frozone/compiler/cpp_features_spec.rb) — 33 feature tests
- [`docs/gc-design.md`](gc-design.md) — GC design (Immix, Boehm, TLABs)
- [`docs/cpp-object-model.md`](cpp-object-model.md) — object model design
- [`Rakefile`](../Rakefile) — `rake bench_cpp` runs all benchmarks

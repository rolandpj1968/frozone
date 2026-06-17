# The Design of Frozone

Frozone is a Ruby implementation. This document captures the architectural
principle that holds the whole thing together. Other docs describe individual
subsystems; this one describes the spine.

## The Ruby implementation lives in `lib/core/4.0/`

`lib/core/4.0/*.rb` is the canonical source of truth for Ruby semantics in
Frozone. When user code calls `arr.length`, what gets invoked is
`lib/core/4.0/array.rb`'s `def length`. Everything that *can* be expressed in
Ruby lives here, in plain Ruby code that humans read and edit.

This file tree is not "a port of MRI's stdlib" or "a convenience layer over
some other implementation." It is *the* implementation. Both backends
(interpreter and compiler) take `core/4.0` as their definition of what each
method means.

## The syntactic membrane: `Intrinsics.X(args)`

The only mechanism by which Ruby code can reach *outside* of Ruby is the
literal token `Intrinsics.foo(...)` in the source. The parser recognizes this
shape syntactically and produces an `Ast::IntrinsicCall` node carrying the
name and argument expressions. Every other Ruby construct compiles to ordinary
method dispatch.

Treating it as a syntactic marker — not a method call on a magical module —
keeps the membrane crisp: it's exactly one rule, applied by exactly one
component (the parser), with no special-case dispatch logic anywhere
downstream.

This is "the design of Frozone" in one rule.

## Two backends, one AST

Both the interpreter and the compiler consume the same `Ast::IntrinsicCall`
node, but they target different worlds.

### Interpreter (MRI host)

When Frozone runs under MRI Ruby, the tree-walking interpreter dispatches an
`Ast::IntrinsicCall` by calling `Vm::Intrinsics.send(name, context, *args)`.

- `Vm::Intrinsics`'s class methods (`lib/frozone/vm/intrinsics/*.rb`) are
  ordinary MRI Ruby code.
- Their bodies operate on host (MRI) primitives, reaching them via the `#raw`
  accessor on Vm wrapper objects.

### Compiler (cpp_box)

When the compiler emits C++ for an `Ast::IntrinsicCall`, it lowers directly:
`Intrinsics.foo(a, b, c)` becomes `intrinsic_foo(a, b, c)` — a literal C
function call.

- `intrinsic_foo` lives in `cpp/runtime/intrinsics/*.{hpp,cpp}`.
- It operates on the C++ primitive structs (`struct Array`, `struct Integer`,
  …) that hold the actual data at runtime.

Same AST node, two emission strategies. No special-case dispatch in either
direction.

## The two primitive layers and what lives in them

There are two parallel storage layers for the core types (Array, Hash, String,
Integer, …), one per backend:

### Compiler backend: C++ primitive structs

`struct Array { std::vector<BO*> data; … };`, `struct Integer { int64_t raw_; };`,
etc. These are the storage substrate of compiled Frozone. They are hand-written
C++ and exist because something eventually has to do `data.push_back(...)` or
`raw_ + other->raw_` in machine code. The methods on these structs come from
*compiling* `lib/core/4.0/*.rb` — their vtables are populated by ordinary
method compilation, and their `Intrinsics.X` calls bottom out at
`intrinsic_X(...)` C functions that touch the struct's data directly.

### Interpreter backend: `Vm::*Object` wrappers

`Vm::ArrayObject`, `Vm::HashObject`, `Vm::StringObject`, etc. are MRI Ruby
classes that wrap host MRI primitives. Each is a *thin storage shell*:

- `#raw` — exposes the wrapped host primitive.
- Any genuinely wrapper-only state — e.g., a `Vm::StringObject` may carry an
  encoding flag that the underlying MRI `String` doesn't model.
- Nothing else.

In particular, no `#length`, `#size`, `#empty?`, `#push`, `#[](i)` — those
methods *belong to the type*, defined once in `lib/core/4.0/array.rb`. If the
wrapper exposes them too, you have two definitions for one operation and they
can drift.

## Invariants and consequences

### The host primitive inside a wrapper is always host-allocated.

Vm wrappers are only ever constructed in two places: literal-evaluation paths
in the AST evaluator (which explicitly allocate the host primitive), and
through `Intrinsics.X_initialize`-style intrinsics that run host-side C/Ruby
code (which can only construct host primitives — that's all they have
access to). Once stored, the wrapper's primitive ivar is host-typed for the
lifetime of the wrapper. This invariant isn't checked at runtime — it falls
out of *where* primitive allocation happens.

### Bridges cross the membrane explicitly via `#raw`.

The MRI bridge `def array_length(_, v) = n2f_int(v.raw.length)` is what
membrane-crossing looks like. `v.raw` is the explicit unwrap. The bridge is
host code reaching into a host primitive — a single labeled site per call.
Bridges that use shortcut methods on the wrapper (`v.length`) are doing the
same thing implicitly, which is what makes the shortcut a layer leak: it hides
the crossing.

### The compiler has exactly one structural special-case.

The lowering rule for `Ast::IntrinsicCall`. Everything else — method
compilation, vtable population, dispatch, ivar storage — is uniform. When a
Vm wrapper class like `Vm::ArrayObject` is itself compiled (the self-compile
case), it compiles like any other Ruby class: vtable slots populated from
its method bodies, ivars laid out as `BO*` fields. The compiler doesn't know
or care that `Vm::ArrayObject` is "a wrapper."

### Self-compile is not a separate mode of the compiler.

When Frozone compiles Frozone (producing `bin/frozone_box`), both the Vm
wrappers and the C++ primitive structs are present in the output. The
compiler doesn't run two different algorithms; it runs *one* algorithm over
the larger input. The wrapper-vs-primitive distinction shows up in the
*runtime data layout* of `bin/frozone_box`, not in the compiler's logic.

When compiling a guest application (compiling a user app, not the host),
the wrappers are unreachable code and pruned. The resulting binary contains
only the C++ primitive substrate and the compiled `core/4.0` methods on it.

## What this lets us not do

We do not need:

- A discriminator like `Intrinsics.interpreted?` to switch behavior at runtime
  based on which backend is executing. Both backends were chosen at compile
  time.
- A "wrapper-vs-primitive membrane enforcement pass" in the compiler. The
  membrane is in the parser; downstream is uniform.
- Synthesized C++ bodies for `Vm::Intrinsics` methods in the self-compile
  case. The Ruby source of the bridges *is* the body to compile; ordinary
  compilation produces the right thing.
- Separate `Vm::Intrinsics` and `Cpp::Intrinsics` modules. There is one
  `Intrinsics.X` syntactic form; there are two emission strategies for the
  resulting AST node. The same source line of `core/4.0` exercises both.

The compiler is small. The runtime substrate is finite. The wrapper layer is
thin. The Ruby implementation is in one place. None of these are accidents.

## Pointers

- Membrane parser hook: `lib/frozone/vm/parser.rb` (the `Intrinsics.X` →
  `Ast::IntrinsicCall` rewrite).
- AST node: `lib/frozone/ast/intrinsic_call.rb`.
- Interpreter dispatch: `Ast::IntrinsicCall#evaluate` (same file).
- MRI bridges: `lib/frozone/vm/intrinsics/*.rb`.
- Vm wrappers: `lib/frozone/vm/*_object.rb`.
- Compiler lowering: `lib/frozone/compiler/backend/cpp_box/intrinsic_lowering.rb`
  (the `HPP_INTRINSICS` table and `lower` method).
- C++ primitive structs: `cpp/runtime/box_first.hpp` (`Array`, `Integer`,
  `String`, `Hash`, …).
- C++ intrinsic implementations: `cpp/runtime/intrinsics/*_intrinsics.{hpp,cpp}`.
- Frozone-Ruby (the implementation): `lib/core/4.0/*.rb`.

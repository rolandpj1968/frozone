# C++ Object Model Design

## Motivation

The C++ backend currently uses `std::shared_ptr<Impl>` for user classes
and `std::any` for heterogeneous types. Both are wrong:

- **shared_ptr**: correct reference semantics but pays atomic refcount
  on every copy. Precludes future GC integration.
- **std::any**: value semantics (deep clone on copy), which is the
  opposite of Ruby's reference semantics. Introduced as a stopgap for
  types the TI can't resolve to a single concrete type.

Ruby has a universal type hierarchy rooted at `BasicObject`. Every
value IS-A `BasicObject`. When TI computes the meet/LCA of two types,
the result is always a valid Ruby class. The C++ lowering should
reflect this: a pointer to a base class, with virtual dispatch.

## Design

### Class hierarchy

```
RubyBasicObject                    ← vtable root, ~8 methods
  └── RubyObject                   ← adds Kernel (puts, class, respond_to?, etc.)
        ├── RubyInteger            ← boxed int64_t
        ├── RubyFloat              ← boxed double
        ├── RubyString             ← existing, gains base class
        ├── RubySymbol             ← existing, gains base class
        ├── RubyArray<T>           ← existing, gains base class
        ├── RubyHash<K,V>          ← existing, gains base class
        ├── RubyNilClass           ← singleton
        ├── RubyTrueClass          ← singleton
        ├── RubyFalseClass         ← singleton
        └── Ruby_Planet            ← user class (generated)
              └── Ruby_Node        ← user class
```

### What goes in the vtable

The closed-world analysis tells us exactly which methods are ever
called on any receiver. The vtable only needs entries for methods
that participate in polymorphic dispatch — i.e., methods called on
a variable whose TI type is a base class (LCA of multiple concrete
types).

For monomorphic call sites (TI proves the concrete type), the emitter
can emit direct calls — no vtable overhead. This is the common case
for the benchmarks.

### Allocation

Objects are heap-allocated. The pointer IS the object reference —
Ruby's reference semantics come for free (copy = pointer copy).

**Phase 1 (now)**: `new` / `delete`. Simple, correct, debuggable.
**Phase 2**: bump allocator / arena. Validates the performance ceiling.
**Phase 3**: Immix GC (see gc-design.md).

### TI-driven type lowering

The shared TI produces `Type` values for every slot. The C++ emitter
lowers them:

| TI Type | C++ lowering | Notes |
|---------|-------------|-------|
| `:i64` | `int64_t` | unboxed, zero overhead |
| `:f64` | `double` | unboxed |
| `:i64, nullable` | `std::optional<int64_t>` | T\|nil for primitives |
| `class: :Planet` | `Ruby_Planet*` | single-type, direct dispatch |
| `class: :Planet, nullable` | `Ruby_Planet*` | nullptr = nil |
| `class: :Object` (LCA) | `RubyObject*` | polymorphic, vtable dispatch |
| `class: :BasicObject` | `RubyBasicObject*` | rare |
| `class: :String` | `RubyString*` | builtin |
| `class: :Array, elem: :i64` | `RubyArray<int64_t>*` | typed array |
| `array_scalar` | `RubyArray<int64_t>*` | same |
| `:bottom` | `auto` | TI couldn't resolve |

### Boxing primitives

When TI computes an LCA that includes a primitive type:

```ruby
x = condition ? 42 : "hello"   # TI: Integer | String → LCA = Object
```

The integer must be **boxed** into `RubyInteger` (heap-allocated, IS-A
`RubyObject`). The emitter inserts the box at the assignment site:

```cpp
RubyObject* x;
if (condition) {
  x = new RubyInteger(42);     // box
} else {
  x = new RubyString("hello");
}
```

For the common case where TI proves the type is always int64_t, no
boxing occurs — the value stays as a raw `int64_t` on the stack.

### Reference semantics

With pointer-based objects:

```cpp
Ruby_Planet* a = new Ruby_Planet(1.0, 2.0);
Ruby_Planet* b = a;            // pointer copy — aliases same object
b->set_x(3.0);                // mutates through alias
assert(a->x() == 3.0);        // ✓ Ruby semantics
```

No shared_ptr needed. No refcount traffic. No deep cloning.
Lifetime is managed by the GC (or by the arena/scope in earlier phases).

### Nil representation

`nil` is a null pointer. Every pointer-typed variable is nullable
by default (just like Ruby). No wrapper needed.

```cpp
Ruby_Planet* p = nullptr;      // nil
if (p) { ... }                 // nil check
```

For unboxed primitives, `nil` still needs `std::optional<T>`.

### Method dispatch

**Monomorphic** (TI proves concrete type): direct call.
```cpp
// TI says p is Ruby_Planet
p->x()                         // direct call, no vtable
```

**Polymorphic** (TI gives LCA): virtual dispatch.
```cpp
// TI says result is RubyObject (LCA of Hash, PayloadNode)
RubyObject* payload = generate_payload(depth, tag);
// any method call on payload goes through vtable
```

**Megamorphic** (method_missing, send): not yet needed for
closed-world benchmarks. Would require a string→method-pointer map.

### Impact on existing benchmarks

| Benchmark | Current | After redesign |
|-----------|---------|----------------|
| fib | int64_t (unboxed) | unchanged |
| matmul | double (unboxed) | unchanged |
| nbody | Ruby_Planet (shared_ptr) | Ruby_Planet* (raw pointer) — faster |
| splay | std::any payload (deep clone) | RubyObject* (pointer copy) — **much** faster |
| binarytrees | shared_ptr tree nodes | raw pointers — faster (no refcount) |
| blurhash | std::any hash values | RubyObject* hash values — cleaner |

The compute benchmarks (fib, matmul) are unaffected — they stay
unboxed. The allocation-heavy benchmarks (splay, binarytrees) get
faster because pointer copy replaces refcount/clone.

### Migration path

1. **Add RubyBasicObject/RubyObject base classes** to the runtime.
   Virtual methods for the common interface (class_name, nil_q,
   to_s, etc.).

2. **Make existing types inherit**: RubyString, RubyArray, RubyHash,
   RubySymbol gain `: public RubyObject`.

3. **Generated classes inherit**: `struct Ruby_Planet : public RubyObject`.
   Ivars are direct fields (no Impl indirection needed — the object
   itself IS heap-allocated).

4. **Replace shared_ptr with raw pointers** in generated code.
   Lifetime managed by scope/arena initially, GC later.

5. **Replace std::any with RubyObject*** for heterogeneous types.

6. **Box primitives** at LCA sites. TI already knows where this is
   needed.

Steps 1-3 can land incrementally without breaking existing benchmarks.
Steps 4-5 are the payoff. Step 6 is needed for self-compilation.

## Interaction with shared TI

The shared TI already computes everything needed:

- `Type#class_name` → which C++ class to use
- `Type#nullable?` → pointer (always nullable) vs optional (primitives)
- `Type#raw?` → stays unboxed (int64_t/double)
- `Type#class_type?` with LCA → `RubyObject*`
- `Type#to_cpp` → renders the right C++ type string

The `to_cpp` method needs updating to emit pointers for class types
instead of value types. This is the key change:

```ruby
# Before:
when :class_type then "Ruby_#{@class_name}"   # value type

# After:
when :class_type then "Ruby_#{@class_name}*"  # pointer
```

## Non-goals (for now)

- **Inline caching**: monomorphic call sites don't need caches
  because TI already proves the type. Polymorphic sites use vtable.
- **Method tables**: vtable is sufficient for closed-world dispatch.
  Open-world (method_missing, define_method at runtime) is deferred.
- **Metaclass / eigenclass**: class methods are static methods on
  the C++ class. No metaclass object needed.

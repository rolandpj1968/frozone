# Second C++ backend — Ruby → C++ translation

How the second C++ backend (`FROZONE_BOX_FIRST=1`, internally
"box-first") lowers each Ruby construct. Naive baseline first;
optimisations layered on top are noted as such.

This is a *reference*, not a tutorial — pair each section with
`lib/frozone/compiler/backend/cpp_box/` for the code that actually
emits it.

---

## Object model

Every Ruby value is a `BasicObject*` — a heap-allocated polymorphic
C++ object. There is no pointer tagging, no inline primitives, no
union-typing. `Integer`, `Float`, `String`, `Array`, `Hash`,
`Symbol`, every user class — all subclasses of `BasicObject`.

```cpp
struct BasicObject {
  // Universal virtual vtable: one slot per method name in the
  // program's call surface.
  virtual BasicObject* m_class(Array* = &EMPTY_ARGS,
                               Hash*  = &EMPTY_KWARGS,
                               BasicObject* = nil_instance());
  virtual BasicObject* m_to_s   (Array* = …, Hash* = …, BasicObject* = …);
  virtual BasicObject* m_inspect(Array* = …, Hash* = …, BasicObject* = …);
  // … one virtual decl per method name reachable from user code.
};

struct Integer  : BasicObject { long long raw_; };
struct Float    : BasicObject { double     raw_; };
struct String   : BasicObject { std::vector<unsigned char> bytes; };
struct Symbol   : BasicObject { const char* name_; };
struct Array    : BasicObject { std::vector<BasicObject*> data; };
struct Hash     : BasicObject { /* insertion-ordered hash storage */ };
```

Singletons:

```cpp
BasicObject* nil_instance();      // exactly one Nil per program
BasicObject* true_instance();
BasicObject* false_instance();
```

**Phase-1 invariant**: every `BasicObject*` slot — positional args,
kwargs, block, locals, ivars — holds a real Ruby object. Never C++
`nullptr`. `truthy()` works uniformly without nullptr checks because
Nil/True/False are real singleton objects.

---

## Calling convention

Every method call uses the same universal signature:

```cpp
recv->m_NAME(Array* args, Hash* kwargs, BasicObject* block)
```

- `args` — a fresh `Array*` containing positional args (defaults to
  `&EMPTY_ARGS` when empty).
- `kwargs` — a `Hash*` of keyword args (defaults to `&EMPTY_KWARGS`).
- `block` — the block, or `nil_instance()` when absent.

```ruby
obj.foo(x, y, key: z) { |a| body }
```

```cpp
obj->m_foo(
  new Array({x, y}),
  new Hash({{intern("key"), z}}),
  /* block: a fresh Proc1 carrying the lambda body */ );
```

### Natural-args (NA) optimisation

For methods whose closed-world surface admits a stable arity, the
emitter also generates **non-universal C++ overloads** of `m_NAME`:

```cpp
// Per-arity NA overloads on a leaf class
BasicObject* m_foo(BasicObject* a);
BasicObject* m_foo(BasicObject* a, BasicObject* b);
// + a kw-unset form when keyword args are involved
```

Call sites whose receiver type / arity are statically known dispatch
directly to the NA overload — no `Array` allocation, no `Hash*` arg,
no `block` arg. Gated by `FROZONE_NATURAL_ARGS=1`; see
`method_shape_survey.rb` + `class_emitter.rb`. NA-with-block is a
separate bucket carrying a typed `Proc*` parameter.

### Leaf typeid dispatch

For names where every defining class is a leaf, the universal-slot
gateway uses C++ `typeid` to direct-call the leaf's method without a
virtual lookup. See `box-first-optimization.md` §1.

---

## Literals

| Ruby            | C++ emission                                  |
|-----------------|-----------------------------------------------|
| `42`            | `new Integer(42)`                             |
| `3.14`          | `new Float(3.14)`                             |
| `nil`           | `nil_instance()`                              |
| `true`          | `true_instance()`                             |
| `false`         | `false_instance()`                            |
| `"hello"`       | `(new String("hello", 5))` — bytes+length ctor |
| `:foo`          | `intern("foo")` — returns the canonical `Symbol*` |
| `[a, b, c]`     | `(new Array({a, b, c}))`                      |
| `{k: v}`        | `(new Hash({{intern("k"), v}}))`              |
| `(1..10)`       | `[&]{ Range* _r = new Range(); _r->begin_ = …; _r->end_ = …; _r->exclude_end_ = false; _r->initialized_ = true; return _r; }()` |
| `/foo/`         | `[&]{ Regexp* _re = new Regexp(); _re->m_initialize(new Array({src, opts})); return _re; }()` |
| `"a #{x} b"`    | `String#+` chain — see "Interpolation" below  |

Splat-inside-array (`[a, *rest, b]`) lowers to a lambda that
flattens via `splat_to_array(...)`, enforcing MRI splat semantics
(Array fast-path, `to_a` coercion, wrap-as-single fallback).

---

## Local variables

Each Ruby local is a C++ local of type `BasicObject*`, named with a
`l_` prefix to avoid clashes with C++ keywords or runtime helpers.

```ruby
x = 1
y = x + 2
```

```cpp
BasicObject* l_x = nil_instance();
l_x = new Integer(1);
BasicObject* l_y = nil_instance();
l_y = l_x->op_plus(new Array({new Integer(2)}));
```

All locals are default-initialised to `nil_instance()` at entry so
late-bound reads (`defined?(y)` before assignment) yield the
expected `nil`. There is no `auto` — every local is `BasicObject*`,
making the emitter blind to TI gains. This is deliberate for the
correctness-first phase.

---

## Method definitions

```ruby
class Foo
  def bar(a, b = 1, *rest, k:, kk: 2, **kw_rest, &blk)
    body
  end
end
```

A single Ruby `def` produces several C++ overloads on `Frozone_Foo`:

1. **Universal-slot override**: full unpacking from `(args, kwargs,
   block)`, default-fill for missing positionals, kw-fetch for `:k`/
   `:kk`, kw-rest collection.
2. **NA overloads** (when eligible): per-arity entry points so
   statically-known call sites skip the `Array*` packaging.
3. **`kw_unset` form** (when kw-bearing): takes each kw value
   directly with a sentinel for "not passed", letting the caller
   skip Hash allocation.

Frame setup boilerplate (push/pop a `Frame` for `caller_locations`
and self/$_ tracking) emits at the top of each body — see
`method_emitter.rb`.

---

## Method calls

```ruby
recv.method_name(arg1, arg2, kw: v, &blk)
```

Lowers to whichever overload the static caller-side picture supports:

- **Universal slot** (always available): one virtual call.
  ```cpp
  recv->m_method_name(
    new Array({arg1, arg2}),
    new Hash({{intern("kw"), v}}),
    blk_or_nil_instance());
  ```
- **NA overload** (when receiver class + arity statically known):
  ```cpp
  recv->m_method_name(arg1, arg2);   // skip Array*, Hash*, block
  ```
- **`kw_unset` form** (kw-bearing method, NA-eligible):
  ```cpp
  recv->m_method_name(arg1, &k_value);  // pointer to kw value or null sentinel
  ```

Implicit-`self` calls (no `recv.`) lower the same way with `_self` as
the receiver. Operator dispatch (`a + b`, `a < b`, `a[i]`) routes
through corresponding vtable slots (`op_plus`, `op_lt`, `op_aref`).

---

## Instance variables

```ruby
@x
@x = 1
```

Each ivar gets a `BasicObject*` field on the class's C++ struct,
named `iv_x`. Reads / writes are direct field access:

```cpp
this->iv_x;            // @x
this->iv_x = new Integer(1);  // @x = 1
```

The ivar set per class is precomputed at AOT time by walking every
write site reachable on instances of that class. Universal ivars
(`iv_class_object`, `iv_eigenclass`, `iv_instance_variables_hash`,
`iv_frozen_object`) live on `Object` itself and are inherited
naturally.

When the AST-interpreter path needs to read an arbitrary ivar by
name, it falls back to a `lookup_ivar(symbol)` virtual that returns
the stored field — see runtime helpers.

---

## Constants

Frozone constants are resolved at AOT time against the snapshot of
the settled VM state. Each top-level constant gets a kernel function
named `k_<flat_path>()` returning the singleton object:

```ruby
ENCODING_UTF8 = Encoding::UTF_8
```

```cpp
k_Encoding_UTF_8()       // accessor for the constant
```

User-class constants are the same shape — every class identity is a
runtime singleton (`Foo_CLASS`, accessed via `k_Foo()`).

`Foo::Bar` constants flatten to `k_Foo_Bar()`. Constant lookup at
runtime under the AST interpreter path goes through `c_<name>()`
slots on each class, which walk Module#const_missing as needed.

---

## Control flow

### if / unless / ternary

```ruby
truthy?(c) ? a : b
```

```cpp
truthy(c) ? a : b
```

`truthy()` is a two-pointer compare (`o != nil_instance() && o !=
false_instance()`) — fast, branch-predictable.

Statement-form `if`/`unless` lower to C++ `if (truthy(...)) { ... }
else { ... }`. The whole `if` expression's value is captured via a
lambda when it appears in an expression position.

### case / when

```ruby
case x
when A, B then a
when c   then b
end
```

The emitter prefers the dispatch shape that matches:

- **Pattern matching by class** (`case x; when Integer; …`) becomes
  `if (truthy(Integer_CLASS->op_case_eq(new Array({x})))) { … }`.
- **Pattern matching with `===`** uses the receiver's `op_case_eq`
  override (which defaults to `==` on most classes).
- **Range matching** lowers via `Range#op_case_eq`.

### while / until / loop

```ruby
while truthy?(c); body; end
```

```cpp
while (truthy(c)) { body; }
```

`break` / `next` / `redo` in a loop lower to C++ control-flow; in a
block they throw structural `BreakException` / `NextException` /
`RedoException` and are caught at the enclosing iter site.

### for

`for x in iter; body; end` desugars to `iter.each { |x| body }` —
the standard method-call form.

---

## Exceptions

```ruby
begin
  body
rescue SomeError => e
  handler
ensure
  cleanup
end
```

The body and rescue clauses run inside a `try { … } catch (...) { … }`
in C++. Each rescue clause becomes a `dynamic_cast` check on the
caught pointer:

```cpp
try {
  body;
} catch (Throwable* e_) {
  if (dynamic_cast<SomeError*>(e_) != nullptr) {
    BasicObject* l_e = e_;
    handler;
  } else {
    throw;  // re-raise to outer handler
  }
}
// ensure runs via RAII or duplicated emit on each exit
```

`raise X.new(...)` lowers to `throw (new X(args))`; bare `raise`
re-raises (`throw`). `retry` is a goto back to the body label.

The exception class hierarchy mirrors Ruby's — every standard
exception class is a real C++ subclass so `dynamic_cast` reflects
`is_a?` semantics correctly.

---

## Boolean operators

```ruby
a && b           # nil/false → returns left, else right
a || b           # truthy → returns left, else right
!a               # boxed_bool(!truthy(a))
a ||= b          # a = a || b  (short-circuit assignment)
a &&= b          # a = a && b
```

Lower as short-circuiting C++ expressions, each wrapped in a lambda
to preserve "returns the value of the chosen side":

```cpp
[&]() -> BasicObject* { auto* _t = a; return truthy(_t) ? b : _t; }()   // a && b
[&]() -> BasicObject* { auto* _t = a; return truthy(_t) ? _t : b; }()   // a || b
```

---

## Blocks, yield, lambda, Proc

Each block compiles to one of the arity-specialized `Proc`
subclasses:

| Block shape           | Subclass | Slot           |
|-----------------------|----------|----------------|
| `{ ... }`             | `Proc0`  | `call0()`      |
| `{ \|x\| ... }`       | `Proc1`  | `call1(BasicObject*)` |
| `{ \|x, y\| ... }`    | `Proc2`  | `call2(BasicObject*, BasicObject*)` |
| anything more complex | `Proc`   | `m_call(Array*, Hash*)` |

Construction at the call site:

```cpp
arr->m_each(/*block:*/ new Proc1([&, this](BasicObject* l_x) -> BasicObject* {
  /* body */
  return nil_instance();
}));
```

Inside the body, `yield x` lowers to:

```cpp
_block->call1(x)     // when callee statically yields 1 arg
```

…or `_block->m_call(new Array({x}), &EMPTY_KWARGS)` when the yield
shape needs the fallback path.

Proc-flavor laxness rules (extra args dropped, missing → nil, procarg0
auto-splat) live as static code in the cross-arity adapters. Lambdas
emit differently (raise on arity mismatch instead of adapting).

`break`, `next`, `redo`, and non-local `return` from a block use
structural exceptions — see `lambda_emitter.rb`.

---

## Class & module definitions

Each `class Foo < Bar` in the closed world becomes:

```cpp
struct Frozone_Foo : Frozone_Bar {
  // per-class ivar fields
  BasicObject* iv_thing = nil_instance();

  // per-method overrides
  BasicObject* m_some_method(Array*, Hash*, BasicObject*) override { … }
};

// Class singleton — ClassObject metaclass instance
inline RubyClass Foo_CLASS{ /* name, parent, members, … */ };
inline RubyClass* k_Foo() { return &Foo_CLASS; }
```

Modules look the same, just without instances of their own — they
exist to be `include`d / `prepend`ed. Module flattening means each
class's struct carries the *materialised* method set; modules
themselves aren't part of the runtime dispatch chain.

Each class's out-of-line method bodies live in their own translation
unit (`frozone_<ClassName>.cpp`) — see `class_emitter.rb` and
`box-first-layouts-split.md`.

---

## super

Closed-world dispatch. The (origin, method) pair for `super` at each
call site is resolved at AOT time by walking the MRO. The emit form:

```cpp
this->Frozone_Parent::m_method_name(args, kwargs, block);
```

…with a `from_super: true` flag passed through to suppress the
"unused block" warning on parent methods.

---

## defined?

`defined?(expr)` lowers per the expression's static category:

- `defined?(local_var)` — `"local-variable"` if the local is in
  scope at this lex position, else `nil`.
- `defined?(@iv)` — runtime check via `lookup_ivar`.
- `defined?(CONST)` — closed-world: constant present in snapshot →
  `"constant"`; else `nil`.
- `defined?(method_call)` — lookup the method in the receiver's
  closed-world dispatch table.
- `defined?(nil)` / `defined?(true)` / `defined?(self)` — static
  strings.

---

## Globals

```ruby
$x        # → g_globals_storage()->lookup(intern("$x"))
$x = 1    # → g_globals_storage()->store(intern("$x"), new Integer(1))
```

A single lazy `Hash*` keyed by Symbol. Match-data globals (`$1`,
`$~`, etc.) and stream globals (`$stdout`, `$stderr`) are special-
cased through dedicated kernel functions.

---

## String interpolation

`"prefix #{x} suffix"` is sugar for a left-to-right `String#+` chain
starting from an empty string:

```cpp
(((new String("", 0))
  ->op_plus(new Array({new String("prefix ", 7)})))
  ->op_plus(new Array({x->m_to_s()})))
  ->op_plus(new Array({new String(" suffix", 7)}))
```

Each non-literal part coerces via `m_to_s`. StringLiteral parts
emit directly.

---

## Splat / kwsplat in calls

`obj.foo(*arr, **h, &blk)` at the call site uses helpers:

- `splat_to_array(x)` — Array fast-path, `to_a` coercion, single-wrap
  fallback. Result `Array*` is merged into the positional `Array*`.
- `splat_to_hash(x)` — Hash fast-path, `to_hash` coercion. Result
  `Hash*` merged into the kwargs `Hash*`.
- `&blk` — when block is `nil_instance()`, no block passed; else
  the block argument is the `Proc*` already in `blk`.

---

## Where to read the actual emission

| Concern               | File |
|-----------------------|------|
| Top-level orchestration | `emitter.rb` |
| Per-class structs + vtable + ivars | `class_emitter.rb` |
| Method bodies + frame setup | `method_emitter.rb` |
| Expression lowering   | `cpp.rb` (`from_*` helpers), `expr_emitter.rb` |
| Blocks / Procs / yield | `lambda_emitter.rb` |
| Intrinsic call lowering | `intrinsic_lowering.rb` |
| Universal-vtable / runtime helpers | `runtime/universe.rb` |
| Method shape survey (NA, leaf dispatch, kw_unset) | `method_shape_survey.rb` |

---

## What this doc deliberately omits

- **Optimisations layered on top** (typeid leaf dispatch shape, NA
  eligibility surveys, reachability pruning, snapshot serialisation,
  per-class TU splits) — see `box-first-optimization.md` and the
  topic-specific docs.
- **Intrinsics catalogue** — see `lib/frozone/compiler/backend/cpp_box/
  intrinsic_lowering.rb` and `cpp/runtime/intrinsics/*.hpp`.
- **TI integration** — TI is not yet plugged into this backend. When
  it lands it will narrow `BasicObject*` slots / NA eligibility /
  leaf-dispatch coverage at codegen time; until then, every value is
  uniformly boxed.

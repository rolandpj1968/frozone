# UnivArgs fence — implementation plan

Design doc for #178. The goal is a single-parameter universal-vtable
signature that the C++ overload resolver cannot confuse with any NA
overload — a soundness fence before TI re-introduction layers
narrowed types over the per-arity overloads.

## Target shape

```cpp
// In a header where Array, Hash, EMPTY_ARGS, EMPTY_KWARGS, and
// nil_instance() are all visible:
struct UnivArgs {
  Array*       args;
  Hash*        kwargs;
  BasicObject* block;

  UnivArgs()
    : args(&EMPTY_ARGS), kwargs(&EMPTY_KWARGS), block(nil_instance()) {}
  UnivArgs(Array* a, Hash* k = &EMPTY_KWARGS,
           BasicObject* b = nullptr)
    : args(a), kwargs(k), block(b ? b : nil_instance()) {}
};
```

Universal-vtable decl becomes:

```cpp
virtual BasicObject* m_NAME(UnivArgs ua = {});
```

Body shape — inject aliases at the top so existing emit code that
references `args`/`kwargs`/`block` keeps working unchanged:

```cpp
BasicObject* Frozone_Foo::m_NAME(UnivArgs ua) {
  Array* args      = ua.args;
  Hash*  kwargs    = ua.kwargs;
  BasicObject* block = ua.block;
  // ... existing body ...
}
```

Call sites:

```cpp
// Today:
recv->m_NAME(new Array({a, b}), new Hash({{k, v}}), block_obj);

// After:
recv->m_NAME({new Array({a, b}), new Hash({{k, v}}), block_obj});
```

Zero-arg dispatch is `recv->m_NAME({})` or `recv->m_NAME()`.

## Why the fence works

C++ overload resolution between:

```cpp
virtual BasicObject* m_NAME(UnivArgs ua = {});            // universal
BasicObject*         m_NAME(BasicObject* a);              // NA arity 1
BasicObject*         m_NAME(BasicObject* a, BasicObject* b); // NA arity 2
```

A call `recv->m_NAME(x)` resolves to NA-1 unambiguously — `x`
(BasicObject*) cannot convert to `UnivArgs` implicitly (no
implicit constructor takes a single BasicObject*). A call
`recv->m_NAME({})` resolves to the universal slot unambiguously.
There is no shared overload-resolution surface; the fence is
syntactic and the compiler enforces it.

## ABI cost

x86-64 SysV passes aggregates >16 bytes via memory, not registers.
UnivArgs is 24 bytes (3× 8-byte pointers). The current 3-arg form
passes in 3 registers. Decision (per prior discussion): eat the
ABI cost — the soundness benefit dominates, and once TI lands the
hot paths will use narrowed NA overloads anyway, where this cost
doesn't apply.

## Touch list

### lib/frozone/compiler/backend/cpp_box/

| File                          | Sites | What                                                          |
|-------------------------------|------:|---------------------------------------------------------------|
| `class_emitter.rb`            |    16 | Universal-slot decls + universal-slot bodies on BasicObject + Object |
| `runtime/universe.rb`         |    18 | Hand-coded universal-slot bodies (mm_*, op_*, etc.)            |
| `method_emitter.rb`           |     3 | Method-body emit signature                                     |
| `emitter.rb`                  |     2 | Hash-semantics inline (op_eq_q / m_hash_value redirects)       |
| `cpp.rb`                      |   N/A | Call-site emit — replace `, ` joins with `{...}` brace-init    |
| `expr_emitter.rb`             |   N/A | Call-site emit (super, attribute write)                        |
| `intrinsic_lowering.rb`       |   N/A | Per-intrinsic emit                                             |
| `lambda_emitter.rb`           |   N/A | Block-arg conversions                                          |

The 39 direct grep hits are decl/body forms. The call sites are
constructed via string interpolation in cpp.rb/expr_emitter.rb's
`from_*` helpers; need to find every join of three universal-args
values and switch to brace-init.

### cpp/runtime/

| File                          | Sites | What                                  |
|-------------------------------|------:|---------------------------------------|
| `frozone_base.hpp`            |     1 | Add UnivArgs struct (after EMPTY_KWARGS forward decl) |
| `intrinsics/*.hpp`            |   ~25 | Intrinsic bodies that take univ-sig (rescue helpers, hash helpers, raise_X) |

## Staging

1. **Stage 1 — declare struct**: add UnivArgs to base header. No
   emit changes yet. The struct is unused — compiles clean.

2. **Stage 2 — decl + body migration on BasicObject default
   slot**: change just the BasicObject universal-slot default
   body emission. Call sites still use 3-arg form via an inline
   overload bridge:
   ```cpp
   inline BasicObject* BasicObject::m_X(Array* a, Hash* k, BasicObject* b) {
     return m_X(UnivArgs{a, k, b});
   }
   ```
   This lets the rest of the codebase compile while we migrate
   downstream. Verify integration_spec.

3. **Stage 3 — migrate each emit family**: hand-coded overrides
   (universe.rb), constant-lookup slots, per-class universal-slot
   overrides, mm_dispatch / send / __send__. After each family,
   integration_spec checkpoint.

4. **Stage 4 — migrate call sites**: cpp.rb's call construction,
   from_super, from_attribute_write, mm_dispatch internal calls.

5. **Stage 5 — remove the inline bridge**: once no caller uses the
   3-arg form, drop the bridge overload. Now the only legal
   universal-slot signature is `(UnivArgs)`.

6. **Stage 6 — collapse `{nil_instance()}` block defaults**: now
   that UnivArgs ctor defaults block to nil_instance(), redundant
   `block(nil_instance())` defaults in NA-with-block sigs can be
   audited (out of scope here, but the natural follow-up).

## Open questions

- **Header placement.** UnivArgs needs Array/Hash/EMPTY_ARGS/
  EMPTY_KWARGS/nil_instance() visible. Currently EMPTY_ARGS is
  declared after Array becomes complete — that's in layouts.hpp,
  not base.hpp. UnivArgs has to live where all three are visible.
  Options: (a) put UnivArgs in layouts.hpp; (b) make EMPTY_ARGS/
  EMPTY_KWARGS extern decls in base.hpp; (c) UnivArgs body
  defaults use `nullptr` and lift defaults to a static helper.
  Option (b) is cleanest.

- **Aggregate-init compatibility.** Brace-init `recv->m_X({a, k,
  b})` requires UnivArgs to be aggregate-initialisable, OR to have
  a matching constructor. With a defaulted default constructor and
  the 3-arg one above, aggregate-init still works as
  `UnivArgs{.args = …, .kwargs = …, .block = …}` (designated) or
  `UnivArgs{a, k, b}` (positional). Verify with `-Wall -Wextra`
  that the compiler doesn't warn about aggregate vs ctor ambiguity.

- **`override` consistency.** Every derived class's universal-
  slot override must change in lockstep. The decl emission helper
  in `class_emitter.rb` (write_override_decl) is the single source
  of truth for these — get the change in one place and downstream
  follows.

## Verification

- `bundle exec rspec spec/frozone/compiler/backend/cpp_box/integration_spec.rb`
  after each stage. 6.5 min per run; budget accordingly.
- Compile `hello.rb` via `FROZONE_BOX_FIRST=1 FROZONE_CPP=1 …
  --aot` and execute the result. Verify identical output.
- Spot-check generated `.cpp` for one user class to confirm the
  UnivArgs shape lands correctly in decls and bodies.

## When to take this on

This is a "no-going-back" structural change. Worth doing when:

- The block calling-convention work (#172, #173) is complete or
  paused — those touch the same universal-slot family and would
  conflict with an in-flight UnivArgs migration.
- A dedicated session: not interleaved with other code edits. The
  staged plan has integration_spec checkpoints between stages, so
  it's interruptible at stage boundaries.

Until then, the soundness gap remains theoretical: today's NA and
universal-slot signatures are different enough by parameter count
that real ambiguity doesn't arise in the gen — but it COULD arise
once TI starts narrowing slots, and the fence prevents the bug
class entirely.

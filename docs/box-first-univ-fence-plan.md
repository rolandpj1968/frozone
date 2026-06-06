# Universal-vtable fence — implementation plan

Design doc for #178. The goal is a universal-vtable signature that the
C++ overload resolver cannot confuse with any NA overload — a
soundness fence before TI re-introduction layers narrowed types over
the per-arity overloads.

## Design choice — tag-first, not value struct

Originally framed as a `UnivArgs` value struct (3 pointers). Revised
to a **tag-first empty struct** (`UnivTag`, with `inline constexpr
UnivTag univ`) as the first parameter of every universal slot. Same
fence (no NA overload can have `UnivTag` as first arg), much cheaper
ABI:

| Axis                  | UnivArgs value struct | UnivTag first-arg |
|-----------------------|-----------------------|-------------------|
| Reg slots per call    | 1 (via memory) + 3 indirection | +1 (5 total, still ≤6) |
| Caller stack store    | 24 bytes per call     | 0                  |
| Callee load           | 24-byte memory copy   | 0 (still in regs)  |
| Body access pattern   | `ua.args` / `ua.kwargs` / `ua.block` (memory unpack) | `args` / `kwargs` / `block` direct |

For dynamic dispatch (where the compiler can't devirtualise / SROA),
the struct form pays a real overhead per call. The tag form is
strictly cheaper.

## Target shape

```cpp
struct UnivTag {};
inline constexpr UnivTag univ{};

// Universal-vtable decl:
virtual BasicObject* m_NAME(UnivTag,
                            Array* args = &EMPTY_ARGS,
                            Hash*  kwargs = &EMPTY_KWARGS,
                            BasicObject* block = nil_instance());

// Body — unchanged from today; args/kwargs/block are named params.
BasicObject* Frozone_Foo::m_NAME(UnivTag, Array* args, Hash* kwargs, BasicObject* block) {
  /* … existing body … */
}

// Call sites: insert `univ` as first arg.
recv->m_NAME(univ, args_array, kwargs_hash, block_obj);
recv->m_NAME(univ);                     // zero-arg dispatch
recv->m_NAME(univ, args_array);          // partial, kwargs/block default
```

## Why the fence works

C++ overload resolution between:

```cpp
virtual BasicObject* m_NAME(UnivTag, Array*, Hash*, BasicObject*);   // universal
BasicObject*         m_NAME(BasicObject*);                            // NA arity 1
BasicObject*         m_NAME(BasicObject*, BasicObject*);              // NA arity 2
```

No NA overload can begin with a `UnivTag` parameter (it's our internal
type, never used in user-level NA codegen). A call `recv->m_NAME(x)`
where `x` is `BasicObject*` cannot match the universal overload, even
if `x` happens to be an `Array*`. A call `recv->m_NAME(univ, …)`
unambiguously routes to the universal overload. The compiler enforces
the separation syntactically.

## Touch list

Scope is larger than "insert one token at every decl" — the call
sites are where most of the work is:

### Ruby emitter — decls (~38 sites)

- `Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BasicObject* block = nil_instance()` → prepend `UnivTag, ` — 25 sites across emitter.rb, method_emitter.rb, class_emitter.rb, runtime/universe.rb.
- `Array* args, Hash* kwargs, BasicObject* block` (no defaults, body-emit shape) → prepend `UnivTag, ` — 13 sites in class_emitter.rb.
- mm_dispatch's signature (free function) stays as-is.

### Ruby emitter — call sites (~100 lines)

- `cpp.rb` from_method_call universal-form dispatch (3 sites in from_method_call_inner: explicit, safe_nav, no-recv).
- `cpp.rb` na_or_wrap_args — universal branch builds `new Array({…})` for kwargs-less universal calls; needs `univ, new Array({…})`.
- `runtime/universe.rb` hand-coded template bodies — every C++ call like `obj->m_X()` / `obj->m_class()` / `obj->op_eq_q(...)` is a universal dispatch and needs `univ` prepended. 27 lines of these.
- `emitter.rb` hash-semantics inlines (op_eq_q, m_hash_value routings) — multiple `recv->m_X(...)` patterns.
- `intrinsic_lowering.rb` — class_allocate, object_class, object_is_a etc. produce universal dispatches.
- `expr_emitter.rb` — m_each call for for-loop lowering, super forwarding.
- `class_emitter.rb` — trampoline forwarding, mm_dispatch's first arg formation, write_universal_surface.

### C++ runtime headers (~30 lines)

- `cpp/runtime/intrinsics/*.hpp` — many hand-written helpers call `recv->m_class()` / `recv->m_to_s()` / etc. directly; need `univ`.
- `cpp/runtime/box_first.hpp` — main entry uses universal dispatches.

## Staged migration

Doing the full swap atomically is high-risk. Two practical paths:

### Path A — bridge overload

1. Land UnivTag scaffolding (✓ committed).
2. Add an inline non-virtual `m_X(Array*, Hash*, BasicObject*)` bridge on BasicObject for every method name that forwards to `this->m_X(univ, args, kwargs, block)`.
3. Emit `using BasicObject::m_X;` unconditionally on every subclass override so the bridge isn't hidden by the override.
4. Change the virtual signature on BasicObject + every override to `(UnivTag, Array*, Hash*, BasicObject*)` in one coordinated commit.
5. Existing call sites continue to work via bridge. Fence is at the virtual layer.
6. Migrate call sites to `univ`-form gradually.
7. Once all call sites are migrated, drop the bridges and the `using` declarations.

Cost: doubled member-function decls on BasicObject during the transition. Multiple stages, each integration_spec checkpoint.

### Path B — atomic swap

1. Land UnivTag scaffolding (✓ committed).
2. In one commit, update all ~38 decls + all ~100 call sites + all ~30 runtime-header calls.
3. Drive integration_spec to green by fixing whatever the compiler complains about.

Cost: high blast radius, ~6.5 min per integration_spec cycle, plausibly 3–5 iterations before green. Requires a dedicated session, not interleaved with other work.

### Recommendation

Path B (atomic swap) when there's a dedicated working session. The
bridge approach in Path A is more incremental but the extra
`using`-declarations across every subclass × every method name are
their own large emit-side change. The atomic version is cleaner.

## Verification

- `bundle exec rspec spec/frozone/compiler/backend/cpp_box/integration_spec.rb` after each iteration.
- Spot-check one generated `.cpp` to confirm `univ` lands at every call site and bodies still compile.
- Run `bin/frozone_box /tmp/hello.rb` end-to-end.

## Open questions resolved

- **Where does `UnivTag` go?** In the layouts header, after kernel-fn forward decls. Already landed (b9d5a22).
- **Aggregate-init vs ctor?** N/A for an empty struct.
- **Override consistency?** All overrides change at once in Path B. The decl-emit helpers in `class_emitter.rb` (write_override_decl, write_universal_surface) are the single source of truth.
- **`UnivTag` as default arg?** Not needed — every call site explicitly passes `univ`. No `m_X()` calls survive.

## Status

- Stage 1 (scaffold): UnivTag declared at the layouts boundary. Committed in b9d5a22.
- Stage 2+ (migration): not started. The ~120 call-site / 38-decl rewrite needs a dedicated session; the "mostly mechanical" framing under-counted the call-side scope.

# Second C++ backend — cast audit

Audit of every C++ cast emitted by the second backend, classifying each
by safety category and recommending which can be eliminated.

Casts counted (as of the audit pass):

| Cast type        | Sites in `lib/frozone/compiler/backend/cpp_box/` |
|------------------|--:|
| `static_cast`    | 277 |
| `dynamic_cast`   | 62  |
| `reinterpret_cast` | ~25 |

The bar:

- **No `dynamic_cast`** anywhere — long-term goal.
- **No `reinterpret_cast`** except for well-defined pointer-as-integer
  and `unsigned char* ↔ char*` for stdlib APIs.
- **`static_cast`** only for proven impl-internals (the canonical case:
  the universal-vtable's `BasicObject* block` arg narrowed to `Proc*`
  inside the body).

The current state hits the `reinterpret_cast` bar; `static_cast`
mostly meets the bar with a few BasicObject* upcast disambiguations
that are harmless; `dynamic_cast` is the active gap — split between
eliminable exact-type checks and legitimate value-protocol narrowing
that genuinely needs RTTI.

---

## reinterpret_cast — all legitimate

Two patterns, both well-defined under the language:

### Pointer-as-integer (object_id / hash_value)

```cpp
return reinterpret_cast<std::size_t>(this);      // m_hash_value default
return int_box(reinterpret_cast<std::int64_t>(this));  // m_object_id
basic_object___id__: ... reinterpret_cast<int64_t>(s)
```

Every Ruby object's identity-hash and identity-id derive from the heap
pointer. There's no cheaper way to expose this; the integer width is
chosen to fit the platform pointer.

### `unsigned char*` ↔ `const char*` for stdlib APIs

```cpp
new String(reinterpret_cast<const char*>(bytes.data()), n)
std::fwrite(reinterpret_cast<const char*>(buf), 1, n, stdout)
std::printf("%s\n", reinterpret_cast<const char*>(s->name_))
```

`String::bytes` is `std::vector<unsigned char>`; stdlib APIs take
`char*`. The conversion is explicit and well-defined for bit-equal
representations.

**Verdict**: keep all `reinterpret_cast` sites. Add no new ones.

---

## static_cast — mostly fine, two categories to flag

### Category A — pointer upcast to base type

Used to disambiguate `new Array({…})` initializer-list elements and
ternary expression result types:

```cpp
new Array({
  static_cast<BasicObject*>(new String(…)),
  static_cast<BasicObject*>(new Integer(…))
})

(truthy(c) ? static_cast<BasicObject*>(t) : static_cast<BasicObject*>(e))
```

These are upcasts — every Ruby class derives from `BasicObject`, so
they're trivially safe. The C++ implicit conversion would work in
most cases too; the explicit cast removes ambiguity for the compiler
and is harmless.

**Verdict**: keep, but mechanical to remove if we ever want a
cleaner read. ~50 sites.

### Category B — known impl-internal pointer narrowing

The canonical case the design explicitly endorses:

```cpp
// inside Frozone_Foo::m_bar(Array* args, Hash* kwargs, BasicObject* block)
Proc* _block = static_cast<Proc*>(block);   // block is always Proc* or nil_instance()
```

Plus a small number of other invariant-protected narrowings:

- `static_cast<Symbol*>(args->data[0])` — `Symbol#name_` reads in
  intrinsic bodies where args[0] is guaranteed Symbol by call-site
  shape.
- `static_cast<Class*>(my_class)` after `m_class() == &Class_CLASS`
  pointer compare.
- `static_cast<Proc*>(nil_instance())` as the default for
  `Proc* block = nullptr` overrides (with the call-site seam
  converting `nil_instance() → nullptr` before reaching them).

**Verdict**: keep. The C++ static type of the surrounding code proves
the narrowing is safe.

### Category C — flagged: arithmetic operator soundness

In `runtime/universe.rb`, the Integer / Float arithmetic operator
bodies use `static_cast` on the fall-through path after a `Float*`
`dynamic_cast` check:

```cpp
// Integer::op_plus(BasicObject* other) NA body
if (auto* f = dynamic_cast<Float*>(other))
  return new Float(static_cast<double>(raw_) + f->raw_);
return new Integer(raw_ + static_cast<Integer*>(other)->raw_);
//                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// UB if `other` is neither Float nor Integer (e.g. `1 + "abc"`).
```

The Ruby-layer Integer#+ in `lib/core/4.0/integer.rb` performs
`__coerce_to_int__(other)` first, which raises TypeError for
non-numeric `other`. So in well-typed Ruby execution this path is
unreachable. But if the call site bypasses the Ruby override (NA-
direct dispatch into the universe.rb body), the static_cast assumes
something the call hasn't proved.

Same pattern in op_minus / op_mul / op_div / op_mod / op_lt / op_gt /
op_le / op_ge / op_eq_q / op_ne_q / op_lshift / etc., plus the
mirror cases on Float (`static_cast<Float*>(other)->raw_` if not Int).

**Verdict**: soundness gap, not just stylistic. Track as a follow-up:
the correct shape is to gate the static_cast on another typeid /
Class* compare (so the failure mode is "raise TypeError", not UB).
Or: ensure these NA bodies are only reachable after the Ruby layer's
coerce protocol has run.

---

## dynamic_cast — the active surface area

62 sites, split roughly:

### Group 1 — exact-type checks, eligible for elimination

These check whether a value is *exactly* a given class (no subclass
tolerance). They're equivalent to `m_class() == &X_CLASS`, but the
latter is cheaper *and* clearer:

| Site                                  | Pattern                              |
|---------------------------------------|--------------------------------------|
| `String#==`/`!=`                      | `dynamic_cast<String*>(other)`       |
| `Array#m_aset` Range branch           | `dynamic_cast<Range*>(idx)`          |
| `Array#m_aref` Range branch           | `dynamic_cast<Range*>(idx)`          |
| `ruby_puts` Integer/Float/Symbol/String arms | exact-type dispatch          |
| Integer/Float arith `Float*`/`Integer*` typecheck (§ C above) | exact-type |
| `Hash` by_identity Integer check      | `*by_identity && dynamic_cast<…>`    |
| `Hash` key Integer guard              | `!dynamic_cast<Integer*>(idx)`       |
| `Range#each` Integer/Float specialise | `dynamic_cast<Integer*>(n)`          |

Roughly half the sites. **Blocker**: the cheap accessor problem.
`m_class()` is a virtual with universal-protocol args
(`Array*`, `Hash*`, `BasicObject*`), so calling it on the hot path
costs at least an empty-Array allocation. Options:

1. Add a non-virtual `klass()` accessor on every class (returns
   `Class*` directly, no protocol args).
2. Use `typeid(*x) == typeid(X)` — fast, accurate for exact-type,
   already used by leaf-dispatch codegen.

Option 2 is the smaller change and consistent with what `leaf
typeid dispatch` (`box-first-optimization.md` §1) already does.

### Group 2 — legitimate value-protocol narrowing

Genuine "we don't know what this is; check if it's an X" cases.
These are correctly using RTTI; eliminate only by adding a known
shape upstream (often not possible):

- **Rescue clauses** (`dynamic_cast<StandardError*>(e_)`,
  `dynamic_cast<UserError*>(e_)`): rescue catches subclasses, RTTI
  walk is the right tool. Replacing with the IS_A LUT would add a
  per-throw Array allocation — slower.
- **Splat handling** (`dynamic_cast<Array*>(arr_str)`): splat value
  may not be an Array; we explicitly fast-path Arrays.
- **`splat_to_array` internal**: same.
- **`send(*args)` kwargs check** (`dynamic_cast<Hash*>(kwargs)`):
  generic `send` may receive non-Hash kwargs from user code.
- **`kernel_require` / `_relative` / `_load` path String check**: path
  could be any object; we want to print whatever it is.
- **Pattern matching** in `gsub` helper (`dynamic_cast<String*>(pat)`,
  `dynamic_cast<Regexp*>(pat)`): the spec passes through Ruby's value
  protocol; we dispatch on actual type.
- **`Proc1::call1` adapter** (`dynamic_cast<Array*>(a)`): procarg0
  auto-splat shape — need to detect if the single arg is an Array.
- **`main()` global narrowing** (`dynamic_cast<Ruby::Array*>(ARGV)`,
  `Ruby::Exception*` on caught throwable, `Ruby::String*` on
  `exc->iv_message`): these run once at startup; the cost is
  negligible. Could be replaced with `static_cast` since the shapes
  are guaranteed by the snapshot, but the audit benefit is minor.

**Verdict**: keep as is. These are the cases where the Ruby value-
protocol genuinely doesn't know the type statically.

---

## Recommendations

### Short term (this audit)

1. **Document** the current cast landscape (this doc).
2. **Flag** the Integer/Float arithmetic soundness gap (Category C
   above) as a separate task — needs a `static_cast` gate or coerce-
   protocol guarantee.
3. **No mass rewrites** without a benefit case. The `BasicObject*`
   upcasts are harmless; eliminating them is churn.

### Medium term

1. **typeid-based exact-type checks**: convert the Group-1
   `dynamic_cast` sites to `typeid(*x) == typeid(X)`. This is a
   purely local rewrite per site and matches the leaf-dispatch
   pattern. Modest perf win, big readability win (no RTTI walk in
   the hot path).
2. **Cheap class accessor**: if we add a non-virtual `klass()`
   accessor anyway (other optimisations might want it), the
   `typeid` rewrites can switch to `o->klass() == &X_CLASS` —
   slightly faster, no `typeid` `name_` table lookups for the LTO
   to chew through.

### Long term

1. **Coerce-protocol audit on universe.rb arith ops**: every
   `static_cast<X*>(other)` after a failed `dynamic_cast<Y*>(other)`
   needs a proof that the Ruby layer's coerce-protocol has already
   run, or a fallthrough that raises TypeError. Either delete the
   universe.rb fallback bodies (let Ruby Integer#+ handle it) or
   add the typeid gate.
2. **`-fno-rtti`** as a build flag once Group-1 is gone and the
   Group-2 rescue-clause path is the only `dynamic_cast` survivor.
   At that point, replace rescue clauses with the IS_A LUT (eating
   the Array allocation) and disable RTTI globally for the modest
   code-size win + clearer "this codebase doesn't depend on RTTI"
   boundary.

---

## Methodology

```
grep -rn 'dynamic_cast' lib/frozone/compiler/backend/cpp_box/
grep -rn 'static_cast'  lib/frozone/compiler/backend/cpp_box/
grep -rn 'reinterpret_cast' lib/frozone/compiler/backend/cpp_box/
```

Each match read in context and classified into the categories above.
The hot files are `runtime/universe.rb` (39 dynamic_casts — the
biggest cluster, mostly Group 1) and `intrinsic_lowering.rb`
(8 dynamic_casts — mostly Group 2).

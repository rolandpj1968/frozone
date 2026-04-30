# Box-first optimization design notes

Status: design — none implemented. Pure optimizations, no correctness
component. Tackle as profiling motivates; the box-first model works
correctly without any of these.

This doc collects deferred optimizations to the box-first emitter and
runtime. Each section is independent; they compose where noted.

---

## 1. Universal-surface VT cleavage

Box-first emits a universal vtable on `BasicObject`: one virtual slot
per method name in the program's call surface. Every subclass inherits
these slots, possibly overriding some. Calls are uniform:
`recv->m_X(args, kwargs, block)`.

Correct but profligate. For a non-trivial program (full WQ parser +
Frozone-Ruby core, ~450 classes), `BasicObject` ends up with thousands
of virtual decls, each subclass's struct body inherits them all, and
the C++ compiler spends a substantial fraction of its time tracking
the inheritance chain.

### The cleavage

Methods split into three buckets by how precisely the compiler can
determine call targets:

1. **No-def**: the symbol isn't defined as a method on any class.
   `respond_to?` is always false; `send` is always `method_missing`.
   Cheap.
2. **Single-def in entire program**: defined on exactly one class.
   Any call that's not to an instance of that class hits
   `method_missing`. No virtual dispatch needed — direct cast + call
   (after a class check).
3. **Multi-def**: defined on multiple classes. True polymorphism.
   Requires per-class dispatch.

### Measurement

Real numbers from the WQ parser stub (`bench/stubs/selfcompile_wq2.rb`)
at AOT time, via `FROZONE_BOX_ANALYSIS=1`:

| Category   | Method names | % of total |
|------------|-------------:|-----------:|
| Total      |         2640 |       100% |
| Single-def |         1822 |     **69%** |
| Multi-def  |          818 |        31% |

Multi-def distribution (count of names by # of defining classes):

| Defining classes | # of names |
|-----------------:|-----------:|
| 2                |        270 |
| 3                |        220 |
| 4                |         79 |
| 5–7              |         73 |
| 8–24             |         23 |
| 48–54            |        137 |
| 57–99            |         16 |

The cluster around 49–54 classes is dominated by the auto-emitted
`m_class` and `m_respond_to_q` (one per class, ~450 total) plus things
like `name`, `hash`, `eql?`. The deep-polymorphism methods at 99 / 90
/ 81 / 73 classes are `:initialize`, `:inspect`, `:to_s`, `:==`. Those
genuinely need universal slots.

### Why this is the right cleavage

If 69% of method names are single-def, those slots can leave
`BasicObject`. The struct shrinks from ~2400 virtuals to ~800. Every
subclass's vtable layout gets correspondingly smaller. cc1plus's
"parser struct body" phase (currently 22% of compile time) drops
proportionally.

`respond_to?` per-class bool arrays similarly shrink — only multi-def
methods need a bit per class. Roughly 3× density improvement, and the
data still admits bit-packing for another 8× if needed.

### Single-def is a proxy, not the criterion

The real question is "**can we determine the precise call target at
this call site?**" Single-def-vs-multi-def is the AOT-only approximation
of that. Two asymmetries:

1. **Single-def, but called on the wrong class.** `Foo#weird_method`
   is single-def; some user code calls `obj.weird_method` where `obj`
   could be anything. The single-def fast path needs a class check;
   on a miss we fall through to `method_missing`.

2. **Multi-def, but precise at this call site.** `to_s` is defined on
   81 classes, but with TI proving `recv` is exactly `Integer` here,
   the call is unambiguous. Direct-dispatch wins are available even
   for multi-def names — they just need TI's per-call-site receiver
   typing.

The right model is per-call-site target precision. Single-def is a
useful AOT-only first cut.

### Hierarchy-rooted VT (compounding win)

For a multi-def method whose definers form an **independent
sub-hierarchy** — say `Parser::Lexer` and `Parser::LexerStrings`, no
overriders elsewhere — the slot doesn't need to live on `BasicObject`.
It can root at the lowest common ancestor of the definers. Subclasses
outside the sub-hierarchy don't carry the slot at all.

Combined with single-def removal, this further trims `BasicObject`'s
universal surface.

### Proposed data structure

Per `Symbol`, a `MethodInfo`:

```cpp
struct MethodInfo {
  enum Kind { NONE, SINGLE_DEF, MULTI_DEF } kind;
  int class_id;          // SINGLE_DEF: defining class id
  MethodFn fn;           // SINGLE_DEF: direct dispatch target
  const bool* responds;  // MULTI_DEF: per-class bit array (sized to
                         //            multi-def-count, not full surface)
};
```

`Symbol::method_info_` populated by `intern()` against a compile-time
table.

#### `respond_to?` becomes 3 cases

```cpp
BasicObject* respond_to_q(Symbol* name) {
  MethodInfo* mi = name->method_info_;
  if (!mi)                       return false_instance();
  if (mi->kind == SINGLE_DEF)    return boxed_bool(this->__class_id__() == mi->class_id);
  return boxed_bool(mi->responds[this->__class_id__()]);
}
```

#### `send` becomes 2 cases

```cpp
BasicObject* send(Array* args, ...) {
  Symbol* name = static_cast<Symbol*>(args->data[0]);
  MethodInfo* mi = name->method_info_;
  Array* rest = strip_first(args);
  if (!mi)                                   return method_missing(name->name_);
  if (mi->kind == SINGLE_DEF) {
    if (this->__class_id__() != mi->class_id) return method_missing(name->name_);
    return mi->fn(this, rest, kw, blk);
  }
  return (this->*MULTI_VT[mi->multi_id])(rest, kw, blk);  // smaller VT
}
```

#### Direct call sites

`recv.foo(args)` where `:foo` is single-def: emit class-id check +
direct call. With TI proving the type, drop the check too.

### When to do this

Tackle alongside TI integration. The data structure (MethodInfo per
symbol) and the AOT analysis (single-def detection, sub-hierarchy
identification) come first. TI integration adds per-call-site
narrowing on top.

The current 27s/1.4GB compile for full WQ parser stub is acceptable.
This is a meaningful optional optimization; defer until self-compile
runs end-to-end and TI work begins.

### Tooling

`FROZONE_CPP=1 FROZONE_BOX_FIRST=1 FROZONE_BOX_ANALYSIS=1 frozone --aot foo.rb`
prints the histogram of method-name → defining-class counts. Use this
to compare codebases.

---

## 2. is_a? — per-class 1D bitset, leaf columns pruned

Box-first answers `o.is_a?(target)` via a closed-world LUT computed at
AOT time. Currently a single global `IS_A[N_CLASSES][N_CLASSES]` bool
table; every receiver indirects through `__class_id__()` to find its
row, every target through `instance_class_id_` (a Class field) to find
its column.

Correct, but the table is large and the data is structurally global —
not co-located with the classes that use it. Two compounding cleanups
shrink the table by ~5× and turn the hot path into a single static-
array index in the same cache line as the receiver class's other
metadata.

### The cleavage

Targets split by what their is_a? semantics need:

1. **Leaf class targets** — no subclasses, no module includes.
   `o.is_a?(Leaf)` is true iff `o.class == Leaf`. A bit table is
   overkill; identity check suffices.
2. **Non-leaf targets** — modules and classes with subclasses. Real
   ancestry walk needed; the LUT must record receiver-class →
   target-class bits.

A receiver can be a leaf (most are) and still need a LUT lookup when
the target is non-leaf, so receivers stay full-surface. Only the
target dimension prunes.

### Measurement

For our box-first universe at WQ self-compile (`bench/stubs/selfcompile_wq2.rb`):

| Category               | Class count | % of total |
|------------------------|------------:|-----------:|
| Total classes/modules  |      ~1000  |       100% |
| Leaf classes           |       ~800  |     **80%** |
| Non-leaf (modules + classes-with-descendants) | ~200 |       20% |

(Approximate — exact numbers come from a `FROZONE_BOX_ANALYSIS=1`-style
print once the analysis is implemented.)

The current `IS_A[N][N]` table is ~1MB of bools. Pruning columns to
non-leaves drops it to ~200KB. Splitting it per-class drops the
working-set hit per call to a single ~200-byte row.

### Why per-class 1D over global 2D

Same total bytes, but every is_a? call only touches its receiver
class's row. The current global `IS_A[N][N]` lookup pages through the
cold half of a 1MB table; a per-class row stays in the same cache
line as the class's other metadata.

Beyond cache locality: data co-locates with the class. The eigenclass
struct already exists (it carries `instance_class_id_` for the IS_A
LUT); adding `is_a_lut_` to it keeps related metadata together rather
than spread across a global block.

### No per-class virtual override

The data lives on the Class struct (eigenclass singleton); m_is_a_q
is implemented once on `Object` and reaches through to the receiver's
class via the existing `m_class()` virtual:

```cpp
inline BasicObject* Object::m_is_a_q(Array* args, Hash*, Proc*) {
  // m_class is auto-emitted on every class; eigenclass instances all
  // return &Class_CLASS (with_auto_overrides targets Class_CLASS, not
  // each eigenclass's own singleton). One pointer compare beats a
  // dynamic_cast RTTI tree walk.
  if (args->data[0]->m_class((new Array({})), nullptr, nullptr) != &Class_CLASS)
    return false_instance();
  auto* tc = static_cast<Class*>(args->data[0]);
  auto* my = static_cast<Class*>(m_class((new Array({})), nullptr, nullptr));
  if (tc->is_leaf_) return boxed_bool(my == tc);
  return boxed_bool(my->is_a_lut_[tc->lut_col_]);
}
```

Receivers don't gain a virtual; `m_class` is auto-emitted on every
class anyway (Kernel#class), so we're using a dispatch that already
exists.

### Proposed data structure

The Class C++ struct grows three fields, populated in
`__init_static_state__` alongside `instance_class_id_`:

```cpp
struct Class : Object {
  int  instance_class_id_ = -1;  // existing: id of the class this Class
                                 // singleton represents
  bool is_leaf_         = false; // new: no subclasses + no module includes
  int  lut_col_         = -1;    // new: column index in pruned LUT,
                                 //      -1 if leaf (never indexed)
  const bool* is_a_lut_ = nullptr; // new: receiver's row, sized to
                                   //      number-of-non-leaves
};
```

Per-class data emitted as a static const near the class definition:

```cpp
static const bool IS_A_Foo[M_NON_LEAF] = {/* row */};
// in __init_static_state__:
Foo_CLASS.is_a_lut_ = IS_A_Foo;
Foo_CLASS.is_leaf_  = <true if Foo has no descendants>;
Foo_CLASS.lut_col_  = <column index or -1>;
```

Modules: same struct (treated as a class for emission), `is_leaf_ =
false` by construction (modules exist to be included), `lut_col_ =
<index>`.

### Codepath comparison

**Today:**
```cpp
inline BasicObject* Object::m_is_a_q(Array* args, ...) {
  int my_id     = this->__class_id__();    // virtual call
  auto* tc      = dynamic_cast<Class*>(args->data[0]);
  if (!tc) return false_instance();
  int target_id = tc->instance_class_id_;
  return boxed_bool(IS_A[my_id][target_id]);  // hits 1MB global table
}
```

**Proposed:**
```cpp
inline BasicObject* Object::m_is_a_q(Array* args, ...) {
  // m_class is auto-emitted on every class; eigenclass instances all
  // return &Class_CLASS (with_auto_overrides targets Class_CLASS, not
  // each eigenclass's own singleton). One pointer compare beats a
  // dynamic_cast RTTI tree walk.
  if (args->data[0]->m_class((new Array({})), nullptr, nullptr) != &Class_CLASS)
    return false_instance();
  auto* tc = static_cast<Class*>(args->data[0]);
  auto* my = static_cast<Class*>(m_class(empty_args, nullptr, nullptr));
  if (tc->is_leaf_) return boxed_bool(my == tc);  // ~80% of targets
  return boxed_bool(my->is_a_lut_[tc->lut_col_]); // hot path: 200 bytes
}
```

The `is_leaf_` branch is highly predictable per call-site (target
class is usually constant at any one site). For leaf targets it's a
single pointer compare; for non-leaf, a bool lookup at a small offset
into the already-warm Class struct.

### When to do this

Pure optimization, no correctness component. Tackle when:

- Profiling shows is_a? on the hot path (hash lookups via
  `Class === instance`, case/when dispatch, type-guarded fast paths).
- Or: cc1plus parse time becomes a problem from the global IS_A table
  size.

The current global LUT is fine for a few-class universe; pays off
most once the universe scales (Frozone²+core4 ~1000 classes).

### Interactions

- **Leaf detection** is a closed-world AOT analysis. Same input as
  the IS_A LUT walker (ancestor chains incl. module includes); just
  record whether each class has any descendants.
- **Composes with §1.** Both shrink BasicObject's surface but in
  different dimensions: §1 removes single-def *method slots*; §2
  reorganizes *is_a? data* away from a global table. Independent wins.
- **Doesn't change m_kind_of_q / m_instance_of_q** — they still
  bottom out into m_is_a_q (kind_of?) or pointer compare on m_class
  (instance_of?).

### Tooling

Add a counter to the existing `FROZONE_BOX_ANALYSIS=1` output: leaf
class count vs. total. The per-class LUT row size = non-leaf count =
the real win factor.

---

## 3. dynamic_cast removal

Status: partial — `m_is_a_q` body now compares `m_class()` against
`&Class_CLASS` instead of `dynamic_cast<Class*>`. The remaining call
sites stayed for now and want a follow-up.

### The pattern

`dynamic_cast` walks the class's RTTI tree at runtime. For our box-
first hierarchy (1 to 4 levels deep typically) it's fast — ~10ns
typical — but it's also opaque to the optimizer, defeats LTO devirt,
and forces RTTI on every class. Where we only need an exact-type
check (no subclass tolerance), a single `m_class() == &X_CLASS`
compare is cheaper *and* more debuggable.

### Audit (~25 sites)

**Replaced (m_is_a_q only, today):**

- `class_emitter.rb` — `m_is_a_q` body checks args[0] is a Class.

**Easy wins, exact-type checks (do when convenient):**

- `String#==` / `String#!=` — `dynamic_cast<String*>(other)`.
- `Array#m_aset` Range branch — `dynamic_cast<Range*>(idx)`.
- `ruby_puts` Integer/Float/Symbol/String arms — exact-type dispatch.

**Hot path, blocked on a cheap class accessor:**

- Integer/Float arithmetic ops (m_plus/minus/mul/div/lt/gt/le/ge/eq_q
  /ne_q) — currently `if (auto* f = dynamic_cast<Float*>(other))`.
- Float `as_double` static — same, called from every Float-side
  arith op.

These are inside tight numerical loops. `m_class()` per-call would
require allocating an empty `Array*` each invocation (universal
protocol arg) — a regression vs RTTI. Plan: introduce a non-virtual
`klass()` accessor (or a no-arg virtual returning `Class*` directly)
so hand-coded bodies can write `o->klass() == &Float_CLASS` without
allocation. Tackle alongside any wider arithmetic fast-path work.

**Should stay (genuinely needs subclass matching):**

- Rescue clause emission (`cpp.rb` from_rescue) — `rescue StandardError`
  must catch every descendant. Could swap to `m_is_a_q` (LUT lookup)
  but that adds an Array allocation per throw and isn't faster than
  the RTTI walk for exception hierarchies that are typically 2-3
  levels.

### Why bother

- C++ code stays cleaner without RTTI gymnastics; readers see a
  pointer compare and immediately understand the semantics.
- Once §1 (single-def slot removal) and §2 (per-class is_a? LUT)
  land, the runtime layer has fewer dynamic_cast call sites overall;
  removing the rest from the hot path completes the picture.
- Frees us to disable RTTI globally (`-fno-rtti`) — modest code-size
  win, more importantly a clearer "these classes don't need runtime
  type info" boundary.

### When to do this

Whenever the cheap-accessor question gets answered. The is_a? case
got handled today because m_class is already auto-emitted on every
class and the cost was a single warm allocation off the hot path —
arithmetic ops can't accept that, so they wait.

---

## 4. Reachability pruning

Status: class-level + method-level **landed** as of 2026-04-30 in
`lib/frozone/compiler/reachability.rb` + `Emitter#collect_call_surface`.
Concrete: fib drops from ~480k cpp LoC / 64MB binary to ~50k LoC /
13MB. Constant-level pruning, TI-narrowed surfaces, and other
follow-ups described in **docs/reachability-pruning.md**. The text
below is the original pre-implementation design — kept for context,
but read the new doc for current state.

### Background

Box-first today emits a method body for **every** entry in
`methods_table` of every class in the universe — `core/4.0/` + parser
+ user code. Even fib (a 4-line Ruby program) produces 53k lines of
C++ and a 53MB binary because the entire core stdlib ships in. Of
~8500 methods emitted for the WQ self-compile stub, ~919 graceful-
skip via EmissionError; many of those are in code paths that user
code can't reach.

### Two-stage pruning

**Stage 1 — call-surface filter.** `collect_call_surface` already
walks every `MethodCall` AST node in the program (transitive through
`require`d files). The output is the set of method NAMES potentially
invoked. Inverting the lens: a method `m_foo` only needs a body if
`:foo` is in the call surface. For fib this drops the surface from
~2640 names to ~50; ~95% of method bodies become unreachable and
trimmable. Cheap — no static analysis beyond what we already do.

**Stage 2 — TI-narrowed receiver set.** With per-call-site receiver
types from TI, narrow further: at each call site `recv.foo`, only
the (class-of-recv, foo) pair needs to be live. For `recv : Integer`,
only `Integer#foo` (and any module mixed into Integer's MRO) survives.
Composes with Stage 1 — Stage 1 culls cold names, Stage 2 culls cold
(class, name) pairs.

### Dynamic-call escape hatches

Pruning has to be conservative around:

- **`klass.new(...)`** where `klass` is a non-literal — could be any
  class with `new` reachable. Closed-world we can union the set of
  classes any constant or local is *known* to hold, often shrinks the
  universe substantially.
- **`obj.send(:m, ...)`** with non-literal symbol — receiver narrows
  by TI, but the method-name set is unknown. WQ parser's
  `send(:_lex_action_<id>)` is the canonical case; the name set IS
  computable from the lexer table, but the analyser would need to
  understand the symbol-construction pattern.
- **`obj.send(:m, ...)`** with literal symbol — fully prunable, same
  as a regular call.
- **`Object.const_get(...)` / `marshal_load` / `eval`** — fully
  dynamic, can't be pruned. Keep the universe alive on these.

For our typical workload (benchmarks, AOT-compiled apps), the
dynamic patterns are rare and known. Mark them at AOT analysis time
and fall back to the full universe only for affected slots.

### Expected impact

- **fib-class programs:** ~10× compile-time + binary-size reduction
  (~80% of core/4.0/ unreachable).
- **WQ self-compile:** maybe 2-3×; the parser drags in a lot of
  genuinely-needed core. But the 919-graceful-skip count would drop
  significantly because most are in unreachable code.
- **Debug cycle:** unsupported-AST EmissionErrors only fire on
  reachable methods, so the "fix one gap, regen, hit next gap" loop
  shortens.

### Interaction with §1 (universal-surface VT cleavage)

§1 trims the surface horizontally (drop universal slots when a name
is single-def). Reachability pruning trims vertically (drop method
bodies when no call site uses them). They compose — a slot might be
single-def AND unreachable, in which case both can leave.

### When to do this

Once compile-time becomes the bottleneck on iteration cycles. Today
~2 min for wq2 is uncomfortable but tolerable; if it grows past
5 min the pruning becomes the obvious next move. Stage 1 is cheap
and worth doing first; Stage 2 waits for TI integration.

### Aside: how cheap can per-class identity be?

The "cheap accessor" question is really "how do we get a Class*
from a BasicObject* without per-instance storage and without a real
function call?" Standard C++ doesn't give you that for free. Three
levels:

1. **Virtual `klass()`** — adds one vtable slot per class (free, vtables
   already exist), but each call is `vptr load → vtable slot load →
   indirect call to a 1-instruction function`. Same cost class as
   `dynamic_cast<X*>` for shallow hierarchies — just cleaner code,
   no RTTI tree walk. The compiler does **not** inline the return
   value into the vtable; the call is real.

2. **vptr compare** — under the Itanium ABI (gcc/clang on Linux), the
   vptr lives at offset 0. `*(void**)a == *(void**)&Foo_PROTO` is a
   single load + compare — no call, no vtable indirection. Compiler-
   specific but reliable in practice. Useful for hot-path exact-type
   checks (Integer/Float arithmetic), where the price of a virtual
   call relative to the actual work is meaningful.

3. **Per-instance Class\*** — 8 bytes per object. Single load, no
   indirection. Cleanest semantics. Catastrophic for Integer (16-byte
   instance becomes 24-byte). Don't.

The §2 design (per-class is_a? bitset) uses (1) — `m_class()` is
already paid for elsewhere (Kernel#class). The hot-path arithmetic
dynamic_casts in §3 want (2) eventually; we'd write a small
`klass_is(BasicObject* o, Class* k)` helper that does the vptr
compare and use it in numeric op bodies. That removes the last RTTI
dependency in the hot path and unlocks `-fno-rtti` globally.

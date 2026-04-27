# Box-first universal-surface VT optimization

Status: design — not implemented. Tackle alongside TI integration.

## Background

Box-first emits a universal vtable on `BasicObject`: one virtual slot per
method name in the program's call surface. Every subclass inherits these
slots, possibly overriding some. Calls are uniform:
`recv->m_X(args, kwargs, block)`.

This is correct but profligate. For a non-trivial program (full WQ parser
+ Frozone-Ruby core, ~450 classes), `BasicObject` ends up with thousands
of virtual decls, each subclass's struct body inherits them all, and the
C++ compiler spends a substantial fraction of its time tracking the
inheritance chain.

## The cleavage

Methods split into three buckets by how precisely the compiler can
determine call targets:

1. **No-def**: the symbol isn't defined as a method on any class. `respond_to?`
   is always false; `send` is always `method_missing`. Cheap.
2. **Single-def in entire program**: defined on exactly one class. Any call
   that's not to an instance of that class hits `method_missing`. No virtual
   dispatch needed — direct cast + call (after a class check).
3. **Multi-def**: defined on multiple classes. True polymorphism.
   Requires per-class dispatch.

## Measurement

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
like `name`, `hash`, `eql?`. The deep-polymorphism methods at 99 / 90 /
81 / 73 classes are `:initialize`, `:inspect`, `:to_s`, `:==`. Those
genuinely need universal slots.

## Why this is the right cleavage

If 69% of method names are single-def, those slots can leave
`BasicObject`. The struct shrinks from ~2400 virtuals to ~800. Every
subclass's vtable layout gets correspondingly smaller. cc1plus's
"parser struct body" phase (currently 22% of compile time) drops
proportionally.

`respond_to?` per-class bool arrays similarly shrink — only multi-def
methods need a bit per class. Roughly 3× density improvement, and the
data still admits bit-packing for another 8× if needed.

## Single-def is a proxy, not the criterion

The real question is "**can we determine the precise call target at
this call site?**" Single-def-vs-multi-def is the AOT-only approximation
of that. Two asymmetries:

1. **Single-def, but called on the wrong class.** `Foo#weird_method` is
   single-def; some user code calls `obj.weird_method` where `obj` could
   be anything. The single-def fast path needs a class check; on a miss
   we fall through to `method_missing`.

2. **Multi-def, but precise at this call site.** `to_s` is defined on
   81 classes, but with TI proving `recv` is exactly `Integer` here, the
   call is unambiguous. Direct-dispatch wins are available even for
   multi-def names — they just need TI's per-call-site receiver typing.

The right model is per-call-site target precision. Single-def is a
useful AOT-only first cut.

## Hierarchy-rooted VT (compounding win)

For a multi-def method whose definers form an **independent
sub-hierarchy** — say `Parser::Lexer` and `Parser::LexerStrings`, no
overriders elsewhere — the slot doesn't need to live on `BasicObject`.
It can root at the lowest common ancestor of the definers. Subclasses
outside the sub-hierarchy don't carry the slot at all.

Combined with single-def removal, this further trims `BasicObject`'s
universal surface.

## Proposed data structure

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

### `respond_to?` becomes 3 cases

```cpp
BasicObject* respond_to_q(Symbol* name) {
  MethodInfo* mi = name->method_info_;
  if (!mi)                       return false_instance();
  if (mi->kind == SINGLE_DEF)    return boxed_bool(this->__class_id__() == mi->class_id);
  return boxed_bool(mi->responds[this->__class_id__()]);
}
```

### `send` becomes 2 cases

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

### Direct call sites

`recv.foo(args)` where `:foo` is single-def: emit class-id check + direct
call. With TI proving the type, drop the check too.

## When to do this

Tackle alongside TI integration. The data structure (MethodInfo per
symbol) and the AOT analysis (single-def detection, sub-hierarchy
identification) come first. TI integration adds per-call-site narrowing
on top.

The current 27s/1.4GB compile for full WQ parser stub is acceptable.
This is a meaningful optional optimization; defer until self-compile
runs end-to-end and TI work begins.

## Tooling

`FROZONE_CPP=1 FROZONE_BOX_FIRST=1 FROZONE_BOX_ANALYSIS=1 frozone --aot foo.rb`
prints the histogram of method-name → defining-class counts. Use this
to compare codebases.

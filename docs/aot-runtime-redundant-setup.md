# AOT-runtime redundant-setup problem (and design options)

## The problem

Box-first AOT compiles the **execute phase** of the entry script into C++, with
`__init_static_state__` reproducing the **post-load-phase snapshot** of every
Vm-level class (methods tables, instance variables, hierarchy, constants).

The split is at top-level node granularity in the entry file: `split_and_load`
classifies each top-level statement as load- or execute-phase, runs the load
nodes pre-AOT, snapshots, and emits the execute nodes as compiled main. That
part works as designed.

The leak: the AOT split only sees **top-level nodes of the entry file**. It
cannot see what *methods called from the execute phase* will themselves do
internally. In frozone.rb specifically, the execute phase invokes
`Frozone::Vm::Vm.new(options).run`, and `Vm#run` begins with `load_core`
— the same setup routine the MRI-host needs to populate Vm class tables on
a cold start. Pre-AOT runs it (legitimately) to populate the snapshot;
post-AOT runs it again because `Vm#run`'s body is identical on both sides
and it has no way to tell that the tables are already populated.

The visible symptoms are downstream of this:

1. The compiled WqParser is exercised against every core/4.0/ file at
   startup (slow, plus exposes every parser-on-box-first bug).
2. Each `def` in those files calls `Ast::MethodDef#evaluate` →
   `klass.set_method(:foo, ...)` → `trigger_method_added(...)`.
3. `trigger_method_added` has a permissive `rescue StandardError` block
   (legitimate during boot — the Vm isn't fully wired up when methods
   start being added) which silently swallows real errors from the
   re-parsing in step 1.
4. The corrupt parser state eventually trips a totally unrelated dispatch
   failure that surfaces to the user as "BUG: method_missing not defined".

## Design options considered

### Option 1: Restructure frozone source for explicit boundaries

Hoist all setup-doing methods out of `Vm#run`'s body so the boundary
between "things to do once at AOT time" and "things to do every run" is
visible at the source level.

- **Pro:** Clear mental model. Each setup method is unambiguously load-time.
- **Con:** Invasive — every host method that defines methods on Vm class
  objects has to know which side it's on. That knowledge lives in many
  places, easy to drift.
- **Ruby precedent:** Limited. `require` is just a method call;
  Rails has a boot pipeline by convention but nothing language-level.
  Restructuring frozone this way means writing against the grain.

### Option 2: Idempotent requires + class defs (preferred)

Recognise that closed-world AOT *already promises* no new method definitions
at runtime. Make method/class/const definition AST nodes no-op when they're
re-evaluating something that's already in the snapshot.

- `Ast::MethodDef#evaluate` — if already-loaded sentinel is set and the
  method is already on the target class, return nil.
- `Ast::ClassDef#evaluate` — class re-opening: just iterate the body,
  whose def nodes are themselves no-ops.
- `Ast::ConstantWrite` against the snapshot — same.
- `require` / `require_relative` — already idempotent against `BUILD_FILES`.

Properties:

- Source-level symmetry: code on both sides is identical, no boundary
  markers required.
- One-line runtime mechanism: a sentinel flag set by `__init_static_state__`.
- Closed-world enforcement preserved: any *new* def at runtime stays a
  violation; the no-op only applies to *re*-defining what's already there.
- Doesn't make the parse cost go away (re-parsing core/4.0/ still happens),
  just makes its effects null. A follow-up pass that short-circuits
  `evaluate_file` on `BUILD_FILES`-resident paths finishes that.

Ruby precedent: Ruby itself doesn't auto-skip method redefinitions because
they're a feature — you can re-open a class and replace a method. Closed-world
gives that up anyway, so eliding it is free.

### Option 3: NOP via "everything is already done"

Combine option 2 with a `BUILD_FILES`-aware short-circuit on
`evaluate_file`/`require_relative`: if the path was loaded pre-AOT, don't
re-parse and re-evaluate. This eliminates both the work and the parse cost.

## Recommended path

Option 2 + the file-level short-circuit from option 3, deferred. For now,
the immediate hack is to gate `Vm#load_core` on a sentinel that's set
post-AOT (via `__init_static_state__`'s state) so the redundant re-load
goes away. That's enough to unblock `/tmp/frozone_box hello.rb` and stop
exercising the parser at startup.

Long-term, the no-op-redefine treatment for `Ast::MethodDef`/`ClassDef` is
the principled fix — it patches over any *future* internal-setup pathway
that gets hidden behind a method call we haven't audited.

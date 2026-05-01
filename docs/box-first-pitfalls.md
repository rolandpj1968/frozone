# Box-first pitfalls

A diagnostic-first reference for box-first AOT bugs we've actually
hit. Each entry leads with the symptom you'd observe, then traces it
to root cause, the resolution we applied, and forward implications
for similar bugs.

If you're reading this because something's wrong, scan the **Symptom**
sections first — the symptoms are typically far removed from the
root cause and have led to multi-hour bisects in the past.

For "how does box-first work" questions, see
`docs/cpp-backend.md`, `docs/cpp-object-model.md`, and
`docs/box-first-optimization.md`.

---

## 1. Lambda `[&]` captures `this` by reference

### Symptom
A method works correctly when called inline but produces garbage,
crashes, or silently returns nil when called via a Proc that was
stored on an ivar (e.g. `@callback = lambda { ... }; ...; @callback.call`).
With `gcc -O0` the failures are sharper; `-O2` may inline them
away and mask the bug intermittently.

### Root cause
Box-first lowered every block as `new Proc([&](Array* __blkargs__) {
... }))`. Inside a member function, `[&]` captures every used
local *by reference*, including `this` — but `this` is a function
parameter (a `BasicObject*` pointer), and capturing it by reference
takes a reference to the parameter slot, not the pointer's value.
Once the parent function returns, the parameter slot is gone; later
invocations of the lambda dereference a dangling reference and read
arbitrary stack memory.

For lambdas passed to `each` and called immediately, the parent
function is still on the stack so the bug doesn't manifest. For
lambdas stored on ivars (Lexer's `@emit_integer = lambda{...}` set
in `initialize`, then called from `advance`) the parent stack frame
is long gone.

### Resolution
Changed `new Proc([&](...))` to `new Proc([&, this](...))` in both
emission sites in `cpp.rb` and `expr_emitter.rb`. The `[&, this]`
form captures `this` *by value* (a copy of the pointer) while keeping
locals captured by reference for closure-mutation semantics.

### Forward implications
Any new Proc/lambda emission site needs `[&, this]` not `[&]`. If
you see "this->foo() returns garbage when called from a Proc", suspect
this. There's no static check; gcc warns only with
`-Wdangling-reference`.

---

## 2. `begin..end` always lambda-wraps via `Ast::Rescue`

### Symptom
Code inside a `begin..end` block (without rescue/else/ensure)
appears to execute, but `next` and `break` and unconditional
`next` -> goto-style control flow inside the block don't reach
the enclosing loop. Particularly catastrophic for ragel-generated
state machines: most state transition actions are emitted as
`begin .. begin @cs = N; _goto_level = _again; next; end .. end`,
and if `next` doesn't escape, the state machine never transitions
out of its initial state. You see the lexer iterate to EOF without
emitting a single token.

### Root cause
Frozone's parser converts every `Prism::BeginNode` to `Ast::Rescue`,
even when there are no rescue/else/ensure clauses. `Cpp#from_rescue`
unconditionally wraps the body in `[&]() try { ... } catch(...)
{ throw; }()` for exception handling. C++ `next`-equivalent (`continue`)
inside that lambda continues nothing — there's no enclosing loop in
the lambda's scope. The walker raises `EmissionError("break/next
inside rescue — lambda boundary blocks loop scope, not yet supported")`,
and `write_stmt_with_rescue` catches it and emits `/* skipped */`.
The whole action body becomes a no-op.

### Resolution
Statement-position `Ast::Rescue` nodes with no rescue_clauses, no
else_node, and no ensure_node now emit the body inline as plain
statements (in `expr_emitter.rb`'s `write_stmt`). `next` then
naturally lowers as `continue` targeting the outer C++ while loop.

### Forward implications
The general "break/next inside lambda" problem still exists for
real rescue/else/ensure forms. If you see ragel-style `next` or
`break` inside a body that has rescue clauses, you'll hit the
EmissionError. Real fix needs trampoline-style control flow
(throw a sentinel, catch at the loop boundary).

---

## 3. `MultipleAssignment` from non-Array RHS

### Symptom
`a, b, c = nil` (or any non-Array RHS) appears to silently corrupt
the locals. In one observed case, racc's
`_slen, _trans, _keys, _inds, _acts, _nacts = nil` left all six
locals as undefined garbage, making subsequent `_slen->m_gt(0)`
return non-deterministic results that varied across compiler
versions and optimization levels.

### Root cause
`expr_emitter.rb`'s MultipleAssignment lowering used to emit
`Array* __mass_rhs_N__ = static_cast<Array*>(<rhs_str>);` —
unconditional `static_cast`, no runtime type check. If the RHS
evaluated to `nil_instance()`, `static_cast<Array*>(nil_instance())`
gave a pointer that *looked* like an Array but had no `data`
field at the right offset. Then `__mass_rhs_N__->data.size()`
read garbage, target slots got nil-or-garbage, and the program
appeared to work but produced wrong answers.

### Resolution
Now uses `dynamic_cast<Array*>` plus a wrap-non-Array path: if RHS
is not an Array, build a fresh 1-element Array containing the value
(or empty if nil). Mirrors MRI's "first target gets value, rest
get nil" semantics.

### Forward implications
Any other `static_cast` of an arbitrary RHS to a specific runtime
type is suspect. The general principle: only `static_cast` when the
caller's static type *guarantees* the runtime type. Anywhere we
accept `BasicObject*` and want a specific subtype, use `dynamic_cast`
with a fallback.

---

## 4. `intern()` aliases the caller's `const char*`

### Symptom
Symbols printed as garbage (e.g. `:+` rendered as `:TV��`).
Particularly for symbols built from runtime strings (e.g.
`String#to_sym`, attribute name lookups in metaprogramming
patterns). Symbols built from string literals
(`intern("=~")` etc.) work correctly because string literals have
program-lifetime storage.

### Root cause
`intern()` stored the caller's `const char*` directly in
`Symbol::name_`:
```cpp
Symbol* s = new Symbol(name);
table[std::string(name)] = s;
```
For string-literal callers (`intern("=~")`), `name` points to a
read-only segment that lives for the program's lifetime — safe.
For runtime-string callers like `string_to_sym`'s
`intern(_buf.c_str())` where `_buf` is a stack-local
`std::string`, the `c_str()` pointer goes dangling once the lambda
returns. Later `Symbol::name_` reads see whatever the stack has
been reused for.

### Resolution
`intern()` now inserts into the table first (`std::string` key
moved into the unordered_map), then takes `name_` from the
table-owned `c_str()` — the unordered_map's key strings live for
the program's lifetime.

### Forward implications
Any `const char*` stored across a function boundary needs ownership
analysis. If you're tempted to write `something->name = some_string`
where `some_string` is a parameter, ask: where does the parameter
come from? Literal? OK. Heap-owned? OK with refcount. Stack-local?
You need to copy.

---

## 5. Derived-class C++ ivar shadowing

### Symptom
A child class's getter (`m_expression()`) returns nil even after
the parent class's initializer (`Map#initialize`) was clearly called
and assigned. Most painfully diagnosed via "the method call works,
the assignment ran, but the read shows nil" — the smoking gun is
that the parent's body ran on `this` and our debug print says
`this->iv_X = real_value`, yet a moment later `this->iv_X` reads as
`nil_instance()` from the child's body.

### Root cause
`collect_ivars` walks `class_methods(cls)`, which uses
`ModuleFlattening.flatten` and so includes the *parent's* methods.
Every `@expression` reference in any flattened-in parent method
caused the derived class to redeclare `BasicObject* iv_expression
= nil_instance();`. C++ doesn't merge field declarations across
inheritance — the derived field shadows the base field. Then:
- `Map::m_initialize`, compiled at Map's class scope, writes to
  `Map::iv_expression`.
- `Map::Operator::m_expression`, compiled at Operator's class
  scope, reads `Operator::iv_expression` — a totally separate
  storage slot, default-initialised to nil.

### Resolution
`build_user_class_def` now collects parent ivars (via
`collect_parent_ivars` walking the superclass chain) and filters
them out of the derived class's declaration list.

### Forward implications
Any data emitted on a struct that's also on the parent will
silently shadow. If you add a new emission for inheritable state
(non-method members), make sure to filter against parent membership.

---

## 6. Ruby-2 trailing-hash vs kwargs

### Symptom
Methods declared with a trailing positional `Hash` parameter
(e.g. `def initialize(type, children=[], properties={})`) silently
lose the trailing-hash arg from callers using hash-syntax
(`Foo.new(t, c, location: map)`). The `properties` parameter binds
to its empty-Hash default, the trailing hash is invisible. AST
nodes built this way end up with `node.loc == nil`, then a
downstream consumer raises "undefined method 'expression' for nil".

### Root cause
Ruby 2 binds `Foo.new(t, c, location: map)` as a 3-arg call where
the third arg is the hash literal `{location: map}` — so it binds
to `properties`. Ruby 3 keyword separation passes hash-syntax args
as kwargs. The Frozone interpreter follows Ruby 2 semantics. Box-first
call sites pass kwargs as a separate `Hash* kwargs` argument; the
callee's positional binding never sees the trailing hash. The parser
gem (and presumably any pre-3.0 Ruby code) heavily relies on this
binding.

### Resolution
At param-bind time in `method_emitter.rb`'s `unpack_params`: if
the method declares no kw params (no `required_kw_params`,
`optional_kw_params`, or `kw_rest_param`) and `kwargs` is non-empty
at call time, append it to `args` as the trailing positional Hash.

### Forward implications
Any method that *does* declare kw params skips this fixup, matching
Ruby 3 semantics. If you see pre-3.0 code where a Hash arg appears
to disappear, double-check the callee's signature has no `**rest`
or kw declarations.

---

## 7. `return` from a block doesn't escape

### Symptom
`each { |x| return true if x.match? }` always returns nil — the
truthy match is found, but `return true` doesn't propagate up to
the enclosing method. `Enumerable#any?`, `#all?`, `#none?`, `#find`
etc. all silently return false/nil even with truthy elements.

### Root cause
Box-first lowers blocks as Procs whose body is a C++ lambda
returning `BasicObject*`. `return true` inside the block compiles
to `return true_instance();` — but that returns from the **lambda**,
not from the enclosing Ruby method. `m_each` ignores the lambda's
return value (it just iterates), so `return true` becomes
`next true`.

### Resolution
For `Array#{any?,all?,none?,one?}`, rewrote in pure Ruby using
index-based `while` loops to avoid the each-block path entirely.
Tactical only; doesn't fix the general case.

### Forward implications
- `next` inside a block *does* work correctly (return-from-Proc-lambda
  IS the right semantics for `next`).
- `break` inside a block currently raises EmissionError (no
  iterator-exit machinery).
- `return` inside a block silently misbehaves — no error, just
  wrong answers. The general fix needs trampoline-style control flow:
  block raises a sentinel exception, method's iterator-call site
  catches and propagates as method return. Significant runtime work.

---

## 8. cpp_name encoding collisions

### Symptom
A user-defined `def match_op(...)` works in interpreted Frozone but
silently doesn't get called in box-first AOT — calls fall through
to method_missing or a *different* `match_op` body.

### Root cause
`Cpp.method_name(:match_op)` returns `m_match_op`. So does
`Cpp.method_name(:=~)` (the operator name was explicitly mapped to
`m_match_op` to avoid an earlier collision with `:match`). The
surface walker was keyed by cpp_name in a `calls` hash and
`next`'d on duplicates — when `:=~` was seen first (as it usually
is via Enumerable code), `:match_op` was treated as already-handled
and its bodies never got scheduled. The cpp emits the eigenclass's
m_match_op slot from the first-seen Ruby name's body — which is
`=~`, not the user's literal `def match_op`.

### Resolution
`collect_call_surface` now tracks `seen_ruby_names` separately from
`calls`. Each Ruby name's bodies get scheduled even when its cpp_name
is already in `calls` under a different Ruby name. The `calls` map
still uses cpp_name (it's emitted as a single C++ slot) but body
scheduling is per Ruby name.

### Forward implications
Any cpp_name collision means the C++ slot serves multiple Ruby
methods — they share a vtable entry. If two Ruby methods semantically
diverge but encode to the same cpp_name, the LAST-emitted body wins.
Worth a future audit of `Cpp::OP_NAMES` for unintentional collisions.

---

## 9. Skipped intrinsic body becomes silent no-op

### Symptom
Many follow-on bugs in this list ultimately trace here: a method
whose body in `lib/core/4.0/` is `Intrinsics.foo(self, ...)`, where
`foo` has no template in `cpp_box/cpp.rb`. The emitter silently
emits the method as a no-op (the body just falls through to
`return nil_instance();`). The method then "exists" (responds_to
is true, dispatches correctly) but always returns nil.

### Root cause
`from_intrinsic_call` raises `EmissionError("intrinsic :foo not yet
supported")` when there's no template. `write_stmt_with_rescue`
catches and emits `/* skipped */`. The method body is otherwise
empty, so `return nil_instance()` is the only effective statement.
Callers see a method that always returns nil — confused for "the
method doesn't exist" or "the data isn't being written" or "the
predicate is always false".

### Resolution
Per-intrinsic, add a template to `INTRINSIC_TEMPLATES` in
`cpp_box/cpp.rb`. This session added: `Hash#{key?,[],[]=,size}`,
`Symbol#{to_s,inspect}`, `String#{to_i,to_sym}`, `Encoding.compatible?`,
`fiber_storage_{get,set}`.

### Forward implications
- Setting `FROZONE_BOX_DEBUG=1` prints `[box-first] skip stmt: ...`
  for each skipped emission. Useful to grep.
- Any time you see "method X exists but returns nil", check whether
  X's body uses an intrinsic. Easiest reproducer: `Foo.new.X.class`
  → if it says `NilClass` and the Ruby def says `Intrinsics.foo`,
  that's it.
- Long-term: `from_intrinsic_call` could refuse to silently emit
  empty bodies for missing intrinsics on the strict-emit path
  (we already strict-emit user code under `with_strict_emit`); the
  body would then become a TypeError or abort instead of nil.

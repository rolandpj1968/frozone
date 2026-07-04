# Reflection under closed-world AoT

Ruby has four families of dynamic-name access:

- `send(sym)`, `public_send(sym)`, `__send__(sym)` — dispatch a method by symbol
- `instance_variable_get(sym)` / `instance_variable_set(sym, val)` — read/write an ivar by symbol
- `const_get(name, inherit=true)` / `const_set(name, val)` — read/write a constant by name
- `const_missing` / `method_missing` — user-defined hooks for the miss paths

Under closed-world AoT compilation, all four are in principle statically resolvable — the compiler knows every method, every ivar, every constant that can ever exist in the program. Dynamic-name access reduces to a lookup in a compile-time-known table.

## The switch-based framing

Every dynamic-name form has the same shape: `receiver.op(sym)` where `sym` names a slot on the receiver's class. Under closed-world AoT the slot set is finite and known at emit time. The natural lowering is a switch:

```cpp
BO* m_instance_variable_get(Symbol* sym) override {
  switch (sym->ivar_id_) {
    case IV_a: return iv_a;
    case IV_b: return iv_b;
    // ...
    default: return nil_instance();   // or NameError
  }
}
```

The switch IS the closed-world assertion made concrete. Reachability sees every branch — nothing hides behind a reflection escape because there is no reflection any more. Dispatch is one virtual call + one small switch, cache-local per class, competitive with direct field access after basic-block optimisation.

The switch's default case is the strictness knob:
- **Strict AoT**: `default: raise NameError` (or compile-time refusal if the argument is a constant Symbol not in the case list).
- **Permissive with lookaside**: `default: fall back to per-object Hash for dynamically-created slots.`

Frozone today errs strict — dynamic-name access forms that aren't statically resolvable currently `std::abort()`.

## Per-primitive status and asymmetry

### `send` — already switch-based via `METHOD_VT`

`Object::m_send(sym)` and `m___send__(sym)` do `(this->*METHOD_VT[method_id])(...)` — a single global function-pointer table indexed by an integer method_id assigned at Symbol intern time. Inheritance is free: class construction copies parent method-VT slots into child VT slots, so send resolves through the normal method lookup chain without special-case code.

Send benefits from a **global** table because a method_id names a UNIFORM SLOT across all classes — every class either has an implementation in that slot or inherits the parent's. The vtable IS the closed-world method surface.

### `instance_variable_get` / `instance_variable_set` — abort-stub today

Frozone compiles both to `std::abort()` with the message "dynamic ivar access not supported." The `iv_instance_variables_hash` slot on `Object` is a vestigial declaration — no code writes to it.

Ivars are inherently **per-class** because different classes have different field layouts. There is no meaningful global "IVAR_VT" — slot 0 is a different field on every class. The natural pattern is per-class virtual `m_instance_variable_get(sym)` and `m_instance_variable_set(sym, val)` whose bodies are switches over that class's own ivars (plus inherited ones via C++ struct inheritance).

An interned `@name` → integer `ivar_id_` gives an O(1) integer compare inside each switch instead of Symbol pointer compare. The dispatch is virtual + switch (small — bounded by ivars per class). Not as compact as send's single table, but still very cheap.

Look-aside for dynamically-created ivars (Ruby's `instance_variable_set(:@brand_new, val)` on any object): a per-object `iv_dynamic_hash` in the switch's default case. Opt-in: classes that need it declare it, others stay lean. Or refuse entirely — depends on how much dynamic-ivar-creation appears in target programs.

### `const_get` / `const_set` — abort-stub today, harder than ivars

Both compile to the not-implemented stub. Landing them cleanly is more architecturally invasive than ivars:

1. **Constant resolution semantics.** Receiver-form `X.const_get(name)` is simpler than bare `C` in code (which walks lexical scope) — receiver-form only walks X's own constants + X's ancestor chain. Per-class `m_const_get(sym)` virtual with a switch is the natural pattern, analogous to `m_instance_variable_get`.

2. **Constant mutation.** Method tables in Frozone are (mostly) closed-world — `define_method` at runtime is unusual and can be refused. Constant tables aren't necessarily closed-world; `Foo::BAR = 1` at any point in program execution is idiomatic. Strict AoT either refuses mutation post-load or maintains a per-module lookaside Hash for post-load `const_set`.

3. **Private constants** change resolution — a private constant is invisible to `const_get` from outside the defining module.

4. **`const_missing` hook** on the miss path adds a layer of dispatch.

The core "per-class switch on constant name" pattern still works. The complexity is in the surrounding table maintenance (mutation, privacy, missing hook), which is separable but nontrivial design work. Best deferred until a concrete program forces the question, ideally coordinated with broader constant-flow analysis.

## Two-layer view: correctness vs. detection

Distinguish the enforcement of AoT closed-world semantics from the compile-time diagnostic that surfaces reflection escapes.

**Correctness layer (body-level).** The compiled method body for each reflection primitive enforces the strictness knob: abort on out-of-set input, or fall back to a lookaside, or raise NameError/NoMethodError, per policy. This is what actually keeps AoT sound.

**Detection layer (reachability's compile-time diagnostic).** Reachability walking AST for reflection call sites and either (a) resolving statically when the argument is literal, or (b) flagging as force-root-required when dynamic. This is what turns silent runtime aborts into build-time errors with source locations.

The two layers are independent. Body-level enforcement holds regardless of how good the AST-level detection is. Detection is quality-of-life: better detection means better error messages before runtime.

## Aliases, overrides, and the detection layer

User code can reroute reflection through two independent mechanisms: aliasing (rename the call site to a different name that resolves to the same body) and overriding (keep the name, replace the body). Both interact with reachability's compile-time diagnostic; neither weakens body-level correctness enforcement.

### Alias direction

```ruby
class Foo
  alias my_get instance_variable_get
end
Foo.new.my_get(:@x)
```

At the AST level, the call site is `MethodCall{name: :my_get}` — a naive reachability walker looking for `name == :instance_variable_get` misses it.

**No new correctness hole.** The alias just renames the call site; the method body it resolves to is the same. Whatever strictness the body enforces (abort, switch, lookaside) applies uniformly regardless of the caller-side name.

Detection needs alias-awareness. Two levels of resolution:

**Without TI** — conservative reflection-family closure. At build time, scan every reachable class's method table for methods whose body is one of the reflection primitives (including alias entries). Collect the union of method names that resolve to a reflection body → `REFLECTION_NAMES = {:instance_variable_get, :my_get, ...}`. AST walker checks membership in this set rather than hard-coded names. Over-approximates but silences false positives via force-root annotations.

**With TI** — precise dispatch. TI resolves the receiver's class, checks that specific class's method table entry for `my_get`. If it points at a reflection body → suspect. If it points at something innocuous → clean.

The alias table is closed-world at emit time. There is no "hidden" alias — `alias_method` with a dynamic name is itself a reflection escape that would be flagged separately.

### Override direction

```ruby
class Foo
  def instance_variable_get(sym)
    Object.const_get(sym.to_s)   # tunnel to a different reflection primitive
  end
end
Foo.new.instance_variable_get(:UserClass)
```

The call site name is the canonical `:instance_variable_get` (already in `REFLECTION_NAMES`) — the naive detection flags it. The escape isn't at the call site; it's in Foo's override BODY (the inner `const_get(dyn)`).

**Naturally handled by existing body-walk.** Reachability already walks every reachable method body. Foo's override is user code — its body gets walked; the nested `const_get(dyn)` gets flagged by the same detection that would flag it if it appeared anywhere else. No new machinery.

The subtle case is TI-less receiver polymorphism:

```ruby
obj = some_condition ? Foo.new : Object.new
obj.instance_variable_get(:UserClass)  # Foo's override, or Object's default?
```

Without TI, reachability doesn't know which class's `instance_variable_get` actually runs. To be complete, the alias-closure computation must include all classes' overrides — union across every reachable class's `instance_variable_get` method-table entry. Each of those bodies gets walked; any inner reflection escape gets flagged. Over-approximates in the same way as the alias direction: false positives silenced by force-root.

### Design out — `final` on Object

MRI treats overriding `send`, `__send__`, `public_send`, and `instance_variable_get/set` as effectively-UB: user code can define them but some internal C-level paths bypass Ruby dispatch, so overrides aren't uniformly honoured. Practical guidance is "don't."

Closed-world AoT can go further: **mark these methods `final` on `Object`, refuse user overrides at compile time.** Under strict AoT this is a legitimate additional constraint. Consequences:

1. **Semantic honesty.** Frozone stops pretending to fully support something MRI itself half-supports. If a target program overrides these, the compiler refuses with a source-located diagnostic rather than silently producing a binary whose behaviour depends on which internal path takes the override.
2. **Detection simplification.** With no user overrides, only Object's canonical implementation exists. Override chains disappear from the detection surface — reachability only needs to detect direct/aliased call sites of the canonical primitive. TI-less receiver polymorphism becomes trivial because every receiver's `instance_variable_get` resolves to the same body.
3. **Alias detection still matters** — user code can still rename the call site via `alias`, so `REFLECTION_NAMES` closure computation is still needed. But that's the entire remaining complexity.

Under a permissive stance (allow overrides), the union-across-classes body walk remains correct. Under `final`, both correctness and detection get materially simpler.

This is exactly the kind of constraint closed-world AoT lets you enforce that MRI can't: turning a dubiously-supported Ruby feature into a hard compile-time error, in exchange for tighter semantic guarantees downstream.

## Frozone's practical reflection surface

For the concrete compilation universe (Frozone itself, WQ parser + Onigmo, optparse, parser gem, `lib/core/4.0/`):

| target                 | const_get     | ivar_get         | ivar_set  | send/public_send/__send__ |
|------------------------|---------------|------------------|-----------|-----------------------------|
| `lib/frozone/`         | 0 (comments)  | 0 (comments)     | 1 literal | 0                            |
| `lib/core/4.0/`        | 2 internal    | 11 internal      | ~80 internal | 26 internal                |
| optparse               | 0             | 0                | 0         | 4 literal `__send__(id)`     |
| parser gem             | 1 dynamic*    | 3 internal       | 0         | 0                            |

\* The one dynamic case is `parser/runner/ruby_rewrite.rb:43` — `Object.const_get(const_name)` where `const_name` comes from CLI args. Genuine reflection escape. The runner CLI is likely not in real compilation targets — the parser library is; the runner is dead code under normal use.

The high counts in `lib/core/4.0/` are the Frozone-Ruby stdlib implementing Ruby's reflection semantics natively (attr_accessor, Struct accessors, Object#dup, initialize_copy, etc.) — internal, statically bounded, mostly literal-symbol.

**Implication:** dynamic reflection is essentially zero in the practical Frozone compilation universe. The abort-stub strictness today rarely bites in practice. Landing the switch-based lowering unlocks the last remaining cases (parser's dynamic `const_get`, any target program with legitimate dynamic access) without weakening soundness.

## Prioritisation and design gates

- **`send` — done.** No further work.
- **`ivar_get/set` — self-contained, pick up when actually needed.** Weekend project. Per-class `m_instance_variable_get/set` virtual, small switch over own ivars, integer `ivar_id_` on Symbol, default to NameError. Ivar mutation semantics are simple: writing to a switch-listed ivar mutates the field; writing to an unknown ivar is either the NameError or the opt-in lookaside Hash. No architectural dependencies.
- **`const_get/set` — defer until forced.** Same per-class-switch pattern applies to the core dispatch, but constant mutation semantics + private constants + `const_missing` need design decisions that are best made alongside broader constant-flow analysis (Level B of the reachability roadmap). Not tractable as a small independent piece.
- **Reflection-family detection at the reachability level.** Independent from the lowering work. Improves error messages (source-located compile errors instead of runtime aborts). Alias-aware closure computation is the correct form; naive name-match works today only because Frozone code doesn't alias these methods.

- **Finalize reflection primitives on Object.** Design lever, not tied to any specific lowering task. Marking `send`, `__send__`, `public_send`, `instance_variable_get`, `instance_variable_set` (and eventually `const_get` / `const_set`) as `final` on `Object` — refusing user overrides at compile time — collapses the override branch of the detection layer entirely and buys a tighter semantic model in exchange for a rarely-exercised Ruby freedom. See "Design out — `final` on Object" above. Cheap to implement (a per-method-name check during class emission), high payoff for both detection simplicity and correctness clarity.

## Look-aside as an escape hatch

For each primitive, the switch's default case can either raise or fall back to a per-object/per-module Hash:

- **Ivars.** Per-object `iv_dynamic_hash`. Cost: extra Hash per class that opts in. Enables MRI's dynamic-ivar-creation semantics.
- **Constants.** Per-module dynamic-constants Hash. Enables runtime `const_set`.
- **Methods.** No look-aside — a runtime `define_method` on a specific instance/class is a distinct closed-world violation that requires its own strategy (or refusal).

The look-aside is a strict AoT compatibility toggle. Strict programs live without it. Permissive programs opt in at explicit runtime cost.

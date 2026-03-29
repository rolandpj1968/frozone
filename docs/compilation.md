# Frozone Crystal Compilation Target

## Overview — what we are building and why

Frozone is currently a tree-walking interpreter: it parses Ruby source with
Prism (or the WqParser) and evaluates AST nodes directly. This works well for
correctness and development speed, but every operation pays interpreter
overhead — method dispatch through a Ruby hash table, boxed VM objects for
every value, frame allocation for every call.

The goal of the compilation target is to produce **native binaries from Ruby
source code** using Crystal as a backend. The compiled program runs at native
speed with no interpreter in the loop.

The approach taken here is **closed-world ahead-of-time (AOT) compilation**
targeting Crystal as an intermediate language. This is deliberately different
from the two other common approaches (JIT and general AOT), and those
differences are worth understanding upfront.

**The key architectural insight — split load and execute:**
Most Ruby programs have two naturally distinct phases: a *load phase* where
classes are defined, modules included, gems initialised, and DSLs evaluated;
and an *execute phase* where the actual work happens. The Frozone compiler
exploits this split: the **Frozone interpreter runs the load phase normally**,
handling all dynamic Ruby (metaprogramming, `define_method`, `has_many`,
everything). Once the load phase is complete and the object model is fully
settled, the compiler **snapshots that state as the closed world** and
translates it to Crystal. The execute phase then runs as a native binary with
no interpreter overhead. This means the closed-world constraint applies only
to the execute phase — which well-written programs, and Rails apps in
production mode, already satisfy.

---

### Closed-world AOT vs JIT

A **JIT compiler** (like YJIT in MRI, or TruffleRuby's Graal backend) compiles
Ruby at runtime, inside a running interpreter. It observes actual types at
runtime (type profiling), generates native code for hot paths, and falls back
to the interpreter for cold or polymorphic paths. The full Ruby object model
remains available at runtime — `eval`, `define_method`, `class_eval`, dynamic
`const_set` all work exactly as in the interpreter. JIT is maximally compatible
but requires a complete interpreter as a foundation, is complex to implement
correctly, and the generated code must handle deoptimisation (falling back to
the interpreter when type assumptions are violated).

A **closed-world AOT compiler** takes a fixed snapshot of the entire program
at compile time and compiles everything in one shot. There is no interpreter
fallback, no runtime deoptimisation, no type profiling. What you gain is:

- **Simpler implementation** — no runtime type profiling, no deoptimisation
  machinery, no interpreter to maintain in parallel
- **Better peak performance** — the compiler can make global optimisations
  that a JIT cannot (Crystal's own type inference does this for us for free)
- **Smaller runtime** — no interpreter overhead in the binary
- **Predictable performance** — no JIT warm-up, no GC pauses from code
  compilation, no tier transitions

What you give up:

- **Dynamic features** — `eval` with runtime strings, fully dynamic
  `define_method`, `class_eval` with strings, `method_missing` as a catch-all
  for truly unknown methods (see below for how each is handled)
- **Incremental loading** — you cannot `require` a file at runtime that wasn't
  part of the closed world at compile time
- **Compatibility** — some Ruby programs genuinely require dynamic features
  and simply cannot be compiled; others use dynamic features in ways that are
  statically analysable (the common case)

---

### The closed-world assumption

The **closed-world assumption** is the central constraint: at compile time, the
compiler sees the complete set of classes, modules, methods, and constants that
will ever exist. Nothing new is defined at runtime.

In practice this means:
- All `require` calls are resolved at compile time; every loaded file is part
  of the closed world
- Class/module definitions are final — `class Foo` opens Foo exactly the set
  of times visible in the source
- Method definitions are final — no `define_method` with a runtime-computed
  name, no `method_missing` as an open-ended proxy (it can appear in the
  source but must be handled specially)
- Constants are effectively immutable after the program starts

This rules out some Ruby idioms (metaprogramming-heavy DSLs, plugin systems
that load code at runtime) but covers the overwhelming majority of real Ruby
programs, including Frozone itself.

---

### Why Crystal as the intermediate language

Rather than generating bytecode or machine code directly, Frozone compiles
Ruby to Crystal source. Crystal then takes it from there. This is sometimes
called **transpilation** or using Crystal as a *pretty-printer backend*.

The key insight is that Crystal *is* Ruby with a static type system bolted on.
Its syntax is almost identical; its semantics (classes, modules, inheritance,
blocks, closures, exceptions) map directly to Ruby's. A Ruby `class Foo < Bar`
becomes a Crystal `class Foo < Bar`. A Ruby `def foo(x); x + 1; end` becomes
a Crystal `def foo(x); x + 1; end`. The structural transformation is trivial.

The **hard parts of compilation** — type inference, optimisation, register
allocation, native code generation, garbage collection — are all handled by
`crystal build`. We get a world-class optimising compiler for free.

The **new work** is the semantic layer: closed-world analysis, the proxy class
hierarchy (`RubyObject` and friends), ivar scanning, `respond_to?` bitsets,
constant resolution. This work is required regardless of backend and is not
wasted if a different backend (LLVM IR, bytecode VM) is added later.

---

### The split strategy: load → compile → execute

The closed-world requirement sounds strict, but most Ruby programs — including
Rails apps — already have a natural two-phase structure:

1. **Load phase:** `require` files, define classes and modules, include
   modules, run class-level code. DSLs fire, `attr_accessor` expands, gems
   register themselves, configuration is evaluated.
2. **Execute phase:** do the actual work — handle requests, process jobs,
   run the main loop.

The split strategy exploits this:

```
Ruby source
    ↓  (Frozone interpreter — load phase runs normally)
Stable object model  ← closed world snapshot point
    ↓  (CrystalCodegen — compile the snapshot)
Crystal source
    ↓  (crystal build)
Native binary  ← execute phase runs here at full speed
```

**The Frozone interpreter runs the load phase.** All the dynamic Ruby that
makes metaprogramming work — `define_method`, `class_eval` with blocks,
`include`, `extend`, `attr_accessor` expansion, DSL method definition — happens
exactly as it does today in the interpreter. The interpreter's job is to fully
evaluate the load phase and produce a stable, settled object model.

**The compiler snapshots the result.** At the snapshot point, all classes,
modules, methods, and constants are known. This settled state IS the closed
world. The compiler translates it to Crystal. Dynamic method definitions from
the load phase appear as ordinary `def` statements in the Crystal output —
the compiler never has to understand what `has_many` means; it just sees the
methods it produced.

**The execute phase runs natively.** No interpreter in the loop. The binary
links against the `crystal/` runtime library and runs at full Crystal speed.

**When is load "done"?** For a simple script it is obvious: the top-level
statements run sequentially and there is no distinction. For a server
application, the snapshot point is after all initialisation is complete and
before the main event loop starts. For Rails this is after
`Rails.application.initialize!` returns. Frozone would call a user-defined
hook (or detect the end of `require`-time execution) to trigger the compile.

This strategy makes the closed-world constraint much less restrictive in
practice. The constraint applies only to the *execute phase* — and well-written
applications are largely static by then.


### Rails — the raison d'être

Ruby's rise is inseparable from Rails. If the Frozone compiler cannot compile
Rails apps, or at least a large fraction of them, it is an interesting
research project rather than a practical tool. So it is worth understanding
Rails carefully.

**The good news: Rails production mode is already eager and static**

Rails has two loading modes:
- **Development mode:** files are loaded lazily via Zeitwerk as constants are
  first referenced. Classes can be reloaded between requests. Very dynamic.
- **Production mode** (`config.eager_load = true`): all files are loaded
  upfront before the first request via `Rails.application.eager_load!`. After
  `Rails.application.initialize!` returns, the object model is fully settled
  and does not change during request handling.

The Frozone compiler targets production mode. The split strategy's snapshot
point is after `initialize!`. In this mode, Rails already behaves like a
closed world for the execute phase.

**Metaprogramming at load time — handled by the interpreter**

Rails' DSL is metaprogramming-heavy but all of it fires at load time:

```ruby
class Post < ApplicationRecord
  has_many :comments           # → define_method :comments, :comments=, ...
  belongs_to :user             # → define_method :user, :user=, :user_id, ...
  scope :published, -> { where(published: true) }  # → defines .published
  validates :title, presence: true
  before_save :normalise_title
end
```

Under the split strategy, the Frozone interpreter evaluates all of this during
the load phase. `has_many :comments` fires, `define_method` runs, and the
resulting methods are added to the `Post` class object. By the snapshot point,
`Post` has concrete `#comments`, `#comments=`, `#user`, `#user=` etc. methods.
The compiler sees ordinary methods and translates them as such. It never needs
to understand what `has_many` means.

Concerns/validations/callbacks become arrays of proc objects stored in class
ivars, exactly as they are in MRI. The interpreter captures this state; the
compiler preserves it.

**Database schema discovery**

ActiveRecord discovers column types from the database at load time:
`Post.column_names` returns the actual columns of the `posts` table. This
means the closed world depends on the DB schema.

In practice this is already solved by Rails itself: `db/schema.rb` is the
authoritative schema definition, committed to the repository, updated after
every migration. The Frozone compiler reads `db/schema.rb` at compile time
to determine column types — no live database connection needed.

The recompilation trigger is: any time `db/schema.rb` changes (i.e., after a
migration), rebuild the compiled binary. This is the same trigger as
`bundle install` (Gemfile.lock changes → rebuild). CI/CD handles it naturally.

**Zeitwerk autoloading**

Modern Rails uses Zeitwerk for autoloading. In production mode,
`Rails.application.eager_load!` calls Zeitwerk's `eager_load` which walks
the autoload paths and `require`s every file. By the snapshot point, all
application classes are loaded. Zeitwerk's autoloading machinery is not needed
in the compiled binary — it is a load-phase tool.

**Request-time concerns**

After the snapshot point, a Rails app handling requests should be essentially
static. Some areas to audit:

| Pattern | Status | Mitigation |
|---------|--------|-----------|
| `has_many`/`belongs_to` | Load time only ✓ | Interpreter handles it |
| `scope` definitions | Load time only ✓ | Interpreter handles it |
| `validates`/`callbacks` | Load time only ✓ | Interpreter handles it |
| Zeitwerk autoloading | Production eager-loads ✓ | Full load before snapshot |
| DB schema discovery | `schema.rb` at compile time ✓ | No live DB needed |
| `method_missing` for `find_by_*` | Removed in Rails 6 ✓ | N/A |
| Some gems using `class_eval` per request | Rare ⚠ | Audit required |
| `Kernel#pp` / `ObjectSpace` in gems | Development only ⚠ | Strip from compiled binary |
| Hot reloading | Development only — not a target | Compiled = production |

Modern Rails (>= 6 with Zeitwerk) is cleaner than old Rails. The main risk is
third-party gems that do request-time class manipulation — these need to be
audited. Most popular gems (Devise, Pundit, Sidekiq, ActiveJob) are
load-time-only and will work correctly.

**Rails as the ultimate correctness test**

Just as Frozone's self-compilation (compiling the interpreter itself) is the
correctness test for the compiler infrastructure, compiling a real Rails app
is the correctness test for the split strategy and the full closed-world
approach. A "hello world" Rails API app with a single model and controller
is a realistic near-term target:

```
bundle exec frozone compile --mode=rails app/
    → snapshot after Rails.application.initialize!
    → Crystal codegen
    → crystal build
    → ./myapp  (handles requests, 0 interpreter overhead)
```

This would be a significant result.


### Limitations and non-goals

| Feature | Status |
|---------|--------|
| `eval(string)` | Prohibited or handled via static-interpolate analysis |
| `require` at runtime | Not supported; all files compiled together |
| `define_method` with runtime name | Not supported |
| `class_eval` / `module_eval` with string | Not supported |
| `method_missing` as open-ended proxy | Requires generated `case` dispatch |
| `send` with dynamic string | Requires generated `case` dispatch |
| `const_get` with dynamic string | Requires generated `case` dispatch |
| Threads | Crystal fibers; cooperative model preserved |
| Bignum arithmetic | `RubyInteger` wraps Crystal's `BigInt` |
| Encoding | Crystal's PCRE2 regex (vs Oniguruma); common subset identical |
| `ObjectSpace` | Not available (no interpreter object graph) |
| Continuations / `callcc` | Not supported |

The first compilation target is **Frozone itself** — if the Frozone interpreter
compiles cleanly under these constraints, we have high confidence the approach
is sound for real-world programs.

---

## Crystal as a backend — why it fits

Crystal started as a Ruby-like language specifically designed to be statically
compilable, so there is deep structural alignment between what Ruby means and
what Crystal can express.

**Advantages:**
- Crystal's type system can represent Ruby's object model well — classes,
  modules, inheritance, generic collections
- Crystal's GC handles memory; no manual memory management
- The Crystal compiler is fast and produces genuinely fast native code
- Crystal has FFI for anything that needs to stay in C (regex engine, encoding
  tables, etc.)
- Crystal has Fiber and Channel natively — Frozone's cooperative threading maps
  cleanly to Crystal fibers

**Hard parts:**
- Ruby's open classes / monkey-patching — Crystal doesn't have them at runtime
- `method_missing`, `send`, `define_method` — need codegen tricks or a fallback
  interpreter path
- Numeric tower (Integer → Bignum) needs explicit handling
- Exception handling is structurally similar but the details differ

**Parser note:** The WqParser path produces an AST designed with static
analysis in mind (it's what RuboCop, Sorbet, and RBS tooling use), which is a
better starting point for type inference than Prism's AST. But Prism works fine
given the AST is already normalised by Frozone's parser layer.


## The closed-world assumption

The closed-world constraint is the key that unlocks the whole thing. Without it
you need a full runtime object model (what Frozone currently is); with it,
Crystal's own compiler infrastructure does most of the heavy lifting.

Crystal IS Ruby with a type-inferring compiler already built in. If you emit
Crystal that mirrors the Ruby structure, Crystal's own type inference resolves
most types without you writing a type inferencer. You are effectively delegating
the hardest part of compilation to `crystal build`. The type errors Crystal
reports are legitimate type errors in the Ruby program — which in a
closed-world setting is arguably the right behaviour.

**Rule:** after compilation, no new method/class/module/constant definitions.
Dynamic `define_method`, `class_eval`, `instance_eval` with strings, etc. are
not permitted (or are routed through a fixed fallback).


## AST-to-Crystal mapping (almost 1:1)

| Frozone AST node        | Crystal output              |
|-------------------------|-----------------------------|
| ClassDef                | `class Foo < Bar`           |
| ModuleDef / include     | `module M` / `include M`    |
| MethodDef               | `def foo(*args)`            |
| InstanceVariable        | `@foo`                      |
| ClassVariable           | `@@foo`                     |
| LocalVariable           | same name                   |
| If/Unless/While/Until   | direct equivalents          |
| Rescue/Ensure/Raise     | direct equivalents          |
| Block/Yield             | Crystal blocks + `yield`    |
| Lambda/Proc             | `->(...) { }` / `Proc.new`  |
| Splat / **kwargs        | `*args` / `**kwargs`        |
| PatternMatch (case/in)  | Crystal has `case/in` too   |
| Super                   | `super`                     |

The codegen pass is closer to a pretty-printer than a traditional compiler.
The heavy lifting — type inference, optimisation, native codegen — is all
delegated to Crystal.


## Compilation pipeline

```
Ruby source
    ↓  (Prism / WqParser — already done)
Frozone AST
    ↓  (collect all class/module/method defs — closed world)
Resolved symbol table
    ↓  (Crystal codegen pass — new work)
.cr file(s)
    ↓  (crystal build — type inference + native codegen)
Native binary
```

One open question: generate a single-file Crystal program, or a Crystal library
that the runtime calls into? The library approach is more compositional (you
could call compiled Frozone code from Crystal code and vice versa), but the
single-file approach is simpler to start with.

**Crystal codegen before bytecode VM**

The natural instinct is to put a bytecode VM on the path to Crystal — it is a
traditional compiler pipeline step and forces you to think through
representation questions (how do you represent a block? a splat? a non-local
return?). But this instinct is wrong for this target, for a simple reason:
*bytecode compilation is a flattening transformation and Crystal codegen is
not*.

Targeting a CPU (or a bytecode VM) requires linearising a recursive tree into a
flat instruction stream. That means: generating jump/branch labels and patching
them, explicitly heap-allocating closure cells for captured variables, emitting
try/catch tables for exceptions, designing a stack or register frame layout.
These are genuinely hard problems — and solving them for bytecode does not
transfer to Crystal, because Crystal's compiler handles all of them internally.

Targeting Crystal is structurally different: `if` → `if`, `while` → `while`,
`def` → `def`, `class` → `class`. Closures, non-local returns, exception
handling, and method dispatch are all emitted in their natural Ruby-shaped form
and Crystal's own compiler takes it from there. The new work is the *semantic*
layer — closed-world analysis, singleton class hierarchy construction, ivar
scanning, primary/natural form generation — which is required for any backend
and is not wasted effort.

**Recommended order:** Crystal codegen first (real native binaries, relatively
lightweight implementation). A bytecode VM is a legitimate later branch if
portability or embedding matters — it is a different product, not a stepping
stone.


## Singleton types — nil, true, false

Ruby's singleton types (`nil`, `true`, `false`) sit naturally inside the
existing `BasicObject` hierarchy — no extra root layer is needed. The trick is
to banish Crystal's own `Nil` from the Frozone object model entirely and instead
model them as real singleton class instances:

```
FrozoneBasicObject        (abstract)
  └── FrozoneObject       (abstract)
        ├── FrozoneNilClass      (singleton: FROZONE_NIL)
        ├── FrozeneTrueClass     (singleton: FROZONE_TRUE)
        ├── FrozeneFalseClass    (singleton: FROZONE_FALSE)
        ├── FrozoneInteger
        ├── FrozoneString
        └── ... etc.
```

This is exactly Ruby's own hierarchy — no invention needed. The singletons are
just constants:

```crystal
FROZONE_NIL   = FrozoneNilClass.new
FROZONE_TRUE  = FrozeneTrueClass.new
FROZONE_FALSE = FrozeneFalseClass.new
```

Every Ruby value — including nil — is a valid `Frozone::BasicObject` reference.
Crystal's `Nil` never appears in the Frozone object model.

**Truthiness in conditions**

Every `if x` where Crystal doesn't statically know the type needs a helper:

```crystal
def frozone_truthy?(val : Frozone::BasicObject) : Bool
  !val.is_a?(FrozoneNilClass) && !val.is_a?(FrozeneFalseClass)
end
```

This is the fast unboxing path: when Crystal's inference has narrowed the type
to something that cannot be `NilClass` or `FalseClass` — e.g. `FrozoneInteger`
— the `frozone_truthy?` call is dead code and Crystal eliminates it. At
fully-inferred call sites, `if x > 0` where `x : FrozoneInteger` generates a
native comparison with no boxing at all.

**Natural forms for boolean-returning methods**

The natural form of comparison operators returns Crystal's `Bool`, not a
`Frozone::BasicObject`:

```crystal
class FrozoneInteger
  # Primary form — arg type unknown at compile time
  def >(other : Frozone::BasicObject) : Frozone::BasicObject
    case other
    when FrozoneInteger then @value > other.@value ? FROZONE_TRUE : FROZONE_FALSE
    else raise TypeError.new("...")
    end
  end

  # Natural form — Crystal knows both types; returns native Bool
  def >(other : FrozoneInteger) : Bool
    @value > other.@value
  end
end
```

When Crystal selects the natural form, `if x > y` just works — no
`frozone_truthy?` wrapper, no boxing, pure native comparison. The optimisation
is automatic and falls out of type inference.


## Dispatch architecture — `Frozone::BasicObject` as the base

**The proposal:** All type declarations bottom out at `Frozone::BasicObject`.
Every method name visible in the closed world gets a stub on
`Frozone::BasicObject` that raises `NoMethodError`. Concrete classes override
with two overload variants: a *primary form* (generic args) and a *natural form*
(precise types). Crystal's overload resolution picks the most specific matching
overload at each call site — no explicit shape check needed.

```crystal
abstract class Frozone::BasicObject
  def +(other : Frozone::BasicObject) : Frozone::BasicObject
    raise NoMethodError.new("undefined method '+' for #{self.class}")
  end
end

class FrozoneInteger < Frozone::Object
  # Primary form — receiver type known, arg type unknown
  def +(other : Frozone::BasicObject) : Frozone::BasicObject
    case other
    when FrozoneInteger then FrozoneInteger.new(@value + other.@value)
    when FrozoneFloat   then FrozoneFloat.new(@value.to_f + other.@value)
    else raise TypeError.new("...")
    end
  end

  # Natural form — Crystal knows both types statically; selected at compile time
  def +(other : FrozoneInteger) : FrozoneInteger
    FrozoneInteger.new(@value + other.@value)
  end
end
```

**Virtual dispatch vs overload resolution (important distinction):**
- For `a + b` where Crystal knows `a : Frozone::BasicObject`: virtual dispatch
  picks the right `+(Frozone::BasicObject)` override at runtime. ✓
- The fast path to the natural form requires Crystal to have narrowed the
  *argument* type statically, not just the receiver. This happens through
  Crystal's global type inference in a closed world — over time more call sites
  resolve to natural forms without explicit annotation.


## Block representation

Blocks are the hardest part. `&block : Frozone::BasicObject -> Frozone::BasicObject`
only handles unary blocks; Ruby blocks have variable arity. Three options:

1. **Fixed-arity overloads:** generate primary forms for arity 0, 1, 2, 3…
   Ugly but Crystal handles it.
2. **Array-args block:** `&block : Array(Frozone::BasicObject) -> Frozone::BasicObject`
   — always pack block args into an array; natural forms use native arity.
3. **`yield` instead of explicit `&block`:** For methods that always yield,
   Crystal's `yield` mechanism infers block type naturally. The explicit `&block`
   form is only needed when storing the proc (lambdas, `Proc.new`, etc.).

Option 3 is probably right for most cases.


## Integer boxing

Crystal's `Int64` is a value type (struct), not a reference type.
`FrozoneInteger` wrapping it would be a class (heap-allocated). This looks bad
for number-heavy code, but:
- In the natural form at concrete call sites, Crystal can inline and unbox — the
  wrapper disappears in emitted machine code for tight numeric loops
- Crystal's escape analysis handles this well
- Boxing truly occurs only in the primary-form (polymorphic dispatch) path —
  which is the already-slow path anyway


## Vtable size concern

Every method name in the closed world gets a stub on `Frozone::BasicObject`.
With all of Ruby's core methods plus application code, that could be 500+ virtual
method slots on every object. Crystal's vtables are per-class, so total size is
`num_classes × num_methods`. This could hurt compile time and instruction-cache
behaviour for the primary dispatch path.

**Mitigation:** Only add stubs for methods actually called on
`Frozone::BasicObject`-typed receivers (i.e., truly polymorphic call sites).
Methods only ever called on known concrete types don't need a stub on the base
class. This is discoverable from the closed-world call graph.


## Instance variables

**The problem:** Ruby discovers instance variables on first use; Crystal requires
them to be declared upfront (or at least all uses must be visible to the
compiler for type inference).

**Solution — static scan:** In a closed world, scan the entire AST to collect
all `@foo` accesses per class. The scan must include:
- The class's own method bodies
- Every module `M` that the class (or any ancestor) includes, transitively
  (modules routinely set ivars on their including classes)
- Superclass ivars are inherited naturally in Crystal — no special handling

Watch out for `attr_accessor`/`attr_reader`/`attr_writer` — in Frozone these
are already evaluated into method defs at parse time, so the `@foo` accesses
should be visible to the scan.

**Ivar types:** All ivars are typed `Frozone::BasicObject` and initialised to
`FROZONE_NIL`. Crystal's `Nil` never appears — Ruby's nil is just `FROZONE_NIL`,
an ordinary `FrozoneNilClass` instance. This maps perfectly to Ruby semantics:
an uninitialized ivar returns nil, which here means a proper callable object
that responds to `nil?`, `to_s`, etc.

```crystal
@name  : Frozone::BasicObject = FROZONE_NIL
@count : Frozone::BasicObject = FROZONE_NIL
```

A simple pre-pass can narrow types conservatively: if every assignment to `@foo`
in the closed world assigns a `FrozoneString`, declare
`@foo : FrozoneString = FROZONE_NIL` (since `FrozoneNilClass < FrozoneObject`,
this is type-safe). No full type inferencer needed — just a conservative
over-approximation of the write set.

**Dynamic ivar access — case dispatch over the known set:**

```crystal
def instance_variable_get(name : Symbol) : Frozone::BasicObject
  case name
  when :@foo then @foo
  when :@bar then @bar
  else raise NameError.new("undefined instance variable #{name} for #{self.class}")
  end
end

def instance_variable_set(name : Symbol, val : Frozone::BasicObject) : Frozone::BasicObject
  case name
  when :@foo then @foo = val
  when :@bar then @bar = val
  else raise NameError.new("undefined instance variable #{name} for #{self.class}")
  end
  val
end
```

The `else` branch is stricter than MRI (which silently creates a new ivar) but
in a closed world nothing should hit it — catching it as an error is useful.

`instance_variables` can be a generated literal array per class — no runtime
introspection needed.

**Conditional initialisation:** If `@b` is only set in some branches, the type
annotation `Frozone::BasicObject = FROZONE_NIL` still holds — `@b` is always
initialised (to nil), and any assignment just changes which `FrozoneBasicObject`
it points to. No special-casing required.

**Overall:** Ivar handling is one of the *smoother* parts of the compilation
problem. Much harder will be `method_missing`, `respond_to?`, and `send` with
dynamic method names.


## Singleton classes and methods

**The key insight:** Ruby's singleton class hierarchy *is itself* a class
hierarchy, and Crystal's class hierarchy is exactly the right representation
for it. The closed-world constraint that feels like a restriction is what makes
the clean representation possible — we know the complete singleton class
structure at compile time.

**Class methods — the common case**

`def self.foo` in class `Foo` puts `foo` on `#<Class:Foo>`, Foo's singleton
class. Crucially `#<Class:Foo>` inherits from `#<Class:Bar>` when `Foo < Bar`
— that is how class methods are inherited. In Crystal this maps directly to a
parallel hierarchy:

```crystal
# Instance side — the familiar part
class FrozeneFoo < FrozoneBar
  def instance_method : Frozone::BasicObject ...
end

# Singleton/class side — mirrors the instance hierarchy
class FrozoneClass_Foo < FrozoneClass_Bar
  def create : Frozone::BasicObject   # Ruby: def self.create
    self.new
  end
  def new : FrozeneFoo
    FrozeneFoo.new
  end
end

FOO_CLASS = FrozoneClass_Foo.new   # the class object itself
```

The two hierarchies run in parallel, and Crystal's own inheritance handles
Ruby's inherited class methods automatically — no extra machinery needed.

**`self.new` inheritance works correctly**

If `Bar < Foo` and `Bar` inherits `Foo.create`, then `Bar.create` should
return a `Bar` instance, not a `Foo`. Crystal's virtual dispatch on `self.new`
handles this exactly as Ruby does:

```crystal
class FrozoneClass_Foo < FrozoneMetaclass
  def create : Frozone::BasicObject
    self.new   # virtual dispatch — calls new on the actual class object
  end
  def new : FrozeneFoo = FrozeneFoo.new
end

class FrozoneClass_Bar < FrozoneClass_Foo
  def new : FrozoneBar = FrozoneBar.new  # overrides new
  # create inherited; self.new → FrozoneClass_Bar#new → FrozoneBar ✓
end
```

No special handling required.

**The metaclass root**

Ruby's full chain for a class object is:
`#<Class:Foo> → #<Class:BasicObject> → Class → Module → Object → BasicObject`

In Crystal we need a root for the class-object side that carries everything
every Ruby class responds to (`name`, `superclass`, `ancestors`,
`instance_methods`, default `new`, etc.):

```
FrozoneMetaclass                    (abstract)
  └── FrozoneClass_BasicObject
        └── FrozoneClass_Object
              └── FrozoneClass_Foo
                    └── FrozoneClass_Bar
```

`FrozoneMetaclass` is also where class-object method lookup bottoms out for
the polymorphic case when Crystal only knows a receiver is *some* class object.

**Method lookup compatibility**

Ruby's lookup order: singleton class → singleton class modules → superclass's
singleton class → regular chain. The Crystal representation preserves this
exactly:

- Singleton class methods → methods directly on `FrozoneClass_Foo`
- Singleton class modules (from `extend` on the class) → Crystal `include`
  in `FrozoneClass_Foo`
- Inherited class methods → `FrozoneClass_Foo < FrozoneClass_Bar` Crystal
  inheritance

Crystal's virtual dispatch *is* Ruby's method lookup for all these cases.
The structure is isomorphic.

**Singleton methods on arbitrary objects**

Much rarer in practice. In a closed world all such definitions are statically
visible:

```ruby
obj = Object.new
def obj.special; "hello"; end
```

A static scan finds every `def expr.method` where `expr` is not `self`. For
each such object, generate a Crystal subclass:

```crystal
class FrozoneObject_with_special < FrozoneObject
  def special : Frozone::BasicObject
    FrozoneString.new("hello")
  end
end
```

The inter-procedural analysis needed to identify which specific object gets
this class is non-trivial, but these cases are rare and usually obvious
(top-level scripts, configuration objects). A reasonable initial rule: if the
receiver is a local variable that never escapes, it is tractable. If it is
truly dynamic (passed around, stored in a collection), fall back to a
per-object method table checked before vtable dispatch — the slow path.

**`extend` follows the same pattern**

```ruby
obj.extend(Greetable)
```

All `extend` calls are statically visible in the closed world. Generate a
subclass that includes the module's methods as instance methods:

```crystal
class FrozoneObject_extended_Greetable < FrozoneObject
  include FrozoneGreetable_instance_methods
end
```


## VM infrastructure intrinsics — what disappears in a closed world

In the Frozone interpreter, a large category of intrinsics exists purely to
*build and query the class hierarchy at runtime*:

```ruby
Intrinsics.class_new(superclass, name)
Intrinsics.module_new(name)
Intrinsics.define_method(class_obj, name, body)
Intrinsics.module_include(class_obj, mod)
Intrinsics.class_ancestors(class_obj)
Intrinsics.method_defined?(class_obj, name)
# ... ~30 more
```

In a closed world these **all disappear**. They are used to construct the object
model at interpreter start-up, but in the Crystal target, that work is done
*statically* by the Crystal type system:

- `class_new(superclass, name)` → `class FrozeneFoo < FrozoneBar` — declared once
- `module_new(name)` → `module FrozoneM` — declared once
- `define_method(klass, name, body)` → `def name(...) ... end` inside the class body
- `module_include(klass, mod)` → `include FrozoneM` inside the class body
- `class_ancestors(klass)` → Crystal's `ancestors` macro (or a generated literal array)
- `method_defined?(klass, name)` → static lookup at compile time

None of these need to exist at runtime in the Crystal binary. The hierarchy is
fully resolved by `crystal build`; querying it is a matter of generating the
right Crystal reflection calls or literal arrays.

The only sub-category that *is* still needed is reflection that the *Ruby
program itself* calls at runtime:
- `Module#ancestors` — generate a literal array per class
- `Module#instance_methods` — generate a literal array per class
- `respond_to?` — generate a `case` dispatch over the known method set
- `send` with a string/symbol — generate a `case` dispatch over the known method set
- `is_a?` / `kind_of?` / `instance_of?` — Crystal's `is_a?` maps directly

These are all mechanical code-gen from the closed-world method/ancestor tables.
The interpreter's dynamic intrinsic machinery reduces to a few generated `case`
statements and literal arrays per class.

**Summary:** VM infrastructure intrinsics are an interpreter bootstrap
artefact. In a Crystal compilation they dissolve into the Crystal class
definitions themselves, leaving zero runtime overhead.


## Regex engine — Oniguruma vs PCRE2

MRI Ruby uses Oniguruma/Onigmo; Crystal uses PCRE2. The two engines handle
common patterns identically — basic character classes, anchors, quantifiers,
capture groups, named captures, lookahead/lookbehind, non-greedy matching all
work the same way.

**Practical approach:** ignore the difference initially. The vast majority of
Ruby regex usage in real applications uses the common subset, and PCRE2 is
arguably *more* capable than Onigmo in some areas (possessive quantifiers,
atomic groups). Edge cases to be aware of:

- Oniguruma's `\h`/`\H` (hex digit) are not in PCRE2 (use `[0-9a-fA-F]`)
- Some Unicode property names differ slightly
- `\K` (reset match start) — supported in PCRE2, not in Oniguruma
- Oniguruma `(?~...)` (absent operator) — PCRE2 has no equivalent

For a Frozone Crystal target, Crystal's `Regex` (PCRE2-backed) is the natural
choice. The handful of Oniguruma-specific features can be handled by a
compatibility shim if they appear, or flagged as unsupported. In practice they
are rarely used outside of Unicode-heavy processing code.


## `respond_to?` — bitset approach

`respond_to?` is ubiquitous in Ruby and must be both correct and fast. The
closed-world assumption gives us the full set of method names at compile time,
which enables an exact O(1) implementation.

**Global method index table**

Assign every method name that appears anywhere in the closed world a unique
integer index at compile time:

```
to_s → 0,  inspect → 1,  == → 2,  respond_to? → 3,  nil? → 4,  ...
```

This table is a compile-time constant — a Crystal `Enum` or a generated hash
literal. Total size: roughly the number of unique method names in the program
(typically 300–600 for a substantial codebase).

**Per-class presence bitset**

Each proxy class gets a generated `StaticArray(Bool, METHOD_COUNT)` class-level
constant — a compile-time boolean array indexed by the global method index:

```crystal
class FrozoneInteger < FrozoneObject
  METHOD_PRESENCE = StaticArray[
    true,   # 0: to_s
    true,   # 1: inspect
    true,   # 2: ==
    true,   # 3: respond_to?
    false,  # 4: nil?   (Integer does not respond to nil?)
    # ...
  ]
end
```

`StaticArray` is a Crystal value type; this is zero heap allocation.

**`respond_to?` implementation**

```crystal
def respond_to?(name : FrozoneSymbol, include_private : Bool = false) : Bool
  idx = name.method_index     # -1 if not a method name at all
  return false if idx < 0
  METHOD_PRESENCE[idx]
end
```

This is a single array bounds check plus an array load — about two instructions
on hardware. No method table traversal, no string hashing, no inheritance walk.

**Inheriting the bitset correctly**

A subclass overrides the parent's bitset with a new `StaticArray` that is a
superset of the parent's. The codegen pass computes the presence set as:
*all methods defined on this class or any ancestor or included module*. Crystal
does not inherit class-level constants, so the subclass always declares its own.
This is correct by construction.

**`respond_to_missing?` support**

If a class defines `respond_to_missing?`, the bitset cannot be fully correct
(the method advertises dynamically-added methods). In a closed world this is
rare and can be handled by generating a fallback:

```crystal
def respond_to?(name : FrozoneSymbol, include_private : Bool = false) : Bool
  idx = name.method_index
  return false if idx < 0
  METHOD_PRESENCE[idx] || respond_to_missing?(name, include_private)
end
```

In practice most classes don't override `respond_to_missing?`, so the fast path
dominates.


## Method-name symbols — a Crystal subclass of `FrozoneSymbol`

The global method index table enables an important Crystal-level optimization:
distinguish at compile time between symbols that are known method names and
those that are not.

```crystal
abstract class FrozoneSymbol < FrozoneObject
  # ...
end

class FrozoneMethodSymbol < FrozoneSymbol
  getter method_index : Int32
end
```

Every `:foo` literal in the source where `:foo` is a known method name is
emitted as a `FrozoneMethodSymbol` constant:

```crystal
SYM_TO_S    = FrozoneMethodSymbol.new(:to_s, 0)
SYM_INSPECT = FrozoneMethodSymbol.new(:inspect, 1)
# ...
SYM_WIBBLE  = FrozoneSymbol.new(:wibble)  # not a method name → plain FrozoneSymbol
```

**The payoff**

Crystal's overload resolution selects the more specific overload at call sites
where the type is known:

```crystal
# General case — sym could be any symbol
def respond_to?(sym : FrozoneSymbol) : Bool
  false   # not a method name; nothing in the closed world responds to it
end

# Fast path — sym is a known method name
def respond_to?(sym : FrozoneMethodSymbol) : Bool
  METHOD_PRESENCE[sym.method_index]
end
```

At a call site `obj.respond_to?(:to_s)` where Crystal sees a
`FrozoneMethodSymbol` literal, it selects the second overload at compile time.
Combined with the fact that `METHOD_PRESENCE` is a `StaticArray`, Crystal can
further constant-fold `METHOD_PRESENCE[0]` to `true` or `false` for each
concrete class — making `respond_to?(:to_s)` on a `FrozoneInteger` receiver
literally a compile-time constant `true` with no runtime work.

**Symbol identity and interning**

In Ruby, `:foo == :foo` is always true (symbols are interned). In Crystal,
`FrozoneMethodSymbol` instances can be interned at the global-index level:
two `FrozoneMethodSymbol`s with the same `method_index` are the same symbol.
A simple `==` override suffices:

```crystal
def ==(other : FrozoneMethodSymbol) : Bool
  @method_index == other.method_index
end
def ==(other : FrozoneSymbol) : Bool
  false   # different types → different symbols
end
```


## Vtable explosion — deeper analysis

The vtable concern: every method name in the closed world requires a virtual
dispatch slot on `Frozone::BasicObject`. With 400+ unique method names, every
class (even small domain classes with 5 methods) carries 400+ vtable entries.
This affects:

- **Binary size**: vtables live in `.rodata`; many classes × many entries
- **Compile time**: Crystal's type inference visits every override for every
  class
- **I-cache**: a vtable dispatch loads from an offset in a large table; cache
  lines covering the actual entry may not be warm

**Why it is less bad than it sounds**

Crystal generates *per-concrete-class* method bodies, not shared thunks. The
vtable has one function-pointer slot per method per class; the pointer is set at
startup (or compiled in as a static initializer). In a typical closed world of
100 classes × 500 methods = 50,000 vtable slots × 8 bytes = 400 KB. Not
ideal but not catastrophic either; a similar-sized Java or C++ application has
comparable numbers.

**Mitigation 1 — only stub methods called polymorphically**

As noted earlier: only add a stub on `Frozone::BasicObject` for methods that
appear at a call site where Crystal's type inference cannot narrow the receiver
to a concrete class. Methods only ever called on known concrete types don't need
a base-class stub.

A first approximation: all `to_s`, `inspect`, `==`, `respond_to?`, `nil?`,
`is_a?`, `send` always need stubs (they're called everywhere on unknown
receivers). Method `frob` that only ever appears on `FrozoneWidget` receivers
does not.

**Mitigation 2 — module-based vtable splitting (interface traits)**

Instead of one monolithic `BasicObject` vtable, group methods by protocol
(module) and only extend classes that include that module:

```crystal
module FrozoneComparable
  abstract def <=>(other : Frozone::BasicObject) : Frozone::BasicObject
  # ... <, >, <=, >= all delegate to <=> by default
end

class FrozoneInteger < FrozeneObject
  include FrozoneComparable
  # ...
end
```

At polymorphic call sites for `<=>`, the receiver type can often be narrowed to
`FrozoneComparable` rather than `BasicObject`. Vtable entry count on
`BasicObject` drops to just the truly universal methods (~20–30).

This is a meaningful win for the I-cache: the hot dispatch path only needs to
find the right entry within the concrete class's vtable, which is now much
smaller for the common `x.to_s` / `x.==` / `x.respond_to?` universal methods.

**The respond_to? bitset is a *separate* table**

The vtable and the presence bitset are parallel data structures serving
different purposes:
- **Vtable**: physical dispatch — which Crystal method body gets called?
- **Presence bitset**: query — does this class support this method name?

They are both indexed by the same global method index, but the vtable entry for
`:wibble` on `FrozoneInteger` is a pointer to `raise NoMethodError` (the
base-class stub), while the presence-bitset entry for `:wibble` is `false`.
The bitset is exact; the vtable contains stubs for non-responding classes to
give correct `NoMethodError` behaviour.

The combined picture: global method index → vtable entry (function pointer or
stub) + presence bit (Bool). Two compact lookups, no hash tables, no string
searching.


## `eval` — compile-time boundary

`eval(string)` is fundamentally incompatible with closed-world compilation:
it takes source code as a *runtime string* and executes it, potentially defining
new classes, methods, or constants that the compiler cannot see.

**Options:**

1. **Prohibit** — emit a compile-time error if `eval` is reachable from any
   compiled method. This is correct for well-behaved programs (most Ruby code
   that is worth compiling does not use `eval`).

2. **Runtime fallback** — bundle the Frozone interpreter as a library; any
   `eval` call at runtime calls back into the interpreter. The compiled program
   is a hybrid: fast Crystal code for the closed-world parts, interpreted Frozone
   for `eval` sites. The interpreter instance shares the compiled object model
   via an FFI bridge. Elegant but complex.

3. **Dead-code elimination** — many `eval` uses are in standard-library code
   that is never reachable from the entry point. If the closed-world call-graph
   analysis shows `eval` is unreachable, it can be silently dropped. Only flag
   it if it is live.

Option 3 is the right starting point. Option 1 is the fallback when it is live.
Option 2 is a future engineering project.

**`instance_eval` / `class_eval` / `module_eval` with blocks**

These are different from string `eval` — they take blocks, which are statically
visible in the closed world. `obj.instance_eval { @foo }` is just a method call
with a block; the block's body is compiled normally. No dynamic code generation
required. These are fine.

**`binding.eval`** — same concern as string `eval`; same treatment.


## Frozone self-compilation — two targets and an audit

Compiling Frozone itself is the ultimate correctness test. There are two distinct
targets:

**Target A — Frozone-as-interpreter compiled to Crystal**
The Frozone Ruby source (`lib/frozone/**`, `lib/core/**`) is compiled by the
Frozone→Crystal compiler. The result is a native `frozone` binary that still
*interprets* Ruby programs at runtime. `ClassObject`, `Frame`, `Context`, etc.
remain as runtime data structures — they are just implemented in Crystal instead
of Ruby. This is analogous to how MRI is C but still interprets Ruby.

**Target B — closed-world program compilation**
A specific Ruby program is compiled. `ClassObject`/`Method`/`Frame` disappear;
replaced by Crystal's own class system. The compiled binary is self-contained
with no interpreter infrastructure. This requires the input program to be within
the compilable subset.

Target A is the practical near-term goal. It exercises the compiler on a large,
real codebase and produces a useful artifact (a faster Frozone). Target B is the
longer-term goal for arbitrary programs.

**Frozone source audit — patterns that need support in Target A**

| Pattern | Location in Frozone | Compilability |
|---------|---------------------|---------------|
| `attr_reader/writer/accessor` | throughout | fine — desugars to `def` at parse time |
| `include M` / `extend M` | throughout | fine — static in closed world |
| `send(:method, args)` with Symbol literal | `vm.rb`, `ast/*.rb` | fine — `case` dispatch |
| `send(dynamic_string, args)` | error handling paths | needs `case` or prohibition |
| `respond_to?(:foo)` | `vm.rb`, intrinsics | fine — bitset |
| `define_method` | `hierarchy.rb` bootstrap | fine — becomes `def` in closed world |
| `class_eval { }` with block | some meta | fine — block is static |
| `method_missing` | `object_object.rb`? | needs generated `case` dispatch |
| `instance_variable_get("@foo")` | reflection intrinsics | needs `case` dispatch |
| `Intrinsics.foo(...)` | `lib/core/4.0/**` | becomes direct Crystal calls |
| String `eval` | not used in core paths | likely dead code; drop |
| `Fiber[:key]` | vm.rb, hash_object.rb | Crystal has Fiber storage natively |
| `Thread.current`, `Mutex` | threading support | Crystal native |
| Prism gem calls | parser.rb | Crystal has Prism bindings (it's a C lib) |

**Key risk: `send` with dynamic method names**

Frozone's `vm.rb` does call-dispatch where the method name comes from parsing
the AST (a Ruby `Symbol` derived from source). At runtime the set of method
names dispatched to is bounded by the closed world — a `case` dispatch over all
known method names is sufficient. This is the same code-gen as `respond_to?`
(the case over method names) and `instance_variable_get` (the case over ivar
names), just on a larger set.

**`Intrinsics.*` calls in `lib/core/4.0/`**

In the current interpreter, `Intrinsics.foo(...)` calls are detected at parse
time and emitted as `Ast::IntrinsicCall` nodes that bypass VM dispatch entirely.
In a compiled Frozone, `Intrinsics` is just a module whose methods are direct
Crystal builtins:

```crystal
module Intrinsics
  def self.string_bytesize(str : FrozoneString) : FrozoneInteger
    FrozoneInteger.new(str.@bytes.size)
  end
  # ...
end
```

The three-layer collapse (XxxObject + Intrinsics + core/4.0) described earlier
applies fully: the compiled `FrozoneString` class just has `bytesize` as a
regular method calling `@bytes.size`. The `Intrinsics` module as a
*dispatch mechanism* disappears; its implementations become direct Crystal.



## `eval` with statically-known interpolates

Most string `eval` in real Ruby programs — and in ruby/spec specifically — is
not truly dynamic. The string is constructed from a small, statically-enumerable
set of values. A constant-propagation pass on the eval argument gives us several
tractable cases:

**Case 1 — literal string**
```ruby
eval("String.new.upcase")
```
The argument is a compile-time constant. Compile it as if it were inline source
code at that point. Trivial.

**Case 2 — string interpolation with compile-time-constant parts**
```ruby
eval("#{klass}.new")   # klass = String (assigned above, never reassigned)
```
SSA / def-use analysis shows `klass` has a single reaching definition that is
a compile-time constant. Fold the interpolation: `eval("String.new")`. Trivial.

**Case 3 — interpolation with a small enumerable value set**
```ruby
# before block: @klass = [String, Array, Hash].sample (or iterated)
eval("#{@klass}.new.foo")
```
Analysis shows `@klass` ranges over a known finite set. Generate one compiled
branch per value, selected at runtime:

```crystal
case _klass_val
when SYM_String then FrozoneString.new.foo
when SYM_Array  then FrozoneArray.new.foo
when SYM_Hash   then FrozoneHash.new.foo
end
```

This is partial evaluation of string interpolation — a phase that runs *before*
the Crystal codegen pass and rewrites `eval(interpolated)` nodes into `case`
dispatch trees. The analysis is the same def-use / value-set propagation used
for `send` with dynamic method names.

**Case 4 — structural eval patterns in ruby/spec**

ruby/spec uses eval for a handful of idioms:
- Testing that a construct raises a SyntaxError: `eval("class foo; end")` —
  here the *eval raises*, not the result; the compiled form can just
  `raise SyntaxError.new(...)` unconditionally (it is always a syntax error)
- Privacy checks: `eval("obj.private_method")` — in a closed world the private
  method is known; emit a `NoMethodError` at the call site
- Dynamic class construction: `eval("class #{name} < #{parent}; end")` — rare,
  usually only in a handful of specs; skip or handle with an enumerated case

**Case 5 — truly dynamic eval**
Prohibit (compile-time error) or route through the interpreter fallback. In
practice these are rare after cases 1–4 are handled.

**Implementation order:** handle case 1 first (trivial), then 2 (trivial after
constprop), then 3 (needs value-set analysis). Cases 4 and 5 can wait.


## Testing with mspec / ruby-spec — the compilation challenge

mspec is itself a dynamic Ruby program: it scans directories, `require`s spec
files at runtime, and uses `eval` and `define_method` extensively. It cannot
be the compiled binary. But it can drive a compiled binary externally.

**The key insight:** each `*_spec.rb` file is small and mostly self-contained
(100–500 lines). If we compile each spec file individually as its own closed
world — together with the relevant subset of `lib/core/4.0/` and a minimal
spec runner — we get a standalone binary for that spec.

**Architecture: compile-and-run harness**

```
MRI mspec  (outer driver — enumerates specs, collects results)
    │
    │  for each spec file:
    │    frozone compile spec_file.rb → spec_file.cr → crystal build → spec_binary
    │    ./spec_binary 2>&1 | parse TAP/custom output
    ↓
results aggregated as usual
```

The outer mspec or a small Rakefile drives the loop. The inner binary is a
fully native Crystal program.

**Minimal compilable spec runner**

Instead of linking full mspec into each compiled binary (complex, dynamic),
provide a ~200-line pure-Ruby spec runner that:
- Implements `describe`, `it`, `before`, `after`, `let`, `subject`
- Implements the matchers (`should`, `should_not`, `eq`, `raise_error`, etc.)
  that ruby/spec actually uses (roughly 30 matchers)
- Prints TAP or a simple pass/fail log to stdout
- Has no `eval`, no dynamic loading, no metaprogramming

This runner is part of the closed world for every compiled spec. It is compiled
once (or included as a Crystal `require`) and shared.

**Handling eval in spec files**

Before compiling a spec file, run the eval-analysis pass (see above):
1. Fully static or constprop-foldable evals → rewrite to inline code
2. Small-value-set interpolations → rewrite to `case` dispatch
3. Structural ruby/spec idioms (SyntaxError tests, privacy tests) → emit canned
   responses
4. Anything left → mark the enclosing `it` block as "skipped (eval)" and emit
   a pending result; do not block the rest of the spec

This gives a graceful degradation: specs that use simple eval compile and run
correctly; specs with truly dynamic eval show as pending rather than failing.

**Bootstrapping order**

1. Build the minimal spec runner library in compilable Ruby
2. Add eval-analysis pre-pass to the Frozone compiler
3. Pick one small ruby/spec module (e.g., `string/upcase_spec.rb`) and get it
   to compile and pass
4. Expand to the full module, then to all core modules
5. Hook into the existing `bundle exec rake core` infrastructure: add a
   `rake core:compiled` task that runs compiled specs alongside interpreted ones

**Comparison with Natalie**

Natalie (natalie-lang.org) took this approach and has a working `mspec`-driven
compiled spec suite. Key lessons from their work:
- The minimal spec runner is ~300 lines and covers 95% of ruby/spec patterns
- The remaining 5% (complex shared_examples, recursive describe nesting, some
  `eval` patterns) can be skipped initially and addressed incrementally
- Compile times per spec file are the bottleneck for the suite; `crystal build`
  in release mode takes 5–10s per file; parallelize the compilation step
- The compile-and-run architecture means you get a clean separation between
  "interpreter correctness" (existing rake core) and "compiler correctness"
  (rake core:compiled); bugs in one don't mask bugs in the other

**Spec files as closed worlds — what is included**

Each spec binary's closed world includes:
- The spec file itself
- The minimal spec runner
- `lib/core/4.0/` for the module being tested (e.g., `string.rb` for string specs)
- Any `require`d shared behaviour files (mspec's `spec_helper.rb` equivalent)
- Nothing else — no Frozone VM, no parser, no intrinsics layer

This is a much smaller closed world than compiling Frozone itself, and is
therefore a realistic early target. If string specs compile and pass, the
compiler is validating real behaviour against a real test suite.



## `eval` fallback — what "call the interpreter" actually requires

"Fall back to the interpreter for truly dynamic eval" is not a free operation.
The interpreter needs to run in the context of the *calling compiled code*, which
means it needs access to:

1. **`self`** — a compiled Crystal object (`FrozeneFoo`). The interpreter must
   be able to call methods on it (compiled Crystal methods) and get/set its
   ivars. This requires the `instance_variable_get/set` case-dispatch scaffolding
   (described in the ivar section) to be present and wired up at runtime, not
   just generated as a closed-world convenience.

2. **Method dispatch on `self` from inside the interpreter** — the interpreter
   calls a method, the receiver is a compiled object, the method body is
   compiled Crystal code. This is an FFI bridge in both directions: Crystal →
   interpreter (for the eval call) and interpreter → Crystal (for method calls
   on compiled objects). Non-trivial.

3. **Local variable frame** — local variables in the enclosing method are
   Crystal stack slots (possibly in registers). To expose them to the
   interpreter they must be boxed into a `Hash(Symbol, FrozoneBasicObject)`
   before the eval call and any mutations written back after it returns.

4. **Constants** — accessible globally; simpler than locals (constants are
   already in a table accessible to both compiled code and the interpreter).

The local variable situation has a saving grace:

```ruby
def foo
  x = 1
  eval("x = 42")   # can mutate existing local x
  p x              # => 42  (must box/unbox x around the eval call)

  eval("y = 2")    # creates y inside the eval's binding
  p y              # NameError — y is NOT visible in foo after eval returns
end
```

**New locals do not escape eval** ✓ — only the set of locals already in scope
at the eval call site can be mutated. This bounds the frame-exposure cost: box
only the live local variables at that point, not an unbounded set. And for the
common ruby/spec eval pattern — `eval("SomeClass.new.method")` with no local
variable interaction at all — only `self` and constants are needed, which is
much simpler.

This is v2+ work. For now: prohibit truly dynamic eval with a clear compile-time
error, and rely on the static-interpolate analysis (cases 1–3 above) to handle
the overwhelming majority of eval uses in real programs and in ruby/spec.


## `eval` fallback — the parser dependency problem

The interpreter fallback for dynamic `eval` requires a full Ruby parser embedded
in the compiled binary. The string arrives at runtime; it must be parsed,
converted to a Frozone AST, and evaluated. That means:

- **Prism** (or WqParser) — Prism is a C library; it can be bundled as a
  Crystal FFI dependency. That part is tractable.
- **Frozone's parser layer** (`parser.rb`, `wq_parser.rb`, `ast/**.rb`) —
  these are substantial Ruby programs. They must either be compiled to Crystal
  (requiring the compiler to handle them) or run on an embedded MRI/YARV
  instance (a very large runtime dependency).
- **The Frozone VM itself** (`vm.rb`, `context.rb`, `frame.rb`, …) — needed
  to evaluate the parsed AST. Same problem: compile it or embed MRI.

This creates a near-circular dependency: to support `eval` in compiled programs,
you need the compiler to compile the VM and parser, but the VM and parser use
dynamic patterns (heavy `send`, `define_method`, `class_eval`, intrinsics) that
are among the hardest things to compile.

**The only clean resolution** is Target A (compile Frozone-as-interpreter to
Crystal): once the Frozone interpreter itself is compiled to a Crystal library,
it can be linked into any compiled program as the `eval` fallback. The runtime
cost is reasonable (the compiled interpreter is still fast relative to an
embedded MRI), and the dependency circle is broken — the interpreter binary
exists before the `eval` fallback is needed.

Until Target A is complete, truly dynamic `eval` simply has no fallback.
Prohibit it; rely on static-interpolate analysis for the common cases; accept
that some ruby/spec tests will be pending.


## Constant lookup — static resolution in a closed world

Ruby's constant lookup algorithm is famously complex: lexical scope first, then
inheritance, then top-level. MRI optimises it with a generation counter (epoch):
each constant assignment increments a global counter; cached lookups store the
epoch and re-resolve on mismatch, giving fast direct access between mutations.

In a closed world the compiler can do better than epoch-check: it can resolve
every constant reference *at compile time*, before any Crystal code is emitted.

**Why static resolution is possible**

At every constant-reference site `X` in the AST, the compiler knows:
- The lexical nesting (which modules/classes enclose the reference) — this is a
  structural property of the AST, not a runtime value
- The full set of constant assignments across the entire closed world
- The full inheritance/include chain of the enclosing class

The standard lookup algorithm (lexical → inheritance → top-level) is run once,
at compile time, for each reference site. The result is a specific qualified
constant `A::B::X`. The Crystal codegen emits a direct reference to that
qualified name. No epoch check, no hash lookup, no runtime overhead at all.

```ruby
# Ruby source
module A
  X = 42
  module B
    p X    # compiler resolves: A::X (lexical scope wins)
  end
end
```

```crystal
# Emitted Crystal
module FrozoneA
  X = FrozoneInteger.new(42)
  module FrozoneB
    p FrozoneA::X    # resolved at compile time, direct reference
  end
end
```

The epoch-check optimization in Frozone and MRI is rendered unnecessary by the
closed-world assumption. Static resolution is strictly better.

**Crystal representation of constants**

| Ruby pattern | Crystal form |
|---|---|
| `X = 42` (assigned once) | `X = FrozoneInteger.new(42)` — true Crystal constant |
| `X = []` then `X = {}` (reassigned, rare, MRI warns) | Crystal class variable `@@x` — mutable |
| Class/module name constants (`String`, `Array`) | `FROZONE_STRING_CLASS = FrozoneClass_String.new` etc. |
| Nested `A::B::X` | `FrozoneA::FrozoneB::X` — namespaced in Crystal module hierarchy |
| `const_get("X")` with literal | resolved at compile time to direct ref |
| `const_get(dynamic_string)` | `case` dispatch over all known constants, or prohibited |

**What looks like constant mutation but is not**

Several Ruby patterns appear to mutate constants but are actually compile-time
operations in a closed world:

- **Class reopening**: `class Foo; end; class Foo; def bar; end; end` — the
  constant `Foo` points to the same class object throughout; the compiler sees
  all `class Foo` bodies merged together. Not a mutation.
- **Autoloading**: `autoload :Foo, 'foo'` — the constant is pending until first
  access. In a closed world all autoloaded files are in the closed world; the
  compiler resolves them eagerly. Not a mutation.
- **Conditional assignment**: `X = condition ? a : b` — a single assignment
  with a branching value. Not a mutation; Crystal constant with a ternary.
- **Module/class definition with `const_set`**: if `const_set` is called with a
  known constant name and a known value, it is equivalent to a constant
  assignment. Treat it as one.

True constant mutation (reassigning a non-class constant to a different value)
is rare, generates a MRI warning, and is not used in well-behaved code. It can
be supported via a Crystal class variable (`@@x`) but this case almost never
arises in practice.

**Comparison with hierarchy/method-def constraint**

The "no new class/module/method definitions after compilation" constraint is the
*load-bearing* restriction that enables the Crystal target — without it, there
is no closed world and the entire approach collapses. Crystal's own class system
cannot represent a hierarchy that changes at runtime.

"No constant mutation" is a *lesser, derived* constraint. It is lesser because:

1. It almost never applies — constant mutation is unusual and warned in Ruby
2. Most apparent mutations (class reopening, autoload) are not real mutations
3. Where it does apply, the fallback (mutable Crystal variable) is local and
   cheap — it doesn't affect the compilation model for anything else
4. Crucially: any program that satisfies the hierarchy constraint almost
   certainly satisfies the constant-mutation constraint for free, since class and
   module names are the most common "constants" and reopening them isn't mutation

In other words: the hierarchy constraint is a hard gate; the constant-mutation
constraint is a soft edge case that is automatically satisfied by the programs
that matter.

**`const_get` / `const_set` with dynamic names**

Same treatment as `send` and `instance_variable_get`:

```crystal
def const_get(name : FrozoneString) : Frozone::BasicObject
  case name.@bytes.to_s
  when "String" then FROZONE_STRING_CLASS
  when "Array"  then FROZONE_ARRAY_CLASS
  when "Foo"    then FROZONE_FOO_CLASS
  # ... all constants in the closed world
  else raise NameError.new("uninitialized constant #{name}")
  end
end
```

Generated mechanically from the closed-world constant table. O(log n) with a
binary search on the string values, or O(1) with a Crystal hash lookup. Either
way: no reflection, no hash table on the object model, just generated code.



## `Frozone.compile!` — the working pipeline (as of 2026-03)

The snapshot-based compilation pipeline is implemented and working end-to-end.

### The stub pattern

A bench stub:
```ruby
# bench/stubs/matmul.rb
$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end          # silence harness during load phase
require_relative '../benchmarks/matmul'   # settles methods and constants

Frozone.compile! do
  run_benchmark(20) do
    a = matgen(N)
    b = matgen(N)
    _c = matmul(a, b)
  end
end
```

Running through the Frozone interpreter generates Crystal source; `crystal
build` then produces a native binary:

```bash
bundle exec ruby frozone.rb bench/stubs/matmul.rb
# => Frozone.compile!: wrote crystal/matmul.cr
cd crystal && crystal build matmul.cr -o matmul && ./matmul
```

### `SnapshotCodegen` — VM-state-driven Crystal emission

`lib/frozone/compiler/snapshot_codegen.rb` inherits from `CrystalCodegen`
(AST-to-Crystal expression emitter) and adds a top-level driver that walks the
*settled VM state* rather than raw source AST:

1. Walk `Vm::Core::OBJECT_CLASS`'s constant and method tables
2. Filter by `source_location` — exclude `lib/core/4.0/` and `lib/frozone/`
   (these map to the Crystal runtime in `crystal/src/`) and the stub file itself
3. Emit user-defined classes (with their user-defined methods)
4. Emit user-defined top-level methods
5. Emit settled non-class constants (e.g. `N = 200` → `Ruby_N = RubyInteger.new(200_i64)`)
6. Emit the `Frozone.compile!` block body as Crystal `main`

`Vm::Method` duck-types as `Ast::MethodDef` (same ivar names), so
`emit_param_list` works on VM method objects directly.

### The Crystal runtime (`crystal/src/`)

The current runtime provides fully-boxed Ruby value types:

| Crystal class | Ruby type |
|---|---|
| `RubyObject` | abstract base (all values) |
| `RubyInteger` | Integer (wraps `Int64`) |
| `RubyFloat` | Float (wraps `Float64`) |
| `RubyString` | String |
| `RubySymbol` | Symbol |
| `RubyArray` | Array |
| `RubyHash` | Hash |
| `RubyNil` | NilClass (singleton `RUBY_NIL`) |
| `RubyBool` | TrueClass/FalseClass (singletons `RUBY_TRUE`/`RUBY_FALSE`) |
| `RubyRange` | Range |
| `RubyClassProxy` | class objects (for `.class`, `.is_a?`, etc.) |

### Benchmark results (matmul, N=200)

| | ms/iter |
|---|---:|
| Frozone interpreted | ~31,700 |
| Frozone→Crystal compiled (fully boxed) | 2,758 |
| MRI Ruby | 524 |

The compiled path is ~11.5× faster than interpreted with zero type
optimisation. Every integer and float is heap-allocated as a `RubyObject`;
unboxing is the main remaining performance work.


## Type inference

### Overview

The compiler has two complementary type inference layers:

1. **Whole-program TypeInference** (`lib/frozone/compiler/type_inference.rb`,
   ~1100 lines) — forward dataflow analysis over the settled VM state.
2. **Method-body literal inference** (`infer_local_types` in
   `snapshot_codegen.rb`) — fixed-point pass seeding types from literal
   assignments.

Both run before code emission. Their results are unpacked into codegen lookup
maps that drive all downstream optimisations.

### Type lattice

The TI uses a type lattice where lower = more specific:

```
:unknown                   — bottom (not yet analysed)

:i64  :f64                 — unboxed Crystal numerics
:array_i64  :array_f64     — typed arrays (Array(Int64), etc.)
{class: :Node}             — user-defined class instance
{class: :Integer}          — boxed Integer (wider than :i64)
{class: :Array, elem: ...} — Array with element type
{class: :Object}           — top of Ruby hierarchy
```

`meet(a, b)` computes the LCA (least common ancestor) by walking the VM's
class hierarchy. Unboxed types widen to their boxed class before LCA:
`meet(:i64, :f64)` → `{class: :Numeric}`. `:unknown` is the identity.

### Slots

Everything the TI tracks is a "slot" — a `[kind, context, name]` tuple:

| Slot | Example | Meaning |
|------|---------|---------|
| `[:local, :fib, :n]` | local `n` in method `fib` | Variable type |
| `[:local, nil, :a]` | local `a` in execute block | Variable type |
| `[:param, :fib, 0]` | first param of `fib` | Inferred param type |
| `[:return, :fib]` | return value of `fib` | Return type |
| `[:ivar, :Planet, :@x]` | ivar `@x` of class `Planet` | Instance variable type |
| `[:const, :N]` | constant `N` | Constant type |
| `[:array_elem, :solve, :cr]` | array `cr` in `solve` | Element type |
| `[:block_param, :solve, :i]` | block param `i` | Block param type |

### Fixed-point iteration

The TI runs 3 iterations (configurable):

**Round 1** — seed from literals, propagate through immediate arithmetic:
- Integer/float/string/nil/true/false literals → precise types
- `x = 1 + 2` → `x` is `:i64`
- Method calls with typed args → typed params → typed returns
- Ivar assignments from constructor params → typed ivars

**Round 2** — return types feed callers:
- `fib(n)` returns `:i64` → callers of `fib` now see `:i64` at call sites
- Array element types propagate through `Array.new(n) { block }`

**Round 3** — one more hop for recursion / indirect propagation:
- Recursive methods see their own return type
- Transitive type flow stabilises

### How results flow into codegen

After TI runs, `SnapshotCodegen.run_type_inference` unpacks the slot map into
per-flag lookup structures:

| TI slot → | Codegen map | Gated by flag |
|-----------|-------------|---------------|
| `:local` scalars | `@ti_locals` → `@typed_locals` | `unbox_locals` |
| `:local` classes | `@ti_class_locals` → `@current_class_locals` | `devirtualize` |
| `:local` arrays | `@ti_local_array_elems` | `native_arrays` |
| `:param` | `@inferred_params` | `call_site_types` |
| `:return` | `@typed_method_returns`, `@instance_method_raw_returns` | `method_specialization`, `raw_returns` |
| `:ivar` | `@typed_ivars` | `typed_ivars` |
| `:array_elem` | `@ti_arrays` → `@typed_array_locals` | `native_arrays` |
| `:block_param` | `@ti_block_params` | `native_iteration` |
| `:const` | `@const_raw_types` | `unbox_locals` |

Each flag gates whether its map is populated; when the flag is off, the map
stays empty and the optimisation naturally doesn't fire.

### Self is a strong clue

When emitting a method defined on class `Foo`, `self` is always *at least*
`Ruby_Foo` — and for leaf classes (no subclasses in the closed world), `self`
is *exactly* `Ruby_Foo`. This makes instance variable types directly inferable
from the class definition without a general type inferencer:

- `initialize` fixes ivar types: `@x = x * DAYS_PER_YEAR` where `x : Float64`
  → `@x : Float64`
- Methods on a leaf class can emit `@x` as `Float64` directly — no
  `RubyObject` boxing needed for the ivar load or store

For non-leaf classes, `self` is a `Ruby_Foo | Ruby_Bar | ...` union — Crystal's
type inference handles this naturally once the types are emitted correctly.

**Literals are always exact:**
- `1`, `200`, `-1` → `Int64`
- `1.0`, `0.01` → `Float64`
- `"string"` → `RubyString`
- `true`/`false`/`nil` → `RubyBool`/`RubyNil`

**Return types of known methods:**
- `Integer#+`, `Integer#*`, etc. → `Int64` when both args are `Int64`
- `Float#+`, `Float#*`, etc. → `Float64` when both args are `Float64`
- `Array#length`, `Array#size` → `Int64`

### The inference algorithm (implemented)

Type inference is implemented in two complementary layers:

1. **Whole-program TypeInference** (`type_inference.rb`): forward dataflow
   over the settled VM state. Tracks locals, params, ivars, returns, array
   elements, and constants as a type lattice (`:unknown` → class-typed →
   scalar `:i64`/`:f64`). Three fixed-point iterations. Results are unpacked
   into per-flag codegen lookup maps.

2. **Method-body literal inference** (`infer_local_types`): fixed-point
   pass over method ASTs seeding types from literal assignments, then
   propagating through arithmetic and local variable assignments.

The combined inference enables 13 optimisation passes (see
`docs/optimisations.md`) producing 10–200× speedups over unoptimised
output on numeric benchmarks.

### Achieved payoff

For numeric benchmarks, the inner loops reduce to native `Int64`/`Float64`
arithmetic with no allocation. Results (Crystal `--release` vs MRI):

- fib(20): **22× faster than MRI**, 13× faster than YJIT
- nbody: **95× faster than MRI**, 33× faster than YJIT
- loops_times: **73× faster than MRI**, 18× faster than YJIT
- attr_accessor: **72× faster than MRI/YJIT**

Mixed benchmarks (binarytrees, sudoku) are 3–9× faster than MRI.
Object-heavy benchmarks (splay) remain slower than YJIT due to
Crystal's union dispatch overhead vs YJIT's inline caches.

---

## Compiled spec testing

The `--aot` flag enables compiling spec-like files without source modification:

```bash
frozone --aot bench/specs/language_spec_small.rb          # auto-detect load/execute boundary
frozone --aot -r bench/test_harness.rb some_spec.rb       # pre-load test harness
```

A minimal mspec-compatible test harness (`bench/test_harness.rb`) provides
`describe`/`it`/`should` for compiled specs. 35+ tests pass through
compilation (Array, Integer, String, language constructs, respond_to?, is_a?).

### Next steps for compiled spec coverage

- **instance_eval support** — needed for real mspec (blocks run with rebound self)
- **Broader Ruby constructs** — exception handling, more class patterns
- **Real ruby-spec files** — the goal is `frozone --aot` on actual ruby-spec files

---

## Future compiler ideas

### Compile-time erasure: `respond_to?`, `is_a?`, `send`

Three of Ruby's most-called reflective methods can be resolved at compile time
in the closed world.

**`respond_to?` — per-class bit array**

1. Collect all method names across all classes → assign each a unique index (0..N).
2. Per class, emit a compact bit array of size N — bit `i` is set if that class
   has method `i`.
3. Each method-name Symbol carries its index as a cached field (interned
   singletons, so one extra integer per unique method name).
4. `obj.respond_to?(:foo)` compiles to `self.class.respond_to_table[foo.method_index]`
   — O(1), no string comparison, no hash lookup.
5. With a literal symbol argument AND known receiver type, the compiler can
   **constant-fold** the entire call to `true` or `false` — zero runtime cost.

**`is_a?` — same technique**

1. Collect all classes/modules → assign each a unique index.
2. Per class, emit a bit array of "is this class/module in my ancestor chain?".
3. `obj.is_a?(Foo)` compiles to `self.class.isa_table[Foo.class_index]` — O(1).
4. With a literal class AND known receiver type → constant-fold.

**`send(:method_name)` — direct call erasure**

`send` with a literal Symbol argument can be replaced with a direct method call
at compile time. The compiler knows the method exists (closed world), knows
visibility, and can emit the direct call — eliminating the dynamic dispatch
overhead entirely. This is particularly valuable in `lib/core/4.0/` where `send`
is used to call private methods (e.g., `n.send(:coerce, self)` in Integer).

**Impact:** The `respond_to` benchmark (6M calls) compiles to 0.3ms with constant
folding — 540× faster than MRI, 50× faster than YJIT. All `respond_to?` calls
resolve to `true`/`false` at compile time.

### Module flattening

At compile time, resolve all `include`/`prepend` into concrete per-class method
tables. The interpreter keeps the real module hierarchy; the compiler flattens
before emission. Benefits: simpler TI (no module lookup chains), unambiguous ivar
ownership, handles Crystal's lack of prepend support. Kernel methods map to the
Crystal runtime, so duplication explosion is limited to user-defined modules.

### String encoding specialization

Most Ruby programs use UTF-8 or ASCII-8BIT exclusively. TI can track string
encoding through the program. For ASCII-only strings: `length == bytesize`,
`reverse` is byte reversal, `[]` is byte indexing, `==`/`<=>` are raw byte
comparisons. Eliminating encoding guards from hot paths enables direct Crystal
`Bytes` operations with no `RubyString` wrapper overhead.

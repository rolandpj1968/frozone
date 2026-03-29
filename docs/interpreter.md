# Frozone Interpreter

Frozone is a tree-walking interpreter for Ruby 4.0. It parses Ruby source into an AST
and evaluates nodes directly — no bytecode compilation step.

## Architecture

### VM Runtime (`lib/frozone/vm/`)

The VM is built around a small set of core objects:

- **ObjectObject** — base for all Frozone-land objects; holds `@class_object`, instance variables
- **ClassObject < ModuleObject < ObjectObject** — the metaclass hierarchy
- **Method** — stores parameter info, body (AST), `uses_block` flag, `source_location`
- **Frame** — execution frame: `the_self`, local variables, `method_frame`, `def_scope`
- **Context** — stack of Frames; pushed/popped for each method/block call

### Class Hierarchy (`lib/frozone/vm/hierarchy.rb`)

The full Ruby class hierarchy (BasicObject → Object → Kernel, Integer, String, Array, Hash,
etc.) is defined in parsed Ruby in `hierarchy.rb`. This file is loaded by the VM at startup
and evaluated to create all class/module objects.

Bootstrap order:
1. `core.rb` — creates 4 essential classes (Object, Class, Module, BasicObject)
2. `hierarchy.rb` — fills in the rest of the hierarchy
3. Bootstrap calls — `NilObject.bootstrap!`, `TrueObject.bootstrap!`, etc.
4. `lib/core/4.0/*.rb` — Ruby stdlib loaded as Frozone-Ruby source

### Core Library (`lib/core/4.0/`)

The Ruby standard library is implemented in Ruby source files that the interpreter parses
at startup. These files define methods on core classes (String, Array, Hash, Integer, etc.)
using a mix of pure Ruby and `Intrinsics.*` calls for operations that require MRI access.

**Design principle:** methods that CAN be expressed in pure Ruby SHOULD be in `lib/core/4.0/`,
not in intrinsics. This makes them visible to the spec suite, auditable, and compilable.

### Intrinsics (`lib/frozone/vm/intrinsics/`)

Intrinsics are MRI-Ruby methods called via `Intrinsics.method_name(args)`. The parser
recognises `ConstantReadNode(:Intrinsics)` and emits `Ast::IntrinsicCall` nodes, which
bypass Frozone-land dispatch entirely.

Intrinsics should contain ONLY what cannot be implemented in pure Ruby:
- Raw string byte access, encoding conversion tables
- Regex engine
- I/O and OS primitives
- VM bootstrap operations (class creation, method definition)

### Parsers

Two independent front-ends produce the same Frozone AST:

| Parser | Implementation | Status |
|--------|----------------|--------|
| **Prism** (default) | `lib/frozone/vm/parser.rb` — wraps the `prism` gem | 2615/2630 |
| **WqParser** | `lib/frozone/vm/wq_parser.rb` — wraps whitequark `parser` gem | ~2613/2630 |

Switch with `--parser=wq` or `PARSER=wq`.

The WqParser uses a [fork of whitequark/parser](https://github.com/rolandpj1968/parser)
that adds Ruby 4.0 parsing support. It exists as a self-hostable path — the `parser` gem
is pure Ruby (no C extensions), so the inner Frozone could eventually use it.

## Self-Hosting (Frozone²)

Frozone can run itself:

```
bundle exec ruby frozone.rb frozone.rb -e "puts 'hello from frozone²'"
# => hello from frozone²
```

**The cheat:** the inner Frozone's `Vm::Vm` class is replaced by a thin proxy that
routes evaluation back to the outer Frozone's MRI-backed evaluator. All Frozone source
files are pre-stubbed in the inner `$LOADED_FEATURES`. The inner Frozone detects it is
running inside Frozone via `RUBY_DESCRIPTION.start_with?('frozone')`.

True self-hosting — where the inner Frozone runs its own AST evaluator on its own class
objects — requires the core library to be fully de-intrinsified (all `String`, `Array`,
`Hash` methods in pure Frozone-Ruby rather than delegating to MRI).

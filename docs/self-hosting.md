# Self-Hosting (Frozone²)

Frozone can run itself. There is no bootstrap problem.

## The key insight

Level 1 Frozone is just a Ruby interpreter. Level 2 Frozone is just a Ruby program.
Level 1 doesn't know or care that its target program is another Frozone interpreter.

When level 2 calls `Intrinsics.string_get_byte(self, i)`, the parser emits an
`IntrinsicCall` node. Level 1's evaluator calls `Vm::Intrinsics.string_get_byte`
— which is plain MRI Ruby calling `.getbyte` on the backing string. No special
bootstrapping, no shims, no proxies. It just works.

## Examples

### Basic

```
$ bundle exec ruby frozone.rb frozone.rb -e "puts 'hello from frozone²'"
hello from frozone²
```

### Real computation

```
$ bundle exec ruby frozone.rb frozone.rb -e '
class Dog
  def initialize(name) = @name = name
  def speak = "#{@name} says woof!"
end
puts Dog.new("Rex").speak
'
Rex says woof!
```

### Frozone³

```
$ bundle exec ruby frozone.rb frozone.rb frozone.rb -e "puts 'hello from frozone³'"
hello from frozone³
```

### Pure-Ruby path

With `--parser=wq`, the inner Frozone uses the pure-Ruby whitequark parser —
no C extensions in the parse path:

```
$ bundle exec ruby frozone.rb frozone.rb --parser=wq -e "puts 'pure ruby all the way'"
pure ruby all the way
```

### Running specs through Frozone²

Language specs pass through Frozone² with identical results to level 1:

```
$ time bundle exec ruby frozone.rb frozone.rb \
    spec/mspec_runner.rb spec/ruby-spec/language/if_spec.rb
52 examples, 0 failures, 0 errors — 2.6s

$ time bundle exec ruby frozone.rb frozone.rb \
    spec/mspec_runner.rb spec/ruby-spec/language/def_spec.rb
73 examples, 0 failures, 0 errors — 3.6s
```

## Performance

Self-hosting is slow by design — a tree-walking interpreter interpreting a tree-walking
interpreter. Each level adds roughly one order of magnitude:

| Level | Example | Time |
|-------|---------|------|
| MRI (YJIT) | `fib(15)` | ~0.01ms |
| Frozone¹ | `fib(15)` | ~50ms |
| Frozone² | `fib(15)` | ~1100ms |

This is expected. The interpreter's job is correctness and spec compliance.
Performance is the compiler's job.

## Why it works

There is no circular dependency. The "levels" are:

1. **MRI** runs `frozone.rb` (level 1)
2. Level 1 loads its VM, parses level 2's `frozone.rb`, evaluates it
3. Level 2 loads its OWN VM (as Frozone objects inside level 1)
4. Level 2 parses the `-e` script and evaluates it
5. Level 2's intrinsic calls are handled by level 1's evaluator

Each level's `Intrinsics` module is a real set of MRI methods at level 1.
When level 2's code calls an intrinsic, level 1 dispatches to the MRI method —
the same way it handles any other method call from any other Ruby program.

The `lib/core/4.0/` Ruby source files are loaded by EACH level independently.
Level 2's `String` class is a Frozone ObjectObject inside level 1, with its methods
defined by evaluating `lib/core/4.0/string.rb` through level 1's interpreter.

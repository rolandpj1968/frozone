# Frozone — Code Conventions

## Code style

### One-liners first
Within every logical section of any file, all single-line endless methods must appear **before** multi-line methods:

```ruby
# Good — one-liners summarise the section, multi-liners are detail below
def size   = @data.size
def empty? = @data.empty?

def push(v)
  @data << v
  self
end
```

Never mix them. Do not move methods across section boundaries when reordering.

### Prefer endless one-liners
Any method whose body fits naturally on one line should use the endless form:

```ruby
def foo = expr            # preferred
def foo; expr; end        # only if endless is unreadable
```

This applies to simple delegations, predicates, attribute readers, and thin wrappers.
When a multi-line method is just "coerce then call" or "validate then delegate",
inline the coercion into the call — don't use a temporary variable:

```ruby
# Good — one logical expression
def <<(n) = Intrinsics.integer_lshift(self, __coerce_to_int__(n))

# Bad — unnecessary temporary, artificially multi-line
def <<(n)
  n = __coerce_to_int__(n)
  Intrinsics.integer_lshift(self, n)
end
```

### Section structure
Each file has at most one public section and one private section. All public methods come first, all private methods at the bottom under a single `private` keyword. Do not interleave public and private, and do not use multiple `private` declarations. Always leave a blank line before the `private` keyword.

### Blank lines around methods
- Multi-line methods: one blank line before and after.
- Adjacent single-liners: no blank lines between them.

### Brevity over superficial efficiency
Prefer clear, concise code over hand-optimised code. It is the compiler's job to turn neat Ruby into efficient native code. Write for readability first:

```ruby
# Good — clear intent, let the compiler optimise
def reverse = @data.reverse

# Bad — manual "optimisation" that obscures intent
def reverse
  result = []
  i = @data.size - 1
  while i >= 0
    result << @data[i]
    i -= 1
  end
  result
end
```

### Extract common patterns
When you see the same code pattern repeated, extract it into a helper. Three similar lines are fine; four is a smell. But don't create abstractions for hypothetical future use — extract only when the pattern already exists in multiple places.

### Post-refactoring checklist
After any broad refactoring pass (sed/perl sweeps, agent conversions, coercion refactors):
1. Convert newly-simple methods to endless one-liners where natural.
2. Re-herd: move all one-liners before multi-liners within each section.
3. Look for repeated patterns and extract common helpers.
4. Run `bundle exec rspec` to verify no regressions.
5. Smoke test the interpreter: `bundle exec rake language` (takes ~1-2 min, broader coverage than rspec).

---

## Intrinsics vs Ruby-land

**Intrinsics** (`lib/frozone/vm/intrinsics/`) should contain **only** what cannot be implemented in pure Ruby:
- Direct access to MRI-internal state (object identity, raw numeric values, raw string bytes)
- Encoding conversion tables
- Regex engine
- I/O and OS primitives
- VM bootstrap operations (class creation, method definition, constant lookup)

Everything else belongs in **`lib/core/4.0/`** as Frozone-Ruby. If a method can be expressed purely in terms of other Ruby methods, it should be there — not in intrinsics.

---

## Coercion protocol

Implicit coercion helpers live in `lib/frozone/vm/intrinsics/helpers.rb`. Use them everywhere; do not inline `fint?(v) ? v.raw : v.raw.to_i` patterns.

| Helper | Protocol | Raises on failure |
|--------|----------|------------------|
| `try_to_int(ctx, v)` | `to_int` | no — returns nil |
| `coerce_to_int(ctx, v)` | `to_int` | yes — TypeError |
| `try_to_str(ctx, v)` | `to_str` | no — returns nil |
| `coerce_to_str(ctx, v)` | `to_str` | yes — TypeError |
| `try_to_ary(ctx, v)` | `to_ary` | no — returns nil |
| `coerce_to_ary(ctx, v)` | `to_ary` | yes — TypeError |
| `try_to_hash(ctx, v)` | `to_hash` | no — returns nil |
| `coerce_to_hash(ctx, v)` | `to_hash` | yes — TypeError |
| `try_to_float(ctx, v)` | `to_f` | no — returns nil |
| `coerce_to_float(ctx, v)` | `to_f` | yes — TypeError |
| `try_to_sym(ctx, v)` | `to_str`→sym | no — returns nil |
| `coerce_to_sym(ctx, v)` | `to_str`→sym | yes — TypeError |
| `try_to_proc(ctx, v)` | `to_proc` | no — returns nil |
| `coerce_to_proc(ctx, v)` | `to_proc` | yes — TypeError |

Use `coerce_*` for operator and indexing arguments (mirrors MRI `rb_convert_type`).
Use `try_*` for optional coercion where nil is a valid "not applicable" result (mirrors MRI `rb_check_convert_type`).

**Never** use `to_i`, `to_s`, etc. directly on Frozone objects in operator/indexing context — those are explicit conversions and bypass the implicit coercion protocol.

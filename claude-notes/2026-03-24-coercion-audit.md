# Coercion Audit — Frozone lib/core/4.0/

*Generated: 2026-03-24*

---

## Executive Summary

**Grade: B+** — The codebase shows a mature, consistent coercion approach. The overwhelming majority of coercion sites follow correct MRI protocol. There are no catastrophic gaps, but a handful of recurring issues degrade spec compliance:

1. **`send(:to_ary)` / `send(:to_a)` in `Kernel#Array()`** — bypasses `respond_to?` check; MRI only calls these if the method is publicly defined.
2. **`rescue NoMethodError` used as a `respond_to?` substitute** in several String, Array, and Enumerable methods — fragile because `NoMethodError` can mask unrelated bugs inside the conversion method itself.
3. **Direct `obj.to_xxx` without `respond_to?` guard** — raises `NoMethodError` instead of `TypeError` in several places.
4. **`Hash#__coerce_to_hash__`** does not validate the return value of `to_hash`.
5. **`IO#lineno=`** does not validate the return value of `to_int`.
6. **`__coerce_to_str__`** raises wrong error message when `to_str` returns wrong type.
7. **Several non-standard error messages** — missing class names, wrong phrasing.

---

## Kernel Conversion Functions

### `Kernel#Integer(val, base, exception:)` (kernel.rb:135–204)

**Overall: Good.** Handles Integer, Float, String, nil, and generic objects correctly.

- Float to Integer via `to_i`: correct (MRI truncates toward zero).
- `to_int` tried first for generic objects, `to_i` as fallback: correct MRI order.
- Base coercion via `respond_to?(:to_int)` then `to_int`: correct.
- **Minor issue (line 180–181):** If `to_int` returns a non-nil non-Integer, code falls through to `to_i`. MRI raises `TypeError` immediately if `to_int` returns non-Integer. The comment says "fall through" but MRI does not — it checks the return type and raises on `to_int` failure.
- Error messages match MRI format.

### `Kernel#Float(val, exception:)` (kernel.rb:206–247)

**Overall: Correct.** Handles Float, Integer, Rational, Complex, String, nil, and generic `to_f`.

- Generic `respond_to?(:to_f)` path validates return type: correct.
- Bare `rescue` on `to_f` call (line 234) catches all exceptions and re-raises as TypeError — matches MRI behavior.

### `Kernel#String(val)` (kernel.rb:249–274)

**Overall: Mostly correct, but overcomplicated.**

- Tries `to_str` first (correct), then `to_s`.
- The `singleton_class.method_defined?(:to_s)` check (lines 258–263) is not what MRI does. MRI just calls `to_s` and relies on it being defined. Frozone's check is an attempt to detect when `to_s` was `undef`d, but is a fragile approximation.
- The `rescue NoMethodError` on `to_s` (line 271) is correct recovery to `TypeError`.

### `Kernel#Array(val)` (kernel.rb:276–295)

**Critical issue: `send(:to_ary)` and `send(:to_a)` bypass `respond_to?`.**

```ruby
# kernel.rb:281 — WRONG
result = val.send(:to_ary)
```

MRI calls `to_ary` only if `respond_to?(:to_ary)` is true. Using `send` means a private `to_ary` would be called when MRI would not. The `rescue NoMethodError` fallback makes this functionally equivalent for simple cases but diverges when `to_ary` is defined privately or raises `NoMethodError` internally.

Same problem for `send(:to_a)` at line 288.

**MRI-correct pattern:**
```ruby
if val.respond_to?(:to_ary)
  result = val.to_ary
  return result if result.is_a?(Array)
  # handle nil or bad return
end
if val.respond_to?(:to_a)
  result = val.to_a
  return result if result.is_a?(Array)
  # handle nil or bad return
end
[val]
```

### `Kernel#Hash(val)` (kernel.rb:297–307)

**Minor issue: `val.to_hash` called without `respond_to?` guard.**

```ruby
# kernel.rb:301 — no guard
result = val.to_hash
```

The `rescue NoMethodError` below handles the missing-method case, but this is the wrong idiom. Should use `respond_to?(:to_hash)` first. Also, if `to_hash` returns a non-Hash non-nil, the error message path is correct (line 303).

---

## Per-File Coercion Audit

### kernel.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 79–84 | `warn` (uplevel) | `to_int` | `respond_to?` then call, validates return | ✓ |
| 120–121 | `sprintf` | `to_str` | `respond_to?` then call | ✓ |
| 135–204 | `Integer()` | `to_int`, `to_i` | correct priority order | ✓ with note |
| 178–180 | `Integer()` | `to_int` non-Integer fallthrough | should raise immediately | ⚠ |
| 206–247 | `Float()` | `to_f` | correct | ✓ |
| 249–274 | `String()` | `to_str`, `to_s` | overcomplicated but mostly correct | ⚠ |
| 276–295 | `Array()` | `to_ary`, `to_a` | `send(...)` + rescue NME — wrong idiom | ✗ |
| 297–307 | `Hash()` | `to_hash` | no `respond_to?` guard | ⚠ |
| 397–418 | `open` | `to_path`, `to_str` | `to_path` return not validated | ⚠ |
| 421–423 | backtick | `to_str` | direct call without `respond_to?` guard | ✗ |
| 445–453 | `__coerce_to_int__` | `to_int` | correct | ✓ |
| 460–485 | `__coerce_load_path__` | `to_path`, `to_str` | correct | ✓ |
| 487–504 | `__coerce_ivar_name__` | `to_str` | correct | ✓ |

**kernel.rb line 421–423 — Backtick `` ` ``:**
```ruby
def `(cmd)
  cmd = cmd.is_a?(String) ? cmd : cmd.to_str  # WRONG: no respond_to? check
```
If `cmd` does not respond to `to_str`, raises `NoMethodError` instead of `TypeError "no implicit conversion of Foo into String"`.

**kernel.rb line 405–408 — `open` `to_path` path:**
```ruby
name = if name.respond_to?(:to_path)
  name.to_path   # No return-value validation
```
If `to_path` returns a non-String, no error is raised. `__coerce_load_path__` handles this correctly; `open` does not.

### string.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 20–26 | `try_convert` | `to_str` | `respond_to?` + call + validates return | ✓ |
| 30 | `initialize` | nil rejection | correct | ✓ |
| 38–41 | `+` | `to_str` | `respond_to?` + return validation | ✓ |
| 48–50 | `*` | `to_int` | direct call without `respond_to?` guard | ✗ |
| 63–77 | `<<` | `to_str` | `respond_to?` + return validation | ✓ |
| 94 | `to_i` | `to_int` on base | direct call without `respond_to?` guard | ✗ |
| 184–192 | `start_with?` | `to_str` | `rescue NoMethodError` pattern | ⚠ |
| 198–202 | `end_with?` | `to_str` | `rescue NoMethodError` pattern | ⚠ |
| 704–710 | `upto` | `to_str` | `rescue NoMethodError/TypeError` pattern | ⚠ |
| 716–726 | `tr_s`, `tr_s!` | `to_str` | direct call without `respond_to?` guard | ✗ |
| 923–927 | `__coerce_to_str__` | `to_str` | `respond_to?` + call; wrong error message | ⚠ |

**string.rb line 48–50 — `String#*`:**
```ruby
n = n.to_int unless n.is_a?(Integer)  # WRONG: no respond_to? guard
```
Raises `NoMethodError` instead of `TypeError "no implicit conversion of Foo into Integer"`.

**string.rb line 94 — `String#to_i(base)`:**
```ruby
base = base.to_int unless base.is_a?(Integer)  # WRONG: no respond_to? guard
```
Same issue.

**string.rb line 716–726 — `String#tr_s`, `String#tr_s!`:**
```ruby
from = from.to_str unless from.is_a?(String)  # WRONG: no respond_to? guard
to = to.to_str unless to.is_a?(String)         # WRONG: no respond_to? guard
```
Raises `NoMethodError` when `from`/`to` lack `to_str`.

**string.rb line 923–927 — `__coerce_to_str__` error message:**
```ruby
raise TypeError, "can't convert to String" unless result.is_a?(String)
```
MRI message: `"can't convert Foo into String (Foo#to_str should return String, not Bar)"`.

**string.rb line 184–202 — `start_with?` / `end_with?` rescue pattern:**
Using `rescue NoMethodError` instead of `respond_to?(:to_str)`. Functionally equivalent for the common case but doesn't validate the return value of `to_str`.

### array.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 10–15 | `try_convert` | `to_ary` | `respond_to?` + call + validates return | ✓ |
| 18–43 | `initialize` | `to_ary`, `to_int` | correct | ✓ |
| 123–143 | `concat` | `to_ary` | `rescue NoMethodError` pattern | ⚠ |
| 280–312 | `*` | `to_str`, `to_int` | correct `respond_to?(:to_str)` priority | ✓ |
| 1790–1800 | `__coerce_to_int__` | `to_int` | correct | ✓ |
| 1767–1787 | `__coerce_to_pair__` | `to_ary` | `respond_to?` + rescue NME hybrid | ⚠ |

**array.rb line 123–143 — `Array#concat`:**
```ruby
begin
  r = other.to_ary  # No respond_to? guard
  raise TypeError, "to_ary must return Array" unless r.is_a?(Array)
  r
rescue NoMethodError
  raise TypeError, "no implicit conversion of #{other.class} into Array"
end
```
`rescue NoMethodError` pattern. Should use `respond_to?(:to_ary)`.

### hash.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 74–80 | `try_convert` | `to_hash` | `respond_to?` + call + validates return | ✓ |
| 47–49 | `[]` (1-arg) | `to_hash` | `respond_to?` + call + validates return | ✓ |
| 677–681 | `__coerce_to_hash__` | `to_hash` | `respond_to?` but NO return validation | ✗ |
| 420–424 | `flatten` | `to_int` | `respond_to?` + call + validates return | ✓ |

**hash.rb line 677–681 — `__coerce_to_hash__`:**
```ruby
def __coerce_to_hash__(other)
  return other if other.is_a?(Hash)
  return other.to_hash if other.respond_to?(:to_hash)  # WRONG: no return validation
  raise TypeError, "no implicit conversion of #{other.class} into Hash"
end
```
If `to_hash` returns a non-Hash, no `TypeError` is raised. MRI requires: `"can't convert Foo into Hash (Foo#to_hash gives Bar)"`. This affects `merge`, `merge!`, `update`, `replace`, `<=`, `>=`, `<`, `>`.

### integer.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 37–54 | `<`, `<=`, `>=`, `>` | `coerce` | via `__coerce_and_compare__` | ✓ |
| 69–91 | `+`, `-`, `*`, `/`, `%` | `coerce` | via `__coerce_op__` | ✓ |
| 113–122 | `<=>` | `coerce` | `respond_to?(:coerce)` + rescue | ✓ |
| 319–338 | `&`, `|`, `^` | `coerce` | inline rescue NME | ✓ |
| 341–348 | `<<`, `>>` | `to_int` | `respond_to?` + call + validates return | ✓ |
| 403–414 | `allbits?`, `anybits?`, `nobits?` | `to_int` via `__coerce_to_int__` | ✓ |
| 422–438 | `coerce` | reverse coerce | ✓ |
| 497–506 | `__coerce_to_int__` | `to_int` | correct logic; wrong error message | ⚠ |
| 199–201 | `round` ndigits | `to_int` | correct logic; wrong error message | ⚠ |

**integer.rb line 497–506 — `__coerce_to_int__` error message:**
```ruby
raise TypeError, "Integer expected"  # non-standard
```
MRI says: `"no implicit conversion of Foo into Integer"`.

**integer.rb line 199–201 — `Integer#round` ndigits:**
```ruby
raise TypeError, "can't convert to Integer" unless n.is_a?(Integer)  # non-standard
```
MRI says: `"can't convert Foo into Integer (Foo#to_int should return Integer, not Bar)"`.

### float.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 38–81 | arithmetic ops | `coerce` | inline rescue NME → TypeError | ✓ |
| 83–101 | comparisons | `coerce` via `__coerce_and_compare__` | ✓ |
| 105–113 | `==` | `coerce` + fallback `other == self` | ✓ (matches MRI) |
| 123–139 | `<=>` | `coerce` with return-value check | ✓ |
| 142–145 | `coerce` | `respond_to?(:to_f)` | ✓ |
| 249–258 | `__to_int__` | `to_int` | correct | ✓ |

Float is clean; no issues found.

### numeric.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 59–68 | `remainder` | `coerce` | direct call without guard | ⚠ |
| 77–95 | `coerce` | `to_f` | excludes nil/true/false/Symbol | ✓ |

**numeric.rb line 60 — `Numeric#remainder`:**
```ruby
def remainder(other)
  a, b = other.coerce(self)   # No guard — raises NoMethodError if coerce absent
```
MRI raises `TypeError "Foo can't be coerced into Numeric"`. Frozone raises `NoMethodError`.

### io.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 115–116 | `read` buf | `to_str` | `respond_to?` + call, no return validation | ⚠ |
| 127–130 | `lineno=` | `to_int` | `respond_to?` but no return validation | ✗ |
| 148–155 | `gets` | `to_int`, `to_str` | complex disambiguation; mostly correct | ✓ |
| 207–210 | `ungetc` | `to_str` | `respond_to?` + call, no return validation | ⚠ |
| 219–222 | `seek` | `to_int` | `respond_to?` + `Integer()` fallback | ✓ |
| 302–305 | `putc` | `to_int` | `respond_to?` + call, no return validation | ⚠ |
| 330–331 | `IO.pipe` | `to_str` | `respond_to?` + call, no return validation | ⚠ |
| 739 | read length | `to_int` | `respond_to?` check but no validation; wrong error message | ⚠ |

**io.rb line 127–130 — `IO#lineno=`:**
```ruby
raise TypeError, "..." unless n.respond_to?(:to_int)
val = n.to_int   # No return-type validation; silent wrong value if to_int returns non-Integer
@lineno = val
```
Should validate: `raise TypeError "..." unless val.is_a?(Integer)`.

### file.rb

File uses `_coerce_path` (a private helper) for all path arguments. The helper correctly:
1. Returns String as-is.
2. Calls `to_path`, validates result, then tries `to_str` if needed.
3. Falls back to `to_str` with validation.
4. Raises `TypeError` with correct message.

File.rb is clean overall.

### range.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 361 | `first(n)` | `to_int` | `respond_to?` + call + validates return | ✓ |
| 376 | `last(n)` | `to_int` | `respond_to?` + call + validates return | ✓ |
| 307–316 | `step` | `coerce` for numeric step | `respond_to?(:coerce)` + call | ✓ |

Range is clean; no issues found.

### enumerable.rb

| Line | Method | Coercion | Protocol | Verdict |
|------|--------|----------|----------|---------|
| 53–66 | `__coerce_count__` | `to_int` | `rescue NoMethodError` pattern | ⚠ |
| 86–88 | `to_h` | `to_ary` | `respond_to?` + call + validates return | ✓ |
| 119–126 | `flat_map` | `to_ary` | `respond_to?` + call + validates return | ✓ |
| 492–496 | `tally` | `to_hash` | `respond_to?` + call + validates return | ✓ |

**enumerable.rb line 53–66 — `__coerce_count__`:**
```ruby
begin
  n2 = n.to_int   # No respond_to? guard
rescue NoMethodError
  raise TypeError, "no implicit conversion of #{n.class} into Integer"
end
```
`rescue NoMethodError` pattern. Should use `respond_to?(:to_int)`.

### rational.rb

Rational arithmetic is clean — all `__coerce_op__` calls use `coerce` correctly with `rescue NoMethodError`.

`__rational_coerce__` (lines 608–649): Complex logic but mostly correct. The `rescue NoMethodError` at top level handles `BasicObject` subclasses appropriately. `respond_to?(:to_r)` then `respond_to?(:to_int)` checks are correct.

`Rational()` and `Complex()` kernel functions: correct overall.

### exception.rb

**`Math._coerce_float` (lines 592–600):**
```ruby
raise TypeError, "can't convert #{type_name} into Float" unless x.is_a?(Numeric)
```
Checks `is_a?(Numeric)` rather than `respond_to?(:to_f)`. Objects that define `to_f` but don't inherit from `Numeric` won't be coerced. MRI's `rb_to_float` accepts any object responding to `to_f`.

**`Signal.signame` (lines 293–298):** Correct `respond_to?(:to_int)` + validate return pattern. Small error message issue: `"no implicit conversion into Integer"` (missing class name) when `to_int` returns non-Integer.

`SystemCallError.new` (lines 437–490): No coercion issues.

---

## Systematic Issues

### 1. `rescue NoMethodError` as a substitute for `respond_to?`

Appears in: `Kernel#Array()`, `Kernel#Hash()`, `Array#concat`, `Enumerable#__coerce_count__`, `String#start_with?/end_with?/upto`, and others.

This pattern is wrong idiom:
- It's slower.
- It silently swallows genuine `NoMethodError`s raised *inside* `to_ary`/`to_str` (e.g., a bug in the conversion method itself).
- It does not honour Ruby's visibility rules — `send` calls private methods that `respond_to?` would reject.

The canonical pattern is `respond_to?(:to_ary)` then call, then validate return type.

### 2. Direct `obj.to_xxx` without `respond_to?` guard

Raises `NoMethodError` instead of `TypeError` when the method is absent. Appears at:
- `kernel.rb:301` — `Hash()` calls `val.to_hash` directly.
- `kernel.rb:422` — backtick calls `cmd.to_str` directly.
- `string.rb:49` — `String#*` calls `n.to_int` without guard.
- `string.rb:94` — `String#to_i(base)` calls `base.to_int` without guard.
- `string.rb:716–726` — `String#tr_s/tr_s!` call `to_str` without guard.
- `numeric.rb:60` — `Numeric#remainder` calls `other.coerce(self)` without guard.

### 3. Missing return-value validation after coercion call

Some sites call `to_str`/`to_hash`/`to_int` without checking if the return value is the right type:
- `hash.rb:679` — `__coerce_to_hash__` returns whatever `to_hash` returns (no type check).
- `io.rb:115` — `read` buf coercion.
- `io.rb:129` — `lineno=` `to_int` return not validated.
- `io.rb:207` — `ungetc` `to_str` return not validated.
- `io.rb:302` — `putc` `to_int` return not validated.

### 4. Non-standard error messages

Multiple sites have messages that deviate from MRI's exact wording, affecting ruby-spec compliance.

---

## Missing `coerce` Protocol

The `coerce` protocol for mixed arithmetic is generally well-implemented:

- `Integer`, `Float`, `Rational`, `Complex` all implement `__coerce_op__` / `__coerce_and_compare__` helpers that correctly call `v.coerce(self)`.
- The helpers rescue `NoMethodError` and raise `TypeError "Foo can't be coerced into Integer/Float"`.
- `Numeric#remainder` (line 60) calls `other.coerce(self)` without a guard — will raise `NoMethodError` instead of `TypeError`.

One note: `Float#coerce` (line 142) calls `v.to_f` for any object responding to `to_f`. This is broad but matches MRI.

`Integer#coerce` (line 422) handles String by calling `Float(other)` — correct MRI behavior.

---

## Error Message Audit

| Location | Frozone message | Expected MRI message |
|----------|----------------|---------------------|
| string.rb:926 | `"can't convert to String"` | `"can't convert Foo into String (Foo#to_str should return String, not Bar)"` |
| integer.rb:501 | `"Integer expected"` | `"no implicit conversion of Foo into Integer"` |
| integer.rb:201 | `"can't convert to Integer"` | `"can't convert Foo into Integer (Foo#to_int should return Integer, not Bar)"` |
| io.rb:739 | `"no implicit conversion into Integer"` | `"no implicit conversion of Foo into Integer"` |
| exception.rb:296 | `"no implicit conversion into Integer"` | `"no implicit conversion of Foo into Integer"` |
| kernel.rb:81 | `"no implicit conversion into Integer"` | `"no implicit conversion of Foo into Integer"` |
| hash.rb:679 | *(no error raised on bad return)* | `"can't convert Foo into Hash (Foo#to_hash gives Bar)"` |
| kernel.rb:422 | `NoMethodError` | `TypeError "no implicit conversion of Foo into String"` |
| string.rb:49 | `NoMethodError` | `TypeError "no implicit conversion of Foo into Integer"` |
| string.rb:716 | `NoMethodError` | `TypeError "no implicit conversion of Foo into String"` |
| string.rb:94 | `NoMethodError` | `TypeError "no implicit conversion of Foo into Integer"` |

---

## Recommended Fixes (Priority Order)

### P1 — Critical (wrong exception type or silently wrong behavior)

**P1.1 — `Kernel#Array()` — replace `send` with `respond_to?` (kernel.rb:279–294)**

Replace `val.send(:to_ary)` and `val.send(:to_a)` with proper `respond_to?` guards, e.g.:
```ruby
if val.respond_to?(:to_ary)
  result = val.to_ary
  return result if result.is_a?(Array)
  return [val] if result.nil?
  raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_ary gives #{result.class})"
end
if val.respond_to?(:to_a)
  result = val.to_a
  return result if result.is_a?(Array)
  return [val] if result.nil?
  raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_a gives #{result.class})"
end
[val]
```

**P1.2 — `String#*` missing `respond_to?` (string.rb:49)**
```ruby
unless n.is_a?(Integer)
  raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.respond_to?(:to_int)
  n = n.to_int
  raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
end
```

**P1.3 — `String#tr_s` / `String#tr_s!` missing `respond_to?` (string.rb:717–718, 724–725)**
```ruby
unless from.is_a?(String)
  raise TypeError, "no implicit conversion of #{from.class} into String" unless from.respond_to?(:to_str)
  from = from.to_str
  raise TypeError, "..." unless from.is_a?(String)
end
```

**P1.4 — Backtick missing `respond_to?` (kernel.rb:422)**
```ruby
unless cmd.is_a?(String)
  raise TypeError, "no implicit conversion of #{cmd.class} into String" unless cmd.respond_to?(:to_str)
  cmd = cmd.to_str
  raise TypeError, "..." unless cmd.is_a?(String)
end
```

**P1.5 — `Hash#__coerce_to_hash__` missing return validation (hash.rb:679)**
```ruby
if other.respond_to?(:to_hash)
  result = other.to_hash
  return result if result.is_a?(Hash)
  raise TypeError, "can't convert #{other.class} into Hash (#{other.class}#to_hash gives #{result.class})" unless result.nil?
end
```

**P1.6 — `String#to_i(base)` missing `respond_to?` (string.rb:94)**
```ruby
unless base.is_a?(Integer)
  raise TypeError, "no implicit conversion of #{base.class} into Integer" unless base.respond_to?(:to_int)
  base = base.to_int
end
```

### P2 — Important (wrong exception type or missing validation)

**P2.1 — `IO#lineno=` missing return-value validation (io.rb:129)**
```ruby
val = n.to_int
raise TypeError, "can't convert #{n.class} into Integer" unless val.is_a?(Integer)
```

**P2.2 — `Numeric#remainder` missing `coerce` guard (numeric.rb:60)**
```ruby
def remainder(other)
  unless other.respond_to?(:coerce)
    raise TypeError, "#{other.class} can't be coerced into Numeric"
  end
  a, b = other.coerce(self)
  ...
end
```

**P2.3 — `Array#concat` replace rescue pattern (array.rb:130–138)**
```ruby
if other.respond_to?(:to_ary)
  r = other.to_ary
  raise TypeError, "to_ary must return Array" unless r.is_a?(Array)
  r
else
  raise TypeError, "no implicit conversion of #{other.class} into Array"
end
```

**P2.4 — `Enumerable#__coerce_count__` replace rescue pattern (enumerable.rb:55–60)**
```ruby
unless n.is_a?(Integer)
  raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.respond_to?(:to_int)
  n2 = n.to_int
  raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n2.is_a?(Integer)
  n = n2
end
```

**P2.5 — `Math._coerce_float` accept `respond_to?(:to_f)` (exception.rb:592–600)**
```ruby
unless x.is_a?(Numeric) || x.respond_to?(:to_f)
  raise TypeError, "can't convert #{type_name} into Float"
end
```

**P2.6 — `Kernel#Hash()` add `respond_to?` guard (kernel.rb:301)**
```ruby
if val.respond_to?(:to_hash)
  result = val.to_hash
  return result if result.is_a?(Hash)
  raise TypeError, "..." unless result.nil?
end
raise TypeError, "no implicit conversion of #{val.class} into Hash"
```

### P3 — Minor (error message mismatches)

**P3.1 — `String#__coerce_to_str__` error message (string.rb:926)**
```ruby
raise TypeError, "can't convert #{obj.class} into String (#{obj.class}#to_str should return String, not #{result.class})"
```

**P3.2 — `Integer#__coerce_to_int__` error message (integer.rb:501)**
```ruby
raise TypeError, "no implicit conversion of #{mask.class} into Integer"
```

**P3.3 — `Integer#round` ndigits message (integer.rb:201)**
```ruby
raise TypeError, "can't convert #{n.class} into Integer (#{n.class}#to_int should return Integer, not #{n.to_int.class})"
```

**P3.4 — `Signal.signame` to_int return message (exception.rb:296)**
```ruby
raise TypeError, "no implicit conversion of #{signum.class} into Integer"
```

**P3.5 — `IO#read` buf, `IO#ungetc`, `IO#putc` coercion return validation (io.rb:115, 207, 302)**
Add return-value checks after `to_str`/`to_int` calls.

**P3.6 — `Kernel#Integer()` to_int non-Integer fallthrough (kernel.rb:180)**
Per MRI, if `to_int` returns a non-Integer (not nil), raise `TypeError` immediately rather than falling through to `to_i`.

**P3.7 — `Kernel#open` `to_path` return validation (kernel.rb:405–409)**
Validate that `to_path` returns a String before using it as a path.

// Frozone C++ backend proof-of-concept: fib benchmark
// Generated from bench/stubs/fib.rb
//
// Demonstrates: no type system friction, no Bool/RubyBool unions,
// no Int32/Int64 ambiguity, no break-from-block issues.
// TI gives us Int64 everywhere — emit raw arithmetic.

#include <cstdio>
#include <cstdint>

// --- Minimal runtime (would be a shared library) ---

class RubyObject {
public:
    virtual ~RubyObject() = default;
    virtual int64_t to_i64() { return 0; }
};

class RubyInteger : public RubyObject {
public:
    int64_t value;
    RubyInteger(int64_t v) : value(v) {}
    int64_t to_i64() override { return value; }
};

// --- TI-specialised fib (raw Int64 — no boxing) ---

static int64_t fib(int64_t n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

// --- Execute phase ---

int main() {
    int64_t total = 0;
    for (int64_t i = 0; i < 3; i++) {
        total = total + fib(35);
    }
    printf("%lld\n", (long long)total);
    return 0;
}

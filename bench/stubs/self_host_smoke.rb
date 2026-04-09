# Self-hosting smoke test — Phase A.
# Just Type for now (no TypeInference — nesting/end issue).

require_relative '../../lib/frozone/compiler/type'

t = Frozone::Compiler::Type.new(:i64)
puts t.kind.to_s
puts t.i64?.to_s
puts t.numeric?.to_s
t2 = Frozone::Compiler::Type.new(:f64)
puts t2.f64?.to_s
puts t2.numeric?.to_s

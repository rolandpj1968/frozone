# Self-hosting smoke test — Phase A.
# Full compiler: Type, TypeInference, Codegen.

require_relative '../../lib/frozone/compiler/codegen'

t = Frozone::Compiler::Type.new(:i64)
puts t.kind.to_s
puts t.i64?.to_s
puts t.numeric?.to_s
t2 = Frozone::Compiler::Type.new(:f64)
puts t2.f64?.to_s
puts t2.to_crystal

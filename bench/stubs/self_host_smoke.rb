# Self-hosting smoke test — Phase A.
#
# Tests compilation of a real compiler class (Frozone::Compiler::Type).
# This exercises:
#   1. Nested namespace emission (Frozone::Compiler::Type)
#   2. Class with constructor, many methods, freeze
#   3. Class-typed nullable ivars (@elem : Type | nil)
#   4. Constants and class methods (Type::I64, Type.new)

require_relative '../../lib/frozone/compiler/type'

t = Frozone::Compiler::Type.new(:i64)
puts t.kind.to_s
puts t.i64?.to_s
puts t.numeric?.to_s
puts t.bottom?.to_s

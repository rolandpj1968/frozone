# Self-hosting smoke test — Phase A, step 1.
#
# Tests:
#   1. Nested namespace modules (Foo::Bar::Baz)
#   2. Class with constructor, ivars, methods
#   3. Class method (self.xxx)
#   4. Constants inside classes
#   5. ::Hash constant path (RootNamespaceNode)

module Outer
  module Inner
    class Greeter
      GREETING = "Hello"

      def initialize(name)
        @name = name
      end

      def greet
        GREETING + ", " + @name.to_s + "!"
      end

      def self.default
        new("world")
      end
    end
  end
end

g = Outer::Inner::Greeter.default
puts g.greet
g2 = Outer::Inner::Greeter.new("Frozone")
puts g2.greet

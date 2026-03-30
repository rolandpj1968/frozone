module Frozone
  module Ast
    class Node
      # All child AST nodes, flattened. Leaf nodes return [].
      # Non-leaf subclasses must override.
      def children = []
    end
  end
end

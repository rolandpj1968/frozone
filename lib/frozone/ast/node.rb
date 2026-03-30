module Frozone
  module Ast
    class Node
      # All child AST nodes, flattened. Subclasses should override for
      # self-compilation; this default uses introspection as a fallback.
      def children
        result = []
        instance_variables.each do |iv|
          val = instance_variable_get(iv)
          case val
          when Node then result << val
          when Array then val.each { |v| result << v if v.is_a?(Node) }
          end
        end
        result
      end
    end
  end
end

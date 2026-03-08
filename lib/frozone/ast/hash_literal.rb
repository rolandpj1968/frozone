require_relative 'node'
require_relative '../vm/hash_object'

module Frozone
  module Ast
    class HashLiteral < Node
      def initialize(kv_nodes)
        @kv_nodes = check_array_of_pairs_of_types("kv_nodes", kv_nodes, Node, Node)
      end

      def to_s = "arr(TODO)"

      def evaluate(context) = Vm::HashObject.new(@kv_nodes.to_h { |k, v| [k.evaluate(context), v.evaluate(context)] })
    end
  end
end

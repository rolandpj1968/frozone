require_relative 'node'
require_relative '../vm/hash_object'

module Frozone
  module Ast
    class HashLiteral < Node
      # kv_nodes: Array of [key_node, val_node] pairs, or [nil, splat_node] for **splat
      def initialize(kv_nodes)
        @kv_nodes = kv_nodes
      end

      def to_s = "hash(TODO)"

      def evaluate(context)
        result = {}
        @kv_nodes.each do |k, v|
          if k.nil?
            # **splat
            splatted = v.evaluate(context)
            splatted.raw.each { |sk, sv| result[sk] = sv }
          else
            result[k.evaluate(context)] = v.evaluate(context)
          end
        end
        Vm::HashObject.new(result)
      end
    end
  end
end

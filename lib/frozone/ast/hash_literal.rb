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
            # nil expands to {} (Ruby 3.4+)
            next if splatted.is_a?(Vm::NilObject)
            # Non-Hash: try to_hash
            unless splatted.is_a?(Vm::HashObject)
              has_to_hash = begin
                splatted.dispatch(context, :respond_to?, [Vm::SymbolObject.from(:to_hash)], {}).truthy?
              rescue
                # BasicObject may not have respond_to? — check directly
                !splatted.lookup_instance_method(:to_hash).nil?
              end
              if has_to_hash
                splatted = splatted.dispatch(context, :to_hash, [], {})
              end
              unless splatted.is_a?(Vm::HashObject)
                raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{splatted.class_object.name} into Hash")
              end
            end
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

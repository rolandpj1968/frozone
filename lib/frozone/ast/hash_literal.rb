require_relative 'node'
require_relative '../vm/hash_object'

module Frozone
  module Ast
    class HashLiteral < Node
      # kv_nodes: Array of [key_node, val_node] pairs, or [nil, splat_node] for **splat
      def initialize(kv_nodes)
        @kv_nodes = kv_nodes
      end

      def children = @kv_nodes.flat_map { |k, v| k.nil? ? [v] : [k, v] }
      def to_s = "hash(TODO)"

      def evaluate(context)
        result = {}
        # Track keys from explicit pairs and literal hash splats (**{...}) for dup-key warnings.
        # Variable splats (**var) do NOT contribute to literal_keys and do NOT trigger warnings.
        literal_keys = {}
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
            # Only warn for duplicate keys from literal hash splats (**{...}), not variable splats (**var)
            literal_splat = v.is_a?(HashLiteral)
            splatted.raw.each do |sk, sv|
              if literal_splat
                warn_if_dup_key(context, literal_keys, sk)
                literal_keys[sk] = true
              end
              result[sk] = sv
            end
          else
            key_val = k.evaluate(context)
            # Freeze String keys (Ruby freezes string keys in hash literals)
            if key_val.is_a?(Vm::StringObject) && !key_val.frozen_object?
              key_val = Vm::StringObject.new(key_val.raw.dup, frozen: true)
            end
            warn_if_dup_key(context, literal_keys, key_val)
            literal_keys[key_val] = true
            result[key_val] = v.evaluate(context)
          end
        end
        Vm::HashObject.new(result)
      end

      private

      def warn_if_dup_key(context, result, new_key)
        return unless dup_key?(result, new_key)

        key_repr = begin
          new_key.dispatch(context, :inspect, [], {}).raw
        rescue StandardError
          new_key.to_s
        end
        Vm::emit_warning(context, "key #{key_repr} is duplicated and overwritten on line #{context.frame.line_number rescue 0}")
      end

      def dup_key?(result, new_key)
        result.any? do |existing_key, _|
          vm_keys_equal?(existing_key, new_key)
        end
      end

      def vm_keys_equal?(a, b)
        return a.equal?(b) if a.is_a?(Vm::SymbolObject) && b.is_a?(Vm::SymbolObject)
        return a.raw == b.raw if a.is_a?(Vm::StringObject) && b.is_a?(Vm::StringObject)
        return a.raw == b.raw if a.is_a?(Vm::IntegerObject) && b.is_a?(Vm::IntegerObject)
        return a.raw == b.raw if a.is_a?(Vm::FloatObject) && b.is_a?(Vm::FloatObject)

        a.equal?(b)
      end
    end
  end
end

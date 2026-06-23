# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Hash
        def hash_size(_, h) = n2f_int(h.size)
        def hash_key(_, h, key, by_id) = n2f_bool(h.key?(key, by_identity: by_id.truthy?))
        def hash_get_default_proc(_, h) = h.default_block || FNIL
        def hash_ruby2_keywords_hash_q(_, h) = n2f_bool(fhash?(h) && h.ruby2_keywords)

        def hash_index_write(_, h, key, value, by_id) = (h.send(:[]=, key, value, by_identity: by_id.truthy?); value)
        def hash_each(context, h, block) = (h.raw_each { |k, v| block.invoke(context, [n2f_arr([k, v])]) }; h)
        def hash_set_identity_mode(_, h, by_id) = (h.set_identity_mode!(by_id.truthy?) if fhash?(h); h)

        # Hash#dup step 2 — give a freshly shallow-dup'd HashObject an
        # independent internal store. HashObject#copy_fields_from
        # pointer-shares @elements per MRI shallow-dup semantics; this
        # in-place dups it so the two HashObjects no longer share kv
        # storage. Mirrors box-first's intrinsic_hash_clone_storage.
        def hash_clone_storage(_, h)
          h.send(:replace_elements_for_copy!, h.send(:elements_for_copy).dup)
          h
        end
        def hash_ruby2_keywords_hash(_, h) = (h.ruby2_keywords = true if fhash?(h); h)

        def hash_index(context, h, key, by_id)
          value = h.send(:[], key, by_identity: by_id.truthy?)
          return value unless value.nil?
          # Key not found — dispatch to VM-level #default to allow subclass overrides
          h.dispatch(context, :default, [key], {})
        end

        def hash_get_default(context, h, key = FNIL)
          if h.default_block
            fnil?(key) ? FNIL : h.default_block.invoke(context, [h, key])
          elsif h.default_value
            h.default_value
          else
            FNIL
          end
        end

        def hash_set_default(_, h, val)
          h.default_block = nil
          h.default_value = fnil?(val) ? nil : val
          val
        end

        def hash_set_default_proc(_, h, prc)
          if fnil?(prc)
            h.default_block = nil
          elsif prc.is_a?(ProcObject)
            h.default_block = prc
            h.default_value = nil
          else
            raise FrozoneException.make(:TypeError, "wrong argument type #{prc.class.name} (expected Proc/nil)")
          end
          prc
        end

        def hash_new(_, default = FNIL, block = FNIL)
          proc_obj = if block.is_a?(ProcObject)
                       block
                     elsif block.is_a?(BlockObject)
                       ProcObject.new(block)
                     elsif !fnil?(block)
                       ProcObject.new(block)
                     end
          if proc_obj
            n2f_hash({}, default_block: proc_obj)
          elsif default && !fnil?(default)
            n2f_hash({}, default_value: default)
          else
            n2f_hash({})
          end
        end

        def hash_delete(_, h, key, by_id)
          val = h.delete(key, by_identity: by_id.truthy?)
          val.nil? ? FNIL : val
        end

        def hash_clear(_, h)
          h.clear_elements if fhash?(h)
          h
        end

        def hash_transform_keys_bang(context, h, hash_arg, block_arg)
          original_pairs = h.raw_each.to_a
          by_id = h.compare_by_identity?
          new_pairs = []
          processed = 0
          begin
            original_pairs.each do |k, v|
              nk = if hash_arg && !fnil?(hash_arg) && hash_arg.key?(k)
                     hash_arg[k]
                   elsif block_arg && !fnil?(block_arg)
                     block_arg.invoke(context, [k])
                   else
                     k
                   end
              new_pairs << [nk, v]
              processed += 1
            end
          rescue Ast::BreakException
            # break occurred mid-iteration: remaining pairs stay with original keys
          end
          h.clear_elements
          original_pairs[processed..].each { |k, v| h.send(:[]=, k, v, by_identity: by_id) }
          new_pairs.each { |k, v| h[k] = v }
          h
        end
      end
    end
  end
end

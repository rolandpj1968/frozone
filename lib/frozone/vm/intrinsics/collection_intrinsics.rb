# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Array
        ARRAY_MAX_SIZE = 1_073_741_823  # 2**30 - 1; prevents allocation hangs for huge sizes

        def array_initialize(context, arr, size_or_array = nil, fill = nil, block = nil)
          size_or_array = nil if size_or_array.nil? || size_or_array.is_a?(NilObject)
          fill = nil if fill.nil? || fill.is_a?(NilObject)
          block = nil if block.nil? || block.is_a?(NilObject)
          arr.raw.clear
          if size_or_array.is_a?(ArrayObject)
            arr.raw.replace(size_or_array.raw.dup)
          elsif size_or_array.is_a?(IntegerObject)
            n = size_or_array.raw
            raise FrozoneException.make(:ArgumentError, "negative array size") if n < 0
            raise FrozoneException.make(:ArgumentError, "array size too big") if n > ARRAY_MAX_SIZE
            if block
              n.times { |i| arr.push(block.invoke(context, [IntegerObject.new(i)])) }
            else
              arr.raw.replace(Array.new(n, fill || NilObject::NIL))
            end
          end
          arr
        end

        def array_new(context, klass, size_or_array = nil, fill = nil, block = nil)
          size_or_array = nil if size_or_array.is_a?(NilObject)
          fill = nil if fill.is_a?(NilObject)
          block = nil if block.is_a?(NilObject)
          # Use the calling class (for Array subclasses); default to ARRAY_CLASS
          cls = klass.is_a?(ClassObject) ? klass : nil
          if size_or_array.is_a?(ArrayObject)
            # Array.new(arr) — copy
            ArrayObject.new(size_or_array.raw.dup, cls)
          elsif size_or_array.is_a?(IntegerObject)
            n = size_or_array.raw
            raise FrozoneException.make(:ArgumentError, "negative array size") if n < 0
            raise FrozoneException.make(:ArgumentError, "array size too big") if n > ARRAY_MAX_SIZE
            if block
              elements = (0...n).map { |i| block.invoke(context, [IntegerObject.new(i)]) }
              ArrayObject.new(elements, cls)
            else
              elements = Array.new(n, fill || NilObject::NIL)
              ArrayObject.new(elements, cls)
            end
          else
            ArrayObject.new([], cls)
          end
        end

        def array_at(_, v, i)
          element = v[i.raw]
          element.nil? ? NilObject::NIL : element
        end


        def array_index_write(_, v, i, val)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          if i.is_a?(IntegerObject)
            v.raw[i.raw] = val
          elsif i.is_a?(RangeObject)
            replacement = val.is_a?(ArrayObject) ? val.raw : [val]
            v.raw[i.raw] = replacement
          else
            raise "Array#[]= index must be an Integer or Range"
          end
          val
        end

        def array_slice_write(_, v, start, length, val)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          raise "Array#[]= start must be an Integer" unless start.is_a?(IntegerObject)
          raise "Array#[]= length must be an Integer" unless length.is_a?(IntegerObject)
          replacement = val.is_a?(ArrayObject) ? val.raw : [val]
          v.raw[start.raw, length.raw] = replacement
          val
        end

        def array_push(_, v, val)
          v.push(val)
          v
        end

        def array_length(_, v) = IntegerObject.new(v.length)

        ARRAY_TO_S_GUARD = :__array_inspect_guard__
        def array_to_s(context, v)
          seen = (Thread.current[ARRAY_TO_S_GUARD] ||= {})
          return StringObject.new("[...]") if seen.key?(v.object_id)
          return StringObject.new("[]".encode("US-ASCII")) if v.raw.empty?
          seen[v.object_id] = true
          begin
            inner = v.raw.map do |e|
              r = e.dispatch(context, :inspect, [], {})
              r = r.dispatch(context, :to_s, [], {}) unless r.is_a?(StringObject)
              if r.is_a?(StringObject)
                r.raw
              else
                # inspect and to_s both failed to return a String — use default format
                cls_name = e.class_object&.name || :Object
                "#<#{cls_name}:0x#{e.__id__.to_s(16).rjust(16, '0')}>"
              end
            end.join(", ")
            StringObject.new("[#{inner}]")
          ensure
            seen.delete(v.object_id)
          end
        end

        def array_flatten(context, arr, depth)
          d = if depth.nil? || depth.is_a?(NilObject)
            nil
          elsif depth.is_a?(IntegerObject)
            n = depth.raw
            n < 0 ? nil : n  # negative means flatten all levels
          elsif depth.respond_to?(:dispatch)
            converted = begin
              depth.dispatch(context, :to_int, [], {})
            rescue
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{depth.class_object.name} into Integer")
            end
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{depth.class_object.name} into Integer") unless converted.is_a?(IntegerObject)
            n = converted.raw
            n < 0 ? nil : n
          else
            raise FrozoneException.make(:TypeError, "no implicit conversion into Integer")
          end
          result = []
          _array_flatten_into(context, arr, d, result, {})
          ArrayObject.new(result)
        end

        def _array_flatten_into(context, arr, depth, result, seen)
          raise FrozoneException.make(:ArgumentError, "flatten: cannot flatten recursive array") if seen[arr.object_id]
          seen[arr.object_id] = true
          arr.raw.each do |elem|
            if elem.is_a?(ArrayObject) && (depth.nil? || depth > 0)
              _array_flatten_into(context, elem, depth.nil? ? nil : depth - 1, result, seen)
            elsif (depth.nil? || depth > 0) && !elem.is_a?(NilObject) && elem.respond_to?(:dispatch)
              converted = _array_flatten_coerce(context, elem)
              if converted
                _array_flatten_into(context, converted, depth.nil? ? nil : depth - 1, result, seen)
              else
                result << elem
              end
            else
              result << elem
            end
          end
          seen.delete(arr.object_id)
        end

        def _array_flatten_coerce(context, elem)
          # MRI's flatten coercion logic:
          # - If respond_to? is overridden (on eigenclass, or non-Object/Kernel class): gate via it
          # - If respond_to_missing? is overridden (not the BasicObject default): gate via respond_to?
          # - Otherwise: call to_ary directly so method_missing can intercept it
          # When gating, let NoMethodError from to_ary propagate (respond_to? said it exists).
          #
          # respond_to? check: use eigenclass_method first (singleton overrides may have lexical
          # scope = Object when defined at top level, making scope inspection unreliable for them).
          rto_overridden = !elem.eigenclass_method(:respond_to?).nil? || begin
            rto = elem.lookup_instance_method(:respond_to?)
            rto && rto.scopes.none? { |s| s.respond_to?(:name) && [:Object, :Kernel, :BasicObject].include?(s.name) }
          end

          # respond_to_missing? check: scope inspection works because top-level scope is :Object,
          # which differs from the BasicObject default (scope :BasicObject).
          rtm = elem.lookup_instance_method(:respond_to_missing?)
          rtm_overridden = rtm && rtm.scopes.none? { |s| s.respond_to?(:name) && s.name == :BasicObject }

          r = if rto_overridden || rtm_overridden
            has_to_ary = begin
              resp = elem.dispatch(context, :respond_to?, [SymbolObject.from(:to_ary), TrueObject::TRUE], {})
              resp.truthy?
            rescue FrozoneException
              false
            end
            return nil unless has_to_ary
            # respond_to? says true → call to_ary; NoMethodError propagates (MRI behaviour)
            elem.dispatch(context, :to_ary, [], {})
          else
            # No custom respond_to? or respond_to_missing?: call to_ary directly (via method_missing)
            begin
              elem.dispatch(context, :to_ary, [], {})
            rescue FrozoneException => e
              raise unless e.vm_object.is_a?(ObjectObject) && e.vm_object.class_object&.name == :NoMethodError
              return nil
            end
          end

          if r.is_a?(ArrayObject)
            r
          elsif r.is_a?(NilObject) || r.nil?
            nil
          else
            raise FrozoneException.make(:TypeError, "can't convert #{elem.class_object.name} into Array (#{elem.class_object.name}#to_ary gives #{r.class_object.name})")
          end
        end

        ARRAY_CMP_GUARD = :__array_cmp_guard__
        def array_cmp(context, v, other)
          unless other.is_a?(ArrayObject)
            return NilObject::NIL unless other.respond_to?(:dispatch)
            converted = begin
              other.dispatch(context, :to_ary, [], {})
            rescue
              return NilObject::NIL
            end
            return NilObject::NIL unless converted.is_a?(ArrayObject)
            other = converted
          end
          seen = (Thread.current[ARRAY_CMP_GUARD] ||= {})
          key = [v.object_id, other.object_id]
          return IntegerObject.new(0) if seen[key]
          seen[key] = true
          begin
            i = 0
            while i < v.length && i < other.length
              c = v[i].dispatch(context, :<=>, [other[i]], {})
              return NilObject::NIL if c.nil? || c.is_a?(NilObject)
              return c if c.raw != 0
              i += 1
            end
            IntegerObject.new(v.length <=> other.length)
          ensure
            seen.delete(key)
          end
        end

        def array_sort(context, v)
          ArrayObject.new(v.raw.sort do |a, b|
            result = begin
              a.dispatch(context, :<=>, [b], {})
            rescue => _e
              raise FrozoneException.make(:ArgumentError, "comparison failed")
            end
            raise FrozoneException.make(:ArgumentError, "comparison failed") if result.nil? || result.is_a?(NilObject)
            result.raw
          end)
        end

        def array_map_with_block(context, arr, block)
          result = []
          i = 0
          while i < arr.length
            begin
              result << block.invoke(context, [arr[i]])
            rescue Ast::BreakException => e
              return e.value
            end
            i += 1
          end
          ArrayObject.new(result)
        end

        def array_map_bang_with_block(context, arr, block)
          i = 0
          while i < arr.length
            begin
              arr[i] = block.invoke(context, [arr[i]])
            rescue Ast::BreakException => e
              return e.value
            end
            i += 1
          end
          arr
        end

        def array_sort_block(context, v, block)
          ArrayObject.new(v.raw.sort do |a, b|
            result = block.invoke(context, [a, b])
            if result.is_a?(IntegerObject)
              result.raw
            elsif result.is_a?(NilObject)
              raise FrozoneException.make(:ArgumentError, "comparison failed")
            else
              cmp = result.dispatch(context, :<=>, [IntegerObject.new(0)], {})
              raise FrozoneException.make(:ArgumentError, "comparison failed") if cmp.is_a?(NilObject) || cmp.nil?
              cmp.raw
            end
          end)
        end

        def array_sort_by(context, v, block)
          pairs = v.raw.map { |e| [block.invoke(context, [e]), e] }
          sorted = pairs.sort { |a, b|
            result = a[0].dispatch(context, :<=>, [b[0]], {})
            (result.nil? || result.is_a?(NilObject)) ? 0 : result.raw
          }
          ArrayObject.new(sorted.map { |_, e| e })
        end

        def array_reverse(_, v) = ArrayObject.new(v.raw.reverse)

        def array_pop(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          val = v.raw.pop
          val.nil? ? NilObject::NIL : val
        end

        def array_shift(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          val = v.raw.shift
          val.nil? ? NilObject::NIL : val
        end

        def array_unshift(_, v, *elems)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          v.raw.unshift(*elems)
          v
        end

        def array_concat(_, v1, v2)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v1) if v1.frozen_object?
          elems = v1.equal?(v2) ? v2.raw.dup : v2.raw
          elems.each { |e| v1.raw << e }
          v1
        end

        def array_replace(_, v, other)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          v.raw.replace(other.raw)
          v
        end

        def array_pack(_, v, fmt_obj)
          fmt = fmt_obj.raw.to_s
          ints = v.raw.map { |e| e.is_a?(IntegerObject) ? e.raw : e.raw.to_i }
          StringObject.new(ints.pack(fmt))
        end

        def array_dup(_, v) = ArrayObject.new(v.raw.dup, v.class_object)

        def array_clone(_, v, freeze_opt = NilObject::NIL, klass = nil)
          cls = klass.is_a?(ClassObject) ? klass : nil
          cloned = ArrayObject.new(v.raw.dup, cls)
          # Copy singleton class (eigenclass) including its methods
          if v.eigenclass
            new_sc = ClassObject.clone_singleton(v.eigenclass, cloned)
            cloned.copy_fields_from(cloned, eigenclass: new_sc, frozen: freeze_opt.truthy?)
          elsif freeze_opt.truthy?
            cloned.freeze_object!
          end
          cloned
        end

        def array_sample(_, v) = v.raw.empty? ? NilObject::NIL : v.raw.sample

        def array_sample_n(_, v, n)
          ArrayObject.new(v.raw.sample(n.raw))
        end

        def array_shuffle(_, v) = ArrayObject.new(v.raw.shuffle)

        def array_combination(context, v, n, block = nil)
          combos = v.raw.combination(n.raw).map { |c| ArrayObject.new(c) }
          return ArrayObject.new(combos) if block.nil? || block.is_a?(NilObject)
          combos.each { |c| block.invoke(context, [c]) }
          v
        end

        def array_permutation(context, v, n = nil, block = nil)
          n = n.nil? || n.is_a?(NilObject) ? v.raw.length : n.raw
          perms = v.raw.permutation(n).map { |p| ArrayObject.new(p) }
          return ArrayObject.new(perms) if block.nil? || block.is_a?(NilObject)
          perms.each { |p| block.invoke(context, [p]) }
          v
        end

        def array_repeated_combination(context, v, n, block = nil)
          n_raw = n.is_a?(IntegerObject) ? n.raw : 0
          return v if n_raw < 0
          combos = v.raw.repeated_combination(n_raw).map { |c| ArrayObject.new(c) }
          return ArrayObject.new(combos) if block.nil? || block.is_a?(NilObject)
          combos.each { |c| block.invoke(context, [c]) }
          v
        end

        def array_repeated_permutation(context, v, n, block = nil)
          n_raw = n.is_a?(IntegerObject) ? n.raw : 0
          return v if n_raw < 0
          perms = v.raw.repeated_permutation(n_raw).map { |p| ArrayObject.new(p) }
          return ArrayObject.new(perms) if block.nil? || block.is_a?(NilObject)
          perms.each { |p| block.invoke(context, [p]) }
          v
        end

        # Range
        def range_new(_, b, e, excl = nil)
          excl = excl.nil? || excl.is_a?(NilObject) ? false : excl.truthy?
          e = NilObject::NIL if e.nil?
          RangeObject.new(b, e, excl)
        end

        def range_allocate(_, _klass)
          RangeObject.new(NilObject::NIL, NilObject::NIL, false, initialized: false)
        end

        def range_initialized_q(_, range)
          bool_object_for(range.is_a?(RangeObject) && range.initialized?)
        end

        def range_set(_, range, b, e, excl)
          excl = excl.nil? || excl.is_a?(NilObject) ? false : excl.truthy?
          e = NilObject::NIL if e.nil?
          range.set_range(b, e, excl)
          range
        end

        def range_begin(_, range) = range.begin_val
        def range_end(_, range)   = range.end_val
        def range_exclude_end(_, range) = bool_object_for(range.exclusive?)

        # Hash
        def hash_index_write(_, h, key, value)
          h[key] = value
          value
        end

        def hash_size(_, h) = IntegerObject.new(h.size)

        def hash_key(_, h, key) = bool_object_for(h.key?(key))

        # Raw key lookup — returns nil (Ruby nil) if not found (no default applied).
        def hash_raw_get(_, h, key)
          h.is_a?(HashObject) ? h[key] : nil
        end

        def hash_index(context, h, key)
          value = h[key]
          return value unless value.nil?
          # Key not found — dispatch to VM-level #default to allow subclass overrides
          h.dispatch(context, :default, [key], {})
        end

        def hash_get_default(context, h, key = nil)
          if h.default_block
            key.nil? || key.is_a?(NilObject) ? NilObject::NIL : h.default_block.invoke(context, [h, key])
          elsif h.default_value
            h.default_value
          else
            NilObject::NIL
          end
        end

        def hash_set_default(_, h, val)
          h.default_block = nil
          h.default_value = val.is_a?(NilObject) ? nil : val
          val
        end


        def hash_get_default_proc(_, h)
          h.default_block || NilObject::NIL
        end

        def hash_set_default_proc(_, h, prc)
          if prc.is_a?(NilObject)
            h.default_block = nil
          elsif prc.is_a?(ProcObject)
            h.default_block = prc
            h.default_value = nil
          else
            raise FrozoneException.make(:TypeError, "wrong argument type #{prc.class.name} (expected Proc/nil)")
          end
          prc
        end

        def hash_new(_, default = nil, block = nil)
          proc_obj = if block.is_a?(ProcObject)
            block
          elsif block.is_a?(BlockObject)
            ProcObject.new(block)
          elsif block && !block.is_a?(NilObject)
            ProcObject.new(block)
          end
          if proc_obj
            HashObject.new({}, default_block: proc_obj)
          elsif default && !default.is_a?(NilObject)
            HashObject.new({}, default_value: default)
          else
            HashObject.new({})
          end
        end

        def hash_each(context, h, block)
          h.raw.each { |k, v| block.invoke(context, [ArrayObject.new([k, v])]) }
          h
        end

        def hash_delete(_, h, key)
          val = h[key]
          h.delete(key)
          val.nil? ? NilObject::NIL : val
        end

        def hash_clear(_, h)
          h.clear_elements if h.is_a?(HashObject)
          h
        end

        def hash_transform_keys_bang(context, h, hash_arg, block_arg)
          original_pairs = h.raw.to_a
          new_pairs = []
          processed = 0
          begin
            original_pairs.each do |k, v|
              nk = if hash_arg && !hash_arg.is_a?(NilObject) && hash_arg.key?(k)
                hash_arg[k]
              elsif block_arg && !block_arg.is_a?(NilObject)
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
          original_pairs[processed..].each { |k, v| h[k] = v }
          new_pairs.each { |k, v| h[k] = v }
          h
        end

        def hash_compare_by_identity(_, h)
          h.compare_by_identity! if h.is_a?(HashObject)
          h
        end

        def hash_reset_compare_by_identity(_, h)
          h.reset_compare_by_identity! if h.is_a?(HashObject)
          h
        end

        def hash_compare_by_identity_q(_, h)
          bool_object_for(h.is_a?(HashObject) && h.compare_by_identity_flag)
        end

        def hash_ruby2_keywords_hash(_, h)
          h.ruby2_keywords = true if h.is_a?(HashObject)
          h
        end

        def hash_ruby2_keywords_hash_q(_, h)
          bool_object_for(h.is_a?(HashObject) && h.ruby2_keywords)
        end
      end
    end
  end
end

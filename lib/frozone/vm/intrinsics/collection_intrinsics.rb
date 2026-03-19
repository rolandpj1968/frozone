# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Array
        ARRAY_MAX_SIZE = 1_073_741_823  # 2**30 - 1; prevents allocation hangs for huge sizes

        def array_initialize(context, arr, size_or_array = NilObject::NIL, fill = NilObject::NIL, block = NilObject::NIL)
          size_or_array = nil if size_or_array.is_a?(NilObject)
          fill = nil if fill.is_a?(NilObject)
          block = nil if block.is_a?(NilObject)
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

        # Return the Frozone default_external encoding name (raw Ruby String), or 'UTF-8'.
        def array_inspect_default_external_name
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          return 'UTF-8' unless enc_class

          ext = enc_class.get_ivar(:@default_external)
          return 'UTF-8' unless ext&.is_a?(ObjectObject)

          ext.get_ivar(:@name)&.raw || 'UTF-8'
        rescue
          'UTF-8'
        end

        # Determine the result encoding for Array#inspect/to_s, matching MRI:
        # - If Encoding.default_external is ASCII-compatible, use it.
        # - Otherwise, use US-ASCII.
        def array_inspect_result_encoding
          ext_name = array_inspect_default_external_name
          enc = ::Encoding.find(ext_name) rescue ::Encoding::UTF_8
          enc.ascii_compatible? ? enc : ::Encoding::US_ASCII
        rescue
          ::Encoding::US_ASCII
        end

        # Convert a raw Ruby String from an element's inspect result to be
        # ASCII-8BIT-joinable. If the string is not ASCII-compatible, encode it
        # to US-ASCII using unicode escapes (matching MRI behavior).
        def array_inspect_normalize_str(s)
          return s if s.encoding.ascii_compatible?

          # Non-ASCII-compatible encoding (UTF-16BE, UTF-32, etc.):
          # encode to US-ASCII with \uXXXX fallback, matching MRI output.
          s.encode('US-ASCII', fallback: ->(c) { "\\u%04X" % c.ord })
        rescue
          s.force_encoding('ASCII-8BIT')
        end

        ARRAY_TO_S_GUARD = :__array_inspect_guard__

        def array_to_s(context, v)
          seen = (Thread.current[ARRAY_TO_S_GUARD] ||= {})
          return StringObject.new("[...]") if seen.key?(v.object_id)
          return StringObject.new("[]".encode("US-ASCII")) if v.raw.empty?

          seen[v.object_id] = true
          begin
            result_enc = array_inspect_result_encoding
            inner_parts = v.raw.map do |e|
              r = e.dispatch(context, :inspect, [], {})
              r = r.dispatch(context, :to_s, [], {}) unless r.is_a?(StringObject)
              if r.is_a?(StringObject)
                array_inspect_normalize_str(r.raw)
              else
                # inspect and to_s both failed to return a String — use default format
                cls_name = e.class_object&.name || :Object
                "#<#{cls_name}:0x#{e.__id__.to_s(16).rjust(16, '0')}>"
              end
            end
            inner = inner_parts.join(", ")
            result = "[#{inner}]"
            result = result.encode(result_enc) if result.encoding != result_enc && result.encoding.ascii_compatible?
            StringObject.new(result)
          ensure
            seen.delete(v.object_id)
          end
        end

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

        # Proxy wrapping a Frozone ObjectObject so MRI's Array#pack can call
        # to_str / to_s / to_int / to_f on it via Frozone dispatch.
        class PackProxy
          attr_reader :frozone_obj

          def initialize(frozone_obj, context)
            @obj = frozone_obj
            @ctx = context
          end

          def frozone_class_name = @obj.class_object&.name.to_s

          def to_str
            result = @obj.dispatch(@ctx, :to_str, [], {})
            return result.raw if result.is_a?(StringObject)

            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into String"
          rescue FrozoneException
            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into String"
          end

          def to_s
            result = @obj.dispatch(@ctx, :to_s, [], {})
            return result.raw if result.is_a?(StringObject)

            frozone_class_name
          rescue FrozoneException
            frozone_class_name
          end

          def to_int
            result = @obj.dispatch(@ctx, :to_int, [], {})
            return result.raw if result.is_a?(IntegerObject)

            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into Integer"
          rescue FrozoneException
            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into Integer"
          end

          def to_f
            result = @obj.dispatch(@ctx, :to_f, [], {})
            return result.raw if result.is_a?(FloatObject)

            raise ::TypeError, "can't convert #{frozone_class_name} into Float"
          rescue FrozoneException
            raise ::TypeError, "can't convert #{frozone_class_name} into Float"
          end
        end

        def pack_coerce_fmt(context, fmt_obj)
          case fmt_obj
          when StringObject then return fmt_obj.raw
          when NilObject
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          end
          begin
            result = fmt_obj.dispatch(context, :to_str, [], {}, nil, public_only: true)
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{fmt_obj.class_object&.name} into String") unless result.is_a?(StringObject)

            result.raw
          rescue FrozoneException => e
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{fmt_obj.class_object&.name} into String") if e.frozone_class_name.to_s =~ /NoMethod/

            raise
          end
        end

        def pack_frozone_to_ruby(elem, context)
          case elem
          when StringObject, IntegerObject, FloatObject, SymbolObject, NilObject, ArrayObject
            elem.raw
          else
            PackProxy.new(elem, context)
          end
        end

        # For float directives: pre-coerce Frozone Numeric subclasses to Ruby Float.
        # Non-Numeric objects stay as PackProxy so MRI raises proper TypeError.
        def pack_frozone_to_float(elem, context)
          return elem.raw if elem.is_a?(FloatObject)
          return elem.raw.to_f if elem.is_a?(IntegerObject)
          raise FrozoneException.make(:TypeError, "can't convert nil into Float") if elem.is_a?(NilObject)

          # Check if Frozone object is a Numeric subclass (e.g. Rational)
          c = elem.class_object
          while c
            return begin
              result = elem.dispatch(context, :to_f, [], {})
              result.is_a?(FloatObject) ? result.raw : PackProxy.new(elem, context)
            rescue FrozoneException
              class_name = elem.class_object&.name.to_s
              raise FrozoneException.make(:TypeError, "can't convert #{class_name} into Float")
            end if c.equal?(Core::NUMERIC_CLASS)

            c = c.is_a?(ClassObject) ? c.superclass : nil
          end
          PackProxy.new(elem, context)
        end

        # Float pack directives: these require Numeric coercion via to_f.
        PACK_FLOAT_DIRECTIVES = /\A[dDfFeEgG]\z/

        # Scan a pack format string and yield [directive_char, count_or_nil] pairs.
        # count_or_nil is nil for '*', an Integer for explicit count, or 1 if no count.
        # Directives that consume no array elements (x, X, @, %) are skipped.
        def pack_scan_format(fmt)
          return to_enum(:pack_scan_format, fmt) unless block_given?

          i = 0
          while i < fmt.length
            c = fmt[i]
            i += 1
            # Skip comments
            if c == '#'
              i += 1 while i < fmt.length && fmt[i] != "\n"
              next
            end
            # Skip whitespace
            next if c == ' ' || c == "\t" || c == "\n" || c == "\r" || c == "\0"
            # Directives that consume no array elements
            next if c == 'x' || c == 'X' || c == '@' || c == '%'
            # Parse optional count
            if i < fmt.length && fmt[i] == '*'
              count = :star
              i += 1
            elsif i < fmt.length && fmt[i] =~ /\d/
              j = i
              j += 1 while j < fmt.length && fmt[j] =~ /\d/
              count = fmt[i...j].to_i
              i = j
            else
              count = 1
            end
            yield c, count
          end
        end

        # Build coercion list for pack: returns array of :float or :other symbols,
        # one per array element consumed by the format.
        def pack_coercion_types(fmt, n_elements)
          types = []
          pack_scan_format(fmt) do |dir, count|
            # Directives that consume multiple elements per count
            if count == :star
              need = n_elements - types.length
              need.times { types << (dir =~ PACK_FLOAT_DIRECTIVES ? :float : :other) }
            else
              count.times { types << (dir =~ PACK_FLOAT_DIRECTIVES ? :float : :other) }
            end
            break if types.length >= n_elements
          end
          types
        end

        def array_pack(context, v, fmt_obj, buffer_obj = NilObject::NIL)
          fmt = pack_coerce_fmt(context, fmt_obj)
          elements = v.raw

          # Validate buffer if provided
          buf_str = nil
          if buffer_obj && !buffer_obj.is_a?(NilObject)
            unless buffer_obj.is_a?(StringObject)
              class_name = buffer_obj.class_object&.name.to_s
              raise FrozoneException.make(:TypeError, "buffer must be String, not #{class_name}")
            end
            raise FrozoneException.make(:FrozenError, "can't modify frozen String", receiver: buffer_obj) if buffer_obj.frozen_object?

            buf_str = buffer_obj.raw
          end

          # Determine coercion type per element (float vs other).
          coercion_types = pack_coercion_types(fmt, elements.length)

          # Coerce each element appropriately.
          pack_args = elements.each_with_index.map do |elem, i|
            if coercion_types[i] == :float
              pack_frozone_to_float(elem, context)
            else
              pack_frozone_to_ruby(elem, context)
            end
          end

          begin
            if buf_str
              # Use MRI's native :buffer option to get correct @-offset behavior
              pack_args.pack(fmt, buffer: buf_str)
              buffer_obj.raw = buf_str
              buffer_obj
            else
              StringObject.new(pack_args.pack(fmt))
            end
          rescue ::TypeError => e
            msg = e.message
            # Fix anonymous PackProxy class name in MRI error messages
            if msg =~ /PackProxy/
              proxy = pack_args.find { |a| a.is_a?(PackProxy) }
              msg = msg.sub(/#<[^>]+>::PackProxy|PackProxy/, proxy ? proxy.frozone_class_name : "Object") if proxy
            end
            raise FrozoneException.make(:TypeError, msg)
          rescue ::ArgumentError => e then raise FrozoneException.make(:ArgumentError, e.message)
          rescue ::RangeError => e then raise FrozoneException.make(:RangeError, e.message)
          end
        end

        def array_dup(_, v) = ArrayObject.new(v.raw.dup, v.class_object)

        def array_clone(_, v, freeze_opt = NilObject::NIL, klass = NilObject::NIL)
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

        def array_sample_n(_, v, n) = ArrayObject.new(v.raw.sample(n.raw))

        # Range
        def range_allocate(_, _klass)
          RangeObject.new(NilObject::NIL, NilObject::NIL, false, initialized: false)
        end

        def range_initialized_q(_, range)
          bool_object_for(range.is_a?(RangeObject) && range.initialized?)
        end

        def range_set(_, range, b, e, excl)
          excl = excl.is_a?(NilObject) ? false : excl.truthy?
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

        def hash_index(context, h, key)
          value = h[key]
          return value unless value.nil?
          # Key not found — dispatch to VM-level #default to allow subclass overrides
          h.dispatch(context, :default, [key], {})
        end

        def hash_get_default(context, h, key = NilObject::NIL)
          if h.default_block
            key.is_a?(NilObject) ? NilObject::NIL : h.default_block.invoke(context, [h, key])
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

        def hash_new(_, default = NilObject::NIL, block = NilObject::NIL)
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

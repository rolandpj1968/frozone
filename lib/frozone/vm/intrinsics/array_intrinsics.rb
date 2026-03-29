# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Array
        def array_length(_, v) = n2f_int(v.length)
        def array_dup(_, v) = n2f_arr(v.raw.dup, v.class_object)
        def array_sample(_, v) = v.raw.empty? ? FNIL : v.raw.sample
        def array_sample_n(_, v, n) = n2f_arr(v.raw.sample(n.raw))
        def array_at(_, v, i) = (e = v[i.raw]; e.nil? ? FNIL : e)
        def array_push(_, v, val) = (v.push(val); v)

        ARRAY_MAX_SIZE = MRI_MAX_SIZE

        def array_initialize(context, arr, size_or_array = FNIL, fill = FNIL, block = FNIL)
          size_or_array = nil if fnil?(size_or_array)
          fill = nil if fnil?(fill)
          block = nil if fnil?(block)
          arr.raw.clear
          if farray?(size_or_array)
            arr.raw.replace(size_or_array.raw.dup)
          elsif fint?(size_or_array)
            n = size_or_array.raw
            raise FrozoneException.make(:ArgumentError, "negative array size") if n < 0
            raise FrozoneException.make(:ArgumentError, "array size too big") if n > ARRAY_MAX_SIZE
            if block
              n.times { |i| arr.push(block.invoke(context, [n2f_int(i)])) }
            else
              arr.raw.replace(Array.new(n, fill || FNIL))
            end
          end
          arr
        end

        def array_index_write(_, v, i, val)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          if fint?(i)
            v.raw[i.raw] = val
          elsif i.is_a?(RangeObject)
            replacement = farray?(val) ? val.raw : [val]
            v.raw[i.raw] = replacement
          else
            raise "Array#[]= index must be an Integer or Range"
          end
          val
        end

        def array_slice_write(_, v, start, length, val)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          raise "Array#[]= start must be an Integer" unless fint?(start)
          raise "Array#[]= length must be an Integer" unless fint?(length)
          replacement = farray?(val) ? val.raw : [val]
          v.raw[start.raw, length.raw] = replacement
          val
        end

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
          return n2f_str("[...]") if seen.key?(v.object_id)
          return n2f_str("[]".encode("US-ASCII")) if v.raw.empty?

          seen[v.object_id] = true
          begin
            result_enc = array_inspect_result_encoding
            inner_parts = v.raw.map do |e|
              r = e.dispatch(context, :inspect, [], {})
              r = r.dispatch(context, :to_s, [], {}) unless fstr?(r)
              if fstr?(r)
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
            n2f_str(result)
          ensure
            seen.delete(v.object_id)
          end
        end

        def array_pop(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          val = v.raw.pop
          val.nil? ? FNIL : val
        end

        def array_shift(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen Array", receiver: v) if v.frozen_object?
          val = v.raw.shift
          val.nil? ? FNIL : val
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
            return result.raw if Intrinsics.fstr?(result)

            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into String"
          rescue FrozoneException
            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into String"
          end

          def to_s
            result = @obj.dispatch(@ctx, :to_s, [], {})
            return result.raw if Intrinsics.fstr?(result)

            frozone_class_name
          rescue FrozoneException
            frozone_class_name
          end

          def to_int
            result = @obj.dispatch(@ctx, :to_int, [], {})
            return result.raw if Intrinsics.fint?(result)

            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into Integer"
          rescue FrozoneException
            raise ::TypeError, "no implicit conversion of #{frozone_class_name} into Integer"
          end

          def to_f
            result = @obj.dispatch(@ctx, :to_f, [], {})
            return result.raw if Intrinsics.ffloat?(result)

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
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{fmt_obj.class_object&.name} into String") unless fstr?(result)

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
          return elem.raw if ffloat?(elem)
          return elem.raw.to_f if fint?(elem)
          raise FrozoneException.make(:TypeError, "can't convert nil into Float") if fnil?(elem)

          # Check if Frozone object is a Numeric subclass (e.g. Rational)
          c = elem.class_object
          while c
            return begin
              result = elem.dispatch(context, :to_f, [], {})
              ffloat?(result) ? result.raw : PackProxy.new(elem, context)
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

        def array_pack(context, v, fmt_obj, buffer_obj = FNIL)
          fmt = pack_coerce_fmt(context, fmt_obj)
          elements = v.raw

          # Validate buffer if provided
          buf_str = nil
          if buffer_obj && !fnil?(buffer_obj)
            unless fstr?(buffer_obj)
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
              n2f_str(pack_args.pack(fmt))
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

        def array_clone(_, v, freeze_opt = FNIL, klass = FNIL)
          cls = klass.is_a?(ClassObject) ? klass : nil
          cloned = n2f_arr(v.raw.dup, cls)
          # freeze: nil → preserve original's frozen state; true/false → explicit
          should_freeze = fnil?(freeze_opt) ? v.frozen_object? : !ffalse?(freeze_opt)
          if v.eigenclass
            new_sc = ClassObject.clone_singleton(v.eigenclass, cloned)
            cloned.copy_fields_from(cloned, eigenclass: new_sc, frozen: should_freeze)
          elsif should_freeze
            cloned.freeze_object!
          end
          cloned
        end
      end
    end
  end
end

# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # String
        def string_plus(_, v1, v2)
          raise TypeError, "no implicit conversion of #{v2.class_object&.name || v2.class.name} into String" unless v2.is_a?(StringObject)
          StringObject.new(v1.raw + v2.raw)
        end

        def string_length(_, v) = IntegerObject.new(v.raw.length)
        def string_bytesize(_, v) = IntegerObject.new(v.raw.bytesize)
        def string_to_s(_, v) = v
        def string_to_i(_, v) = IntegerObject.new(v.raw.to_i)
        def string_inspect(_, v) = StringObject.new(v.raw.inspect)

        def string_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(StringObject)
          IntegerObject.new(v1.raw <=> v2.raw)
        end

        def string_hash(_, v) = IntegerObject.new(v.raw.hash)

        def string_eql(_, v1, v2) = bool_object_for(v2.is_a?(StringObject) && v1.raw == v2.raw)

        def string_start_with(_, v, *args) = bool_object_for(v.raw.start_with?(*args.map(&:raw)))
        def string_end_with(_, v, *args)   = bool_object_for(v.raw.end_with?(*args.map(&:raw)))
        def string_include(_, v, s)        = bool_object_for(v.raw.include?(s.raw))
        def string_empty(_, v)             = bool_object_for(v.raw.empty?)
        def string_strip(_, v)             = StringObject.new(v.raw.strip)
        def string_lstrip(_, v)            = StringObject.new(v.raw.lstrip)
        def string_rstrip(_, v)            = StringObject.new(v.raw.rstrip)

        def string_chomp(_, v, sep = nil)
          sep.nil? || sep.is_a?(NilObject) ? StringObject.new(v.raw.chomp) : StringObject.new(v.raw.chomp(sep.raw))
        end

        def string_chop(_, v)              = StringObject.new(v.raw.chop)
        def string_upcase(_, v)            = StringObject.new(v.raw.upcase)
        def string_downcase(_, v)          = StringObject.new(v.raw.downcase)
        def string_swapcase(_, v)          = StringObject.new(v.raw.swapcase)
        def string_capitalize(_, v)        = StringObject.new(v.raw.capitalize)
        def string_reverse(_, v)           = StringObject.new(v.raw.reverse)

        def string_reverse_bang(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          v.raw = v.raw.reverse.freeze
          v
        end

        def string_chars(_, v)             = ArrayObject.new(v.raw.chars.map { |c| StringObject.new(c) })
        def string_bytes(_, v)             = ArrayObject.new(v.raw.bytes.map { |b| IntegerObject.new(b) })
        def string_ord(_, v)               = IntegerObject.new(v.raw.ord)

        def string_split(context, v, sep = nil, limit = nil)
          sep = nil if sep.is_a?(NilObject)
          limit = nil if limit.is_a?(NilObject)

          # Coerce limit to integer
          if limit && !limit.is_a?(IntegerObject)
            begin
              limit = limit.dispatch(context, :to_int, [], {})
              raise FrozoneException.make(:TypeError, "no implicit conversion into Integer") unless limit.is_a?(IntegerObject)
            rescue FrozoneException => e
              vm_obj = e.vm_object
              if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{vm_obj.class_object&.name} into Integer")
              end
              raise
            end
          end
          limit_raw = limit&.raw

          # Use $; when sep is nil
          gs = nil
          if sep.nil?
            gs = GLOBALS[:"$;"]
            gs = nil if gs.nil? || gs.is_a?(NilObject)
          end

          # Determine the raw separator
          sep_raw = if sep.nil? && gs.nil?
            nil
          elsif sep.nil?
            gs.is_a?(StringObject) ? gs.raw : gs.raw
          elsif sep.is_a?(StringObject) || sep.is_a?(RegexpObject)
            sep.raw
          else
            begin
              coerced = sep.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{sep.class_object&.name || 'Object'} into String") unless coerced.is_a?(StringObject)
              coerced.raw
            rescue FrozoneException => e
              vm_obj = e.vm_object
              if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{sep.class_object&.name || 'Object'} into String")
              end
              raise
            end
          end

          parts = if sep_raw.nil?
            limit_raw ? v.raw.split(nil, limit_raw) : v.raw.split
          else
            limit_raw ? v.raw.split(sep_raw, limit_raw) : v.raw.split(sep_raw)
          end
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end

        def extract_pattern(context, pattern)
          return pattern.raw if pattern.is_a?(StringObject) || pattern.is_a?(RegexpObject)
          if pattern.is_a?(ObjectObject)
            r = pattern.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if r.is_a?(StringObject)
          end
          name = pattern.is_a?(ObjectObject) ? (pattern.class_object&.name || 'Object').to_s : pattern.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def extract_string_replacement(context, replacement)
          return replacement.raw if replacement.is_a?(StringObject)
          if replacement.is_a?(ObjectObject)
            r = replacement.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if r.is_a?(StringObject)
          end
          name = replacement.is_a?(ObjectObject) ? (replacement.class_object&.name || 'Object').to_s : replacement.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def block_result_to_s(context, val)
          return val.raw if val.is_a?(StringObject)
          r = val.dispatch(context, :to_s, [], {}) rescue nil
          r.is_a?(StringObject) ? r.raw : val.to_s
        end

        def string_gsub(context, v, pattern, replacement = nil, block = nil)
          pat = extract_pattern(context, pattern)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          has_block = block && !block.is_a?(NilObject)
          if has_block && !has_replacement
            result = v.raw.gsub(pat) do |_match|
              update_match_globals($~)
              match_obj = StringObject.new($&)
              block_result_to_s(context, block.invoke(context, [match_obj]))
            end
            StringObject.new(result)
          elsif !has_replacement
            NilObject::NIL
          elsif replacement.is_a?(HashObject)
            result = v.raw.gsub(pat) do |match|
              r = replacement[StringObject.new(match)]
              r.is_a?(NilObject) || r.nil? ? match : block_result_to_s(context, r)
            end
            StringObject.new(result)
          else
            StringObject.new(v.raw.gsub(pat, extract_string_replacement(context, replacement)))
          end
        end

        def string_sub(context, v, pattern, replacement = nil, block = nil)
          pat = extract_pattern(context, pattern)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          has_block = block && !block.is_a?(NilObject)
          if has_block && !has_replacement
            result = v.raw.sub(pat) do |_match|
              update_match_globals($~)
              match_obj = StringObject.new($&)
              block_result_to_s(context, block.invoke(context, [match_obj]))
            end
            StringObject.new(result)
          elsif !has_replacement
            NilObject::NIL
          elsif replacement.is_a?(HashObject)
            result = v.raw.sub(pat) do |match|
              r = replacement[StringObject.new(match)]
              r.is_a?(NilObject) || r.nil? ? match : block_result_to_s(context, r)
            end
            StringObject.new(result)
          else
            StringObject.new(v.raw.sub(pat, extract_string_replacement(context, replacement)))
          end
        end

        def string_tr(_, v, from, to) = StringObject.new(v.raw.tr(from.raw, to.raw))

        def string_squeeze(_, v, *args)
          args.empty? ? StringObject.new(v.raw.squeeze) : StringObject.new(v.raw.squeeze(*args.map(&:raw)))
        end

        def string_count(_, v, *args) = IntegerObject.new(v.raw.count(*args.map(&:raw)))
        def string_delete(_, v, *args) = StringObject.new(v.raw.delete(*args.map(&:raw)))

        # Called as string_slice(v, idx) — no length — or string_slice(v, idx, len) — explicit length.
        # String#[] uses :__unset__ sentinel so explicit nil can be distinguished from absent len.
        def string_slice(context, v, idx, len = nil)
          if idx.is_a?(RegexpObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if !len.nil? && len.is_a?(NilObject)
            m = idx.raw.match(v.raw)
            update_match_globals(m)
            unless len.nil?
              # len can be Integer (capture index), String/Symbol (named capture), or to_int-able
              cap_idx = if len.is_a?(IntegerObject)
                          len.raw
                        elsif len.is_a?(StringObject) || len.is_a?(SymbolObject)
                          len.raw
                        else
                          str_vm_coerce_to_int(context, len)
                        end
              if m
                begin
                  cap = m[cap_idx]
                rescue IndexError => e
                  raise FrozoneException.make(:IndexError, e.message)
                end
                return cap ? StringObject.new(cap) : NilObject::NIL
              else
                return NilObject::NIL
              end
            end
            return m ? StringObject.new(m[0]) : NilObject::NIL
          end
          # String index: substring search
          if idx.is_a?(StringObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String") unless len.nil?
            result = v.raw[idx.raw]
            return result.nil? ? NilObject::NIL : StringObject.new(result)
          end
          # Range index
          if idx.is_a?(RangeObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into Range") unless len.nil?
            # Coerce range bounds if needed
            b = idx.begin_val
            e = idx.end_val
            b_raw = b.nil? || b.is_a?(NilObject) ? nil : (b.is_a?(IntegerObject) ? b.raw : str_vm_coerce_to_int(context, b))
            e_raw = e.nil? || e.is_a?(NilObject) ? nil : (e.is_a?(IntegerObject) ? e.raw : str_vm_coerce_to_int(context, e))
            range = Range.new(b_raw, e_raw, idx.exclusive?)
            begin
              result = v.raw[range]
            rescue TypeError => err
              raise FrozoneException.make(:TypeError, err.message)
            end
            return result.nil? ? NilObject::NIL : StringObject.new(result)
          end
          # Coerce idx to Integer
          idx_i = if idx.is_a?(IntegerObject)
                    idx.raw
                  else
                    str_vm_coerce_to_int(context, idx)
                  end
          # Coerce len to Integer if provided
          if len.nil?
            begin
              result = v.raw[idx_i]
            rescue TypeError => e
              raise FrozoneException.make(:TypeError, e.message)
            rescue RangeError => e
              raise FrozoneException.make(:RangeError, e.message)
            end
          else
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if len.is_a?(NilObject)
            len_i = len.is_a?(IntegerObject) ? len.raw : str_vm_coerce_to_int(context, len)
            begin
              result = v.raw[idx_i, len_i]
            rescue TypeError => e
              raise FrozoneException.make(:TypeError, e.message)
            rescue RangeError => e
              raise FrozoneException.make(:RangeError, e.message)
            end
          end
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end

        def str_vm_coerce_to_int(context, obj)
          raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if obj.is_a?(NilObject)
          unless obj.respond_to?(:dispatch)
            return obj.raw.is_a?(Integer) ? obj.raw : (raise FrozoneException.make(:TypeError, "no implicit conversion into Integer"))
          end
          begin
            coerced = obj.dispatch(context, :to_int, [], {})
            coerced.is_a?(IntegerObject) ? coerced.raw : (raise FrozoneException.make(:TypeError, "to_int should return Integer"))
          rescue FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object&.name} into Integer")
            end
            raise
          end
        end

        def string_index(_, v, sub, offset = nil)
          result = (offset.nil? || offset.is_a?(NilObject)) ? v.raw.index(sub.raw) : v.raw.index(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def string_rindex(_, v, sub, offset = nil)
          result = (offset.nil? || offset.is_a?(NilObject)) ? v.raw.rindex(sub.raw) : v.raw.rindex(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def string_replace(_, v, other)
          return v if other.is_a?(NilObject)
          v.raw = other.raw.freeze
          v
        end

        def string_succ(_, v)          = StringObject.new(v.raw.succ)

        def string_succ_bang(_, v)
          v.raw = v.raw.succ.freeze
          v
        end

        def string_insert(_, v, index, str)
          v.raw = v.raw.dup.insert(index.raw, str.raw).freeze
          v
        end

        def string_slice_bang(context, v, idx, len = nil)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # Coerce idx
          if idx.is_a?(RangeObject)
            b = idx.begin_val
            e = idx.end_val
            b_raw = b.nil? || b.is_a?(NilObject) ? nil : (b.is_a?(IntegerObject) ? b.raw : str_vm_coerce_to_int(context, b))
            e_raw = e.nil? || e.is_a?(NilObject) ? nil : (e.is_a?(IntegerObject) ? e.raw : str_vm_coerce_to_int(context, e))
            idx_ruby = Range.new(b_raw, e_raw, idx.exclusive?)
          elsif idx.is_a?(IntegerObject)
            idx_ruby = idx.raw
          elsif idx.is_a?(RegexpObject)
            idx_ruby = idx.raw
          elsif idx.is_a?(StringObject)
            idx_ruby = idx.raw
          else
            idx_ruby = str_vm_coerce_to_int(context, idx)
          end
          len_ruby = if len.nil? || len.is_a?(NilObject)
                       nil
                     elsif len.is_a?(IntegerObject)
                       len.raw
                     else
                       str_vm_coerce_to_int(context, len)
                     end
          mutated = v.raw.dup
          if idx_ruby.is_a?(::Regexp) && len_ruby.nil?
            m = idx_ruby.match(mutated)
            update_match_globals(m)
            result = m ? (mutated.slice!(idx_ruby); m[0]) : nil
          elsif len_ruby.nil?
            result = mutated.slice!(idx_ruby)
          else
            result = mutated.slice!(idx_ruby, len_ruby)
          end
          v.raw = mutated
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end

        def string_coerce_replacement(context, repl)
          return repl.raw if repl.is_a?(StringObject)
          if repl.is_a?(IntegerObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String")
          end
          if repl.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          end
          begin
            coerced = repl.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{repl.class_object&.name || 'Object'} into String") unless coerced.is_a?(StringObject)
            coerced.raw
          rescue FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{repl.class_object&.name || 'Object'} into String")
            end
            raise
          end
        end

        def string_store(context, v, idx, *rest)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          repl_vm = rest.pop
          repl_raw = string_coerce_replacement(context, repl_vm)

          s = v.raw.dup
          begin
            if idx.is_a?(IntegerObject)
              i = idx.raw
              if rest.empty?
                s[i] = repl_raw
              else
                len_vm = rest[0]
                len = len_vm.is_a?(IntegerObject) ? len_vm.raw : str_vm_coerce_to_int(context, len_vm)
                s[i, len] = repl_raw
              end
            elsif idx.is_a?(StringObject)
              pat = idx.raw
              raise FrozoneException.make(:IndexError, "string not matched") unless s.include?(pat)
              s[pat] = repl_raw
            elsif idx.is_a?(RegexpObject)
              pat = idx.raw
              if rest.empty?
                m = pat.match(s)
                raise FrozoneException.make(:IndexError, "regexp not matched") unless m
                update_match_globals(m)
                s[pat] = repl_raw
              else
                cap_vm = rest[0]
                cap = cap_vm.is_a?(IntegerObject) ? cap_vm.raw : str_vm_coerce_to_int(context, cap_vm)
                m = pat.match(s)
                raise FrozoneException.make(:IndexError, "regexp not matched") unless m
                update_match_globals(m)
                s[pat, cap] = repl_raw
              end
            elsif idx.is_a?(RangeObject)
              b = idx.begin_val
              e = idx.end_val
              b_raw = b.nil? || b.is_a?(NilObject) ? nil : (b.is_a?(IntegerObject) ? b.raw : str_vm_coerce_to_int(context, b))
              e_raw = e.nil? || e.is_a?(NilObject) ? nil : (e.is_a?(IntegerObject) ? e.raw : str_vm_coerce_to_int(context, e))
              s[Range.new(b_raw, e_raw, idx.exclusive?)] = repl_raw
            else
              i = str_vm_coerce_to_int(context, idx)
              if rest.empty?
                s[i] = repl_raw
              else
                len_vm = rest[0]
                len = len_vm.is_a?(IntegerObject) ? len_vm.raw : str_vm_coerce_to_int(context, len_vm)
                s[i, len] = repl_raw
              end
            end
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          v.raw = s
          repl_vm
        end

        def string_each_line(context, v, sep, block)
          if sep.is_a?(NilObject) || sep.nil?
            # nil separator: yield entire string as one chunk
            if block.nil? || block.is_a?(NilObject)
              return ArrayObject.new([StringObject.new(v.raw.dup)])
            end
            block.invoke(context, [StringObject.new(v.raw.dup)])
            return v
          end
          sep_raw = sep.raw
          return ArrayObject.new(v.raw.each_line(sep_raw).map { |l| StringObject.new(l) }) if block.nil? || block.is_a?(NilObject)
          v.raw.each_line(sep_raw) { |l| block.invoke(context, [StringObject.new(l)]) }
          v
        end

        def string_b(_, v) = StringObject.new(v.raw.b)
        def string_ascii_only(_, v) = bool_object_for(v.raw.ascii_only?)
        def string_concat(_, v1, v2)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v1.raw.inspect}") if v1.frozen?
          v2_str = v2.is_a?(StringObject) ? v2.raw : v2.to_s
          v1.raw << v2_str
          v1
        end

        def string_concat_codepoint(_, v1, n)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v1.raw.inspect}") if v1.frozen?
          codepoint = n.is_a?(IntegerObject) ? n.raw : n.to_i
          raise FrozoneException.make(:RangeError, "invalid codepoint #{codepoint} in #{v1.raw.encoding}") if codepoint < 0
          begin
            enc = v1.raw.encoding
            # US-ASCII with value 128..255: switch to BINARY
            if enc == ::Encoding::US_ASCII && codepoint >= 128 && codepoint <= 255
              v1.raw.force_encoding(::Encoding::BINARY)
              v1.raw << codepoint
            else
              v1.raw << codepoint.chr(enc)
            end
          rescue RangeError => e
            raise FrozoneException.make(:RangeError, e.message)
          end
          v1
        end
        def string_multiply(_, v, n)
          count = n.is_a?(IntegerObject) ? n.raw : (n.respond_to?(:raw) ? n.raw.to_i : n.to_i)
          raise FrozoneException.make(:ArgumentError, "negative string size (or exceeds maximum allowed string size)") if count < 0
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if count > 9_223_372_036_854_775_807
          str = v.raw
          raise FrozoneException.make(:ArgumentError, "argument exceeds the limit") if !str.empty? && count > 1_073_741_823
          StringObject.new(str * count)
        end

        def string_format(_, v, args)
          raw_args = args.is_a?(ArrayObject) ? args.raw.map(&:raw) : args.raw
          StringObject.new(v.raw % raw_args)
        end

        def string_encode(context, v, enc = nil, **_opts)
          return StringObject.new(v.raw.dup) if enc.nil? || enc.is_a?(NilObject)
          enc_name = if enc.is_a?(StringObject)
                       enc.raw
                     elsif enc.respond_to?(:dispatch)
                       enc.dispatch(context, :name, [], {}).raw rescue (enc.get_ivar(:@name)&.raw || enc.to_s)
                     else
                       enc.to_s
                     end
          begin
            StringObject.new(v.raw.encode(enc_name))
          rescue ::Encoding::UndefinedConversionError, ::Encoding::InvalidByteSequenceError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_encode_bang(context, v, enc = nil, **_opts)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String") if v.frozen?
          return v if enc.nil? || enc.is_a?(NilObject)
          enc_name = if enc.is_a?(StringObject)
                       enc.raw
                     elsif enc.respond_to?(:dispatch)
                       enc.dispatch(context, :name, [], {}).raw rescue (enc.get_ivar(:@name)&.raw || enc.to_s)
                     else
                       enc.to_s
                     end
          begin
            v.raw.encode!(enc_name)
            v
          rescue ::Encoding::UndefinedConversionError, ::Encoding::InvalidByteSequenceError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_force_encoding(context, v, enc)
          enc_name = if enc.is_a?(StringObject)
                       enc.raw
                     elsif enc.respond_to?(:get_ivar)
                       enc.dispatch(context, :name, [], {}).raw rescue enc.get_ivar(:@name)&.raw || enc.to_s
                     else
                       enc.to_s
                     end
          v.raw.force_encoding(enc_name)
          v
        end

        def string_encoding(_, v)
          enc_name = v.raw.encoding.name
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          return StringObject.new(enc_name) unless enc_class
          const_name = enc_name.tr('-', '_').to_sym
          enc_class.get_constant(const_name) || StringObject.new(enc_name)
        end

        def string_freeze(_, v)           = (v.freeze_object!; v)
        def string_frozen(_, v)           = bool_object_for(v.frozen_object?)
        def string_dup(_, v)              = StringObject.new(v.raw.dup)
        def string_to_sym(_, v)           = SymbolObject.from(v.raw.to_sym)
        def string_to_f(_, v)             = FloatObject.new(v.raw.to_f)
        def string_to_r(context, v)
          r = v.raw.to_r
          make_rational(r)
        end

        def string_match(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          m = pat.match(v.raw)
          update_match_globals(m)
          m ? MatchDataObject.new(m) : NilObject::NIL
        end

        def string_match_q(_, v, pattern, pos)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          str = v.raw
          result = (pos.is_a?(NilObject) || pos.nil?) ? pat.match?(str) : pat.match?(str, pos.raw)
          bool_object_for(result)
        end

        def string_scan(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          results = v.raw.scan(pat)
          ArrayObject.new(results.map { |r| r.is_a?(Array) ? ArrayObject.new(r.map { |s| StringObject.new(s) }) : StringObject.new(r) })
        end

        # Symbol
        def symbol_to_s(_, v) = StringObject.new(v.raw.to_s)
        def symbol_inspect(_, v) = StringObject.new(v.raw.inspect)

        SYMBOL_NAME_CACHE = {}
        def symbol_name(_, v)
          SYMBOL_NAME_CACHE[v.raw] ||= StringObject.new(v.raw.to_s, frozen: true)
        end

        def symbol_hash(_, v) = IntegerObject.new(v.raw.hash)

        def symbol_eql(_, v1, v2) = bool_object_for(v2.is_a?(SymbolObject) && v1.raw == v2.raw)

        def symbol_to_proc(context, sym)
          method_name = sym.raw
          native = NativeBlock.new(
            source_location: nil,
            parameters_override: [[:req], [:rest]],
            is_lambda: true
          ) do |ctx, args, block: nil|
            if args.empty?
              raise FrozoneException.make(:ArgumentError, "no receiver given")
            end
            receiver = args[0]
            rest = args[1..]
            block_obj = block.is_a?(ProcObject) ? block.block_object : block
            block_obj = nil if block_obj.nil? || block_obj.is_a?(NilObject)
            receiver.dispatch(ctx, method_name, rest, {}, block_obj, private_ok: false, public_only: true)
          end
          ProcObject.new(native, lambda: true)
        end

        def symbol_all_symbols(_)
          ArrayObject.new(SymbolObject::SymbolObjects.values)
        end
      end
    end
  end
end

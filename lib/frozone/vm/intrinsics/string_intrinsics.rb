# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      # Global dedup table: maps raw MRI string → frozen StringObject
      STRING_DEDUP_TABLE = {}

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

        def string_spaceship(context, v1, v2)
          if v2.is_a?(StringObject)
            return IntegerObject.new(v1.raw <=> v2.raw)
          end
          # Try to_str coercion
          if v2.is_a?(ObjectObject)
            begin
              coerced = v2.dispatch(context, :to_str, [], {})
              return IntegerObject.new(v1.raw <=> coerced.raw) if coerced.is_a?(StringObject)
            rescue FrozoneException
            end
            # Try v2 <=> v1, negate result
            begin
              r = v2.dispatch(context, :<=>, [v1], {})
              return NilObject::NIL if r.nil? || r.is_a?(NilObject)
              return IntegerObject.new(-r.raw)
            rescue FrozoneException
            end
          end
          NilObject::NIL
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
          if sep.nil? || sep.is_a?(NilObject)
            StringObject.new(v.raw.chomp)
          else
            StringObject.new(v.raw.chomp(sep.is_a?(StringObject) ? sep.raw : sep.respond_to?(:raw) ? sep.raw : sep.to_s))
          end
        end

        def string_chop(_, v)              = StringObject.new(v.raw.chop)
        def string_upcase(_, v)            = StringObject.new(v.raw.upcase)
        def string_downcase(_, v)          = StringObject.new(v.raw.downcase)
        def string_swapcase(_, v)          = StringObject.new(v.raw.swapcase)
        def string_capitalize(_, v)        = StringObject.new(v.raw.capitalize)
        def string_reverse(_, v)           = StringObject.new(v.raw.reverse)

        def string_casecmp(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(StringObject)
          # Return nil for incompatible encodings
          return NilObject::NIL if ::Encoding.compatible?(v1.raw, v2.raw).nil?
          begin
            result = v1.raw.downcase(:ascii) <=> v2.raw.downcase(:ascii)
            result.nil? ? NilObject::NIL : IntegerObject.new(result)
          rescue ::ArgumentError
            # Invalid byte sequence — compare raw bytes
            begin
              result = v1.raw.b <=> v2.raw.b
              result.nil? ? NilObject::NIL : IntegerObject.new(result)
            rescue
              NilObject::NIL
            end
          end
        end

        def string_casecmp_q(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(StringObject)
          # Return nil for incompatible encodings
          return NilObject::NIL if ::Encoding.compatible?(v1.raw, v2.raw).nil?
          begin
            result = v1.raw.downcase(:fold) <=> v2.raw.downcase(:fold)
            result.nil? ? NilObject::NIL : bool_object_for(result == 0)
          rescue ::ArgumentError
            # Invalid byte sequence — compare raw bytes
            begin
              result = v1.raw.b <=> v2.raw.b
              result.nil? ? NilObject::NIL : bool_object_for(result == 0)
            rescue
              NilObject::NIL
            end
          end
        end

        def string_reverse_bang(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          v.raw = v.raw.reverse
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
          has_block = block && !block.is_a?(NilObject)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          if has_block && !has_replacement
            last_m = nil
            result = v.raw.gsub(pat) do |_match|
              m = $~
              update_match_globals(m)
              last_m = m
              match_obj = StringObject.new($&)
              ret = block_result_to_s(context, block.invoke(context, [match_obj]))
              # Restore $~ to the gsub match after block runs (block may have changed it)
              update_match_globals(m)
              ret
            end
            update_match_globals(last_m)
            StringObject.new(result)
          elsif replacement.nil? || replacement.is_a?(NilObject)
            # Explicit nil replacement → TypeError (no-replacement case handled in string.rb)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          elsif replacement.is_a?(HashObject)
            last_m = nil
            result = v.raw.gsub(pat) do |match|
              last_m = $~
              key = StringObject.new(match)
              r = replacement.dispatch(context, :[], [key], {})
              (r.nil? || r.is_a?(NilObject)) ? '' : block_result_to_s(context, r)
            end
            update_match_globals(last_m)
            StringObject.new(result)
          else
            repl_raw = extract_string_replacement(context, replacement)
            last_m = nil
            if pat.is_a?(::Regexp)
              v.raw.scan(pat) { last_m = $~ }
            else
              last_i = v.raw.rindex(pat)
              last_m = last_i ? ::Regexp.new(::Regexp.escape(pat)).match(v.raw, last_i) : nil
            end
            update_match_globals(last_m)
            StringObject.new(v.raw.gsub(pat, repl_raw))
          end
        end

        def string_sub(context, v, pattern, replacement = nil, block = nil)
          pat = extract_pattern(context, pattern)
          has_block = block && !block.is_a?(NilObject)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          if has_block && !has_replacement
            the_m = nil
            result = v.raw.sub(pat) do |_match|
              m = $~
              update_match_globals(m)
              the_m = m
              match_obj = StringObject.new($&)
              ret = block_result_to_s(context, block.invoke(context, [match_obj]))
              update_match_globals(m)
              ret
            end
            update_match_globals(the_m)
            StringObject.new(result)
          elsif replacement.nil? || replacement.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          elsif replacement.is_a?(HashObject)
            first_m = nil
            result = v.raw.sub(pat) do |match|
              first_m = $~
              key = StringObject.new(match)
              r = replacement.dispatch(context, :[], [key], {})
              (r.nil? || r.is_a?(NilObject)) ? '' : block_result_to_s(context, r)
            end
            update_match_globals(first_m)
            StringObject.new(result)
          else
            repl_raw = extract_string_replacement(context, replacement)
            m = if pat.is_a?(::Regexp)
                  pat.match(v.raw)
                else
                  i = v.raw.index(pat)
                  i ? ::Regexp.new(::Regexp.escape(pat)).match(v.raw, i) : nil
                end
            update_match_globals(m)
            StringObject.new(v.raw.sub(pat, repl_raw))
          end
        end

        def string_tr(context, v, from, to)
          from_raw = from.is_a?(StringObject) ? from.raw : coerce_str_args(context, [from])[0]
          to_raw   = to.is_a?(StringObject)   ? to.raw   : coerce_str_args(context, [to])[0]
          StringObject.new(v.raw.tr(from_raw, to_raw))
        end

        def string_squeeze(context, v, *args)
          strs = coerce_str_args(context, args)
          args.empty? ? StringObject.new(v.raw.squeeze) : StringObject.new(v.raw.squeeze(*strs))
        end

        def string_count(context, v, *args)
          strs = coerce_str_args(context, args)
          IntegerObject.new(v.raw.count(*strs))
        end

        def string_delete(context, v, *args)
          strs = coerce_str_args(context, args)
          StringObject.new(v.raw.delete(*strs))
        end

        private

        def coerce_str_args(context, args)
          args.map do |a|
            if a.is_a?(StringObject)
              a.raw
            elsif a.is_a?(ObjectObject)
              begin
                r = a.dispatch(context, :to_str, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{a.class_object&.name} into String") unless r.is_a?(StringObject)
                r.raw
              rescue FrozoneException => e
                vm_obj = e.vm_object
                if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{a.class_object&.name} into String")
                end
                raise
              end
            else
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{a.class} into String")
            end
          end
        end

        public

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

        def string_index(context, v, sub, offset = nil)
          pat = coerce_str_or_regexp(context, sub)
          off_raw = coerce_offset(context, offset)
          begin
            result = off_raw ? v.raw.index(pat, off_raw) : v.raw.index(pat)
            if pat.is_a?(::Regexp)
              m = result ? pat.match(v.raw, result) : nil
              update_match_globals(m)
            end
            result.nil? ? NilObject::NIL : IntegerObject.new(result)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.make(:EncodingError, e.message)
          rescue ::TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          end
        end

        def string_rindex(context, v, sub, offset = nil)
          if sub.is_a?(IntegerObject) || (sub.is_a?(ObjectObject) && sub.class_object&.name == :Integer)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String")
          end
          pat = coerce_str_or_regexp(context, sub)
          off_raw = coerce_offset(context, offset)
          begin
            result = off_raw ? v.raw.rindex(pat, off_raw) : v.raw.rindex(pat)
            result.nil? ? NilObject::NIL : IntegerObject.new(result)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.make(:EncodingError, e.message)
          rescue ::TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          end
        end

        private

        def coerce_str_or_regexp(context, sub)
          return sub.raw if sub.is_a?(StringObject) || sub.is_a?(RegexpObject)
          if sub.is_a?(NilObject) || sub.is_a?(TrueObject) || sub.is_a?(FalseObject)
            name = sub.class_object&.name || sub.class.name
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
          end
          if sub.is_a?(ObjectObject)
            begin
              r = sub.dispatch(context, :to_str, [], {})
              return r.raw if r.is_a?(StringObject)
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name} into String")
            rescue FrozoneException => e
              vm_obj = e.vm_object
              if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name} into String")
              end
              raise
            end
          end
          sub.respond_to?(:raw) ? sub.raw : sub.to_s
        end

        def coerce_offset(context, offset)
          return nil if offset.nil? || offset.is_a?(NilObject)
          return offset.raw if offset.is_a?(IntegerObject)
          str_vm_coerce_to_int(context, offset)
        end

        public

        def string_dedup(_, v)
          raw = v.raw
          # skip dedup for strings with instance variables
          return v if v.frozen_object? && v.get_ivar(:@__ivars__)
          key = "#{raw.b}\x00#{raw.encoding.name}"
          existing = STRING_DEDUP_TABLE[key]
          if existing
            existing
          else
            if v.frozen_object?
              STRING_DEDUP_TABLE[key] = v
              v
            else
              new_str = StringObject.new(raw.dup)
              new_str.freeze_object!
              STRING_DEDUP_TABLE[key] = new_str
              new_str
            end
          end
        end

        def string_replace(context, v, other)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          other_raw = if other.is_a?(StringObject)
                        other.raw
                      elsif other.is_a?(NilObject)
                        raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                      elsif other.is_a?(ObjectObject)
                        r = begin
                          other.dispatch(context, :to_str, [], {})
                        rescue FrozoneException
                          nil
                        end
                        unless r.is_a?(StringObject)
                          raise FrozoneException.make(:TypeError, "no implicit conversion of #{other.class_object&.name || 'Object'} into String")
                        end
                        r.raw
                      else
                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{other.class_object&.name || other.class} into String")
                      end
          v.raw = other_raw.dup
          v
        end

        def string_succ(_, v)          = StringObject.new(v.raw.succ)

        def string_succ_bang(_, v)
          v.raw = v.raw.succ
          v
        end

        def string_insert(_, v, index, str)
          idx = index.is_a?(IntegerObject) ? index.raw : index.is_a?(Integer) ? index : index.to_i
          s = str.is_a?(StringObject) ? str.raw : str.to_s
          begin
            v.raw = v.raw.dup.insert(idx, s)
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          end
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
          # Coerce separator to string
          sep_raw = if sep.is_a?(StringObject)
                      sep.raw
                    elsif sep.is_a?(SymbolObject)
                      raise FrozoneException.make(:TypeError, "no implicit conversion of Symbol into String")
                    elsif sep.is_a?(ObjectObject)
                      begin
                        r = sep.dispatch(context, :to_str, [], {})
                        raise FrozoneException.make(:TypeError, "no implicit conversion into String") unless r.is_a?(StringObject)
                        r.raw
                      rescue FrozoneException => e
                        vm_obj = e.vm_object
                        if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                          raise FrozoneException.make(:TypeError, "no implicit conversion of #{sep.class_object&.name} into String")
                        end
                        raise
                      end
                    else
                      raise FrozoneException.make(:TypeError, "no implicit conversion of #{sep.class} into String")
                    end
          begin
            if block.nil? || block.is_a?(NilObject)
              ArrayObject.new(v.raw.each_line(sep_raw).map { |l| StringObject.new(l) })
            else
              v.raw.each_line(sep_raw) { |l| block.invoke(context, [StringObject.new(l)]) }
              v
            end
          rescue ::Encoding::CompatibilityError => e
            enc_name = v.raw.encoding.name
            # UTF-7 and similar non-BOM dummies raise ConverterNotFoundError
            # UTF-16/UTF-32 (BOM dummies) return whole string
            if enc_name == 'UTF-7' || enc_name.start_with?('ISO-2022')
              wrapped = FrozoneException.wrap_mri(::Encoding::ConverterNotFoundError.new(e.message))
              raise FrozoneException.new(wrapped, e.message)
            end
            # BOM dummy encodings (UTF-16, UTF-32) — return/yield whole string
            if block.nil? || block.is_a?(NilObject)
              ArrayObject.new([StringObject.new(v.raw.dup)])
            else
              block.invoke(context, [StringObject.new(v.raw.dup)])
              v
            end
          rescue ::Encoding::ConverterNotFoundError => e
            wrapped = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(wrapped, e.message)
          end
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

        def string_format(context, v, args)
          # Sync Frozone's $DEBUG with MRI so unused-arg check works
          frozone_debug = GLOBALS[:"$DEBUG"]
          saved_debug = $DEBUG
          $DEBUG = frozone_debug.truthy? if frozone_debug
          begin
            if args.is_a?(ArrayObject)
              raw_args = args.raw.map { |a| frozone_to_format_proxy(context, a) }
              StringObject.new(v.raw % raw_args)
            elsif args.is_a?(HashObject)
              # Named reference format %{name} or %<name>s — pass as hash, not array
              raw_arg = frozone_to_format_proxy(context, args)
              StringObject.new(v.raw % raw_arg)
            else
              raw_arg = frozone_to_format_proxy(context, args)
              StringObject.new(v.raw % raw_arg)
            end
          rescue ::TypeError => e
            # Normalize MRI's "no implicit conversion from X to Y" to "no implicit conversion of X into Y"
            msg = e.message.gsub(/\Ano implicit conversion from (.+) to (.+)\z/) {
              "no implicit conversion of #{$1} into #{$2.split.map(&:capitalize).join}"
            }
            raise FrozoneException.make(:TypeError, msg)
          rescue ::ArgumentError => e
            raise FrozoneException.make(:ArgumentError, e.message)
          rescue ::KeyError => e
            exc = FrozoneException.wrap_mri(e)
            # Set receiver to the original Frozone HashObject (not the MRI proxy)
            frozone_receiver = if args.is_a?(HashObject)
              args
            elsif e.respond_to?(:receiver) && e.receiver.is_a?(HashFormatProxy)
              e.receiver.frozone_vm_hash
            end
            exc.set_ivar(:@receiver, frozone_receiver) if frozone_receiver
            if e.respond_to?(:key) && e.key
              mri_key = e.key
              frozone_key = mri_key.is_a?(::Symbol) ? SymbolObject.from(mri_key) : StringObject.new(mri_key.to_s)
              exc.set_ivar(:@key, frozone_key)
            end
            raise FrozoneException.new(exc, e.message)
          ensure
            $DEBUG = saved_debug
          end
        end

        private

        # Create an MRI object that proxies Frozone object coercions for sprintf
        def frozone_to_format_proxy(context, arg)
          return arg.raw if arg.is_a?(StringObject) || arg.is_a?(IntegerObject) ||
                            arg.is_a?(FloatObject) || arg.is_a?(SymbolObject)
          return nil if arg.is_a?(NilObject)
          return arg.raw if arg.is_a?(TrueObject) || arg.is_a?(FalseObject)
          return arg.raw if arg.is_a?(RegexpObject)
          if arg.is_a?(HashObject)
            # Convert to MRI hash with symbol keys for named references %{name}, %<name>s
            h = {}
            arg.raw.each do |k, v|
              mri_key = k.is_a?(SymbolObject) ? k.raw : k.respond_to?(:raw) ? k.raw.to_sym : k.to_sym
              mri_val = frozone_to_format_proxy(context, v)
              h[mri_key] = mri_val
            end
            proxy = HashFormatProxy.new(h, arg)
            # Propagate Frozone hash default so %{missing} works with Hash.new(default)
            if arg.default_block && !arg.default_block.is_a?(NilObject)
              fz_block = arg.default_block
              fz_ctx = context
              proxy.default_proc = proc { |_h, k|
                sym_key = k.is_a?(::Symbol) ? SymbolObject.from(k) : StringObject.new(k.to_s)
                result = fz_block.invoke(fz_ctx, [arg, sym_key]) rescue NilObject::NIL
                frozone_to_format_proxy(fz_ctx, result)
              }
            elsif arg.default_value && !arg.default_value.is_a?(NilObject)
              proxy.default = frozone_to_format_proxy(context, arg.default_value)
            end
            proxy
          elsif arg.is_a?(ObjectObject)
            FormatProxy.new(arg, context)
          else
            arg.respond_to?(:raw) ? arg.raw : arg
          end
        end

        public

        # Proxy class for Frozone ObjectObjects in sprintf
        class FormatProxy
          def initialize(vm_obj, context)
            @vm_obj = vm_obj
            @context = context
          end

          def to_s
            r = @vm_obj.dispatch(@context, :to_s, [], {})
            r.is_a?(StringObject) ? r.raw : @vm_obj.to_s
          rescue Frozone::Vm::FrozoneException => e
            # Let NoMethodError propagate (e.g. BasicObject without to_s)
            raise if e.vm_object.is_a?(ObjectObject) && e.vm_object.class_object&.name == :NoMethodError
            @vm_obj.to_s
          end

          def inspect
            r = @vm_obj.dispatch(@context, :inspect, [], {}) rescue nil
            r.is_a?(StringObject) ? r.raw : @vm_obj.to_s
          end

          # to_ary is dispatched through Frozone for mock support
          # Returns nil (not array), array, or non-array (so MRI raises TypeError)
          def to_ary
            r = @vm_obj.dispatch(@context, :to_ary, [], {})
            return nil if r.is_a?(NilObject)
            if r.is_a?(ArrayObject)
              r.raw.map { |a| a.respond_to?(:raw) ? a.raw : a }
            else
              # Return non-array value so MRI raises TypeError
              r.respond_to?(:raw) ? r.raw : r.to_s
            end
          rescue Frozone::Vm::FrozoneException
            nil
          end

          def to_int
            r = @vm_obj.dispatch(@context, :to_int, [], {})
            raise TypeError, "can't convert #{@vm_obj.class_object&.name} into Integer" unless r.is_a?(IntegerObject)
            r.raw
          rescue Frozone::Vm::FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise TypeError, "no implicit conversion of #{@vm_obj.class_object&.name} into Integer"
            end
            raise TypeError, e.message
          end

          def to_i
            r = @vm_obj.dispatch(@context, :to_i, [], {})
            r.is_a?(IntegerObject) ? r.raw : 0
          rescue Frozone::Vm::FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise TypeError, "no implicit conversion of #{@vm_obj.class_object&.name} into Integer"
            end
            raise TypeError, e.message
          end

          def to_f
            r = @vm_obj.dispatch(@context, :to_f, [], {})
            raise TypeError, "can't convert #{@vm_obj.class_object&.name} into Float" unless r.is_a?(FloatObject)
            r.raw
          rescue Frozone::Vm::FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise TypeError, "no implicit conversion of #{@vm_obj.class_object&.name} into Float"
            end
            raise TypeError, e.message
          end

          # to_str is called by %c format (not by %s which uses to_s)
          def to_str
            r = @vm_obj.dispatch(@context, :to_str, [], {})
            return r.raw if r.is_a?(StringObject)
            return nil if r.is_a?(NilObject)
            # Non-String returned: raise TypeError so MRI propagates correct message
            raise TypeError, "can't convert #{@vm_obj.class_object&.name} into String (#{@vm_obj.class_object&.name}#to_str gives #{r.class_object&.name})"
          rescue Frozone::Vm::FrozoneException
            nil
          end

          def respond_to_missing?(name, include_private = false)
            # Don't advertise to_ary via respond_to? (it may still be called directly by MRI)
            return false if name == :to_ary
            true
          end

          def method_missing(name, *args)
            @vm_obj.respond_to?(:raw) ? @vm_obj.raw.send(name, *args) : super
          end
        end

        # Proxy for Hash args to support named format references %{name}, %<name>s
        # Inherits from Hash so MRI's % operator treats it as a hash type directly.
        class HashFormatProxy < ::Hash
          attr_reader :frozone_vm_hash

          def initialize(h, vm_hash = nil)
            @frozone_vm_hash = vm_hash
            super()
            update(h)
          end
        end

        def string_encode(context, v, enc = nil, src_enc = nil, **opts)
          enc_opts = extract_encode_opts(opts)
          if enc.nil? || enc.is_a?(NilObject)
            # Check default_internal
            di = GLOBALS[:"$KCODE"] # Not ideal; check Encoding.default_internal via constants
            return StringObject.new(v.raw.dup)
          end
          enc_name = resolve_encoding_name(context, enc)
          src_name = src_enc && !src_enc.is_a?(NilObject) ? resolve_encoding_name(context, src_enc) : nil
          begin
            result = if src_name
                       enc_opts.empty? ? v.raw.encode(enc_name, src_name) : v.raw.encode(enc_name, src_name, **enc_opts)
                     else
                       enc_opts.empty? ? v.raw.encode(enc_name) : v.raw.encode(enc_name, **enc_opts)
                     end
            StringObject.new(result)
          rescue ::Encoding::UndefinedConversionError,
                 ::Encoding::InvalidByteSequenceError,
                 ::Encoding::ConverterNotFoundError,
                 ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        def string_encode_bang(context, v, enc = nil, src_enc = nil, **opts)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String") if v.frozen?
          return v if enc.nil? || enc.is_a?(NilObject)
          enc_name = resolve_encoding_name(context, enc)
          src_name = src_enc && !src_enc.is_a?(NilObject) ? resolve_encoding_name(context, src_enc) : nil
          enc_opts = extract_encode_opts(opts)
          begin
            if src_name
              enc_opts.empty? ? v.raw.encode!(enc_name, src_name) : v.raw.encode!(enc_name, src_name, **enc_opts)
            else
              enc_opts.empty? ? v.raw.encode!(enc_name) : v.raw.encode!(enc_name, **enc_opts)
            end
            v
          rescue ::Encoding::UndefinedConversionError,
                 ::Encoding::InvalidByteSequenceError,
                 ::Encoding::ConverterNotFoundError,
                 ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        private

        def extract_encode_opts(opts)
          return {} unless opts.is_a?(::Hash)
          result = {}
          opts.each do |k, v|
            key = k.is_a?(SymbolObject) ? k.raw : k.is_a?(Symbol) ? k : nil
            next unless key
            val = v.is_a?(SymbolObject) ? v.raw : v.is_a?(NilObject) ? nil : v.is_a?(StringObject) ? v.raw : v
            result[key] = val
          end
          result
        end

        def resolve_encoding_name(context, enc)
          if enc.is_a?(StringObject)
            enc.raw
          elsif enc.is_a?(ObjectObject)
            # Check if it's an Encoding object (has @name ivar)
            name_ivar = enc.get_ivar(:@name)
            if name_ivar && name_ivar.is_a?(StringObject)
              return name_ivar.raw
            end
            # Try to_str coercion
            begin
              r = enc.dispatch(context, :to_str, [], {})
              return r.raw if r.is_a?(StringObject)
              return r.to_s if r.is_a?(::String)  # mspec mock may return raw String
            rescue FrozoneException => e
              vm_obj = e.vm_object
              unless vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise
              end
            end
            # Try :name method (for Encoding objects)
            begin
              r = enc.dispatch(context, :name, [], {})
              return r.raw if r.is_a?(StringObject)
            rescue FrozoneException
            end
            name = enc.class_object&.name || 'Object'
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
          elsif enc.is_a?(::String)
            enc  # raw MRI string
          else
            'UTF-8'
          end
        end

        public

        def string_force_encoding(context, v, enc)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen_object?
          enc_name = if enc.is_a?(StringObject)
                       enc.raw
                     elsif enc.is_a?(SymbolObject)
                       enc.raw.to_s
                     elsif enc.is_a?(NilObject)
                       raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                     elsif enc.is_a?(ObjectObject)
                       # Check if it's actually an Encoding instance (not just any object with @name)
                       if enc.class_object&.name == :Encoding
                         begin
                           r = enc.dispatch(context, :name, [], {})
                           r.is_a?(StringObject) ? r.raw : (enc.get_ivar(:@name)&.raw || enc.to_s)
                         rescue FrozoneException
                           enc.get_ivar(:@name)&.raw || enc.to_s
                         end
                       else
                         # Try to_str coercion
                         begin
                           coerced = enc.dispatch(context, :to_str, [], {})
                           raise FrozoneException.make(:TypeError, "no implicit conversion of #{enc.class_object&.name} into String") unless coerced.is_a?(StringObject)
                           coerced.raw
                         rescue FrozoneException => e
                           vm_obj = e.vm_object
                           if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                             raise FrozoneException.make(:TypeError, "no implicit conversion of #{enc.class_object&.name} into String")
                           end
                           raise
                         end
                       end
                     else
                       enc.to_s
                     end
          # Resolve special encoding names through Frozone's Encoding class
          enc_name = resolve_special_encoding_name(enc_name)
          begin
            v.raw.force_encoding(enc_name)
          rescue ::ArgumentError => e
            raise FrozoneException.make(:ArgumentError, e.message)
          end
          v
        end

        def resolve_special_encoding_name(name)
          case name
          when 'locale', 'external'
            enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
            return name unless enc_class
            begin
              ext = enc_class.get_ivar(:@default_external)
              ext.is_a?(ObjectObject) ? (ext.get_ivar(:@name)&.raw || name) : name
            rescue
              name
            end
          when 'internal'
            enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
            return 'ASCII-8BIT' unless enc_class
            begin
              int = enc_class.get_ivar(:@default_internal)
              if int.nil? || int.is_a?(NilObject)
                'ASCII-8BIT'
              else
                int.is_a?(ObjectObject) ? (int.get_ivar(:@name)&.raw || name) : name
              end
            rescue
              'ASCII-8BIT'
            end
          else
            name
          end
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

        def string_match(context, v, pattern)
          if pattern.is_a?(StringObject)
            pat = Regexp.new(pattern.raw)
            m = pat.match(v.raw)
            update_match_globals(m)
            return m ? MatchDataObject.new(m) : NilObject::NIL
          end
          if pattern.is_a?(RegexpObject)
            m = pattern.raw.match(v.raw)
            update_match_globals(m)
            return m ? MatchDataObject.new(m) : NilObject::NIL
          end
          if pattern.is_a?(IntegerObject) || pattern.is_a?(FloatObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{pattern.class_object&.name} into String")
          end
          # Non-regexp, non-string: try to_str coercion, then TypeError
          if pattern.is_a?(ObjectObject)
            begin
              coerced = pattern.dispatch(context, :to_str, [], {})
              if coerced.is_a?(StringObject)
                pat = Regexp.new(coerced.raw)
                m = pat.match(v.raw)
                update_match_globals(m)
                return m ? MatchDataObject.new(m) : NilObject::NIL
              end
            rescue FrozoneException => e
              vm_obj = e.vm_object
              unless vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise
              end
            end
            name = pattern.class_object&.name || 'Object'
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
          end
          raise FrozoneException.make(:TypeError, "no implicit conversion into String")
        end

        def string_match_pos(_, v, pattern, pos)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          pos_raw = pos.is_a?(IntegerObject) ? pos.raw : pos.to_i
          m = pat.match(v.raw, pos_raw)
          update_match_globals(m)
          m ? MatchDataObject.new(m) : NilObject::NIL
        end

        def string_match_q(_, v, pattern, pos)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          str = v.raw
          result = (pos.is_a?(NilObject) || pos.nil?) ? pat.match?(str) : pat.match?(str, pos.raw)
          bool_object_for(result)
        end

        def string_scan(context, v, pattern, block = nil)
          has_block = block && !block.is_a?(NilObject)
          # For string pattern: use raw string (literal match). For regexp: use raw regexp.
          pat = if pattern.is_a?(StringObject)
                  pattern.raw
                elsif pattern.is_a?(RegexpObject)
                  pattern.raw
                else
                  # Try to_str coercion
                  r = pattern.dispatch(context, :to_str, [], {}) rescue nil
                  if r.is_a?(StringObject)
                    r.raw
                  else
                    name = pattern.is_a?(ObjectObject) ? (pattern.class_object&.name || 'Object').to_s : pattern.class.name
                    raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
                  end
                end
          if has_block
            # Build regexp for string pattern so $~ is set properly
            scan_pat = pat.is_a?(::String) ? ::Regexp.new(::Regexp.escape(pat)) : pat
            last_m = nil
            v.raw.scan(scan_pat) do
              m = $~
              update_match_globals(m)
              last_m = m
              groups = m.captures
              if groups.empty?
                block.invoke(context, [StringObject.new(m[0])])
              else
                block.invoke(context, [ArrayObject.new(groups.map { |g| g ? StringObject.new(g) : NilObject::NIL })])
              end
            end
            update_match_globals(last_m)
            v
          else
            scan_pat = pat.is_a?(::String) ? ::Regexp.new(::Regexp.escape(pat)) : pat
            last_m = nil
            results = v.raw.scan(scan_pat).map do |r|
              last_m = $~
              r.is_a?(::Array) ? ArrayObject.new(r.map { |s| StringObject.new(s) }) : StringObject.new(r)
            end
            update_match_globals(last_m)
            ArrayObject.new(results)
          end
        end

        # Byte-level primitives

        def string_getbyte(_, v, i)
          result = v.raw.getbyte(i.is_a?(IntegerObject) ? i.raw : i.to_i)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def string_setbyte(context, v, i, b)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          i_raw = i.is_a?(IntegerObject) ? i.raw : str_vm_coerce_to_int(context, i)
          b_raw = b.is_a?(IntegerObject) ? b.raw : str_vm_coerce_to_int(context, b)
          begin
            v.raw.setbyte(i_raw, b_raw)
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          end
          b
        end

        def string_append_as_bytes(context, v, *args)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          enc = v.raw.encoding
          # Collect bytes to append
          byte_str = "".b
          args.each do |arg|
            if arg.is_a?(StringObject)
              byte_str << arg.raw.b
            elsif arg.is_a?(IntegerObject)
              byte_str << (arg.raw & 0xFF).chr(::Encoding::BINARY)
            else
              type_name = arg.is_a?(ObjectObject) ? (arg.class_object&.name || 'Object').to_s : arg.class.name.split('::').last
              raise FrozoneException.make(:TypeError, "wrong argument type #{type_name} (expected String or Integer)")
            end
          end
          # Append bytes without encoding check by switching to binary temporarily
          v.raw.force_encoding(::Encoding::BINARY)
          v.raw << byte_str
          v.raw.force_encoding(enc)
          v
        end

        def string_byteslice(context, v, idx, len = nil)
          result = begin
            if idx.is_a?(RangeObject)
              b = idx.begin_val
              e = idx.end_val
              b_raw = b.nil? || b.is_a?(NilObject) ? nil : (b.is_a?(IntegerObject) ? b.raw : str_vm_coerce_to_int(context, b))
              e_raw = e.nil? || e.is_a?(NilObject) ? nil : (e.is_a?(IntegerObject) ? e.raw : str_vm_coerce_to_int(context, e))
              v.raw.byteslice(Range.new(b_raw, e_raw, idx.exclusive?))
            elsif len
              idx_i = idx.is_a?(IntegerObject) ? idx.raw : str_vm_coerce_to_int(context, idx)
              len_i = len.is_a?(IntegerObject) ? len.raw : str_vm_coerce_to_int(context, len)
              v.raw.byteslice(idx_i, len_i)
            else
              idx_i = idx.is_a?(IntegerObject) ? idx.raw : str_vm_coerce_to_int(context, idx)
              v.raw.byteslice(idx_i)
            end
          rescue ::RangeError => e
            raise FrozoneException.make(:RangeError, e.message)
          end
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end

        def string_byteindex(context, v, sub, offset = nil)
          offset_raw = offset.nil? ? nil : (offset.is_a?(IntegerObject) ? offset.raw : str_vm_coerce_to_int(context, offset))
          is_regexp = sub.is_a?(RegexpObject)
          pat = if sub.is_a?(StringObject)
                  sub.raw
                elsif is_regexp
                  sub.raw
                elsif sub.is_a?(NilObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                elsif sub.is_a?(TrueObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of true into String")
                elsif sub.is_a?(FalseObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of false into String")
                elsif sub.is_a?(ObjectObject)
                  r = begin
                    sub.dispatch(context, :to_str, [], {})
                  rescue FrozoneException
                    nil
                  end
                  r.is_a?(StringObject) ? r.raw : raise(FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || 'Object'} into String"))
                else
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || sub.class} into String")
                end
          begin
            result = offset_raw ? v.raw.byteindex(pat, offset_raw) : v.raw.byteindex(pat)
            if result.nil?
              update_match_globals(nil) if is_regexp
              NilObject::NIL
            else
              if is_regexp
                m = pat.match(v.raw, v.raw.byteindex(pat, offset_raw || 0))
                update_match_globals(m)
              end
              IntegerObject.new(result)
            end
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          end
        end

        def string_byterindex(context, v, sub, offset = nil)
          offset_raw = offset.nil? ? nil : (offset.is_a?(IntegerObject) ? offset.raw : str_vm_coerce_to_int(context, offset))
          is_regexp = sub.is_a?(RegexpObject)
          pat = if sub.is_a?(StringObject)
                  sub.raw
                elsif is_regexp
                  sub.raw
                elsif sub.is_a?(NilObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                elsif sub.is_a?(TrueObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of true into String")
                elsif sub.is_a?(FalseObject)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of false into String")
                elsif sub.is_a?(ObjectObject)
                  r = begin
                    sub.dispatch(context, :to_str, [], {})
                  rescue FrozoneException
                    nil
                  end
                  r.is_a?(StringObject) ? r.raw : raise(FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || 'Object'} into String"))
                else
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || sub.class} into String")
                end
          begin
            result = offset_raw ? v.raw.byterindex(pat, offset_raw) : v.raw.byterindex(pat)
            if result.nil?
              update_match_globals(nil) if is_regexp
              NilObject::NIL
            else
              if is_regexp
                m = pat.match(v.raw, result)
                update_match_globals(m)
              end
              IntegerObject.new(result)
            end
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          end
        end

        def string_bytesplice(context, v, *args)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # Signatures: bytesplice(index, length, str) or bytesplice(range, str) or
          #             bytesplice(index, length, str, str_index, str_length) or bytesplice(range, str, str_range)
          begin
            raw_args = args.map do |a|
              if a.is_a?(RangeObject)
                b = a.begin_val
                e = a.end_val
                b_raw = b.nil? || b.is_a?(NilObject) ? nil : b.raw
                e_raw = e.nil? || e.is_a?(NilObject) ? nil : e.raw
                Range.new(b_raw, e_raw, a.exclusive?)
              else
                a.respond_to?(:raw) ? a.raw : a
              end
            end
            v.raw.bytesplice(*raw_args)
          rescue ::IndexError => e
            raise FrozoneException.make(:IndexError, e.message)
          rescue ::TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
          v
        end

        def string_valid_encoding(_, v) = bool_object_for(v.raw.valid_encoding?)

        def string_scrub(context, v, replacement = nil, block = nil)
          has_block = block && !block.is_a?(NilObject)
          has_repl = replacement && !replacement.is_a?(NilObject)
          begin
            result = if has_block
                       v.raw.scrub { |b| block_result_to_s(context, block.invoke(context, [StringObject.new(b)])) }
                     elsif has_repl
                       v.raw.scrub(replacement.raw)
                     else
                       v.raw.scrub
                     end
            StringObject.new(result)
          rescue ::EncodingError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_dump(_, v) = StringObject.new(v.raw.dump, frozen: true)

        def string_undump(_, v)
          begin
            StringObject.new(v.raw.undump)
          rescue ::RuntimeError => e
            raise FrozoneException.make(:RuntimeError, e.message)
          rescue ::Encoding::UndefinedConversionError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_oct(_, v) = IntegerObject.new(v.raw.oct)

        def string_upto(context, v, other, exclusive, block)
          return enum_for_str_upto(v, other, exclusive) if block.nil? || block.is_a?(NilObject)
          excl = exclusive.truthy?
          other_raw = other.is_a?(StringObject) ? other.raw : other.dispatch(context, :to_str, [], {}).raw
          v.raw.upto(other_raw, excl) do |s|
            block.invoke(context, [StringObject.new(s)])
          end
          v
        end

        def string_grapheme_clusters(_, v)
          ArrayObject.new(v.raw.grapheme_clusters.map { |g| StringObject.new(g) })
        end

        def string_each_grapheme_cluster(context, v, block)
          if block.nil? || block.is_a?(NilObject)
            return enum_for_no_block(context, v, :each_grapheme_cluster)
          end
          v.raw.each_grapheme_cluster { |g| block.invoke(context, [StringObject.new(g)]) }
          v
        end

        def string_append_bytes(_, v, *args)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # append_bytes never changes the receiver encoding; it appends raw bytes
          orig_enc = v.raw.encoding
          v.raw.force_encoding(::Encoding::BINARY)
          args.each do |arg|
            if arg.is_a?(StringObject)
              arg.raw.force_encoding(::Encoding::BINARY).each_byte { |b| v.raw << b }
            elsif arg.is_a?(IntegerObject)
              n = arg.raw
              # wrap negative, truncate to byte
              b = n & 0xFF
              v.raw << b
            else
              v.raw.force_encoding(orig_enc)
              raise FrozoneException.make(:TypeError, "wrong argument type #{arg.class_object&.name} (expected String or Integer)")
            end
          end
          v.raw.force_encoding(orig_enc)
          v
        end

        def string_tr_s(_, v, from, to) = StringObject.new(v.raw.tr_s(from.raw, to.raw))

        def string_swapcase_opts(_, v, *args)
          opts = args.map { |a| a.is_a?(SymbolObject) ? a.raw : a.raw.to_sym }
          StringObject.new(opts.empty? ? v.raw.swapcase : v.raw.swapcase(*opts))
        end

        def string_upcase_opts(_, v, *args)
          opts = args.map { |a| a.is_a?(SymbolObject) ? a.raw : a.raw.to_sym }
          StringObject.new(opts.empty? ? v.raw.upcase : v.raw.upcase(*opts))
        end

        def string_downcase_opts(_, v, *args)
          opts = args.map { |a| a.is_a?(SymbolObject) ? a.raw : a.raw.to_sym }
          StringObject.new(opts.empty? ? v.raw.downcase : v.raw.downcase(*opts))
        end

        def string_capitalize_opts(_, v, *args)
          opts = args.map { |a| a.is_a?(SymbolObject) ? a.raw : a.raw.to_sym }
          StringObject.new(opts.empty? ? v.raw.capitalize : v.raw.capitalize(*opts))
        end

        def string_unicode_normalize(_, v, form = nil)
          form_raw = (form.nil? || form.is_a?(NilObject)) ? :nfc : form.raw
          begin
            StringObject.new(v.raw.unicode_normalize(form_raw))
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_unicode_normalized_q(_, v, form = nil)
          form_raw = (form.nil? || form.is_a?(NilObject)) ? :nfc : form.raw
          begin
            bool_object_for(v.raw.unicode_normalized?(form_raw))
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_to_i_base(_, v, base)
          base_raw = base.is_a?(IntegerObject) ? base.raw : 0
          IntegerObject.new(v.raw.to_i(base_raw))
        end

        def string_to_c(context, v)
          c = v.raw.to_c
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          return IntegerObject.new(0) unless c_class
          real_raw = c.real
          imag_raw = c.imaginary
          real_vm = numeric_to_vm(context, real_raw, rat_class)
          imag_vm = numeric_to_vm(context, imag_raw, rat_class)
          c_class.dispatch(context, :new, [real_vm, imag_vm], {})
        end

        private

        def numeric_to_vm(context, n, rat_class)
          case n
          when ::Integer then IntegerObject.new(n)
          when ::Float   then FloatObject.new(n)
          when ::Rational
            return IntegerObject.new(n.numerator) if n.denominator == 1
            return FloatObject.new(n.to_f) unless rat_class
            rat_class.dispatch(context, :new, [IntegerObject.new(n.numerator), IntegerObject.new(n.denominator)], {})
          else IntegerObject.new(0)
          end
        end

        public

        private

        def enum_for_str_upto(v, other, exclusive)
          # Return a bare Enumerator — reuse kernel_to_enum pattern
          excl = exclusive.truthy?
          other_str = other.is_a?(StringObject) ? other : NilObject::NIL
          NativeBlock.new(source_location: nil, parameters_override: []) { }
          # Minimal: return an enumerator object via the VM's to_enum mechanism
          # For now, fall back to building the array and wrapping
          arr = []
          s = v.raw
          o = other_str.is_a?(StringObject) ? other_str.raw : ''
          s.upto(o, excl) { |x| arr << StringObject.new(x) }
          ArrayObject.new(arr)
        end

        def enum_for_no_block(context, v, method_name)
          v.dispatch(context, :to_enum, [SymbolObject.from(method_name)], {})
        end

        public

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

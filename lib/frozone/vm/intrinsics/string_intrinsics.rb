# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      # Global dedup table: maps raw MRI string → frozen StringObject
      STRING_DEDUP_TABLE = {}

      # Proxy for Hash args to support named format references %{name},
      # %<name>s in `Intrinsics.string_format`. Inherits from Hash so MRI's
      # % operator treats it as a hash type directly. Module-level so
      # box-first codegen can resolve the constant from the eigenclass-
      # method bodies that reference it. Unreachable in box-first runtime
      # (the `Intrinsics.interpreted?` guard skips the proxy path).
      class HashFormatProxy < Hash
        attr_reader :frozone_vm_hash

        def initialize(h, vm_hash = FNIL)
          @frozone_vm_hash = vm_hash
          super()
          update(h)
        end
      end

      # Proxy class for Frozone ObjectObjects in sprintf. Module-level
      # for the same codegen-resolution reason as HashFormatProxy above.
      class FormatProxy
        def initialize(vm_obj, context)
          @vm_obj = vm_obj
          @context = context
        end

        def to_s
          r = @vm_obj.dispatch(@context, :to_s, [], {})
          Intrinsics.fstr?(r) ? r.raw : @vm_obj.to_s
        rescue Frozone::Vm::FrozoneException => e
          # Let NoMethodError propagate (e.g. BasicObject without to_s)
          raise if e.vm_object.is_a?(ObjectObject) && e.vm_object.class_object&.name == :NoMethodError
          @vm_obj.to_s
        end

        def inspect
          r = @vm_obj.dispatch(@context, :inspect, [], {}) rescue nil
          Intrinsics.fstr?(r) ? r.raw : @vm_obj.to_s
        end

        # to_ary is dispatched through Frozone for mock support
        # Returns nil (not array), array, or non-array (so MRI raises TypeError)
        def to_ary
          r = @vm_obj.dispatch(@context, :to_ary, [], {})
          return nil if Intrinsics.fnil?(r)
          if Intrinsics.farray?(r)
            r.raw.map { |a| Intrinsics.fobj?(a) ? a.raw : a }
          else
            # Return non-array value so MRI raises TypeError
            Intrinsics.fobj?(r) ? r.raw : r.to_s
          end
        rescue Frozone::Vm::FrozoneException
          nil
        end

        def to_int
          r = @vm_obj.dispatch(@context, :to_int, [], {})
          raise TypeError, "can't convert #{@vm_obj.class_object&.name} into Integer" unless Intrinsics.fint?(r)
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
          Intrinsics.fint?(r) ? r.raw : 0
        rescue Frozone::Vm::FrozoneException => e
          vm_obj = e.vm_object
          if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
            raise TypeError, "no implicit conversion of #{@vm_obj.class_object&.name} into Integer"
          end
          raise TypeError, e.message
        end

        def to_f
          r = @vm_obj.dispatch(@context, :to_f, [], {})
          raise TypeError, "can't convert #{@vm_obj.class_object&.name} into Float" unless Intrinsics.ffloat?(r)
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
          return r.raw if Intrinsics.fstr?(r)
          return nil if Intrinsics.fnil?(r)
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

        def method_missing(name, *args) = Intrinsics.fobj?(@vm_obj) ? @vm_obj.raw.send(name, *args) : super
      end

      class << self
        # `:__unset__` is the sentinel used as a default value for
        # optional positional params in core/4.0/ Ruby code (e.g.
        # `def slice(idx, len = :__unset__)`). When that default kicks
        # in for a Frozone-Ruby method call and is then forwarded to an
        # Intrinsics.* call, the value arriving here is a SymbolObject
        # wrapping `:__unset__`, NOT a raw Ruby Symbol. SymbolObject
        # doesn't override `==`, so `len == :__unset__` is identity-
        # compare and false. Compare via the raw value instead.
        # (Pre-arity-unification of slice/byteslice in
        # `lib/core/4.0/string.rb`, the ternary `len.equal?(:__unset__)
        # ? Intrinsics.string_slice(self, idx) : ...` worked around
        # this by NOT passing len in the unset case — the intrinsic's
        # own `:__unset__` default kicked in (raw Ruby Symbol), and
        # the comparison stayed within raw Symbols. After unification
        # the intrinsic always receives the SymbolObject form, so the
        # check has to handle it.)
        def unset_marker?(v)
          return true if v.equal?(:__unset__)
          return true if v.is_a?(SymbolObject) && v.raw == :__unset__
          false
        end

        # String
        def string_bytesize(_, v) = n2f_int(v.raw.bytesize)
        def string_get_byte(_, v, i) = (b = v.raw.getbyte(fint?(i) ? i.raw : i.to_i); b ? n2f_int(b) : FNIL)
        def string_inspect(_, v) = n2f_str(v.raw.inspect)
        def string_crypt(_, v, salt) = n2f_str(v.raw.crypt(salt.raw))
        def string_hash(_, v) = n2f_int(v.raw.hash)
        def string_eql(_, v1, v2) = n2f_bool(fstr?(v2) && v1.raw == v2.raw)
        def string_ord(_, v) = n2f_int(v.raw.ord)
        def string_chars(_, v) = n2f_arr(v.raw.chars.map { |p| n2f_str(p) })

        def string_spaceship_raw(_, v1, v2) = n2f_int(v1.raw <=> v2.raw)

        def string_split(context, v, sep = FNIL, limit = FNIL)
          sep = nil if fnil?(sep)

          # Detect :__unset__ sentinel (limit not provided)
          limit_unset = fsym?(limit) && limit.raw == :__unset__

          unless limit_unset
            # Explicit nil for limit raises TypeError
            if fnil?(limit)
              raise FrozoneException.make(:TypeError, "no implicit conversion from nil to integer")
            end

            # Coerce limit to integer
            unless fnil?(limit) || fint?(limit)
              begin
                limit = limit.dispatch(context, :to_int, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion into Integer") unless fint?(limit)
              rescue FrozoneException => e
                vm_obj = e.vm_object
                if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{e.message.split.last} into Integer")
                end
                raise
              end
            end
          end

          limit = nil if limit_unset
          limit_raw = fint?(limit) ? limit.raw : nil

          # Use $; when sep is nil
          gs = nil
          if sep.nil? || fnil?(sep)
            gs = GLOBALS[:"$;"]
            gs = nil if fnil?(gs)
          end

          # Determine the raw separator
          sep_raw = if (sep.nil? || fnil?(sep)) && gs.nil?
                      nil
                    elsif sep.nil? || fnil?(sep)
                      fstr?(gs) ? gs.raw : gs.raw
                    elsif fstr?(sep) || sep.is_a?(RegexpObject)
                      sep.raw
                    else
                      begin
                        coerced = sep.dispatch(context, :to_str, [], {})
                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{sep.class_object&.name || 'Object'} into String") unless fstr?(coerced)
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
          n2f_arr(parts.map { |p| n2f_str(p) })
        end

        def extract_pattern(context, pattern)
          return pattern.raw if fstr?(pattern) || pattern.is_a?(RegexpObject)
          if pattern.is_a?(ObjectObject)
            r = pattern.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if fstr?(r)
          end
          name = pattern.is_a?(ObjectObject) ? (pattern.class_object&.name || 'Object').to_s : pattern.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def extract_string_replacement(context, replacement)
          return replacement.raw if fstr?(replacement)
          if replacement.is_a?(ObjectObject)
            r = replacement.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if fstr?(r)
          end
          name = replacement.is_a?(ObjectObject) ? (replacement.class_object&.name || 'Object').to_s : replacement.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def block_result_to_s(context, val)
          return val.raw if fstr?(val)
          r = val.dispatch(context, :to_s, [], {}) rescue nil
          fstr?(r) ? r.raw : val.to_s
        end

        def string_gsub(context, v, pattern, replacement = FNIL, block = FNIL)
          pat = extract_pattern(context, pattern)
          has_block = !fnil?(block)
          has_replacement = !fnil?(replacement)
          if has_block && !has_replacement
            last_m = nil
            # Method references (BoundMethodObject) don't get $~ set (only Proc/lambda do)
            # When &method(:foo) is passed, it arrives wrapped in ProcObject by Method#invoke
            inner = block.is_a?(ProcObject) ? block.block_object : block
            set_match_for_block = !inner.is_a?(BoundMethodObject)
            result = v.raw.gsub(pat) do |_match|
              m = $~
              last_m = m
              gsub_apply_block(context, block, set_match_for_block, m)
            end
            update_match_globals(last_m)
            n2f_str(result)
          elsif fnil?(replacement)
            # Explicit nil replacement → TypeError (no-replacement case handled in string.rb)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          elsif fhash?(replacement)
            last_m = nil
            result = v.raw.gsub(pat) do |match|
              last_m = $~
              key = n2f_str(match)
              r = replacement.dispatch(context, :[], [key], {})
              fnil?(r) ? '' : block_result_to_s(context, r)
            end
            update_match_globals(last_m)
            n2f_str(result)
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
            n2f_str(v.raw.gsub(pat, repl_raw))
          end
        end

        def string_sub(context, v, pattern, replacement = FNIL, block = FNIL)
          pat = extract_pattern(context, pattern)
          has_block = !fnil?(block)
          has_replacement = !fnil?(replacement)
          if has_block && !has_replacement
            the_m = nil
            result = v.raw.sub(pat) do |_match|
              m = $~
              update_match_globals(m)
              the_m = m
              match_obj = n2f_str(::Regexp.last_match(0))
              ret = block_result_to_s(context, block.invoke(context, [match_obj]))
              update_match_globals(m)
              ret
            end
            update_match_globals(the_m)
            n2f_str(result)
          elsif fnil?(replacement)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          elsif fhash?(replacement)
            first_m = nil
            result = v.raw.sub(pat) do |match|
              first_m = $~
              key = n2f_str(match)
              r = replacement.dispatch(context, :[], [key], {})
              fnil?(r) ? '' : block_result_to_s(context, r)
            end
            update_match_globals(first_m)
            n2f_str(result)
          else
            repl_raw = extract_string_replacement(context, replacement)
            m = if pat.is_a?(::Regexp)
                  pat.match(v.raw)
                else
                  i = v.raw.index(pat)
                  i ? ::Regexp.new(::Regexp.escape(pat)).match(v.raw, i) : nil
                end
            update_match_globals(m)
            n2f_str(v.raw.sub(pat, repl_raw))
          end
        end

        def string_tr_raw(_, v, from, to) = n2f_str(v.raw.tr(from.raw, to.raw))
        def string_squeeze_raw(_, v, *args) = args.empty? ? n2f_str(v.raw.squeeze) : n2f_str(v.raw.squeeze(*args.map(&:raw)))
        def string_count_raw(_, v, *args) = n2f_int(v.raw.count(*args.map(&:raw)))
        def string_delete_raw(_, v, *args) = n2f_str(v.raw.delete(*args.map(&:raw)))

        private

        # Called inside a native gsub/sub block to invoke the Frozone block and return the replacement string.
        # Handles $~ lifecycle for Proc blocks (set and restore) vs BoundMethod blocks (clear/restore).
        def gsub_apply_block(context, block, set_match_for_block, m)
          match_obj = n2f_str(m[0])
          if set_match_for_block
            update_match_globals(m)
            ret = block_result_to_s(context, block.invoke(context, [match_obj]))
            # Restore $~ to the gsub match after block runs (block may have changed it)
            update_match_globals(m)
            ret
          else
            # BoundMethodObject: $~ is method-local in MRI; clear before invoke, restore after
            saved_md = GLOBALS[:"$~"]
            update_match_globals(nil)
            ret = block_result_to_s(context, block.invoke(context, [match_obj]))
            GLOBALS[:"$~"] = saved_md
            ret
          end
        end

        def coerce_str_args(context, args)
          args.map do |a|
            if fstr?(a)
              a.raw
            elsif a.is_a?(ObjectObject)
              begin
                r = a.dispatch(context, :to_str, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{a.class_object&.name} into String") unless fstr?(r)
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
        def string_slice(context, v, idx, len = :__unset__)
          if idx.is_a?(RegexpObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if len != :__unset__ && fnil?(len)
            m = idx.raw.match(v.raw)
            update_match_globals(m)
            unless unset_marker?(len) || fnil?(len)
              # len can be Integer (capture index), String/Symbol (named capture), or to_int-able
              cap_idx = if fint?(len)
                          len.raw
                        elsif fstr?(len) || fsym?(len)
                          len.raw
                        else
                          str_vm_coerce_to_int(context, len)
                        end
              if m
                cap = reraise(IndexError) { m[cap_idx] }
                return cap ? n2f_str(cap) : FNIL
              else
                return FNIL
              end
            end
            return m ? n2f_str(m[0]) : FNIL
          end
          # String index: substring search
          if fstr?(idx)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String") unless unset_marker?(len)
            result = v.raw[idx.raw]
            return result.nil? ? FNIL : n2f_str(result)
          end
          # Range index
          if idx.is_a?(RangeObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into Range") unless unset_marker?(len)
            # Coerce range bounds if needed
            b = idx.begin_val
            e = idx.end_val
            b_raw = fnil?(b) ? nil : (fint?(b) ? b.raw : str_vm_coerce_to_int(context, b))
            e_raw = fnil?(e) ? nil : (fint?(e) ? e.raw : str_vm_coerce_to_int(context, e))
            range = Range.new(b_raw, e_raw, idx.exclusive?)
            result = reraise(TypeError) { v.raw[range] }
            return result.nil? ? FNIL : n2f_str(result)
          end
          # Coerce idx to Integer
          idx_i = if fint?(idx)
                    idx.raw
                  else
                    str_vm_coerce_to_int(context, idx)
                  end
          # Coerce len to Integer if provided
          if unset_marker?(len)
            result = reraise(TypeError, RangeError) { v.raw[idx_i] }
          else
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if fnil?(len)
            len_i = fint?(len) ? len.raw : str_vm_coerce_to_int(context, len)
            result = reraise(TypeError, RangeError) { v.raw[idx_i, len_i] }
          end
          result.nil? ? FNIL : n2f_str(result)
        end

        def str_vm_coerce_to_int(context, obj)
          raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if fnil?(obj)
          unless fobj?(obj)
            return obj.raw.is_a?(Integer) ? obj.raw : (raise FrozoneException.make(:TypeError, "no implicit conversion into Integer"))
          end
          # Check respond_to?(:to_int, true) first (matches MRI rb_check_convert_type behavior)
          begin
            rt_result = obj.dispatch(context, :respond_to?, [n2f_sym(:to_int), FTRUE], {})
            unless rt_result.truthy?
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object&.name} into Integer")
            end
          rescue FrozoneException
            # respond_to? not found or raised - fall through to direct dispatch
          end
          begin
            coerced = obj.dispatch(context, :to_int, [], {})
            fint?(coerced) ? coerced.raw : (raise FrozoneException.make(:TypeError, "to_int should return Integer"))
          rescue FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object&.name} into Integer")
            end
            raise
          end
        end

        def string_index(context, v, sub, offset = FNIL)
          pat = coerce_str_or_regexp(context, sub)
          off_raw = coerce_offset(context, offset)
          begin
            result = off_raw ? v.raw.index(pat, off_raw) : v.raw.index(pat)
            if pat.is_a?(::Regexp)
              m = result ? pat.match(v.raw, result) : nil
              update_match_globals(m)
            end
            result.nil? ? FNIL : n2f_int(result)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::TypeError => e then raise FrozoneException.make(:TypeError, e.message)
          end
        end

        def string_rindex(context, v, sub, offset = FNIL)
          if fint?(sub) || (sub.is_a?(ObjectObject) && sub.class_object&.name == :Integer)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String")
          end
          pat = coerce_str_or_regexp(context, sub)
          off_raw = coerce_offset(context, offset)
          begin
            result = off_raw ? v.raw.rindex(pat, off_raw) : v.raw.rindex(pat)
            if pat.is_a?(::Regexp)
              m = result ? pat.match(v.raw, result) : nil
              update_match_globals(m)
            end
            result.nil? ? FNIL : n2f_int(result)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::TypeError => e then raise FrozoneException.make(:TypeError, e.message)
          end
        end

        private

        def deprecated_warnings_enabled?
          warning_class = Core::OBJECT_CLASS.get_constant(:Warning)
          return true unless warning_class
          ctx = Fiber[:context]
          return true unless ctx
          flag = warning_class.dispatch(ctx, :[], [n2f_sym(:deprecated)], {}) rescue nil
          flag.nil? || flag.truthy?
        rescue
          true
        end

        def coerce_str_or_regexp(context, sub)
          return sub.raw if fstr?(sub) || sub.is_a?(RegexpObject)
          if fnil?(sub) || ftrue?(sub) || ffalse?(sub)
            name = sub.class_object&.name || sub.class.name
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
          end
          if sub.is_a?(ObjectObject)
            begin
              r = sub.dispatch(context, :to_str, [], {})
              return r.raw if fstr?(r)
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name} into String")
            rescue FrozoneException => e
              vm_obj = e.vm_object
              if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name} into String")
              end
              raise
            end
          end
          fobj?(sub) ? sub.raw : sub.to_s
        end

        def coerce_offset(context, offset)
          return nil if fnil?(offset)
          return nil if fsym?(offset) && offset.raw == :__unset__
          return offset.raw if fint?(offset)
          str_vm_coerce_to_int(context, offset)
        end

        public

        def string_succ(_, v) = n2f_str(v.raw.succ)
        def string_b(_, v) = n2f_str(v.raw.b)
        def string_ascii_only(_, v) = n2f_bool(v.raw.ascii_only?)

        def string_dedup(_, v)
          raw = v.raw
          # skip dedup for strings with instance variables
          return v if v.frozen_object? && v.instance_variables_hash.any?
          key = "#{raw.b}\x00#{raw.encoding.name}"
          existing = STRING_DEDUP_TABLE[key]
          if existing
            existing
          else
            if v.frozen_object?
              v.mark_deduped!
              STRING_DEDUP_TABLE[key] = v
              v
            else
              new_str = n2f_str(raw.dup)
              new_str.freeze_object!
              new_str.mark_deduped!
              STRING_DEDUP_TABLE[key] = new_str
              new_str
            end
          end
        end

        def string_replace(context, v, other)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          if v.chilled? && deprecated_warnings_enabled?
            Frozone::Vm.emit_warning(context, v.chilled_warning)
            v.unchilled!
          end
          other_raw = if fstr?(other)
                        other.raw
                      elsif fnil?(other)
                        raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                      elsif other.is_a?(ObjectObject)
                        r = begin
                          other.dispatch(context, :to_str, [], {})
                        rescue FrozoneException
                          nil
                        end
                        unless fstr?(r)
                          raise FrozoneException.make(:TypeError, "no implicit conversion of #{other.class_object&.name || 'Object'} into String")
                        end
                        r.raw
                      else
                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{other.class_object&.name || other.class} into String")
                      end
          v.raw = other_raw.dup
          v
        end

        def string_succ_bang(_, v)
          v.raw = v.raw.succ
          v
        end

        def string_insert(_, v, index, str)
          idx = fint?(index) ? index.raw : index.is_a?(Integer) ? index : index.to_i
          s = fstr?(str) ? str.raw : str.to_s
          v.raw = reraise(::IndexError) { v.raw.dup.insert(idx, s) }
          v
        end

        def string_slice_bang(context, v, idx, len = FNIL)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # Coerce idx
          if idx.is_a?(RangeObject)
            b = idx.begin_val
            e = idx.end_val
            b_raw = fnil?(b) ? nil : (fint?(b) ? b.raw : str_vm_coerce_to_int(context, b))
            e_raw = fnil?(e) ? nil : (fint?(e) ? e.raw : str_vm_coerce_to_int(context, e))
            idx_ruby = Range.new(b_raw, e_raw, idx.exclusive?)
          elsif fint?(idx)
            idx_ruby = idx.raw
          elsif idx.is_a?(RegexpObject)
            idx_ruby = idx.raw
          elsif fstr?(idx)
            idx_ruby = idx.raw
          else
            idx_ruby = str_vm_coerce_to_int(context, idx)
          end
          len_ruby = if fnil?(len)
                       nil
                     elsif fint?(len)
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
          result.nil? ? FNIL : n2f_str(result)
        end

        def string_coerce_replacement(context, repl)
          return repl.raw if fstr?(repl)
          if fint?(repl)
            raise FrozoneException.make(:TypeError, "no implicit conversion of Integer into String")
          end
          if fnil?(repl)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
          end
          begin
            coerced = repl.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{repl.class_object&.name || 'Object'} into String") unless fstr?(coerced)
            coerced.raw
          rescue FrozoneException => e
            vm_obj = e.vm_object
            if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{repl.class_object&.name || 'Object'} into String")
            end
            raise
          end
        end

        def string_store(context, v, idx, rest)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # `rest` is the guest ArrayObject of trailing args ([value] or
          # [length, value]); operate on its host array of VM elements.
          rest = rest.raw.dup
          repl_vm = rest.pop

          s = v.raw.dup
          begin
            if idx.is_a?(RegexpObject)
              # Check match BEFORE coercing replacement
              pat = idx.raw
              if rest.empty?
                m = pat.match(s)
                raise FrozoneException.make(:IndexError, "regexp not matched") unless m
                repl_raw = string_coerce_replacement(context, repl_vm)
                update_match_globals(m)
                s[pat] = repl_raw
              else
                cap_vm = rest[0]
                cap = fint?(cap_vm) ? cap_vm.raw : str_vm_coerce_to_int(context, cap_vm)
                m = pat.match(s)
                raise FrozoneException.make(:IndexError, "regexp not matched") unless m
                # Validate capture index BEFORE coercing replacement
                if cap >= m.size || cap < -m.size
                  raise FrozoneException.make(:IndexError, "index #{cap} out of regexp")
                end
                repl_raw = string_coerce_replacement(context, repl_vm)
                update_match_globals(m)
                s[pat, cap] = repl_raw
              end
            else
              repl_raw = string_coerce_replacement(context, repl_vm)
              if fint?(idx)
                i = idx.raw
                if rest.empty?
                  s[i] = repl_raw
                else
                  len_vm = rest[0]
                  len = fint?(len_vm) ? len_vm.raw : str_vm_coerce_to_int(context, len_vm)
                  s[i, len] = repl_raw
                end
              elsif fstr?(idx)
                pat = idx.raw
                raise FrozoneException.make(:IndexError, "string not matched") unless s.include?(pat)
                s[pat] = repl_raw
              elsif idx.is_a?(RangeObject)
                b = idx.begin_val
                e = idx.end_val
                b_raw = fnil?(b) ? nil : (fint?(b) ? b.raw : str_vm_coerce_to_int(context, b))
                e_raw = fnil?(e) ? nil : (fint?(e) ? e.raw : str_vm_coerce_to_int(context, e))
                s[Range.new(b_raw, e_raw, idx.exclusive?)] = repl_raw
              else
                i = str_vm_coerce_to_int(context, idx)
                if rest.empty?
                  s[i] = repl_raw
                else
                  len_vm = rest[0]
                  len = fint?(len_vm) ? len_vm.raw : str_vm_coerce_to_int(context, len_vm)
                  s[i, len] = repl_raw
                end
              end
            end
          rescue ::IndexError => e then raise FrozoneException.make(:IndexError, e.message)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          v.raw = s
          repl_vm
        end

        def string_each_line(context, v, sep, block)
          if fnil?(sep)
            # nil separator: yield entire string as one chunk
            if fnil?(block)
              return n2f_arr([n2f_str(v.raw.dup)])
            end
            block.invoke(context, [n2f_str(v.raw.dup)])
            return v
          end
          # Coerce separator to string
          sep_raw = if fstr?(sep)
                      sep.raw
                    elsif fsym?(sep)
                      raise FrozoneException.make(:TypeError, "no implicit conversion of Symbol into String")
                    elsif sep.is_a?(ObjectObject)
                      begin
                        r = sep.dispatch(context, :to_str, [], {})
                        raise FrozoneException.make(:TypeError, "no implicit conversion into String") unless fstr?(r)
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
            if fnil?(block)
              n2f_arr(v.raw.each_line(sep_raw).map { |l| n2f_str(l) })
            else
              v.raw.each_line(sep_raw) { |l| block.invoke(context, [n2f_str(l)]) }
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
            if fnil?(block)
              n2f_arr([n2f_str(v.raw.dup)])
            else
              block.invoke(context, [n2f_str(v.raw.dup)])
              v
            end
          rescue ::Encoding::ConverterNotFoundError => e
            wrapped = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(wrapped, e.message)
          end
        end

        def string_concat(context, v1, v2)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v1.raw.inspect}") if v1.frozen?
          if v1.chilled? && deprecated_warnings_enabled?
            Frozone::Vm.emit_warning(context, v1.chilled_warning)
            v1.unchilled!
          end
          v2_str = fstr?(v2) ? v2.raw : v2.to_s
          v1.raw << v2_str
          v1
        end

        def string_concat_codepoint(_, v1, n)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v1.raw.inspect}") if v1.frozen?
          codepoint = fint?(n) ? n.raw : n.to_i
          raise FrozoneException.make(:RangeError, "invalid codepoint #{codepoint} in #{v1.raw.encoding}") if codepoint < 0
          reraise(RangeError) do
            enc = v1.raw.encoding
            # US-ASCII with value 128..255: switch to BINARY
            if enc == ::Encoding::US_ASCII && codepoint >= 128 && codepoint <= 255
              v1.raw.force_encoding(::Encoding::BINARY)
              v1.raw << codepoint
            else
              v1.raw << codepoint.chr(enc)
            end
          end
          v1
        end

        def string_multiply(_, v, n)
          count = fint?(n) ? n.raw : (fobj?(n) ? n.raw.to_i : n.to_i)
          raise FrozoneException.make(:ArgumentError, "negative string size (or exceeds maximum allowed string size)") if count < 0
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if count > LONG_MAX
          str = v.raw
          raise FrozoneException.make(:ArgumentError, "argument exceeds the limit") if !str.empty? && count > MRI_MAX_SIZE
          n2f_str(str * count)
        end

        def string_format(context, v, args)
          # Sync Frozone's $DEBUG with MRI so unused-arg check works
          frozone_debug = GLOBALS[:"$DEBUG"]
          saved_debug = $DEBUG
          $DEBUG = frozone_debug.truthy? if frozone_debug
          begin
            if farray?(args)
              raw_args = args.raw.map { |a| frozone_to_format_proxy(context, a) }
              n2f_str(v.raw % raw_args)
            elsif fhash?(args)
              # Named reference format %{name} or %<name>s — pass as hash, not array
              raw_arg = frozone_to_format_proxy(context, args)
              n2f_str(v.raw % raw_arg)
            else
              raw_arg = frozone_to_format_proxy(context, args)
              n2f_str(v.raw % raw_arg)
            end
          rescue ::TypeError => e
            # Normalize MRI's "no implicit conversion from X to Y" to "no implicit conversion of X into Y"
            msg = e.message.gsub(/\Ano implicit conversion from (.+) to (.+)\z/) {
              "no implicit conversion of #{::Regexp.last_match(1)} into #{::Regexp.last_match(2).split.map(&:capitalize).join}"
            }
            raise FrozoneException.make(:TypeError, msg)
          rescue ::ArgumentError => e then raise FrozoneException.make(:ArgumentError, e.message)
          rescue ::KeyError => e
            exc = FrozoneException.wrap_mri(e)
            # Set receiver to the original Frozone HashObject (not the MRI proxy)
            frozone_receiver = if fhash?(args)
                                 args
                               elsif Intrinsics.interpreted?(self) &&
                                     e.respond_to?(:receiver) && e.receiver.is_a?(HashFormatProxy)
                                 # box-first/self-host: HashFormatProxy isn't
                                 # codegen-resolvable from here (#155 sibling);
                                 # `args` is the FrozoneException's @receiver
                                 # path above (fhash?). For the rare format-
                                 # error coming from a plain MRI hash receiver,
                                 # report it without wrapping.
                                 e.receiver.frozone_vm_hash
                               end
            exc.set_ivar(:@receiver, frozone_receiver) if frozone_receiver
            if e.respond_to?(:key) && e.key
              mri_key = e.key
              frozone_key = mri_key.is_a?(::Symbol) ? n2f_sym(mri_key) : n2f_str(mri_key.to_s)
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
          return arg.raw if fstr?(arg) || fint?(arg) ||
                            ffloat?(arg) || fsym?(arg)
          return nil if fnil?(arg)
          return arg.raw if ftrue?(arg) || ffalse?(arg)
          return arg.raw if arg.is_a?(RegexpObject)
          if fhash?(arg)
            # Convert to MRI hash with symbol keys for named references %{name}, %<name>s
            h = {}
            arg.raw.each do |k, v|
              mri_key = fsym?(k) ? k.raw : fobj?(k) ? k.raw.to_sym : k.to_sym
              mri_val = frozone_to_format_proxy(context, v)
              h[mri_key] = mri_val
            end
            # box-first/self-host: skip HashFormatProxy (#155 sibling) — the
            # class definition is in `class << self` and the codegen doesn't
            # resolve it cleanly from this method body. The default-proc /
            # default-value propagation below also needs MRI host Hash behaviour
            # (default_proc setter, MRI block dispatch) that box-first doesn't
            # implement. Returning a plain host Hash is sufficient for the
            # common %s / %d / non-default cases mspec exercises.
            return h unless Intrinsics.interpreted?(self)
            proxy = HashFormatProxy.new(h, arg)
            # Propagate Frozone hash default so %{missing} works with Hash.new(default)
            if arg.default_block && !fnil?(arg.default_block)
              fz_block = arg.default_block
              fz_ctx = context
              proxy.default_proc = proc { |_h, k|
                sym_key = k.is_a?(::Symbol) ? n2f_sym(k) : n2f_str(k.to_s)
                result = fz_block.invoke(fz_ctx, [arg, sym_key]) rescue FNIL
                frozone_to_format_proxy(fz_ctx, result)
              }
            elsif arg.default_value && !fnil?(arg.default_value)
              proxy.default = frozone_to_format_proxy(context, arg.default_value)
            end
            proxy
          elsif arg.is_a?(ObjectObject)
            FormatProxy.new(arg, context)
          else
            fobj?(arg) ? arg.raw : arg
          end
        end

        public



        def string_encode(context, v, enc = FNIL, src_enc = FNIL, opts = FNIL)
          # Coerce options hash if it's a VM object
          opts = coerce_encode_opts(context, opts || {})

          enc_nil = fnil?(enc)
          src_nil = fnil?(src_enc)

          enc_name = if enc_nil
                       # Use Encoding.default_internal
                       di = begin
                         Core::OBJECT_CLASS.get_constant(:Encoding)&.dispatch(context, :default_internal, [], {})
                       rescue
                         nil
                       end
                       di && !fnil?(di) ? resolve_encoding_name(context, di) : nil
                     else
                       resolve_encoding_name(context, enc)
                     end

          src_name = src_nil ? nil : resolve_encoding_name(context, src_enc)
          enc_opts = extract_encode_opts(opts)
          xml_opt = enc_opts.delete(:xml)
          fallback_opt = enc_opts.delete(:fallback)

          newline_opts = %i[cr_newline crlf_newline universal_newline]
          has_newline_opt = enc_opts.any? { |k, v| newline_opts.include?(k) && v }
          has_replace_opt = enc_opts[:invalid] == :replace || enc_opts[:undef] == :replace
          return n2f_str(v.raw.dup) if enc_name.nil? && !xml_opt && !has_newline_opt && !has_replace_opt

          begin
            result = if xml_opt
                       encode_xml(v.raw, enc_name, xml_opt, enc_opts)
                     elsif fallback_opt
                       encode_with_fallback(context, v.raw, enc_name, fallback_opt, enc_opts)
                     elsif enc_name.nil? && (has_newline_opt || has_replace_opt)
                       # Encoding change within same encoding (invalid: :replace, newline conversion)
                       v.raw.encode(v.raw.encoding, **enc_opts)
                     elsif src_name
                       enc_opts.empty? ? v.raw.encode(enc_name, src_name) : v.raw.encode(enc_name, src_name, **enc_opts)
                     else
                       enc_opts.empty? ? v.raw.encode(enc_name) : v.raw.encode(enc_name, **enc_opts)
                     end
            n2f_str(result)
          rescue ::Encoding::UndefinedConversionError,
                 ::Encoding::InvalidByteSequenceError,
                 ::Encoding::ConverterNotFoundError,
                 ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        def string_encode_bang(context, v, enc = FNIL, src_enc = FNIL, opts = FNIL)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String") if v.frozen?
          opts = coerce_encode_opts(context, opts || {})
          enc_nil = fnil?(enc)
          enc_opts = extract_encode_opts(opts)
          has_replace_opt = enc_opts[:invalid] == :replace || enc_opts[:undef] == :replace
          if enc_nil
            # Check default_internal
            di = begin
              Core::OBJECT_CLASS.get_constant(:Encoding)&.dispatch(context, :default_internal, [], {})
            rescue
              nil
            end
            if di && !fnil?(di)
              enc = di
            elsif has_replace_opt
              # No target encoding but invalid: :replace — encode in-place (same encoding)
              begin
                v.raw.encode!(v.raw.encoding, **enc_opts)
              rescue ::Encoding::UndefinedConversionError,
                     ::Encoding::InvalidByteSequenceError,
                     ::Encoding::ConverterNotFoundError,
                     ::Encoding::CompatibilityError => e
                raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
              end
              return v
            else
              return v
            end
          end
          enc_name = resolve_encoding_name(context, enc)
          src_name = (src_enc && !fnil?(src_enc)) ? resolve_encoding_name(context, src_enc) : nil
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

        def coerce_encode_opts(context, opts)
          return {} if fnil?(opts)
          return opts.raw if fhash?(opts)
          return opts if opts.is_a?(::Hash)
          # Try to_hash coercion for mock objects
          begin
            result = opts.dispatch(context, :to_hash, [], {})
            return fhash?(result) ? result.raw : {}
          rescue
          end
          {}
        end

        def extract_encode_opts(opts)
          return {} unless opts.is_a?(::Hash)
          result = {}
          opts.each do |k, v|
            key = fsym?(k) ? k.raw : k.is_a?(Symbol) ? k : nil
            next unless key
            val = if fsym?(v) then v.raw
                  elsif fnil?(v) then nil
                  elsif fstr?(v) then v.raw
                  elsif ftrue?(v) then true
                  elsif ffalse?(v) then false
                  elsif fint?(v) then v.raw
                  else
                    v
                  end
            result[key] = val
          end
          result
        end

        def encode_xml(raw_str, enc_name, xml_opt, enc_opts)
          # Validate xml option
          unless xml_opt == :text || xml_opt == :attr
            raise FrozoneException.make(:ArgumentError, "unknown xml option value: #{xml_opt.inspect}")
          end
          # Process string char by char
          result = String.new("")
          raw_str.each_char do |ch|
            if enc_name
              begin
                ch.encode(enc_name, **enc_opts)
                # char is encodable — apply XML entity encoding
                result << case ch
                          when '&' then '&amp;'
                          when '<' then '&lt;'
                          when '>' then '&gt;'
                          when '"' then (xml_opt == :attr ? '&quot;' : ch)
                          else ch
                          end
              rescue ::Encoding::UndefinedConversionError
                # Replace with hex numeric character reference (not entity-encoded)
                codepoint = ch.ord
                result << "&#x#{codepoint.to_s(16).upcase};"
              end
            else
              result << case ch
                        when '&' then '&amp;'
                        when '<' then '&lt;'
                        when '>' then '&gt;'
                        when '"' then (xml_opt == :attr ? '&quot;' : ch)
                        else ch
                        end
            end
          end
          result = "\"#{result}\"" if xml_opt == :attr
          enc_name ? result.force_encoding(enc_name) : result
        end

        def encode_with_fallback(context, raw_str, enc_name, fallback, enc_opts)
          # If invalid: :replace is set, first sanitize the string to remove invalid byte sequences
          # (MRI handles invalid sequences as units, not byte-by-byte via chars)
          working_str = if enc_opts[:invalid] == :replace
                          repl = enc_opts[:replace] || "?"
                          raw_str.encode(raw_str.encoding, invalid: :replace, replace: repl)
                        else
                          raw_str
                        end
          # Strip invalid: :replace from opts since we've already handled it
          fallback_enc_opts = enc_opts.reject { |k, _| k == :invalid }

          # Implement fallback encoding manually since MRI doesn't support VM procs as fallback
          chars = working_str.chars
          result = enc_name ? String.new("", encoding: Encoding.find(enc_name)) : String.new("")
          chars.each do |ch|
            begin
              encoded_ch = ch.encode(enc_name || ch.encoding, **fallback_enc_opts)
              result << encoded_ch
            rescue ::Encoding::UndefinedConversionError
              # Apply fallback to get replacement for undefined char
              replacement_vm = call_fallback(context, fallback, ch)
              if replacement_vm
                replacement_raw = if fstr?(replacement_vm)
                                    replacement_vm.raw
                                  elsif replacement_vm.is_a?(::String)
                                    replacement_vm
                                  elsif replacement_vm.is_a?(ObjectObject)
                                    begin
                                      r = replacement_vm.dispatch(context, :to_str, [], {})
                                      f2n_raw(r)
                                    rescue FrozoneException => e
                                      vm = e.vm_object
                                      if vm.is_a?(ObjectObject) && vm.class_object&.name == :NoMethodError
                                        type_name = replacement_vm.class_object&.name || 'Object'
                                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{type_name} into String")
                                      end
                                      raise
                                    end
                                  else
                                    nil
                                  end
                if replacement_raw.nil?
                  raise
                end
                begin
                  encoded_repl = replacement_raw.encode(enc_name)
                  result << encoded_repl
                rescue ::Encoding::UndefinedConversionError
                  raise ::ArgumentError, "too big fallback string"
                end
              else
                raise
              end
            end
          end
          result
        end

        def call_fallback(context, fallback, ch)
          if fhash?(fallback)
            # VM-level Hash
            ch_obj = n2f_str(ch)
            val = fallback.raw.find { |k, _| fstr?(k) && k.raw == ch }&.last
            val ||= begin
              fallback.dispatch(context, :default, [ch_obj], {})
            rescue FrozoneException
              nil
            end
            fnil?(val) ? nil : val
          elsif fallback.is_a?(::Hash)
            val = fallback[ch]
            val = fallback.default if val.nil? && fallback.default
            val
          elsif fallback.is_a?(ProcObject)
            begin
              fallback.invoke(context, [n2f_str(ch)])
            rescue FrozoneException
              nil
            end
          elsif fallback.is_a?(ObjectObject)
            # Try calling it as a proc/method (responds to :call)
            begin
              fallback.dispatch(context, :call, [n2f_str(ch)], {})
            rescue FrozoneException => e
              vm = e.vm_object
              if vm.is_a?(ObjectObject) && vm.class_object&.name == :NoMethodError
                # Try [] for hash-like objects
                begin
                  fallback.dispatch(context, :[], [n2f_str(ch)], {})
                rescue FrozoneException
                  nil
                end
              else
                raise
              end
            end
          else
            nil
          end
        end

        def resolve_encoding_name(context, enc)
          if fstr?(enc)
            enc.raw
          elsif enc.is_a?(ObjectObject)
            # Only use @name ivar if this is actually an Encoding object
            if enc.class_object&.name == :Encoding
              name_ivar = enc.get_ivar(:@name)
              return name_ivar.raw if name_ivar && fstr?(name_ivar)
              # Try :name method
              begin
                r = enc.dispatch(context, :name, [], {})
                return r.raw if fstr?(r)
              rescue FrozoneException
              end
            end
            # Try to_str coercion
            begin
              r = enc.dispatch(context, :to_str, [], {})
              return r.raw if fstr?(r)
              return r.to_s if r.is_a?(::String)  # mspec mock may return raw String
            rescue FrozoneException => e
              vm_obj = e.vm_object
              unless vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                raise
              end
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

        def string_chilled_q(_, v) = n2f_bool(v.chilled?)
        def string_frozen(_, v) = n2f_bool(v.frozen_object?)
        def string_to_sym(_, v) = n2f_sym(v.raw.to_sym)
        def string_to_f(_, v) = n2f_float(v.raw.to_f)
        def string_to_r(_, v) = make_rational(v.raw.to_r)
        def string_to_i_base(_, v, base) = n2f_int(v.raw.to_i(fint?(base) ? base.raw : 0))

        def string_force_encoding(context, v, enc)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen_object?
          enc_name = if fstr?(enc)
                       enc.raw
                     elsif fsym?(enc)
                       enc.raw.to_s
                     elsif fnil?(enc)
                       raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                     elsif enc.is_a?(ObjectObject)
                       # Check if it's actually an Encoding instance (not just any object with @name)
                       if enc.class_object&.name == :Encoding
                         begin
                           r = enc.dispatch(context, :name, [], {})
                           fstr?(r) ? r.raw : (enc.get_ivar(:@name)&.raw || enc.to_s)
                         rescue FrozoneException
                           enc.get_ivar(:@name)&.raw || enc.to_s
                         end
                       else
                         # Try to_str coercion
                         begin
                           coerced = enc.dispatch(context, :to_str, [], {})
                           raise FrozoneException.make(:TypeError, "no implicit conversion of #{enc.class_object&.name} into String") unless fstr?(coerced)
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
          reraise(::ArgumentError) { v.raw.force_encoding(enc_name) }
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
              if fnil?(int)
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
          return n2f_str(enc_name) unless enc_class
          const_name = enc_name.tr('-', '_').to_sym
          enc_class.get_constant(const_name) || n2f_str(enc_name)
        end

        def string_freeze(_, v)
          v.freeze_object!
          v
        end

        def string_dup(context, v)
          copy = n2f_str(v.raw.dup)
          copy.class_object = v.class_object
          copy.copy_fields_from(v, eigenclass: nil, frozen: false)
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
        end

        def string_match(context, v, pattern)
          if fstr?(pattern)
            pat = Regexp.new(pattern.raw)
            m = pat.match(v.raw)
            update_match_globals(m)
            return m ? MatchDataObject.new(m) : FNIL
          end
          if pattern.is_a?(RegexpObject)
            m = pattern.raw.match(v.raw)
            update_match_globals(m)
            return m ? MatchDataObject.new(m) : FNIL
          end
          if fint?(pattern) || ffloat?(pattern)
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{pattern.class_object&.name} into String")
          end
          # Non-regexp, non-string: try to_str coercion, then TypeError
          if pattern.is_a?(ObjectObject)
            begin
              coerced = pattern.dispatch(context, :to_str, [], {})
              if fstr?(coerced)
                pat = Regexp.new(coerced.raw)
                m = pat.match(v.raw)
                update_match_globals(m)
                return m ? MatchDataObject.new(m) : FNIL
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
          pat = fstr?(pattern) ? Regexp.new(pattern.raw) : pattern.raw
          pos_raw = fint?(pos) ? pos.raw : pos.to_i
          m = pat.match(v.raw, pos_raw)
          update_match_globals(m)
          m ? MatchDataObject.new(m) : FNIL
        end

        def string_match_q(_, v, pattern, pos)
          pat = fstr?(pattern) ? Regexp.new(pattern.raw) : pattern.raw
          str = v.raw
          raw_pos = f2n_raw(pos)
          result = raw_pos.nil? ? pat.match?(str) : pat.match?(str, raw_pos)
          n2f_bool(result)
        end

        def string_scan(context, v, pattern, block = FNIL)
          has_block = !fnil?(block)
          # For string pattern: use raw string (literal match). For regexp: use raw regexp.
          pat = if fstr?(pattern)
                  pattern.raw
                elsif pattern.is_a?(RegexpObject)
                  pattern.raw
                else
                  # Try to_str coercion
                  r = pattern.dispatch(context, :to_str, [], {}) rescue nil
                  if fstr?(r)
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
                block.invoke(context, [n2f_str(m[0])])
              else
                block.invoke(context, [n2f_arr(groups.map { |g| g ? n2f_str(g) : FNIL })])
              end
            end
            update_match_globals(last_m)
            v
          else
            scan_pat = pat.is_a?(::String) ? ::Regexp.new(::Regexp.escape(pat)) : pat
            last_m = nil
            results = v.raw.scan(scan_pat).map do |r|
              last_m = $~
              r.is_a?(::Array) ? n2f_arr(r.map { |s| n2f_str(s) }) : n2f_str(r)
            end
            update_match_globals(last_m)
            n2f_arr(results)
          end
        end

        # Byte-level primitives

        def string_valid_encoding(_, v) = n2f_bool(v.raw.valid_encoding?)
        def string_dump(_, v) = n2f_str(v.raw.dump, frozen: true)
        def string_oct(_, v) = n2f_int(v.raw.oct)
        def string_grapheme_clusters(_, v) = n2f_arr(v.raw.grapheme_clusters.map { |g| n2f_str(g) })
        def string_tr_s(_, v, from, to) = n2f_str(v.raw.tr_s(from.raw, to.raw))
        def string_getbyte(_, v, i) = (r = v.raw.getbyte(fint?(i) ? i.raw : i.to_i); r ? n2f_int(r) : FNIL)

        def string_setbyte(context, v, i, b)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          i_raw = fint?(i) ? i.raw : str_vm_coerce_to_int(context, i)
          b_raw = fint?(b) ? b.raw : str_vm_coerce_to_int(context, b)
          reraise(::IndexError) { v.raw.setbyte(i_raw, b_raw) }
          b
        end

        def string_append_as_bytes(context, v, *args)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          enc = v.raw.encoding
          # Collect bytes to append
          byte_str = "".b
          args.each do |arg|
            if fstr?(arg)
              byte_str << arg.raw.b
            elsif fint?(arg)
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

        def string_byteslice(context, v, idx, len = FNIL)
          result = reraise(::RangeError) do
            if idx.is_a?(RangeObject)
              b = idx.begin_val
              e = idx.end_val
              b_raw = fnil?(b) ? nil : (fint?(b) ? b.raw : str_vm_coerce_to_int(context, b))
              e_raw = fnil?(e) ? nil : (fint?(e) ? e.raw : str_vm_coerce_to_int(context, e))
              v.raw.byteslice(Range.new(b_raw, e_raw, idx.exclusive?))
            elsif !fnil?(len)
              idx_i = fint?(idx) ? idx.raw : str_vm_coerce_to_int(context, idx)
              len_i = fint?(len) ? len.raw : str_vm_coerce_to_int(context, len)
              v.raw.byteslice(idx_i, len_i)
            else
              idx_i = fint?(idx) ? idx.raw : str_vm_coerce_to_int(context, idx)
              v.raw.byteslice(idx_i)
            end
          end
          result.nil? ? FNIL : n2f_str(result)
        end

        def string_byteindex(context, v, sub, offset = FNIL)
          offset_raw = fnil?(offset) ? nil : (fint?(offset) ? offset.raw : str_vm_coerce_to_int(context, offset))
          is_regexp = sub.is_a?(RegexpObject)
          pat = if fstr?(sub)
                  sub.raw
                elsif is_regexp
                  sub.raw
                elsif fnil?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                elsif ftrue?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of true into String")
                elsif ffalse?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of false into String")
                elsif sub.is_a?(ObjectObject)
                  r = begin
                    sub.dispatch(context, :to_str, [], {})
                  rescue FrozoneException
                    nil
                  end
                  fstr?(r) ? r.raw : raise(FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || 'Object'} into String"))
                else
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || sub.class} into String")
                end
          begin
            result = offset_raw ? v.raw.byteindex(pat, offset_raw) : v.raw.byteindex(pat)
            if result.nil?
              update_match_globals(nil) if is_regexp
              FNIL
            else
              if is_regexp
                m = pat.match(v.raw, v.raw.byteindex(pat, offset_raw || 0))
                update_match_globals(m)
              end
              n2f_int(result)
            end
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::IndexError => e then raise FrozoneException.make(:IndexError, e.message)
          end
        end

        def string_byterindex(context, v, sub, offset = FNIL)
          offset_raw = fnil?(offset) ? nil : (fint?(offset) ? offset.raw : str_vm_coerce_to_int(context, offset))
          is_regexp = sub.is_a?(RegexpObject)
          pat = if fstr?(sub)
                  sub.raw
                elsif is_regexp
                  sub.raw
                elsif fnil?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of nil into String")
                elsif ftrue?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of true into String")
                elsif ffalse?(sub)
                  raise FrozoneException.make(:TypeError, "no implicit conversion of false into String")
                elsif sub.is_a?(ObjectObject)
                  r = begin
                    sub.dispatch(context, :to_str, [], {})
                  rescue FrozoneException
                    nil
                  end
                  fstr?(r) ? r.raw : raise(FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || 'Object'} into String"))
                else
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{sub.class_object&.name || sub.class} into String")
                end
          begin
            result = offset_raw ? v.raw.byterindex(pat, offset_raw) : v.raw.byterindex(pat)
            if result.nil?
              update_match_globals(nil) if is_regexp
              FNIL
            else
              if is_regexp
                m = pat.match(v.raw, result)
                update_match_globals(m)
              end
              n2f_int(result)
            end
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::IndexError => e then raise FrozoneException.make(:IndexError, e.message)
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
                b_raw = f2n_raw(b)
                e_raw = f2n_raw(e)
                Range.new(b_raw, e_raw, a.exclusive?)
              else
                fobj?(a) ? a.raw : a
              end
            end
            v.raw.bytesplice(*raw_args)
          rescue ::IndexError => e then raise FrozoneException.make(:IndexError, e.message)
          rescue ::TypeError => e then raise FrozoneException.make(:TypeError, e.message)
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          v
        end

        def string_scrub(context, v, replacement = FNIL, block = FNIL)
          has_block = !fnil?(block)
          has_repl = replacement && !fnil?(replacement)
          reraise(::EncodingError) do
            result = if has_block
                       v.raw.scrub { |b| block_result_to_s(context, block.invoke(context, [n2f_str(b)])) }
                     elsif has_repl
                       v.raw.scrub(replacement.raw)
                     else
                       v.raw.scrub
                     end
            n2f_str(result)
          end
        end

        def string_undump(_, v)
          begin
            n2f_str(v.raw.undump)
          rescue ::RuntimeError => e then raise FrozoneException.make(:RuntimeError, e.message)
          rescue ::Encoding::UndefinedConversionError => e then raise FrozoneException.make(:EncodingError, e.message)
          end
        end

        def string_upto(context, v, other, exclusive, block)
          return enum_for_str_upto(v, other, exclusive) if fnil?(block)
          excl = exclusive.truthy?
          other_raw = fstr?(other) ? other.raw : other.dispatch(context, :to_str, [], {}).raw
          v.raw.upto(other_raw, excl) do |s|
            block.invoke(context, [n2f_str(s)])
          end
          v
        end

        def string_each_grapheme_cluster(context, v, block)
          if fnil?(block)
            return enum_for_no_block(context, v, :each_grapheme_cluster)
          end
          v.raw.each_grapheme_cluster { |g| block.invoke(context, [n2f_str(g)]) }
          v
        end

        def string_append_bytes(_, v, *args)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          # append_bytes never changes the receiver encoding; it appends raw bytes
          orig_enc = v.raw.encoding
          v.raw.force_encoding(::Encoding::BINARY)
          args.each do |arg|
            if fstr?(arg)
              arg.raw.force_encoding(::Encoding::BINARY).each_byte { |b| v.raw << b }
            elsif fint?(arg)
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

        def string_swapcase_opts(_, v, *args)
          opts = args.map { |a| fsym?(a) ? a.raw : a.raw.to_sym }
          n2f_str(opts.empty? ? v.raw.swapcase : v.raw.swapcase(*opts))
        end

        def string_upcase_opts(_, v, *args)
          opts = args.map { |a| fsym?(a) ? a.raw : a.raw.to_sym }
          n2f_str(opts.empty? ? v.raw.upcase : v.raw.upcase(*opts))
        end

        def string_downcase_opts(_, v, *args)
          opts = args.map { |a| fsym?(a) ? a.raw : a.raw.to_sym }
          n2f_str(opts.empty? ? v.raw.downcase : v.raw.downcase(*opts))
        end

        def string_capitalize_opts(_, v, *args)
          opts = args.map { |a| fsym?(a) ? a.raw : a.raw.to_sym }
          n2f_str(opts.empty? ? v.raw.capitalize : v.raw.capitalize(*opts))
        end

        def string_unicode_normalize(_, v, form = FNIL)
          form_raw = fnil?(form) ? :nfc : form.raw
          begin
            n2f_str(v.raw.unicode_normalize(form_raw))
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        def string_unicode_normalized_q(_, v, form = FNIL)
          form_raw = fnil?(form) ? :nfc : form.raw
          begin
            n2f_bool(v.raw.unicode_normalized?(form_raw))
          rescue ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        def string_to_c(context, v)
          c = v.raw.to_c
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          return n2f_int(0) unless c_class
          real_raw = c.real
          imag_raw = c.imaginary
          real_vm = numeric_to_vm(context, real_raw, rat_class)
          imag_vm = numeric_to_vm(context, imag_raw, rat_class)
          c_class.dispatch(context, :new, [real_vm, imag_vm], {})
        end

        private

        def enum_for_no_block(context, v, method_name) = v.dispatch(context, :to_enum, [n2f_sym(method_name)], {})

        def numeric_to_vm(context, n, rat_class)
          case n
          when ::Integer then n2f_int(n)
          when ::Float   then n2f_float(n)
          when ::Rational
            return n2f_int(n.numerator) if n.denominator == 1
            return n2f_float(n.to_f) unless rat_class
            make_rational(n)
          else n2f_int(0)
          end
        end

        def enum_for_str_upto(v, other, exclusive)
          # Return a bare Enumerator — reuse kernel_to_enum pattern
          excl = exclusive.truthy?
          other_str = fstr?(other) ? other : FNIL
          NativeBlock.new(source_location: nil, parameters_override: []) {}
          # Minimal: return an enumerator object via the VM's to_enum mechanism
          # For now, fall back to building the array and wrapping
          arr = []
          s = v.raw
          o = fstr?(other_str) ? other_str.raw : ''
          s.upto(o, excl) { |x| arr << n2f_str(x) }
          n2f_arr(arr)
        end

        public

        def locale_charmap(_) = n2f_str(::Encoding.locale_charmap || "UTF-8")

        def encoding_set_default_external(_, enc_name_obj)
          enc_name = fstr?(enc_name_obj) ? enc_name_obj.raw : enc_name_obj.to_s
          begin
            ::Encoding.default_external = ::Encoding.find(enc_name)
          rescue ::ArgumentError
            nil
          end
          FNIL
        end

        def encoding_set_default_internal(_, enc_name_obj)
          if fnil?(enc_name_obj)
            ::Encoding.default_internal = nil
          else
            enc_name = fstr?(enc_name_obj) ? enc_name_obj.raw : enc_name_obj.to_s
            begin
              ::Encoding.default_internal = ::Encoding.find(enc_name)
            rescue ::ArgumentError
              nil
            end
          end
          FNIL
        end

        def encoding_compatible(_, a, b)
          mri_a = encoding_compatible_to_mri(a)
          mri_b = encoding_compatible_to_mri(b)
          return FNIL if mri_a.nil? || mri_b.nil?
          enc = ::Encoding.compatible?(mri_a, mri_b)
          return FNIL if enc.nil?
          encoding_find_or_make(enc.name)
        end

        def encoding_converter_check(_, from_str, to_str)
          from_raw = fstr?(from_str) ? from_str.raw : from_str.to_s
          to_raw = fstr?(to_str) ? to_str.raw : to_str.to_s
          begin
            ::Encoding::Converter.new(from_raw, to_raw)
          rescue ::Encoding::ConverterNotFoundError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          FNIL
        end

        def string_encoding_compat(_, v1, v2)
          # Returns compatible Encoding object for the two strings, or raises CompatibilityError
          enc = ::Encoding.compatible?(v1.raw, v2.raw)
          if enc.nil?
            err = ::Encoding::CompatibilityError.new(
              "incompatible character encodings: #{v1.raw.encoding} and #{v2.raw.encoding}"
            )
            raise FrozoneException.new(FrozoneException.wrap_mri(err), err.message)
          end
          # Return a Frozone encoding object (just need the name; force_encoding accepts strings)
          begin
            encoding_obj = Core::OBJECT_CLASS.get_constant(:Encoding)
            if encoding_obj
              encoding_obj.dispatch(nil, :find, [n2f_str(enc.name)], {})
            else
              n2f_str(enc.name)
            end
          rescue
            n2f_str(enc.name)
          end
        end

        def string_unpack(context, v, fmt, offset_arg = FNIL)
          fmt_raw = fstr?(fmt) ? fmt.raw : fmt.to_s
          reraise(::ArgumentError, ::TypeError) do
            results = if offset_arg && !fnil?(offset_arg)
                        off = fint?(offset_arg) ? offset_arg.raw : offset_arg.to_i
                        v.raw.unpack(fmt_raw, offset: off)
                      else
                        v.raw.unpack(fmt_raw)
                      end
            n2f_arr(results.map { |r| unpack_result_to_vm(r) })
          end
        end

        def string_unpack1(context, v, fmt, offset_arg = FNIL)
          fmt_raw = fstr?(fmt) ? fmt.raw : fmt.to_s
          reraise(::ArgumentError, ::TypeError) do
            result = if offset_arg && !fnil?(offset_arg)
                       off = fint?(offset_arg) ? offset_arg.raw : offset_arg.to_i
                       v.raw.unpack1(fmt_raw, offset: off)
                     else
                       v.raw.unpack1(fmt_raw)
                     end
            unpack_result_to_vm(result)
          end
        end

        private

        def unpack_result_to_vm(r)
          case r
          when ::Integer then n2f_int(r)
          when ::Float then n2f_float(r)
          when ::String then n2f_str(r)
          when nil then FNIL
          else FNIL
          end
        end

        public

        # Encoding::Converter intrinsics — delegate to MRI Encoding::Converter
        def encoding_converter_new(context, from_str, to_str, opts_hash = FNIL)
          from_raw = fstr?(from_str) ? from_str.raw : from_str.to_s
          to_raw = fstr?(to_str) ? to_str.raw : to_str.to_s
          opts = {}
          if fhash?(opts_hash)
            opts_hash.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.to_s.to_sym
              opts[key] = case v
                          when StringObject  then v.raw
                          when SymbolObject  then v.raw
                          when TrueObject    then true
                          when FalseObject   then false
                          when IntegerObject then v.raw
                          else fnil?(v) ? nil : v
                          end
            end
          elsif fint?(opts_hash)
            opts = opts_hash.raw
          end
          begin
            mri_conv = opts.is_a?(::Integer) ? ::Encoding::Converter.new(from_raw, to_raw, opts) : ::Encoding::Converter.new(from_raw, to_raw, **opts)
          rescue ::Encoding::ConverterNotFoundError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::TypeError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          EncodingConverterObject.new(mri_conv)
        end

        def encoding_converter_source_encoding(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          enc_name = conv.source_encoding.name
          encoding_find_or_make(enc_name)
        end

        def encoding_converter_destination_encoding(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          enc_name = conv.destination_encoding.name
          encoding_find_or_make(enc_name)
        end

        def encoding_converter_inspect(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return n2f_str("#<Encoding::Converter>") unless conv
          src = conv.source_encoding.name
          dst = conv.destination_encoding.name
          n2f_str("#<Encoding::Converter: #{src} to #{dst}>")
        end

        def encoding_converter_convpath(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return n2f_arr([]) unless conv
          path = conv.convpath.map do |pair|
            if pair.is_a?(Array)
              n2f_arr([encoding_find_or_make(pair[0].name), encoding_find_or_make(pair[1].name)])
            else
              n2f_str(pair.to_s)
            end
          end
          n2f_arr(path)
        end

        def encoding_converter_replacement(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          r = conv.replacement
          n2f_str(r)
        end

        def encoding_converter_replacement_set(_, receiver, val)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          str = fstr?(val) ? val.raw : val.to_s
          begin
            conv.replacement = str
          rescue ::Encoding::UndefinedConversionError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::TypeError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          val
        end

        def encoding_converter_convert(_, receiver, src_str)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          raise FrozoneException.make(:ArgumentError, "converter is already finished") unless conv
          src = fstr?(src_str) ? src_str.raw : src_str.to_s
          begin
            result = conv.convert(src)
          rescue ::Encoding::InvalidByteSequenceError => e
            exc = FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
            enrich_encoding_error(exc.vm_object, e)
            raise exc
          rescue ::Encoding::UndefinedConversionError => e
            exc = FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
            enrich_encoding_error(exc.vm_object, e)
            raise exc
          rescue ::ArgumentError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          n2f_str(result)
        end

        def encoding_converter_finish(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          raise FrozoneException.make(:ArgumentError, "converter is already finished") unless conv
          begin
            result = conv.finish
          rescue ::Encoding::InvalidByteSequenceError => e
            exc = FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
            enrich_encoding_error(exc.vm_object, e)
            raise exc
          end
          n2f_str(result)
        end

        def encoding_converter_primitive_convert(context, receiver, src_arg, dest_str, offset_arg = FNIL, size_arg = FNIL, opts_arg = FNIL)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          raise FrozoneException.make(:ArgumentError, "converter is already finished") unless conv

          dest = fstr?(dest_str) ? dest_str.raw : +"#{dest_str}"
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{dest.inspect}") if fstr?(dest_str) && dest_str.frozen_object?

          src = if fnil?(src_arg)
                  nil
                else
                  fstr?(src_arg) ? src_arg.raw : src_arg.to_s
                end

          offset = if fnil?(offset_arg)
                     nil
                   elsif fint?(offset_arg)
                     offset_arg.raw
                   elsif fobj?(offset_arg)
                     result = offset_arg.dispatch(context, :to_int, [], {}) rescue nil
                     raise FrozoneException.make(:TypeError, "no implicit conversion of #{offset_arg.class_object.name} into Integer") unless fint?(result)
                     result.raw
                   end

          size = if fnil?(size_arg)
                   nil
                 elsif fint?(size_arg)
                   size_arg.raw
                 elsif fobj?(size_arg)
                   result = size_arg.dispatch(context, :to_int, [], {}) rescue nil
                   raise FrozoneException.make(:TypeError, "no implicit conversion of #{size_arg.class_object.name} into Integer") unless fint?(result)
                   result.raw
                 end

          opts = {}
          if fhash?(opts_arg)
            opts_arg.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.to_s.to_sym
              opts[key] = case v
                          when TrueObject  then true
                          when FalseObject then false
                          when IntegerObject then v.raw
                          else fnil?(v) ? nil : v
                          end
            end
          elsif fint?(opts_arg)
            opts = opts_arg.raw
          end

          begin
            status = if opts.is_a?(::Integer)
                       conv.primitive_convert(src, dest, offset, size, opts)
                     elsif opts.empty?
                       conv.primitive_convert(src, dest, offset, size)
                     else
                       conv.primitive_convert(src, dest, offset, size, **opts)
                     end
          rescue ::FrozenError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          rescue ::ArgumentError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end

          # Update Frozone dest StringObject's raw string
          dest_str.raw = dest if fstr?(dest_str)

          n2f_sym(status)
        end

        def encoding_converter_primitive_errinfo(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return n2f_arr([n2f_sym(:source_buffer_empty),
                                  FNIL, FNIL, FNIL, FNIL]) unless conv
          info = conv.primitive_errinfo
          n2f_arr(info.map { |item|
            case item
            when ::Symbol then n2f_sym(item)
            when ::String then n2f_str(item)
            when nil      then FNIL
            else FNIL
            end
          })
        end

        def encoding_converter_last_error(_, receiver)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          err = conv.last_error
          return FNIL if err.nil?
          exc = FrozoneException.wrap_mri(err)
          enrich_encoding_error(exc, err)
          exc
        end

        def encoding_converter_insert_output(_, receiver, str)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return FNIL unless conv
          s = fstr?(str) ? str.raw : str.to_s
          begin
            conv.insert_output(s)
          rescue ::Encoding::InvalidByteSequenceError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          FNIL
        end

        def encoding_converter_putback(_, receiver, n_arg = FNIL)
          conv = receiver.is_a?(EncodingConverterObject) ? receiver.mri_converter : nil
          return n2f_str("") unless conv
          result = if fnil?(n_arg)
                     conv.putback
                   else
                     n = fint?(n_arg) ? n_arg.raw : n_arg.to_i
                     conv.putback(n)
                   end
          n2f_str(result)
        end

        def encoding_converter_search_convpath(_, from_str, to_str, opts_arg = FNIL)
          from_raw = fstr?(from_str) ? from_str.raw : from_str.to_s
          to_raw = fstr?(to_str) ? to_str.raw : to_str.to_s
          opts = {}
          if fhash?(opts_arg)
            opts_arg.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.to_s.to_sym
              opts[key] = case v
                          when TrueObject  then true
                          when FalseObject then false
                          else fnil?(v) ? nil : v
                          end
            end
          end
          begin
            path = opts.empty? ? ::Encoding::Converter.search_convpath(from_raw, to_raw) : ::Encoding::Converter.search_convpath(from_raw, to_raw, **opts)
          rescue ::Encoding::ConverterNotFoundError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          n2f_arr(path.map { |pair|
            if pair.is_a?(Array)
              n2f_arr([encoding_find_or_make(pair[0].name), encoding_find_or_make(pair[1].name)])
            else
              n2f_str(pair.to_s)
            end
          })
        end

        def encoding_converter_asciicompat_encoding(context, enc_arg)
          # Resolve arg to MRI Encoding or String
          mri_enc = if fstr?(enc_arg)
                      enc_arg.raw
                    elsif fobj?(enc_arg)
                      # Frozone Encoding object or something with to_str
                      name_obj = enc_arg.get_ivar(:@name) rescue nil
                      if fstr?(name_obj)
                        mri_name = name_obj.raw
                        begin
                          ::Encoding.find(mri_name)
                        rescue ::ArgumentError
                          # "internal" alias with nil internal encoding
                          nil
                        end
                      else
                        nil
                      end
                    else
                      enc_arg.to_s
                    end
          return FNIL if mri_enc.nil?
          begin
            result = ::Encoding::Converter.asciicompat_encoding(mri_enc)
          rescue ::TypeError => e
            # Try to_str on the Frozone object
            if fobj?(enc_arg) && context
              str_obj = enc_arg.dispatch(context, :to_str, [], {}) rescue nil
              if fstr?(str_obj)
                result = ::Encoding::Converter.asciicompat_encoding(str_obj.raw) rescue nil
              end
            end
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message) if result.nil?
          end
          return FNIL if result.nil?
          encoding_find_or_make(result.name)
        end

        private

        def encoding_compatible_to_mri(vm_obj)
          case vm_obj
          when StringObject
            vm_obj.raw
          when SymbolObject
            vm_obj.raw
          when RegexpObject
            vm_obj.raw
          else
            # Check if it's an Encoding VM object (has @name ivar)
            name_obj = vm_obj.is_a?(ObjectObject) ? (vm_obj.get_ivar(:@name) rescue nil) : nil
            if fstr?(name_obj)
              begin
                ::Encoding.find(name_obj.raw)
              rescue ::ArgumentError
                nil
              end
            else
              nil
            end
          end
        end

        def encoding_find_or_make(enc_name)
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          if enc_class
            ctx = Fiber[:context]
            begin
              enc_class.dispatch(ctx, :find, [n2f_str(enc_name)], {})
            rescue FrozoneException
              n2f_str(enc_name)
            rescue
              n2f_str(enc_name)
            end
          else
            n2f_str(enc_name)
          end
        end

        def enrich_encoding_error(vm_obj, mri_err)
          return unless vm_obj.respond_to?(:set_ivar)
          if mri_err.respond_to?(:source_encoding)
            src_enc = mri_err.source_encoding
            vm_obj.set_ivar(:@source_encoding, encoding_find_or_make(src_enc.name)) if src_enc
            vm_obj.set_ivar(:@source_encoding_name, n2f_str(src_enc.name)) if src_enc
          end
          if mri_err.respond_to?(:destination_encoding)
            dst_enc = mri_err.destination_encoding
            vm_obj.set_ivar(:@destination_encoding, encoding_find_or_make(dst_enc.name)) if dst_enc
            vm_obj.set_ivar(:@destination_encoding_name, n2f_str(dst_enc.name)) if dst_enc
          end
          if mri_err.respond_to?(:error_bytes)
            eb = mri_err.error_bytes
            vm_obj.set_ivar(:@error_bytes, eb ? n2f_str(eb) : FNIL)
          end
          if mri_err.respond_to?(:readagain_bytes)
            rb = mri_err.readagain_bytes
            vm_obj.set_ivar(:@readagain_bytes, rb ? n2f_str(rb) : FNIL)
          end
          if mri_err.respond_to?(:incomplete_input?)
            vm_obj.set_ivar(:@incomplete_input, n2f_bool(mri_err.incomplete_input?))
          end
          if mri_err.respond_to?(:error_char)
            ec = mri_err.error_char rescue nil
            vm_obj.set_ivar(:@error_char, ec ? n2f_str(ec) : FNIL)
          end
        end

        public

        # Symbol
        def symbol_to_s(_, v) = n2f_str(v.raw.to_s, chilled_source: v.raw)
        def symbol_hash(_, v) = n2f_int(v.raw.hash)
        def symbol_all_symbols(_) = n2f_arr(SymbolObject::SymbolObjects.values)
      end
    end
  end
end

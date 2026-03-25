# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Regexp
        def regexp_newly_created_q(_, r) = r.is_a?(RegexpObject) ? n2f_bool(r.newly_created_for_subclass) : FFALSE
        def regexp_source(_, r) = n2f_str(r.raw.source)
        def regexp_inspect(_, r) = n2f_str(r.raw.inspect)
        def regexp_to_s(_, r) = n2f_str(r.raw.to_s)
        def regexp_escape(_, str) = n2f_str(Regexp.escape(str.raw.to_s))
        def regexp_hash(_, r) = n2f_int(r.raw.hash)
        def regexp_names(_, r) = n2f_arr(r.raw.names.map { |n| n2f_str(n) })
        def match_data_size(_, md) = n2f_int(md.raw.size)
        def match_data_pre_match(_, md) = n2f_str(md.raw.pre_match)
        def match_data_post_match(_, md) = n2f_str(md.raw.post_match)
        def match_data_regexp(_, md) = md.frozone_regexp || RegexpObject.new(md.raw.regexp.source, md.raw.regexp.options)
        def match_data_captures(_, md) = n2f_arr(md.raw.captures.map { |c| c ? n2f_str(c) : FNIL })
        def match_data_hash(_, md) = n2f_int(md.raw.hash)
        def match_data_names(_, md) = n2f_arr(md.raw.regexp.named_captures.keys.map { |k| n2f_str(k) })
        def match_data_to_a(_, md) = n2f_arr(([md.raw[0]] + md.raw.captures).map { |c| c ? n2f_str(c) : FNIL })
        def match_data_named_captures(_, md) = n2f_hash(md.raw.named_captures.transform_keys { |k| n2f_str(k) }.transform_values { |v| v ? n2f_str(v) : FNIL })

        def update_match_globals(m, regexp_obj = nil)
          Fiber[:last_match] = m
          if m
            md = MatchDataObject.new(m, fnil?(regexp_obj) ? nil : regexp_obj)
            GLOBALS[:"$~"] = md
            m.captures.each_with_index do |cap, i|
              GLOBALS[:"$#{i + 1}"] = cap ? n2f_str(cap) : FNIL
            end
            last_non_nil = m.captures.reverse.find { |c| !c.nil? }
            GLOBALS[:"$+"] = last_non_nil ? n2f_str(last_non_nil) : FNIL
            GLOBALS[:"$&"] = n2f_str(m[0])
            GLOBALS[:"$`"] = n2f_str(m.pre_match)
            GLOBALS[:"$'"] = n2f_str(m.post_match)
            md
          else
            GLOBALS[:"$~"] = FNIL
            GLOBALS.delete_if { |k, _| k.to_s =~ /^\$[1-9]\d*$/ }
            GLOBALS[:"$&"] = GLOBALS[:"$`"] = GLOBALS[:"$'"] = FNIL
            FNIL
          end
        end

        def regexp_eq(_, r1, r2)
          return FTRUE if r1.equal?(r2)
          return FFALSE unless r2.is_a?(RegexpObject)
          n2f_bool(r1.raw == r2.raw)
        end

        def regexp_new(context, klass, pattern, options = FNIL, kw_opts = FNIL)
          regexp_class = Core::OBJECT_CLASS.get_constant(:Regexp)
          if pattern.is_a?(RegexpObject)
            # When given a Regexp, use its source+options; warn and ignore extra options
            if options && !fnil?(options) && !ffalse?(options)
              kernel_warn(context, FNIL, n2f_arr([n2f_str("warning: flags ignored")]))
            end
            result = RegexpObject.new(pattern.raw.source, pattern.raw.options, pattern.raw.encoding.name, klass: klass)
            unless klass.equal?(regexp_class)
              result.newly_created_for_subclass = true
              result.dispatch(context, :initialize, [pattern, options || FNIL], {}, nil, private_ok: true)
              result.newly_created_for_subclass = false
            end
            return result
          end
          reraise(::RegexpError) do
            pat_raw = coerce_regexp_pattern(context, pattern)
            flags = regexp_flags_from_options(context, options)
            timeout_val = regexp_timeout_from_kw_opts(kw_opts)
            result = RegexpObject.new(pat_raw, flags, klass: klass, timeout: timeout_val)
            unless klass.equal?(regexp_class)
              result.newly_created_for_subclass = true
              result.dispatch(context, :initialize, [pattern, options || FNIL], {}, nil, private_ok: true)
              result.newly_created_for_subclass = false
            end
            result
          end
        end

        def regexp_options(_, r)
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless r.is_a?(RegexpObject)
          n2f_int(r.raw.options)
        end

        def regexp_linear_time_q(_, r)
          n2f_bool(Regexp.linear_time?(r.raw))
        rescue
          FFALSE
        end

        def regexp_class_linear_time_q(context, pattern, flags = FNIL)
          if pattern.is_a?(RegexpObject)
            unless fnil?(flags)
              kernel_warn(context, FNIL, n2f_arr([n2f_str("warning: flags ignored")]))
            end
            raw_pat = pattern.raw
          elsif fstr?(pattern)
            opts = fint?(flags) ? flags.raw : 0
            raw_pat = reraise(::RegexpError) { Regexp.new(pattern.raw, opts) }
          else
            return FFALSE
          end
          n2f_bool(Regexp.linear_time?(raw_pat))
        rescue
          FFALSE
        end

        def regexp_encoding(context, r)
          enc_name = r.raw.encoding.name
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          return n2f_str(enc_name) unless enc_class
          begin
            enc_class.dispatch(context, :find, [n2f_str(enc_name)], {})
          rescue
            n2f_str(enc_name)
          end
        end

        def regexp_named_captures(_, r)
          caps = r.raw.named_captures
          pairs = caps.transform_keys { |name| n2f_str(name) }
                      .transform_values { |indices| n2f_arr(indices.map { |i| n2f_int(i) }) }
          n2f_hash(pairs)
        end

        def regexp_tilde(context, receiver)
          dollar_underscore = GLOBALS[:"$_"]
          return FNIL unless fstr?(dollar_underscore)
          s = dollar_underscore.raw
          m = receiver.raw.match(s)
          update_match_globals(m, receiver)
          m ? n2f_int(m.begin(0)) : FNIL
        end

        REGEXP_TIMEOUT = [nil]

        def regexp_timeout(_, _r)
          v = REGEXP_TIMEOUT[0]
          return FNIL if v.nil?
          v.is_a?(Integer) ? n2f_int(v) : n2f_float(v)
        end

        def regexp_set_timeout(_, _r, val)
          raw_val = f2n_raw(val)
          REGEXP_TIMEOUT[0] = raw_val
          ::Regexp.timeout = raw_val
          val
        end

        def regexp_union(context, patterns)
          raw_pats = patterns.raw
          # Unwrap single array argument: Regexp.union(["a", "b"]) → treat as Regexp.union("a", "b")
          raw_pats = raw_pats[0].raw if raw_pats.length == 1 && farray?(raw_pats[0])
          return RegexpObject.new('(?!)', 0) if raw_pats.empty?
          pats = raw_pats.map { |p| coerce_union_element(context, p) }
          reraise(::ArgumentError) { ::Regexp.union(*pats).then { |r| RegexpObject.new(r.source, r.options) } }
        end

        def regexp_last_match(context, n = FNIL)
          md = Fiber[:last_match]
          return FNIL unless md
          if fnil?(n)
            GLOBALS[:"$~"] || FNIL
          else
            idx = if fint?(n)
                    n.raw
                  elsif fstr?(n) || fsym?(n)
                    n.raw.to_s
                  else
                    klass = frozone_class_name(n)
                    begin
                      result = n.dispatch(context, :to_int, [], {})
                      fint?(result) ? result.raw : result.raw.to_i
                    rescue FrozoneException => e
                      raise unless e.frozone_class_name == :NoMethodError
                      raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
                    end
                  end
            cap = md[idx]
            cap ? n2f_str(cap) : FNIL
          end
        end

        def regexp_match(context, receiver, str, pos = FNIL)
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless receiver.is_a?(RegexpObject)
          if fnil?(str)
            update_match_globals(nil)
            return FNIL
          end
          s = if fstr?(str)
                str.raw
              elsif fsym?(str)
                str.raw.to_s
              else
                klass = frozone_class_name(str)
                begin
                  result = str.dispatch(context, :to_str, [], {})
                  unless fstr?(result)
                    raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
                  end
                  result.raw
                rescue FrozoneException => e
                  raise unless e.frozone_class_name == :NoMethodError
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
                end
              end
          p = fint?(pos) ? pos.raw : 0
          begin
            m = p == 0 ? receiver.raw.match(s) : receiver.raw.match(s, p)
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
          update_match_globals(m, receiver)
        end

        def regexp_match_bool(context, receiver, str, pos = FNIL)
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless receiver.is_a?(RegexpObject)
          return FFALSE if fnil?(str)
          s = if fstr?(str)
                str.raw
              else
                begin
                  result = str.dispatch(context, :to_str, [], {})
                  fstr?(result) ? result.raw : result.to_s
                rescue
                  str.respond_to?(:raw) ? str.raw.to_s : str.to_s
                end
              end
          p = fint?(pos) ? pos.raw : 0
          begin
            n2f_bool(p == 0 ? receiver.raw.match?(s) : receiver.raw.match?(s, p))
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
        end

        def regexp_match_index(_, receiver, str)
          return FNIL if fnil?(str)
          s = fstr?(str) ? str.raw : (str.respond_to?(:raw) ? str.raw.to_s : str.to_s)
          begin
            m = receiver.raw.match(s)
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
          update_match_globals(m, receiver)
          m ? n2f_int(m.begin(0)) : FNIL
        end

        def match_data_group_key(context, n)
          if fint?(n)
            n.raw
          elsif fstr?(n) || fsym?(n)
            n.raw.to_s
          else
            klass = frozone_class_name(n)
            begin
              result = n.dispatch(context, :to_int, [], {})
              fint?(result) ? result.raw : result.raw.to_i
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          end
        end

        def match_data_index(context, md, idx) = reraise(::IndexError) do
          key = match_data_group_key(context, idx)
          val = md.raw[key]
          val ? n2f_str(val) : FNIL
        end

        def match_data_slice(_, md, start_obj, len_obj)
          s = fint?(start_obj) ? start_obj.raw : start_obj.raw.to_i
          l = fint?(len_obj) ? len_obj.raw : len_obj.raw.to_i
          all = [md.raw[0]] + md.raw.captures
          slice = all[s, l]
          return FNIL unless slice
          n2f_arr(slice.map { |c| c ? n2f_str(c) : FNIL })
        end

        def match_data_slice_range(_, md, range_obj)
          all = [md.raw[0]] + md.raw.captures
          r = range_obj.raw rescue (return FNIL)
          slice = all[r]
          return FNIL unless slice
          n2f_arr(slice.map { |c| c ? n2f_str(c) : FNIL })
        end

        def match_data_values_at_range(_, md, range_obj, size_obj)
          all = [md.raw[0]] + md.raw.captures
          size = all.size
          r = range_obj.raw rescue (return n2f_arr([]))
          rb = r.begin
          re = r.end
          # Check for negative out-of-range begin
          if rb && rb < 0 && rb.abs > size
            raise FrozoneException.make(:RangeError, "#{r} out of range")
          end
          # Compute absolute start
          start = rb.nil? ? 0 : (rb < 0 ? [rb + size, 0].max : rb)
          # Compute absolute finish (inclusive), extending beyond size to fill nil
          finish = if re.nil?
                     size - 1
                   else
                     f = re < 0 ? re + size : re
                     r.exclude_end? ? f - 1 : f
                   end
          indices = start > finish ? [] : (start..finish).to_a
          result = indices.map { |i| i < size ? (all[i] ? n2f_str(all[i]) : FNIL) : FNIL }
          n2f_arr(result)
        end

        def match_data_string(_, md)
          s = n2f_str(md.raw.string.dup)
          s.freeze
          s
        end

        def match_data_begin(context, md, n) = reraise(::IndexError) do
          key = match_data_group_key(context, n)
          v = md.raw.begin(key)
          v ? n2f_int(v) : FNIL
        end

        def match_data_end(context, md, n) = reraise(::IndexError) do
          key = match_data_group_key(context, n)
          v = md.raw.end(key)
          v ? n2f_int(v) : FNIL
        end

        def match_data_bytebegin(context, md, n)
          reraise(::IndexError, ::NameError, as: :IndexError) do
            key = match_data_group_key(context, n)
            v = md.raw.bytebegin(key)
            v ? n2f_int(v) : FNIL
          end
        end

        def match_data_byteend(context, md, n)
          reraise(::IndexError, ::NameError, as: :IndexError) do
            key = match_data_group_key(context, n)
            v = md.raw.byteend(key)
            v ? n2f_int(v) : FNIL
          end
        end

        def match_data_match_length(context, md, n)
          reraise(::IndexError, ::NameError, as: :IndexError) do
            key = match_data_group_key(context, n)
            b = md.raw.begin(key)
            e = md.raw.end(key)
            next FNIL unless b && e
            n2f_int(e - b)
          end
        end


        private

        # Coerce a Regexp pattern argument (non-Regexp) to a raw String.
        def coerce_regexp_pattern(context, pattern)
          pat_klass = frozone_class_name(pattern)
          return pattern.raw if fstr?(pattern)
          begin
            result = pattern.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "can't convert #{pat_klass} into String") unless fstr?(result)
            result.raw
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{pat_klass} into String")
          end
        end

        # Convert Regexp.new options argument to raw flags (Integer or String).
        def regexp_flags_from_options(context, options)
          if fnil?(options) || ffalse?(options)
            0
          elsif fint?(options)
            options.raw
          elsif fstr?(options)
            options.raw
          elsif ftrue?(options)
            Regexp::IGNORECASE
          else
            kernel_warn(context, FNIL, n2f_arr([n2f_str("warning: expected true or false as ignorecase")]))
            Regexp::IGNORECASE
          end
        end

        # Extract :timeout from Regexp.new keyword options hash.
        def regexp_timeout_from_kw_opts(kw_opts)
          return nil unless fhash?(kw_opts)
          kw_opts.raw.each do |k, v|
            if fsym?(k) && k.raw == :timeout
              return ffloat?(v) ? v.raw : (fint?(v) ? v.raw.to_f : nil)
            end
          end
          nil
        end

        # Coerce a single element of Regexp.union arguments to a raw String or Regexp.
        def coerce_union_element(context, p)
          return p.raw if p.is_a?(RegexpObject)
          return p.raw if fstr?(p)
          return p.raw.to_s if fsym?(p)
          klass = frozone_class_name(p)
          begin
            result = p.dispatch(context, :to_regexp, [], {})
            return result.raw if result.is_a?(RegexpObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Regexp")
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
          end
          begin
            str_result = p.dispatch(context, :to_str, [], {})
            return fstr?(str_result) ? str_result.raw : str_result.raw.to_s
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
          end
        end
      end
    end
  end
end

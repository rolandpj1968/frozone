# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # File / Dir
        def file_join(_, parts)
          strs = parts.raw.flat_map { |p| p.is_a?(ArrayObject) ? p.raw.map(&:raw) : p.raw }
          StringObject.new(File.join(*strs))
        end

        def file_dirname(_, path) = StringObject.new(File.dirname(path.raw))

        def file_basename(_, path, suffix = nil)
          result = suffix.nil? || suffix.is_a?(NilObject) ? File.basename(path.raw) : File.basename(path.raw, suffix.raw)
          StringObject.new(result)
        end

        def file_expand_path(_, path, base = nil)
          result = base.nil? || base.is_a?(NilObject) ? File.expand_path(path.raw) : File.expand_path(path.raw, base.raw)
          StringObject.new(result)
        end

        def file_exist(_, path) = bool_object_for(File.exist?(path.raw))
        def file_directory(_, path) = bool_object_for(File.directory?(path.raw))
        def file_file(_, path) = bool_object_for(File.file?(path.raw))
        def file_readable(_, path) = bool_object_for(File.readable?(path.raw))
        def file_executable(_, path) = bool_object_for(File.executable?(path.raw))
        def file_writable(_, path) = bool_object_for(File.writable?(path.raw))

        def file_size(_, path)
          s = File.size?(path.raw)
          s ? IntegerObject.new(s) : NilObject::NIL
        end

        def file_read(_, path) = StringObject.new(File.read(path.raw))

        def file_write(_, path, content)
          File.write(path.raw, content.raw)
          IntegerObject.new(content.raw.length)
        end

        def file_open(context, path, mode, block)
          mode_str = mode.is_a?(NilObject) || mode.nil? ? 'r' : mode.raw
          if block && !block.is_a?(NilObject)
            File.open(path.raw, mode_str) do |f|
              io_obj = IOObject.new(f, Core.io_class)
              block.invoke(context, [io_obj])
            end
            NilObject::NIL
          else
            IOObject.new(File.open(path.raw, mode_str), Core.io_class)
          end
        end

        def file_delete(_, paths)
          paths.raw.each { |p| File.delete(p.raw) rescue nil }
          IntegerObject.new(paths.raw.length)
        end

        def file_rename(_, from, to) = (File.rename(from.raw, to.raw); IntegerObject.new(0))
        def file_symlink(_, path) = bool_object_for(File.symlink?(path.raw))
        def file_symlink_create(_, target, link) = (File.symlink(target.raw, link.raw); IntegerObject.new(0))
        def file_zero(_, path) = bool_object_for(File.zero?(path.raw))

        def file_fnmatch(_, pattern, path, flags)
          bool_object_for(File.fnmatch(pattern.raw, path.raw, flags.raw))
        end

        def file_stat(_, path)
          st = File.stat(path.raw)
          obj = ObjectObject.new(Core::OBJECT_CLASS)
          obj.instance_variable_set(:@__stat__, st)
          obj
        end

        def file_split(_, path)
          parts = File.split(path.raw)
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end

        def dir_pwd(_) = StringObject.new(Dir.pwd)
        def dir_home(_) = StringObject.new(Dir.home)

        def dir_glob(_, pattern)
          ArrayObject.new(Dir.glob(pattern.raw).map { |p| StringObject.new(p) })
        end

        def dir_chdir(context, path, block)
          path_raw = path.is_a?(NilObject) || path.nil? ? nil : path.raw
          if block && !block.is_a?(NilObject)
            result = path_raw ? Dir.chdir(path_raw) { block.invoke(context, [StringObject.new(Dir.pwd)]) } :
                                Dir.chdir { block.invoke(context, [StringObject.new(Dir.pwd)]) }
            result.is_a?(ObjectObject) ? result : NilObject::NIL
          else
            Dir.chdir(path_raw || Dir.pwd)
            NilObject::NIL
          end
        end

        def dir_mkdir(_, path) = (Dir.mkdir(path.raw); IntegerObject.new(0))

        def dir_entries(_, path)
          entries = Dir.entries(path.raw)
          ArrayObject.new(entries.map { |e| StringObject.new(e) })
        end

        def dir_rmdir(_, path) = (Dir.rmdir(path.raw); IntegerObject.new(0))
        def dir_empty(_, path) = bool_object_for(Dir.empty?(path.raw))
        def dir_exist(_, path) = path.raw && Dir.exist?(path.raw) ? TrueObject::TRUE : FalseObject::FALSE

        def dir_mktmpdir(context, prefix, block)
          require 'tmpdir'
          pfx = prefix.is_a?(NilObject) || prefix.nil? ? nil : prefix.raw
          path = pfx ? Dir.mktmpdir(pfx) : Dir.mktmpdir
          if block && !block.is_a?(NilObject)
            begin
              block.invoke(context, [StringObject.new(path)])
            ensure
              FileUtils.remove_entry(path) rescue nil
            end
          else
            StringObject.new(path)
          end
        end

        def process_pid(_) = IntegerObject.new(Process.pid)
        def process_euid(_) = IntegerObject.new(Process.euid)

        # Time
        def time_now(_) = TimeObject.new(Time.now)

        def time_minus(_, t, other)
          other.is_a?(TimeObject) ? FloatObject.new(t.raw - other.raw) : TimeObject.new(t.raw - other.raw)
        end

        def time_plus(_, t, secs) = TimeObject.new(t.raw + secs.raw)
        def time_to_f(_, t) = FloatObject.new(t.raw.to_f)
        def time_to_i(_, t) = IntegerObject.new(t.raw.to_i)
        def time_to_s(_, t) = StringObject.new(t.raw.to_s)

        # Regexp
        def update_match_globals(m, regexp_obj = nil)
          Fiber[:last_match] = m
          if m
            md = MatchDataObject.new(m, regexp_obj)
            GLOBALS[:"$~"] = md
            m.captures.each_with_index do |cap, i|
              GLOBALS[:"$#{i + 1}"] = cap ? StringObject.new(cap) : NilObject::NIL
            end
            last_non_nil = m.captures.reverse.find { |c| !c.nil? }
            GLOBALS[:"$+"] = last_non_nil ? StringObject.new(last_non_nil) : NilObject::NIL
            GLOBALS[:"$&"] = StringObject.new(m[0])
            GLOBALS[:"$`"] = StringObject.new(m.pre_match)
            GLOBALS[:"$'"] = StringObject.new(m.post_match)
            md
          else
            GLOBALS[:"$~"] = NilObject::NIL
            GLOBALS.delete_if { |k, _| k.to_s =~ /^\$[1-9]\d*$/ }
            GLOBALS[:"$&"] = GLOBALS[:"$`"] = GLOBALS[:"$'"] = NilObject::NIL
            NilObject::NIL
          end
        end

        def regexp_eq(_, r1, r2)
          return TrueObject::TRUE if r1.equal?(r2)
          return FalseObject::FALSE unless r2.is_a?(RegexpObject)
          bool_object_for(r1.raw == r2.raw)
        end

        def regexp_new(context, pattern, options = nil)
          if pattern.is_a?(RegexpObject)
            # When given a Regexp, use its source+options; warn and ignore extra options
            if options && !options.is_a?(NilObject) && !options.is_a?(FalseObject)
              kernel_warn(context, NilObject::NIL, ArrayObject.new([StringObject.new("warning: flags ignored")]))
            end
            return RegexpObject.new(pattern.raw.source, pattern.raw.options, pattern.raw.encoding.name)
          end
          # Coerce to String
          pat_raw = if pattern.is_a?(StringObject)
            pattern.raw
          else
            klass = pattern.respond_to?(:class_object) ? (pattern.class_object&.name || pattern.class) : pattern.class
            begin
              result = pattern.dispatch(context, :to_str, [], {})
              unless result.is_a?(StringObject)
                raise FrozoneException.make(:TypeError, "can't convert #{klass} into String")
              end
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          flags = if options.nil? || options.is_a?(NilObject) || options.is_a?(FalseObject)
            0
          elsif options.is_a?(IntegerObject)
            options.raw
          elsif options.is_a?(StringObject)
            options.raw
          elsif options.is_a?(TrueObject)
            Regexp::IGNORECASE
          else
            0
          end
          RegexpObject.new(pat_raw, flags)
        rescue ::RegexpError => e
          raise FrozoneException.make(:RegexpError, e.message)
        end

        def regexp_source(_, r) = StringObject.new(r.raw.source)
        def regexp_options(_, r) = IntegerObject.new(r.raw.options)
        def regexp_inspect(_, r) = StringObject.new(r.raw.inspect)
        def regexp_to_s(_, r) = StringObject.new(r.raw.to_s)
        def regexp_casefold(_, r) = bool_object_for(r.raw.casefold?)
        def regexp_fixed_encoding(_, r) = bool_object_for(r.raw.fixed_encoding?)
        def regexp_escape(_, str) = StringObject.new(Regexp.escape(str.raw.to_s))
        def regexp_hash(_, r) = IntegerObject.new(r.raw.hash)
        def regexp_linear_time_q(_, r)
          bool_object_for(Regexp.linear_time?(r.raw))
        rescue
          FalseObject::FALSE
        end

        def regexp_class_linear_time_q(context, pattern, flags = NilObject::NIL)
          if pattern.is_a?(RegexpObject)
            unless flags.is_a?(NilObject) || flags.nil?
              kernel_warn(context, NilObject::NIL, ArrayObject.new([StringObject.new("warning: flags ignored")]))
            end
            raw_pat = pattern.raw
          elsif pattern.is_a?(StringObject)
            opts = flags.is_a?(IntegerObject) ? flags.raw : 0
            begin
              raw_pat = Regexp.new(pattern.raw, opts)
            rescue ::RegexpError => e
              raise FrozoneException.make(:RegexpError, e.message)
            end
          else
            return FalseObject::FALSE
          end
          bool_object_for(Regexp.linear_time?(raw_pat))
        rescue
          FalseObject::FALSE
        end

        def regexp_encoding(context, r)
          enc_name = r.raw.encoding.name
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          return StringObject.new(enc_name) unless enc_class
          begin
            enc_class.dispatch(context, :find, [StringObject.new(enc_name)], {})
          rescue
            StringObject.new(enc_name)
          end
        end

        def regexp_named_captures(_, r)
          caps = r.raw.named_captures
          pairs = caps.transform_keys { |name| StringObject.new(name) }
                     .transform_values { |indices| ArrayObject.new(indices.map { |i| IntegerObject.new(i) }) }
          HashObject.new(pairs)
        end

        def regexp_names(_, r)
          ArrayObject.new(r.raw.names.map { |n| StringObject.new(n) })
        end

        def regexp_tilde(context, receiver)
          dollar_underscore = GLOBALS[:"$_"]
          return NilObject::NIL unless dollar_underscore.is_a?(StringObject)
          s = dollar_underscore.raw
          m = receiver.raw.match(s)
          update_match_globals(m, receiver)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

        REGEXP_TIMEOUT = [nil].freeze

        def regexp_timeout(_, _r) = REGEXP_TIMEOUT[0].nil? ? NilObject::NIL : IntegerObject.new(REGEXP_TIMEOUT[0])

        def regexp_set_timeout(_, _r, val)
          REGEXP_TIMEOUT[0] = val.is_a?(NilObject) ? nil : val.raw
          val
        end

        def regexp_union(context, patterns)
          raw_pats = patterns.raw
          # Unwrap single array argument: Regexp.union(["a", "b"]) → treat as Regexp.union("a", "b")
          raw_pats = raw_pats[0].raw if raw_pats.length == 1 && raw_pats[0].is_a?(ArrayObject)
          return RegexpObject.new('(?!)', 0) if raw_pats.empty?
          pats = raw_pats.map do |p|
            if p.is_a?(RegexpObject)
              p.raw
            elsif p.is_a?(StringObject)
              Regexp.escape(p.raw)
            else
              # Try to_regexp first
              klass = p.respond_to?(:class_object) ? (p.class_object&.name || p.class) : p.class
              begin
                result = p.dispatch(context, :to_regexp, [], {})
                if result.is_a?(RegexpObject)
                  result.raw
                else
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Regexp")
                end
              rescue FrozoneException => e
                raise unless e.frozone_class_name == :NoMethodError
                # Try to_str
                begin
                  str_result = p.dispatch(context, :to_str, [], {})
                  Regexp.escape(str_result.is_a?(StringObject) ? str_result.raw : str_result.raw.to_s)
                rescue FrozoneException => e2
                  raise unless e2.frozone_class_name == :NoMethodError
                  raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
                end
              end
            end
          end
          ::Regexp.union(*pats).then { |r| RegexpObject.new(r.source, r.options) }
        rescue ::ArgumentError => e
          raise FrozoneException.make(:ArgumentError, e.message)
        end

        def regexp_last_match(context, n = nil)
          md = Fiber[:last_match]
          return NilObject::NIL unless md
          if n.nil? || n.is_a?(NilObject)
            GLOBALS[:"$~"] || NilObject::NIL
          else
            idx = if n.is_a?(IntegerObject)
              n.raw
            elsif n.is_a?(StringObject) || n.is_a?(SymbolObject)
              n.raw.to_s
            else
              klass = n.respond_to?(:class_object) ? (n.class_object&.name || n.class) : n.class
              begin
                result = n.dispatch(context, :to_int, [], {})
                result.is_a?(IntegerObject) ? result.raw : result.raw.to_i
              rescue FrozoneException => e
                raise unless e.frozone_class_name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
              end
            end
            cap = md[idx]
            cap ? StringObject.new(cap) : NilObject::NIL
          end
        end

        def regexp_match(context, receiver, str, pos = NilObject::NIL)
          if str.is_a?(NilObject)
            update_match_globals(nil)
            return NilObject::NIL
          end
          s = if str.is_a?(StringObject)
            str.raw
          elsif str.is_a?(SymbolObject)
            str.raw.to_s
          else
            klass = str.respond_to?(:class_object) ? (str.class_object&.name || str.class) : str.class
            begin
              result = str.dispatch(context, :to_str, [], {})
              unless result.is_a?(StringObject)
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
              end
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          p = pos.is_a?(IntegerObject) ? pos.raw : 0
          m = p == 0 ? receiver.raw.match(s) : receiver.raw.match(s, p)
          update_match_globals(m, receiver)
        end

        def regexp_match_bool(context, receiver, str, pos = NilObject::NIL)
          return FalseObject::FALSE if str.is_a?(NilObject)
          s = if str.is_a?(StringObject)
                str.raw
              elsif str.respond_to?(:raw)
                str.raw.to_s
              else
                begin
                  result = str.dispatch(context, :to_str, [], {})
                  result.is_a?(StringObject) ? result.raw : result.to_s
                rescue
                  str.to_s
                end
              end
          p = pos.is_a?(IntegerObject) ? pos.raw : 0
          bool_object_for(p == 0 ? receiver.raw.match?(s) : receiver.raw.match?(s, p))
        end

        def regexp_match_index(_, receiver, str)
          return NilObject::NIL if str.is_a?(NilObject)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          update_match_globals(m, receiver)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

        def match_data_group_key(context, n)
          if n.is_a?(IntegerObject)
            n.raw
          elsif n.is_a?(StringObject) || n.is_a?(SymbolObject)
            n.raw.to_s
          else
            klass = n.respond_to?(:class_object) ? (n.class_object&.name || n.class.to_s) : n.class.to_s
            begin
              result = n.dispatch(context, :to_int, [], {})
              result.is_a?(IntegerObject) ? result.raw : result.raw.to_i
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          end
        end

        def match_data_to_a(_, md)
          captures = [md.raw[0]] + md.raw.captures
          ArrayObject.new(captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_index(context, md, idx)
          raw = md.raw
          key = match_data_group_key(context, idx)
          val = raw[key]
          val ? StringObject.new(val) : NilObject::NIL
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_slice(_, md, start_obj, len_obj)
          s = start_obj.is_a?(IntegerObject) ? start_obj.raw : start_obj.raw.to_i
          l = len_obj.is_a?(IntegerObject) ? len_obj.raw : len_obj.raw.to_i
          all = [md.raw[0]] + md.raw.captures
          slice = all[s, l]
          return NilObject::NIL unless slice
          ArrayObject.new(slice.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_slice_range(_, md, range_obj)
          all = [md.raw[0]] + md.raw.captures
          r = range_obj.raw rescue (return NilObject::NIL)
          slice = all[r]
          return NilObject::NIL unless slice
          ArrayObject.new(slice.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_values_at_range(_, md, range_obj, size_obj)
          all = [md.raw[0]] + md.raw.captures
          size = all.size
          r = range_obj.raw rescue (return ArrayObject.new([]))
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
          result = indices.map { |i| i < size ? (all[i] ? StringObject.new(all[i]) : NilObject::NIL) : NilObject::NIL }
          ArrayObject.new(result)
        end

        def match_data_size(_, md)    = IntegerObject.new(md.raw.size)
        def match_data_pre_match(_, md)  = StringObject.new(md.raw.pre_match)
        def match_data_post_match(_, md) = StringObject.new(md.raw.post_match)
        def match_data_string(_, md)
          s = StringObject.new(md.raw.string.dup)
          s.freeze
          s
        end
        def match_data_regexp(_, md)
          md.frozone_regexp || RegexpObject.new(md.raw.regexp.source, md.raw.regexp.options)
        end

        def match_data_begin(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.begin(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_end(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.end(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_captures(_, md)
          ArrayObject.new(md.raw.captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_bytebegin(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.bytebegin(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        rescue ::NameError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_byteend(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.byteend(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        rescue ::NameError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_match_length(context, md, n)
          key = match_data_group_key(context, n)
          b = md.raw.begin(key)
          e = md.raw.end(key)
          return NilObject::NIL unless b && e
          IntegerObject.new(e - b)
        rescue ::IndexError => e
          raise FrozoneException.make(:IndexError, e.message)
        rescue ::NameError => e
          raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_hash(_, md)
          IntegerObject.new(md.raw.hash)
        end

        def match_data_named_captures(_, md)
          h = md.raw.named_captures.transform_keys { |k| StringObject.new(k) }
                                    .transform_values { |v| v ? StringObject.new(v) : NilObject::NIL }
          HashObject.new(h)
        end

        def match_data_names(_, md)
          ArrayObject.new(md.raw.regexp.named_captures.keys.map { |k| StringObject.new(k) })
        end
      end
    end
  end
end

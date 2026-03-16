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
        def update_match_globals(m)
          Fiber[:last_match] = m
          if m
            md = MatchDataObject.new(m)
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

        def regexp_source(_, r) = StringObject.new(r.raw.source)
        def regexp_options(_, r) = IntegerObject.new(r.raw.options)
        def regexp_inspect(_, r) = StringObject.new(r.raw.inspect)
        def regexp_to_s(_, r) = StringObject.new(r.raw.to_s)
        def regexp_casefold(_, r) = bool_object_for(r.raw.casefold?)
        def regexp_fixed_encoding(_, r) = bool_object_for(r.raw.fixed_encoding?)
        def regexp_escape(_, str) = StringObject.new(Regexp.escape(str.raw.to_s))

        def regexp_union(_, patterns)
          pats = patterns.raw.map { |p| p.is_a?(RegexpObject) ? p.raw : Regexp.escape(p.raw.to_s) }
          RegexpObject.new(pats.join('|'), '')
        end

        def regexp_last_match(_, n = nil)
          md = Fiber[:last_match]
          return NilObject::NIL unless md
          if n.nil? || n.is_a?(NilObject)
            MatchDataObject.new(md)
          else
            cap = md[n.raw]
            cap ? StringObject.new(cap) : NilObject::NIL
          end
        end

        def regexp_match(_, receiver, str)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          update_match_globals(m)
        end

        def regexp_match_index(_, receiver, str)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          update_match_globals(m)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

        def match_data_to_a(_, md)
          captures = [md.raw[0]] + md.raw.captures
          ArrayObject.new(captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_index(_, md, idx)
          raw = md.raw
          val = if idx.is_a?(IntegerObject)
            raw[idx.raw]
          elsif idx.is_a?(StringObject) || idx.is_a?(SymbolObject)
            raw[idx.raw.to_s]
          else
            raw[idx.raw]
          end
          val ? StringObject.new(val) : NilObject::NIL
        end

        def match_data_size(_, md)    = IntegerObject.new(md.raw.size)
        def match_data_pre_match(_, md)  = StringObject.new(md.raw.pre_match)
        def match_data_post_match(_, md) = StringObject.new(md.raw.post_match)
        def match_data_string(_, md)     = StringObject.new(md.raw.string.dup)
        def match_data_regexp(_, md)     = RegexpObject.new(md.raw.regexp.source, md.raw.regexp.options)

        def match_data_begin(_, md, n)
          v = md.raw.begin(n.is_a?(IntegerObject) ? n.raw : n.raw.to_s)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_end(_, md, n)
          v = md.raw.end(n.is_a?(IntegerObject) ? n.raw : n.raw.to_s)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_captures(_, md)
          ArrayObject.new(md.raw.captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
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

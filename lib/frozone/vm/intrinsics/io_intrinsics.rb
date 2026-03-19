# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # File / Dir
        def file_basename(_, path, suffix = NilObject::NIL) = StringObject.new(File.basename(path.raw, suffix.is_a?(NilObject) ? nil : suffix.raw))
        def file_absolute_path(_, path, base = NilObject::NIL) = StringObject.new(File.absolute_path(path.raw, base.is_a?(NilObject) ? nil : base.raw))
        def file_absolute_path_q(_, path) = bool_object_for(File.absolute_path?(path.raw))
        def file_exist(_, path) = bool_object_for(File.exist?(path.raw))
        def file_directory(_, path) = bool_object_for(File.directory?(path.raw))
        def file_file(_, path) = bool_object_for(File.file?(path.raw))
        def file_readable(_, path) = bool_object_for(File.readable?(path.raw))
        def file_readable_real(_, path) = bool_object_for(File.readable_real?(path.raw))
        def file_executable(_, path) = bool_object_for(File.executable?(path.raw))
        def file_executable_real(_, path) = bool_object_for(File.executable_real?(path.raw))
        def file_writable(_, path) = bool_object_for(File.writable?(path.raw))
        def file_writable_real(_, path) = bool_object_for(File.writable_real?(path.raw))
        def file_owned(_, path) = bool_object_for(File.owned?(path.raw)) rescue FalseObject::FALSE
        def file_grpowned(_, path) = bool_object_for(File.grpowned?(path.raw)) rescue FalseObject::FALSE
        def file_blockdev(_, path) = bool_object_for(File.blockdev?(path.raw)) rescue FalseObject::FALSE
        def file_chardev(_, path) = bool_object_for(File.chardev?(path.raw)) rescue FalseObject::FALSE
        def file_pipe(_, path) = bool_object_for(File.pipe?(path.raw)) rescue FalseObject::FALSE
        def file_socket(_, path) = bool_object_for(File.socket?(path.raw)) rescue FalseObject::FALSE
        def file_setuid(_, path) = bool_object_for(File.setuid?(path.raw)) rescue FalseObject::FALSE
        def file_setgid(_, path) = bool_object_for(File.setgid?(path.raw)) rescue FalseObject::FALSE
        def file_sticky(_, path) = bool_object_for(File.sticky?(path.raw)) rescue FalseObject::FALSE
        def file_identical(_, a, b) = bool_object_for(File.identical?(a.raw, b.raw)) rescue FalseObject::FALSE
        def file_ftype(_, path)      = reraise(Errno::ENOENT)        { StringObject.new(File.ftype(path.raw)) }
        def file_size_exact(_, path) = reraise(Errno::ENOENT)        { IntegerObject.new(File.size(path.raw)) }
        def file_atime(_, path)      = reraise(Errno::ENOENT)        { TimeObject.new(File.atime(path.raw)) }
        def file_mtime(_, path)      = reraise(Errno::ENOENT)        { TimeObject.new(File.mtime(path.raw)) }
        def file_ctime(_, path)      = reraise(Errno::ENOENT)        { TimeObject.new(File.ctime(path.raw)) }
        def file_read(_, path) = StringObject.new(File.read(path.raw))
        def file_symlink(_, path) = bool_object_for(File.symlink?(path.raw))
        def file_readlink(_, path) = reraise(Errno::ENOENT) { StringObject.new(File.readlink(path.raw)) }
        def file_zero(_, path) = bool_object_for(File.zero?(path.raw))
        def file_fnmatch(_, pattern, path, flags) = bool_object_for(File.fnmatch(pattern.raw, path.raw, flags.raw))
        # Returns nil - stat info accessed via individual methods
        def file_stat_native(_, path) = reraise(Errno::ENOENT) { NilObject::NIL }
        def file_stat_mode(_, path)      = stat_int_field(path) { |s| s.mode }
        def file_stat_ino(_, path)       = stat_int_field(path) { |s| s.ino }
        def file_stat_nlink(_, path)     = stat_int_field(path) { |s| s.nlink }
        def file_stat_uid(_, path)       = stat_int_field(path) { |s| s.uid }
        def file_stat_gid(_, path)       = stat_int_field(path) { |s| s.gid }
        def file_stat_dev(_, path)       = stat_int_field(path) { |s| s.dev }
        def file_stat_rdev(_, path)      = stat_int_field(path) { |s| s.rdev }
        def file_stat_dev_major(_, path) = stat_int_field(path) { |s| s.dev_major }
        def file_stat_dev_minor(_, path) = stat_int_field(path) { |s| s.dev_minor }
        def file_stat_rdev_major(_, path) = stat_int_field(path) { |s| s.rdev_major }
        def file_stat_rdev_minor(_, path) = stat_int_field(path) { |s| s.rdev_minor }
        def file_stat_blocks(_, path)    = stat_int_field(path) { |s| s.blocks || 0 }
        def file_stat_blksize(_, path)   = stat_int_field(path, default: 4096) { |s| s.blksize || 4096 }
        def dir_pwd(_) = StringObject.new(Dir.pwd)
        def dir_empty(_, path) = bool_object_for(Dir.empty?(path.raw))
        def dir_exist(_, path) = bool_object_for(path.raw && Dir.exist?(path.raw))
        def process_pid(_) = IntegerObject.new(Process.pid)
        def process_euid(_) = IntegerObject.new(Process.euid)

        def file_join(_, parts)
          strs = parts.raw.flat_map { |p| p.is_a?(ArrayObject) ? p.raw.map(&:raw) : p.raw }
          StringObject.new(File.join(*strs))
        end

        def file_dirname(_, path, level = NilObject::NIL)
          lvl = level.is_a?(NilObject) ? 1 : level.raw
          StringObject.new(File.dirname(path.raw, lvl))
        end

        def file_expand_path(_, path, base = NilObject::NIL) = reraise(ArgumentError) do
          StringObject.new(File.expand_path(path.raw, base.is_a?(NilObject) ? nil : base.raw))
        end

        def file_realpath(_, path, base = NilObject::NIL)
          StringObject.new(File.realpath(path.raw, base.is_a?(NilObject) ? nil : base.raw))
        rescue Errno::ENOENT => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        end

        def file_realdirpath(_, path, base = NilObject::NIL)
          StringObject.new(File.realdirpath(path.raw, base.is_a?(NilObject) ? nil : base.raw))
        rescue Errno::ENOENT => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        end

        def file_umask(_, new_mask)
          if new_mask.is_a?(NilObject)
            IntegerObject.new(File.umask)
          else
            old = File.umask(new_mask.is_a?(IntegerObject) ? new_mask.raw : new_mask.raw.to_i)
            IntegerObject.new(old)
          end
        end

        def file_size(_, path)
          s = File.size?(path.raw)
          s ? IntegerObject.new(s) : NilObject::NIL
        end

        def file_birthtime(_, path)
          TimeObject.new(File.birthtime(path.raw))
        rescue Errno::ENOENT        => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue NotImplementedError  => e then raise FrozoneException.make(:NotImplementedError, e.message)
        end

        def file_write(_, path, content)
          File.write(path.raw, content.raw)
          IntegerObject.new(content.raw.length)
        end

        def file_open(context, path, mode, block)
          mode_str = mode.is_a?(NilObject) ? 'r' : mode.raw
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

        def file_delete_strict(context, paths)
          raw_paths = paths.raw
          return IntegerObject.new(0) if raw_paths.empty?
          raw_paths.each do |p|
            path_str = coerce_to_path(context, p)
            reraise(Errno::ENOENT) { File.delete(path_str) }
          end
          IntegerObject.new(raw_paths.length)
        end

        def file_rename(_, from, to) = reraise(Errno::ENOENT) do
          File.rename(from.raw, to.raw)
          IntegerObject.new(0)
        end

        def file_symlink_create(_, target, link) = reraise(Errno::EEXIST) do
          File.symlink(target.raw, link.raw)
          IntegerObject.new(0)
        end

        def file_link(_, target, link) = reraise(Errno::ENOENT) do
          File.link(target.raw, link.raw)
          IntegerObject.new(0)
        end

        def file_chmod(_, mode_int, paths)
          count = 0
          paths.raw.each do |p|
            File.chmod(mode_int.raw, p.raw)
            count += 1
          end
          IntegerObject.new(count)
        rescue Errno::ENOENT => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue RangeError    => e then raise FrozoneException.make(:RangeError, e.message)
        end

        def file_truncate(_, path, length)
          len = length.is_a?(IntegerObject) ? length.raw : length.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          File.truncate(path.raw, len)
          IntegerObject.new(0)
        rescue Errno::ENOENT  => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue Errno::EINVAL  => e then raise FrozoneException.make(:Errno__EINVAL, e.message)
        end

        def file_mkfifo(_, path, mode) = reraise(NotImplementedError) do
          File.mkfifo(path.raw, mode.raw)
          IntegerObject.new(0)
        end

        def file_utime(_, atime, mtime, paths)
          a = atime.is_a?(NilObject) ? Time.now : (atime.is_a?(TimeObject) ? atime.raw : Time.at(atime.raw.to_f))
          m = mtime.is_a?(NilObject) ? Time.now : (mtime.is_a?(TimeObject) ? mtime.raw : Time.at(mtime.raw.to_f))
          path_strs = paths.raw.map { |p| p.is_a?(StringObject) ? p.raw : p.raw.to_s }
          File.utime(a, m, *path_strs)
          IntegerObject.new(path_strs.length)
        end

        def file_split(_, path)
          parts = File.split(path.raw)
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end

        def dir_home(_, user = NilObject::NIL) = reraise(ArgumentError) do
          u = user.is_a?(NilObject) ? nil : user.raw
          StringObject.new(u ? Dir.home(u) : Dir.home)
        end

        def dir_glob(context, pattern, flags = NilObject::NIL, base = NilObject::NIL, sort = NilObject::NIL)
          # pattern can be a String, Array, or object with to_path
          flag_int = flags.is_a?(NilObject) ? 0 : flags.raw.to_i
          base_str = base.is_a?(NilObject) ? nil : base.raw
          sort_val = sort.is_a?(NilObject) || (sort.is_a?(TrueObject) || (sort.is_a?(FalseObject) ? false : sort.raw))
          pats = if pattern.is_a?(ArrayObject)
                   pattern.raw.map { |p| coerce_to_path(context, p) }
                 elsif pattern.is_a?(StringObject)
                   pattern.raw
                 else
                   coerce_to_path(context, pattern)
                 end
          results = if base_str
                      Dir.glob(pats, flag_int, base: base_str, sort: sort_val)
                    else
                      Dir.glob(pats, flag_int, sort: sort_val)
                    end
          ArrayObject.new(results.map { |p| StringObject.new(p) })
        rescue ArgumentError => e then raise FrozoneException.make(:ArgumentError, e.message)
        end

        def dir_chdir(context, path, block)
          path_raw = path.is_a?(NilObject) ? nil : coerce_to_path(context, path)
          if block && !block.is_a?(NilObject)
            result = reraise(Errno::ENOENT) do
              path_raw ? Dir.chdir(path_raw) { block.invoke(context, [StringObject.new(Dir.pwd)]) } :
                         Dir.chdir { block.invoke(context, [StringObject.new(Dir.pwd)]) }
            end
            result.is_a?(ObjectObject) ? result : NilObject::NIL
          else
            reraise(Errno::ENOENT) { path_raw ? Dir.chdir(path_raw) : Dir.chdir }
            IntegerObject.new(0)
          end
        end

        def dir_mkdir(_, path, mode = NilObject::NIL)
          m = mode.is_a?(NilObject) ? 0o777 : mode.raw
          Dir.mkdir(path.raw, m)
          IntegerObject.new(0)
        rescue Errno::ENOENT  => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue Errno::EEXIST  => e then raise FrozoneException.make(:Errno__EEXIST, e.message)
        rescue Errno::EACCES  => e then raise FrozoneException.make(:Errno__EACCES, e.message)
        end

        def dir_entries(_, path)
          entries = Dir.entries(path.raw)
          ArrayObject.new(entries.map { |e| StringObject.new(e) })
        end

        def dir_rmdir(_, path)
          Dir.rmdir(path.raw)
          IntegerObject.new(0)
        rescue Errno::ENOENT    => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue Errno::EACCES    => e then raise FrozoneException.make(:Errno__EACCES, e.message)
        rescue Errno::ENOTEMPTY => e then raise FrozoneException.make(:Errno__ENOTEMPTY, e.message)
        end

        def dir_open(_, path)
          dir = ::Dir.new(path.raw)
          obj = ObjectObject.new(Core::OBJECT_CLASS)
          obj.instance_variable_set(:@__dir__, dir)
          obj
        rescue Errno::ENOENT  => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue Errno::ENOTDIR => e then raise FrozoneException.make(:Errno__ENOTDIR, e.message)
        end

        def dir_close(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.close if d
          NilObject::NIL
        rescue IOError
          NilObject::NIL
        end

        def dir_read(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          entry = d.read
          entry ? StringObject.new(entry) : NilObject::NIL
        end

        def dir_seek(_, dir_obj, pos)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.seek(pos.raw)
          NilObject::NIL
        end

        def dir_rewind(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.rewind
          NilObject::NIL
        end

        def dir_fileno(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          IntegerObject.new(d.fileno)
        rescue NotImplementedError
          IntegerObject.new(0)
        end

        def dir_chroot(_, path)
          Dir.chroot(path.raw)
          IntegerObject.new(0)
        rescue Errno::EPERM    => e then raise FrozoneException.make(:Errno__EPERM, e.message)
        rescue Errno::ENOENT   => e then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue SystemCallError => e then raise FrozoneException.make(:SystemCallError, e.message)
        end

        def dir_mktmpdir(context, prefix, block)
          require 'tmpdir'
          pfx = prefix.is_a?(NilObject) ? nil : prefix.raw
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

        def process_kill(_, sig_obj, pid_obj)
          sig = sig_obj.is_a?(IntegerObject) ? sig_obj.raw : sig_obj.raw.to_i
          pid = pid_obj.is_a?(IntegerObject) ? pid_obj.raw : pid_obj.raw.to_i
          Process.kill(sig, pid)
          NilObject::NIL
        end

        def process_clock_gettime(_, clock_id_obj, unit_obj)
          clock_id = clock_id_obj.is_a?(IntegerObject) ? clock_id_obj.raw : 1  # default CLOCK_MONOTONIC
          unit_sym = unit_obj.is_a?(SymbolObject) ? unit_obj.raw : :float_second
          result = Process.clock_gettime(clock_id, unit_sym)
          result.is_a?(Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        # Time

        # Wrap MRI utc_offset (Integer or Rational) as a Frozone object.
        def wrap_utc_offset(offset) = offset.is_a?(Integer) ? IntegerObject.new(offset) : make_rational(offset)

        def time_now(context) = time_make(context, Time.now)
        def time_to_f(_, t) = FloatObject.new(t.raw.to_f)
        def time_to_i(_, t) = IntegerObject.new(t.raw.to_i)
        def time_to_s(_, t) = StringObject.new(t.raw.to_s)
        def time_inspect(_, t) = StringObject.new(t.raw.inspect)
        def time_usec(_, t) = IntegerObject.new(t.raw.usec)
        def time_nsec(_, t) = IntegerObject.new(t.raw.nsec)
        def time_sec(_, t) = IntegerObject.new(t.raw.sec)
        def time_min(_, t) = IntegerObject.new(t.raw.min)
        def time_hour(_, t) = IntegerObject.new(t.raw.hour)
        def time_mday(_, t) = IntegerObject.new(t.raw.mday)
        def time_month(_, t) = IntegerObject.new(t.raw.month)
        def time_year(_, t) = IntegerObject.new(t.raw.year)
        def time_wday(_, t) = IntegerObject.new(t.raw.wday)
        def time_yday(_, t) = IntegerObject.new(t.raw.yday)
        def time_utc?(_, t) = bool_object_for(t.raw.utc?)
        def time_dup(_, t) = time_preserve_class(t, t.raw.dup)
        def time_utc_offset(_, t) = wrap_utc_offset(t.raw.utc_offset)
        def time_asctime(_, t) = StringObject.new(t.raw.asctime)
        def time_ceil(_, t, n) = TimeObject.new(t.raw.ceil(n.is_a?(IntegerObject) ? n.raw : 0))
        def time_floor(_, t, n) = TimeObject.new(t.raw.floor(n.is_a?(IntegerObject) ? n.raw : 0))
        def time_round(_, t, n) = TimeObject.new(t.raw.round(n.is_a?(IntegerObject) ? n.raw : 0))
        def time_load(_, str) = TimeObject.new(Time.send(:_load, str.raw))
        def time_strftime(_, t, format) = StringObject.new(t.raw.strftime(format.raw))
        def time_dst?(_, t) = bool_object_for(t.raw.dst?)
        def time_hash(_, t) = IntegerObject.new(t.raw.hash)

        # Extract an MRI Numeric from a Frozone value (Integer, Float, or Rational ObjectObject).
        # get_ivar returns NilObject::NIL (not MRI nil) when ivar is absent.
        def frozone_to_mri_numeric(obj)
          return obj.raw if obj.is_a?(IntegerObject) || obj.is_a?(FloatObject)
          return 0 if obj.is_a?(NilObject)
          num = obj.get_ivar(:@numerator)
          den = obj.get_ivar(:@denominator)
          # NilObject::NIL means the ivar is not set — not a Rational ObjectObject
          return obj.respond_to?(:raw) ? obj.raw : 0 if num.is_a?(NilObject) || den.is_a?(NilObject)
          n = num.is_a?(IntegerObject) ? num.raw : (num.respond_to?(:raw) ? num.raw.to_i : 0)
          d = den.is_a?(IntegerObject) ? den.raw : (den.respond_to?(:raw) ? den.raw.to_i : 1)
          d == 1 ? n : Rational(n, d)
        end

        # Create a TimeObject, inheriting the subclass from context.the_self when called
        # from a class method (Time.at on a subclass, Time.new on a subclass, etc.).
        def time_make(context, mri_time)
          t = TimeObject.new(mri_time)
          the_self = context.respond_to?(:the_self) ? context.the_self : context.frame&.the_self
          if the_self.is_a?(ClassObject) && !the_self.equal?(t.class_object)
            t.class_object = the_self
          end
          t
        end

        # Create a TimeObject preserving the class of an existing TimeObject (for instance methods).
        def time_preserve_class(src, mri_time)
          t = TimeObject.new(mri_time)
          t.class_object = src.class_object unless src.class_object.equal?(t.class_object)
          t
        end

        # time_at_raw: called from pure-Ruby Time.at after argument coercion.
        # t_r: Frozone Numeric (Integer/Float/Rational) or TimeObject; tz: Frozone String/Integer or nil.
        def time_at_raw(context, t_r, tz)
          # Pass TimeObject.raw directly so MRI Time.at(time) preserves the UTC flag.
          mri_r = t_r.is_a?(TimeObject) ? t_r.raw : frozone_to_mri_numeric(t_r)
          t = Time.at(mri_r)
          unless tz.is_a?(NilObject)
            tz_raw = tz.is_a?(StringObject) ? tz.raw : frozone_to_mri_numeric(tz).to_i
            t = t.localtime(tz_raw)
          end
          time_make(context, t)
        end

        # Legacy: still used when time_at is called without keyword args.
        def time_at(context, t, subsec = NilObject::NIL)
          raw_t = t.is_a?(TimeObject) ? t.raw : Time.at(frozone_to_mri_numeric(t))
          if subsec.is_a?(NilObject)
            time_make(context, Time.at(raw_t))
          else
            time_make(context, Time.at(raw_t, subsec.raw.to_f))
          end
        end

        def time_mktime(context, year, month, day, hour, min, sec, usec, use_utc, isdst = NilObject::NIL)
          y  = frozone_to_mri_numeric(year).to_i
          mo = frozone_to_mri_numeric(month).to_i
          d  = frozone_to_mri_numeric(day).to_i
          h  = frozone_to_mri_numeric(hour).to_i
          mi = frozone_to_mri_numeric(min).to_i
          s  = frozone_to_mri_numeric(sec)   # Rational preserved
          us = frozone_to_mri_numeric(usec)  # Rational preserved
          # 10-arg C-style form with isdst hint for DST disambiguation (local only).
          if !(use_utc.is_a?(TrueObject) || use_utc == true) &&
             (isdst.is_a?(TrueObject) || isdst.is_a?(FalseObject) || isdst == true || isdst == false)
            isdst_val = isdst.is_a?(TrueObject) || isdst == true
            return time_make(context, Time.local(s, mi, h, d, mo, y, 0, 0, isdst_val, nil))
          end
          # Passing usec=0 explicitly clobbers fractional seconds in sec (Rational).
          # Only pass usec if it's non-zero.
          args = us.zero? ? [y, mo, d, h, mi, s] : [y, mo, d, h, mi, s, us]
          if use_utc.is_a?(TrueObject) || use_utc == true
            time_make(context, Time.utc(*args))
          else
            time_make(context, Time.local(*args))
          end
        end

        def time_new(context, year, month, day, hour, min, sec, tz)
          if year.is_a?(NilObject)
            if tz.is_a?(NilObject)
              return time_make(context, Time.now)
            else
              tz_mri = tz.is_a?(StringObject) ? tz.raw : frozone_to_mri_numeric(tz)
              tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
              return time_make(context, Time.now.localtime(tz_val))
            end
          end
          mri_args = [year, month, day, hour, min, sec].map { |a|
            a.is_a?(NilObject) ? nil : frozone_to_mri_numeric(a)
          }
          if tz.is_a?(NilObject)
            # Drop trailing nils to use MRI defaults
            trimmed = mri_args.reverse.drop_while(&:nil?).reverse
            time_make(context, Time.new(*trimmed))
          else
            tz_mri = tz.is_a?(StringObject) ? tz.raw : frozone_to_mri_numeric(tz)
            # Strings, Rationals, Floats pass through as-is; other numerics → int
            tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
            time_make(context, Time.new(*mri_args, tz_val))
          end
        end

        # time_new_from_string: Time.new("2021-12-25 00:00:00 +09:00", precision:, in:)
        # precision: IntegerObject (9 = ns default) or NilObject (unlimited)
        # in_tz: Frozone String/Integer/Rational or NilObject
        def time_new_from_string(context, str, precision, in_tz)
          mri_str = str.is_a?(StringObject) ? str.raw : str.to_s
          mri_prec = if precision.is_a?(NilObject)
                       nil
                     elsif precision.is_a?(IntegerObject)
                       precision.raw
                     else
                       frozone_to_mri_numeric(precision).to_i
                     end
          opts = {}
          opts[:precision] = mri_prec unless mri_prec == 9
          unless in_tz.is_a?(NilObject)
            opts[:in] = in_tz.is_a?(StringObject) ? in_tz.raw : frozone_to_mri_numeric(in_tz)
          end
          t = opts.empty? ? Time.new(mri_str) : Time.new(mri_str, **opts)
          time_make(context, t)
        rescue ArgumentError, TypeError => e then raise FrozoneException.make(e.class.name.to_sym, e.message)
        end

        def time_minus(_, t, other)
          if other.is_a?(TimeObject)
            FloatObject.new(t.raw - other.raw)
          else
            TimeObject.new(t.raw - frozone_to_mri_numeric(other))
          end
        end

        def time_plus(_, t, secs) = reraise(TypeError) do
          raise FrozoneException.make(:TypeError, "can't convert NilClass into an exact number") if secs.is_a?(NilObject)
          TimeObject.new(t.raw + frozone_to_mri_numeric(secs))
        end

        def time_to_r(_, t)
          r = begin; t.raw.to_r; rescue; Rational(t.raw.to_i, 1); end
          make_rational(r)
        end

        def time_zone(_, t)
          z = t.raw.zone
          z.nil? || z.empty? ? NilObject::NIL : StringObject.new(z)
        end

        def time_localtime(_, t, tz = NilObject::NIL)
          if t.frozen_object?
            # localtime() with no arg on an already-local frozen time is a no-op (no error)
            return t if tz.is_a?(NilObject) && !t.raw.utc?
            raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
          end

          if tz.is_a?(NilObject)
            t.raw.localtime
          elsif tz.is_a?(StringObject)
            t.raw.localtime(tz.raw)
          elsif tz.is_a?(IntegerObject)
            t.raw.localtime(tz.raw)
          elsif tz.is_a?(FloatObject)
            t.raw.localtime(tz.raw.to_i)
          else
            mri_tz = frozone_to_mri_numeric(tz)
            # Preserve Rational offsets; fall back to integer for other numerics
            tz_val = mri_tz.is_a?(Rational) ? mri_tz : mri_tz.to_i
            t.raw.localtime(tz_val)
          end
          t
        rescue FrozoneException
          raise
        rescue TypeError, ArgumentError => e then raise FrozoneException.make(e.class.name.to_sym, e.message)
        end

        def time_utc(_, t)
          if t.frozen_object?
            return t if t.raw.utc?
            raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
          end
          t.raw.utc
          t
        end

        def time_subsec(_, t)
          r = t.raw.subsec
          r.is_a?(Integer) ? IntegerObject.new(r) : make_rational(r)
        end

        def time_iso8601(_, t, n)
          ndigits = n.is_a?(IntegerObject) ? n.raw : 0
          StringObject.new(t.raw.iso8601(ndigits))
        end

        def time_dump(_, t)
          d = t.raw.send(:_dump, -1)
          StringObject.new(d)
        end

        # Regexp
        def regexp_newly_created_q(_, r) = r.is_a?(RegexpObject) ? bool_object_for(r.newly_created_for_subclass) : FalseObject::FALSE
        def regexp_source(_, r) = StringObject.new(r.raw.source)
        def regexp_inspect(_, r) = StringObject.new(r.raw.inspect)
        def regexp_to_s(_, r) = StringObject.new(r.raw.to_s)
        def regexp_casefold(_, r) = bool_object_for(r.raw.casefold?)
        def regexp_fixed_encoding(_, r) = bool_object_for(r.raw.fixed_encoding?)
        def regexp_escape(_, str) = StringObject.new(Regexp.escape(str.raw.to_s))
        def regexp_hash(_, r) = IntegerObject.new(r.raw.hash)
        def regexp_names(_, r) = ArrayObject.new(r.raw.names.map { |n| StringObject.new(n) })
        def match_data_size(_, md)    = IntegerObject.new(md.raw.size)
        def match_data_pre_match(_, md)  = StringObject.new(md.raw.pre_match)
        def match_data_post_match(_, md) = StringObject.new(md.raw.post_match)
        def match_data_regexp(_, md) = md.frozone_regexp || RegexpObject.new(md.raw.regexp.source, md.raw.regexp.options)
        def match_data_captures(_, md) = ArrayObject.new(md.raw.captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        def match_data_hash(_, md) = IntegerObject.new(md.raw.hash)
        def match_data_names(_, md) = ArrayObject.new(md.raw.regexp.named_captures.keys.map { |k| StringObject.new(k) })

        def update_match_globals(m, regexp_obj = NilObject::NIL)
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

        def regexp_new(context, klass, pattern, options = NilObject::NIL, kw_opts = NilObject::NIL)
          regexp_class = Core::OBJECT_CLASS.get_constant(:Regexp)
          if pattern.is_a?(RegexpObject)
            # When given a Regexp, use its source+options; warn and ignore extra options
            if options && !options.is_a?(NilObject) && !options.is_a?(FalseObject)
              kernel_warn(context, NilObject::NIL, ArrayObject.new([StringObject.new("warning: flags ignored")]))
            end
            result = RegexpObject.new(pattern.raw.source, pattern.raw.options, pattern.raw.encoding.name, klass: klass)
            unless klass.equal?(regexp_class)
              result.newly_created_for_subclass = true
              result.dispatch(context, :initialize, [pattern, options || NilObject::NIL], {}, nil, private_ok: true)
              result.newly_created_for_subclass = false
            end
            return result
          end
          pat_raw = coerce_regexp_pattern(context, pattern)
          flags = regexp_flags_from_options(context, options)
          timeout_val = regexp_timeout_from_kw_opts(kw_opts)
          result = RegexpObject.new(pat_raw, flags, klass: klass, timeout: timeout_val)
          unless klass.equal?(regexp_class)
            result.newly_created_for_subclass = true
            result.dispatch(context, :initialize, [pattern, options || NilObject::NIL], {}, nil, private_ok: true)
            result.newly_created_for_subclass = false
          end
          result
        rescue ::RegexpError => e then raise FrozoneException.make(:RegexpError, e.message)
        end

        def regexp_options(_, r)
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless r.is_a?(RegexpObject)
          IntegerObject.new(r.raw.options)
        end

        def regexp_linear_time_q(_, r)
          bool_object_for(Regexp.linear_time?(r.raw))
        rescue
          FalseObject::FALSE
        end

        def regexp_class_linear_time_q(context, pattern, flags = NilObject::NIL)
          if pattern.is_a?(RegexpObject)
            unless flags.is_a?(NilObject)
              kernel_warn(context, NilObject::NIL, ArrayObject.new([StringObject.new("warning: flags ignored")]))
            end
            raw_pat = pattern.raw
          elsif pattern.is_a?(StringObject)
            opts = flags.is_a?(IntegerObject) ? flags.raw : 0
            raw_pat = reraise(::RegexpError) { Regexp.new(pattern.raw, opts) }
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

        def regexp_tilde(context, receiver)
          dollar_underscore = GLOBALS[:"$_"]
          return NilObject::NIL unless dollar_underscore.is_a?(StringObject)
          s = dollar_underscore.raw
          m = receiver.raw.match(s)
          update_match_globals(m, receiver)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

        REGEXP_TIMEOUT = [nil]

        def regexp_timeout(_, _r)
          v = REGEXP_TIMEOUT[0]
          return NilObject::NIL if v.nil?
          v.is_a?(Integer) ? IntegerObject.new(v) : FloatObject.new(v)
        end

        def regexp_set_timeout(_, _r, val)
          raw_val = val.is_a?(NilObject) ? nil : val.raw
          REGEXP_TIMEOUT[0] = raw_val
          ::Regexp.timeout = raw_val
          val
        end

        def regexp_union(context, patterns)
          raw_pats = patterns.raw
          # Unwrap single array argument: Regexp.union(["a", "b"]) → treat as Regexp.union("a", "b")
          raw_pats = raw_pats[0].raw if raw_pats.length == 1 && raw_pats[0].is_a?(ArrayObject)
          return RegexpObject.new('(?!)', 0) if raw_pats.empty?
          pats = raw_pats.map { |p| coerce_union_element(context, p) }
          ::Regexp.union(*pats).then { |r| RegexpObject.new(r.source, r.options) }
        rescue ::ArgumentError => e then raise FrozoneException.make(:ArgumentError, e.message)
        end

        def regexp_last_match(context, n = NilObject::NIL)
          md = Fiber[:last_match]
          return NilObject::NIL unless md
          if n.is_a?(NilObject)
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
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless receiver.is_a?(RegexpObject)
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
          begin
            m = p == 0 ? receiver.raw.match(s) : receiver.raw.match(s, p)
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
          update_match_globals(m, receiver)
        end

        def regexp_match_bool(context, receiver, str, pos = NilObject::NIL)
          raise FrozoneException.make(:TypeError, "uninitialized Regexp") unless receiver.is_a?(RegexpObject)
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
          begin
            bool_object_for(p == 0 ? receiver.raw.match?(s) : receiver.raw.match?(s, p))
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
        end

        def regexp_match_index(_, receiver, str)
          return NilObject::NIL if str.is_a?(NilObject)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          begin
            m = receiver.raw.match(s)
          rescue ::Regexp::TimeoutError => e
            vm_obj = FrozoneException.wrap_mri(e)
            raise FrozoneException.new(vm_obj, e.message)
          end
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

        def match_data_index(context, md, idx) = reraise(::IndexError) do
          key = match_data_group_key(context, idx)
          val = md.raw[key]
          val ? StringObject.new(val) : NilObject::NIL
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

        def match_data_string(_, md)
          s = StringObject.new(md.raw.string.dup)
          s.freeze
          s
        end

        def match_data_begin(context, md, n) = reraise(::IndexError) do
          key = match_data_group_key(context, n)
          v = md.raw.begin(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_end(context, md, n) = reraise(::IndexError) do
          key = match_data_group_key(context, n)
          v = md.raw.end(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_bytebegin(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.bytebegin(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError, ::NameError => e then raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_byteend(context, md, n)
          key = match_data_group_key(context, n)
          v = md.raw.byteend(key)
          v ? IntegerObject.new(v) : NilObject::NIL
        rescue ::IndexError, ::NameError => e then raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_match_length(context, md, n)
          key = match_data_group_key(context, n)
          b = md.raw.begin(key)
          e = md.raw.end(key)
          return NilObject::NIL unless b && e
          IntegerObject.new(e - b)
        rescue ::IndexError, ::NameError => e then raise FrozoneException.make(:IndexError, e.message)
        end

        def match_data_named_captures(_, md)
          h = md.raw.named_captures.transform_keys { |k| StringObject.new(k) }
                .transform_values { |v| v ? StringObject.new(v) : NilObject::NIL }
          HashObject.new(h)
        end

        def io_popen_capture(_, cmd, opts_obj = NilObject::NIL)
          mri_opts = {}
          if opts_obj.is_a?(HashObject) && !opts_obj.raw.empty?
            opts_obj.raw.each do |k, v|
              key = k.is_a?(SymbolObject) ? k.raw : k.raw.to_sym
              val = case v
                    when ArrayObject then v.raw.map { |e| e.is_a?(SymbolObject) ? e.raw : e.raw }
                    when SymbolObject then v.raw
                    when IntegerObject then v.raw
                    else v.raw
                    end
              mri_opts[key] = val
            end
          end
          output = if cmd.is_a?(ArrayObject)
                     ::IO.popen(cmd.raw.map { |a| a.is_a?(StringObject) ? a.raw : a.to_s }, 'r', **mri_opts, &:read) rescue ""
                   elsif cmd.is_a?(StringObject)
                     ::IO.popen(cmd.raw, 'r', **mri_opts, &:read) rescue ""
                   else
                     ::IO.popen(cmd.to_s, 'r', **mri_opts, &:read) rescue ""
                   end
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
          StringObject.new(output || "")
        end

        def io_external_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.external_encoding rescue nil
          return NilObject::NIL if enc.nil?
          StringObject.new(enc.name)
        end

        def io_explicit_encoding?(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          bool_object_for(receiver.explicit_encoding?)
        end

        def io_mark_explicit_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          receiver.instance_variable_set(:@explicit_encoding, true)
          NilObject::NIL
        end

        def encoding_set_default_external(_, name_obj)
          name = name_obj.is_a?(StringObject) ? name_obj.raw : (name_obj.is_a?(NilObject) ? nil : name_obj.to_s)
          enc = name ? ::Encoding.find(name) : ::Encoding::UTF_8 rescue nil
          ::Encoding.default_external = enc if enc
          NilObject::NIL
        end

        def encoding_set_default_internal(_, name_obj)
          name = name_obj.is_a?(StringObject) ? name_obj.raw : (name_obj.is_a?(NilObject) ? nil : name_obj.to_s)
          enc = name ? ::Encoding.find(name) : nil rescue nil
          ::Encoding.default_internal = enc
          NilObject::NIL
        end

        def io_sysopen(_, path_obj, mode_obj = NilObject::NIL, perm_obj = NilObject::NIL)
          path = path_obj.is_a?(StringObject) ? path_obj.raw : path_obj.to_s
          mode = if mode_obj.is_a?(NilObject) then 'r'
                 elsif mode_obj.is_a?(StringObject) then mode_obj.raw
                 elsif mode_obj.is_a?(IntegerObject) then mode_obj.raw
                 else
                   'r'
                 end
          perm = perm_obj.is_a?(IntegerObject) ? perm_obj.raw : 0o666
          IntegerObject.new(::IO.sysopen(path, mode, perm))
        rescue ::Errno::ENOENT => e  then raise FrozoneException.make(:Errno__ENOENT, e.message)
        rescue ::Errno::EACCES => e  then raise FrozoneException.make(:Errno__EACCES, e.message)
        rescue ::TypeError => e      then raise FrozoneException.make(:TypeError, e.message)
        rescue ::ArgumentError => e  then raise FrozoneException.make(:ArgumentError, e.message)
        rescue ::SystemCallError => e then raise FrozoneException.make(:SystemCallError, e.message)
        end

        def io_new_from_fd(_, fd_obj, mode_obj = NilObject::NIL, opts_obj = NilObject::NIL)
          fd = fd_obj.is_a?(IntegerObject) ? fd_obj.raw : fd_obj.raw.to_i
          mode, opts = parse_io_mode(mode_obj, opts_obj)
          explicit_enc = (mode.is_a?(::String) && mode.include?(':')) ||
                         opts.key?(:encoding) || opts.key?(:external_encoding)
          native_io = if mode && opts.empty? then ::IO.new(fd, mode)
                      elsif mode             then ::IO.new(fd, mode, **opts)
                      elsif opts.empty?      then ::IO.new(fd)
                      else
                        ::IO.new(fd, **opts)
                      end
          IOObject.new(native_io, Core.io_class, explicit_encoding: explicit_enc)
        rescue ::ArgumentError => e   then raise FrozoneException.make(:ArgumentError, e.message)
        rescue ::TypeError => e       then raise FrozoneException.make(:TypeError, e.message)
        rescue ::SystemCallError => e then raise FrozoneException.make(:SystemCallError, e.message)
        end

        def io_read(_, receiver, len_obj = NilObject::NIL, buf_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          len = len_obj.is_a?(NilObject) ? nil : len_obj.raw
          result = len ? receiver.native_io.read(len) : receiver.native_io.read
          result.nil? ? NilObject::NIL : StringObject.new(result)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_gets(_, receiver, sep_obj = NilObject::NIL, limit_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          sep = sep_obj.is_a?(NilObject) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          line = receiver.native_io.gets(sep)
          line.nil? ? NilObject::NIL : StringObject.new(line)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_readline(_, receiver, sep_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          sep = sep_obj.is_a?(NilObject) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          StringObject.new(receiver.native_io.readline(sep))
        rescue ::EOFError => e then raise FrozoneException.make(:EOFError, e.message)
        rescue ::IOError => e  then raise FrozoneException.make(:IOError, e.message)
        end

        def io_readlines(_, receiver, sep_obj = NilObject::NIL)
          return ArrayObject.new([]) unless receiver.is_a?(IOObject)
          sep = sep_obj.is_a?(NilObject) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          ArrayObject.new(receiver.native_io.readlines(sep).map { |l| StringObject.new(l) })
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_close(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          receiver.native_io.close rescue nil
          NilObject::NIL
        end

        def io_closed?(_, receiver)
          return TrueObject::TRUE unless receiver.is_a?(IOObject)
          bool_object_for(receiver.native_io.closed?)
        end

        def io_fileno(_, receiver)
          return IntegerObject.new(1) unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.fileno)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_eof?(_, receiver)
          return TrueObject::TRUE unless receiver.is_a?(IOObject)
          bool_object_for(receiver.native_io.eof?)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_seek(_, receiver, offset_obj, whence_obj = NilObject::NIL)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          offset = offset_obj.is_a?(IntegerObject) ? offset_obj.raw : 0
          whence = whence_obj.is_a?(NilObject) ? ::IO::SEEK_SET : whence_obj.raw
          IntegerObject.new(receiver.native_io.seek(offset, whence))
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_pos(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.pos)
        end

        def io_pos_set(_, receiver, pos_obj)
          return pos_obj unless receiver.is_a?(IOObject)
          receiver.native_io.pos = pos_obj.is_a?(IntegerObject) ? pos_obj.raw : 0
          pos_obj
        end

        def io_rewind(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          receiver.native_io.rewind
          IntegerObject.new(0)
        end

        def io_binmode(_, receiver)
          return receiver unless receiver.is_a?(IOObject)
          receiver.native_io.binmode
          receiver
        end

        def io_binmode?(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          bool_object_for(receiver.native_io.binmode?)
        end

        def io_set_encoding(_, receiver, ext_obj, int_obj = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject)
          ext_enc = extract_encoding_name(ext_obj)
          int_enc = extract_encoding_name(int_obj)
          if int_enc
            receiver.native_io.set_encoding(ext_enc, int_enc)
          elsif ext_enc
            receiver.native_io.set_encoding(ext_enc)
          end rescue nil
          receiver
        end

        def io_internal_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.internal_encoding rescue nil
          enc ? StringObject.new(enc.name) : NilObject::NIL
        end

        def io_isatty(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          bool_object_for(receiver.native_io.isatty)
        end

        def io_getbyte(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          b = receiver.native_io.getbyte
          b.nil? ? NilObject::NIL : IntegerObject.new(b)
        end

        def io_getc(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          c = receiver.native_io.getc
          c.nil? ? NilObject::NIL : StringObject.new(c)
        end

        def io_readbyte(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.readbyte)
        rescue ::EOFError => e then raise FrozoneException.make(:EOFError, e.message)
        end

        def io_readchar(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          StringObject.new(receiver.native_io.readchar)
        rescue ::EOFError => e then raise FrozoneException.make(:EOFError, e.message)
        end

        def io_ungetbyte(_, receiver, byte_obj)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          byte = byte_obj.is_a?(IntegerObject) ? byte_obj.raw : (byte_obj.is_a?(StringObject) ? byte_obj.raw : nil)
          receiver.native_io.ungetbyte(byte) if byte
          NilObject::NIL
        end

        def io_ungetc(_, receiver, str_obj)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          receiver.native_io.ungetc(str_obj.is_a?(StringObject) ? str_obj.raw : str_obj.to_s)
          NilObject::NIL
        end

        def io_sysread(_, receiver, len_obj, buf_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          StringObject.new(receiver.native_io.sysread(len_obj.is_a?(IntegerObject) ? len_obj.raw : 0))
        rescue ::EOFError => e then raise FrozoneException.make(:EOFError, e.message)
        rescue ::IOError => e  then raise FrozoneException.make(:IOError, e.message)
        end

        def io_syswrite(_, receiver, str_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.syswrite(str_obj.is_a?(StringObject) ? str_obj.raw : str_obj.to_s))
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_each_line(context, receiver, sep_obj = NilObject::NIL, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject) && block && !block.is_a?(NilObject)
          sep = sep_obj.is_a?(NilObject) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : $/)
          receiver.native_io.each_line(sep) { |line| block.invoke(context, [StringObject.new(line)]) }
          receiver
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_each_byte(context, receiver, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject) && block && !block.is_a?(NilObject)
          receiver.native_io.each_byte { |b| block.invoke(context, [IntegerObject.new(b)]) }
          receiver
        end

        def io_each_char(context, receiver, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject) && block && !block.is_a?(NilObject)
          receiver.native_io.each_char { |c| block.invoke(context, [StringObject.new(c)]) }
          receiver
        end

        def io_stat(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          stat = receiver.native_io.stat
          stat_obj = ObjectObject.new(Core::OBJECT_CLASS.get_constant(:File)&.get_constant(:Stat) || Core::OBJECT_CLASS)
          stat_obj.set_ivar(:@native_stat, ObjectObject.new(Core::OBJECT_CLASS).tap { |o| o.instance_variable_set(:@raw, stat) })
          stat_obj
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_inspect(_, receiver)
          return StringObject.new("#<IO>") unless receiver.is_a?(IOObject)
          StringObject.new(receiver.native_io.inspect)
        rescue
          StringObject.new("#<IO>")
        end

        def io_chmod(_, receiver, mode_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          mode = mode_obj.is_a?(IntegerObject) ? mode_obj.raw : mode_obj.raw.to_i
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if mode > 2**32 || mode < -(2**31)
          receiver.native_io.chmod(mode)
          IntegerObject.new(0)
        rescue ::RangeError => e   then raise FrozoneException.make(:RangeError, e.message)
        rescue ::Errno::EBADF => e then raise FrozoneException.make(:Errno__EBADF, e.message)
        end

        def io_truncate(_, receiver, len_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          len = len_obj.is_a?(IntegerObject) ? len_obj.raw : len_obj.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          receiver.native_io.truncate(len)
          IntegerObject.new(0)
        rescue ::IOError => e      then raise FrozoneException.make(:IOError, e.message)
        rescue ::Errno::EINVAL => e then raise FrozoneException.make(:Errno__EINVAL, e.message)
        end

        def io_writable?(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          bool_object_for((receiver.native_io.stat.mode rescue 0) & 0o200 != 0)
        rescue
          FalseObject::FALSE
        end

        def io_atime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.atime)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_mtime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.mtime)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_ctime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.ctime)
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        def io_birthtime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.birthtime)
        rescue ::IOError => e          then raise FrozoneException.make(:IOError, e.message)
        rescue ::NotImplementedError => e then raise FrozoneException.make(:NotImplementedError, e.message)
        end

        def io_path(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          path = receiver.native_io.path rescue nil
          path ? StringObject.new(path) : NilObject::NIL
        rescue
          NilObject::NIL
        end

        def io_flock(_, receiver, lock_op_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.flock(lock_op_obj.is_a?(IntegerObject) ? lock_op_obj.raw : 0))
        rescue ::IOError => e then raise FrozoneException.make(:IOError, e.message)
        end

        # print/puts/write/flush/sync_set delegate to a native IO, defaulting to $stdout
        def io_print(context, receiver, args)
          native = native_io_for(receiver)
          args.raw.each { |a| native.print(a.dispatch(context, :to_s, [], {}).raw) }
          NilObject::NIL
        end

        def io_puts(context, receiver, args)
          native = native_io_for(receiver)
          if args.raw.empty?
            native.puts
          else
            args.raw.each { |a| native.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          NilObject::NIL
        end

        def io_write(context, receiver, args)
          native = native_io_for(receiver)
          s = args.raw.first.dispatch(context, :to_s, [], {}).raw
          native.write(s)
          IntegerObject.new(s.bytesize)
        end

        def io_flush(_, receiver)
          native_io_for(receiver).flush rescue nil
          receiver
        end

        def io_sync_set(_, receiver, val)
          native_io_for(receiver).sync = val.truthy? rescue nil
          val
        end

        private

        def native_io_for(receiver) = receiver.is_a?(IOObject) ? receiver.native_io : $stdout

        def stat_int_field(path, default: 0)
          IntegerObject.new(yield File.stat(path.raw))
        rescue Errno::ENOENT, Errno::EACCES
          IntegerObject.new(default)
        end

        def coerce_to_path(context, obj)
          return obj.raw if obj.is_a?(StringObject)
          begin
            r = obj.dispatch(context, :to_path, [], {})
            return r.is_a?(StringObject) ? r.raw : r.raw.to_s
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
          end
          begin
            r = obj.dispatch(context, :to_str, [], {})
            r.is_a?(StringObject) ? r.raw : r.raw.to_s
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object&.name || obj.class} into String")
          end
        end

        def extract_encoding_name(enc_obj)
          case enc_obj
          when StringObject then enc_obj.raw
          when NilObject, nil then nil
          when ObjectObject
            n = enc_obj.get_ivar(:@name)
            n.is_a?(StringObject) ? n.raw : nil
          else nil
          end
        end

        # Coerce a Regexp pattern argument (non-Regexp) to a raw String.
        def coerce_regexp_pattern(context, pattern)
          pat_klass = pattern.respond_to?(:class_object) ? (pattern.class_object&.name || pattern.class) : pattern.class
          return pattern.raw if pattern.is_a?(StringObject)
          begin
            result = pattern.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "can't convert #{pat_klass} into String") unless result.is_a?(StringObject)
            result.raw
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{pat_klass} into String")
          end
        end

        # Convert Regexp.new options argument to raw flags (Integer or String).
        def regexp_flags_from_options(context, options)
          if options.is_a?(NilObject) || options.is_a?(FalseObject)
            0
          elsif options.is_a?(IntegerObject)
            options.raw
          elsif options.is_a?(StringObject)
            options.raw
          elsif options.is_a?(TrueObject)
            Regexp::IGNORECASE
          else
            kernel_warn(context, NilObject::NIL, ArrayObject.new([StringObject.new("warning: expected true or false as ignorecase")]))
            Regexp::IGNORECASE
          end
        end

        # Extract :timeout from Regexp.new keyword options hash.
        def regexp_timeout_from_kw_opts(kw_opts)
          return nil unless kw_opts.is_a?(HashObject)
          kw_opts.raw.each do |k, v|
            if k.is_a?(SymbolObject) && k.raw == :timeout
              return v.is_a?(FloatObject) ? v.raw : (v.is_a?(IntegerObject) ? v.raw.to_f : nil)
            end
          end
          nil
        end

        # Coerce a single element of Regexp.union arguments to a raw String or Regexp.
        def coerce_union_element(context, p)
          return p.raw if p.is_a?(RegexpObject)
          return p.raw if p.is_a?(StringObject)
          return p.raw.to_s if p.is_a?(SymbolObject)
          klass = p.respond_to?(:class_object) ? (p.class_object&.name || p.class) : p.class
          begin
            result = p.dispatch(context, :to_regexp, [], {})
            return result.raw if result.is_a?(RegexpObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Regexp")
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
          end
          begin
            str_result = p.dispatch(context, :to_str, [], {})
            return str_result.is_a?(StringObject) ? str_result.raw : str_result.raw.to_s
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
          end
        end

        # Parse IO.new mode and opts arguments.
        # Returns [mode, opts_hash] where mode is nil/String/Integer and opts_hash is a Ruby Hash.
        def parse_io_mode(mode_obj, opts_obj)
          mode = if mode_obj.is_a?(NilObject) then nil
                 elsif mode_obj.is_a?(StringObject) then mode_obj.raw
                 elsif mode_obj.is_a?(IntegerObject) then mode_obj.raw
                 elsif mode_obj.is_a?(HashObject) then (opts_obj = mode_obj; nil)
                 else
                   nil
                 end
          opts = {}
          if opts_obj.is_a?(HashObject)
            opts_obj.raw.each do |k, v|
              opts[k.is_a?(SymbolObject) ? k.raw : k.to_s.to_sym] = case v
                                                                    when StringObject  then v.raw
                                                                    when IntegerObject then v.raw
                                                                    when TrueObject    then true
                                                                    when FalseObject   then false
                                                                    when NilObject     then nil
                                                                    else v
                                                                    end
            end
          end
          [mode, opts]
        end
      end
    end
  end
end

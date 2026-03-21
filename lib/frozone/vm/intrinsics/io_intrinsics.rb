# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # File / Dir
        def file_basename(_, path, suffix = FNIL) = fnil?(suffix) ? n2f_str(File.basename(path.raw)) : n2f_str(File.basename(path.raw, suffix.raw))
        def file_absolute_path(_, path, base = FNIL) = n2f_str(File.absolute_path(path.raw, f2n_raw(base)))
        def file_absolute_path_q(_, path) = n2f_bool(File.absolute_path?(path.raw))
        def file_exist(_, path) = n2f_bool(File.exist?(path.raw))
        def file_directory(_, path) = n2f_bool(File.directory?(path.raw))
        def file_file(_, path) = n2f_bool(File.file?(path.raw))
        def file_readable(_, path) = n2f_bool(File.readable?(path.raw))
        def file_readable_real(_, path) = n2f_bool(File.readable_real?(path.raw))
        def file_executable(_, path) = n2f_bool(File.executable?(path.raw))
        def file_executable_real(_, path) = n2f_bool(File.executable_real?(path.raw))
        def file_writable(_, path) = n2f_bool(File.writable?(path.raw))
        def file_writable_real(_, path) = n2f_bool(File.writable_real?(path.raw))
        def file_owned(_, path) = n2f_bool(File.owned?(path.raw)) rescue FFALSE
        def file_grpowned(_, path) = n2f_bool(File.grpowned?(path.raw)) rescue FFALSE
        def file_blockdev(_, path) = n2f_bool(File.blockdev?(path.raw)) rescue FFALSE
        def file_chardev(_, path) = n2f_bool(File.chardev?(path.raw)) rescue FFALSE
        def file_pipe(_, path) = n2f_bool(File.pipe?(path.raw)) rescue FFALSE
        def file_socket(_, path) = n2f_bool(File.socket?(path.raw)) rescue FFALSE
        def file_setuid(_, path) = n2f_bool(File.setuid?(path.raw)) rescue FFALSE
        def file_setgid(_, path) = n2f_bool(File.setgid?(path.raw)) rescue FFALSE
        def file_sticky(_, path) = n2f_bool(File.sticky?(path.raw)) rescue FFALSE
        def file_identical(_, a, b) = n2f_bool(File.identical?(a.raw, b.raw)) rescue FFALSE
        def file_ftype(_, path) = reraise(Errno::ENOENT) { n2f_str(File.ftype(path.raw)) }
        def file_size_exact(_, path) = reraise(Errno::ENOENT) { n2f_int(File.size(path.raw)) }
        def file_atime(_, path) = reraise(Errno::ENOENT) { n2f_time(File.atime(path.raw)) }
        def file_mtime(_, path) = reraise(Errno::ENOENT) { n2f_time(File.mtime(path.raw)) }
        def file_ctime(_, path) = reraise(Errno::ENOENT) { n2f_time(File.ctime(path.raw)) }
        def file_read(_, path) = n2f_str(File.read(path.raw))
        def file_symlink(_, path) = n2f_bool(File.symlink?(path.raw))
        def file_readlink(_, path) = reraise(Errno::ENOENT) { n2f_str(File.readlink(path.raw)) }
        def file_zero(_, path) = n2f_bool(File.zero?(path.raw))
        def file_fnmatch(_, pattern, path, flags) = n2f_bool(File.fnmatch(pattern.raw, path.raw, flags.raw))
        # Returns nil - stat info accessed via individual methods (path-based)
        def file_stat_native(_, path) = reraise(Errno::ENOENT) { FNIL }
        def file_lstat_native(_, path) = reraise(Errno::ENOENT) { FNIL }
        def file_stat_mode(_, path) = stat_int_field(path) { |s| s.mode }
        def file_stat_ino(_, path) = stat_int_field(path) { |s| s.ino }
        def file_stat_nlink(_, path) = stat_int_field(path) { |s| s.nlink }
        def file_stat_uid(_, path) = stat_int_field(path) { |s| s.uid }
        def file_stat_gid(_, path) = stat_int_field(path) { |s| s.gid }
        def file_stat_dev(_, path) = stat_int_field(path) { |s| s.dev }
        def file_stat_rdev(_, path) = stat_int_field(path) { |s| s.rdev }
        def file_stat_dev_major(_, path) = stat_int_field(path) { |s| s.dev_major }
        def file_stat_dev_minor(_, path) = stat_int_field(path) { |s| s.dev_minor }
        def file_stat_rdev_major(_, path) = stat_int_field(path) { |s| s.rdev_major }
        def file_stat_rdev_minor(_, path) = stat_int_field(path) { |s| s.rdev_minor }
        def file_stat_blocks(_, path) = stat_int_field(path) { |s| s.blocks || 0 }
        def file_stat_blksize(_, path) = stat_int_field(path, default: 4096) { |s| s.blksize || 4096 }
        def file_lstat_mode(_, path) = lstat_int_field(path) { |s| s.mode }
        def file_lstat_atime(_, path) = lstat_time_field(path) { |s| s.atime }
        def file_lstat_mtime(_, path) = lstat_time_field(path) { |s| s.mtime }
        # Native stat object accessors — only used when @native_stat is set on File::Stat.
        # The native_stat_obj is an ObjectObject with MRI-level @raw ivar holding the MRI File::Stat.
        def file_native_stat_int(_, native_stat_obj, field_sym)
          stat = native_stat_obj.instance_variable_get(:@raw)
          return n2f_int(0) unless stat
          field = fstr?(field_sym) ? field_sym.raw.to_sym : (fsym?(field_sym) ? field_sym.raw : field_sym)
          n2f_int(stat.send(field))
        end

        def file_native_stat_size(_, native_stat_obj)
          stat = native_stat_obj.instance_variable_get(:@raw)
          n2f_int(stat ? stat.size : 0)
        end

        def file_native_stat_time(_, native_stat_obj, field_sym)
          stat = native_stat_obj.instance_variable_get(:@raw)
          return n2f_time(Time.now) unless stat
          field = fstr?(field_sym) ? field_sym.raw.to_sym : (fsym?(field_sym) ? field_sym.raw : field_sym)
          n2f_time(stat.send(field))
        end
        def dir_pwd(_) = n2f_str(Dir.pwd)
        def dir_empty(_, path) = n2f_bool(Dir.empty?(path.raw))
        def dir_exist(_, path) = n2f_bool(path.raw && Dir.exist?(path.raw))
        def process_pid(_) = n2f_int(Process.pid)
        def process_uid(_) = n2f_int(Process.uid)
        def process_gid(_) = n2f_int(Process.gid)
        def process_euid(_) = n2f_int(Process.euid)
        def process_egid(_) = n2f_int(Process.egid)
        def file_join(_, parts) = n2f_str(File.join(*parts.raw.flat_map { |p| farray?(p) ? p.raw.map(&:raw) : p.raw }))
        def file_split(_, path) = n2f_arr(File.split(path.raw).map { |p| n2f_str(p) })
        def file_dirname(_, path, level = FNIL) = n2f_str(File.dirname(path.raw, fnil?(level) ? 1 : level.raw))
        def file_realpath(_, path, base = FNIL) = reraise(Errno::ENOENT) { n2f_str(File.realpath(path.raw, f2n_raw(base))) }
        def file_realdirpath(_, path, base = FNIL) = reraise(Errno::ENOENT) { n2f_str(File.realdirpath(path.raw, f2n_raw(base))) }
        def file_birthtime(_, path) = reraise(Errno::ENOENT, NotImplementedError) { n2f_time(File.birthtime(path.raw)) }

        def file_lutime(_, atime, mtime, paths)
          a = atime.is_a?(TimeObject) ? atime.raw : (fnil?(atime) ? Time.now : Time.at(atime.raw.to_f))
          m = mtime.is_a?(TimeObject) ? mtime.raw : (fnil?(mtime) ? Time.now : Time.at(mtime.raw.to_f))
          paths.raw.each { |p| File.lutime(a, m, p.raw) rescue nil }
          n2f_int(paths.raw.length)
        end

        def file_expand_path(_, path, base = FNIL) = reraise(ArgumentError) do
          n2f_str(File.expand_path(path.raw, f2n_raw(base)))
        end

        def file_umask(_, new_mask)
          if fnil?(new_mask)
            n2f_int(File.umask)
          else
            old = File.umask(fint?(new_mask) ? new_mask.raw : new_mask.raw.to_i)
            n2f_int(old)
          end
        end

        def file_size(_, path)
          s = File.size?(path.raw)
          s ? n2f_int(s) : FNIL
        end

        def file_write(_, path, content)
          File.write(path.raw, content.raw)
          n2f_int(content.raw.length)
        end

        def file_open(context, path, mode, block, perm = nil, flags = nil)
          mode_raw = fnil?(mode) ? nil : mode.raw
          perm_int = (perm && !fnil?(perm) && fint?(perm)) ? perm.raw : 0o666
          flags_int = (flags && !fnil?(flags) && fint?(flags)) ? flags.raw : nil
          # Combine mode with flags: if mode is an integer, bitwise-OR with flags;
          # if string mode, pass flags as separate option to File.open.
          if mode_raw.is_a?(Integer) && flags_int
            mode_combined = mode_raw | flags_int
            open_args = [path.raw, mode_combined, perm_int]
          elsif flags_int
            # String mode + flags: use File.open with flags: keyword
            mode_str = mode_raw || 'r'
            open_args = [path.raw, mode_str, perm_int, { flags: flags_int }]
          else
            mode_str = mode_raw || 'r'
            open_args = [path.raw, mode_str, perm_int]
          end
          file_klass = Core.file_class || Core.io_class
          if block && !fnil?(block)
            f = File.open(*open_args)
            io_obj = IOObject.new(f, file_klass)
            close_error = nil
            result = begin
              block.invoke(context, [io_obj])
            ensure
              # Call Frozone's close so singleton-method overrides are respected.
              # Capture close errors to re-raise after ensure (matching MRI behavior:
              # non-IOError/non-"closed stream" close errors propagate).
              begin
                io_obj.dispatch(context, :close, [], {}, nil)
              rescue FrozoneException => e
                # IOError with "closed stream" is suppressed; other errors propagate
                msg = e.message.to_s rescue ''
                close_error = e unless msg.include?('closed stream')
              rescue => e
                close_error = e
              end
            end
            raise close_error if close_error
            result
          else
            IOObject.new(File.open(*open_args), file_klass)
          end
        end

        def file_delete_strict(context, paths)
          raw_paths = paths.raw
          return n2f_int(0) if raw_paths.empty?
          raw_paths.each do |p|
            path_str = coerce_to_path(context, p)
            reraise(Errno::ENOENT) { File.delete(path_str) }
          end
          n2f_int(raw_paths.length)
        end

        def file_rename(_, from, to) = reraise(Errno::ENOENT) do
          File.rename(from.raw, to.raw)
          n2f_int(0)
        end

        def file_symlink_create(_, target, link) = reraise(Errno::EEXIST) do
          File.symlink(target.raw, link.raw)
          n2f_int(0)
        end

        def file_link(_, target, link) = reraise(Errno::ENOENT) do
          File.link(target.raw, link.raw)
          n2f_int(0)
        end

        def file_chmod(_, mode_int, paths)
          reraise(Errno::ENOENT, RangeError) do
            count = 0
            paths.raw.each do |p|
              File.chmod(mode_int.raw, p.raw)
              count += 1
            end
            n2f_int(count)
          end
        end

        def file_truncate(_, path, length)
          len = fint?(length) ? length.raw : length.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          reraise(Errno::ENOENT, Errno::EINVAL) do
            File.truncate(path.raw, len)
            n2f_int(0)
          end
        end

        def file_mkfifo(_, path, mode) = reraise(NotImplementedError) do
          File.mkfifo(path.raw, mode.raw)
          n2f_int(0)
        end

        def file_utime(_, atime, mtime, paths)
          a = fnil?(atime) ? Time.now : (atime.is_a?(TimeObject) ? atime.raw : Time.at(atime.raw.to_f))
          m = fnil?(mtime) ? Time.now : (mtime.is_a?(TimeObject) ? mtime.raw : Time.at(mtime.raw.to_f))
          path_strs = paths.raw.map { |p| fstr?(p) ? p.raw : p.raw.to_s }
          File.utime(a, m, *path_strs)
          n2f_int(path_strs.length)
        end

        def dir_entries(_, path) = n2f_arr(Dir.entries(path.raw).map { |e| n2f_str(e) })

        def dir_home(_, user = FNIL) = reraise(ArgumentError) do
          u = f2n_raw(user)
          n2f_str(u ? Dir.home(u) : Dir.home)
        end

        def dir_glob(context, pattern, flags = FNIL, base = FNIL, sort = FNIL)
          # pattern can be a String, Array, or object with to_path
          flag_int = fnil?(flags) ? 0 : flags.raw.to_i
          base_str = f2n_raw(base)
          sort_val = fnil?(sort) || (ftrue?(sort) || (ffalse?(sort) ? false : sort.raw))
          pats = if farray?(pattern)
                   pattern.raw.map { |p| coerce_to_path(context, p) }
                 elsif fstr?(pattern)
                   pattern.raw
                 else
                   coerce_to_path(context, pattern)
                 end
          results = if base_str
                      Dir.glob(pats, flag_int, base: base_str, sort: sort_val)
                    else
                      Dir.glob(pats, flag_int, sort: sort_val)
                    end
          reraise(ArgumentError) { n2f_arr(results.map { |p| n2f_str(p) }) }
        end

        def dir_chdir(context, path, block)
          path_raw = fnil?(path) ? nil : coerce_to_path(context, path)
          if block && !fnil?(block)
            result = reraise(Errno::ENOENT) do
              path_raw ? Dir.chdir(path_raw) { block.invoke(context, [n2f_str(Dir.pwd)]) } :
                         Dir.chdir { block.invoke(context, [n2f_str(Dir.pwd)]) }
            end
            result.is_a?(ObjectObject) ? result : FNIL
          else
            reraise(Errno::ENOENT) { path_raw ? Dir.chdir(path_raw) : Dir.chdir }
            n2f_int(0)
          end
        end

        def dir_mkdir(_, path, mode = FNIL)
          m = fnil?(mode) ? 0o777 : mode.raw
          reraise(Errno::ENOENT, Errno::EEXIST, Errno::EACCES) do
            Dir.mkdir(path.raw, m)
            n2f_int(0)
          end
        end

        def dir_rmdir(_, path) = reraise(Errno::ENOENT, Errno::EACCES, Errno::ENOTEMPTY) do
          Dir.rmdir(path.raw)
          n2f_int(0)
        end

        def dir_open(_, path)
          reraise(Errno::ENOENT, Errno::ENOTDIR) do
            dir = ::Dir.new(path.raw)
            obj = ObjectObject.new(Core::OBJECT_CLASS)
            obj.instance_variable_set(:@__dir__, dir)
            obj
          end
        end

        def dir_close(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.close if d
          FNIL
        rescue IOError
          FNIL
        end

        def dir_read(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          entry = d.read
          entry ? n2f_str(entry) : FNIL
        end

        def dir_seek(_, dir_obj, pos)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.seek(pos.raw)
          FNIL
        end

        def dir_rewind(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          d.rewind
          FNIL
        end

        def dir_fileno(_, dir_obj)
          d = dir_obj.instance_variable_get(:@__dir__)
          n2f_int(d.fileno)
        rescue NotImplementedError
          n2f_int(0)
        end

        def dir_chroot(_, path) = reraise(Errno::EPERM, Errno::ENOENT, SystemCallError) do
          Dir.chroot(path.raw)
          n2f_int(0)
        end

        def dir_mktmpdir(context, prefix, block)
          require 'tmpdir'
          pfx = f2n_raw(prefix)
          path = pfx ? Dir.mktmpdir(pfx) : Dir.mktmpdir
          if block && !fnil?(block)
            begin
              block.invoke(context, [n2f_str(path)])
            ensure
              FileUtils.remove_entry(path) rescue nil
            end
          else
            n2f_str(path)
          end
        end

        def process_kill(_, sig_obj, pid_obj)
          sig = fint?(sig_obj) ? sig_obj.raw : sig_obj.raw.to_i
          pid = fint?(pid_obj) ? pid_obj.raw : pid_obj.raw.to_i
          Process.kill(sig, pid)
          FNIL
        end

        def process_clock_gettime(_, clock_id_obj, unit_obj)
          clock_id = fint?(clock_id_obj) ? clock_id_obj.raw : 1  # default CLOCK_MONOTONIC
          unit_sym = fsym?(unit_obj) ? unit_obj.raw : :float_second
          result = Process.clock_gettime(clock_id, unit_sym)
          result.is_a?(Integer) ? n2f_int(result) : n2f_float(result)
        end

        # Time

        # Wrap MRI utc_offset (Integer or Rational) as a Frozone object.
        def wrap_utc_offset(offset) = offset.is_a?(Integer) ? n2f_int(offset) : make_rational(offset)

        def time_now(context) = time_make(context, Time.now)
        def time_to_f(_, t) = n2f_float(t.raw.to_f)
        def time_to_i(_, t) = n2f_int(t.raw.to_i)
        def time_to_s(_, t) = n2f_str(t.raw.to_s)
        def time_inspect(_, t) = n2f_str(t.raw.inspect)
        def time_usec(_, t) = n2f_int(t.raw.usec)
        def time_nsec(_, t) = n2f_int(t.raw.nsec)
        def time_sec(_, t) = n2f_int(t.raw.sec)
        def time_min(_, t) = n2f_int(t.raw.min)
        def time_hour(_, t) = n2f_int(t.raw.hour)
        def time_mday(_, t) = n2f_int(t.raw.mday)
        def time_month(_, t) = n2f_int(t.raw.month)
        def time_year(_, t) = n2f_int(t.raw.year)
        def time_wday(_, t) = n2f_int(t.raw.wday)
        def time_yday(_, t) = n2f_int(t.raw.yday)
        def time_utc?(_, t) = n2f_bool(t.raw.utc?)
        def time_dup(_, t) = time_preserve_class(t, t.raw.dup)
        def time_utc_offset(_, t) = wrap_utc_offset(t.raw.utc_offset)
        def time_asctime(_, t) = n2f_str(t.raw.asctime)
        def time_ceil(_, t, n) = n2f_time(t.raw.ceil(fint?(n) ? n.raw : 0))
        def time_floor(_, t, n) = n2f_time(t.raw.floor(fint?(n) ? n.raw : 0))
        def time_round(_, t, n) = n2f_time(t.raw.round(fint?(n) ? n.raw : 0))
        def time_load(_, str)
          raw = str.raw
          # MRI's Time._load reads @submicro via C-level internal ivars that can't
          # be reproduced with Ruby-level instance_variable_set. Instead, load the
          # base time (microsecond precision), then add sub-microsecond ns from @nano_num.
          t = Time.send(:_load, raw)
          nano_num = str.get_ivar(:@nano_num)
          if fint?(nano_num)
            ns = nano_num.raw  # sub-microsecond nanoseconds, 0..999
            if ns > 0
              nano_den = str.get_ivar(:@nano_den)
              den = fint?(nano_den) ? nano_den.raw : 1
              t = t + Rational(ns, den * 1_000_000_000)
            end
          end
          n2f_time(t)
        end
        def time_strftime(_, t, format) = n2f_str(t.raw.strftime(format.raw))
        def time_dst?(_, t) = n2f_bool(t.raw.dst?)
        def time_hash(_, t) = n2f_int(t.raw.hash)
        def time_iso8601(_, t, n) = n2f_str(t.raw.iso8601(fint?(n) ? n.raw : 0))
        def time_dump(_, t) = n2f_str(t.raw.send(:_dump, -1))

        # Extract an MRI Numeric from a Frozone value (Integer, Float, or Rational ObjectObject).
        # get_ivar returns FNIL (not MRI nil) when ivar is absent.
        def frozone_to_mri_numeric(obj)
          return obj.raw if fint?(obj) || ffloat?(obj)
          return 0 if fnil?(obj)
          num = obj.get_ivar(:@numerator)
          den = obj.get_ivar(:@denominator)
          # FNIL means the ivar is not set — not a Rational ObjectObject
          return fobj?(obj) ? obj.raw : 0 if fnil?(num) || fnil?(den)
          n = fint?(num) ? num.raw : (fobj?(num) ? num.raw.to_i : 0)
          d = fint?(den) ? den.raw : (fobj?(den) ? den.raw.to_i : 1)
          d == 1 ? n : Rational(n, d)
        end

        # Create a TimeObject, inheriting the subclass from context.the_self when called
        # from a class method (Time.at on a subclass, Time.new on a subclass, etc.).
        def time_make(context, mri_time)
          t = n2f_time(mri_time)
          the_self = context.frame&.the_self
          if the_self.is_a?(ClassObject) && !the_self.equal?(t.class_object)
            t.class_object = the_self
          end
          t
        end

        # Create a TimeObject preserving the class of an existing TimeObject (for instance methods).
        def time_preserve_class(src, mri_time)
          t = n2f_time(mri_time)
          t.class_object = src.class_object unless src.class_object.equal?(t.class_object)
          t
        end

        # time_at_raw: called from pure-Ruby Time.at after argument coercion.
        # t_r: Frozone Numeric (Integer/Float/Rational) or TimeObject; tz: Frozone String/Integer or nil.
        def time_at_raw(context, t_r, tz)
          # Pass TimeObject.raw directly so MRI Time.at(time) preserves the UTC flag.
          mri_r = t_r.is_a?(TimeObject) ? t_r.raw : frozone_to_mri_numeric(t_r)
          t = Time.at(mri_r)
          unless fnil?(tz)
            tz_raw = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz).to_i
            t = t.localtime(tz_raw)
          end
          time_make(context, t)
        end

        # Legacy: still used when time_at is called without keyword args.
        def time_at(context, t, subsec = FNIL)
          raw_t = t.is_a?(TimeObject) ? t.raw : Time.at(frozone_to_mri_numeric(t))
          if fnil?(subsec)
            time_make(context, Time.at(raw_t))
          else
            time_make(context, Time.at(raw_t, subsec.raw.to_f))
          end
        end

        def time_mktime(context, year, month, day, hour, min, sec, usec, use_utc, isdst = FNIL)
          y  = frozone_to_mri_numeric(year).to_i
          mo = frozone_to_mri_numeric(month).to_i
          d  = frozone_to_mri_numeric(day).to_i
          h  = frozone_to_mri_numeric(hour).to_i
          mi = frozone_to_mri_numeric(min).to_i
          s  = frozone_to_mri_numeric(sec)   # Rational preserved
          us = frozone_to_mri_numeric(usec)  # Rational preserved
          # 10-arg C-style form with isdst hint for DST disambiguation (local only).
          if !(ftrue?(use_utc) || use_utc == true) &&
             (ftrue?(isdst) || ffalse?(isdst) || isdst == true || isdst == false)
            isdst_val = ftrue?(isdst) || isdst == true
            return time_make(context, Time.local(s, mi, h, d, mo, y, 0, 0, isdst_val, nil))
          end
          # Passing usec=0 explicitly clobbers fractional seconds in sec (Rational).
          # Only pass usec if it's non-zero.
          args = us.zero? ? [y, mo, d, h, mi, s] : [y, mo, d, h, mi, s, us]
          if ftrue?(use_utc) || use_utc == true
            time_make(context, Time.utc(*args))
          else
            time_make(context, Time.local(*args))
          end
        end

        def time_new(context, year, month, day, hour, min, sec, tz)
          if fnil?(year)
            if fnil?(tz)
              return time_make(context, Time.now)
            else
              tz_mri = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz)
              tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
              return time_make(context, Time.now.localtime(tz_val))
            end
          end
          mri_args = [year, month, day, hour, min, sec].map { |a|
            fnil?(a) ? nil : frozone_to_mri_numeric(a)
          }
          if fnil?(tz)
            # Drop trailing nils to use MRI defaults
            trimmed = mri_args.reverse.drop_while(&:nil?).reverse
            time_make(context, Time.new(*trimmed))
          else
            tz_mri = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz)
            # Strings, Rationals, Floats pass through as-is; other numerics → int
            tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
            time_make(context, Time.new(*mri_args, tz_val))
          end
        end

        # time_new_from_string: Time.new("2021-12-25 00:00:00 +09:00", precision:, in:)
        # precision: IntegerObject (9 = ns default) or NilObject (unlimited)
        # in_tz: Frozone String/Integer/Rational or NilObject
        def time_new_from_string(context, str, precision, in_tz)
          mri_str = fstr?(str) ? str.raw : str.to_s
          mri_prec = if fnil?(precision)
                       nil
                     elsif fint?(precision)
                       precision.raw
                     else
                       frozone_to_mri_numeric(precision).to_i
                     end
          opts = {}
          opts[:precision] = mri_prec unless mri_prec == 9
          unless fnil?(in_tz)
            opts[:in] = fstr?(in_tz) ? in_tz.raw : frozone_to_mri_numeric(in_tz)
          end
          reraise(ArgumentError, TypeError) do
            t = opts.empty? ? Time.new(mri_str) : Time.new(mri_str, **opts)
            time_make(context, t)
          end
        end

        def time_minus(_, t, other)
          if other.is_a?(TimeObject)
            n2f_float(t.raw - other.raw)
          else
            n2f_time(t.raw - frozone_to_mri_numeric(other))
          end
        end

        def time_plus(_, t, secs) = reraise(TypeError) do
          raise FrozoneException.make(:TypeError, "can't convert NilClass into an exact number") if fnil?(secs)
          n2f_time(t.raw + frozone_to_mri_numeric(secs))
        end

        def time_to_r(_, t)
          r = begin; t.raw.to_r; rescue; Rational(t.raw.to_i, 1); end
          make_rational(r)
        end

        def time_zone(_, t)
          z = t.raw.zone
          z.nil? || z.empty? ? FNIL : n2f_str(z)
        end

        def time_localtime(_, t, tz = FNIL)
          reraise(TypeError, ArgumentError) do
            if t.frozen_object?
              # localtime() with no arg on an already-local frozen time is a no-op (no error)
              return t if fnil?(tz) && !t.raw.utc?
              raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
            end

            if fnil?(tz)
              t.raw.localtime
            elsif fstr?(tz)
              t.raw.localtime(tz.raw)
            elsif fint?(tz)
              t.raw.localtime(tz.raw)
            elsif ffloat?(tz)
              t.raw.localtime(tz.raw.to_i)
            else
              mri_tz = frozone_to_mri_numeric(tz)
              # Preserve Rational offsets; fall back to integer for other numerics
              tz_val = mri_tz.is_a?(Rational) ? mri_tz : mri_tz.to_i
              t.raw.localtime(tz_val)
            end
            t
          end
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
          r.is_a?(Integer) ? n2f_int(r) : make_rational(r)
        end

        # Regexp
        def regexp_newly_created_q(_, r) = r.is_a?(RegexpObject) ? n2f_bool(r.newly_created_for_subclass) : FFALSE
        def regexp_source(_, r) = n2f_str(r.raw.source)
        def regexp_inspect(_, r) = n2f_str(r.raw.inspect)
        def regexp_to_s(_, r) = n2f_str(r.raw.to_s)
        def regexp_casefold(_, r) = n2f_bool(r.raw.casefold?)
        def regexp_fixed_encoding(_, r) = n2f_bool(r.raw.fixed_encoding?)
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
            md = MatchDataObject.new(m, regexp_obj.is_a?(NilObject) ? nil : regexp_obj)
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
          raw_pats = raw_pats[0].raw if raw_pats.length == 1 && raw_pats[0].is_a?(ArrayObject)
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

        def io_popen_capture(_, cmd, opts_obj = FNIL)
          mri_opts = {}
          if fhash?(opts_obj) && !opts_obj.raw.empty?
            opts_obj.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.raw.to_sym
              val = case v
                    when ArrayObject then v.raw.map { |e| fsym?(e) ? e.raw : e.raw }
                    when SymbolObject then v.raw
                    when IntegerObject then v.raw
                    else v.raw
                    end
              mri_opts[key] = val
            end
          end
          output = if farray?(cmd)
                     ::IO.popen(cmd.raw.map { |a| fstr?(a) ? a.raw : a.to_s }, 'r', **mri_opts, &:read) rescue ""
                   elsif fstr?(cmd)
                     ::IO.popen(cmd.raw, 'r', **mri_opts, &:read) rescue ""
                   else
                     ::IO.popen(cmd.to_s, 'r', **mri_opts, &:read) rescue ""
                   end
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
          n2f_str(output || "")
        end

        def io_external_encoding(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.external_encoding rescue nil
          return FNIL if enc.nil?
          n2f_str(enc.name)
        end

        def io_explicit_encoding?(_, receiver)
          return FFALSE unless receiver.is_a?(IOObject)
          n2f_bool(receiver.explicit_encoding?)
        end

        def io_mark_explicit_encoding(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          receiver.instance_variable_set(:@explicit_encoding, true)
          FNIL
        end

        def encoding_set_default_external(_, name_obj)
          name = fstr?(name_obj) ? name_obj.raw : (fnil?(name_obj) ? nil : name_obj.to_s)
          enc = name ? ::Encoding.find(name) : ::Encoding::UTF_8 rescue nil
          ::Encoding.default_external = enc if enc
          FNIL
        end

        def encoding_set_default_internal(_, name_obj)
          name = fstr?(name_obj) ? name_obj.raw : (fnil?(name_obj) ? nil : name_obj.to_s)
          enc = name ? ::Encoding.find(name) : nil rescue nil
          ::Encoding.default_internal = enc
          FNIL
        end

        def io_sysopen(_, path_obj, mode_obj = FNIL, perm_obj = FNIL)
          path = fstr?(path_obj) ? path_obj.raw : path_obj.to_s
          mode = if fnil?(mode_obj) then 'r'
                 elsif fstr?(mode_obj) then mode_obj.raw
                 elsif fint?(mode_obj) then mode_obj.raw
                 else
                   'r'
                 end
          perm = fint?(perm_obj) ? perm_obj.raw : 0o666
          reraise(::Errno::ENOENT, ::Errno::EACCES, ::TypeError, ::ArgumentError, ::SystemCallError) do
            n2f_int(::IO.sysopen(path, mode, perm))
          end
        end

        def io_new_from_fd(_, fd_obj, mode_obj = FNIL, opts_obj = FNIL)
          fd = fint?(fd_obj) ? fd_obj.raw : fd_obj.raw.to_i
          mode, opts = parse_io_mode(mode_obj, opts_obj)
          explicit_enc = (mode.is_a?(::String) && mode.include?(':')) ||
                         opts.key?(:encoding) || opts.key?(:external_encoding)
          native_io = if mode && opts.empty? then ::IO.new(fd, mode)
                      elsif mode             then ::IO.new(fd, mode, **opts)
                      elsif opts.empty?      then ::IO.new(fd)
                      else
                        ::IO.new(fd, **opts)
                      end
          reraise(::ArgumentError, ::TypeError, ::SystemCallError) do
            IOObject.new(native_io, Core.io_class, explicit_encoding: explicit_enc)
          end
        end

        def io_read(_, receiver, len_obj = FNIL, buf_obj = FNIL)
          return FNIL unless receiver.is_a?(IOObject)
          len = f2n_raw(len_obj)
          reraise(::IOError) do
            result = len ? receiver.native_io.read(len) : receiver.native_io.read
            result.nil? ? FNIL : n2f_str(result)
          end
        end

        def io_gets(_, receiver, sep_obj = FNIL, limit_obj = FNIL)
          return FNIL unless receiver.is_a?(IOObject)
          sep = fnil?(sep_obj) ? $/ : f2n_raw(sep_obj)
          reraise(::IOError) do
            line = receiver.native_io.gets(sep)
            line.nil? ? FNIL : n2f_str(line)
          end
        end

        def io_readline(_, receiver, sep_obj = FNIL)
          return FNIL unless receiver.is_a?(IOObject)
          sep = fnil?(sep_obj) ? $/ : f2n_raw(sep_obj)
          reraise(::EOFError, ::IOError) { n2f_str(receiver.native_io.readline(sep)) }
        end

        def io_readlines(_, receiver, sep_obj = FNIL)
          return n2f_arr([]) unless receiver.is_a?(IOObject)
          sep = fnil?(sep_obj) ? $/ : f2n_raw(sep_obj)
          reraise(::IOError) { n2f_arr(receiver.native_io.readlines(sep).map { |l| n2f_str(l) }) }
        end

        def io_close(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          receiver.native_io.close rescue nil
          FNIL
        end

        def io_closed?(_, receiver)
          return FTRUE unless receiver.is_a?(IOObject)
          n2f_bool(receiver.native_io.closed?)
        end

        def io_fileno(_, receiver)
          return n2f_int(1) unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_int(receiver.native_io.fileno) }
        end

        def io_eof?(_, receiver)
          return FTRUE unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_bool(receiver.native_io.eof?) }
        end

        def io_seek(_, receiver, offset_obj, whence_obj = FNIL)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          offset = fint?(offset_obj) ? offset_obj.raw : 0
          whence = fnil?(whence_obj) ? ::IO::SEEK_SET : whence_obj.raw
          reraise(::IOError) { n2f_int(receiver.native_io.seek(offset, whence)) }
        end

        def io_pos(_, receiver)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          n2f_int(receiver.native_io.pos)
        end

        def io_pos_set(_, receiver, pos_obj)
          return pos_obj unless receiver.is_a?(IOObject)
          receiver.native_io.pos = fint?(pos_obj) ? pos_obj.raw : 0
          pos_obj
        end

        def io_rewind(_, receiver)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          receiver.native_io.rewind
          n2f_int(0)
        end

        def io_binmode(_, receiver)
          return receiver unless receiver.is_a?(IOObject)
          receiver.native_io.binmode
          receiver
        end

        def io_binmode?(_, receiver)
          return FFALSE unless receiver.is_a?(IOObject)
          n2f_bool(receiver.native_io.binmode?)
        end

        def io_set_encoding(_, receiver, ext_obj, int_obj = FNIL)
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
          return FNIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.internal_encoding rescue nil
          enc ? n2f_str(enc.name) : FNIL
        end

        def io_isatty(_, receiver)
          return FFALSE unless receiver.is_a?(IOObject)
          n2f_bool(receiver.native_io.isatty)
        end

        def io_getbyte(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          b = receiver.native_io.getbyte
          b.nil? ? FNIL : n2f_int(b)
        end

        def io_getc(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          c = receiver.native_io.getc
          c.nil? ? FNIL : n2f_str(c)
        end

        def io_readbyte(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::EOFError) { n2f_int(receiver.native_io.readbyte) }
        end

        def io_readchar(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::EOFError) { n2f_str(receiver.native_io.readchar) }
        end

        def io_ungetbyte(_, receiver, byte_obj)
          return FNIL unless receiver.is_a?(IOObject)
          byte = f2n_raw(byte_obj)
          receiver.native_io.ungetbyte(byte) if byte
          FNIL
        end

        def io_ungetc(_, receiver, str_obj)
          return FNIL unless receiver.is_a?(IOObject)
          receiver.native_io.ungetc(fstr?(str_obj) ? str_obj.raw : str_obj.to_s)
          FNIL
        end

        def io_sysread(_, receiver, len_obj, buf_obj = FNIL)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::EOFError, ::IOError) { n2f_str(receiver.native_io.sysread(fint?(len_obj) ? len_obj.raw : 0)) }
        end

        def io_syswrite(_, receiver, str_obj)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_int(receiver.native_io.syswrite(fstr?(str_obj) ? str_obj.raw : str_obj.to_s)) }
        end

        def io_each_line(context, receiver, sep_obj = FNIL, block = FNIL)
          return receiver unless receiver.is_a?(IOObject) && block && !fnil?(block)
          sep = fnil?(sep_obj) ? $/ : (fstr?(sep_obj) ? sep_obj.raw : $/)
          reraise(::IOError) do
            receiver.native_io.each_line(sep) { |line| block.invoke(context, [n2f_str(line)]) }
            receiver
          end
        end

        def io_each_byte(context, receiver, block = FNIL)
          return receiver unless receiver.is_a?(IOObject) && block && !fnil?(block)
          receiver.native_io.each_byte { |b| block.invoke(context, [n2f_int(b)]) }
          receiver
        end

        def io_each_char(context, receiver, block = FNIL)
          return receiver unless receiver.is_a?(IOObject) && block && !fnil?(block)
          receiver.native_io.each_char { |c| block.invoke(context, [n2f_str(c)]) }
          receiver
        end

        def io_stat(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::IOError) do
            stat = receiver.native_io.stat
            stat_obj = ObjectObject.new(Core::OBJECT_CLASS.get_constant(:File)&.get_constant(:Stat) || Core::OBJECT_CLASS)
            stat_obj.set_ivar(:@native_stat, ObjectObject.new(Core::OBJECT_CLASS).tap { |o| o.instance_variable_set(:@raw, stat) })
            stat_obj
          end
        end

        def io_inspect(_, receiver)
          return n2f_str("#<IO>") unless receiver.is_a?(IOObject)
          n2f_str(receiver.native_io.inspect)
        rescue
          n2f_str("#<IO>")
        end

        def io_chmod(_, receiver, mode_obj)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          mode = fint?(mode_obj) ? mode_obj.raw : mode_obj.raw.to_i
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if mode > 2**32 || mode < -(2**31)
          reraise(::RangeError, ::Errno::EBADF) do
            receiver.native_io.chmod(mode)
            n2f_int(0)
          end
        end

        def io_truncate(_, receiver, len_obj)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          len = fint?(len_obj) ? len_obj.raw : len_obj.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          reraise(::IOError, ::Errno::EINVAL) do
            receiver.native_io.truncate(len)
            n2f_int(0)
          end
        end

        def io_writable?(_, receiver)
          return FFALSE unless receiver.is_a?(IOObject)
          n2f_bool((receiver.native_io.stat.mode rescue 0) & 0o200 != 0)
        rescue
          FFALSE
        end

        def io_atime(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.atime) }
        end

        def io_mtime(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.mtime) }
        end

        def io_ctime(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.ctime) }
        end

        def io_birthtime(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          reraise(::IOError, ::NotImplementedError) { n2f_time(receiver.native_io.stat.birthtime) }
        end

        def io_path(_, receiver)
          return FNIL unless receiver.is_a?(IOObject)
          path = receiver.native_io.path rescue nil
          path ? n2f_str(path) : FNIL
        rescue
          FNIL
        end

        def io_flock(_, receiver, lock_op_obj)
          return n2f_int(0) unless receiver.is_a?(IOObject)
          reraise(::IOError) { n2f_int(receiver.native_io.flock(fint?(lock_op_obj) ? lock_op_obj.raw : 0)) }
        end

        # print/puts/write/flush/sync_set delegate to a native IO, defaulting to $stdout
        def io_print(context, receiver, args)
          native = native_io_for(receiver)
          args.raw.each { |a| native.print(a.dispatch(context, :to_s, [], {}).raw) }
          FNIL
        end

        def io_puts(context, receiver, args)
          native = native_io_for(receiver)
          if args.raw.empty?
            native.puts
          else
            args.raw.each { |a| native.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          FNIL
        end

        def io_write(context, receiver, args)
          native = native_io_for(receiver)
          s = args.raw.first.dispatch(context, :to_s, [], {}).raw
          native.write(s)
          n2f_int(s.bytesize)
        end

        def io_flush(_, receiver)
          native_io_for(receiver).flush rescue nil
          receiver
        end

        def io_sync_set(_, receiver, val)
          native_io_for(receiver).sync = val.truthy? rescue nil
          val
        end

        def io_autoclose_set(_, receiver, val)
          native_io_for(receiver).autoclose = val.truthy? rescue nil
          val
        end

        def io_autoclose?(_, receiver)
          val = begin; native_io_for(receiver).autoclose?; rescue StandardError; true; end
          n2f_bool(val)
        end

        def io_reopen(context, receiver, target, mode = FNIL)
          native = native_io_for(receiver)
          if target.is_a?(IOObject)
            native.reopen(target.native_io) rescue nil
          else
            path = fstr?(target) ? target.raw : coerce_to_path(context, target)
            m = fnil?(mode) ? 'r' : mode.raw
            native.reopen(path, m) rescue nil
          end
          receiver
        end

        def file_new_from_fd(context, path_or_fd, mode_obj, opts_obj = FNIL)
          mode = fnil?(mode_obj) ? 'r' : mode_obj.raw
          opts = {}
          if fhash?(opts_obj)
            opts_obj.raw.each { |k, v| opts[k.raw] = v.raw rescue v }
          end
          reraise(Errno::ENOENT, Errno::EACCES) do
            if fint?(path_or_fd)
              native = ::IO.new(path_or_fd.raw, mode)
            else
              p = fstr?(path_or_fd) ? path_or_fd.raw : coerce_to_path(context, path_or_fd)
              native = ::File.open(p, mode)
            end
            io_klass = Core.io_class || Core::OBJECT_CLASS
            IOObject.new(native, io_klass)
          end
        end

        def dir_fchdir(context, fd_obj, block_obj = FNIL)
          fd = fint?(fd_obj) ? fd_obj.raw : (native_io_for(fd_obj).fileno rescue nil)
          if fnil?(block_obj) || block_obj.nil?
            Dir.fchdir(fd) if fd
          else
            Dir.fchdir(fd) do
              block_obj.invoke(context, [])
            end
          end
          n2f_int(0)
        end

        private

        def native_io_for(receiver) = receiver.is_a?(IOObject) ? receiver.native_io : $stdout

        def stat_int_field(path, default: 0)
          n2f_int(yield File.stat(path.raw))
        rescue Errno::ENOENT, Errno::EACCES
          n2f_int(default)
        end

        def lstat_int_field(path, default: 0)
          n2f_int(yield File.lstat(path.raw))
        rescue Errno::ENOENT, Errno::EACCES
          n2f_int(default)
        end

        def lstat_time_field(path)
          n2f_time(yield File.lstat(path.raw))
        rescue Errno::ENOENT, Errno::EACCES
          n2f_time(Time.now)
        end

        def coerce_to_path(context, obj)
          return obj.raw if fstr?(obj)
          begin
            r = obj.dispatch(context, :to_path, [], {})
            return fstr?(r) ? r.raw : r.raw.to_s
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
          end
          begin
            r = obj.dispatch(context, :to_str, [], {})
            fstr?(r) ? r.raw : r.raw.to_s
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
            f2n_raw(n)
          else nil
          end
        end

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

        # Parse IO.new mode and opts arguments.
        # Returns [mode, opts_hash] where mode is nil/String/Integer and opts_hash is a Ruby Hash.
        def parse_io_mode(mode_obj, opts_obj)
          mode = if fnil?(mode_obj) then nil
                 elsif fstr?(mode_obj) then mode_obj.raw
                 elsif fint?(mode_obj) then mode_obj.raw
                 elsif fhash?(mode_obj) then (opts_obj = mode_obj; nil)
                 else
                   nil
                 end
          opts = {}
          if fhash?(opts_obj)
            opts_obj.raw.each do |k, v|
              opts[fsym?(k) ? k.raw : k.to_s.to_sym] = case v
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

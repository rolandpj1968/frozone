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

        def file_binread(_, path, len_obj, offset_obj)
          path_s = path.raw
          len = fnil?(len_obj) ? nil : len_obj.raw
          offset = fnil?(offset_obj) ? nil : offset_obj.raw
          reraise(::Errno::ENOENT, ::Errno::EACCES, ::ArgumentError) do
            n2f_str(File.binread(path_s, *[len, offset].compact))
          end
        end
        def file_symlink(_, path) = n2f_bool(File.symlink?(path.raw))
        def file_readlink(_, path) = reraise(Errno::ENOENT) { n2f_str(File.readlink(path.raw)) }
        def file_zero(_, path) = n2f_bool(File.zero?(path.raw))
        def file_fnmatch(_, pattern, path, flags) = n2f_bool(File.fnmatch(pattern.raw, path.raw, flags.raw))
        # Validate path exists; stat info is accessed lazily via individual methods (path-based)
        def file_stat_native(_, path)
          reraise(Errno::ENOENT, Errno::ENOTDIR) { File.stat(path.raw) }
          FNIL
        end

        def file_lstat_native(_, path)
          reraise(Errno::ENOENT, Errno::ENOTDIR) { File.lstat(path.raw) }
          FNIL
        end
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
        def process_groups(_) = n2f_arr(Process.groups.map { |g| n2f_int(g) })
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

        def file_umask(context, new_mask)
          if fnil?(new_mask)
            n2f_int(File.umask)
          else
            int_val = if fint?(new_mask)
              new_mask.raw
            elsif new_mask.respond_to?(:raw) && new_mask.raw.is_a?(Integer)
              new_mask.raw
            else
              result = new_mask.dispatch(context, :to_int, [], {})
              fint?(result) ? result.raw : result.raw.to_i
            end
            n2f_int(File.umask(int_val))
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
            open_kwargs = {}
          elsif flags_int
            # String mode + flags: use File.open with flags: keyword
            mode_str = mode_raw || 'r'
            open_args = [path.raw, mode_str, perm_int]
            open_kwargs = { flags: flags_int }
          else
            mode_str = mode_raw || 'r'
            open_args = [path.raw, mode_str, perm_int]
            open_kwargs = {}
          end
          file_klass = Core.file_class || Core.io_class
          if !fnil?(block)
            f = File.open(*open_args, **open_kwargs)
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
            IOObject.new(File.open(*open_args, **open_kwargs), file_klass)
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
          base_str = fnil?(base) ? nil : (fstr?(base) ? base.raw : coerce_to_path(context, base))
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
          if !fnil?(block)
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

        def dir_for_fd(_, fd_obj)
          fd = fint?(fd_obj) ? fd_obj.raw : fd_obj.raw.to_i
          dir = ::Dir.for_fd(fd)
          obj = ObjectObject.new(Core::OBJECT_CLASS)
          obj.instance_variable_set(:@__dir__, dir)
          obj
        end

        def dir_chroot(_, path) = reraise(Errno::EPERM, Errno::ENOENT, SystemCallError) do
          Dir.chroot(path.raw)
          n2f_int(0)
        end

        def dir_mktmpdir(context, prefix, block)
          require 'tmpdir'
          pfx = f2n_raw(prefix)
          path = pfx ? Dir.mktmpdir(pfx) : Dir.mktmpdir
          if !fnil?(block)
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
          clock_id = if fint?(clock_id_obj) then clock_id_obj.raw
                     elsif fsym?(clock_id_obj) then clock_id_obj.raw
                     else 1  # default CLOCK_MONOTONIC
                     end
          unit_sym = fsym?(unit_obj) ? unit_obj.raw : :float_second
          result = Process.clock_gettime(clock_id, unit_sym)
          result.is_a?(Integer) ? n2f_int(result) : n2f_float(result)
        end

        def process_clock_getres(_, clock_id_obj, unit_obj)
          clock_id = if fint?(clock_id_obj) then clock_id_obj.raw
                     elsif fsym?(clock_id_obj) then clock_id_obj.raw
                     else 1
                     end
          unit_sym = fsym?(unit_obj) ? unit_obj.raw : :float_second
          result = Process.clock_getres(clock_id, unit_sym)
          result.is_a?(Integer) ? n2f_int(result) : n2f_float(result)
        end


        private

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
      end
    end
  end
end

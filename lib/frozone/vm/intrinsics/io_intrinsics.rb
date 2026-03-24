# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def io_popen_capture(_, cmd, opts_obj = FNIL)
          mri_opts = {}
          env_hash = nil
          if fhash?(opts_obj) && !opts_obj.raw.empty?
            opts_obj.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.raw.to_sym
              if key == :env && v.is_a?(HashObject)
                env_hash = v.raw.each_with_object({}) do |(ek, ev), h|
                  h[fstr?(ek) ? ek.raw : ek.raw.to_s] = fnil?(ev) ? nil : (fstr?(ev) ? ev.raw : ev.raw.to_s)
                end
              else
                val = case v
                      when ArrayObject then v.raw.map { |e| fsym?(e) ? e.raw : e.raw }
                      when SymbolObject then v.raw
                      when IntegerObject then v.raw
                      else v.raw
                      end
                mri_opts[key] = val
              end
            end
          end
          # When cmd is a HashObject, it's an env hash (IO.popen(env, cmd, ...))
          actual_cmd, actual_env = if fhash?(cmd)
            env_h = cmd.raw.each_with_object({}) do |(k, v), h|
              h[fstr?(k) ? k.raw : k.raw.to_s] = fnil?(v) ? nil : (fstr?(v) ? v.raw : v.raw.to_s)
            end
            [opts_obj, env_h]  # cmd is actually the second arg (not supported this way, use env: opt)
          else
            [cmd, env_hash]
          end
          output = if farray?(actual_cmd)
                     arr = actual_cmd.raw.map { |a| fstr?(a) ? a.raw : a.to_s }
                     # Prepend env hash inside array if provided (MRI convention)
                     arr = [actual_env, *arr] if actual_env
                     begin
                       ::IO.popen(arr, 'r', **mri_opts, &:read)
                     rescue => e
                       ""
                     end
                   elsif fstr?(actual_cmd)
                     ::IO.popen(actual_cmd.raw, 'r', **mri_opts, &:read) rescue ""
                   else
                     ::IO.popen(actual_cmd.to_s, 'r', **mri_opts, &:read) rescue ""
                   end
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
          n2f_str(output || "")
        end

        def io_popen(_, cmd, mode_obj = FNIL, opts_obj = FNIL)
          mode = fnil?(mode_obj) ? 'r' : (fstr?(mode_obj) ? mode_obj.raw : 'r')
          mri_opts = {}
          env_hash = nil
          if fhash?(opts_obj) && !opts_obj.raw.empty?
            opts_obj.raw.each do |k, v|
              key = fsym?(k) ? k.raw : k.raw.to_sym
              if key == :env && v.is_a?(HashObject)
                env_hash = v.raw.each_with_object({}) do |(ek, ev), h|
                  h[fstr?(ek) ? ek.raw : ek.raw.to_s] = fnil?(ev) ? nil : (fstr?(ev) ? ev.raw : ev.raw.to_s)
                end
              else
                val = case v
                      when ArrayObject then v.raw.map { |e| fsym?(e) ? e.raw : e.raw }
                      when SymbolObject then v.raw
                      when IntegerObject then v.raw
                      else v.raw
                      end
                mri_opts[key] = val
              end
            end
          end
          # Resolve env from HashObject cmd (IO.popen(env, cmd, ...)) or opts :env key
          actual_cmd, actual_env = if fhash?(cmd)
            env_h = cmd.raw.each_with_object({}) do |(k, v), h|
              h[fstr?(k) ? k.raw : k.raw.to_s] = fnil?(v) ? nil : (fstr?(v) ? v.raw : v.raw.to_s)
            end
            [opts_obj, env_h]
          else
            [cmd, env_hash]
          end
          native_io = if farray?(actual_cmd)
            arr = actual_cmd.raw.map { |a| fstr?(a) ? a.raw : a.to_s }
            arr = [actual_env, *arr] if actual_env
            reraise(::Errno::ENOENT, ::Errno::EACCES, ::ArgumentError, ::SystemCallError) do
              ::IO.popen(arr, mode, **mri_opts)
            end
          elsif fstr?(actual_cmd)
            reraise(::Errno::ENOENT, ::ArgumentError, ::SystemCallError) do
              ::IO.popen(actual_cmd.raw, mode, **mri_opts)
            end
          else
            reraise(::ArgumentError) { ::IO.popen(actual_cmd.to_s, mode, **mri_opts) }
          end
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
          IOObject.new(native_io, Core.io_class)
        end

        def io_external_encoding(_, receiver)
          return FNIL unless fio?(receiver)
          enc = receiver.native_io.external_encoding rescue nil
          return FNIL if enc.nil?
          n2f_str(enc.name)
        end

        def io_explicit_encoding?(_, receiver)
          return FFALSE unless fio?(receiver)
          n2f_bool(receiver.explicit_encoding?)
        end

        def io_mark_explicit_encoding(_, receiver)
          return FNIL unless fio?(receiver)
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

        def io_pipe(_, ext_enc_obj = FNIL, int_enc_obj = FNIL)
          reraise(::SystemCallError) do
            r_native, w_native = ::IO.pipe
            r_io = IOObject.new(r_native, Core.io_class)
            w_io = IOObject.new(w_native, Core.io_class)
            unless fnil?(ext_enc_obj)
              ext_name = fstr?(ext_enc_obj) ? ext_enc_obj.raw : ext_enc_obj.get_ivar(:@name)&.then { |n| fstr?(n) ? n.raw : n.to_s }
              if ext_name
                int_name = if fnil?(int_enc_obj) then nil
                           elsif fstr?(int_enc_obj) then int_enc_obj.raw
                           else int_enc_obj.get_ivar(:@name)&.then { |n| fstr?(n) ? n.raw : n.to_s }
                           end
                r_native.set_encoding(ext_name, int_name)
              end
            end
            n2f_arr([r_io, w_io])
          end
        end

        def io_dup(_, receiver)
          return FNIL unless fio?(receiver)
          native = receiver.native_io
          reraise(::IOError, ::SystemCallError) do
            duped_native = native.dup
            IOObject.new(duped_native, receiver.class_object)
          end
        end

        def io_new_from_fd(context, fd_obj, mode_obj = FNIL, opts_obj = FNIL)
          fd = if fint?(fd_obj) then fd_obj.raw
               else
                 begin
                   coerced = fd_obj.dispatch(context, :to_int, [], {})
                   raise FrozoneException.make(:TypeError, "no implicit conversion of #{fd_obj.class_object.name} into Integer") unless fint?(coerced)
                   coerced.raw
                 rescue FrozoneException => e
                   raise unless e.frozone_class_name == :NoMethodError
                   raise FrozoneException.make(:TypeError, "no implicit conversion of #{fd_obj.class_object.name} into Integer")
                 end
               end
          mode, opts = parse_io_mode(context, mode_obj, opts_obj)
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
          return FNIL unless fio?(receiver)
          len = f2n_raw(len_obj)
          has_buf = fstr?(buf_obj)
          if has_buf && buf_obj.frozen_object?
            raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{buf_obj.raw.inspect}")
          end
          reraise(::IOError) do
            result = len ? receiver.native_io.read(len) : receiver.native_io.read
            if has_buf
              # Modify buffer in-place, preserving encoding when reading with a length limit.
              # When reading all (len=nil), buffer encoding follows the IO encoding.
              orig_enc = len ? buf_obj.raw.encoding : nil
              buf_obj.raw.replace(result || "")
              buf_obj.raw.force_encoding(orig_enc) if orig_enc
              result.nil? ? FNIL : buf_obj
            else
              result.nil? ? FNIL : n2f_str(result)
            end
          end
        end

        def io_gets(_, receiver, sep_obj = FNIL, limit_obj = FNIL)
          return FNIL unless fio?(receiver)
          # sep_obj: FNIL means nil (no separator = read to EOF), otherwise use raw value
          sep = fnil?(sep_obj) ? nil : f2n_raw(sep_obj)
          limit = fnil?(limit_obj) ? nil : (limit_obj.is_a?(IntegerObject) ? limit_obj.raw : nil)
          reraise(::IOError) do
            line = if limit.nil?
              receiver.native_io.gets(sep)
            elsif sep.nil?
              receiver.native_io.gets(nil, limit)
            else
              receiver.native_io.gets(sep, limit)
            end
            line.nil? ? FNIL : n2f_str(line)
          end
        end

        def io_readline(_, receiver, sep_obj = FNIL)
          return FNIL unless fio?(receiver)
          sep = fnil?(sep_obj) ? $/ : f2n_raw(sep_obj)
          reraise(::EOFError, ::IOError) { n2f_str(receiver.native_io.readline(sep)) }
        end

        def io_readlines(_, receiver, sep_obj = FNIL)
          return n2f_arr([]) unless fio?(receiver)
          sep = fnil?(sep_obj) ? $/ : f2n_raw(sep_obj)
          reraise(::IOError) { n2f_arr(receiver.native_io.readlines(sep).map { |l| n2f_str(l) }) }
        end

        def io_close(_, receiver)
          return FNIL unless fio?(receiver)
          receiver.native_io.close rescue nil
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
          FNIL
        end

        def io_pid(_, receiver)
          return FNIL unless fio?(receiver)
          pid = receiver.native_io.pid rescue nil
          pid ? n2f_int(pid) : FNIL
        end

        def io_close_read(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { receiver.native_io.close_read }
          FNIL
        end

        def io_close_write(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { receiver.native_io.close_write }
          FNIL
        end

        def io_closed?(_, receiver)
          return FTRUE unless fio?(receiver)
          n2f_bool(receiver.native_io.closed?)
        end

        def io_fileno(_, receiver)
          return n2f_int(1) unless fio?(receiver)
          reraise(::IOError) { n2f_int(receiver.native_io.fileno) }
        end

        def io_close_on_exec_q(_, receiver)
          return FTRUE unless fio?(receiver)
          reraise(::IOError) { n2f_bool(receiver.native_io.close_on_exec?) }
        end

        def io_close_on_exec_set(_, receiver, val)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { receiver.native_io.close_on_exec = ftrue?(val) }
          val
        end

        def io_eof?(_, receiver)
          return FTRUE unless fio?(receiver)
          reraise(::IOError) { n2f_bool(receiver.native_io.eof?) }
        end

        def io_seek(_, receiver, offset_obj, whence_obj = FNIL)
          return n2f_int(0) unless fio?(receiver)
          offset = fint?(offset_obj) ? offset_obj.raw : 0
          whence = fnil?(whence_obj) ? ::IO::SEEK_SET : whence_obj.raw
          reraise(::IOError) { n2f_int(receiver.native_io.seek(offset, whence)) }
        end

        def io_pos(_, receiver)
          return n2f_int(0) unless fio?(receiver)
          n2f_int(receiver.native_io.pos)
        end

        def io_pos_set(_, receiver, pos_obj)
          return pos_obj unless fio?(receiver)
          receiver.native_io.pos = fint?(pos_obj) ? pos_obj.raw : 0
          pos_obj
        end

        def io_rewind(_, receiver)
          return n2f_int(0) unless fio?(receiver)
          receiver.native_io.rewind
          n2f_int(0)
        end

        def io_binmode(_, receiver)
          return receiver unless fio?(receiver)
          receiver.native_io.binmode
          receiver
        end

        def io_binmode?(_, receiver)
          return FFALSE unless fio?(receiver)
          n2f_bool(receiver.native_io.binmode?)
        end

        def io_set_encoding(_, receiver, ext_obj, int_obj = FNIL)
          return receiver unless fio?(receiver)
          ext_enc = extract_encoding_name(ext_obj)
          int_enc = extract_encoding_name(int_obj)
          # Always call set_encoding when int_obj was explicitly provided (even if nil)
          # FNIL means "not provided"; but since FNIL == NilObject::NIL, we check ext_obj too
          begin
            receiver.native_io.set_encoding(ext_enc, int_enc)
          rescue => _ignored
          end
          receiver
        end

        def io_internal_encoding(_, receiver)
          return FNIL unless fio?(receiver)
          enc = receiver.native_io.internal_encoding rescue nil
          enc ? n2f_str(enc.name) : FNIL
        end

        def io_isatty(_, receiver)
          return FFALSE unless fio?(receiver)
          n2f_bool(receiver.native_io.isatty)
        end

        def io_getbyte(_, receiver)
          return FNIL unless fio?(receiver)
          b = receiver.native_io.getbyte
          b.nil? ? FNIL : n2f_int(b)
        end

        def io_getc(_, receiver)
          return FNIL unless fio?(receiver)
          c = receiver.native_io.getc
          c.nil? ? FNIL : n2f_str(c)
        end

        def io_readbyte(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::EOFError) { n2f_int(receiver.native_io.readbyte) }
        end

        def io_readchar(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::EOFError) { n2f_str(receiver.native_io.readchar) }
        end

        def io_ungetbyte(_, receiver, byte_obj)
          return FNIL unless fio?(receiver)
          byte = f2n_raw(byte_obj)
          receiver.native_io.ungetbyte(byte) if byte
          FNIL
        end

        def io_ungetc(_, receiver, str_obj)
          return FNIL unless fio?(receiver)
          receiver.native_io.ungetc(fstr?(str_obj) ? str_obj.raw : str_obj.to_s)
          FNIL
        end

        def io_sysread(_, receiver, len_obj, buf_obj = FNIL)
          return FNIL unless fio?(receiver)
          reraise(::EOFError, ::IOError) { n2f_str(receiver.native_io.sysread(fint?(len_obj) ? len_obj.raw : 0)) }
        end

        def io_syswrite(_, receiver, str_obj)
          return n2f_int(0) unless fio?(receiver)
          reraise(::IOError) { n2f_int(receiver.native_io.syswrite(fstr?(str_obj) ? str_obj.raw : str_obj.to_s)) }
        end

        def io_each_line(context, receiver, sep_obj = FNIL, block = FNIL)
          return receiver unless fio?(receiver) && !fnil?(block)
          sep = fnil?(sep_obj) ? $/ : (fstr?(sep_obj) ? sep_obj.raw : $/)
          reraise(::IOError) do
            receiver.native_io.each_line(sep) { |line| block.invoke(context, [n2f_str(line)]) }
            receiver
          end
        end

        def io_each_byte(context, receiver, block = FNIL)
          return receiver unless fio?(receiver) && !fnil?(block)
          receiver.native_io.each_byte { |b| block.invoke(context, [n2f_int(b)]) }
          receiver
        end

        def io_each_char(context, receiver, block = FNIL)
          return receiver unless fio?(receiver) && !fnil?(block)
          receiver.native_io.each_char { |c| block.invoke(context, [n2f_str(c)]) }
          receiver
        end

        def io_stat(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) do
            stat = receiver.native_io.stat
            stat_obj = ObjectObject.new(Core::OBJECT_CLASS.get_constant(:File)&.get_constant(:Stat) || Core::OBJECT_CLASS)
            stat_obj.set_ivar(:@native_stat, ObjectObject.new(Core::OBJECT_CLASS).tap { |o| o.instance_variable_set(:@raw, stat) })
            stat_obj
          end
        end

        def io_inspect(_, receiver)
          return n2f_str("#<IO>") unless fio?(receiver)
          n2f_str(receiver.native_io.inspect)
        rescue
          n2f_str("#<IO>")
        end

        def io_chmod(_, receiver, mode_obj)
          return n2f_int(0) unless fio?(receiver)
          mode = fint?(mode_obj) ? mode_obj.raw : mode_obj.raw.to_i
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if mode > 2**32 || mode < -(2**31)
          reraise(::RangeError, ::Errno::EBADF) do
            receiver.native_io.chmod(mode)
            n2f_int(0)
          end
        end

        def io_truncate(_, receiver, len_obj)
          return n2f_int(0) unless fio?(receiver)
          len = fint?(len_obj) ? len_obj.raw : len_obj.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          reraise(::IOError, ::Errno::EINVAL) do
            receiver.native_io.truncate(len)
            n2f_int(0)
          end
        end

        def io_writable?(_, receiver)
          return FFALSE unless fio?(receiver)
          n2f_bool((receiver.native_io.stat.mode rescue 0) & 0o200 != 0)
        rescue
          FFALSE
        end

        def io_atime(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.atime) }
        end

        def io_mtime(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.mtime) }
        end

        def io_ctime(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError) { n2f_time(receiver.native_io.stat.ctime) }
        end

        def io_birthtime(_, receiver)
          return FNIL unless fio?(receiver)
          reraise(::IOError, ::NotImplementedError) { n2f_time(receiver.native_io.stat.birthtime) }
        end

        def io_path(_, receiver)
          return FNIL unless fio?(receiver)
          path = receiver.native_io.path rescue nil
          path ? n2f_str(path) : FNIL
        rescue
          FNIL
        end

        def io_flock(_, receiver, lock_op_obj)
          return n2f_int(0) unless fio?(receiver)
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
          total = 0
          args.raw.each do |arg|
            s = arg.dispatch(context, :to_s, [], {}).raw
            total += native.write(s)
          end
          n2f_int(total)
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

        def io_select(_, reads_obj, writes_obj = FNIL, errors_obj = FNIL, timeout_obj = FNIL)
          to_native = lambda do |arr_obj|
            return nil if fnil?(arr_obj)
            return nil unless farray?(arr_obj)
            arr_obj.raw.map { |io| fio?(io) ? io.native_io : nil }.compact
          end
          native_reads  = to_native.call(reads_obj)
          native_writes = to_native.call(writes_obj)
          native_errors = to_native.call(errors_obj)
          timeout = fnil?(timeout_obj) ? nil : (fint?(timeout_obj) ? timeout_obj.raw.to_f : (ffloat?(timeout_obj) ? timeout_obj.raw : nil))
          # Build native → frozone IO mapping
          all_frozone = [reads_obj, writes_obj, errors_obj].flat_map { |a| farray?(a) ? a.raw : [] }
          native_to_frozone = {}
          all_frozone.each { |fio| native_to_frozone[fio.native_io] = fio if fio?(fio) }
          result = ::IO.select(native_reads, native_writes, native_errors, timeout)
          return FNIL if result.nil?
          n2f_arr(result.map { |arr| n2f_arr(arr.map { |native| native_to_frozone[native] || IOObject.new(native, Core.io_class) }) })
        end

        def io_pread(_, receiver, length_obj, offset_obj, buf_obj = FNIL)
          native = native_io_for(receiver)
          len    = fint?(length_obj) ? length_obj.raw : length_obj.raw.to_i
          off    = fint?(offset_obj) ? offset_obj.raw : offset_obj.raw.to_i
          reraise(::IOError, ::SystemCallError, ::EOFError) do
            str = native.pread(len, off)
            n2f_str(str)
          end
        end

        def io_pwrite(_, receiver, str_obj, offset_obj)
          native = native_io_for(receiver)
          str    = fstr?(str_obj) ? str_obj.raw : str_obj.raw.to_s
          off    = fint?(offset_obj) ? offset_obj.raw : offset_obj.raw.to_i
          reraise(::IOError, ::SystemCallError) do
            n2f_int(native.pwrite(str, off))
          end
        end

        def io_read_nonblock(_, receiver, len_obj, buf_obj = FNIL, exception_flag = FNIL)
          native = native_io_for(receiver)
          len = fint?(len_obj) ? len_obj.raw : len_obj.raw.to_i
          no_exception = !fnil?(exception_flag) && !exception_flag.truthy?
          begin
            str = native.read_nonblock(len, exception: !no_exception)
            return n2f_sym(:wait_readable) if str == :wait_readable
            return FNIL if str.nil?
            n2f_str(str)
          rescue ::IO::WaitReadable => e
            reraise(e.class) { raise }
          rescue ::IO::WaitWritable => e
            reraise(e.class) { raise }
          rescue ::EOFError, ::IOError, ::SystemCallError => e
            reraise(e.class) { raise }
          end
        end

        def io_write_nonblock(_, receiver, str_obj, exception_flag = FNIL)
          native = native_io_for(receiver)
          str = fstr?(str_obj) ? str_obj.raw : str_obj.raw.to_s
          no_exception = !fnil?(exception_flag) && !exception_flag.truthy?
          begin
            result = native.write_nonblock(str, exception: !no_exception)
            return n2f_sym(:wait_writable) if result == :wait_writable
            n2f_int(result)
          rescue ::IO::WaitReadable => e
            reraise(e.class) { raise }
          rescue ::IO::WaitWritable => e
            reraise(e.class) { raise }
          rescue ::IOError, ::SystemCallError => e
            reraise(e.class) { raise }
          end
        end

        def io_reopen(context, receiver, target, mode = FNIL)
          native = native_io_for(receiver)
          if fio?(target)
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
          reraise(Errno::ENOENT, Errno::EACCES) do
            if fint?(path_or_fd)
              native = ::File.new(path_or_fd.raw, mode)
              file_klass = Core.file_class || Core.io_class || Core::OBJECT_CLASS
            else
              p = fstr?(path_or_fd) ? path_or_fd.raw : coerce_to_path(context, path_or_fd)
              native = ::File.open(p, mode)
              file_klass = Core.file_class || Core.io_class || Core::OBJECT_CLASS
            end
            IOObject.new(native, file_klass)
          end
        end

        def dir_fchdir(context, fd_obj, block_obj = FNIL)
          fd = fint?(fd_obj) ? fd_obj.raw : (native_io_for(fd_obj).fileno rescue nil)
          if fnil?(block_obj)
            Dir.fchdir(fd) if fd
            n2f_int(0)
          else
            result = nil
            Dir.fchdir(fd) do
              result = block_obj.invoke(context, [])
            end
            result
          end
        end


        private

        def native_io_for(receiver) = fio?(receiver) ? receiver.native_io : $stdout

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

        # Coerce a Frozone object to a Ruby string via to_str dispatch.
        def coerce_to_str_raw(context, obj, type_name = nil)
          return nil if fnil?(obj)
          return obj.raw if fstr?(obj)
          begin
            coerced = obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object.name} into String") unless fstr?(coerced)
            coerced.raw
          rescue FrozoneException => e
            raise unless e.frozone_class_name == :NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{obj.class_object.name} into String")
          end
        end

        # Parse IO.new mode and opts arguments.
        # Returns [mode, opts_hash] where mode is nil/String/Integer and opts_hash is a Ruby Hash.
        def parse_io_mode(context, mode_obj, opts_obj)
          mode = if fnil?(mode_obj) then nil
                 elsif fstr?(mode_obj) then mode_obj.raw
                 elsif fint?(mode_obj) then mode_obj.raw
                 elsif fhash?(mode_obj) then (opts_obj = mode_obj; nil)
                 else
                   # Try to_str/to_int coercion
                   begin
                     coerced = mode_obj.dispatch(context, :to_str, [], {})
                     fstr?(coerced) ? coerced.raw : nil
                   rescue FrozoneException => e
                     raise unless e.frozone_class_name == :NoMethodError
                     begin
                       coerced = mode_obj.dispatch(context, :to_int, [], {})
                       fint?(coerced) ? coerced.raw : nil
                     rescue FrozoneException
                       nil
                     end
                   end
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
                                                         when ObjectObject
                                                           # Encoding objects passed as option values: extract name string
                                                           if v.class_object&.name == :Encoding
                                                             name_ivar = v.get_ivar(:@name)
                                                             name_ivar && fstr?(name_ivar) ? name_ivar.raw : v
                                                           else
                                                             sym_k = fsym?(k) ? k.raw : k.to_s.to_sym
                                                             if sym_k == :mode
                                                               # Mode can be String or Integer: try to_str, then to_int
                                                               begin
                                                                 coerce_to_str_raw(context, v)
                                                               rescue FrozoneException
                                                                 begin
                                                                   coerced = v.dispatch(context, :to_int, [], {})
                                                                   fint?(coerced) ? coerced.raw : v
                                                                 rescue FrozoneException
                                                                   v
                                                                 end
                                                               end
                                                             elsif %i[encoding external_encoding internal_encoding].include?(sym_k)
                                                               coerce_to_str_raw(context, v) || v
                                                             else
                                                               v
                                                             end
                                                           end
                                                         else v
                                                         end
            end
          end
          # Warn if :encoding is given alongside :external_encoding or :internal_encoding (MRI behavior)
          if opts.key?(:encoding) && (opts.key?(:external_encoding) || opts.key?(:internal_encoding))
            enc_val = opts.delete(:encoding)
            Frozone::Vm.emit_warning(context, "Ignoring encoding parameter '#{enc_val}': external_encoding is used")
          end
          # Merge :mode option: if positional mode is nil, use :mode opt; if both non-nil, error.
          opt_mode = opts.delete(:mode)
          if opt_mode && !mode.nil?
            raise FrozoneException.make(:ArgumentError, "mode specified twice")
          end
          mode = opt_mode if opt_mode && mode.nil?
          [mode, opts]
        end
      end
    end
  end
end

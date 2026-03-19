module Frozone
  module Vm
    module Intrinsics
      # Current Frozone (simulated) thread ID: nil = main thread, otherwise the
      # object_id of the active Frozone Thread object (set by thread_save_reset_locals).
      # Single-element array so it can be mutated from class methods.
      CURRENT_FROZONE_THREAD_ID = [nil]

      class << self
        def io_print(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          args.raw.each { |a| native.print(a.dispatch(context, :to_s, [], {}).raw) }
          NilObject::NIL
        end

        def io_puts(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          if args.raw.empty?
            native.puts
          else
            args.raw.each { |a| native.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          NilObject::NIL
        end

        def io_write(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          str = args.raw.first
          s = str.dispatch(context, :to_s, [], {}).raw
          native.write(s)
          IntegerObject.new(s.bytesize)
        end

        def io_flush(_, receiver)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          native.flush rescue nil
          receiver
        end

        def io_sync_set(_, receiver, val)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          native.sync = val.truthy? rescue nil
          val
        end

        def io_popen_capture(_, cmd, opts_obj = NilObject::NIL)
          # Convert opts HashObject to MRI hash
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
            cmd_arr = cmd.raw.map { |a| a.is_a?(StringObject) ? a.raw : a.to_s }
            ::IO.popen(cmd_arr, 'r', **mri_opts, &:read) rescue ""
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
          # If no explicit encoding was specified, the IO tracks Encoding.default_external.
          # Return the name so the Ruby layer can look up the Frozone Encoding object.
          # The flag tells us whether it was explicit (specific encoding) or implicit (default_external).
          StringObject.new(enc.name)
        end

        def io_explicit_encoding?(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          receiver.explicit_encoding? ? TrueObject::TRUE : FalseObject::FALSE
        end

        def io_mark_explicit_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          receiver.instance_variable_set(:@explicit_encoding, true)
          NilObject::NIL
        end

        # Sync Frozone's Encoding.default_external to MRI so native IO objects track it.
        def encoding_set_default_external(_, name_obj)
          name = name_obj.is_a?(StringObject) ? name_obj.raw : (frozone_nil?(name_obj) ? nil : name_obj.to_s)
          begin
            enc = name ? ::Encoding.find(name) : ::Encoding::UTF_8
            ::Encoding.default_external = enc
          rescue ::ArgumentError
            # Unknown encoding name — leave MRI default unchanged
          end
          NilObject::NIL
        end

        # Sync Frozone's Encoding.default_internal to MRI so native IO objects track it.
        def encoding_set_default_internal(_, name_obj)
          name = name_obj.is_a?(StringObject) ? name_obj.raw : (frozone_nil?(name_obj) ? nil : name_obj.to_s)
          begin
            enc = name ? ::Encoding.find(name) : nil
            ::Encoding.default_internal = enc
          rescue ::ArgumentError
            # Unknown encoding name — leave MRI default unchanged
          end
          NilObject::NIL
        end

        # IO.sysopen(path, mode_str = 'r', perm = 0666) → integer fd
        def io_sysopen(_, path_obj, mode_obj = NilObject::NIL, perm_obj = NilObject::NIL)
          path = path_obj.is_a?(StringObject) ? path_obj.raw : path_obj.to_s
          mode = if frozone_nil?(mode_obj)
            'r'
          elsif mode_obj.is_a?(StringObject)
            mode_obj.raw
          elsif mode_obj.is_a?(IntegerObject)
            mode_obj.raw  # numeric flags
          else
            'r'
          end
          perm = perm_obj.is_a?(IntegerObject) ? perm_obj.raw : 0o666
          begin
            fd = if mode.is_a?(::Integer)
              ::IO.sysopen(path, mode, perm)
            else
              ::IO.sysopen(path, mode, perm)
            end
            IntegerObject.new(fd)
          rescue ::Errno::ENOENT => e
            raise FrozoneException.make(:Errno__ENOENT, e.message)
          rescue ::Errno::EACCES => e
            raise FrozoneException.make(:Errno__EACCES, e.message)
          rescue ::TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          rescue ::ArgumentError => e
            raise FrozoneException.make(:ArgumentError, e.message)
          rescue ::SystemCallError => e
            raise FrozoneException.make(:SystemCallError, e.message)
          end
        end

        # IO.new(fd, mode_or_opts = 'r', **opts) → IOObject
        def io_new_from_fd(_, fd_obj, mode_obj = NilObject::NIL, opts_obj = NilObject::NIL)
          fd = fd_obj.is_a?(IntegerObject) ? fd_obj.raw : fd_obj.raw.to_i
          mode = if frozone_nil?(mode_obj)
            nil
          elsif mode_obj.is_a?(StringObject)
            mode_obj.raw
          elsif mode_obj.is_a?(IntegerObject)
            mode_obj.raw
          elsif mode_obj.is_a?(HashObject)
            opts_obj = mode_obj
            nil
          else
            nil
          end
          opts = {}
          if opts_obj.is_a?(HashObject)
            opts_obj.raw.each do |k, v|
              key = k.is_a?(SymbolObject) ? k.raw : k.to_s.to_sym
              opts[key] = case v
                          when StringObject  then v.raw
                          when IntegerObject then v.raw
                          when TrueObject    then true
                          when FalseObject   then false
                          when NilObject     then nil
                          else v
                          end
            end
          end
          # Detect if encoding was explicitly specified in the mode string (e.g., 'r:utf-8')
          explicit_enc = mode.is_a?(::String) && mode.include?(':')
          explicit_enc ||= opts.key?(:encoding) || opts.key?(:external_encoding)
          begin
            native_io = if mode && opts.empty?
              ::IO.new(fd, mode)
            elsif mode
              ::IO.new(fd, mode, **opts)
            elsif opts.empty?
              ::IO.new(fd)
            else
              ::IO.new(fd, **opts)
            end
            IOObject.new(native_io, Core.io_class, explicit_encoding: explicit_enc)
          rescue ::ArgumentError => e
            raise FrozoneException.make(:ArgumentError, e.message)
          rescue ::TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          rescue ::SystemCallError => e
            raise FrozoneException.make(:SystemCallError, e.message)
          end
        end

        # IO instance read methods - delegate to native IO
        def io_read(_, receiver, len_obj = NilObject::NIL, buf_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          native = receiver.native_io
          len = frozone_nil?(len_obj) ? nil : len_obj.raw
          begin
            result = len ? native.read(len) : native.read
            result.nil? ? NilObject::NIL : StringObject.new(result)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_gets(_, receiver, sep_obj = NilObject::NIL, limit_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          native = receiver.native_io
          sep = frozone_nil?(sep_obj) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          begin
            line = native.gets(sep)
            line.nil? ? NilObject::NIL : StringObject.new(line)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_readline(_, receiver, sep_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          native = receiver.native_io
          sep = frozone_nil?(sep_obj) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          begin
            line = native.readline(sep)
            StringObject.new(line)
          rescue ::EOFError => e
            raise FrozoneException.make(:EOFError, e.message)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_readlines(_, receiver, sep_obj = NilObject::NIL)
          return ArrayObject.new([]) unless receiver.is_a?(IOObject)
          native = receiver.native_io
          sep = frozone_nil?(sep_obj) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : nil)
          begin
            lines = native.readlines(sep)
            ArrayObject.new(lines.map { |l| StringObject.new(l) })
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_close(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          begin
            receiver.native_io.close
          rescue ::IOError
            # Already closed — ignore
          end
          NilObject::NIL
        end

        def io_closed?(_, receiver)
          return TrueObject::TRUE unless receiver.is_a?(IOObject)
          receiver.native_io.closed? ? TrueObject::TRUE : FalseObject::FALSE
        end

        def io_fileno(_, receiver)
          return IntegerObject.new(1) unless receiver.is_a?(IOObject)
          begin
            IntegerObject.new(receiver.native_io.fileno)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_eof?(_, receiver)
          return TrueObject::TRUE unless receiver.is_a?(IOObject)
          begin
            receiver.native_io.eof? ? TrueObject::TRUE : FalseObject::FALSE
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_seek(_, receiver, offset_obj, whence_obj = NilObject::NIL)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          offset = offset_obj.is_a?(IntegerObject) ? offset_obj.raw : 0
          whence = frozone_nil?(whence_obj) ? ::IO::SEEK_SET : whence_obj.raw
          begin
            result = receiver.native_io.seek(offset, whence)
            IntegerObject.new(result)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_pos(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          IntegerObject.new(receiver.native_io.pos)
        end

        def io_pos_set(_, receiver, pos_obj)
          return pos_obj unless receiver.is_a?(IOObject)
          pos = pos_obj.is_a?(IntegerObject) ? pos_obj.raw : 0
          receiver.native_io.pos = pos
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
          receiver.native_io.binmode? ? TrueObject::TRUE : FalseObject::FALSE
        end

        def io_set_encoding(_, receiver, ext_obj, int_obj = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject)
          native = receiver.native_io
          ext_enc = case ext_obj
                    when StringObject then ext_obj.raw
                    when NilObject then nil
                    when ObjectObject
                      name_obj = ext_obj.get_ivar(:@name)
                      name_obj.is_a?(StringObject) ? name_obj.raw : nil
                    else nil
                    end
          int_enc = case int_obj
                    when StringObject then int_obj.raw
                    when NilObject, nil then nil
                    when ObjectObject
                      name_obj = int_obj.get_ivar(:@name)
                      name_obj.is_a?(StringObject) ? name_obj.raw : nil
                    else nil
                    end
          begin
            if int_enc
              native.set_encoding(ext_enc, int_enc)
            elsif ext_enc
              native.set_encoding(ext_enc)
            end
          rescue ::ArgumentError
            # Ignore encoding errors
          end
          receiver
        end

        def io_internal_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.internal_encoding rescue nil
          enc ? StringObject.new(enc.name) : NilObject::NIL
        end

        def io_isatty(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          receiver.native_io.isatty ? TrueObject::TRUE : FalseObject::FALSE
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
          begin
            IntegerObject.new(receiver.native_io.readbyte)
          rescue ::EOFError => e
            raise FrozoneException.make(:EOFError, e.message)
          end
        end

        def io_readchar(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          begin
            StringObject.new(receiver.native_io.readchar)
          rescue ::EOFError => e
            raise FrozoneException.make(:EOFError, e.message)
          end
        end

        def io_ungetbyte(_, receiver, byte_obj)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          byte = byte_obj.is_a?(IntegerObject) ? byte_obj.raw : (byte_obj.is_a?(StringObject) ? byte_obj.raw : nil)
          receiver.native_io.ungetbyte(byte) if byte
          NilObject::NIL
        end

        def io_ungetc(_, receiver, str_obj)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          str = str_obj.is_a?(StringObject) ? str_obj.raw : str_obj.to_s
          receiver.native_io.ungetc(str)
          NilObject::NIL
        end

        def io_sysread(_, receiver, len_obj, buf_obj = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          len = len_obj.is_a?(IntegerObject) ? len_obj.raw : 0
          begin
            StringObject.new(receiver.native_io.sysread(len))
          rescue ::EOFError => e
            raise FrozoneException.make(:EOFError, e.message)
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
        end

        def io_syswrite(_, receiver, str_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          str = str_obj.is_a?(StringObject) ? str_obj.raw : str_obj.to_s
          IntegerObject.new(receiver.native_io.syswrite(str))
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        end

        def io_each_line(context, receiver, sep_obj = NilObject::NIL, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject)
          native = receiver.native_io
          sep = frozone_nil?(sep_obj) ? $/ : (sep_obj.is_a?(StringObject) ? sep_obj.raw : $/)
          return receiver unless block && !block.is_a?(NilObject)
          begin
            native.each_line(sep) do |line|
              block.invoke(context, [StringObject.new(line)])
            end
          rescue ::IOError => e
            raise FrozoneException.make(:IOError, e.message)
          end
          receiver
        end

        def io_each_byte(context, receiver, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject)
          native = receiver.native_io
          return receiver unless block && !block.is_a?(NilObject)
          native.each_byte { |b| block.invoke(context, [IntegerObject.new(b)]) }
          receiver
        end

        def io_each_char(context, receiver, block = NilObject::NIL)
          return receiver unless receiver.is_a?(IOObject)
          native = receiver.native_io
          return receiver unless block && !block.is_a?(NilObject)
          native.each_char { |c| block.invoke(context, [StringObject.new(c)]) }
          receiver
        end

        def io_stat(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          stat = receiver.native_io.stat
          # Return a minimal File::Stat-like object
          stat_obj = ObjectObject.new(Core::OBJECT_CLASS.get_constant(:File)&.get_constant(:Stat) || Core::OBJECT_CLASS)
          stat_obj.set_ivar(:@native_stat, ObjectObject.new(Core::OBJECT_CLASS).tap { |o| o.instance_variable_set(:@raw, stat) })
          stat_obj
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
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
        rescue ::RangeError => e
          raise FrozoneException.make(:RangeError, e.message)
        rescue ::Errno::EBADF => e
          raise FrozoneException.make(:Errno__EBADF, e.message)
        end

        def io_truncate(_, receiver, len_obj)
          return IntegerObject.new(0) unless receiver.is_a?(IOObject)
          len = len_obj.is_a?(IntegerObject) ? len_obj.raw : len_obj.raw.to_i
          raise FrozoneException.make(:Errno__EINVAL, "Invalid argument") if len < 0
          receiver.native_io.truncate(len)
          IntegerObject.new(0)
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        rescue ::Errno::EINVAL => e
          raise FrozoneException.make(:Errno__EINVAL, e.message)
        end

        def io_writable?(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(IOObject)
          mode = receiver.native_io.stat.mode rescue 0
          bool_object_for((mode & 0o200) != 0)
        rescue
          FalseObject::FALSE
        end

        def io_atime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.atime)
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        end

        def io_mtime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.mtime)
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        end

        def io_ctime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.ctime)
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        end

        def io_birthtime(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          TimeObject.new(receiver.native_io.stat.birthtime)
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        rescue ::NotImplementedError => e
          raise FrozoneException.make(:NotImplementedError, e.message)
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
          op = lock_op_obj.is_a?(IntegerObject) ? lock_op_obj.raw : 0
          IntegerObject.new(receiver.native_io.flock(op))
        rescue ::IOError => e
          raise FrozoneException.make(:IOError, e.message)
        end

      end
    end
  end
end

require_relative 'intrinsics/helpers'
require_relative 'intrinsics/object_intrinsics'
require_relative 'intrinsics/kernel_intrinsics'
require_relative 'intrinsics/random_intrinsics'
require_relative 'intrinsics/fiber_intrinsics'
require_relative 'intrinsics/proc_intrinsics'
require_relative 'intrinsics/module_intrinsics'
require_relative 'intrinsics/numeric_intrinsics'
require_relative 'intrinsics/io_intrinsics'
require_relative 'intrinsics/string_intrinsics'
require_relative 'intrinsics/collection_intrinsics'

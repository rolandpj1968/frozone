class IO
  include Enumerable

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  # A read-only IO-like object backed by a captured string (used by IO.popen block form).
  class CapturedOutput
    def read(len = nil) = len ? @str[0, len] : @str
    def gets = @str
    def close = self

    def initialize(str)
      @str = str
    end
  end

  def print(*args) = Intrinsics.io_print(self, args)

  def puts(*args)
    if args.empty?
      write("
")
    else
      args.each do |arg|
        if arg.nil?
          write("
")
        elsif arg.is_a?(Array)
          __puts_array__(arg)
        elsif arg.respond_to?(:to_ary)
          ary = arg.to_ary
          ary.nil? ? __puts_scalar__(arg) : (ary.is_a?(Array) ? __puts_array__(ary) : __puts_scalar__(arg))
        else
          __puts_scalar__(arg)
        end
      end
    end
    nil
  end

  def __puts_array__(arr, seen = nil)
    seen ||= {}
    if seen.key?(arr.__id__)
      write("[...]\n")
      return
    end
    seen[arr.__id__] = true
    arr.each do |elem|
      if elem.is_a?(Array)
        __puts_array__(elem, seen)
      elsif elem.respond_to?(:to_ary)
        ary = elem.to_ary
        ary.nil? ? __puts_scalar__(elem) : (ary.is_a?(Array) ? __puts_array__(ary, seen) : __puts_scalar__(elem))
      else
        __puts_scalar__(elem)
      end
    end
  end
  private :__puts_array__

  def __puts_scalar__(arg)
    str = arg.to_s
    str = "#<#{arg.class}:0x#{arg.__id__.to_s(16)}>" unless str.is_a?(String)
    write(str)
    write("
") unless str.end_with?("
")
  end
  private :__puts_scalar__

  def write(*args) = Intrinsics.io_write(self, args)
  def flush = Intrinsics.io_flush(self)
  def sync=(val) = Intrinsics.io_sync_set(self, val)
  def sync       = Intrinsics.io_sync(self)
  def autoclose=(val)  = Intrinsics.io_autoclose_set(self, val)
  def autoclose?       = Intrinsics.io_autoclose?(self)
  def <<(str); write(str.is_a?(String) ? str : str.to_s); self; end
  def close = Intrinsics.io_close(self)
  def close_read = Intrinsics.io_close_read(self)
  def close_write = Intrinsics.io_close_write(self)
  def pid
    raise IOError, "closed stream" if closed?
    Intrinsics.io_pid(self)
  end

  def closed? = Intrinsics.io_closed?(self)
  def fileno = Intrinsics.io_fileno(self)
  alias to_i fileno
  def eof? = Intrinsics.io_eof?(self)
  def eof = eof?
  def close_on_exec? = Intrinsics.io_close_on_exec_q(self)
  def close_on_exec=(val) = Intrinsics.io_close_on_exec_set(self, val)
  def isatty = Intrinsics.io_isatty(self)
  def tty? = isatty
  def fsync = Intrinsics.io_fsync(self)
  def ioctl(integer_cmd, arg = 0) = Intrinsics.io_ioctl(self, integer_cmd, arg)
  def binmode = Intrinsics.io_binmode(self)
  def binmode? = Intrinsics.io_binmode?(self)
  def pos = Intrinsics.io_pos(self)
  def pos=(p)          = Intrinsics.io_pos_set(self, p)
  def tell = pos
  def rewind
    Intrinsics.io_rewind(self)
    @lineno = 0
    0
  end
  def stat = Intrinsics.io_stat(self)
  def inspect = Intrinsics.io_inspect(self)
  def read(len = nil, buf = nil)
    buf = buf.to_str if buf && !buf.is_a?(String) && buf.respond_to?(:to_str)
    Intrinsics.io_read(self, len, buf)
  end
  def lineno
    raise IOError, "closed stream" if closed?
    raise IOError, "not opened for reading" unless Intrinsics.io_readable?(self)
    @lineno ||= 0
  end

  def lineno=(n)
    raise IOError, "closed stream" if closed?
    raise IOError, "not opened for reading" unless Intrinsics.io_readable?(self)
    val = __coerce_to_int__(n)
    raise RangeError, "integer #{val} too big to convert into 'int'" if val > 2_147_483_647 || val < -2_147_483_648
    @lineno = val
  end

  def gets(*args, chomp: false)
    # Disambiguate: gets() → sep=$/, lim=nil
    #               gets(Integer) → sep=$/, lim=n
    #               gets(String/nil) → sep=arg, lim=nil
    #               gets(String/nil, Integer) → sep=arg, lim=n
    case args.length
    when 0
      sep = $/
      lim = nil
    when 1
      arg = args[0]
      if arg.is_a?(Integer)
        sep = $/; lim = arg
      elsif arg.nil?
        sep = nil; lim = nil  # nil sep = read to EOF
      elsif arg.respond_to?(:to_int) && !arg.respond_to?(:to_str)
        sep = $/; lim = arg.to_int  # responds to to_int but not to_str → treat as limit
      else
        sep = arg.respond_to?(:to_str) ? arg.to_str : arg; lim = nil
      end
    when 2
      sep = args[0].nil? ? nil : (args[0].respond_to?(:to_str) ? args[0].to_str : args[0])
      lim = args[1].nil? ? nil : args[1].to_int
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
    line = Intrinsics.io_gets(self, sep, lim)
    line = line.chomp if chomp && !line.nil?
    if line.nil?
      $_ = nil
    else
      @lineno = (@lineno || 0) + 1
      $. = @lineno
      $_ = line
    end
    line
  end
  def readline(*args, chomp: false)
    line = gets(*args, chomp: chomp)
    raise EOFError, "end of file reached" if line.nil?
    line
  end
  def readlines(*args, chomp: false, **_opts)
    sep, lim = __parse_sep_limit__(args)
    raise ArgumentError, "invalid limit: 0 for #{self.class}#readlines" if lim == 0
    lines = []
    while (line = Intrinsics.io_gets(self, sep, lim))
      @lineno = (@lineno || 0) + 1
      $. = @lineno
      if chomp
        line =
          if sep.nil? then line
          elsif sep.empty? then line.sub(/\n{2,}\z/, '')
          else line.chomp(sep)
          end
      end
      lines << line
    end
    lines
  end

  def getbyte = Intrinsics.io_getbyte(self)
  def getc = Intrinsics.io_getc(self)
  def readbyte = Intrinsics.io_readbyte(self)
  def readchar = Intrinsics.io_readchar(self)
  def ungetbyte(b) = Intrinsics.io_ungetbyte(self, b)
  def ungetc(s)
    if s.is_a?(Integer)
      enc = external_encoding || Encoding.default_external || Encoding::UTF_8
      Intrinsics.io_ungetc(self, s.chr(enc))
    elsif s.is_a?(String)
      Intrinsics.io_ungetc(self, s)
    elsif s.nil?
      raise TypeError, "no implicit conversion of nil into String"
    elsif s.respond_to?(:to_str)
      Intrinsics.io_ungetc(self, s.to_str)
    else
      raise TypeError, "no implicit conversion of #{s.class} into String"
    end
  end
  def sysread(len, buf = nil) = Intrinsics.io_sysread(self, len, buf)
  def syswrite(str) = Intrinsics.io_syswrite(self, str)
  def sysseek(offset, whence = SEEK_SET) = seek(offset, whence)
  def pread(length, offset, buf = nil) = Intrinsics.io_pread(self, length, offset, buf)
  def pwrite(str, offset) = Intrinsics.io_pwrite(self, str, offset)

  def seek(offset, whence = SEEK_SET)
    offset = __coerce_to_int__(offset)
    whence = __coerce_to_int__(whence)
    Intrinsics.io_seek(self, offset, whence)
  end

  def read_nonblock(len, buf = nil, exception: true)
    Intrinsics.io_read_nonblock(self, len, buf, exception)
  end

  def write_nonblock(str, exception: true)
    Intrinsics.io_write_nonblock(self, str, exception)
  end

  def readpartial(len, buf = nil) = Intrinsics.io_sysread(self, len, buf)

  def each_line(*args, chomp: false, &block)
    return to_enum(:each_line, *args, chomp: chomp) unless block
    sep, lim = __parse_sep_limit__(args)
    raise ArgumentError, "invalid limit: 0 for #{self.class}#each_line" if lim == 0
    while (line = Intrinsics.io_gets(self, sep, lim))
      @lineno = (@lineno || 0) + 1
      $. = @lineno
      if chomp
        line =
          if sep.nil?
            line  # slurp mode: no chomp
          elsif sep.empty?
            line.sub(/\n{2,}\z/, '')  # paragraph mode: strip 2+ trailing newlines only
          else
            line.chomp(sep)  # strip the separator
          end
      end
      block.call(line)
    end
    self
  end

  def each_byte(&block)
    return to_enum(:each_byte) unless block
    Intrinsics.io_each_byte(self, block)
  end

  def each_char(&block)
    return to_enum(:each_char) unless block
    Intrinsics.io_each_char(self, block)
  end

  def each_codepoint(&block)
    return to_enum(:each_codepoint) unless block
    each_char { |c| block.call(c.ord) }
  end

  def bytes(&block)
    return to_enum(:each_byte) unless block
    each_byte(&block)
  end

  def chars(&block)
    return to_enum(:each_char) unless block
    each_char(&block)
  end

  def codepoints(&block)
    return to_enum(:each_codepoint) unless block
    each_codepoint(&block)
  end

  def each(*args, chomp: false, &block) = each_line(*args, chomp: chomp, &block)
  def atime = Intrinsics.io_atime(self)
  def mtime = Intrinsics.io_mtime(self)
  def ctime = Intrinsics.io_ctime(self)
  def birthtime = Intrinsics.io_birthtime(self)
  def path = Intrinsics.io_path(self)
  def to_path = path
  def to_io = self
  def size = stat.size
  def printf(*args) = (write(sprintf(*args)); nil)
  def putc(c)
    if c.is_a?(String)
      write(c[0] || "")
    elsif c.is_a?(Integer)
      write((c & 0xFF).chr)
    elsif c.respond_to?(:to_int)
      write((c.to_int & 0xFF).chr)
    else
      raise TypeError, "no implicit conversion of #{c.class} into Integer"
    end
    c
  end
  def flock(lock_op) = Intrinsics.io_flock(self, lock_op)
  def advise(advice, offset = 0, len = 0) = nil
  def dup = Intrinsics.io_dup(self)

  def reopen(path_or_io, mode = nil)
    if path_or_io.respond_to?(:to_io)
      Intrinsics.io_reopen(self, path_or_io.to_io)
    elsif path_or_io.respond_to?(:to_path)
      Intrinsics.io_reopen(self, path_or_io.to_path, mode || 'r')
    elsif path_or_io.respond_to?(:to_str)
      Intrinsics.io_reopen(self, path_or_io.to_str, mode || 'r')
    else
      raise TypeError, "no implicit conversion of #{path_or_io.class} into String"
    end
  end

  def self.select(read_array, write_array = nil, error_array = nil, timeout = nil)
    Intrinsics.io_select(read_array, write_array, error_array, timeout)
  end

  def self.pipe(ext_enc = nil, int_enc = nil, **opts, &block)
    ext_enc = ext_enc.to_str if ext_enc && !ext_enc.is_a?(String) && !ext_enc.is_a?(Encoding) && ext_enc.respond_to?(:to_str)
    int_enc = int_enc.to_str if int_enc && !int_enc.is_a?(String) && !int_enc.is_a?(Encoding) && int_enc.respond_to?(:to_str)
    pair = Intrinsics.io_pipe(self)
    r_mode =
      if ext_enc
        ext_str = ext_enc.is_a?(Encoding) ? ext_enc.name : ext_enc.to_s
        int_enc ? "r:#{ext_str}:#{int_enc.is_a?(Encoding) ? int_enc.name : int_enc}" : "r:#{ext_str}"
      else
        'r'
      end
    pair[0].send(:initialize, pair[0].fileno, r_mode, **opts)
    pair[1].send(:initialize, pair[1].fileno, 'w')
    if block
      begin
        block.call(*pair)
      ensure
        pair[0].close unless pair[0].closed?
        pair[1].close unless pair[1].closed?
      end
    else
      pair
    end
  end

  def self.popen(*args, **opts, &block)
    # Support: popen(cmd, mode='r', **opts) and popen(env, cmd, mode='r', **opts)
    cmd, mode, env =
      if args.length >= 2 && args[0].is_a?(Hash) && !args[0].empty? &&
          !(args[1].is_a?(String) && args[1].start_with?('-'))
        env = args.shift
        [args[0], args[1] || 'r', env]
      else
        [args[0], args[1] || 'r', nil]
      end
    # Coerce mode with to_str if not a String or nil
    mode = mode.to_str if mode && !mode.is_a?(String) && mode.respond_to?(:to_str)
    # Coerce chdir: value with to_path if needed
    if opts.key?(:chdir) && opts[:chdir] && !opts[:chdir].is_a?(String)
      val = opts[:chdir]
      opts = opts.merge(chdir: val.to_path) if val.respond_to?(:to_path)
    end
    opts_arg = env ? opts.merge(env: env) : opts
    opts_arg = opts_arg.empty? ? nil : opts_arg
    io = Intrinsics.io_popen(self, cmd, mode, opts_arg)
    if block
      begin
        block.call(io)
      ensure
        io.close rescue nil
      end
    else
      io
    end
  end

  def self.sysopen(path, mode = 'r', perm = 0666)
    path = __coerce_to_path__(path)
    Intrinsics.io_sysopen(path, mode, perm)
  end

  def initialize(fd, mode_or_opts = nil, **opts)
    opts_arg = opts.empty? ? nil : opts
    Intrinsics.io_reinitialize(self, fd, mode_or_opts, opts_arg)
  end

  def self.new(fd, mode_or_opts = nil, **opts, &block)
    warn "warning: IO::new() does not take block; use IO::open() instead" if block
    opts_arg = opts.empty? ? nil : opts
    Intrinsics.io_new_from_fd(fd, mode_or_opts, opts_arg)
  end

  def self.for_fd(fd, mode = nil, **opts, &block)
    self.new(fd, mode, **opts, &block)
  end

  def self.open(fd_or_path, mode = nil, **opts, &block)
    if fd_or_path.is_a?(Integer) || (!fd_or_path.is_a?(String) && fd_or_path.respond_to?(:to_int))
      io = self.new(fd_or_path, mode, **opts)
      return io unless block
      block_error = nil
      begin
        block.call(io)
      rescue Exception => block_error
        raise
      ensure
        begin
          io.close
        rescue IOError => close_error
          raise close_error unless close_error.message == 'closed stream' || block_error
        rescue Exception => close_error
          raise close_error unless block_error
        end
      end
    else
      # Fall through to File.open equivalent for path-based open
      fd = self.sysopen(fd_or_path, mode || opts[:mode] || 'r')
      io = self.new(fd, mode, **opts)
      if block
        block_error = nil
        begin
          block.call(io)
        rescue Exception => block_error
          raise
        ensure
          begin
            io.close
          rescue IOError => close_error
            raise close_error unless close_error.message == 'closed stream' || block_error
          rescue Exception => close_error
            raise close_error unless block_error
          end
        end
      else
        io
      end
    end
  end

  # Shared helper: parse (sep, limit) from a raw *args array using MRI rules.
  # Returns [sep, lim] where lim may be nil.
  def __parse_sep_limit__(args)
    case args.length
    when 0
      [$/, nil]
    when 1
      arg = args[0]
      if arg.is_a?(Integer)
        [$/, arg]
      elsif arg.nil?
        [nil, nil]
      elsif !arg.respond_to?(:to_str) && arg.respond_to?(:to_int)
        [$/, arg.to_int]
      elsif arg.respond_to?(:to_str)
        [arg.to_str, nil]
      else
        raise TypeError, "no implicit conversion of #{arg.class} into String"
      end
    when 2
      sep =
        if args[0].nil?
          nil
        elsif args[0].respond_to?(:to_str)
          args[0].to_str
        else
          raise TypeError, "no implicit conversion of #{args[0].class} into String"
        end
      lim =
        if args[1].is_a?(Integer)
          args[1]
        elsif args[1].respond_to?(:to_int)
          args[1].to_int
        else
          raise TypeError, "no implicit conversion of #{args[1].class} into Integer"
        end
      [sep, lim]
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
  end
  private :__parse_sep_limit__

  # Coerce a path argument to String using to_path or to_str.
  def self.__coerce_path__(path)
    if path.nil?
      raise TypeError, "no implicit conversion of nil into String"
    elsif path.respond_to?(:to_path)
      path.to_path
    elsif path.respond_to?(:to_str)
      path.to_str
    else
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end
  end
  private_class_method :__coerce_path__

  def self.__parse_sep_limit__(args)
    case args.length
    when 0
      [$/, nil]
    when 1
      arg = args[0]
      if arg.is_a?(Integer)
        [$/, arg]
      elsif arg.nil?
        [nil, nil]
      elsif !arg.respond_to?(:to_str) && arg.respond_to?(:to_int)
        [$/, arg.to_int]
      elsif arg.respond_to?(:to_str)
        [arg.to_str, nil]
      else
        raise TypeError, "no implicit conversion of #{arg.class} into String"
      end
    when 2
      sep =
        if args[0].nil?
          nil
        elsif args[0].respond_to?(:to_str)
          args[0].to_str
        else
          raise TypeError, "no implicit conversion of #{args[0].class} into String"
        end
      lim =
        if args[1].is_a?(Integer)
          args[1]
        elsif args[1].respond_to?(:to_int)
          args[1].to_int
        else
          raise TypeError, "no implicit conversion of #{args[1].class} into Integer"
        end
      [sep, lim]
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
  end
  private_class_method :__parse_sep_limit__

  def self.foreach(path, *args, chomp: false, **opts, &block)
    return to_enum(:foreach, path, *args, chomp: chomp, **opts) unless block
    path = __coerce_path__(path)
    sep, lim = __parse_sep_limit__(args)
    raise ArgumentError, "invalid limit: 0 for IO.foreach" if lim == 0
    io_mode = opts.key?(:mode) ? opts.delete(:mode) : 'r'
    open(path, io_mode, **opts) do |f|
      while (line = f.gets(sep, *[lim].compact))
        if chomp
          line =
            if sep.nil? then line
            elsif sep.empty? then line.sub(/\n{2,}\z/, '')
            else line.chomp(sep)
            end
        end
        block.call(line)
      end
    end
    nil
  end

  def self.read(path, length = nil, offset = nil, **opts)
    path =
      if path.respond_to?(:to_path)
        path.to_path
      elsif path.respond_to?(:to_str)
        path.to_str
      else
        raise TypeError, "no implicit conversion of #{path.class} into String"
      end
    if offset
      offset = offset.respond_to?(:to_int) ? offset.to_int : Integer(offset)
      raise ArgumentError, "negative offset" if offset < 0
    end
    open_args = opts[:open_args]
    if open_args
      # open_args may be [mode] or [mode, {opts}] or [{opts}]
      args = open_args.dup
      kw = (args.last.is_a?(Hash) ? args.pop : {})
      mode = args.shift || 'r'
      open(path, mode, **kw) do |f|
        f.seek(offset) if offset
        length ? f.read(length) : f.read
      end
    else
      mode = opts[:mode] || 'r'
      enc_opt = {}
      enc_opt[:external_encoding] = opts[:external_encoding] || opts[:encoding] if opts[:external_encoding] || opts[:encoding]
      enc_opt[:internal_encoding] = opts[:internal_encoding] if opts[:internal_encoding]
      open(path, mode, **enc_opt) do |f|
        f.seek(offset) if offset
        length ? f.read(length) : f.read
      end
    end
  end

  def self.readlines(path, *args, chomp: false, **opts)
    path = __coerce_path__(path)
    io_mode = opts.key?(:mode) ? opts.delete(:mode) : 'r'
    open(path, io_mode, **opts) do |f|
      f.readlines(*args, chomp: chomp)
    end
  end

  def self.write(path, content, offset = nil, **opts)
    if opts.key?(:open_args)
      open_args = opts[:open_args]
      # open_args: array of positional/keyword args to File.open
      # Extract mode and kwargs from open_args
      open_mode = nil
      open_kwargs = {}
      open_args.each do |arg|
        if arg.is_a?(String)
          open_mode = arg
        elsif arg.is_a?(Hash)
          open_kwargs = arg
          open_mode ||= open_kwargs.delete(:mode)
        end
      end
      # When open_args is given: if no mode specified, open read-only (raises IOError on write)
      open_mode ||= 'r'
      open(path, open_mode, **open_kwargs) do |f|
        f.seek(offset) if offset
        return f.write(content)
      end
    else
      # Check for encoding specified both in mode string and :encoding option
      if opts[:mode].is_a?(String) && opts[:mode].include?(':') && opts.key?(:encoding)
        raise ArgumentError, "encoding specified twice"
      end
      mode = opts[:mode]
      enc = opts[:encoding]
      flags = opts[:flags]
      open_kwargs = {}
      open_kwargs[:encoding] = enc if enc
      open_kwargs[:flags] = flags if flags
      if mode.nil?
        if offset
          # Read-write without truncate; create if missing
          begin
            open(path, 'r+', **open_kwargs) do |f|
              f.seek(offset)
              return f.write(content)
            end
          rescue Errno::ENOENT
            # File doesn't exist: create it
            open(path, 'w', **open_kwargs) do |f|
              f.seek(offset)
              return f.write(content)
            end
          end
        else
          mode = 'w'
        end
      end
      open(path, mode, **open_kwargs) do |f|
        f.seek(offset) if offset
        f.write(content)
      end
    end
  end

  def self.binread(path, length = nil, offset = nil)
    open(path, 'rb') do |f|
      f.seek(offset) if offset
      length ? f.read(length) : f.read
    end
  end

  def self.binwrite(path, content, offset = nil, **opts)
    mode = opts[:mode]
    flags = opts[:flags]
    open_kwargs = {}
    open_kwargs[:flags] = flags if flags
    if mode.nil?
      if offset
        begin
          open(path, 'r+b', **open_kwargs) do |f|
            f.seek(offset)
            return f.write(content)
          end
        rescue Errno::ENOENT
          open(path, 'wb', **open_kwargs) do |f|
            f.seek(offset)
            return f.write(content)
          end
        end
      else
        mode = 'wb'
      end
    end
    open(path, mode, **open_kwargs) do |f|
      f.seek(offset) if offset
      f.write(content)
    end
  end

  def self.copy_stream(src, dst, copy_length = nil, src_offset = nil)
    src_io = src.is_a?(String) ? open(src, 'rb') : src
    dst_io = dst.is_a?(String) ? open(dst, 'wb') : dst
    begin
      src_io.seek(src_offset) if src_offset && src_io.respond_to?(:seek)
      copied = 0
      buf_size = 65536
      loop do
        remaining = copy_length ? [copy_length - copied, buf_size].min : buf_size
        break if remaining <= 0
        chunk = src_io.read(remaining)
        break if chunk.nil? || chunk.empty?
        dst_io.write(chunk)
        copied += chunk.bytesize
        break if copy_length && copied >= copy_length
      end
      copied
    ensure
      src_io.close if src.is_a?(String)
      dst_io.close if dst.is_a?(String)
    end
  end

  def chmod(mode)
    mode_int =
      if mode.is_a?(Integer)
        mode
      elsif mode.respond_to?(:to_int)
        mode.to_int
      else
        raise TypeError, "no implicit conversion of #{mode.class} into Integer"
      end
    raise RangeError, "bignum too big to convert into 'long'" if mode_int > 2**32 || mode_int < -(2**31)
    Intrinsics.io_chmod(self, mode_int)
  end

  def truncate(len)
    raise TypeError, "no implicit conversion into Integer" unless len.is_a?(Integer) || len.respond_to?(:to_int)
    raise IOError, "closed stream" if closed?
    l = len.is_a?(Integer) ? len : len.to_int
    Intrinsics.io_truncate(self, l)
  end

  def external_encoding
    name = Intrinsics.io_external_encoding(self)
    return nil if name.nil?
    # Return the encoding reported by the native IO. Since Frozone syncs its
    # Encoding.default_external changes to MRI, the native IO's encoding will
    # dynamically track Frozone's default_external when no explicit encoding was given,
    # and remain frozen when default_internal == default_external at creation time.
    Encoding.find(name)
  rescue ArgumentError
    Encoding.default_external
  end

  def internal_encoding
    name = Intrinsics.io_internal_encoding(self)
    name.nil? ? nil : Encoding.find(name)
  end

  def set_encoding(ext_enc, int_enc = nil)
    Intrinsics.io_set_encoding(self, ext_enc, int_enc)
    Intrinsics.io_mark_explicit_encoding(self)
    self
  end
  module WaitReadable; end
  module WaitWritable; end

  # Match MRI: Errno::EAGAIN/EWOULDBLOCK include WaitReadable so that
  # read_nonblock raises something that is_a?(IO::WaitReadable).
  Errno::EAGAIN.include IO::WaitReadable
  Errno::EWOULDBLOCK.include IO::WaitReadable unless Errno::EAGAIN.equal?(Errno::EWOULDBLOCK)
  Errno::EINPROGRESS.include IO::WaitWritable if defined?(Errno::EINPROGRESS)

  EAGAINWaitReadable = Class.new(Errno::EAGAIN) { include IO::WaitReadable }
  EAGAINWaitWritable = Class.new(Errno::EAGAIN) { include IO::WaitWritable }

  EWOULDBLOCKWaitReadable = Errno::EAGAIN.equal?(Errno::EWOULDBLOCK) ?
    EAGAINWaitReadable :
    Class.new(Errno::EWOULDBLOCK) { include IO::WaitReadable }
  EWOULDBLOCKWaitWritable = Errno::EAGAIN.equal?(Errno::EWOULDBLOCK) ?
    EAGAINWaitWritable :
    Class.new(Errno::EWOULDBLOCK) { include IO::WaitWritable }
end


class STDOUT < IO; end
class STDERR < IO; end
class STDIN  < IO; end

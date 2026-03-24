class IO
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
        else
          begin
            ary = arg.to_ary
            ary.nil? ? __puts_scalar__(arg) : (ary.is_a?(Array) ? __puts_array__(ary) : __puts_scalar__(arg))
          rescue NoMethodError
            __puts_scalar__(arg)
          end
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
      else
        begin
          ary = elem.to_ary
          ary.nil? ? __puts_scalar__(elem) : (ary.is_a?(Array) ? __puts_array__(ary, seen) : __puts_scalar__(elem))
        rescue NoMethodError
          __puts_scalar__(elem)
        end
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
  def sync=(val)       = Intrinsics.io_sync_set(self, val)
  def sync = true
  def autoclose=(val)  = Intrinsics.io_autoclose_set(self, val)
  def autoclose?       = Intrinsics.io_autoclose?(self)
  def <<(str); write(str); self; end
  def close = Intrinsics.io_close(self)
  def close_read = Intrinsics.io_close_read(self)
  def close_write = Intrinsics.io_close_write(self)
  def pid = Intrinsics.io_pid(self)
  def closed? = Intrinsics.io_closed?(self)
  def fileno = Intrinsics.io_fileno(self)
  def eof? = Intrinsics.io_eof?(self)
  def eof = eof?
  def close_on_exec? = Intrinsics.io_close_on_exec_q(self)
  def close_on_exec=(val) = Intrinsics.io_close_on_exec_set(self, val)
  def isatty = Intrinsics.io_isatty(self)
  def tty? = isatty
  def binmode = Intrinsics.io_binmode(self)
  def binmode? = Intrinsics.io_binmode?(self)
  def pos = Intrinsics.io_pos(self)
  def pos=(p)          = Intrinsics.io_pos_set(self, p)
  def tell = pos
  def rewind = Intrinsics.io_rewind(self)
  def stat = Intrinsics.io_stat(self)
  def inspect = Intrinsics.io_inspect(self)
  def read(len = nil, buf = nil) = Intrinsics.io_read(self, len, buf)
  def lineno
    @lineno ||= 0
  end

  def lineno=(n)
    @lineno = n.to_int
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
  def readlines(sep = $/) = Intrinsics.io_readlines(self, sep)
  def getbyte = Intrinsics.io_getbyte(self)
  def getc = Intrinsics.io_getc(self)
  def readbyte = Intrinsics.io_readbyte(self)
  def readchar = Intrinsics.io_readchar(self)
  def ungetbyte(b) = Intrinsics.io_ungetbyte(self, b)
  def ungetc(s) = Intrinsics.io_ungetc(self, s)
  def sysread(len, buf = nil) = Intrinsics.io_sysread(self, len, buf)
  def syswrite(str) = Intrinsics.io_syswrite(self, str)
  def seek(offset, whence = SEEK_SET) = Intrinsics.io_seek(self, offset, whence)
  def read_nonblock(len, buf = nil, exception: true) = nil
  def readpartial(len, buf = nil) = nil
  def each_line(sep = $/, &block) = Intrinsics.io_each_line(self, sep, block)
  def each_byte(&block) = Intrinsics.io_each_byte(self, block)
  def each_char(&block) = Intrinsics.io_each_char(self, block)
  def each(sep = $/, &block)      = each_line(sep, &block)
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

  def self.pipe(ext_enc = nil, int_enc = nil, **opts, &block)
    pair = Intrinsics.io_pipe(ext_enc, int_enc)
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

  def self.popen(cmd, mode = 'r', **opts, &block)
    opts_arg = opts.empty? ? nil : opts
    io = Intrinsics.io_popen(cmd, mode, opts_arg)
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
    Intrinsics.io_sysopen(path, mode, perm)
  end

  def self.new(fd, mode_or_opts = nil, **opts, &block)
    warn "warning: IO::new() does not take block; use IO::open() instead" if block
    opts_arg = opts.empty? ? nil : opts
    Intrinsics.io_new_from_fd(fd, mode_or_opts, opts_arg)
  end

  def self.for_fd(fd, mode = 'r', **opts, &block)
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

  def self.foreach(path, sep = $/, &block)
    open(path, 'r') do |f|
      f.each_line(sep, &block)
    end
  end

  def self.read(path, length = nil, offset = nil, **opts)
    path = if path.respond_to?(:to_path)
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

  def self.readlines(path, sep = $/, **opts)
    open(path, 'r') do |f|
      f.readlines(sep)
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

  def self.binwrite(path, content, offset = nil)
    open(path, 'wb') do |f|
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
    mode_int = if mode.is_a?(Integer)
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

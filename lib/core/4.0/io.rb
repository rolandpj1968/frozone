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
        elsif arg.respond_to?(:to_ary)
          ary = arg.to_ary
          ary.is_a?(Array) ? __puts_array__(ary) : __puts_scalar__(arg)
        else
          __puts_scalar__(arg)
        end
      end
    end
    nil
  end

  def __puts_array__(arr)
    arr.each { |elem| puts(elem) }
  end
  private :__puts_array__

  def __puts_scalar__(arg)
    str = arg.to_s
    str = "#<\#{arg.class}:0x\#{arg.__id__.to_s(16)}>" unless str.is_a?(String)
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
  def closed? = Intrinsics.io_closed?(self)
  def fileno = Intrinsics.io_fileno(self)
  def eof? = Intrinsics.io_eof?(self)
  def eof = eof?
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
  def gets(sep = $/, limit = nil) = Intrinsics.io_gets(self, sep, limit)
  def readline(sep = $/) = Intrinsics.io_readline(self, sep)
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
  def putc(c) = (write(c.is_a?(Integer) ? c.chr : c.to_s[0]); c)
  def flock(lock_op) = Intrinsics.io_flock(self, lock_op)
  def advise(advice, offset = 0, len = 0) = nil
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

  def self.popen(cmd, mode = 'r', **opts, &block)
    output = Intrinsics.io_popen_capture(cmd, opts)
    io = CapturedOutput.new(output)
    if block
      result = block.call(io)
      io.close
      result
    else
      io
    end
  end

  def self.sysopen(path, mode = 'r', perm = 0666)
    Intrinsics.io_sysopen(path, mode, perm)
  end

  def self.new(fd, mode_or_opts = nil, **opts, &block)
    opts_arg = opts.empty? ? nil : opts
    io = Intrinsics.io_new_from_fd(fd, mode_or_opts, opts_arg)
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

  def self.for_fd(fd, mode = 'r', **opts, &block)
    self.new(fd, mode, **opts, &block)
  end

  def self.open(fd_or_path, mode = 'r', **opts, &block)
    if fd_or_path.is_a?(Integer)
      self.new(fd_or_path, mode, **opts, &block)
    else
      # Fall through to File.open equivalent for path-based open
      fd = self.sysopen(fd_or_path, mode)
      io = self.new(fd, mode, **opts)
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
  end

  def self.foreach(path, sep = $/, &block)
    open(path, 'r') do |f|
      f.each_line(sep, &block)
    end
  end

  def self.read(path, length = nil, offset = nil, **opts)
    open(path, opts[:mode] || 'r') do |f|
      f.seek(offset) if offset
      length ? f.read(length) : f.read
    end
  end

  def self.readlines(path, sep = $/, **opts)
    open(path, 'r') do |f|
      f.readlines(sep)
    end
  end

  def self.write(path, content, offset = nil, **opts)
    mode = opts[:mode] || 'w'
    open(path, mode) do |f|
      f.seek(offset) if offset
      f.write(content)
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

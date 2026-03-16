class IO
  # A read-only IO-like object backed by a captured string (used by IO.popen block form).
  class CapturedOutput
    def initialize(str)
      @str = str
    end

    def read(len = nil) = len ? @str[0, len] : @str
    def gets             = @str
    def close            = self
  end

  def self.popen(cmd, mode = 'r', &block)
    output = Intrinsics.io_popen_capture(cmd)
    io = CapturedOutput.new(output)
    if block
      result = block.call(io)
      io.close
      result
    else
      io
    end
  end

  def print(*args) = Intrinsics.io_print(self, args)
  def puts(*args)  = Intrinsics.io_puts(self, args)
  def write(*args) = Intrinsics.io_write(self, args)
  def flush        = Intrinsics.io_flush(self)
  def sync=(val)   = Intrinsics.io_sync_set(self, val)
  def sync         = true
  def <<(str); write(str); self; end
  def fileno       = 1
  def isatty       = false
  def tty?         = false
  def close        = self
  def closed?      = false
  def binmode      = self
  def set_encoding(*_) = self

  def external_encoding
    name = Intrinsics.io_external_encoding(self)
    # If native IO has an encoding (readable IOs like STDIN), track Encoding.default_external.
    # If native IO has no encoding (write-only IOs like STDOUT/STDERR), return nil.
    name.nil? ? nil : Encoding.default_external
  end

  def internal_encoding = nil
  def binmode?          = false
  def read_nonblock(len, buf = nil, exception: true) = nil
  def readpartial(len, buf = nil) = nil

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

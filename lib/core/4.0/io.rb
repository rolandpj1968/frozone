class IO
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
    name.nil? ? nil : Encoding.find(name)
  end

  def internal_encoding = nil
  def binmode?          = false
  def read_nonblock(len, buf = nil, exception: true) = nil
  def readpartial(len, buf = nil) = nil
end

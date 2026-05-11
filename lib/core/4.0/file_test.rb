module FileTest
  # Bypass -- meta-programming form (DELEGATED.each { define_method ... } +
  # module_function(*DELEGATED)) is currently O(N2)-feeling under the
  # box-first interpreter due to dispatch overhead from Module/Class fusion.
  # Explicit defs keep the same behaviour and are trivial to interpret.
  module_function

  def blockdev?(*args)        = File.blockdev?(*args)
  def chardev?(*args)         = File.chardev?(*args)
  def directory?(*args)       = File.directory?(*args)
  def executable?(*args)      = File.executable?(*args)
  def executable_real?(*args) = File.executable_real?(*args)
  def exist?(*args)           = File.exist?(*args)
  def file?(*args)            = File.file?(*args)
  def grpowned?(*args)        = File.grpowned?(*args)
  def identical?(*args)       = File.identical?(*args)
  def owned?(*args)           = File.owned?(*args)
  def pipe?(*args)            = File.pipe?(*args)
  def readable?(*args)        = File.readable?(*args)
  def readable_real?(*args)   = File.readable_real?(*args)
  def setgid?(*args)          = File.setgid?(*args)
  def setuid?(*args)          = File.setuid?(*args)
  def size(*args)             = File.size(*args)
  def size?(*args)            = File.size?(*args)
  def socket?(*args)          = File.socket?(*args)
  def sticky?(*args)          = File.sticky?(*args)
  def symlink?(*args)         = File.symlink?(*args)
  def world_readable?(*args)  = File.world_readable?(*args)
  def world_writable?(*args)  = File.world_writable?(*args)
  def writable?(*args)        = File.writable?(*args)
  def writable_real?(*args)   = File.writable_real?(*args)
  def zero?(*args)            = File.zero?(*args)
end

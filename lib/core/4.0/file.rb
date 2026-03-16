class File
  SEPARATOR     = '/'
  ALT_SEPARATOR = nil
  PATH_SEPARATOR = ':'

  def self.join(*parts)        = Intrinsics.file_join(parts)
  def self.dirname(path)       = Intrinsics.file_dirname(path)
  def self.basename(path, suffix = nil) = Intrinsics.file_basename(path, suffix)
  def self.expand_path(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.exist?(path)        = Intrinsics.file_exist(path)
  def self.exists?(path)       = Intrinsics.file_exist(path)
  def self.directory?(path)    = Intrinsics.file_directory(path)
  def self.file?(path)         = Intrinsics.file_file(path)
  def self.readable?(path)     = Intrinsics.file_readable(path)
  def self.executable?(path)   = Intrinsics.file_executable(path)
  def self.writable?(path)     = Intrinsics.file_writable(path)
  def self.size(path)          = Intrinsics.file_size(path)
  def self.size?(path)         = Intrinsics.file_size(path)
  def self.read(path, length = nil, offset = nil, **opts) = Intrinsics.file_read(path)
  def self.realpath(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.split(path)         = Intrinsics.file_split(path)
  def self.write(path, content, **opts) = Intrinsics.file_write(path, content)
  def self.open(path, mode = 'r', &block) = Intrinsics.file_open(path, mode, block)
  def self.delete(*paths)      = Intrinsics.file_delete(paths)
  def self.unlink(*paths)      = Intrinsics.file_delete(paths)
  def self.rename(from, to)    = Intrinsics.file_rename(from, to)
  def self.symlink?(path)      = Intrinsics.file_symlink(path)
  def self.symlink(target, link) = Intrinsics.file_symlink_create(target, link)
  def self.zero?(path)         = Intrinsics.file_zero(path)
  def self.absolute_path(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.chmod(mode, *paths) = nil
  def self.stat(path)          = Intrinsics.file_stat(path)
  def self.lstat(path)         = Intrinsics.file_stat(path)
  def self.binread(path, length = nil, offset = nil) = Intrinsics.file_read(path)
  def self.binwrite(path, content, offset = nil) = Intrinsics.file_write(path, content)
  def self.fnmatch(pattern, path, flags = 0)  = Intrinsics.file_fnmatch(pattern, path, flags)
  def self.fnmatch?(pattern, path, flags = 0) = Intrinsics.file_fnmatch(pattern, path, flags)
end

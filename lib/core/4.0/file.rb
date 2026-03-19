class File
  SEPARATOR     = '/'
  Separator      = '/'
  ALT_SEPARATOR = nil
  PATH_SEPARATOR = ':'

  # File open/lock/fnmatch mode constants
  RDONLY    = 0
  WRONLY    = 1
  RDWR      = 2
  APPEND    = 1024
  CREAT     = 64
  EXCL      = 128
  TRUNC     = 512
  NONBLOCK  = 2048
  NOCTTY    = 256
  SYNC      = 1052672
  SHARE_DELETE = 0

  LOCK_SH   = 1
  LOCK_EX   = 2
  LOCK_NB   = 4
  LOCK_UN   = 8

  FNM_NOESCAPE = 1
  FNM_PATHNAME = 2
  FNM_DOTMATCH = 4
  FNM_CASEFOLD = 8
  FNM_SYSCASE  = 0
  FNM_EXTGLOB  = 16

  module Constants
    RDONLY    = File::RDONLY
    WRONLY    = File::WRONLY
    RDWR      = File::RDWR
    APPEND    = File::APPEND
    CREAT     = File::CREAT
    EXCL      = File::EXCL
    TRUNC     = File::TRUNC
    NONBLOCK  = File::NONBLOCK
    NOCTTY    = File::NOCTTY
    SYNC      = File::SYNC
    SHARE_DELETE = File::SHARE_DELETE
    LOCK_SH   = File::LOCK_SH
    LOCK_EX   = File::LOCK_EX
    LOCK_NB   = File::LOCK_NB
    LOCK_UN   = File::LOCK_UN
    FNM_NOESCAPE = File::FNM_NOESCAPE
    FNM_PATHNAME = File::FNM_PATHNAME
    FNM_DOTMATCH = File::FNM_DOTMATCH
    FNM_CASEFOLD = File::FNM_CASEFOLD
    FNM_SYSCASE  = File::FNM_SYSCASE
    FNM_EXTGLOB  = File::FNM_EXTGLOB
  end

  # Coerce path argument: try to_path first, then to_str, then to_s for String
  def self._coerce_path(arg)
    return arg if arg.is_a?(String)
    if arg.respond_to?(:to_path)
      r = arg.to_path
      return r if r.is_a?(String)
      raise TypeError, "no implicit conversion of #{arg.class} into String"
    end
    if arg.respond_to?(:to_str)
      r = arg.to_str
      return r if r.is_a?(String)
      raise TypeError, "no implicit conversion of #{arg.class} into String"
    end
    raise TypeError, "no implicit conversion of #{arg.class} into String"
  end

  def self.join(*parts)        = Intrinsics.file_join(parts)
  def self.dirname(path, level = 1) = Intrinsics.file_dirname(_coerce_path(path), level)
  def self.basename(path, suffix = nil)
    p = _coerce_path(path)
    suffix.nil? ? Intrinsics.file_basename(p, nil) : Intrinsics.file_basename(p, suffix)
  end

  def self.expand_path(path, base = nil) = Intrinsics.file_expand_path(_coerce_path(path), base)
  def self.absolute_path(path, base = nil) = Intrinsics.file_absolute_path(_coerce_path(path), base)
  def self.absolute_path?(path) = Intrinsics.file_absolute_path_q(_coerce_path(path))

  def self.exist?(path)        = Intrinsics.file_exist(_coerce_path(path))
  def self.exists?(path)       = Intrinsics.file_exist(_coerce_path(path))
  def self.directory?(path)    = Intrinsics.file_directory(_coerce_path(path))
  def self.file?(path)         = Intrinsics.file_file(_coerce_path(path))
  def self.readable?(path)     = Intrinsics.file_readable(_coerce_path(path))
  def self.readable_real?(path) = Intrinsics.file_readable_real(_coerce_path(path))
  def self.executable?(path)   = Intrinsics.file_executable(_coerce_path(path))
  def self.executable_real?(path) = Intrinsics.file_executable_real(_coerce_path(path))
  def self.writable?(path)     = Intrinsics.file_writable(_coerce_path(path))
  def self.writable_real?(path) = Intrinsics.file_writable_real(_coerce_path(path))
  def self.owned?(path)        = Intrinsics.file_owned(_coerce_path(path))
  def self.grpowned?(path)     = Intrinsics.file_grpowned(_coerce_path(path))
  def self.size(path)          = Intrinsics.file_size_exact(_coerce_path(path))
  def self.size?(path)         = Intrinsics.file_size(_coerce_path(path))
  def self.zero?(path)         = Intrinsics.file_zero(_coerce_path(path))
  def self.empty?(path)        = Intrinsics.file_zero(_coerce_path(path))
  def self.symlink?(path)      = Intrinsics.file_symlink(_coerce_path(path))
  def self.blockdev?(path)     = Intrinsics.file_blockdev(_coerce_path(path))
  def self.chardev?(path)      = Intrinsics.file_chardev(_coerce_path(path))
  def self.pipe?(path)         = Intrinsics.file_pipe(_coerce_path(path))
  def self.socket?(path)       = Intrinsics.file_socket(_coerce_path(path))
  def self.setuid?(path)       = Intrinsics.file_setuid(_coerce_path(path))
  def self.setgid?(path)       = Intrinsics.file_setgid(_coerce_path(path))
  def self.sticky?(path)       = Intrinsics.file_sticky(_coerce_path(path))
  def self.identical?(a, b)    = Intrinsics.file_identical(_coerce_path(a), _coerce_path(b))
  def self.ftype(path)         = Intrinsics.file_ftype(_coerce_path(path))

  def self.atime(path)         = Intrinsics.file_atime(_coerce_path(path))
  def self.mtime(path)         = Intrinsics.file_mtime(_coerce_path(path))
  def self.ctime(path)         = Intrinsics.file_ctime(_coerce_path(path))
  def self.birthtime(path)     = Intrinsics.file_birthtime(_coerce_path(path))

  def self.read(path, length = nil, offset = nil, **opts) = Intrinsics.file_read(_coerce_path(path))
  def self.realpath(path, base = nil) = Intrinsics.file_realpath(_coerce_path(path), base)
  def self.realdirpath(path, base = nil) = Intrinsics.file_realdirpath(_coerce_path(path), base)
  def self.split(path)         = Intrinsics.file_split(_coerce_path(path))
  def self.write(path, content, **opts) = Intrinsics.file_write(_coerce_path(path), content)
  def self.open(path, mode = 'r', **opts, &block) = Intrinsics.file_open(_coerce_path(path), mode, block)
  def self.delete(*paths)      = Intrinsics.file_delete_strict(paths)
  def self.unlink(*paths)      = Intrinsics.file_delete_strict(paths)
  def self.rename(from, to)    = Intrinsics.file_rename(_coerce_path(from), _coerce_path(to))
  def self.symlink(target, link) = Intrinsics.file_symlink_create(_coerce_path(target), _coerce_path(link))
  def self.link(target, link)  = Intrinsics.file_link(_coerce_path(target), _coerce_path(link))
  def self.readlink(path)      = Intrinsics.file_readlink(_coerce_path(path))

  def self.truncate(path, length)
    raise TypeError, "no implicit conversion into String" unless path.is_a?(String) || path.respond_to?(:to_path) || path.respond_to?(:to_str)
    raise TypeError, "no implicit conversion into Integer" unless length.is_a?(Integer) || length.respond_to?(:to_int)
    Intrinsics.file_truncate(_coerce_path(path), length.is_a?(Integer) ? length : length.to_int)
  end

  def self.chmod(mode, *paths)
    mode_int = if mode.is_a?(Integer)
      mode
    elsif mode.respond_to?(:to_int)
      mode.to_int
    else
      raise TypeError, "no implicit conversion of #{mode.class} into Integer"
    end
    raise RangeError, "bignum too big to convert into 'long'" if mode_int > 2**32 || mode_int < -(2**31)
    coerced_paths = paths.map do |p|
      if p.is_a?(String)
        p
      elsif p.respond_to?(:to_path)
        p.to_path
      elsif p.respond_to?(:to_str)
        p.to_str
      else
        raise TypeError, "no implicit conversion of #{p.class} into String"
      end
    end
    Intrinsics.file_chmod(mode_int, coerced_paths)
  end

  def self.chown(uid, gid, *paths) = paths.length
  def self.lchown(uid, gid, *paths) = paths.length
  def self.lchmod(mode, *paths)    = paths.length

  def self.utime(atime, mtime, *paths)
    Intrinsics.file_utime(atime, mtime, paths)
  end

  def self.lutime(atime, mtime, *paths) = paths.length

  def self.stat(path)
    p = if path.is_a?(String)
      path
    elsif path.respond_to?(:to_path)
      path.to_path
    elsif path.respond_to?(:to_str)
      path.to_str
    else
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end
    Stat.new(p)
  end

  def self.lstat(path) = Stat.new(_coerce_path(path))
  def self.binread(path, length = nil, offset = nil) = Intrinsics.file_read(_coerce_path(path))
  def self.binwrite(path, content, offset = nil) = Intrinsics.file_write(_coerce_path(path), content)
  def self.fnmatch(pattern, path, flags = 0)  = Intrinsics.file_fnmatch(pattern, path, flags)
  def self.fnmatch?(pattern, path, flags = 0) = Intrinsics.file_fnmatch(pattern, path, flags)
  def self.mkfifo(path, mode = 0o666)         = Intrinsics.file_mkfifo(_coerce_path(path), mode)

  def self.world_readable?(path)
    begin
      mode = Intrinsics.file_stat_mode(_coerce_path(path))
      (mode & 0o004) != 0 ? mode & 0o777 : nil
    rescue
      nil
    end
  end

  def self.world_writable?(path)
    begin
      mode = Intrinsics.file_stat_mode(_coerce_path(path))
      (mode & 0o002) != 0 ? mode & 0o777 : nil
    rescue
      nil
    end
  end

  def self.umask(new_mask = nil) = Intrinsics.file_umask(new_mask)

  NULL = '/dev/null'

  class Stat
    include Comparable

    def initialize(path)
      @path = path
      @stat = Intrinsics.file_stat_native(path)
    end

    def <=>(other)
      return nil unless other.is_a?(Stat)
      mtime <=> other.mtime
    end

    def directory?    = File.directory?(@path)
    def file?         = File.file?(@path)
    def readable?     = File.readable?(@path)
    def readable_real? = File.readable_real?(@path)
    def writable?     = File.writable?(@path)
    def writable_real? = File.writable_real?(@path)
    def executable?   = File.executable?(@path)
    def executable_real? = File.executable_real?(@path)
    def symlink?      = File.symlink?(@path)
    def zero?         = File.zero?(@path)
    def empty?        = File.zero?(@path)
    def size          = File.size(@path)
    def owned?        = File.owned?(@path)
    def grpowned?     = File.grpowned?(@path)
    def pipe?         = File.pipe?(@path)
    def socket?       = File.socket?(@path)
    def blockdev?     = File.blockdev?(@path)
    def chardev?      = File.chardev?(@path)
    def setuid?       = File.setuid?(@path)
    def setgid?       = File.setgid?(@path)
    def sticky?       = File.sticky?(@path)
    def ftype         = File.ftype(@path)

    def atime         = File.atime(@path)
    def mtime         = File.mtime(@path)
    def ctime         = File.ctime(@path)
    def birthtime     = File.birthtime(@path)

    def mode          = Intrinsics.file_stat_mode(@path)
    def ino           = Intrinsics.file_stat_ino(@path)
    def nlink         = Intrinsics.file_stat_nlink(@path)
    def uid           = Intrinsics.file_stat_uid(@path)
    def gid           = Intrinsics.file_stat_gid(@path)
    def dev           = Intrinsics.file_stat_dev(@path)
    def rdev          = Intrinsics.file_stat_rdev(@path)
    def dev_major     = Intrinsics.file_stat_dev_major(@path)
    def dev_minor     = Intrinsics.file_stat_dev_minor(@path)
    def rdev_major    = Intrinsics.file_stat_rdev_major(@path)
    def rdev_minor    = Intrinsics.file_stat_rdev_minor(@path)
    def blocks        = Intrinsics.file_stat_blocks(@path)
    def blksize       = Intrinsics.file_stat_blksize(@path)

    def world_readable?
      mode = Intrinsics.file_stat_mode(@path)
      (mode & 0o004) != 0 ? mode & 0o777 : nil
    end

    def world_writable?
      mode = Intrinsics.file_stat_mode(@path)
      (mode & 0o002) != 0 ? mode & 0o777 : nil
    end

    def inspect
      "#<File::Stat dev=#{dev}, ino=#{ino}, mode=#{mode}, nlink=#{nlink}, uid=#{uid}, gid=#{gid}, size=#{size}, atime=#{atime}, mtime=#{mtime}, ctime=#{ctime}>"
    end
  end
end

module FileTest
  DELEGATED = %i[
    blockdev? chardev? directory? executable? executable_real?
    exist? file? grpowned? identical? owned? pipe? readable?
    readable_real? setgid? setuid? size size? socket? sticky?
    symlink? world_readable? world_writable? writable? writable_real? zero?
  ].freeze

  DELEGATED.each do |m|
    define_method(m) { |*args| File.send(m, *args) }
  end
  module_function(*DELEGATED)
end

class File < IO
  include Enumerable

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
  BINARY       = 0

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

  include File::Constants

  # IO should also directly include File::Constants (MRI: IO.include?(File::Constants) == true)
  IO.include File::Constants

  def self.expand_path(path, base = nil) = Intrinsics.file_expand_path(_coerce_path(path), base.nil? ? nil : _coerce_path(base))
  def self.absolute_path(path, base = nil) = Intrinsics.file_absolute_path(_coerce_path(path), base.nil? ? nil : _coerce_path(base))
  def self.absolute_path?(path) = Intrinsics.file_absolute_path_q(_coerce_path(path))
  def self.exist?(path) = Intrinsics.file_exist(_coerce_path(path))
  def self.exists?(path) = Intrinsics.file_exist(_coerce_path(path))
  def self.directory?(path) = Intrinsics.file_directory(_coerce_path(path))
  def self.file?(path) = Intrinsics.file_file(_coerce_path(path))
  def self.readable?(path) = Intrinsics.file_readable(_coerce_path(path))
  def self.readable_real?(path) = Intrinsics.file_readable_real(_coerce_path(path))
  def self.executable?(path) = Intrinsics.file_executable(_coerce_path(path))
  def self.executable_real?(path) = Intrinsics.file_executable_real(_coerce_path(path))
  def self.writable?(path) = Intrinsics.file_writable(_coerce_path(path))
  def self.writable_real?(path) = Intrinsics.file_writable_real(_coerce_path(path))
  def self.owned?(path) = Intrinsics.file_owned(_coerce_path(path))
  def self.grpowned?(path) = Intrinsics.file_grpowned(_coerce_path(path))
  def self.size(path) = Intrinsics.file_size_exact(_coerce_path(path))
  def self.size?(path) = Intrinsics.file_size(_coerce_path(path))
  def self.zero?(path) = Intrinsics.file_zero(_coerce_path(path))
  def self.empty?(path) = Intrinsics.file_zero(_coerce_path(path))
  def self.symlink?(path) = Intrinsics.file_symlink(_coerce_path(path))
  def self.blockdev?(path) = Intrinsics.file_blockdev(_coerce_path(path))
  def self.chardev?(path) = Intrinsics.file_chardev(_coerce_path(path))
  def self.pipe?(path) = Intrinsics.file_pipe(_coerce_path(path))
  def self.socket?(path) = Intrinsics.file_socket(_coerce_path(path))
  def self.setuid?(path) = Intrinsics.file_setuid(_coerce_path(path))
  def self.setgid?(path) = Intrinsics.file_setgid(_coerce_path(path))
  def self.sticky?(path) = Intrinsics.file_sticky(_coerce_path(path))
  def self.identical?(a, b) = Intrinsics.file_identical(_coerce_path(a), _coerce_path(b))
  def self.ftype(path) = Intrinsics.file_ftype(_coerce_path(path))
  def self.atime(path) = Intrinsics.file_atime(_coerce_path(path))
  def self.mtime(path) = Intrinsics.file_mtime(_coerce_path(path))
  def self.ctime(path) = Intrinsics.file_ctime(_coerce_path(path))
  def self.birthtime(path) = Intrinsics.file_birthtime(_coerce_path(path))
  def self.realpath(path, base = nil) = Intrinsics.file_realpath(_coerce_path(path), base)
  def self.realdirpath(path, base = nil) = Intrinsics.file_realdirpath(_coerce_path(path), base)
  def self.split(path) = Intrinsics.file_split(_coerce_path(path))
  def self.write(path, content, offset = nil, **opts)
    IO.write(_coerce_path(path), content, offset, **opts)
  end
  def self.delete(*paths) = Intrinsics.file_delete_strict(paths)
  def self.unlink(*paths) = Intrinsics.file_delete_strict(paths)
  def self.rename(from, to) = Intrinsics.file_rename(_coerce_path(from), _coerce_path(to))
  def self.symlink(target, link) = Intrinsics.file_symlink_create(_coerce_path(target), _coerce_path(link))
  def self.link(target, link) = Intrinsics.file_link(_coerce_path(target), _coerce_path(link))
  def self.readlink(path) = Intrinsics.file_readlink(_coerce_path(path))
  def self.lchown(uid, gid, *paths) = paths.length
  def self.lchmod(mode, *paths) = paths.length
  def self.lutime(atime, mtime, *paths) = Intrinsics.file_lutime(atime, mtime, paths.map { |p| _coerce_path(p) })
  def self.stat(path) = Stat.new(_coerce_path(path))
  def self.lstat(path) = Stat.new(_coerce_path(path), lstat: true)
  def self.binread(path, length = nil, offset = nil) = Intrinsics.file_binread(_coerce_path(path), length, offset)
  def self.binwrite(path, content, offset = nil) = Intrinsics.file_write(_coerce_path(path), content)
  def self.fnmatch?(pattern, path, flags = 0) = fnmatch(pattern, path, flags)
  def self.mkfifo(path, mode = 0o666)         = Intrinsics.file_mkfifo(_coerce_path(path), mode)
  def self.umask(new_mask = nil) = Intrinsics.file_umask(new_mask)
  def self.utime(atime, mtime, *paths) = Intrinsics.file_utime(atime, mtime, paths.map { |p| _coerce_path(p) })

  def self.join(*parts)
    return '' if parts.empty?
    segs = []
    _join_parts(parts, segs, [])
    return '' if segs.empty?
    result = +segs[0]  # dup to ensure a new string even for single-arg case
    segs[1..].each do |s|
      if s.start_with?('/')
        # Right side starts with slash(es): strip trailing slashes from left, keep right's leading slashes
        result.sub!(/\/+\z/, '')
        result += s
      elsif result.end_with?('/')
        # Left already ends with slash: just append right
        result += s
      else
        result += '/' + s
      end
    end
    result
  end

  def self.dirname(path, level = 1)
    l = level.is_a?(Integer) ? level : __coerce_to_int__(level)
    Intrinsics.file_dirname(_coerce_path(path), l)
  end

  def self.read(path, length = nil, offset = nil, **opts)
    mode = opts.delete(:mode)
    open_opts = opts
    if mode || !open_opts.empty?
      open_mode = mode || 'r'
      open(path, open_mode, **open_opts) do |f|
        f.seek(offset) if offset && offset != 0
        length ? f.read(length) : f.read
      end
    elsif length || (offset && offset != 0)
      open(path, 'r') do |f|
        f.seek(offset) if offset && offset != 0
        length ? f.read(length) : f.read
      end
    else
      Intrinsics.file_read(_coerce_path(path))
    end
  end

  def self.open(path, mode = nil, perm = 0o666, **opts, &block)
    mode = opts.delete(:mode) || mode || 'r'
    raise ArgumentError, "newline decorator with binary mode" if opts[:newline] && mode.to_s.include?('b')
    mode = __mode_with_encoding__(mode, opts)
    if path.is_a?(Integer)
      io = Intrinsics.file_new_from_fd(path, mode, opts.empty? ? nil : opts)
      if block
        begin
          block.call(io)
        ensure
          io.close rescue nil
        end
      else
        io
      end
    else
      flags = opts[:flags]
      extra_opts = {}
      extra_opts[:newline] = opts[:newline] if opts[:newline]
      Intrinsics.file_open(_coerce_path(path), mode, block, perm, flags, extra_opts.empty? ? nil : extra_opts)
    end
  end

  def self.new(path, mode = nil, perm = 0o666, **opts, &block)
    if block_given?
      Intrinsics.kernel_deprecation_warn(self, "File::new() does not take block; use File::open() instead")
    end
    mode = opts.delete(:mode) || mode || 'r'
    mode = __mode_with_encoding__(mode, opts)
    if path.is_a?(Integer)
      Intrinsics.file_new_from_fd(path, mode, opts.empty? ? nil : opts)
    else
      flags = opts[:flags]
      Intrinsics.file_open(_coerce_path(path), mode, nil, perm, flags)
    end
  end

  def self.__mode_with_encoding__(mode, opts)
    mode_str = mode.is_a?(Integer) ? mode : mode.to_s
    return mode_str if mode.is_a?(Integer)
    # Apply binmode: true by inserting 'b' after the access character if not already present
    if opts[:binmode] && !mode_str.include?('b')
      # Insert 'b' after the first mode char (e.g. 'w' → 'wb', 'r+' → 'rb+')
      # Handle both 'rw+' form and encoding suffix: insert before ':' if present
      colon_idx = mode_str.index(':')
      base = colon_idx ? mode_str[0, colon_idx] : mode_str
      enc_suffix = colon_idx ? mode_str[colon_idx..] : ''
      # Insert 'b' after the first char (r/w/a) and before any + or other flags
      base = base[0] + 'b' + base[1..]
      mode_str = base + enc_suffix
    end
    return mode_str if mode_str.include?(':')
    if (enc = opts[:encoding])
      mode_str + ':' + enc.to_s
    elsif (ext = opts[:external_encoding])
      int_enc = opts[:internal_encoding]
      mode_str + ':' + ext.to_s + (int_enc ? ':' + int_enc.to_s : '')
    else
      mode_str
    end
  end
  private_class_method :__mode_with_encoding__

  def self.chown(uid, gid, *paths)
    paths.each { |p| raise Errno::ENOENT, _coerce_path(p) unless exist?(_coerce_path(p)) }
    paths.length
  end

  def self.path(path)
    if path.is_a?(String)
      raise ArgumentError, "path name contains null byte" if path.include?("\0")
      path
    elsif path.respond_to?(:to_path)
      result = path.to_path
      raise TypeError, "no implicit conversion of #{path.class} into String" unless result.is_a?(String)
      raise ArgumentError, "path name contains null byte" if result.include?("\0")
      result
    elsif path.is_a?(IO)
      path.path
    else
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end
  end

  def self.extname(path)
    p = _coerce_path(path)
    base = File.basename(p)
    # Hidden files (starting with a dot) with no other dot have no extension.
    # All-dot names like '.', '..', '...' have no extension.
    # Edge cases: 'file' → '', '.hidden' → '', 'file.' → '.', 'file.rb' → '.rb'
    dot = base.rindex('.')
    return '' if dot.nil? || dot == 0
    return '' if base.chars.all? { |c| c == '.' }
    base[dot..]
  end

  def self.basename(path, suffix = nil)
    p = _coerce_path(path)
    suffix.nil? ? Intrinsics.file_basename(p, nil) : Intrinsics.file_basename(p, suffix)
  end

  def self.truncate(path, length) = Intrinsics.file_truncate(_coerce_path(path), __coerce_to_int__(length))

  def self.chmod(mode, *paths)
    mode_int = __coerce_to_int__(mode)
    raise RangeError, "bignum too big to convert into 'long'" if mode_int > UINT32_UPPER || mode_int < INT32_LOWER
    Intrinsics.file_chmod(mode_int, paths.map { |p| _coerce_path(p) })
  end

  def self.fnmatch(pattern, path, flags = 0) = Intrinsics.file_fnmatch(pattern, _coerce_path(path), __coerce_to_int__(flags))

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

  NULL = '/dev/null'

  class Stat
    include Comparable

    # Mode-based type predicates (correct for both stat and lstat)
    def file?      = (mode & 0o170000) == 0o100000
    def directory? = (mode & 0o170000) == 0o040000
    def symlink?   = (mode & 0o170000) == 0o120000
    def pipe?      = (mode & 0o170000) == 0o010000
    def socket?    = (mode & 0o170000) == 0o140000
    def blockdev?  = (mode & 0o170000) == 0o060000
    def chardev?   = (mode & 0o170000) == 0o020000
    def setuid?    = (mode & 0o004000) != 0
    def setgid?    = (mode & 0o002000) != 0
    def sticky?    = (mode & 0o001000) != 0
    def zero?      = size == 0
    def empty?     = size == 0
    def size?      = size == 0 ? nil : size
    def readable? = File.readable?(@path)
    def readable_real? = File.readable_real?(@path)
    def writable? = File.writable?(@path)
    def writable_real? = File.writable_real?(@path)
    def executable? = File.executable?(@path)
    def executable_real? = File.executable_real?(@path)
    def owned? = File.owned?(@path)
    def grpowned? = File.grpowned?(@path)
    def ctime = @native_stat ? Intrinsics.file_native_stat_time(@native_stat, :ctime) : File.ctime(@path)
    def birthtime = @native_stat ? Intrinsics.file_native_stat_time(@native_stat, :birthtime) : File.birthtime(@path)
    def size = @native_stat ? Intrinsics.file_native_stat_size(@native_stat) : File.size(@path)
    def mode = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :mode) :
                (@lstat ? Intrinsics.file_lstat_mode(@path) : Intrinsics.file_stat_mode(@path))
    def ino = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :ino) : Intrinsics.file_stat_ino(@path)
    def nlink = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :nlink) : Intrinsics.file_stat_nlink(@path)
    def uid = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :uid) : Intrinsics.file_stat_uid(@path)
    def gid = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :gid) : Intrinsics.file_stat_gid(@path)
    def dev = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :dev) : Intrinsics.file_stat_dev(@path)
    def rdev = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :rdev) : Intrinsics.file_stat_rdev(@path)
    def dev_major = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :dev_major) : Intrinsics.file_stat_dev_major(@path)
    def dev_minor = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :dev_minor) : Intrinsics.file_stat_dev_minor(@path)
    def rdev_major = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :rdev_major) : Intrinsics.file_stat_rdev_major(@path)
    def rdev_minor = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :rdev_minor) : Intrinsics.file_stat_rdev_minor(@path)
    def blocks = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :blocks) : Intrinsics.file_stat_blocks(@path)
    def blksize = @native_stat ? Intrinsics.file_native_stat_int(@native_stat, :blksize) : Intrinsics.file_stat_blksize(@path)
    def inspect = "#<File::Stat dev=0x#{dev.to_s(16)}, ino=#{ino}, mode=0#{mode.to_s(8)}, nlink=#{nlink}, uid=#{uid}, gid=#{gid}, rdev=0x#{rdev.to_s(16)}, size=#{size}, blksize=#{blksize}, blocks=#{blocks}, atime=#{atime.inspect}, mtime=#{mtime.inspect}, ctime=#{ctime.inspect}>"

    def atime
      return Intrinsics.file_lstat_atime(@path) if @lstat
      @native_stat ? Intrinsics.file_native_stat_time(@native_stat, :atime) : File.atime(@path)
    end

    def mtime
      return Intrinsics.file_lstat_mtime(@path) if @lstat
      @native_stat ? Intrinsics.file_native_stat_time(@native_stat, :mtime) : File.mtime(@path)
    end

    def ftype
      case mode & 0o170000
      when 0o100000 then 'file'
      when 0o040000 then 'directory'
      when 0o120000 then 'link'
      when 0o010000 then 'fifo'
      when 0o140000 then 'socket'
      when 0o060000 then 'blockSpecial'
      when 0o020000 then 'characterSpecial'
      else 'unknown'
      end
    end

    def initialize(path, lstat: false)
      @path = __coerce_to_path__(path)
      @lstat = lstat
      @stat = lstat ? Intrinsics.file_lstat_native(@path) : Intrinsics.file_stat_native(@path)
    end

    def <=>(other)
      return nil unless other.is_a?(Stat)
      mtime <=> other.mtime
    end

    def world_readable?
      m = mode
      (m & 0o004) != 0 ? m & 0o777 : nil
    end

    def world_writable?
      m = mode
      (m & 0o002) != 0 ? m & 0o777 : nil
    end
  end

  def chown(uid, gid) = 0
  def lstat = File::Stat.new(path, lstat: true)

  class << self
    private

    # Recursive helper for File.join — populates segs with string segments.
    # seen is an array used for cycle detection (identity comparison).
    def _join_parts(parts, segs, seen)
      parts.each do |p|
        if p.is_a?(String)
          raise ArgumentError, 'string contains null byte' if p.include?("\0")
          segs << p
        elsif p.is_a?(Array)
          raise ArgumentError, "recursive array" if seen.any? { |s| s.equal?(p) }
          seen.push(p)
          sub = []
          _join_parts(p, sub, seen)
          seen.pop
          if sub.empty?
            segs << ''
          else
            joined = sub[0]
            sub[1..].each do |s|
              if s.start_with?('/')
                joined = joined.sub(/\/+\z/, '') + s
              elsif joined.end_with?('/')
                joined += s
              else
                joined += '/' + s
              end
            end
            segs << joined
          end
        elsif p.respond_to?(:to_path)
          r = p.to_path
          raise TypeError, "no implicit conversion of #{p.class} into String" unless r.is_a?(String)
          segs << r
        elsif p.respond_to?(:to_str)
          r = p.to_str
          raise TypeError, "no implicit conversion of #{p.class} into String" unless r.is_a?(String)
          segs << r
        else
          raise TypeError, "no implicit conversion of #{p.class} into String"
        end
      end
    end

    # Coerce path argument: try to_path first, then to_str, then to_s for String
    def _coerce_path(arg)
      return arg if arg.is_a?(String)
      if !arg.respond_to?(:to_path) && arg.respond_to?(:to_io)
        arg = arg.to_io
      end
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
  end
end

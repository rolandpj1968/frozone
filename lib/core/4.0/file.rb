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

  NULL = '/dev/null'

  # stat-mode bit masks. POSIX values; mirrored in os_stat field layout.
  S_IFMT = 0o170000
  S_IFREG = 0o100000
  S_IFDIR = 0o040000
  S_IFLNK = 0o120000
  S_IFCHR = 0o020000
  S_IFBLK = 0o060000
  S_IFIFO = 0o010000
  S_IFSOCK = 0o140000
  S_ISUID = 0o004000
  S_ISGID = 0o002000
  S_ISVTX = 0o001000

  # access(2) mode bits
  R_OK = 4
  W_OK = 2
  X_OK = 1

  # os_stat field indices — mirrors stat_array in file_intrinsics.hpp.
  OS_STAT_MODE = 0
  OS_STAT_SIZE = 1
  OS_STAT_UID = 2
  OS_STAT_GID = 3
  OS_STAT_DEV = 4
  OS_STAT_INO = 5
  OS_STAT_NLINK = 6
  OS_STAT_RDEV = 7
  OS_STAT_BLOCKS = 8
  OS_STAT_BLKSIZE = 9
  OS_STAT_ATIME_SEC = 10
  OS_STAT_ATIME_NSEC = 11
  OS_STAT_MTIME_SEC = 12
  OS_STAT_MTIME_NSEC = 13
  OS_STAT_CTIME_SEC = 14
  OS_STAT_CTIME_NSEC = 15

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
    def mode    = @stat[OS_STAT_MODE]
    def size    = @stat[OS_STAT_SIZE]
    def uid     = @stat[OS_STAT_UID]
    def gid     = @stat[OS_STAT_GID]
    def dev     = @stat[OS_STAT_DEV]
    def ino     = @stat[OS_STAT_INO]
    def nlink   = @stat[OS_STAT_NLINK]
    def rdev    = @stat[OS_STAT_RDEV]
    def blocks  = @stat[OS_STAT_BLOCKS]
    def blksize = @stat[OS_STAT_BLKSIZE]
    def atime   = Intrinsics.time_make(@stat[OS_STAT_ATIME_SEC], @stat[OS_STAT_ATIME_NSEC], 0, false)
    def mtime   = Intrinsics.time_make(@stat[OS_STAT_MTIME_SEC], @stat[OS_STAT_MTIME_NSEC], 0, false)
    def ctime   = Intrinsics.time_make(@stat[OS_STAT_CTIME_SEC], @stat[OS_STAT_CTIME_NSEC], 0, false)
    # glibc-style major/minor: dev encoded as (major << 8) | minor for legacy devices;
    # the modern encoding uses (major << 8) | (minor & 0xff) | ((minor & ~0xff) << 12).
    # The simple bit split below matches MRI on Linux for typical fs devices.
    def dev_major  = (dev >> 8) & 0xfff
    def dev_minor  = (dev & 0xff) | ((dev >> 12) & ~0xff)
    def rdev_major = (rdev >> 8) & 0xfff
    def rdev_minor = (rdev & 0xff) | ((rdev >> 12) & ~0xff)
    def birthtime  = raise NotImplementedError, "File::Stat#birthtime — needs statx"
    def inspect = "#<File::Stat dev=0x#{dev.to_s(16)}, ino=#{ino}, mode=0#{mode.to_s(8)}, nlink=#{nlink}, uid=#{uid}, gid=#{gid}, rdev=0x#{rdev.to_s(16)}, size=#{size}, blksize=#{blksize}, blocks=#{blocks}, atime=#{atime.inspect}, mtime=#{mtime.inspect}, ctime=#{ctime.inspect}>"

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
      @stat = lstat ? Intrinsics.os_lstat(@path) : Intrinsics.os_stat(@path)
      raise Errno::ENOENT, @path if @stat.nil?
    end

    # IO#stat — tuple read from os_fstat on a live fd; no path.
    def self.__from_tuple__(tuple)
      s = allocate
      s.__init_from_tuple__(tuple)
      s
    end

    def __init_from_tuple__(tuple)
      @path = nil
      @lstat = false
      @stat = tuple
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

  class << self
    def exist?(path) = !Intrinsics.os_stat(_coerce_path(path)).nil?
    def exists?(path) = exist?(path)
    def directory?(path) = __stat_type?(path, S_IFDIR)
    def file?(path) = __stat_type?(path, S_IFREG)
    def chardev?(path) = __stat_type?(path, S_IFCHR)
    def blockdev?(path) = __stat_type?(path, S_IFBLK)
    def pipe?(path) = __stat_type?(path, S_IFIFO)
    def socket?(path) = __stat_type?(path, S_IFSOCK)
    def symlink?(path) = (st = Intrinsics.os_lstat(_coerce_path(path))) && (st[OS_STAT_MODE] & S_IFMT) == S_IFLNK || false
    def setuid?(path) = __stat_bit?(path, S_ISUID)
    def setgid?(path) = __stat_bit?(path, S_ISGID)
    def sticky?(path) = __stat_bit?(path, S_ISVTX)
    def size?(path) = (st = Intrinsics.os_stat(_coerce_path(path))) && st[OS_STAT_SIZE] > 0 ? st[OS_STAT_SIZE] : nil
    def zero?(path) = (st = Intrinsics.os_stat(_coerce_path(path))) && st[OS_STAT_SIZE] == 0 || false
    def empty?(path) = zero?(path)
    def owned?(path) = (st = Intrinsics.os_stat(_coerce_path(path))) && st[OS_STAT_UID] == Intrinsics.os_euid || false
    def grpowned?(path) = (st = Intrinsics.os_stat(_coerce_path(path))) && st[OS_STAT_GID] == Intrinsics.os_egid || false
    def readable?(path) = Intrinsics.os_access(_coerce_path(path), R_OK)
    def readable_real?(path) = Intrinsics.os_access(_coerce_path(path), R_OK)
    def writable?(path) = Intrinsics.os_access(_coerce_path(path), W_OK)
    def writable_real?(path) = Intrinsics.os_access(_coerce_path(path), W_OK)
    def executable?(path) = Intrinsics.os_access(_coerce_path(path), X_OK)
    def executable_real?(path) = Intrinsics.os_access(_coerce_path(path), X_OK)
    def split(path) = [dirname(_coerce_path(path)), basename(_coerce_path(path))]
    def absolute_path(path, base = nil) = expand_path(path, base)
    def absolute_path?(path) = _coerce_path(path).start_with?('/')
    def ftype(path)     = File::Stat.new(_coerce_path(path), lstat: true).ftype
    def atime(path)     = File::Stat.new(_coerce_path(path)).atime
    def mtime(path)     = File::Stat.new(_coerce_path(path)).mtime
    def ctime(path)     = File::Stat.new(_coerce_path(path)).ctime
    def birthtime(path) = File::Stat.new(_coerce_path(path)).birthtime
    def delete(*paths)
      paths.each { |p| Intrinsics.os_unlink(_coerce_path(p)) || raise(Errno::ENOENT, _coerce_path(p)) }
      paths.length
    end
    def unlink(*paths) = delete(*paths)
    def rename(from, to) = Intrinsics.os_rename(_coerce_path(from), _coerce_path(to)) ? 0 : raise(Errno::ENOENT, "#{from} → #{to}")
    def symlink(target, link) = Intrinsics.os_symlink(_coerce_path(target), _coerce_path(link)) ? 0 : raise(Errno::EEXIST, link)
    def link(target, link) = Intrinsics.os_link(_coerce_path(target), _coerce_path(link)) ? 0 : raise(Errno::ENOENT, "#{target} → #{link}")
    def readlink(path) = Intrinsics.os_readlink(_coerce_path(path)) || raise(Errno::ENOENT, "No such file or directory @ rb_readlink - #{path}")
    def lchown(uid, gid, *paths) = paths.length
    def lchmod(mode, *paths) = paths.length
    def lutime(atime, mtime, *paths) = _utimes(atime, mtime, paths, false)
    def stat(path) = Stat.new(_coerce_path(path))
    def lstat(path) = Stat.new(_coerce_path(path), lstat: true)
    def binread(path, length = nil, offset = nil) = Intrinsics.file_binread(_coerce_path(path), length, offset)
    def binwrite(path, content, offset = nil) = Intrinsics.file_write(_coerce_path(path), content)
    def fnmatch?(pattern, path, flags = 0) = fnmatch(pattern, path, flags)
    def mkfifo(path, mode = 0o666) = Intrinsics.os_mkfifo(_coerce_path(path), mode) ? 0 : raise(Errno::EEXIST, path)
    def umask(new_mask = nil) = Intrinsics.os_umask(new_mask.nil? ? nil : __coerce_to_int__(new_mask))
    def utime(atime, mtime, *paths) = _utimes(atime, mtime, paths, true)
    def truncate(path, length) = Intrinsics.os_truncate(_coerce_path(path), __coerce_to_int__(length)) ? 0 : raise(Errno::ENOENT, path)
    def fnmatch(pattern, path, flags = 0) = Intrinsics.os_fnmatch(pattern, _coerce_path(path), __coerce_to_int__(flags))
    def chmod(mode_int, *paths)
      mode = __coerce_to_int__(mode_int)
      paths.each { |p| Intrinsics.os_chmod(_coerce_path(p), mode) || raise(Errno::ENOENT, _coerce_path(p)) }
      paths.length
    end

    def size(path)
      st = Intrinsics.os_stat(_coerce_path(path))
      raise Errno::ENOENT, "No such file or directory @ rb_file_s_size - #{path}" unless st
      st[OS_STAT_SIZE]
    end

    def identical?(a, b)
      sa = Intrinsics.os_stat(_coerce_path(a))
      sb = Intrinsics.os_stat(_coerce_path(b))
      return false unless sa && sb
      sa[OS_STAT_DEV] == sb[OS_STAT_DEV] && sa[OS_STAT_INO] == sb[OS_STAT_INO]
    end

    def expand_path(path, base = nil)
      p = _coerce_path(path)
      p = ENV['HOME'] + p[1..] if p.start_with?('~/') || p == '~'
      unless p.start_with?('/')
        b = base.nil? ? Intrinsics.dir_pwd : _coerce_path(base)
        b = Intrinsics.dir_pwd + '/' + b unless b.start_with?('/')
        p = b + '/' + p
      end
      __normalize_path__(p)
    end

    def realpath(path, base = nil)
      p = expand_path(path, base)
      r = Intrinsics.os_realpath(p)
      raise Errno::ENOENT, "No such file or directory @ rb_file_s_realpath - #{path}" unless r
      r
    end

    def realdirpath(path, base = nil)
      p = expand_path(path, base)
      r = Intrinsics.os_realpath(p)
      r || p
    end

    def write(path, content, offset = nil, **opts)
      IO.write(_coerce_path(path), content, offset, **opts)
    end

    def join(*parts)
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

    def dirname(path, level = 1)
      l = level.is_a?(Integer) ? level : __coerce_to_int__(level)
      s = _coerce_path(path)
      while l > 0 && !s.empty?
        slash = s.rindex('/')
        if slash.nil?
          s = ''
          break
        elsif slash == 0
          s = '/'
          break
        else
          s = s[0, slash]
        end
        l -= 1
      end
      s.empty? ? '.' : s
    end

    def read(path, length = nil, offset = nil, **opts)
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

    def open(path, mode = nil, perm = 0o666, **opts, &block)
      io = new(path, mode, perm, **opts)
      return io unless block
      begin
        block.call(io)
      ensure
        io.close rescue nil
      end
    end

    def new(path, mode = nil, perm = 0o666, **opts, &block)
      if block_given?
        Intrinsics.kernel_deprecation_warn(self, "File::new() does not take block; use File::open() instead")
      end
      mode = opts.delete(:mode) || mode || 'r'
      raise ArgumentError, "newline decorator with binary mode" if opts[:newline] && mode.to_s.include?('b')
      mode = __mode_with_encoding__(mode, opts)
      fd = path.is_a?(Integer) ? path : IO.sysopen(_coerce_path(path), mode, perm)
      io = allocate
      io.send(:initialize, fd, mode)
      io
    end

    def chown(uid, gid, *paths)
      paths.each { |p| raise Errno::ENOENT, _coerce_path(p) unless exist?(_coerce_path(p)) }
      paths.length
    end

    def path(path)
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

    def extname(path)
      p = _coerce_path(path)
      base = File.basename(p)
      # Hidden files (starting with a dot) with no other dot have no extension.
      # All-dot names like '.', '..', '...' have no extension.
      # Edge cases: 'file' -> '', '.hidden' -> '', 'file.' -> '.', 'file.rb' -> '.rb'
      dot = base.rindex('.')
      return '' if dot.nil? || dot == 0
      return '' if base.chars.all? { |c| c == '.' }
      base[dot..]
    end

    def basename(path, suffix = nil)
      s = _coerce_path(path)
      slash = s.rindex('/')
      base = slash.nil? ? s : s[(slash + 1)..]
      return base if suffix.nil?
      sfx = _coerce_path(suffix)
      if sfx == '.*'
        dot = base.rindex('.')
        return base[0, dot] if dot && dot > 0
      elsif sfx.size < base.size && base.end_with?(sfx)
        return base[0, base.size - sfx.size]
      end
      base
    end

    def world_readable?(path)
      begin
        st = Intrinsics.os_stat(_coerce_path(path))
        mode = st && st[OS_STAT_MODE]
        (mode & 0o004) != 0 ? mode & 0o777 : nil
      rescue
        nil
      end
    end

    def world_writable?(path)
      begin
        st = Intrinsics.os_stat(_coerce_path(path))
        mode = st && st[OS_STAT_MODE]
        (mode & 0o002) != 0 ? mode & 0o777 : nil
      rescue
        nil
      end
    end

    private

    # Apply atime/mtime to each path via utimensat. follow=true follows
    # symlinks (utime); follow=false hits the link itself (lutime).
    def _utimes(atime, mtime, paths, follow)
      asec, ansec = _time_to_pair(atime)
      msec, mnsec = _time_to_pair(mtime)
      paths.each do |p|
        Intrinsics.os_utimes(_coerce_path(p), asec, ansec, msec, mnsec, follow) ||
          raise(Errno::ENOENT, _coerce_path(p))
      end
      paths.length
    end

    def _time_to_pair(t)
      case t
      when Time    then [t.to_i, t.nsec]
      when Integer then [t, 0]
      when Float   then [t.to_i, ((t - t.to_i) * 1_000_000_000).to_i]
      when nil     then n = Time.now; [n.to_i, n.nsec]
      else raise TypeError, "no implicit conversion of #{t.class} into Time"
      end
    end

    def __stat_type?(path, type_bits) = (st = Intrinsics.os_stat(_coerce_path(path))) && (st[OS_STAT_MODE] & S_IFMT) == type_bits || false
    def __stat_bit?(path, mask) = (st = Intrinsics.os_stat(_coerce_path(path))) && (st[OS_STAT_MODE] & mask) != 0 || false

    # Lexical normalisation: split on '/', skip '.', pop on '..'. Keeps
    # everything in plain Ruby; no realpath, no symlink follow.
    def __normalize_path__(path)
      absolute = path.start_with?('/')
      parts = []
      path.split('/').each do |seg|
        next if seg.empty? || seg == '.'
        if seg == '..'
          parts.pop if !parts.empty? && parts.last != '..'
          parts.push('..') if !absolute && (parts.empty? || parts.last == '..')
        else
          parts.push(seg)
        end
      end
      out = absolute ? '/' + parts.join('/') : parts.join('/')
      out = '.' if out.empty?
      out
    end

    # Recursive helper for File.join -- populates segs with string segments.
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

    def __mode_with_encoding__(mode, opts)
      mode_str = mode.is_a?(Integer) ? mode : mode.to_s
      return mode_str if mode.is_a?(Integer)
      # Apply binmode: true by inserting 'b' after the access character if not already present
      if opts[:binmode] && !mode_str.include?('b')
        # Insert 'b' after the first mode char (e.g. 'w' -> 'wb', 'r+' -> 'rb+')
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
  end

  def chown(uid, gid) = 0
  def lstat = File::Stat.new(path, lstat: true)
end

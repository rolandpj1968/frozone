class Dir
  include Enumerable

  def self.pwd = Intrinsics.dir_pwd
  def self.getwd = Intrinsics.dir_pwd
  def self.home(user = nil)       = Intrinsics.dir_home(user)
  def self.[](*patterns, base: nil, sort: true)
    pattern = patterns.length == 1 ? patterns[0] : patterns
    glob(pattern, 0, base: base, sort: sort)
  end
  def self.chdir(path = nil, &block) = Intrinsics.dir_chdir(path, block)
  def self.fchdir(fd, &block) = Intrinsics.dir_fchdir(fd, block)
  def self.mkdir(path, mode = 0o777)
    mode = mode.respond_to?(:to_int) ? mode.to_int : mode unless mode.is_a?(Integer)
    raise TypeError, "no implicit conversion of #{mode.class} into Integer" unless mode.is_a?(Integer)
    Intrinsics.dir_mkdir(_coerce_path(path), mode)
  end
  def self.mktmpdir(prefix = nil, &block) = Intrinsics.dir_mktmpdir(prefix, block)
  def self.delete(path) = Intrinsics.dir_rmdir(_coerce_path(path))
  def self.rmdir(path) = Intrinsics.dir_rmdir(_coerce_path(path))
  def self.unlink(path) = Intrinsics.dir_rmdir(_coerce_path(path))
  def path = @path
  def to_path = @path
  def inspect = "#<Dir:#{@path}>"
  def closed? = @closed

  def pos
    raise IOError, "closed directory" if @closed
    @pos
  end

  def tell
    raise IOError, "closed directory" if @closed
    @pos
  end
  def children = __load_entries__.reject { |e| e == '.' || e == '..' }
  def entries = __load_entries__.dup
  def chdir(&block) = Intrinsics.dir_chdir(@path, block)
  def fileno = Intrinsics.dir_fileno(@dir)

  def self.glob(pattern, flags = 0, base: nil, sort: true, &block)
    raise ArgumentError, "expected true or false as sort:" unless sort == true || sort == false
    results = Intrinsics.dir_glob(pattern, flags, base, sort)
    if block
      results.each { |p| block.call(p) }
      nil
    else
      results
    end
  end

  def self.exist?(path)
    p = if path.is_a?(String)
      path
    elsif path.respond_to?(:to_path)
      path.to_path
    elsif path.respond_to?(:to_str)
      path.to_str
    else
      return false
    end
    Intrinsics.dir_exist(p)
  end

  def self.entries(path, encoding: nil)
    p = _coerce_path(path)
    result = Intrinsics.dir_entries(p)
    if encoding
      enc = encoding.is_a?(Encoding) ? encoding : Encoding.find(encoding.to_s)
      result.map! { |e| e.force_encoding(enc) }
    end
    result
  end

  def self.children(path, encoding: nil)
    p = _coerce_path(path)
    entries(p, encoding: encoding).reject { |e| e == '.' || e == '..' }
  end

  def self.foreach(path, encoding: nil, &block)
    return to_enum(:foreach, path, encoding: encoding) unless block
    entries(path, encoding: encoding).each { |e| block.call(e) }
    nil
  end

  def self.each_child(path, encoding: nil, &block)
    return to_enum(:each_child, path, encoding: encoding) unless block
    children(path, encoding: encoding).each { |e| block.call(e) }
    nil
  end

  def self.empty?(path)
    p = _coerce_path(path)
    Intrinsics.dir_empty(p)
  end

  def self.chroot(path)
    p = _coerce_path(path)
    Intrinsics.dir_chroot(p)
  end

  def self.open(path, encoding: nil, &block)
    dir = new(path)
    if block
      begin
        block.call(dir)
      ensure
        dir.close rescue nil
      end
    else
      dir
    end
  end

  def self._coerce_path(arg)
    return arg if arg.is_a?(String)
    if arg.respond_to?(:to_path)
      r = arg.to_path
      return r if r.is_a?(String)
      raise TypeError, "no implicit conversion into String"
    end
    if arg.respond_to?(:to_str)
      r = arg.to_str
      return r if r.is_a?(String)
      raise TypeError, "no implicit conversion into String"
    end
    raise TypeError, "no implicit conversion of #{arg.class} into String"
  end

  def initialize(path, encoding: nil)
    @path = Dir._coerce_path(path)
    @encoding = encoding ? (encoding.is_a?(Encoding) ? encoding : Encoding.find(encoding.to_s)) : nil
    @dir = Intrinsics.dir_open(@path)
    @closed = false
    @entries = nil
    @pos = 0
  end

  def close
    return if @closed
    Intrinsics.dir_close(@dir)
    @closed = true
    nil
  end

  def pos=(n)
    @pos = n
    Intrinsics.dir_seek(@dir, n)
    n
  end

  def seek(n)
    self.pos = n
    self
  end

  def rewind
    @pos = 0
    Intrinsics.dir_rewind(@dir)
    self
  end

  def read
    entry = Intrinsics.dir_read(@dir)
    @pos += 1 if entry
    entry = entry.force_encoding(@encoding) if entry && @encoding
    entry
  end

  def each(&block)
    return to_enum(:each) unless block
    rewind
    while (entry = read)
      block.call(entry)
    end
    self
  end

  def each_child(&block)
    return to_enum(:each_child) unless block
    children.each { |e| block.call(e) }
    self
  end

  private

  def __load_entries__ = (@entries ||= Dir.entries(@path, encoding: @encoding))
end

class Dir
  include Enumerable

  def self.pwd                    = Intrinsics.dir_pwd
  def self.getwd                  = Intrinsics.dir_pwd

  def self.home(user = nil)       = Intrinsics.dir_home(user)

  def self.glob(pattern, flags = 0, base: nil, sort: true, &block)
    results = Intrinsics.dir_glob(pattern, flags, base, sort)
    if block
      results.each { |p| block.call(p) }
      nil
    else
      results
    end
  end

  def self.[](pattern) = glob(pattern)

  def self.chdir(path = nil, &block) = Intrinsics.dir_chdir(path, block)

  def self.mkdir(path, mode = 0o777) = Intrinsics.dir_mkdir(path, mode)

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

  def self.mktmpdir(prefix = nil, &block) = Intrinsics.dir_mktmpdir(prefix, block)

  def self.entries(path, encoding: nil)
    p = _coerce_path(path)
    Intrinsics.dir_entries(p)
  end

  def self.children(path, encoding: nil)
    p = _coerce_path(path)
    entries(p).reject { |e| e == '.' || e == '..' }
  end

  def self.foreach(path, encoding: nil, &block)
    entries(path).each { |e| block.call(e) }
  end

  def self.each_child(path, encoding: nil, &block)
    children(path).each { |e| block.call(e) }
  end

  def self.delete(path) = Intrinsics.dir_rmdir(_coerce_path(path))
  def self.rmdir(path)  = Intrinsics.dir_rmdir(_coerce_path(path))
  def self.unlink(path) = Intrinsics.dir_rmdir(_coerce_path(path))

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
    @path = if path.is_a?(String)
      path
    elsif path.respond_to?(:to_path)
      path.to_path
    elsif path.respond_to?(:to_str)
      path.to_str
    else
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end
    @dir = Intrinsics.dir_open(@path)
    @closed = false
    @entries = nil
    @pos = 0
  end

  def path = @path
  def to_path = @path

  def inspect = "#<Dir:#{@path}>"

  def close
    return if @closed
    Intrinsics.dir_close(@dir)
    @closed = true
    nil
  end

  def closed? = @closed

  def pos = @pos
  def tell = @pos

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
    entry
  end

  def each(&block)
    return to_enum(:each) unless block
    _load_entries.each { |e| block.call(e) }
    self
  end

  def children
    _load_entries.reject { |e| e == '.' || e == '..' }
  end

  def entries = _load_entries.dup

  def chdir(&block)
    Intrinsics.dir_chdir(@path, block)
  end

  def fileno = Intrinsics.dir_fileno(@dir)

  def _load_entries
    @entries ||= Dir.entries(@path)
  end

  private :_load_entries
end

class Dir
  include Enumerable

  class << self
    def pwd = Intrinsics.dir_pwd
    def getwd = Intrinsics.dir_pwd
    def home(user = nil) = Intrinsics.dir_home(user)
    def chdir(path = nil, &block) = Intrinsics.dir_chdir(path, block)
    def fchdir(fd, &block) = Intrinsics.dir_fchdir(fd, block)
    # mktmpdir: build a "/tmp/<prefix>XXXXXX" template, hand to mkdtemp(3),
    # then either return the path or yield to the block and clean up after.
    def mktmpdir(prefix = nil, &block)
      base = ENV['TMPDIR'] || '/tmp'
      pre = prefix.nil? ? '' : prefix.to_s
      path = Intrinsics.os_mkdtemp("#{base}/#{pre}XXXXXX")
      return path unless block
      begin
        block.call(path)
      ensure
        # Best-effort recursive cleanup. The path is freshly created and
        # owned by us; if rmdir fails because something's in there, the
        # caller's leftover is the surprise, not ours.
        _rm_rf(path) rescue nil
      end
    end

    # Tiny recursive rm — enough for mktmpdir cleanup. Uses entries + stat
    # to walk. Pure Ruby on top of what's already there.
    def _rm_rf(path)
      return unless File.exist?(path)
      if File.directory?(path) && !File.symlink?(path)
        entries(path).each do |e|
          next if e == '.' || e == '..'
          _rm_rf(File.join(path, e))
        end
        Intrinsics.dir_rmdir(path)
      else
        File.delete(path)
      end
    end
    private :_rm_rf
    def delete(path) = Intrinsics.dir_rmdir(__coerce_to_path__(path))
    def rmdir(path) = Intrinsics.dir_rmdir(__coerce_to_path__(path))
    def unlink(path) = Intrinsics.dir_rmdir(__coerce_to_path__(path))
    def empty?(path) = Intrinsics.dir_empty(__coerce_to_path__(path))
    def chroot(path) = Intrinsics.dir_chroot(__coerce_to_path__(path))
    def children(path, encoding: nil) = entries(__coerce_to_path__(path), encoding: encoding).reject { |e| e == '.' || e == '..' }
    def mkdir(path, mode = 0o777) = Intrinsics.dir_mkdir(__coerce_to_path__(path), __coerce_to_int__(mode))
    def [](*patterns, base: nil, sort: true) = glob(patterns.length == 1 ? patterns[0] : patterns, 0, base: base, sort: sort)

    def glob(pattern, flags = 0, base: nil, sort: true, &block)
      raise ArgumentError, "expected true or false as sort:" unless sort == true || sort == false
      results = Intrinsics.dir_glob(pattern, flags, base, sort)
      if block
        results.each { |p| block.call(p) }
        nil
      else
        results
      end
    end

    def exist?(path)
      p =
        if path.is_a?(String)
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

    def entries(path, encoding: nil)
      p = __coerce_to_path__(path)
      result = Intrinsics.dir_entries(p)
      if encoding
        enc = encoding.is_a?(Encoding) ? encoding : Encoding.find(encoding.to_s)
        result.map! { |e| e.force_encoding(enc) }
      end
      result
    end

    def foreach(path, encoding: nil, &block)
      return to_enum(:foreach, path, encoding: encoding) unless block
      entries(path, encoding: encoding).each { |e| block.call(e) }
      nil
    end

    def each_child(path, encoding: nil, &block)
      return to_enum(:each_child, path, encoding: encoding) unless block
      children(path, encoding: encoding).each { |e| block.call(e) }
      nil
    end

    def for_fd(fd)
      dir = allocate
      dir.instance_variable_set(:@path, nil)
      dir.instance_variable_set(:@encoding, nil)
      dir.instance_variable_set(:@dir, Intrinsics.dir_for_fd(fd))
      dir.instance_variable_set(:@closed, false)
      dir.instance_variable_set(:@entries, nil)
      dir.instance_variable_set(:@pos, 0)
      dir
    end

    def open(path, encoding: nil, &block)
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
  end

  def initialize(path, encoding: nil)
    @path = __coerce_to_path__(path)
    @encoding = encoding ? (encoding.is_a?(Encoding) ? encoding : Encoding.find(encoding.to_s)) : nil
    @dir = Intrinsics.dir_open(@path)
    @closed = false
    @entries = nil
    @pos = 0
  end

  def path = @path
  def to_path = @path
  def inspect = "#<Dir:#{@path}>"
  def closed? = @closed
  def children = __load_entries__.reject { |e| e == '.' || e == '..' }
  def entries = __load_entries__.dup
  def fileno = Intrinsics.dir_fileno(@dir)
  def chdir(&block) = Intrinsics.dir_fchdir(Intrinsics.dir_fileno(@dir), block)

  def pos
    raise IOError, "closed directory" if @closed
    @pos
  end

  alias tell pos

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

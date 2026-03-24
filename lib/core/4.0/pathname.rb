class Pathname
  def to_s = @path
  def to_str = @path
  def to_path = @path
  def inspect = "#<Pathname:#{@path}>"
  def ==(other) = other.is_a?(Pathname) ? @path == other.to_s : false
  alias eql? ==
  def hash = @path.hash
  def +(other) = Pathname.new(File.join(@path, other.to_s))
  def /(other) = self + other
  def cleanpath = Pathname.new(File.expand_path(@path).sub(/\A#{Dir.pwd}/, '.'))
  def realpath = Pathname.new(File.realpath(@path))
  def expand_path(base = nil) = Pathname.new(File.expand_path(@path, base&.to_s))
  def absolute? = File.absolute_path?(@path)
  def relative? = !absolute?
  def dirname = Pathname.new(File.dirname(@path))
  def basename(suffix = nil) = Pathname.new(suffix ? File.basename(@path, suffix) : File.basename(@path))
  def extname = File.extname(@path)
  def exist? = File.exist?(@path)
  def file? = File.file?(@path)
  def directory? = File.directory?(@path)
  def readable? = File.readable?(@path)
  def writable? = File.writable?(@path)
  def executable? = File.executable?(@path)
  def symlink? = File.symlink?(@path)
  def zero? = File.zero?(@path)
  def size = File.size(@path)
  def stat = File.stat(@path)
  def lstat = File.lstat(@path)
  def read = File.read(@path)
  def binread = File.binread(@path)
  def readlines = File.readlines(@path)
  def write(data) = File.write(@path, data)
  def binwrite(data) = File.binwrite(@path, data)
  def open(mode = 'r', **opts, &block) = File.open(@path, mode, **opts, &block)
  def each_line(&block) = File.foreach(@path, &block)
  def readlink = Pathname.new(File.readlink(@path))
  def unlink = File.unlink(@path)
  alias delete unlink
  def rename(target) = File.rename(@path, target.to_s)
  def chmod(mode) = File.chmod(mode, @path)
  def chown(owner, group) = File.chown(owner, group, @path)
  def split = [dirname, basename]
  def entries = Dir.entries(@path).map { |e| Pathname.new(e) }
  def each_child(with_directory = true, &block) = children(with_directory).each(&block)
  def glob(pattern, &block) = Dir.glob(File.join(@path, pattern)).map { |p| Pathname.new(p) }.tap { |r| r.each(&block) if block }
  def join(*args) = args.reduce(self) { |base, part| Pathname.new(File.join(base.to_s, part.to_s)) }
  def relative_path_from(base) = Pathname.new(File.expand_path(@path).delete_prefix(File.expand_path(base.to_s) + '/'))
  def sub(pattern, replacement = nil, &block) = replacement ? Pathname.new(@path.sub(pattern, replacement)) : Pathname.new(@path.sub(pattern, &block))

  def initialize(path)
    path = path.to_s if path.is_a?(Pathname)
    raise TypeError, "no implicit conversion of #{path.class} into String" unless path.is_a?(String)
    raise ArgumentError, "pathname contains null byte" if path.include?("\0")
    @path = path
  end

  def children(with_directory = true)
    entries.reject { |e| e.to_s == '.' || e.to_s == '..' }.map do |e|
      with_directory ? Pathname.new(File.join(@path, e.to_s)) : e
    end
  end

  def mkpath
    require 'fileutils'
    FileUtils.mkdir_p(@path)
    self
  end

  def rmtree
    require 'fileutils'
    FileUtils.rm_rf(@path)
    self
  end

  def ascend(&block)
    parts = @path.split('/')
    parts.length.downto(1) { |n| yield Pathname.new(parts[0, n].join('/')) }
  end

  def descend(&block)
    parts = @path.split('/')
    1.upto(parts.length) { |n| yield Pathname.new(parts[0, n].join('/')) }
  end
end

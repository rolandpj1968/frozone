class Pathname
  def to_s = @path
  def to_str = @path
  def to_path = @path
  def inspect = "#<Pathname:#{@path}>"
  def ==(other) = other.is_a?(Pathname) ? @path == other.to_s : false
  alias eql? ==
  def <=>(other) = other.is_a?(Pathname) ? @path <=> other.to_s : nil
  include Comparable
  def hash = @path.hash
  def realpath = Pathname.new(File.realpath(@path))
  def realdirpath(base = nil) = Pathname.new(File.realdirpath(@path, base&.to_s))
  def expand_path(base = nil) = Pathname.new(File.expand_path(@path, base&.to_s))
  def absolute? = File.absolute_path?(@path)
  def relative? = !absolute?
  def root? = (@path =~ /\A\/+\z/) ? true : false
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
  def sub(pattern, replacement = nil, &block) = replacement ? Pathname.new(@path.sub(pattern, replacement)) : Pathname.new(@path.sub(pattern, &block))
  def /(other) = self + other
  def parent = self + '..'

  def initialize(path)
    path = path.to_path if !path.is_a?(Pathname) && !path.is_a?(String) && path.respond_to?(:to_path)
    path = path.to_s if path.is_a?(Pathname)
    raise TypeError, "no implicit conversion of #{path.class} into String" unless path.is_a?(String)
    raise ArgumentError, "pathname contains null byte" if path.include?("\0")
    @path = path
  end

  def cleanpath
    abs = @path.start_with?('/')
    parts = @path.split('/')
    result = []
    parts.each do |part|
      if part == '' || part == '.'
        next
      elsif part == '..'
        if abs || (!result.empty? && result.last != '..')
          result.pop unless result.empty?
        else
          result << '..'
        end
      else
        result << part
      end
    end
    if abs
      Pathname.new('/' + result.join('/'))
    elsif result.empty?
      Pathname.new('.')
    else
      Pathname.new(result.join('/'))
    end
  end

  def +(other)
    other = Pathname.new(other.to_s) unless other.is_a?(Pathname)
    return other if other.absolute?
    Pathname.new(File.join(@path, other.to_s)).cleanpath
  end

  def join(*args)
    return self if args.empty?
    result = args.pop
    result = Pathname.new(result.to_s) unless result.is_a?(Pathname)
    return result if result.absolute?
    args.reverse_each do |arg|
      arg = Pathname.new(arg.to_s) unless arg.is_a?(Pathname)
      result = arg + result
      return result if result.absolute?
    end
    self + result
  end

  def glob(pattern, flags = 0, &block)
    results = Dir.glob(File.join(@path, pattern), flags).map { |p| Pathname.new(p) }
    if block
      results.each(&block)
      nil
    else
      results
    end
  end

  def relative_path_from(base)
    base = Pathname.new(base.to_s) unless base.is_a?(Pathname)
    dest = cleanpath
    base_clean = base.cleanpath

    dest_names = __path_components__(dest.to_s)
    base_names = __path_components__(base_clean.to_s)

    if (dest.absolute? ? 1 : 0) != (base_clean.absolute? ? 1 : 0)
      raise ArgumentError, "different prefix: #{dest.to_s.inspect} and #{base_clean.to_s.inspect}"
    end

    while !dest_names.empty? && !base_names.empty? && dest_names.first == base_names.first
      dest_names.shift
      base_names.shift
    end

    if base_names.include?('..')
      raise ArgumentError, "base has `..': #{base}"
    end

    names = (['..'] * base_names.length) + dest_names
    names.empty? ? Pathname.new('.') : Pathname.new(names.join('/'))
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

  def empty?
    if directory?
      Dir.empty?(@path)
    else
      File.zero?(@path)
    end
  end

  def self.pwd = Pathname.new(Dir.pwd)
  def self.getwd = pwd

  def self.glob(pattern, flags = 0, base: nil, sort: true, **rest)
    raise ArgumentError, "unknown keyword: #{rest.keys.map { |k| ":#{k}" }.join(', ')}" unless rest.empty?
    base_path = base ? base.to_s : nil
    opts = {}
    opts[:base] = base_path if base_path
    opts[:sort] = sort
    Dir.glob(pattern.to_s, flags, **opts).map { |p| Pathname.new(p) }
  end

  private

  def __path_components__(path)
    path = path.sub(/\A\//, '')
    return [] if path == '.' || path.empty?
    path.split('/')
  end
end

module Kernel
  module_function

  def Pathname(path)
    return path if path.is_a?(Pathname)
    Pathname.new(path)
  end
end

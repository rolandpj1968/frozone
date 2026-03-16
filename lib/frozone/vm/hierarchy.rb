module Kernel
end

class Object < BasicObject
  include Kernel
end

module Comparable
end

module Enumerable
end

class String < Object
  include Comparable
end

class Symbol < Object
  include Comparable
end

class Array < Object
  include Enumerable
end

class Hash < Object
  include Enumerable
end

class Numeric < Object
  include Comparable
end

class Integer < Numeric
end

class Float < Numeric
end

class Proc < Object
end

class Method < Object
end

class UnboundMethod < Object
end

class Binding < Object
end

class Range < Object
end

class Regexp < Object
end

class MatchData < Object
end

class Random < Object
end

class IO < Object
end

class File < IO
  SEPARATOR = '/'
  ALT_SEPARATOR = nil
  PATH_SEPARATOR = ':'

  def self.join(*parts) = Intrinsics.file_join(parts)
  def self.dirname(path) = Intrinsics.file_dirname(path)
  def self.basename(path, suffix = nil) = Intrinsics.file_basename(path, suffix)
  def self.expand_path(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.exist?(path) = Intrinsics.file_exist(path)
  def self.exists?(path) = Intrinsics.file_exist(path)
  def self.directory?(path) = Intrinsics.file_directory(path)
  def self.file?(path) = Intrinsics.file_file(path)
  def self.readable?(path) = Intrinsics.file_readable(path)
  def self.executable?(path) = Intrinsics.file_executable(path)
  def self.writable?(path) = Intrinsics.file_writable(path)
  def self.size(path) = Intrinsics.file_size(path)
  def self.size?(path) = Intrinsics.file_size(path)
  def self.read(path, length = nil, offset = nil, **opts) = Intrinsics.file_read(path)
  def self.realpath(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.split(path) = Intrinsics.file_split(path)
  def self.write(path, content, **opts) = Intrinsics.file_write(path, content)
  def self.open(path, mode = 'r', &block) = Intrinsics.file_open(path, mode, block)
  def self.delete(*paths) = Intrinsics.file_delete(paths)
  def self.unlink(*paths) = Intrinsics.file_delete(paths)
  def self.rename(from, to) = Intrinsics.file_rename(from, to)
  def self.symlink?(path) = Intrinsics.file_symlink(path)
  def self.symlink(target, link) = Intrinsics.file_symlink_create(target, link)
  def self.zero?(path) = Intrinsics.file_zero(path)
  def self.absolute_path(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.chmod(mode, *paths) = nil
  def self.stat(path) = Intrinsics.file_stat(path)
  def self.lstat(path) = Intrinsics.file_stat(path)

  def self.binread(path, length = nil, offset = nil) = Intrinsics.file_read(path)
  def self.binwrite(path, content, offset = nil) = Intrinsics.file_write(path, content)
  def self.fnmatch(pattern, path, flags = 0) = Intrinsics.file_fnmatch(pattern, path, flags)
  def self.fnmatch?(pattern, path, flags = 0) = Intrinsics.file_fnmatch(pattern, path, flags)
end

class Dir < Object
  def self.pwd = Intrinsics.dir_pwd
  def self.home = Intrinsics.dir_home
  def self.glob(pattern) = Intrinsics.dir_glob(pattern)
  def self.[](pattern) = self.glob(pattern)
  def self.chdir(path = nil, &block) = Intrinsics.dir_chdir(path, block)
  def self.mkdir(path, mode = 0o777) = Intrinsics.dir_mkdir(path)
  def self.exist?(path) = Intrinsics.dir_exist(path)
  def self.mktmpdir(prefix = nil, &block) = Intrinsics.dir_mktmpdir(prefix, block)
  def self.entries(path) = Intrinsics.dir_entries(path)
  def self.delete(path) = Intrinsics.dir_rmdir(path)
  def self.rmdir(path) = Intrinsics.dir_rmdir(path)
  def self.empty?(path) = Intrinsics.dir_empty(path)
end

class Encoding < Object
  UTF_8 = nil
  def self.find(name) = nil
end

class Process < Object
  def self.pid = Intrinsics.process_pid
  def self.euid = Intrinsics.process_euid
  def self.exit(code = true) = Kernel.exit(code)
  def self.exit!(code = false) = Intrinsics.kernel_exit(self, code)

  class Status < Object
    def exitstatus = Intrinsics.process_status_exitstatus(self)
    def success? = exitstatus == 0
    def pid = Intrinsics.process_status_pid(self)
    def to_i = exitstatus
    def to_s = "#<Process::Status: pid #{pid} exit #{exitstatus}>"
    def inspect = to_s
  end
end

class Exception < Object
  def initialize(msg = nil)
    @message = msg.nil? ? self.class.name : msg.to_s
  end
  def message = @message.nil? ? self.class.name : @message
  def to_s = message
  def inspect = "#<#{self.class.name}: #{message}>"
  def backtrace = @backtrace || []
  def exception(msg = nil) = msg ? self.class.new(msg) : self
  def set_backtrace(bt) = (@backtrace = bt)
end

class SystemExit < Exception
  def initialize(code = true, msg = nil)
    if code.is_a?(String)
      @status = 0
      super(code)
    else
      @status = code.is_a?(Integer) ? code : (code ? 0 : 1)
      super(msg || self.class.name)
    end
  end

  def status = @status
  def success? = @status == 0
end

class NoMemoryError < Exception
end

class SystemStackError < Exception
end

class ScriptError < Exception
end

class LoadError < ScriptError
end

class SyntaxError < ScriptError
end

class NotImplementedError < ScriptError
end

class SignalException < Exception
end

class Interrupt < SignalException
end

class SecurityError < Exception
end

class StandardError < Exception
end

class ArgumentError < StandardError
end

class EncodingError < StandardError
end

class FiberError < StandardError
end

class IOError < StandardError
end

class EOFError < IOError
end

class IndexError < StandardError
end

class KeyError < IndexError
end

class StopIteration < IndexError
end

class NameError < StandardError
  def receiver = @receiver
end

class NoMethodError < NameError
end

class RangeError < StandardError
end

class FloatDomainError < RangeError
end

class RegexpError < StandardError
end

class RuntimeError < StandardError
end

class FrozenError < RuntimeError
  def receiver = @receiver
end

class SystemCallError < StandardError
end

class ThreadError < StandardError
end

class TypeError < StandardError
end

class ZeroDivisionError < StandardError
end

class LocalJumpError < StandardError
end

class UncaughtThrowError < ArgumentError
end

class RangeError < StandardError
end

class FloatDomainError < RangeError
end

class IndexError < StandardError
end

class StopIteration < IndexError
end

class EncodingError < StandardError
end

class Time < Object
  def self.now = Intrinsics.time_now
  def -(other) = Intrinsics.time_minus(self, other)
  def +(other) = Intrinsics.time_plus(self, other)
  def to_f = Intrinsics.time_to_f(self)
  def to_i = Intrinsics.time_to_i(self)
  def to_s = Intrinsics.time_to_s(self)
end

class Thread < Object
  def self.report_on_exception=(val); nil; end  # stub
  def self.report_on_exception = false       # stub
  def self.pass; nil; end                        # no-op in single-threaded VM

  class Mutex < Object
    def initialize; @locked = false; end
    def lock; @locked = true; self; end
    def unlock; @locked = false; self; end
    def locked? = @locked
    def synchronize(&block); lock; begin; block.call; ensure; unlock; end; end
    def try_lock; !@locked && (@locked = true); end
  end

  # Single-threaded Thread: runs block immediately, isolating thread-local globals.
  # thread_run_block invokes the block with thread_boundary:true so that `break`
  # raises LocalJumpError (catchable inside the block) instead of propagating out.
  def initialize(&block)
    @result    = nil
    @exception = nil
    Intrinsics.thread_save_reset_locals(self)
    begin
      @result = Intrinsics.thread_run_block(block)
    rescue => e
      @exception = e
    ensure
      Intrinsics.thread_restore_locals(self)
    end
  end

  def join(timeout = nil) = self

  def value
    raise @exception if @exception
    @result
  end

  def status = false  # dead
  def alive? = false
end

class Fiber < Object
  def self.new(&block) = Intrinsics.fiber_new(self, block)
  def self.yield(*args) = Intrinsics.fiber_yield(self, args)
  def self.current = Intrinsics.fiber_current(self)
  def self.[](key) = Intrinsics.fiber_storage_get(self, key)
  def self.[]=(key, val) = Intrinsics.fiber_storage_set(self, key, val)

  def resume(*args) = Intrinsics.fiber_resume(self, args)
  def alive? = Intrinsics.fiber_alive(self)
end

class Mutex < Object
  def initialize; @locked = false; end
  def lock; @locked = true; self; end
  def unlock; @locked = false; self; end
  def locked? = @locked
  def owned? = @locked
  def synchronize(&block); lock; begin; block.call; ensure; unlock; end; end
  def try_lock; !@locked && (@locked = true); end
end

class STDOUT < IO
end

class STDERR < IO
end

class STDIN < IO
end

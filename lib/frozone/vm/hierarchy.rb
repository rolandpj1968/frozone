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

class Range < Object
end

class Regexp < Object
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
  def self.read(path) = Intrinsics.file_read(path)
  def self.realpath(path, base = nil) = Intrinsics.file_expand_path(path, base)
  def self.split(path) = Intrinsics.file_split(path)
end

class Dir < Object
  def self.pwd = Intrinsics.dir_pwd
  def self.home = Intrinsics.dir_home
  def self.glob(pattern) = Intrinsics.dir_glob(pattern)
  def self.[](pattern) = self.glob(pattern)
end

class Encoding < Object
  UTF_8 = nil
  def self.find(name) = nil
end

class Process < Object
  def self.pid = Intrinsics.process_pid
  def self.euid = Intrinsics.process_euid
end

class Exception < Object
end

class SystemExit < Exception
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
end

class SystemCallError < StandardError
end

class ThreadError < StandardError
end

class TypeError < StandardError
end

class ZeroDivisionError < StandardError
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
  def self.report_on_exception=(val) = nil  # stub
  def self.report_on_exception = false       # stub
end

class STDOUT < IO
end

class STDERR < IO
end

class STDIN < IO
end

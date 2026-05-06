# Stub for the etc C extension -- provides minimal Etc module for Frozone VM.
module Etc
  def self.getlogin = ENV['USER'] || ENV['LOGNAME'] || Intrinsics.process_uid.to_s
  def self.getpwuid(uid = Process.uid) = nil
  def self.getpwnam(name) = nil
  def self.getgrgid(gid = Process.gid) = nil
  def self.getgrnam(name) = nil
  def self.nprocessors = 1
  def self.sysconf(name) = nil
  def self.confstr(name) = nil
  def self.systmpdir = '/tmp'
end

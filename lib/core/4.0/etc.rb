# Stub for the etc C extension — provides minimal Etc module for Frozone VM.
module Etc
  def self.getlogin
    ENV['USER'] || ENV['LOGNAME'] || Intrinsics.process_uid.to_s
  end

  def self.getpwuid(uid = Process.uid)
    nil
  end

  def self.getpwnam(name)
    nil
  end

  def self.getgrgid(gid = Process.gid)
    nil
  end

  def self.getgrnam(name)
    nil
  end

  def self.nprocessors
    1
  end

  def self.sysconf(name)
    nil
  end

  def self.confstr(name)
    nil
  end
end

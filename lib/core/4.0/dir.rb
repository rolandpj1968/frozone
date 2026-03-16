class Dir
  def self.pwd                   = Intrinsics.dir_pwd
  def self.home                  = Intrinsics.dir_home
  def self.glob(pattern)         = Intrinsics.dir_glob(pattern)
  def self.[](pattern)           = glob(pattern)
  def self.chdir(path = nil, &block) = Intrinsics.dir_chdir(path, block)
  def self.mkdir(path, mode = 0o777) = Intrinsics.dir_mkdir(path)
  def self.exist?(path)          = Intrinsics.dir_exist(path)
  def self.mktmpdir(prefix = nil, &block) = Intrinsics.dir_mktmpdir(prefix, block)
  def self.entries(path)         = Intrinsics.dir_entries(path)
  def self.delete(path)          = Intrinsics.dir_rmdir(path)
  def self.rmdir(path)           = Intrinsics.dir_rmdir(path)
  def self.empty?(path)          = Intrinsics.dir_empty(path)
end

class Process
  def self.pid   = Intrinsics.process_pid
  def self.euid  = Intrinsics.process_euid
  def self.exit(code = true)  = Kernel.exit(code)
  def self.exit!(code = false) = Intrinsics.kernel_exit(self, code)

  class Status
    def exitstatus = Intrinsics.process_status_exitstatus(self)
    def success?   = exitstatus == 0
    def pid        = Intrinsics.process_status_pid(self)
    def to_i       = exitstatus
    def to_s       = "#<Process::Status: pid #{pid} exit #{exitstatus}>"
    def inspect    = to_s
  end
end

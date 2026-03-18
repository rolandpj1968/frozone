class Process
  CLOCK_REALTIME  = 0
  CLOCK_MONOTONIC = 1

  def self.pid   = Intrinsics.process_pid
  def self.euid  = Intrinsics.process_euid
  def self.exit(code = true)  = Kernel.exit(code)
  def self.exit!(code = false) = Intrinsics.kernel_exit(self, code)

  def self.clock_gettime(clock_id, unit = :float_second)
    Intrinsics.process_clock_gettime(clock_id, unit)
  end

  def self.kill(signal, *pids)
    sigstr = signal.is_a?(Integer) ? nil : signal.to_s.sub(/\ASIG/, '')
    sig = signal.is_a?(Integer) ? signal : Signal.list[sigstr]
    raise ArgumentError, "unsupported signal #{signal}" unless sig
    our_pid = Process.pid
    pids.each do |pid|
      raise SignalException.new(sig) if pid == our_pid
      Intrinsics.process_kill(sig, pid)
    end
    pids.length
  end

  class Status
    def exitstatus = Intrinsics.process_status_exitstatus(self)
    def success?   = exitstatus == 0
    def pid        = Intrinsics.process_status_pid(self)
    def to_i       = exitstatus
    def to_s       = "#<Process::Status: pid #{pid} exit #{exitstatus}>"
    def inspect    = to_s
  end
end

class Process
  CLOCK_REALTIME             = 0
  CLOCK_MONOTONIC            = 1
  CLOCK_PROCESS_CPUTIME_ID   = 2
  CLOCK_THREAD_CPUTIME_ID    = 3
  CLOCK_MONOTONIC_RAW        = 4
  CLOCK_REALTIME_COARSE      = 5
  CLOCK_MONOTONIC_COARSE     = 6
  CLOCK_BOOTTIME             = 7
  CLOCK_REALTIME_ALARM       = 8
  CLOCK_BOOTTIME_ALARM       = 9
  CLOCK_TAI                  = 11

  WNOHANG       = 1
  WUNTRACED     = 2
  PRIO_PROCESS  = 0
  PRIO_PGRP     = 1
  PRIO_USER     = 2
  RLIMIT_CPU    = 0
  RLIMIT_FSIZE  = 1
  RLIMIT_DATA   = 2
  RLIMIT_STACK  = 3
  RLIMIT_CORE   = 4
  RLIMIT_RSS    = 5
  RLIMIT_NPROC  = 6
  RLIMIT_NOFILE = 7
  RLIMIT_MEMLOCK = 8
  RLIMIT_AS     = 9
  RLIM_INFINITY    = 18446744073709551615
  RLIM_SAVED_MAX   = 18446744073709551615
  RLIM_SAVED_CUR   = 18446744073709551615

  def self._fork = raise(NotImplementedError, "fork() function is unimplemented on this machine")
  # wait family: call os_waitpid, construct a Process::Status, update $?.
  # os_waitpid returns [child_pid, raw_status] or nil (WNOHANG / ECHILD).
  def self._do_waitpid(pid, flags)
    result = Intrinsics.os_waitpid(pid, flags)
    return nil if result.nil?
    cpid, raw = result[0], result[1]
    s = Process::Status.new(cpid, raw)
    $? = s
    # Explicit cross-tier publish: the box's $? lives in the compiled
    # globals store, but interpreted user code reads $? via the Vm
    # interpreter's GLOBALS hash. Mirror so both tiers see the result.
    ::Frozone::Vm::GLOBALS[:"$?"] = s
    [cpid, s]
  end

  def self.wait(pid = -1, flags = 0)
    r = _do_waitpid(__coerce_to_int__(pid), flags)
    raise Errno::ECHILD if r.nil?
    r[0]
  end

  def self.wait2(pid = -1, flags = 0)
    r = _do_waitpid(__coerce_to_int__(pid), flags)
    raise Errno::ECHILD if r.nil?
    r
  end

  def self.waitpid(pid = -1, flags = 0) = wait(pid, flags)
  def self.waitpid2(pid = -1, flags = 0) = wait2(pid, flags)

  def self.waitall
    out = []
    loop do
      r = _do_waitpid(-1, 0)
      break if r.nil?
      out << r
    end
    out
  end
  def self.pid = Intrinsics.process_pid
  def self.uid = Intrinsics.process_uid
  def self.gid = Intrinsics.process_gid
  def self.euid = Intrinsics.process_euid
  def self.egid = Intrinsics.process_egid
  def self.groups = Intrinsics.process_groups
  def self.exit(code = true)  = Kernel.exit(code)
  def self.exit!(code = false) = Intrinsics.kernel_exit(self, code)
  def self.abort(msg = nil) = Kernel.abort(msg)
  def self.argv0 = $0.freeze
  def self.spawn(*args) = Intrinsics.kernel_spawn(self, *args)
  def self.clock_getres(clock_id, unit = :float_second) = Intrinsics.process_clock_getres(clock_id, unit)
  def self.clock_gettime(clock_id, unit = :float_second) = Intrinsics.process_clock_gettime(clock_id, unit)
  def self.daemon(stay_in_dir = false, keep_stdio_open = false) = Intrinsics.kernel_exec_daemon(stay_in_dir, keep_stdio_open)

  def self.fork(&block)
    pid = _fork
    if pid.nil?
      block.call if block
      exit!(0)
    end
    pid
  end

  def self.exec(*args)
    env = args.first.is_a?(Hash) ? args.shift : nil
    raise ArgumentError, "wrong number of arguments (given 0, expected 1+)" if args.empty?
    cmd = args.first
    if cmd.is_a?(Array)
      raise ArgumentError, "wrong first argument" unless cmd.length == 2
      cmd.each { |s| raise ArgumentError, "string contains null byte" if s.to_s.include?("\0") }
    else
      raise ArgumentError, "string contains null byte" if cmd.to_s.include?("\0")
    end
    args[1..].each { |a| raise ArgumentError, "string contains null byte" if a.to_s.include?("\0") }
    full_args = env ? [env] + args : args
    Intrinsics.kernel_exec(self, *full_args)
  end

  def self.kill(signal, *pids)
    sigstr = signal.is_a?(Integer) ? nil : signal.to_s.sub(/\ASIG/, '')
    sig = signal.is_a?(Integer) ? signal : Signal.list[sigstr]
    raise ArgumentError, "unsupported signal #{signal}" unless sig
    our_pid = Process.pid
    int_sig = Signal.list["INT"] || 2
    pids.each do |pid|
      if pid == our_pid
        # If there is an active callable handler registered via Signal.trap,
        # deliver through MRI so the handler runs. Otherwise raise in Frozone.
        name = Signal::CANONICAL_BY_NUM[sig]
        handler = Signal.instance_variable_get(:@handlers)[name]
        if handler && !handler.is_a?(String)
          Intrinsics.process_kill(sig, pid)
        else
          raise(sig == int_sig ? Interrupt.new : SignalException.new(sig))
        end
      else
        Intrinsics.process_kill(sig, pid)
      end
    end
    pids.length
  end

  def self.uid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer) || id.is_a?(String)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.gid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer) || id.is_a?(String)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.euid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer) || id.is_a?(String)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.egid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer) || id.is_a?(String)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.detach(pid)
    pid = __coerce_to_int__(pid)
    Thread.new(pid) do |p|
      begin
        status = Process.wait2(p)
        status ? status[1] : nil
      rescue Errno::ECHILD
        nil
      end
    end
  end

  module UID
    def self.rid = Process.uid
    def self.eid = Process.euid
    def self.eid=(id) = Process.euid = id
    def self.rid=(id) = Process.uid = id
    def self.sid_available? = false
    def self.grant_privilege(id) = Process.uid = id
    def self.switch = raise NotImplementedError
  end

  module GID
    def self.rid = Process.gid
    def self.eid = Process.egid
    def self.eid=(id) = Process.egid = id
    def self.rid=(id) = Process.gid = id
    def self.sid_available? = false
    def self.grant_privilege(id) = Process.gid = id
    def self.switch = raise NotImplementedError
  end

  module Sys
    def self.getuid = Process.uid
    def self.getgid = Process.gid
    def self.geteuid = Process.euid
    def self.getegid = Process.egid
    def self.setuid(id) = Process.uid = id
    def self.setgid(id) = Process.gid = id
    def self.seteuid(id) = Process.euid = id
    def self.setegid(id) = Process.egid = id
    def self.setruid(id) = raise NotImplementedError
    def self.setrgid(id) = raise NotImplementedError
    def self.setsid = raise NotImplementedError
    def self.issetugid = false
  end

  # POSIX wait-status bit layout (decoded in pure Ruby — same bit-twiddle
  # MRI's process.c does). raw_status comes from waitpid(2) directly:
  #   low 7 bits  = signal that terminated the process (0 = exited normally)
  #   bit 7       = WCOREDUMP (set if dumped core)
  #   bits 8..15  = exit status (when exited normally)
  class Status
    def initialize(pid, raw_status)
      @pid = pid
      @raw = raw_status
    end

    def pid = @pid
    def to_i = @raw
    def exited? = (@raw & 0x7f) == 0
    def signaled? = ((@raw & 0x7f) + 1) >> 1 > 0
    def stopped? = (@raw & 0xff) == 0x7f  # WIFSTOPPED bit pattern
    def coredump? = (@raw & 0x80) != 0
    def exitstatus = exited? ? (@raw >> 8) & 0xff : nil
    def termsig = signaled? ? (@raw & 0x7f) : nil
    def stopsig = stopped? ? (@raw >> 8) & 0xff : nil
    def success? = exited? && exitstatus == 0
    def to_s = "#<Process::Status: pid #{pid} exit #{exitstatus}>"
    def inspect = to_s
  end
end

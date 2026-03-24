class Process
  CLOCK_REALTIME  = 0
  CLOCK_MONOTONIC = 1

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

  def self.clock_getres(clock_id, unit = :float_second)
    Intrinsics.process_clock_getres(clock_id, unit)
  end

  def self.clock_gettime(clock_id, unit = :float_second)
    Intrinsics.process_clock_gettime(clock_id, unit)
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
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.gid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.euid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer)
    raise Errno::EPERM, "Operation not permitted"
  end

  def self.egid=(id)
    raise TypeError, "can't convert #{id.class} into Integer" unless id.is_a?(Integer)
    raise Errno::EPERM, "Operation not permitted"
  end

  module UID
    def self.rid = Process.uid
    def self.eid = Process.euid
    def self.eid=(id) = Process.euid = id
    def self.rid=(id) = Process.uid = id
    def self.sid_available? = false
    def self.switch; raise NotImplementedError; end
    def self.grant_privilege(id) = Process.uid = id
  end

  module GID
    def self.rid = Process.gid
    def self.eid = Process.egid
    def self.eid=(id) = Process.egid = id
    def self.rid=(id) = Process.gid = id
    def self.sid_available? = false
    def self.switch; raise NotImplementedError; end
    def self.grant_privilege(id) = Process.gid = id
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
    def self.setruid(id); raise NotImplementedError; end
    def self.setrgid(id); raise NotImplementedError; end
    def self.setsid; raise NotImplementedError; end
    def self.issetugid = false
  end

  class Status
    def exitstatus = Intrinsics.process_status_exitstatus(self)
    def success? = exitstatus == 0
    def pid = Intrinsics.process_status_pid(self)
    def termsig = Intrinsics.process_status_termsig(self)
    def signaled? = !termsig.nil?
    def stopped? = false
    def stopsig = nil
    def coredump? = false
    def exited? = !signaled?
    def to_i = exitstatus.to_i
    def to_s = "#<Process::Status: pid #{pid} exit #{exitstatus}>"
    def inspect = to_s
  end
end

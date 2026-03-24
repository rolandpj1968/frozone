module Signal
  # Standard POSIX signals (linux x86_64); EXIT=0 and CLD alias included per MRI
  LIST = {
    "EXIT" => 0,
    "HUP"  => 1,  "INT"  => 2,  "QUIT" => 3,  "ILL"  => 4,
    "TRAP" => 5,  "ABRT" => 6,  "BUS"  => 7,  "FPE"  => 8,
    "KILL" => 9,  "USR1" => 10, "SEGV" => 11, "USR2" => 12,
    "PIPE" => 13, "ALRM" => 14, "TERM" => 15, "CHLD" => 17,
    "CLD"  => 17,
    "CONT" => 18, "STOP" => 19, "TSTP" => 20, "TTIN" => 21,
    "TTOU" => 22, "URG"  => 23, "XCPU" => 24, "XFSZ" => 25,
    "VTALRM" => 26, "PROF" => 27, "WINCH" => 28, "IO" => 29,
    "PWR" => 30,  "SYS"  => 31,
  }.freeze

  # Canonical name by number (first entry wins for aliases like CLD/CHLD).
  # Pre-built for Signal.signame performance.
  _canonical = {}
  LIST.each { |name, num| _canonical[num] ||= name }
  CANONICAL_BY_NUM = _canonical.freeze

  # Signals that cannot be trapped (OS-level)
  UNCATCHABLE = %w[KILL STOP].freeze
  # Signals reserved by Ruby VM
  RESERVED    = %w[SEGV BUS ILL FPE VTALRM].freeze
  # Signals whose OS-default state is "SYSTEM_DEFAULT" (Ruby doesn't install a Ruby handler)
  SYSTEM_DEFAULT_INITIAL = %w[CHLD CLD CONT PROF URG XCPU XFSZ TTIN TTOU TSTP IO PWR WINCH SYS].freeze

  # Sentinel for "never set" (distinct from nil which is a valid handler meaning IGNORE)
  UNSET = Object.new.freeze

  # Handler registry: canonical signal name → handler (proc, "IGNORE", "DEFAULT", nil, etc.)
  @handlers = {}

  def self.list = LIST

  def self._normalize_name(signal)
    if signal.is_a?(Integer)
      raise ArgumentError, "invalid signal number (#{signal})" unless CANONICAL_BY_NUM.key?(signal)
      return CANONICAL_BY_NUM[signal]
    end
    if signal.respond_to?(:to_str)
      str = signal.to_str
    elsif signal.is_a?(Symbol)
      str = signal.to_s
    else
      raise ArgumentError, "bad signal type #{signal.class}"
    end
    name = str.start_with?("SIG") ? str[3..] : str
    raise ArgumentError, "unsupported signal `SIG#{name}'" unless LIST.key?(name)
    # Return the canonical name for aliases (CLD → CHLD via CANONICAL_BY_NUM)
    CANONICAL_BY_NUM[LIST[name]]
  end

  def self.trap(signal, command = :__no_command__, &block)
    callable = command.equal?(:__no_command__) ? block : command
    name = _normalize_name(signal)
    raise ArgumentError, "can't trap reserved signal: SIG#{name}" if RESERVED.include?(name)
    if UNCATCHABLE.include?(name)
      raise Errno::EINVAL, "Invalid argument - Signal already used by VM or OS"
    end
    handler = case callable
              when "SIG_IGN", :SIG_IGN, "IGNORE", :IGNORE   then "IGNORE"
              when "SIG_DFL", :SIG_DFL, "DEFAULT", :DEFAULT  then "DEFAULT"
              when "SYSTEM_DEFAULT", :SYSTEM_DEFAULT          then "SYSTEM_DEFAULT"
              when "EXIT", :EXIT                              then "EXIT"
              else callable
              end
    old_raw = @handlers.fetch(name, UNSET)
    @handlers[name] = handler
    # Register with MRI's signal handling
    Intrinsics.signal_register(name, handler)
    if old_raw.equal?(UNSET)
      SYSTEM_DEFAULT_INITIAL.include?(name) ? "SYSTEM_DEFAULT" : "DEFAULT"
    else
      old_raw
    end
  end

  def self.signame(signum)
    unless signum.is_a?(Integer)
      if signum.respond_to?(:to_int)
        signum = signum.to_int
        raise TypeError, "no implicit conversion into Integer" unless signum.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{signum.class} into Integer"
      end
    end
    CANONICAL_BY_NUM[signum]
  end
end

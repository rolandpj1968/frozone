class StringIO
  include Enumerable
  include IO::Readable rescue nil  # optional mixin

  VERSION = "3.1.2"

  attr_accessor :lineno

  def self.new(*args, **kwargs, &block)
    if block
      warn "warning: StringIO::new() does not take block; use StringIO::open() instead"
    end
    super(*args, **kwargs)
  end

  def self.open(*args, **kwargs, &block)
    io = allocate
    io.send(:initialize, *args, **kwargs)
    return io unless block
    begin
      result = block.call(io)
    rescue Exception
      io.close rescue nil
      io.instance_variable_set(:@string, nil) rescue nil
      raise
    end
    io.close rescue nil
    io.instance_variable_set(:@string, nil) rescue nil
    result
  end

  def initialize(str = nil, mode = nil, mode_arg = nil, binmode: nil, textmode: nil,
                 external_encoding: nil, internal_encoding: nil, encoding: nil, **opts)
    # Handle :mode keyword option
    if mode.nil? && opts.key?(:mode)
      mode = opts[:mode]
    end
    # nil mode_arg means mode_arg wasn't passed
    mode = mode_arg if mode.nil? && !mode_arg.nil?

    # Default str to empty string
    str_given = !str.nil?
    str = "" if str.nil?

    # Coerce str to String via to_str
    str = str.to_str if str.respond_to?(:to_str)
    str = str.to_s unless str.is_a?(String)

    # Parse mode — convert via to_str if object
    int_trunc_only = false  # for frozen-string error type
    if mode.nil?
      # Default mode: read-write for mutable strings, read-only for frozen
      mode_str = str.frozen? ? "r" : "r+"
    elsif mode.is_a?(Integer)
      # IO::TRUNC alone (no WRONLY/RDWR) → FrozenError on frozen strings
      has_int_wronly = (mode & File::WRONLY) != 0 rescue false
      has_int_rdwr   = (mode & File::RDWR)   != 0 rescue false
      has_int_trunc  = (mode & File::TRUNC)  != 0 rescue false
      int_trunc_only = has_int_trunc && !has_int_wronly && !has_int_rdwr
      mode_str = _int_mode_to_str(mode)
    else
      mode = mode.to_str if mode.respond_to?(:to_str)
      mode_str = mode.to_s
    end

    # Validate binmode/textmode conflicts
    has_b = mode_str.include?("b")
    has_t = mode_str.include?("t")
    # If mode string has 'b' or 't', any explicit binmode:/textmode: kwarg is an error
    if (has_b || has_t) && (!binmode.nil? || !textmode.nil?)
      raise ArgumentError, "binary/text mode mismatch"
    end
    # Both binmode and textmode explicitly provided
    if !binmode.nil? && !textmode.nil?
      raise ArgumentError, "both textmode and binmode specified"
    end

    # Check for encoding specified both in mode string and keyword
    if mode_str.include?(":") && (external_encoding || encoding || internal_encoding)
      raise ArgumentError, "encoding specified twice"
    end

    # Strip encoding suffix from mode string
    mode_str = mode_str.split(":").first

    binary = has_b || binmode == true
    mode_str = mode_str.gsub("b", "").gsub("t", "")

    case mode_str
    when "r"
      @readable = true;  @writable = false; @append = false; @truncate = false
    when "w"
      @readable = false; @writable = true;  @append = false; @truncate = true
    when "a"
      @readable = false; @writable = true;  @append = true;  @truncate = false
    when "r+"
      @readable = true;  @writable = true;  @append = false; @truncate = false
    when "w+"
      @readable = true;  @writable = true;  @append = false; @truncate = true
    when "a+"
      @readable = true;  @writable = true;  @append = true;  @truncate = false
    else
      raise ArgumentError, "invalid access mode #{mode}"
    end

    # Integer modes: only truncate if TRUNC flag is explicitly set
    @truncate = false if mode.is_a?(Integer) && !has_int_trunc

    # Frozen string checks
    if str.frozen? && @writable
      if int_trunc_only
        raise FrozenError, "can't modify frozen String: #{str.inspect}"
      else
        raise Errno::EACCES, "Permission denied"
      end
    end

    # Store the string directly (not a dup) to preserve object identity
    @string = str
    if @truncate
      # Clear content in-place to preserve identity, or use new string if frozen
      if @string.respond_to?(:clear) && !@string.frozen?
        @string.clear
      else
        @string = "".force_encoding(str.encoding) rescue ""
      end
    end
    @pos       = @append ? @string.bytesize : 0
    @lineno    = 0
    @closed_r  = false
    @closed_w  = false
    @binary    = binary
    @sync      = true

    ext_enc = external_encoding || encoding
    if ext_enc
      @external_encoding = Encoding.find(ext_enc.to_s) rescue ext_enc
      # Apply encoding to @string
      @string.force_encoding(@external_encoding) if @string.respond_to?(:force_encoding) && !@string.frozen?
    elsif binary
      @external_encoding = Encoding::ASCII_8BIT rescue Encoding::BINARY rescue nil
      @string.force_encoding(@external_encoding) if @external_encoding && @string.respond_to?(:force_encoding) && !@string.frozen?
    else
      # Encoding derived dynamically from @string — don't set @external_encoding
      # For no-arg case, apply default_external to the string
      @external_encoding = nil
      if !str_given
        def_enc = Encoding.default_external rescue nil
        @string.force_encoding(def_enc) if def_enc && @string.respond_to?(:force_encoding) && !@string.frozen?
      end
    end
    @internal_encoding = internal_encoding
  end

  # ── Underlying string ──────────────────────────────────────────────────

  def string
    @string
  end

  def string=(str)
    str = str.to_str if str.respond_to?(:to_str)
    @string = str
    @pos    = 0
    @lineno = 0
    str
  end

  # ── State ──────────────────────────────────────────────────────────────

  def size   = @string.bytesize
  alias length size

  def pos = @pos

  def pos=(n)
    n = n.to_int if n.respond_to?(:to_int)
    raise Errno::EINVAL, "Invalid argument" if n < 0
    @pos = n
  end
  alias tell pos

  def rewind
    @pos    = 0
    @lineno = 0
    0
  end

  def seek(offset, whence = IO::SEEK_SET)
    _check_open
    offset = offset.to_int if offset.respond_to?(:to_int)
    base = case whence
           when IO::SEEK_SET, 0 then 0
           when IO::SEEK_CUR, 1 then @pos
           when IO::SEEK_END, 2 then @string.bytesize
           else raise Errno::EINVAL, "Invalid argument"
           end
    new_pos = base + offset
    raise Errno::EINVAL, "Invalid argument" if new_pos < 0
    @pos = new_pos
    0
  end

  def eof?
    _check_readable
    @pos >= @string.bytesize
  end
  alias eof eof?

  # ── Encoding ───────────────────────────────────────────────────────────

  def external_encoding
    @external_encoding || @string.encoding
  end

  def internal_encoding
    @internal_encoding
  end

  def set_encoding(ext, int = nil, **opts)
    @external_encoding = Encoding.find(ext.to_s) rescue ext
    @internal_encoding = int ? (Encoding.find(int.to_s) rescue int) : nil
    @explicit_encoding = true
    @string.force_encoding(@external_encoding) if @external_encoding && !@string.frozen?
    self
  end

  def binmode
    @binary = true
    @external_encoding = Encoding::ASCII_8BIT rescue nil
    self
  end

  def binmode? = @binary

  # ── Closing ────────────────────────────────────────────────────────────

  def close
    @closed_r = true
    @closed_w = true
    nil
  end

  def close_read
    raise IOError, "closing non-duplex IO for reading" unless @readable || @closed_r
    @closed_r = true
    nil
  end

  def close_write
    raise IOError, "closing non-duplex IO for writing" unless @writable || @closed_w
    @closed_w = true
    nil
  end

  def closed?       = @closed_r && @closed_w
  def closed_read?  = @closed_r || !@readable
  def closed_write? = @closed_w || !@writable

  # ── Reading ────────────────────────────────────────────────────────────

  def read(length = nil, buffer = nil)
    _check_readable
    if length.nil?
      data = @string.byteslice(@pos..) || ""
      @pos = @string.bytesize
      data = data.encode(Encoding::ASCII_8BIT) rescue data if false  # keep encoding
      data = data.b rescue data if @binary
      if buffer
        buffer.replace(data) rescue (buffer << data)
        return buffer
      end
      return data
    end

    length = length.to_int if length.respond_to?(:to_int)
    raise TypeError, "no implicit conversion into Integer" unless length.is_a?(Integer)
    raise ArgumentError, "negative length #{length} given" if length < 0

    # Validate buffer (must respond to to_str)
    if buffer
      if buffer.is_a?(String)
        buf_enc = buffer.encoding rescue nil
      elsif buffer.respond_to?(:to_str)
        buffer = buffer.to_str
        buf_enc = buffer.encoding rescue nil
      else
        raise TypeError, "no implicit conversion of #{buffer.class} into String"
      end
    end

    if @pos >= @string.bytesize
      if buffer
        buffer.replace("") rescue (buffer.clear rescue nil)
      end
      return length == 0 ? (buffer || "") : nil
    end

    data = @string.byteslice(@pos, length) || ""
    @pos += data.bytesize
    data = data.b rescue data  # read always returns binary bytes
    if buffer
      saved_enc = buf_enc
      buffer.replace(data) rescue (buffer.clear rescue nil; buffer << data rescue nil)
      buffer.force_encoding(saved_enc) if saved_enc && buffer.respond_to?(:force_encoding)
      return buffer
    end
    data
  end

  def readbyte
    _check_readable
    raise EOFError, "end of file reached" if eof?
    b = @string.getbyte(@pos)
    @pos += 1
    b
  end

  def readchar
    _check_readable
    raise EOFError, "end of file reached" if eof?
    getc
  end

  def readline(sep = $/, limit = nil, chomp: false)
    _check_readable
    line = gets(sep, limit, chomp: chomp)
    raise EOFError, "end of file reached" if line.nil?
    line
  end

  def readlines(sep = $/, limit = nil, chomp: false)
    _check_readable
    # Normalize sep/limit once
    sep, limit = _normalize_sep_limit(sep, limit)
    # limit=0 is an error
    if limit.is_a?(Integer) && limit == 0
      raise ArgumentError, "invalid limit: 0 for readlines"
    end
    saved_dl = $_
    lines = []
    while (line = gets(sep, limit, chomp: chomp))
      lines << line
    end
    $_ = saved_dl
    lines
  end

  def getc
    _check_readable
    return nil if @pos >= @string.bytesize
    # Read one character (potentially multi-byte)
    ch = @string[@pos / 1]  rescue nil  # character at byte pos - simplified
    # For proper multi-byte support, use byteslice and detect char width
    byte = @string.getbyte(@pos)
    return nil if byte.nil?
    # Determine UTF-8 char width from lead byte
    width = if byte < 0x80 then 1
            elsif byte < 0xE0 then 2
            elsif byte < 0xF0 then 3
            else 4
            end
    ch = @string.byteslice(@pos, width) || ""
    @pos += ch.bytesize
    ch
  end

  def getbyte
    _check_readable
    return nil if @pos >= @string.bytesize
    b = @string.getbyte(@pos)
    @pos += 1 if b
    b
  end

  def ungetc(char)
    _check_readable
    if char.is_a?(Integer)
      char = char.chr rescue char.chr(Encoding::BINARY)
    elsif char.respond_to?(:to_str)
      char = char.to_str
    elsif !char.is_a?(String)
      raise TypeError, "no implicit conversion of #{char.class} into String"
    end
    _unget_str(char)
    nil
  end

  def ungetbyte(byte)
    _check_readable
    if byte.is_a?(Integer)
      byte = (byte & 0xff).chr(Encoding::BINARY)
    elsif byte.is_a?(String)
      byte = byte.b rescue byte
    elsif byte.respond_to?(:to_str)
      byte = byte.to_str
    else
      raise TypeError, "no implicit conversion of #{byte.class} into Integer"
    end
    _unget_str(byte)
    nil
  end

  def gets(sep = $/, limit = nil, chomp: false)
    _check_readable
    return nil if @pos >= @string.bytesize

    # Normalise args: gets(limit) when sep is Integer or responds to to_int but not to_str
    if sep.is_a?(Integer)
      limit = sep
      sep   = $/
    elsif sep && !sep.is_a?(String) && !sep.nil?
      if sep.respond_to?(:to_int) && !sep.respond_to?(:to_str)
        limit = sep.to_int
        sep   = $/
      elsif sep.respond_to?(:to_str)
        sep = sep.to_str
      end
    end

    data = @string.byteslice(@pos..) || ""

    line = if sep.nil?
             # nil separator: return everything
             data
           elsif sep == ""
             # paragraph mode: read until \n\n, include ALL consecutive newlines
             idx = data.index("\n\n")
             if idx
               rest = data[idx + 2..]
               extra = rest&.match(/\A\n+/)&.[](0) || ""
               data[0, idx + 2 + extra.length]
             else
               data
             end
           else
             idx = data.index(sep)
             idx ? data[0, idx + sep.length] : data
           end

    # Apply limit (negative limit = no limit)
    if limit
      limit = limit.to_int if limit.respond_to?(:to_int)
      if limit == 0
        @lineno += 1
        return ""
      end
      line = line.byteslice(0, limit) if limit > 0 && line.bytesize > limit
    end

    return nil if line.empty? && @pos >= @string.bytesize

    @pos    += line.bytesize
    @lineno += 1
    $_ = line

    chomp ? _chomp(line, sep) : line
  end

  # ── Writing ────────────────────────────────────────────────────────────

  def write(*strs)
    _check_writable
    total = 0
    strs.each do |obj|
      str = obj.is_a?(String) ? obj : obj.to_s
      _write_str(str)
      total += str.bytesize
    end
    total
  end
  alias syswrite write

  def write_nonblock(*strs, exception: true)
    write(*strs)
  end

  def <<(obj)
    _check_writable
    str = obj.is_a?(String) ? obj : obj.to_s
    _write_str(str)
    self
  end

  def print(*args)
    _check_writable
    args = [$_] if args.empty?
    args.each do |a|
      s = a.nil? ? "" : a.to_s
      _write_str(s)
    end
    _write_str($\.to_s) if $\
    nil
  end

  def puts(*args)
    _check_writable
    if args.empty?
      _write_str("\n")
      return nil
    end
    _puts_args(args, (Fiber[:__sio_puts_seen__] ||= {}))
    nil
  end

  def printf(fmt, *args)
    _check_writable
    _write_str(sprintf(fmt, *args))
    nil
  end

  def putc(obj)
    _check_writable
    ch = if obj.is_a?(Integer)
           (obj % 256).chr
         elsif obj.is_a?(String)
           obj[0]
         elsif obj.respond_to?(:to_int)
           (obj.to_int % 256).chr
         elsif obj.respond_to?(:to_str)
           obj.to_str[0]
         else
           raise TypeError, "no implicit conversion of #{obj.class} into Integer"
         end
    _write_str(ch)
    obj
  end

  def truncate(len)
    _check_writable
    if len.respond_to?(:to_int)
      len = len.to_int
    elsif !len.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{len.class} into Integer"
    end
    raise Errno::EINVAL, "Invalid argument - negative length" if len < 0
    cur = @string.bytesize
    if len < cur
      @string.replace(@string.byteslice(0, len) || "")
    elsif len > cur
      @string << ("\x00" * (len - cur))
    end
    len
  end

  # ── Iteration ─────────────────────────────────────────────────────────

  def each_line(sep = $/, limit = nil, chomp: false, &block)
    _check_readable
    return enum_for(:each_line, sep, limit, chomp: chomp) unless block
    # Normalize sep/limit once before the loop so mocks aren't called per-iteration
    sep, limit = _normalize_sep_limit(sep, limit)
    saved_dl = $_
    while (line = gets(sep, limit, chomp: chomp))
      block.call(line)
    end
    $_ = saved_dl
    self
  end
  alias each each_line
  alias each_with_index each_line rescue nil

  def each_byte(&block)
    _check_readable
    return enum_for(:each_byte) unless block
    while (b = getbyte)
      block.call(b)
    end
    self
  end

  def each_char(&block)
    _check_readable
    return enum_for(:each_char) unless block
    while (ch = getc)
      block.call(ch)
    end
    self
  end

  def each_codepoint(&block)
    _check_readable
    return enum_for(:each_codepoint) unless block
    each_char { |ch| block.call(ch.ord) }
    self
  end

  def bytes    = each_byte.to_a
  def chars    = each_char.to_a
  def lines(*args)  = each_line(*args).to_a
  def codepoints    = each_codepoint.to_a

  # ── sysread / read_nonblock / readpartial ─────────────────────────────

  def sysread(length = nil, buffer = nil)
    _check_readable
    if length.nil?
      data = @string.byteslice(@pos..) || ""
      @pos = @string.bytesize
      data = data.b rescue data if @binary
      if buffer
        buffer = buffer.to_str if !buffer.is_a?(String) && buffer.respond_to?(:to_str)
        buffer.replace(data) rescue nil
        return buffer
      end
      return data
    end

    if length.respond_to?(:to_int) && !length.is_a?(Integer)
      length = length.to_int
    elsif !length.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{length.class} into Integer"
    end
    raise ArgumentError, "negative length #{length} given" if length < 0

    if buffer
      if buffer.is_a?(String)
        buf_enc = buffer.encoding rescue nil
      elsif buffer.respond_to?(:to_str)
        buffer = buffer.to_str
        buf_enc = buffer.encoding rescue nil
      else
        raise TypeError, "no implicit conversion of #{buffer.class} into String"
      end
    end

    raise EOFError, "end of file reached" if length > 0 && @pos >= @string.bytesize

    data = @string.byteslice(@pos, length) || ""
    @pos += data.bytesize
    data = data.b rescue data

    if buffer
      saved_enc = buf_enc
      buffer.replace(data) rescue nil
      buffer.force_encoding(saved_enc) if saved_enc && buffer.respond_to?(:force_encoding)
      return buffer
    end
    data
  end

  def read_nonblock(length = nil, buffer = nil, exception: true)
    _check_readable
    if length.respond_to?(:to_int) && !length.is_a?(Integer)
      length = length.to_int
    elsif length && !length.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{length.class} into Integer"
    end
    if length && length > 0 && @pos >= @string.bytesize
      return nil unless exception
      raise EOFError, "end of file reached"
    end
    sysread(length, buffer)
  end

  def readpartial(length, buffer = nil)
    _check_readable
    if length.respond_to?(:to_int) && !length.is_a?(Integer)
      length = length.to_int
    elsif !length.is_a?(Integer)
      raise TypeError, "no implicit conversion into Integer"
    end
    raise ArgumentError, "negative length #{length} given" if length < 0

    buf_enc = nil
    if buffer
      if buffer.is_a?(String)
        buf_enc = buffer.encoding rescue nil
      elsif buffer.respond_to?(:to_str)
        buffer = buffer.to_str
        buf_enc = buffer.encoding rescue nil
      else
        raise TypeError, "no implicit conversion of #{buffer.class} into String"
      end
    end

    if length == 0
      buffer.replace("") rescue nil if buffer
      ret = buffer || ""
      ret.force_encoding(buf_enc) if buf_enc && ret.respond_to?(:force_encoding)
      return ret
    end

    if @pos >= @string.bytesize
      buffer.replace("") rescue nil if buffer
      raise EOFError, "end of file reached"
    end

    data = (@string.byteslice(@pos, length) || "").b rescue (@string.byteslice(@pos, length) || "")
    @pos += data.bytesize

    if buffer
      saved_enc = buf_enc
      buffer.replace(data) rescue nil
      buffer.force_encoding(saved_enc) if saved_enc && buffer.respond_to?(:force_encoding)
      return buffer
    end
    data
  end

  # ── reopen ────────────────────────────────────────────────────────────

  def reopen(*args)
    case args.length
    when 0
      @pos      = 0
      @lineno   = 0
      @closed_r = false
      @closed_w = false
      @readable = true
      @writable = !@string.frozen?
      @append   = false
    when 1
      obj = args[0]
      if obj.is_a?(StringIO)
        initialize(obj.string)
      elsif obj.is_a?(String)
        initialize(obj)
      elsif obj.respond_to?(:to_strio)
        initialize(obj.to_strio.string)
      else
        raise TypeError, "no implicit conversion of #{obj.class} into StringIO"
      end
    when 2
      str, mode = args
      unless str.is_a?(String)
        if str.respond_to?(:to_str)
          str = str.to_str
        else
          raise TypeError, "no implicit conversion of #{str.class} into String"
        end
      end
      initialize(str, mode)
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
    self
  end

  # ── set_encoding_by_bom ───────────────────────────────────────────────

  def set_encoding_by_bom
    raise FrozenError, "can't modify frozen #{self.class}" if frozen?
    return nil unless @readable && !@closed_r
    return nil if @explicit_encoding

    data = @string.byteslice(@pos, 4)
    return nil if data.nil? || data.empty?

    bytes = data.bytes

    enc, bom_size = if bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF
                      [Encoding::UTF_8, 3]
                    elsif bytes[0] == 0xFF && bytes[1] == 0xFE
                      bytes[2] == 0x00 && bytes[3] == 0x00 ?
                        [Encoding::UTF_32LE, 4] : [Encoding::UTF_16LE, 2]
                    elsif bytes[0] == 0xFE && bytes[1] == 0xFF
                      [Encoding::UTF_16BE, 2]
                    elsif bytes[0] == 0x00 && bytes[1] == 0x00 &&
                          bytes[2] == 0xFE && bytes[3] == 0xFF
                      [Encoding::UTF_32BE, 4]
                    else
                      [nil, 0]
                    end

    if enc
      @external_encoding = enc
      @pos += bom_size
      return enc
    end
    nil
  end

  # ── IO compatibility stubs ────────────────────────────────────────────

  def flush          = self
  def sync           = true
  def sync=(_v); true; end
  def fsync          = 0
  def fileno         = nil
  def isatty         = false
  alias tty? isatty
  def pid            = nil
  def fcntl(*_)      = raise(NotImplementedError, "fcntl not supported")
  def ioctl(*_)      = raise(Errno::EBADF, "Bad file descriptor")
  def stat           = raise(Errno::EBADF, "Bad file descriptor")
  def to_io          = self
  def to_s           = "#<StringIO:0x#{object_id.to_s(16)}>"
  def inspect        = to_s
  def readable?      = @readable && !@closed_r
  def writable?      = @writable && !@closed_w
  def readable_real? = readable?
  def writable_real? = writable?

  private

  def _unget_str(str)
    new_pos = @pos > 0 ? @pos - 1 : 0
    orig_enc = @string.encoding rescue Encoding::BINARY
    str_b    = str.b rescue str
    cur_b    = @string.b rescue @string

    result = if new_pos >= cur_b.bytesize
               padding = new_pos - cur_b.bytesize
               cur_b + ("\x00" * padding) + str_b
             else
               cur_b.byteslice(0, new_pos).to_s + str_b + cur_b.byteslice(new_pos + 1..).to_s
             end

    result.force_encoding(orig_enc) rescue result.force_encoding(Encoding::BINARY)
    begin
      @string.replace(result)
    rescue
      @string = result
    end
    @pos = new_pos
  end

  def _normalize_sep_limit(sep, limit)
    if sep.is_a?(Integer)
      limit = sep; sep = $/
    elsif sep && !sep.is_a?(String)
      if sep.respond_to?(:to_int) && !sep.respond_to?(:to_str)
        limit = sep.to_int; sep = $/
      elsif sep.respond_to?(:to_str)
        sep = sep.to_str
      end
    end
    limit = limit.to_int if limit && !limit.is_a?(Integer) && limit.respond_to?(:to_int)
    [sep, limit]
  end

  def _puts_args(args, seen)
    args.each do |a|
      ary = nil
      ary = a.to_ary if a.respond_to?(:to_ary)
      if ary.is_a?(Array)
        ary_id = ary.object_id
        if seen[ary_id]
          _write_str("[...]\n")
        else
          seen[ary_id] = true
          _puts_args(ary, seen)
          seen.delete(ary_id)
        end
      else
        s = a.nil? ? "" : a.to_s
        s = "#{a.inspect.split(" ")[0]}>" unless s.is_a?(String)
        s = s.to_s
        _write_str(s)
        _write_str("\n") unless s.end_with?("\n")
      end
    end
  end

  def _check_open
    raise IOError, "closed stream" if closed?
  end

  def _check_readable
    raise IOError, "not opened for reading" if @closed_r || !@readable
  end

  def _check_writable
    raise IOError, "not opened for writing" if @closed_w || !@writable
    raise Errno::EACCES, "Permission denied" if @string.frozen?
  end

  def _write_str(str)
    # Transcode or relabel str to match the target encoding
    if @external_encoding
      ascii8bit = Encoding::ASCII_8BIT rescue nil
      if @external_encoding == ascii8bit
        str = str.b rescue str
      elsif ascii8bit && str.encoding != @external_encoding && str.encoding != ascii8bit
        str = str.encode(@external_encoding) rescue str
      end
    end

    write_pos = @append ? @string.bytesize : @pos
    cur_size  = @string.bytesize

    if write_pos > cur_size
      # Pad with null bytes
      @string = @string + ("\x00" * (write_pos - cur_size)) + str
    elsif write_pos + str.bytesize <= cur_size
      # Replace in middle
      @string = @string.byteslice(0, write_pos).to_s + str +
                @string.byteslice(write_pos + str.bytesize..).to_s
    else
      # Overwrite and extend
      @string = @string.byteslice(0, write_pos).to_s + str
    end

    # Maintain @string's encoding label
    if @external_encoding && @string.respond_to?(:force_encoding) && !@string.frozen?
      @string.force_encoding(@external_encoding) rescue nil
    end

    @pos = write_pos + str.bytesize
  end

  def _int_mode_to_str(m)
    has_rdwr   = (m & File::RDWR)   != 0
    has_wronly = (m & File::WRONLY) != 0
    has_trunc  = (m & File::TRUNC)  != 0 rescue false
    has_append = (m & File::APPEND) != 0 rescue false

    if has_rdwr
      base = has_trunc ? "w+" : "r+"
    elsif has_wronly || has_trunc
      base = "w"
    else
      base = "r"
    end
    base = "a" + base[1..] if has_append
    base += "b" if (m & File::BINARY) != 0 rescue nil
    base
  end

  def _chomp(str, sep)
    return str.chomp if sep.nil? || sep == "" || sep == "\n"
    str.end_with?(sep) ? str[0, str.length - sep.length] : str
  end
end

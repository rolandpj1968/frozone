# Pure-Ruby StringScanner for Frozone.
# Implements the essential StringScanner API used by csv, uri, and other stdlib gems.
# All positions are byte-based, matching MRI's StringScanner semantics.

class StringScanner
  Id      = 'None$Id'.freeze
  Version = '3.1.3'.freeze

  attr_reader :string

  def pos = @pos
  def pointer = @pos
  def eos?      = @pos >= @string.bytesize
  def rest      = @string.byteslice(@pos..) || ''
  def rest?     = !eos?
  def rest_size = @string.bytesize - @pos
  alias restsize rest_size
  def matched?    = !@matched.nil?
  def matched     = @matched
  def matchedsize = @matched ? @matched.bytesize : nil
  alias matched_size matchedsize
  def to_s = inspect
  def fixed_anchor? = @fixed_anchor
  def self.must_C_version = self

  # charpos returns the CHARACTER position (not byte position)
  def charpos
    @string.byteslice(0, @pos).length
  end

  def initialize(str, fixed_anchor: false)
    str = str.respond_to?(:to_str) ? str.to_str : str.to_s
    @string       = str
    @pos          = 0
    @matched      = nil
    @match_data   = nil
    @pre_match    = nil
    @post_match   = nil
    @fixed_anchor = fixed_anchor
  end

  def string=(str)
    str         = str.respond_to?(:to_str) ? str.to_str : str.to_s
    @string     = str
    @pos        = 0
    @matched    = nil
    @match_data = nil
    @pre_match  = nil
    @post_match = nil
    @string
  end

  def pos=(n)
    n = @string.bytesize + n if n < 0
    raise RangeError, "index out of range" if n < 0 || n > @string.bytesize
    @pos = n
  end
  alias pointer= pos=

  def reset
    @pos        = 0
    @matched    = nil
    @match_data = nil
    @pre_match  = nil
    @post_match = nil
    self
  end

  def terminate
    @pos        = @string.bytesize
    @matched    = nil
    @match_data = nil
    @pre_match  = nil
    @post_match = nil
    self
  end
  alias clear terminate

  def concat(str)
    raise TypeError, "no implicit conversion of #{str.class} into String" unless str.respond_to?(:to_str)
    @string = @string + str.to_str
    self
  end
  alias << concat

  def dup
    copy = self.class.allocate
    copy.instance_variable_set(:@string,       @string.dup)
    copy.instance_variable_set(:@pos,          @pos)
    copy.instance_variable_set(:@matched,      @matched)
    copy.instance_variable_set(:@match_data,   @match_data)
    copy.instance_variable_set(:@pre_match,    @pre_match)
    copy.instance_variable_set(:@post_match,   @post_match)
    copy.instance_variable_set(:@fixed_anchor, @fixed_anchor)
    copy
  end

  def peek(n)
    raise ArgumentError, "invalid argument: #{n}" if n < 0
    @string.byteslice(@pos, n) || ''
  end

  # Returns the byte at current position as an Integer, without advancing.
  def peek_byte
    return nil if eos?
    @string.byteslice(@pos, 1).force_encoding('BINARY').ord
  end

  # Scans one byte, returns it as an Integer.
  def scan_byte
    return nil if eos?
    byte_str    = @string.byteslice(@pos, 1)
    @pre_match  = @string.byteslice(0, @pos)
    @pos       += 1
    @post_match = @string.byteslice(@pos..) || ''
    @matched    = byte_str
    @match_data = nil
    byte_str.force_encoding('BINARY').ord
  end

  # Scan for pattern at current position. Advances pos on match.
  def scan(pattern)
    _match(pattern, advance: true, return_str: true)
  end

  # Scan for pattern at current position, return match length or nil. Advances pos.
  def skip(pattern)
    _match(pattern, advance: true, return_str: false)
  end

  # Check for pattern at current position without advancing.
  def check(pattern)
    _match(pattern, advance: false, return_str: true)
  end

  # Return match byte-length without advancing, but sets match state.
  def match?(pattern)
    _match(pattern, advance: false, return_str: false)
  end

  # Scan until pattern is found; return substring up to and including match.
  def scan_until(pattern)
    _match_until(pattern, advance: true, return_str: true)
  end

  # Scan until pattern; return distance in bytes skipped.
  def skip_until(pattern)
    _match_until(pattern, advance: true, return_str: false)
  end

  # Check until pattern without advancing; return substring.
  def check_until(pattern)
    _match_until(pattern, advance: false, return_str: true)
  end

  # Return distance to pattern without advancing.
  def exist?(pattern)
    _match_until(pattern, advance: false, return_str: false)
  end

  # Search for pattern; advance and/or return_str controlled by args.
  def search_full(pattern, advance, return_str)
    _match_until(pattern, advance: advance, return_str: return_str)
  end

  def scan_full(pattern, advance, return_str)
    _match(pattern, advance: advance, return_str: return_str)
  end

  # Scan an integer literal starting at current position. Returns Integer or nil.
  # Supports base: 10 (default) and base: 16.
  def scan_integer(base: 10)
    unless @string.encoding.ascii_compatible?
      raise Encoding::CompatibilityError, "ASCII incompatible encoding: #{@string.encoding.name}"
    end
    unless base == 10 || base == 16
      raise ArgumentError, "Unsupported integer base: #{base}, expected 10 or 16"
    end
    rest_str = @string.byteslice(@pos..) || ''
    if base == 16
      # Match optional sign, then 0x prefix or bare hex digits
      # In 3.1.3: "0x" alone (or followed by non-hex) matches just "0"
      m = rest_str.match(/\A([+-]?)(?:0[xX]([0-9a-fA-F]*)([0-9a-fA-F]+)|([0-9a-fA-F]+))/)
      if m
        if m[2] # 0x prefix form
          hex_part = m[3] || ''
          matched_str = m[1] + '0x' + m[2] + hex_part
          # If 0x prefix with nothing or non-hex after → match just "0"
          if hex_part.empty? && m[2].empty?
            # "0x" with nothing following → match "0"
            matched_str = m[1] + '0'
            val = 0
          else
            val = (m[1] + '0x' + m[2] + hex_part).to_i(16)
          end
        else # bare hex digits
          matched_str = m[1] + m[4]
          val = matched_str.to_i(16)
        end
        @matched    = matched_str
        @match_data = nil
        @pre_match  = @string.byteslice(0, @pos)
        @pos       += matched_str.bytesize
        @post_match = @string.byteslice(@pos..) || ''
        return val
      end
    else
      m = rest_str.match(/\A[+-]?\d+/)
      if m
        matched_str = m[0]
        @matched    = matched_str
        @match_data = nil
        @pre_match  = @string.byteslice(0, @pos)
        @pos       += matched_str.bytesize
        @post_match = @string.byteslice(@pos..) || ''
        return matched_str.to_i
      end
    end
    @matched    = nil
    @match_data = nil
    @pre_match  = nil
    @post_match = nil
    nil
  end

  def pre_match  = @pre_match
  def post_match = @post_match

  def [](n)
    raise TypeError, "no implicit conversion of Range into Integer" if n.is_a?(Range)
    # When no match_data (byte-level ops like get_byte, getch, scan_byte):
    # Integer index 0 returns @matched; name/symbol access raises IndexError.
    unless @match_data
      return nil unless @matched
      if n.is_a?(Integer)
        return n == 0 ? @matched : nil
      end
      raise IndexError, "no named captures"
    end
    @match_data[n]
  end

  def captures
    return nil unless @match_data
    @match_data.captures
  end

  def values_at(*indices)
    return nil unless @match_data
    @match_data.values_at(*indices)
  end

  def named_captures
    return {} unless @match_data
    @match_data.named_captures
  end

  def size
    return nil unless @match_data
    @match_data.size
  end

  def getch
    return nil if eos?
    # Get the character at current byte position (UTF-8 aware)
    char_pos = @string.byteslice(0, @pos).length
    ch = @string[char_pos] || ''
    @pre_match  = @string.byteslice(0, @pos)
    @pos       += ch.bytesize
    @post_match = @string.byteslice(@pos..) || ''
    @matched    = ch
    @match_data = nil
    ch
  end

  def get_byte
    return nil if eos?
    byte = @string.byteslice(@pos, 1)
    @pre_match  = @string.byteslice(0, @pos)
    @pos       += 1
    @post_match = @string.byteslice(@pos..) || ''
    @matched    = byte
    @match_data = nil
    byte
  end

  def unscan
    raise ScanError, "unscan failed: previous match record not exist" unless @match_data || @matched
    @pos       -= @matched.bytesize if @matched
    @matched    = nil
    @match_data = nil
    @pre_match  = nil
    @post_match = nil
    self
  end

  def beginning_of_line?
    @pos == 0 || @string.byteslice(@pos - 1) == "\n"
  end
  alias bol? beginning_of_line?

  def inspect
    total = @string.bytesize
    if eos?
      "#<StringScanner fin>"
    elsif @pos == 0
      # At beginning: show up to 5 chars of rest (no "before" part)
      rest_preview = @string[0, 5] || ''
      rest_str = @string.length > 5 ? "#{rest_preview}..." : rest_preview
      "#<StringScanner #{@pos}/#{total} @ #{rest_str.inspect}>"
    else
      # Show up to 5 chars before pos and up to 5 chars after pos
      char_pos = @string.byteslice(0, @pos).length
      before   = @string[[char_pos - 5, 0].max, [char_pos, 5].min] || ''
      after_ch = @string[char_pos, 5] || ''
      after    = @string.length > char_pos + 5 ? "#{after_ch}..." : after_ch
      "#<StringScanner #{@pos}/#{total} #{before.inspect} @ #{after.inspect}>"
    end
  end

  # Error is the canonical name; ScanError is the legacy alias.
  class Error < StandardError; end
  ScanError = Error

  private

  def _match(pattern, advance:, return_str:)
    unless pattern.is_a?(Regexp) || pattern.is_a?(String)
      raise TypeError, "wrong argument type #{pattern.class} (expected Regexp)"
    end
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    if @fixed_anchor
      # In fixed-anchor mode, match against the full string so ^ and \A have
      # their natural meanings (^ = beginning of line, \A = beginning of string).
      # Use pattern.match(str, pos) so MatchData positions are relative to the
      # full string (not a substring), enabling the md.begin(0) == char_pos check.
      char_pos = @string.byteslice(0, @pos).length
      md = pattern.match(@string, char_pos)
      unless md && md.begin(0) == char_pos
        @matched = @match_data = @pre_match = @post_match = nil
        return nil
      end
    else
      sub = @string.byteslice(@pos..) || ''
      md = pattern.match(sub)
      unless md && md.begin(0) == 0
        @matched = @match_data = @pre_match = @post_match = nil
        return nil
      end
    end
    @matched    = md[0]
    @match_data = md
    @pre_match  = @string.byteslice(0, @pos)
    match_end   = @pos + @matched.bytesize
    @pos        = match_end if advance
    @post_match = @string.byteslice(match_end..) || ''
    return_str ? @matched : @matched.bytesize
  end

  def _match_until(pattern, advance:, return_str:)
    unless pattern.is_a?(Regexp) || pattern.is_a?(String)
      raise TypeError, "wrong argument type #{pattern.class} (expected Regexp)"
    end
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    if @fixed_anchor
      # In fixed-anchor mode, search forward in the full string from @pos.
      # Use pattern.match(str, pos) so MatchData positions are relative to the full string.
      char_pos = @string.byteslice(0, @pos).length
      md = pattern.match(@string, char_pos)
    else
      sub = @string.byteslice(@pos..) || ''
      md = pattern.match(sub)
    end
    unless md
      @matched = @match_data = @pre_match = @post_match = nil
      return nil
    end
    if @fixed_anchor
      # md positions are character-based in the full string
      match_start_bytes = @string[0, md.begin(0)].bytesize - @pos
      match_start_bytes = 0 if match_start_bytes < 0
      end_bytes = match_start_bytes + md[0].bytesize
    else
      # md positions are character-based in sub; convert to bytes
      match_start_bytes = sub[0, md.begin(0)].bytesize
      end_bytes         = match_start_bytes + md[0].bytesize
    end
    @matched    = md[0]
    @match_data = md
    @pre_match  = @string.byteslice(0, @pos + match_start_bytes)
    result      = if return_str
      @string.byteslice(@pos, end_bytes)
    else
      end_bytes
    end
    match_abs_end = @pos + end_bytes
    @pos          = match_abs_end if advance
    @post_match   = @string.byteslice(match_abs_end..) || ''
    result
  end
end

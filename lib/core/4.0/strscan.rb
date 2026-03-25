# Pure-Ruby StringScanner for Frozone.
# Implements the essential StringScanner API used by csv, uri, and other stdlib gems.

class StringScanner
  Id = 'None$Id'.freeze

  attr_reader :string

  def pos = @pos
  alias charpos pos
  def eos?       = @pos >= @string.bytesize
  def rest       = @string[@pos..]
  def rest?      = !eos?
  def rest_size  = @string.bytesize - @pos
  alias restsize rest_size
  def peek(n)    = @string[@pos, n] || ''
  def matched?   = !@matched.nil?
  def matched    = @matched
  def matchedsize = @matched ? @matched.length : nil
  alias matched_size matchedsize
  def to_s = inspect

  def initialize(str, fixed_anchor: false)
    @string       = str.to_s.dup
    @pos          = 0
    @matched      = nil
    @match_data   = nil
    @fixed_anchor = fixed_anchor
  end

  def string=(str)
    @string  = str.to_s.dup
    @pos     = 0
    @matched = nil
    @match_data = nil
    @string
  end

  def pos=(n)
    n = @string.length + n if n < 0
    raise RangeError, "index out of range" if n < 0 || n > @string.bytesize
    @pos = n
  end
  alias pointer= pos=

  def reset
    @pos     = 0
    @matched = nil
    @match_data = nil
    self
  end

  def terminate
    @pos     = @string.bytesize
    @matched = nil
    @match_data = nil
    self
  end
  alias clear terminate

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

  # Return match length without advancing.
  def match?(pattern)
    _match(pattern, advance: false, return_str: false)
  end

  # Scan until pattern is found; return substring up to and including match.
  def scan_until(pattern)
    _match_until(pattern, advance: true, return_str: true)
  end

  # Scan until pattern; return distance skipped.
  def skip_until(pattern)
    _match_until(pattern, advance: true, return_str: false)
  end

  # Check until pattern without advancing; return substring.
  def check_until(pattern)
    _match_until(pattern, advance: false, return_str: true)
  end

  # Search for pattern without advancing; return distance.
  def search_full(pattern, advance, return_str)
    _match_until(pattern, advance: advance, return_str: return_str)
  end

  def scan_full(pattern, advance, return_str)
    _match(pattern, advance: advance, return_str: return_str)
  end

  def pre_match
    return nil unless @match_data
    @match_data.pre_match
  end

  def post_match
    return nil unless @match_data
    @match_data.post_match
  end

  def [](n)
    return nil unless @match_data
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
    ch = @string[@pos]
    @pos += ch.bytesize
    @matched = ch
    @match_data = nil
    ch
  end
  alias get_byte getch

  def unscan
    raise ScanError, "unscan failed: previous match record not exist" unless @match_data || @matched
    @pos -= @matched.bytesize if @matched
    @matched = nil
    @match_data = nil
    self
  end

  def beginning_of_line?
    @pos == 0 || @string[@pos - 1] == "\n"
  end
  alias bol? beginning_of_line?

  def inspect
    if eos?
      "#<StringScanner fin>"
    else
      rest_str = rest.length > 5 ? "#{rest[0, 5]}..." : rest
      before   = @pos > 0 ? (@string[@pos - [5, @pos].min, [5, @pos].min] || '') : ''
      "#<StringScanner #{@pos}/#{@string.bytesize} @ #{before.inspect}...>"
    end
  end

  private

  def _match(pattern, advance:, return_str:)
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    sub = @string[@pos..]
    md = pattern.match(sub)
    if md && md.begin(0) == 0
      @match_data = md
      @matched    = md[0]
      @pos       += md[0].bytesize if advance
      return_str ? @matched : @matched.bytesize
    else
      @matched    = nil
      @match_data = nil
      nil
    end
  end

  def _match_until(pattern, advance:, return_str:)
    pattern = Regexp.new(Regexp.escape(pattern)) if pattern.is_a?(String)
    sub = @string[@pos..]
    md = pattern.match(sub)
    if md
      end_pos = md.begin(0) + md[0].length
      @match_data = md
      @matched    = md[0]
      result      = return_str ? sub[0, end_pos] : end_pos
      @pos       += end_pos if advance
      result
    else
      @matched    = nil
      @match_data = nil
      nil
    end
  end

  class ScanError < StandardError; end
end

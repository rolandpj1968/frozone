# Frozone stub: load the stdlib random/formatter.rb, then add random_number
# which is defined in the C extension but missing from the pure-Ruby file.
#
# This file is found first (core path precedes stdlib) so it can wrap the real one.

# Find and load the actual stdlib formatter (skip this file itself)
_frozone_core_dir = File.dirname(File.dirname(__FILE__))
_stdlib_formatter = $LOAD_PATH.map { |d| File.join(d, 'random', 'formatter.rb') }
                               .find { |f| f != __FILE__ && !f.start_with?(_frozone_core_dir) && File.exist?(f) }
require _stdlib_formatter if _stdlib_formatter

# Add random_number to Random::Formatter (C extension normally provides this).
module Random::Formatter
  # Returns a random number. If +n+ is nil or 0, returns a Float in [0, 1).
  # If +n+ is a positive Integer, returns an Integer in [0, n).
  # If +n+ is a Range, returns a value within that range.
  # Negative numbers treated as if 0 (returns float).
  def random_number(n = nil)
    if n.nil?
      __secure_float__
    elsif n.is_a?(Integer)
      return __secure_float__ if n <= 0
      __secure_int__(n)
    elsif n.is_a?(Float)
      return __secure_float__ if n <= 0.0
      __secure_float__ * n
    elsif n.is_a?(Range)
      beg = n.begin
      fin = n.end
      if beg.is_a?(Integer) && fin.is_a?(Integer)
        span = fin - beg + (n.exclude_end? ? 0 : 1)
        return beg if span <= 0
        beg + __secure_int__(span)
      else
        beg_f = beg.to_f
        fin_f = fin.to_f
        span  = fin_f - beg_f
        beg_f + __secure_float__ * span
      end
    else
      raise ArgumentError, "invalid argument - #{n.inspect}"
    end
  end

  # rand delegates to random_number
  def rand(n = nil)
    random_number(n)
  end

  private

  def __secure_float__
    bytes = random_bytes(8).unpack1('Q>')
    bytes.to_f / (2**64)
  end

  def __secure_int__(n)
    bits  = n.bit_length
    nbytes = (bits + 7) / 8
    mask  = (1 << bits) - 1
    loop do
      val = random_bytes(nbytes).unpack1('H*').to_i(16) & mask
      return val if val < n
    end
  end
end

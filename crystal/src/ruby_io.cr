# Minimal IO wrapper for compiled Ruby programs.
# Wraps Crystal's IO objects (STDIN, STDOUT, STDERR) as RubyObject.

class RubyIO < RubyObject
  @io : IO

  def initialize(@io : IO)
  end

  def read : RubyObject
    content = @io.gets_to_end
    RubyString.new(content)
  end

  def gets(*args) : RubyObject
    line = @io.gets
    line ? RubyString.new(line) : RubyNil::INSTANCE
  end

  def puts(*args) : RubyObject
    args.each { |a| @io.puts(a.to_s) }
    RubyNil::INSTANCE
  end

  def print(*args) : RubyObject
    args.each { |a| @io.print(a.to_s) }
    RubyNil::INSTANCE
  end

  def write(str : RubyObject) : RubyObject
    @io.print(str.to_s)
    RubyInteger.new(str.to_s.bytesize.to_i64)
  end

  def flush : RubyObject
    @io.flush
    self
  end

  def to_s : String; "#<IO>"; end
  def inspect : String; "#<IO>"; end
end

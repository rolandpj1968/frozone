class StringIO
  def string = @data
  def readline = gets || raise(EOFError, "end of file reached")
  def eof? = @pos >= @data.length

  def initialize(str = "", mode = "r+")
    @data = str.dup
    @pos = 0
    @mode = mode
  end

  def gets(sep = $/, limit = nil)
    if @pos >= @data.length
      $_ = nil
      return nil
    end
    if sep.nil?
      result = @data[@pos..]
      @pos = @data.length
    else
      idx = @data.index(sep, @pos)
      if idx.nil?
        result = @data[@pos..]
        @pos = @data.length
      else
        result = @data[@pos..idx]
        @pos = idx + sep.length
      end
    end
    $_ = result
    result
  end
  def rewind; @pos = 0; self; end
  def pos = @pos
  def pos=(n); @pos = n; end

  def read(n = nil)
    return @data[@pos..] if n.nil?
    result = @data[@pos, n] || ""
    @pos += result.length
    result
  end

  def write(s) = @data += s.to_s
  def puts(*args) = args.each { |a| write(a.to_s + "\n") }
  def print(*args) = args.each { |a| write(a.to_s) }
  def truncate(n = 0); @data = @data[0, n] || ""; @pos = n if @pos > n; 0; end
  def close = self
  def closed? = false

  def each_line(sep = $/, &block)
    while (line = gets(sep))
      block.call(line)
    end
    self
  end

  alias each each_line
end

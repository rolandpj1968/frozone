class Encoding
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_s = @name
  def inspect = "#<Encoding:#{@name}>"
  def ==(other) = other.is_a?(Encoding) && other.name == @name

  UTF_8    = new("UTF-8")
  US_ASCII = new("US-ASCII")
  ASCII    = US_ASCII
  BINARY   = new("ASCII-8BIT")
  ASCII_8BIT = BINARY
  EUC_JP   = new("EUC-JP")
  ISO_8859_1 = new("ISO-8859-1")
  UTF_16   = new("UTF-16")
  UTF_16BE = new("UTF-16BE")
  UTF_16LE = new("UTF-16LE")
  UTF_32   = new("UTF-32")
  UTF_32BE = new("UTF-32BE")
  UTF_32LE = new("UTF-32LE")
  SHIFT_JIS = new("Shift_JIS")
  Windows_1252 = new("Windows-1252")

  def self.default_external = UTF_8
  def self.default_external=(enc) = enc
  def self.default_internal = nil
  def self.default_internal=(enc) = enc
  def self.find(name) = UTF_8
  def self.list = [UTF_8, US_ASCII, BINARY, EUC_JP, ISO_8859_1]
  def self.aliases = {}
end

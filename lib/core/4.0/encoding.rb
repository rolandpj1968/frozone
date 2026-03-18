class Encoding
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_s = @name
  def inspect = "#<Encoding:#{@name}>"
  def ==(other) = other.is_a?(Encoding) && other.name == @name
  alias eql? ==

  # Non-ASCII-compatible encodings (UTF-16 and UTF-32 use multi-byte for ASCII chars)
  NON_ASCII_COMPATIBLE = %w[UTF-16 UTF-16BE UTF-16LE UTF-32 UTF-32BE UTF-32LE].freeze
  # Dummy encodings need BOM or explicit byte order to be usable
  DUMMY_ENCODINGS = %w[UTF-16 UTF-32].freeze

  def ascii_compatible?
    !NON_ASCII_COMPATIBLE.include?(@name)
  end

  def dummy?
    DUMMY_ENCODINGS.include?(@name)
  end

  def ascii_only?
    @name == "US-ASCII"
  end

  UTF_8    = new("UTF-8")
  US_ASCII = new("US-ASCII")
  ASCII    = US_ASCII
  BINARY   = new("ASCII-8BIT")
  ASCII_8BIT = BINARY
  EUC_JP   = new("EUC-JP")
  ISO_8859_1  = new("ISO-8859-1")
  ISO8859_1   = ISO_8859_1
  ISO_8859_2  = new("ISO-8859-2")
  ISO8859_2   = ISO_8859_2
  ISO_8859_3  = new("ISO-8859-3")
  ISO8859_3   = ISO_8859_3
  ISO_8859_4  = new("ISO-8859-4")
  ISO8859_4   = ISO_8859_4
  ISO_8859_5  = new("ISO-8859-5")
  ISO8859_5   = ISO_8859_5
  ISO_8859_6  = new("ISO-8859-6")
  ISO8859_6   = ISO_8859_6
  ISO_8859_7  = new("ISO-8859-7")
  ISO8859_7   = ISO_8859_7
  ISO_8859_8  = new("ISO-8859-8")
  ISO8859_8   = ISO_8859_8
  ISO_8859_9  = new("ISO-8859-9")
  ISO8859_9   = ISO_8859_9
  ISO_8859_10 = new("ISO-8859-10")
  ISO8859_10  = ISO_8859_10
  ISO_8859_11 = new("ISO-8859-11")
  ISO8859_11  = ISO_8859_11
  ISO_8859_13 = new("ISO-8859-13")
  ISO8859_13  = ISO_8859_13
  ISO_8859_14 = new("ISO-8859-14")
  ISO8859_14  = ISO_8859_14
  ISO_8859_15 = new("ISO-8859-15")
  ISO8859_15  = ISO_8859_15
  ISO_8859_16 = new("ISO-8859-16")
  ISO8859_16  = ISO_8859_16
  UTF_16   = new("UTF-16")
  UTF_16BE = new("UTF-16BE")
  UTF_16LE = new("UTF-16LE")
  UTF_32   = new("UTF-32")
  UTF_32BE = new("UTF-32BE")
  UTF_32LE = new("UTF-32LE")
  SHIFT_JIS    = new("Shift_JIS")
  Shift_JIS    = SHIFT_JIS
  Windows_31J  = new("Windows-31J")
  CP932        = Windows_31J
  Windows_1250 = new("Windows-1250")
  Windows_1251 = new("Windows-1251")
  Windows_1252 = new("Windows-1252")
  Windows_1253 = new("Windows-1253")
  Windows_1254 = new("Windows-1254")
  Windows_1255 = new("Windows-1255")
  Windows_1256 = new("Windows-1256")
  Windows_1257 = new("Windows-1257")
  Windows_1258 = new("Windows-1258")
  Big5     = new("Big5")
  BIG5     = Big5
  Big5_HKSCS = new("Big5-HKSCS")
  Big5_UAO   = new("Big5-UAO")
  IBM437   = new("IBM437")
  IBM775   = new("IBM775")
  IBM852   = new("IBM852")
  IBM855   = new("IBM855")
  IBM857   = new("IBM857")
  IBM860   = new("IBM860")
  IBM861   = new("IBM861")
  IBM862   = new("IBM862")
  IBM863   = new("IBM863")
  IBM864   = new("IBM864")
  IBM865   = new("IBM865")
  IBM866   = new("IBM866")
  IBM869   = new("IBM869")
  KOI8_R      = new("KOI8-R")
  KOI8_U      = new("KOI8-U")
  CP65001     = new("CP65001")
  Emacs_Mule  = new("Emacs-Mule")
  ISO_2022_JP = new("ISO-2022-JP")
  ISO_2022_JP_2 = new("ISO-2022-JP-2")
  ISO_2022_JP_KDDI = new("ISO-2022-JP-KDDI")
  UTF8_MAC    = new("UTF8-MAC")
  EUCJP_MS    = new("eucJP-ms")
  CP51932     = new("CP51932")
  GB18030     = new("GB18030")
  GBK         = new("GBK")
  GB2312      = new("GB2312")
  TIS_620     = new("TIS-620")
  UTF_7       = new("UTF-7")
  CESU_8      = new("CESU-8")

  CompatibilityError        = Class.new(EncodingError)
  ConverterNotFoundError    = Class.new(EncodingError)
  InvalidByteSequenceError  = Class.new(EncodingError)
  UndefinedConversionError  = Class.new(EncodingError)

  ALL = [UTF_8, US_ASCII, BINARY, EUC_JP, ISO_8859_1, ISO_8859_2, ISO_8859_3,
         ISO_8859_4, ISO_8859_5, ISO_8859_6, ISO_8859_7, ISO_8859_8, ISO_8859_9,
         ISO_8859_10, ISO_8859_11, ISO_8859_13, ISO_8859_14, ISO_8859_15, ISO_8859_16,
         UTF_16, UTF_16BE, UTF_16LE, UTF_32, UTF_32BE, UTF_32LE,
         SHIFT_JIS, Windows_31J, Windows_1250, Windows_1251, Windows_1252,
         Windows_1253, Windows_1254, Windows_1255, Windows_1256, Windows_1257, Windows_1258,
         Big5, Big5_HKSCS, Big5_UAO,
         IBM437, IBM775, IBM852, IBM855, IBM857, IBM860, IBM861, IBM862,
         IBM863, IBM864, IBM865, IBM866, IBM869,
         KOI8_R, KOI8_U, CP65001,
         Emacs_Mule, ISO_2022_JP, ISO_2022_JP_2, ISO_2022_JP_KDDI,
         UTF8_MAC, EUCJP_MS, CP51932, GB18030, GBK, GB2312, TIS_620, UTF_7, CESU_8].freeze

  @default_external = UTF_8
  @default_internal = nil

  def self.default_external
    @default_external || UTF_8
  end

  def self.default_external=(enc)
    @default_external = enc.is_a?(Encoding) ? enc : find(enc.to_s)
  end

  def self.default_internal
    @default_internal
  end

  def self.default_internal=(enc)
    @default_internal = enc.is_a?(Encoding) ? enc : (enc ? find(enc.to_s) : nil)
  end

  def self.find(name)
    return default_external if name == "locale" || name == "external" || name == "filesystem"
    return default_internal || UTF_8 if name == "internal"
    name_s = name.to_s
    ALL.find { |e| e.name.casecmp(name_s) == 0 } ||
      begin
        canonical = aliases[name_s] || aliases.find { |k, _| k.casecmp(name_s) == 0 }&.last
        if canonical
          ALL.find { |e| e.name.casecmp(canonical) == 0 } ||
            raise(ArgumentError, "unknown encoding name - #{name_s}")
        else
          raise(ArgumentError, "unknown encoding name - #{name_s}")
        end
      end
  end

  def self.list = ALL
  def self.aliases = {
    "ASCII" => "US-ASCII", "ANSI_X3.4-1968" => "US-ASCII",
    "BINARY" => "ASCII-8BIT", "CP65001" => "UTF-8"
  }

  class Converter
    def self.new(from_enc, to_enc, *_opts)
      from = from_enc.is_a?(Encoding) ? from_enc.name : from_enc.to_s
      to   = to_enc.is_a?(Encoding) ? to_enc.name : to_enc.to_s
      begin
        # Try creating the converter via MRI to see if it's possible
        Intrinsics.encoding_converter_check(from, to)
      rescue Encoding::ConverterNotFoundError => e
        raise Encoding::ConverterNotFoundError, e.message
      end
      super()
    end
  end
end

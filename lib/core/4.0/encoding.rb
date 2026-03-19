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

  def replicate(new_name)
    Encoding.new(new_name)
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
  SJIS         = SHIFT_JIS
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
  ISO2022_JP  = ISO_2022_JP
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
  Stateless_ISO_2022_JP = new("stateless-ISO-2022-JP")
  MacCyrillic  = new("macCyrillic")
  MacJapanese  = new("MacJapanese")
  MacThai      = new("MacThai")

  CompatibilityError        = Class.new(EncodingError)
  ConverterNotFoundError    = Class.new(EncodingError)
  InvalidByteSequenceError  = Class.new(EncodingError)
  UndefinedConversionError  = Class.new(EncodingError)

  class InvalidByteSequenceError
    def source_encoding_name
      @source_encoding_name&.to_s
    end

    def destination_encoding_name
      @destination_encoding_name&.to_s
    end

    def source_encoding
      @source_encoding
    end

    def destination_encoding
      @destination_encoding
    end

    def error_bytes
      @error_bytes
    end

    def readagain_bytes
      @readagain_bytes
    end

    def incomplete_input?
      @incomplete_input
    end
  end

  class UndefinedConversionError
    def source_encoding_name
      @source_encoding_name&.to_s
    end

    def destination_encoding_name
      @destination_encoding_name&.to_s
    end

    def source_encoding
      @source_encoding
    end

    def destination_encoding
      @destination_encoding
    end

    def error_char
      @error_char
    end
  end

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
         UTF8_MAC, EUCJP_MS, CP51932, GB18030, GBK, GB2312, TIS_620, UTF_7, CESU_8,
         Stateless_ISO_2022_JP, MacCyrillic, MacJapanese, MacThai].freeze

  # Complete alias table matching MRI Ruby
  ALIASES = {
    "ASCII"             => "US-ASCII",
    "ANSI_X3.4-1968"   => "US-ASCII",
    "646"               => "US-ASCII",
    "BINARY"            => "ASCII-8BIT",
    "CP65001"           => "UTF-8",
    "UTF8"              => "UTF-8",
    "SJIS"              => "Shift_JIS",
    "Shift-JIS"         => "Shift_JIS",
    "CP932"             => "Windows-31J",
    "PCK"               => "Windows-31J",
    "EUC_JP"            => "EUC-JP",
    "eucJP"             => "EUC-JP",
    "eucJP-ms"          => "eucJP-ms",
    "UTF-16"            => "UTF-16",
    "UCS-2BE"           => "UTF-16BE",
    "UCS-4BE"           => "UTF-32BE",
    "UCS-4LE"           => "UTF-32LE",
    "ISO8859-1"         => "ISO-8859-1",
    "ISO8859-2"         => "ISO-8859-2",
    "ISO8859-3"         => "ISO-8859-3",
    "ISO8859-4"         => "ISO-8859-4",
    "ISO8859-5"         => "ISO-8859-5",
    "ISO8859-6"         => "ISO-8859-6",
    "ISO8859-7"         => "ISO-8859-7",
    "ISO8859-8"         => "ISO-8859-8",
    "ISO8859-9"         => "ISO-8859-9",
    "ISO8859-10"        => "ISO-8859-10",
    "ISO8859-11"        => "ISO-8859-11",
    "ISO8859-13"        => "ISO-8859-13",
    "ISO8859-14"        => "ISO-8859-14",
    "ISO8859-15"        => "ISO-8859-15",
    "ISO8859-16"        => "ISO-8859-16",
    "ISO-8859-14"       => "ISO-8859-14",
    "KOI8-R"            => "KOI8-R",
    "KOI8-U"            => "KOI8-U",
    "Big5-HKSCS"        => "Big5-HKSCS",
    "GB2312"            => "GBK",
    "macCyrillic"       => "macCyrillic",
    "stateless-ISO-2022-JP" => "stateless-ISO-2022-JP",
  }.freeze

  @default_external = UTF_8
  @default_internal = nil

  def self.default_external
    @default_external || UTF_8
  end

  def self.default_external=(enc)
    @default_external = enc.is_a?(Encoding) ? enc : find(enc.to_s)
    # Sync to MRI so that native Ruby IO objects track Frozone's default_external.
    Intrinsics.encoding_set_default_external(@default_external.name)
  end

  def self.default_internal
    @default_internal
  end

  def self.default_internal=(enc)
    @default_internal = enc.is_a?(Encoding) ? enc : (enc ? find(enc.to_s) : nil)
    # Sync to MRI so that native Ruby IO objects track Frozone's default_internal.
    Intrinsics.encoding_set_default_internal(@default_internal&.name)
  end

  def self.find(name)
    raise TypeError, "no implicit conversion of #{name.class} into String" if name.is_a?(Symbol)
    return name if name.is_a?(Encoding)
    name_s = name.respond_to?(:to_str) ? name.to_str : name.to_s
    return default_external if name_s == "locale" || name_s == "external" || name_s == "filesystem"
    return default_internal if name_s == "internal"
    ALL.find { |e| e.name.casecmp(name_s) == 0 } ||
      begin
        canonical = ALIASES[name_s] || ALIASES.find { |k, _| k.casecmp(name_s) == 0 }&.last
        if canonical
          ALL.find { |e| e.name.casecmp(canonical) == 0 } ||
            raise(ArgumentError, "unknown encoding name - #{name_s}")
        else
          raise(ArgumentError, "unknown encoding name - #{name_s}")
        end
      end
  end

  def self.list = ALL

  def self.aliases
    base = ALIASES.dup
    base["external"] = default_external.name
    base["locale"] = locale_charmap || default_external.name
    base["filesystem"] = default_external.name
    base["internal"] = default_internal ? default_internal.name : default_external.name
    base
  end

  def self.name_list
    names = ALL.map(&:name)
    names + ALIASES.keys
  end

  def self.locale_charmap
    Intrinsics.locale_charmap
  end

  def self.compatible?(a, b)
    Intrinsics.encoding_compatible(a, b)
  end

  class Converter
    INVALID_MASK               = 15
    INVALID_REPLACE            = 2
    UNDEF_MASK                 = 240
    UNDEF_REPLACE              = 32
    UNDEF_HEX_CHARREF          = 48
    PARTIAL_INPUT              = 131072
    AFTER_OUTPUT               = 262144
    UNIVERSAL_NEWLINE_DECORATOR = 256
    CRLF_NEWLINE_DECORATOR     = 4096
    CR_NEWLINE_DECORATOR       = 8192
    XML_TEXT_DECORATOR         = 32768
    XML_ATTR_CONTENT_DECORATOR = 65536
    XML_ATTR_QUOTE_DECORATOR   = 1048576

    def self.new(from_enc, to_enc, opts = nil)
      from = from_enc.is_a?(Encoding) ? from_enc.name : from_enc.to_str
      to   = to_enc.is_a?(Encoding) ? to_enc.name : to_enc.to_str
      # Validate replacement if provided
      if opts.is_a?(Hash) && opts.key?(:replace)
        repl = opts[:replace]
        unless repl.nil? || repl.is_a?(String)
          if repl.respond_to?(:to_str)
            repl_s = repl.to_str
            raise TypeError, "no implicit conversion of #{repl.class} into String" unless repl_s.is_a?(String)
          else
            raise TypeError, "no implicit conversion of #{repl.class} into String"
          end
        end
      end
      if opts.nil?
        Intrinsics.encoding_converter_new(from, to)
      else
        Intrinsics.encoding_converter_new(from, to, opts)
      end
    end

    def self.asciicompat_encoding(enc)
      enc_arg = enc.is_a?(Encoding) ? enc : enc
      Intrinsics.encoding_converter_asciicompat_encoding(enc_arg)
    end

    def self.search_convpath(from_enc, to_enc, opts = nil)
      from = from_enc.is_a?(Encoding) ? from_enc.name : from_enc.to_s
      to   = to_enc.is_a?(Encoding) ? to_enc.name : to_enc.to_s
      if opts.nil?
        Intrinsics.encoding_converter_search_convpath(from, to)
      else
        Intrinsics.encoding_converter_search_convpath(from, to, opts)
      end
    end

    def source_encoding
      Intrinsics.encoding_converter_source_encoding(self)
    end

    def destination_encoding
      Intrinsics.encoding_converter_destination_encoding(self)
    end

    def inspect
      Intrinsics.encoding_converter_inspect(self)
    end

    def convpath
      Intrinsics.encoding_converter_convpath(self)
    end

    def replacement
      Intrinsics.encoding_converter_replacement(self)
    end

    def replacement=(val)
      raise TypeError, "no implicit conversion of #{val.class} into String" unless val.is_a?(String)
      Intrinsics.encoding_converter_replacement_set(self, val)
    end

    def convert(src)
      Intrinsics.encoding_converter_convert(self, src)
    end

    def finish
      Intrinsics.encoding_converter_finish(self)
    end

    def primitive_convert(src, dest, offset = nil, size = nil, opts = nil)
      if opts.nil?
        Intrinsics.encoding_converter_primitive_convert(self, src, dest, offset, size)
      else
        Intrinsics.encoding_converter_primitive_convert(self, src, dest, offset, size, opts)
      end
    end

    def primitive_errinfo
      Intrinsics.encoding_converter_primitive_errinfo(self)
    end

    def last_error
      Intrinsics.encoding_converter_last_error(self)
    end

    def insert_output(str)
      Intrinsics.encoding_converter_insert_output(self, str)
    end

    def putback(n = nil)
      if n.nil?
        Intrinsics.encoding_converter_putback(self)
      else
        Intrinsics.encoding_converter_putback(self, n)
      end
    end
  end
end

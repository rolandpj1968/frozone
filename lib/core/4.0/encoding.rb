class Encoding
  attr_reader :name

  def to_s = @name
  def ==(other) = other.is_a?(Encoding) && other.name == @name
  alias eql? ==

  def initialize(name)
    @name = name
  end

  def inspect
    if @name == "ASCII-8BIT"
      "#<Encoding:BINARY (ASCII-8BIT)>"
    elsif dummy?
      "#<Encoding:#{@name} (dummy)>"
    else
      "#<Encoding:#{@name}>"
    end
  end

  def names
    result = [@name]
    # Add all static aliases that point to this encoding's name
    ALL_ALIASES.each do |a, canonical|
      result << a if canonical == @name && !result.include?(a)
    end
    # Add dynamic aliases (external, locale, filesystem, internal)
    dyn = Encoding.aliases
    %w[external locale filesystem internal].each do |pseudo|
      result << pseudo if dyn[pseudo] == @name && !result.include?(pseudo)
    end
    result
  end
  # Non-ASCII-compatible encodings (multi-byte for ASCII chars, or stateful/escape-based)
  NON_ASCII_COMPATIBLE = %w[
    UTF-16 UTF-16BE UTF-16LE UTF-32 UTF-32BE UTF-32LE
    UTF-7 ISO-2022-JP ISO-2022-JP-2 ISO-2022-JP-KDDI
    CP50220 CP50221 IBM037
  ].freeze
  # Dummy encodings: need BOM, byte order info, or are stateful
  DUMMY_ENCODINGS = %w[
    UTF-16 UTF-32
    ISO-2022-JP ISO-2022-JP-2 ISO-2022-JP-KDDI
    UTF-7 CP50220 CP50221 IBM037
  ].freeze

  def ascii_compatible? = !NON_ASCII_COMPATIBLE.include?(@name)
  def dummy? = DUMMY_ENCODINGS.include?(@name)
  def ascii_only? = @name == "US-ASCII"
  def replicate(new_name) = Encoding.new(new_name)
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
  SJIS         = Windows_31J  # MRI: Encoding::SJIS is Windows-31J, not Shift_JIS
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
  CP65001     = UTF_8  # alias for UTF-8 (Windows code page 65001)
  Emacs_Mule  = new("Emacs-Mule")
  ISO_2022_JP = new("ISO-2022-JP")
  ISO2022_JP  = ISO_2022_JP
  ISO_2022_JP_2 = new("ISO-2022-JP-2")
  ISO_2022_JP_KDDI = new("ISO-2022-JP-KDDI")
  CP50220     = new("CP50220")
  CP50221     = new("CP50221")
  IBM037      = new("IBM037")
  UTF8_MAC    = new("UTF8-MAC")
  EUCJP_MS    = new("eucJP-ms")
  CP51932     = new("CP51932")
  GB18030     = new("GB18030")
  GBK         = new("GBK")
  GB2312      = GBK  # alias for GBK
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
    def source_encoding_name = @source_encoding_name&.to_s
    def destination_encoding_name = @destination_encoding_name&.to_s
    def source_encoding = @source_encoding
    def destination_encoding = @destination_encoding
    def error_bytes = @error_bytes
    def readagain_bytes = @readagain_bytes
    def incomplete_input? = @incomplete_input
  end

  class UndefinedConversionError
    def source_encoding_name = @source_encoding_name&.to_s
    def destination_encoding_name = @destination_encoding_name&.to_s
    def source_encoding = @source_encoding
    def destination_encoding = @destination_encoding
    def error_char = @error_char
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
         KOI8_R, KOI8_U,
         Emacs_Mule, ISO_2022_JP, ISO_2022_JP_2, ISO_2022_JP_KDDI, CP50220, CP50221, IBM037,
         UTF8_MAC, EUCJP_MS, CP51932, GB18030, GBK, TIS_620, UTF_7, CESU_8,
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

  # Reverse alias table: canonical name → list of aliases (for #names method)
  ALL_ALIASES = ALIASES.freeze

  @default_external = UTF_8
  @default_internal = nil

  def self.list = ALL

  def self.default_external
    @default_external || UTF_8
  end

  def self.default_external=(enc)
    raise ArgumentError, "default external encoding cannot be nil" if enc.nil?
    if enc.is_a?(Encoding)
      @default_external = enc
    elsif enc.is_a?(String)
      @default_external = find(enc)
    elsif enc.respond_to?(:to_str)
      @default_external = find(enc.to_str)
    else
      raise TypeError, "no implicit conversion of #{enc.class} into String"
    end
    # Sync to MRI so that native Ruby IO objects track Frozone's default_external.
    Intrinsics.encoding_set_default_external(@default_external.name)
  end

  def self.default_internal
    @default_internal
  end

  def self.default_internal=(enc)
    if enc.nil?
      @default_internal = nil
    elsif enc.is_a?(Encoding)
      @default_internal = enc
    elsif enc.is_a?(String)
      @default_internal = find(enc)
    elsif enc.respond_to?(:to_str)
      result = enc.to_str
      raise TypeError, "no implicit conversion of #{result.class} into String" unless result.is_a?(String)
      @default_internal = find(result)
    else
      raise TypeError, "no implicit conversion of #{enc.class} into String"
    end
    # Sync to MRI so that native Ruby IO objects track Frozone's default_internal.
    Intrinsics.encoding_set_default_internal(@default_internal&.name)
  end

  def self.find(name)
    raise TypeError, "no implicit conversion of #{name.class} into String" if name.is_a?(Symbol)
    return name if name.is_a?(Encoding)
    name_s = name.respond_to?(:to_str) ? name.to_str : name.to_s
    name_lower = name_s.downcase
    return default_external if name_lower == "locale" || name_lower == "external" || name_lower == "filesystem"
    return default_internal if name_lower == "internal"
    ALL.find { |e| e.name.downcase == name_lower } ||
      begin
        canonical = ALIASES[name_s] || ALIASES.find { |k, _| k.downcase == name_lower }&.last
        if canonical
          canonical_lower = canonical.downcase
          ALL.find { |e| e.name.downcase == canonical_lower } ||
            raise(ArgumentError, "unknown encoding name - #{name_s}")
        else
          raise(ArgumentError, "unknown encoding name - #{name_s}")
        end
      end
  end

  def self.aliases
    base = ALIASES.dup
    base["external"] = default_external.name
    base["locale"] = locale_charmap || default_external.name
    base["filesystem"] = default_external.name
    base["internal"] = default_internal.name if default_internal
    base
  end

  def self.name_list
    names = ALL.map(&:name)
    all_aliases = ALIASES.keys + ["external", "locale", "filesystem"]
    all_aliases << "internal" if default_internal
    names + all_aliases
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

    def source_encoding = Intrinsics.encoding_converter_source_encoding(self)
    def destination_encoding = Intrinsics.encoding_converter_destination_encoding(self)
    def inspect = Intrinsics.encoding_converter_inspect(self)
    def convpath = Intrinsics.encoding_converter_convpath(self)
    def replacement = Intrinsics.encoding_converter_replacement(self)
    def convert(src) = Intrinsics.encoding_converter_convert(self, src)
    def finish = Intrinsics.encoding_converter_finish(self)
    def primitive_errinfo = Intrinsics.encoding_converter_primitive_errinfo(self)
    def last_error = Intrinsics.encoding_converter_last_error(self)
    def insert_output(str) = Intrinsics.encoding_converter_insert_output(self, str)

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
      enc_arg = if enc.is_a?(Encoding) || enc.is_a?(String)
        enc
      elsif enc.respond_to?(:to_str)
        enc.to_str
      else
        enc
      end
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

    def replacement=(val)
      raise TypeError, "no implicit conversion of #{val.class} into String" unless val.is_a?(String)
      Intrinsics.encoding_converter_replacement_set(self, val)
    end

    def primitive_convert(src, dest, offset = nil, size = nil, opts = nil)
      if opts.nil?
        Intrinsics.encoding_converter_primitive_convert(self, src, dest, offset, size)
      else
        Intrinsics.encoding_converter_primitive_convert(self, src, dest, offset, size, opts)
      end
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

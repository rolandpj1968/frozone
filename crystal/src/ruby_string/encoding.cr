# RubyEncoding — a comprehensive enum of Ruby encoding names.
#
# Design principles:
#   - Each member corresponds to one canonical Ruby encoding name.
#   - `.from_name` does case-insensitive lookup and resolves common aliases.
#   - `#name` returns the canonical MRI name (e.g. "UTF-8", "ASCII-8BIT").
#   - `#ascii_compatible?` is false only for UTF-16 and UTF-32 families.
#   - `#single_byte?` is true for ASCII_8BIT, US_ASCII, and all ISO-8859-*,
#     Windows-*, KOI8-*, IBM/CP/Mac single-byte encodings.
#
# Adding a new encoding later:
#   1. Add a member to the enum.
#   2. Add its canonical name to `#name`.
#   3. Update `#ascii_compatible?` and `#single_byte?` if needed.
#   4. Add entries to RUBY_ENCODING_ALIASES below.

enum RubyEncoding
  # -------------------------------------------------------------------------
  # Unicode / ASCII families
  # -------------------------------------------------------------------------
  UTF_8        # UTF-8
  ASCII_8BIT   # ASCII-8BIT (BINARY)
  US_ASCII     # US-ASCII (ASCII)
  UTF_16LE     # UTF-16LE
  UTF_16BE     # UTF-16BE
  UTF_32LE     # UTF-32LE
  UTF_32BE     # UTF-32BE
  UTF_8_MAC    # UTF8-MAC (NFD-normalised UTF-8, used on macOS HFS+)

  # -------------------------------------------------------------------------
  # ISO-8859 family (Latin, Greek, Cyrillic, etc.)
  # -------------------------------------------------------------------------
  ISO_8859_1
  ISO_8859_2
  ISO_8859_3
  ISO_8859_4
  ISO_8859_5
  ISO_8859_6
  ISO_8859_7
  ISO_8859_8
  ISO_8859_9
  ISO_8859_10
  ISO_8859_11
  ISO_8859_13
  ISO_8859_14
  ISO_8859_15
  ISO_8859_16

  # -------------------------------------------------------------------------
  # Windows code pages
  # -------------------------------------------------------------------------
  WINDOWS_874
  WINDOWS_1250
  WINDOWS_1251
  WINDOWS_1252
  WINDOWS_1253
  WINDOWS_1254
  WINDOWS_1255
  WINDOWS_1256
  WINDOWS_1257

  # -------------------------------------------------------------------------
  # IBM / OEM code pages
  # -------------------------------------------------------------------------
  IBM437
  IBM720
  IBM737
  IBM775
  IBM852
  IBM855
  IBM857
  IBM860
  IBM861
  IBM862
  IBM863
  IBM864
  IBM865
  IBM866
  IBM869
  CP850
  CP852
  CP855

  # -------------------------------------------------------------------------
  # Mac OS single-byte encodings
  # -------------------------------------------------------------------------
  MACCROATIAN
  MACCYRILLIC
  MACGREEK
  MACICELAND
  MACROMAN
  MACROMANIA
  MACTURKISH
  MACUKRAINE

  # -------------------------------------------------------------------------
  # KOI8 / TIS family
  # -------------------------------------------------------------------------
  KOI8_R
  KOI8_U
  TIS_620

  # -------------------------------------------------------------------------
  # Japanese (multi-byte)
  # -------------------------------------------------------------------------
  EUC_JP
  SHIFT_JIS
  WINDOWS_31J   # Windows-31J (CP932, a Microsoft extension of Shift_JIS)

  # -------------------------------------------------------------------------
  # Korean
  # -------------------------------------------------------------------------
  EUC_KR
  CP949

  # -------------------------------------------------------------------------
  # Chinese
  # -------------------------------------------------------------------------
  GBK
  GB18030
  BIG5
  BIG5_HKSCS

  # -------------------------------------------------------------------------
  # Sentinel for unrecognised encodings
  # -------------------------------------------------------------------------
  UNKNOWN

  # =========================================================================
  # Class-level methods
  # =========================================================================

  # Return the RubyEncoding for the given name string.
  # Lookup is case-insensitive and handles common aliases.
  # Returns UNKNOWN if not recognised.
  def self.from_name(name : String) : RubyEncoding
    # Normalise: upper-case, collapse hyphens/underscores/spaces to underscore.
    key = name.upcase.gsub('-', '_').gsub(' ', '_')
    RUBY_ENCODING_ALIASES[key]? || UNKNOWN
  end

  # Convenience alias: BINARY => ASCII_8BIT
  def self.binary : RubyEncoding
    ASCII_8BIT
  end

  # Convenience alias: ASCII => US_ASCII
  def self.ascii : RubyEncoding
    US_ASCII
  end

  # =========================================================================
  # Instance methods
  # =========================================================================

  # Return the canonical MRI encoding name string.
  def name : String
    case self
    when UTF_8        then "UTF-8"
    when ASCII_8BIT   then "ASCII-8BIT"
    when US_ASCII     then "US-ASCII"
    when UTF_16LE     then "UTF-16LE"
    when UTF_16BE     then "UTF-16BE"
    when UTF_32LE     then "UTF-32LE"
    when UTF_32BE     then "UTF-32BE"
    when UTF_8_MAC    then "UTF8-MAC"
    when ISO_8859_1   then "ISO-8859-1"
    when ISO_8859_2   then "ISO-8859-2"
    when ISO_8859_3   then "ISO-8859-3"
    when ISO_8859_4   then "ISO-8859-4"
    when ISO_8859_5   then "ISO-8859-5"
    when ISO_8859_6   then "ISO-8859-6"
    when ISO_8859_7   then "ISO-8859-7"
    when ISO_8859_8   then "ISO-8859-8"
    when ISO_8859_9   then "ISO-8859-9"
    when ISO_8859_10  then "ISO-8859-10"
    when ISO_8859_11  then "ISO-8859-11"
    when ISO_8859_13  then "ISO-8859-13"
    when ISO_8859_14  then "ISO-8859-14"
    when ISO_8859_15  then "ISO-8859-15"
    when ISO_8859_16  then "ISO-8859-16"
    when WINDOWS_874  then "Windows-874"
    when WINDOWS_1250 then "Windows-1250"
    when WINDOWS_1251 then "Windows-1251"
    when WINDOWS_1252 then "Windows-1252"
    when WINDOWS_1253 then "Windows-1253"
    when WINDOWS_1254 then "Windows-1254"
    when WINDOWS_1255 then "Windows-1255"
    when WINDOWS_1256 then "Windows-1256"
    when WINDOWS_1257 then "Windows-1257"
    when IBM437       then "IBM437"
    when IBM720       then "IBM720"
    when IBM737       then "IBM737"
    when IBM775       then "IBM775"
    when IBM852       then "IBM852"
    when IBM855       then "IBM855"
    when IBM857       then "IBM857"
    when IBM860       then "IBM860"
    when IBM861       then "IBM861"
    when IBM862       then "IBM862"
    when IBM863       then "IBM863"
    when IBM864       then "IBM864"
    when IBM865       then "IBM865"
    when IBM866       then "IBM866"
    when IBM869       then "IBM869"
    when CP850        then "CP850"
    when CP852        then "CP852"
    when CP855        then "CP855"
    when MACCROATIAN  then "MacCroatian"
    when MACCYRILLIC  then "MacCyrillic"
    when MACGREEK     then "MacGreek"
    when MACICELAND   then "MacIceland"
    when MACROMAN     then "MacRoman"
    when MACROMANIA   then "MacRomania"
    when MACTURKISH   then "MacTurkish"
    when MACUKRAINE   then "MacUkraine"
    when KOI8_R       then "KOI8-R"
    when KOI8_U       then "KOI8-U"
    when TIS_620      then "TIS-620"
    when EUC_JP       then "EUC-JP"
    when SHIFT_JIS    then "Shift_JIS"
    when WINDOWS_31J  then "Windows-31J"
    when EUC_KR       then "EUC-KR"
    when CP949        then "CP949"
    when GBK          then "GBK"
    when GB18030      then "GB18030"
    when BIG5         then "Big5"
    when BIG5_HKSCS   then "Big5-HKSCS"
    when UNKNOWN      then "UNKNOWN"
    else                   "UNKNOWN"
    end
  end

  # True for all encodings EXCEPT the UTF-16 and UTF-32 families.
  # UTF-16/32 are not ASCII-compatible because ASCII characters
  # are represented as two (or four) bytes rather than one.
  def ascii_compatible? : Bool
    case self
    when UTF_16LE, UTF_16BE, UTF_32LE, UTF_32BE
      false
    else
      true
    end
  end

  # True for encodings where every character is exactly one byte.
  # This covers: ASCII_8BIT, US_ASCII, the entire ISO-8859-* family,
  # all Windows code pages (874, 1250-1257), IBM/CP/Mac single-byte
  # pages, KOI8-*, and TIS-620.
  def single_byte? : Bool
    case self
    when ASCII_8BIT,
         US_ASCII,
         ISO_8859_1, ISO_8859_2, ISO_8859_3, ISO_8859_4,
         ISO_8859_5, ISO_8859_6, ISO_8859_7, ISO_8859_8,
         ISO_8859_9, ISO_8859_10, ISO_8859_11, ISO_8859_13,
         ISO_8859_14, ISO_8859_15, ISO_8859_16,
         WINDOWS_874,
         WINDOWS_1250, WINDOWS_1251, WINDOWS_1252, WINDOWS_1253,
         WINDOWS_1254, WINDOWS_1255, WINDOWS_1256, WINDOWS_1257,
         IBM437, IBM720, IBM737, IBM775, IBM852, IBM855, IBM857,
         IBM860, IBM861, IBM862, IBM863, IBM864, IBM865, IBM866, IBM869,
         CP850, CP852, CP855,
         MACCROATIAN, MACCYRILLIC, MACGREEK, MACICELAND,
         MACROMAN, MACROMANIA, MACTURKISH, MACUKRAINE,
         KOI8_R, KOI8_U,
         TIS_620
      true
    else
      false
    end
  end
end

# ---------------------------------------------------------------------------
# Alias lookup table — outside the enum (Crystal enums cannot have class vars).
#
# Keys are normalised: upper-cased and hyphens converted to underscores.
# This matches the normalisation in RubyEncoding.from_name.
# ---------------------------------------------------------------------------

RUBY_ENCODING_ALIASES = {
  # UTF-8
  "UTF_8"           => RubyEncoding::UTF_8,
  "UTF8"            => RubyEncoding::UTF_8,
  "UTF_8_BOM"       => RubyEncoding::UTF_8,

  # ASCII-8BIT / BINARY
  "ASCII_8BIT"      => RubyEncoding::ASCII_8BIT,
  "BINARY"          => RubyEncoding::ASCII_8BIT,
  "BLOB"            => RubyEncoding::ASCII_8BIT,

  # US-ASCII
  "US_ASCII"        => RubyEncoding::US_ASCII,
  "ASCII"           => RubyEncoding::US_ASCII,
  "USASCII"         => RubyEncoding::US_ASCII,
  "US_ASCII_7BIT"   => RubyEncoding::US_ASCII,
  "646"             => RubyEncoding::US_ASCII,
  "ANSI_X3.4_1968"  => RubyEncoding::US_ASCII,

  # UTF-16
  "UTF_16LE"        => RubyEncoding::UTF_16LE,
  "UTF16LE"         => RubyEncoding::UTF_16LE,
  "UTF_16BE"        => RubyEncoding::UTF_16BE,
  "UTF16BE"         => RubyEncoding::UTF_16BE,
  "UTF_16"          => RubyEncoding::UTF_16BE,
  "UTF16"           => RubyEncoding::UTF_16BE,

  # UTF-32
  "UTF_32LE"        => RubyEncoding::UTF_32LE,
  "UTF32LE"         => RubyEncoding::UTF_32LE,
  "UTF_32BE"        => RubyEncoding::UTF_32BE,
  "UTF32BE"         => RubyEncoding::UTF_32BE,
  "UTF_32"          => RubyEncoding::UTF_32BE,
  "UTF32"           => RubyEncoding::UTF_32BE,

  # UTF-8-MAC
  "UTF8_MAC"        => RubyEncoding::UTF_8_MAC,
  "UTF_8_MAC"       => RubyEncoding::UTF_8_MAC,
  "UTF8MAC"         => RubyEncoding::UTF_8_MAC,

  # ISO-8859
  "ISO_8859_1"      => RubyEncoding::ISO_8859_1,
  "ISO8859_1"       => RubyEncoding::ISO_8859_1,
  "ISO88591"        => RubyEncoding::ISO_8859_1,
  "LATIN1"          => RubyEncoding::ISO_8859_1,
  "LATIN_1"         => RubyEncoding::ISO_8859_1,
  "ISO_8859_2"      => RubyEncoding::ISO_8859_2,
  "ISO8859_2"       => RubyEncoding::ISO_8859_2,
  "LATIN2"          => RubyEncoding::ISO_8859_2,
  "ISO_8859_3"      => RubyEncoding::ISO_8859_3,
  "ISO8859_3"       => RubyEncoding::ISO_8859_3,
  "LATIN3"          => RubyEncoding::ISO_8859_3,
  "ISO_8859_4"      => RubyEncoding::ISO_8859_4,
  "ISO8859_4"       => RubyEncoding::ISO_8859_4,
  "LATIN4"          => RubyEncoding::ISO_8859_4,
  "ISO_8859_5"      => RubyEncoding::ISO_8859_5,
  "ISO8859_5"       => RubyEncoding::ISO_8859_5,
  "ISO_8859_6"      => RubyEncoding::ISO_8859_6,
  "ISO8859_6"       => RubyEncoding::ISO_8859_6,
  "ISO_8859_7"      => RubyEncoding::ISO_8859_7,
  "ISO8859_7"       => RubyEncoding::ISO_8859_7,
  "ISO_8859_8"      => RubyEncoding::ISO_8859_8,
  "ISO8859_8"       => RubyEncoding::ISO_8859_8,
  "ISO_8859_9"      => RubyEncoding::ISO_8859_9,
  "ISO8859_9"       => RubyEncoding::ISO_8859_9,
  "LATIN5"          => RubyEncoding::ISO_8859_9,
  "ISO_8859_10"     => RubyEncoding::ISO_8859_10,
  "ISO8859_10"      => RubyEncoding::ISO_8859_10,
  "LATIN6"          => RubyEncoding::ISO_8859_10,
  "ISO_8859_11"     => RubyEncoding::ISO_8859_11,
  "ISO8859_11"      => RubyEncoding::ISO_8859_11,
  "ISO_8859_13"     => RubyEncoding::ISO_8859_13,
  "ISO8859_13"      => RubyEncoding::ISO_8859_13,
  "LATIN7"          => RubyEncoding::ISO_8859_13,
  "ISO_8859_14"     => RubyEncoding::ISO_8859_14,
  "ISO8859_14"      => RubyEncoding::ISO_8859_14,
  "LATIN8"          => RubyEncoding::ISO_8859_14,
  "ISO_8859_15"     => RubyEncoding::ISO_8859_15,
  "ISO8859_15"      => RubyEncoding::ISO_8859_15,
  "LATIN9"          => RubyEncoding::ISO_8859_15,
  "ISO_8859_16"     => RubyEncoding::ISO_8859_16,
  "ISO8859_16"      => RubyEncoding::ISO_8859_16,
  "LATIN10"         => RubyEncoding::ISO_8859_16,

  # Windows code pages
  "WINDOWS_874"     => RubyEncoding::WINDOWS_874,
  "CP874"           => RubyEncoding::WINDOWS_874,
  "WINDOWS_1250"    => RubyEncoding::WINDOWS_1250,
  "CP1250"          => RubyEncoding::WINDOWS_1250,
  "WINDOWS_1251"    => RubyEncoding::WINDOWS_1251,
  "CP1251"          => RubyEncoding::WINDOWS_1251,
  "WINDOWS_1252"    => RubyEncoding::WINDOWS_1252,
  "CP1252"          => RubyEncoding::WINDOWS_1252,
  "WINDOWS_1253"    => RubyEncoding::WINDOWS_1253,
  "CP1253"          => RubyEncoding::WINDOWS_1253,
  "WINDOWS_1254"    => RubyEncoding::WINDOWS_1254,
  "CP1254"          => RubyEncoding::WINDOWS_1254,
  "WINDOWS_1255"    => RubyEncoding::WINDOWS_1255,
  "CP1255"          => RubyEncoding::WINDOWS_1255,
  "WINDOWS_1256"    => RubyEncoding::WINDOWS_1256,
  "CP1256"          => RubyEncoding::WINDOWS_1256,
  "WINDOWS_1257"    => RubyEncoding::WINDOWS_1257,
  "CP1257"          => RubyEncoding::WINDOWS_1257,

  # IBM / OEM
  "IBM437"          => RubyEncoding::IBM437,
  "CP437"           => RubyEncoding::IBM437,
  "IBM720"          => RubyEncoding::IBM720,
  "CP720"           => RubyEncoding::IBM720,
  "IBM737"          => RubyEncoding::IBM737,
  "CP737"           => RubyEncoding::IBM737,
  "IBM775"          => RubyEncoding::IBM775,
  "CP775"           => RubyEncoding::IBM775,
  "IBM852"          => RubyEncoding::IBM852,
  "IBM855"          => RubyEncoding::IBM855,
  "IBM857"          => RubyEncoding::IBM857,
  "CP857"           => RubyEncoding::IBM857,
  "IBM860"          => RubyEncoding::IBM860,
  "CP860"           => RubyEncoding::IBM860,
  "IBM861"          => RubyEncoding::IBM861,
  "CP861"           => RubyEncoding::IBM861,
  "IBM862"          => RubyEncoding::IBM862,
  "CP862"           => RubyEncoding::IBM862,
  "IBM863"          => RubyEncoding::IBM863,
  "CP863"           => RubyEncoding::IBM863,
  "IBM864"          => RubyEncoding::IBM864,
  "CP864"           => RubyEncoding::IBM864,
  "IBM865"          => RubyEncoding::IBM865,
  "CP865"           => RubyEncoding::IBM865,
  "IBM866"          => RubyEncoding::IBM866,
  "CP866"           => RubyEncoding::IBM866,
  "IBM869"          => RubyEncoding::IBM869,
  "CP869"           => RubyEncoding::IBM869,
  "CP850"           => RubyEncoding::CP850,
  "CP852"           => RubyEncoding::CP852,
  "CP855"           => RubyEncoding::CP855,

  # Mac encodings
  "MACCROATIAN"     => RubyEncoding::MACCROATIAN,
  "MACCYRILLIC"     => RubyEncoding::MACCYRILLIC,
  "MACGREEK"        => RubyEncoding::MACGREEK,
  "MACICELAND"      => RubyEncoding::MACICELAND,
  "MACROMAN"        => RubyEncoding::MACROMAN,
  "MACROMANIA"      => RubyEncoding::MACROMANIA,
  "MACTURKISH"      => RubyEncoding::MACTURKISH,
  "MACUKRAINE"      => RubyEncoding::MACUKRAINE,

  # KOI8 / TIS
  "KOI8_R"          => RubyEncoding::KOI8_R,
  "KOI8R"           => RubyEncoding::KOI8_R,
  "KOI8_U"          => RubyEncoding::KOI8_U,
  "KOI8U"           => RubyEncoding::KOI8_U,
  "TIS_620"         => RubyEncoding::TIS_620,
  "TIS620"          => RubyEncoding::TIS_620,

  # Japanese
  "EUC_JP"          => RubyEncoding::EUC_JP,
  "EUCJP"           => RubyEncoding::EUC_JP,
  "EUC_JP_MS"       => RubyEncoding::EUC_JP,
  "SHIFT_JIS"       => RubyEncoding::SHIFT_JIS,
  "SHIFTJIS"        => RubyEncoding::SHIFT_JIS,
  "SJIS"            => RubyEncoding::SHIFT_JIS,
  "WINDOWS_31J"     => RubyEncoding::WINDOWS_31J,
  "CP932"           => RubyEncoding::WINDOWS_31J,
  "CSWINDOWS31J"    => RubyEncoding::WINDOWS_31J,

  # Korean
  "EUC_KR"          => RubyEncoding::EUC_KR,
  "EUCKR"           => RubyEncoding::EUC_KR,
  "CP949"           => RubyEncoding::CP949,

  # Chinese
  "GBK"             => RubyEncoding::GBK,
  "CP936"           => RubyEncoding::GBK,
  "GB18030"         => RubyEncoding::GB18030,
  "BIG5"            => RubyEncoding::BIG5,
  "BIG5_HKSCS"      => RubyEncoding::BIG5_HKSCS,
  "BIG5HKSCS"       => RubyEncoding::BIG5_HKSCS,

  # Sentinel
  "UNKNOWN"         => RubyEncoding::UNKNOWN,
} of String => RubyEncoding

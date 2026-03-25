require "./single_byte_tables"

module Encoding
  module SingleByte
    # All supported single-byte encoding names (canonical uppercase forms)
    ENCODINGS = %w[
      ISO-8859-1
      ISO-8859-2
      ISO-8859-3
      ISO-8859-4
      ISO-8859-5
      ISO-8859-6
      ISO-8859-7
      ISO-8859-8
      ISO-8859-9
      ISO-8859-10
      ISO-8859-11
      ISO-8859-13
      ISO-8859-14
      ISO-8859-15
      ISO-8859-16
      WINDOWS-874
      WINDOWS-1250
      WINDOWS-1251
      WINDOWS-1252
      WINDOWS-1253
      WINDOWS-1254
      WINDOWS-1255
      WINDOWS-1256
      WINDOWS-1257
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
      MACCROATIAN
      MACCYRILLIC
      MACGREEK
      MACICELAND
      MACROMAN
      MACROMANIA
      MACTURKISH
      MACUKRAINE
      KOI8-U
      KOI8-R
      TIS-620
      CP850
      CP852
      CP855
    ]

    # Transcode a single byte from the given encoding to a Unicode codepoint.
    # Returns -1 if the byte is invalid/undefined for the encoding,
    # or if the encoding is not supported.
    def self.byte_to_ucs(byte : UInt8, encoding : String) : Int32
      i = byte.to_i
      case encoding
      when "ISO-8859-1"   then BYTE_TO_UCS_ISO_8859_1[i]
      when "ISO-8859-2"   then BYTE_TO_UCS_ISO_8859_2[i]
      when "ISO-8859-3"   then BYTE_TO_UCS_ISO_8859_3[i]
      when "ISO-8859-4"   then BYTE_TO_UCS_ISO_8859_4[i]
      when "ISO-8859-5"   then BYTE_TO_UCS_ISO_8859_5[i]
      when "ISO-8859-6"   then BYTE_TO_UCS_ISO_8859_6[i]
      when "ISO-8859-7"   then BYTE_TO_UCS_ISO_8859_7[i]
      when "ISO-8859-8"   then BYTE_TO_UCS_ISO_8859_8[i]
      when "ISO-8859-9"   then BYTE_TO_UCS_ISO_8859_9[i]
      when "ISO-8859-10"  then BYTE_TO_UCS_ISO_8859_10[i]
      when "ISO-8859-11"  then BYTE_TO_UCS_ISO_8859_11[i]
      when "ISO-8859-13"  then BYTE_TO_UCS_ISO_8859_13[i]
      when "ISO-8859-14"  then BYTE_TO_UCS_ISO_8859_14[i]
      when "ISO-8859-15"  then BYTE_TO_UCS_ISO_8859_15[i]
      when "ISO-8859-16"  then BYTE_TO_UCS_ISO_8859_16[i]
      when "WINDOWS-874"  then BYTE_TO_UCS_WINDOWS_874[i]
      when "WINDOWS-1250" then BYTE_TO_UCS_WINDOWS_1250[i]
      when "WINDOWS-1251" then BYTE_TO_UCS_WINDOWS_1251[i]
      when "WINDOWS-1252" then BYTE_TO_UCS_WINDOWS_1252[i]
      when "WINDOWS-1253" then BYTE_TO_UCS_WINDOWS_1253[i]
      when "WINDOWS-1254" then BYTE_TO_UCS_WINDOWS_1254[i]
      when "WINDOWS-1255" then BYTE_TO_UCS_WINDOWS_1255[i]
      when "WINDOWS-1256" then BYTE_TO_UCS_WINDOWS_1256[i]
      when "WINDOWS-1257" then BYTE_TO_UCS_WINDOWS_1257[i]
      when "IBM437"       then BYTE_TO_UCS_IBM437[i]
      when "IBM720"       then BYTE_TO_UCS_IBM720[i]
      when "IBM737"       then BYTE_TO_UCS_IBM737[i]
      when "IBM775"       then BYTE_TO_UCS_IBM775[i]
      when "IBM852"       then BYTE_TO_UCS_IBM852[i]
      when "IBM855"       then BYTE_TO_UCS_IBM855[i]
      when "IBM857"       then BYTE_TO_UCS_IBM857[i]
      when "IBM860"       then BYTE_TO_UCS_IBM860[i]
      when "IBM861"       then BYTE_TO_UCS_IBM861[i]
      when "IBM862"       then BYTE_TO_UCS_IBM862[i]
      when "IBM863"       then BYTE_TO_UCS_IBM863[i]
      when "IBM864"       then BYTE_TO_UCS_IBM864[i]
      when "IBM865"       then BYTE_TO_UCS_IBM865[i]
      when "IBM866"       then BYTE_TO_UCS_IBM866[i]
      when "IBM869"       then BYTE_TO_UCS_IBM869[i]
      when "MACCROATIAN"  then BYTE_TO_UCS_MACCROATIAN[i]
      when "MACCYRILLIC"  then BYTE_TO_UCS_MACCYRILLIC[i]
      when "MACGREEK"     then BYTE_TO_UCS_MACGREEK[i]
      when "MACICELAND"   then BYTE_TO_UCS_MACICELAND[i]
      when "MACROMAN"     then BYTE_TO_UCS_MACROMAN[i]
      when "MACROMANIA"   then BYTE_TO_UCS_MACROMANIA[i]
      when "MACTURKISH"   then BYTE_TO_UCS_MACTURKISH[i]
      when "MACUKRAINE"   then BYTE_TO_UCS_MACUKRAINE[i]
      when "KOI8-U"       then BYTE_TO_UCS_KOI8_U[i]
      when "KOI8-R"       then BYTE_TO_UCS_KOI8_R[i]
      when "TIS-620"      then BYTE_TO_UCS_TIS_620[i]
      when "CP850"        then BYTE_TO_UCS_CP850[i]
      when "CP852"        then BYTE_TO_UCS_CP852[i]
      when "CP855"        then BYTE_TO_UCS_CP855[i]
      else                     -1
      end
    end

    # Transcode a Unicode codepoint to a single byte in the given encoding.
    # Returns -1 if the codepoint cannot be represented in the encoding,
    # or if the encoding is not supported.
    # ASCII codepoints (0x00-0x7F) are always identity-mapped in all supported encodings.
    def self.ucs_to_byte(codepoint : Int32, encoding : String) : Int32
      tbl = case encoding
            when "ISO-8859-1"   then UCS_TO_BYTE_ISO_8859_1
            when "ISO-8859-2"   then UCS_TO_BYTE_ISO_8859_2
            when "ISO-8859-3"   then UCS_TO_BYTE_ISO_8859_3
            when "ISO-8859-4"   then UCS_TO_BYTE_ISO_8859_4
            when "ISO-8859-5"   then UCS_TO_BYTE_ISO_8859_5
            when "ISO-8859-6"   then UCS_TO_BYTE_ISO_8859_6
            when "ISO-8859-7"   then UCS_TO_BYTE_ISO_8859_7
            when "ISO-8859-8"   then UCS_TO_BYTE_ISO_8859_8
            when "ISO-8859-9"   then UCS_TO_BYTE_ISO_8859_9
            when "ISO-8859-10"  then UCS_TO_BYTE_ISO_8859_10
            when "ISO-8859-11"  then UCS_TO_BYTE_ISO_8859_11
            when "ISO-8859-13"  then UCS_TO_BYTE_ISO_8859_13
            when "ISO-8859-14"  then UCS_TO_BYTE_ISO_8859_14
            when "ISO-8859-15"  then UCS_TO_BYTE_ISO_8859_15
            when "ISO-8859-16"  then UCS_TO_BYTE_ISO_8859_16
            when "WINDOWS-874"  then UCS_TO_BYTE_WINDOWS_874
            when "WINDOWS-1250" then UCS_TO_BYTE_WINDOWS_1250
            when "WINDOWS-1251" then UCS_TO_BYTE_WINDOWS_1251
            when "WINDOWS-1252" then UCS_TO_BYTE_WINDOWS_1252
            when "WINDOWS-1253" then UCS_TO_BYTE_WINDOWS_1253
            when "WINDOWS-1254" then UCS_TO_BYTE_WINDOWS_1254
            when "WINDOWS-1255" then UCS_TO_BYTE_WINDOWS_1255
            when "WINDOWS-1256" then UCS_TO_BYTE_WINDOWS_1256
            when "WINDOWS-1257" then UCS_TO_BYTE_WINDOWS_1257
            when "IBM437"       then UCS_TO_BYTE_IBM437
            when "IBM720"       then UCS_TO_BYTE_IBM720
            when "IBM737"       then UCS_TO_BYTE_IBM737
            when "IBM775"       then UCS_TO_BYTE_IBM775
            when "IBM852"       then UCS_TO_BYTE_IBM852
            when "IBM855"       then UCS_TO_BYTE_IBM855
            when "IBM857"       then UCS_TO_BYTE_IBM857
            when "IBM860"       then UCS_TO_BYTE_IBM860
            when "IBM861"       then UCS_TO_BYTE_IBM861
            when "IBM862"       then UCS_TO_BYTE_IBM862
            when "IBM863"       then UCS_TO_BYTE_IBM863
            when "IBM864"       then UCS_TO_BYTE_IBM864
            when "IBM865"       then UCS_TO_BYTE_IBM865
            when "IBM866"       then UCS_TO_BYTE_IBM866
            when "IBM869"       then UCS_TO_BYTE_IBM869
            when "MACCROATIAN"  then UCS_TO_BYTE_MACCROATIAN
            when "MACCYRILLIC"  then UCS_TO_BYTE_MACCYRILLIC
            when "MACGREEK"     then UCS_TO_BYTE_MACGREEK
            when "MACICELAND"   then UCS_TO_BYTE_MACICELAND
            when "MACROMAN"     then UCS_TO_BYTE_MACROMAN
            when "MACROMANIA"   then UCS_TO_BYTE_MACROMANIA
            when "MACTURKISH"   then UCS_TO_BYTE_MACTURKISH
            when "MACUKRAINE"   then UCS_TO_BYTE_MACUKRAINE
            when "KOI8-U"       then UCS_TO_BYTE_KOI8_U
            when "KOI8-R"       then UCS_TO_BYTE_KOI8_R
            when "TIS-620"      then UCS_TO_BYTE_TIS_620
            when "CP850"        then UCS_TO_BYTE_CP850
            when "CP852"        then UCS_TO_BYTE_CP852
            when "CP855"        then UCS_TO_BYTE_CP855
            else                     return -1
            end

      # ASCII codepoints (0x00-0x7F) are always identity-mapped
      return codepoint if 0 <= codepoint <= 0x7F

      # Binary search for the codepoint in the sorted reverse table
      result = tbl.bsearch { |pair| pair[0] >= codepoint }
      return -1 if result.nil?
      return -1 if result[0] != codepoint
      result[1].to_i
    end
  end
end

# RubyEncodingObject — RubyObject wrapper around the unboxed RubyEncoding tag.
#
# Ruby exposes Encoding instances as first-class objects (Encoding::UTF_8 etc.
# are RubyObjects you can pass around, store in fields, compare for equality).
# Internally, RubyString uses the unboxed `RubyEncoding` enum as a fast tag —
# but the enum is a value type, not part of the RubyObject hierarchy.
#
# This wrapper bridges the two: each canonical RubyEncoding member has exactly
# one RubyEncodingObject singleton (interned in @@table), so identity comparison
# works (`Encoding::UTF_8.equal?(s.encoding)` is `true`). The codegen emits
# Ruby's `Encoding::UTF_8` constant references as the matching singleton name
# (`Ruby_Encoding_UTF_8`), and Frozone-Ruby code that needs the underlying enum
# tag for RubyString construction reads `obj.ruby_encoding`.

require "./ruby_object"
require "./ruby_string/encoding"

class RubyEncodingObject < RubyObject
  getter ruby_encoding : RubyEncoding

  @@table = Hash(RubyEncoding, RubyEncodingObject).new

  def self.for(enc : RubyEncoding) : RubyEncodingObject
    @@table[enc] ||= new(enc)
  end

  def initialize(@ruby_encoding : RubyEncoding)
  end

  def name : RubyString
    RubyString.new(@ruby_encoding.name)
  end

  def to_s : String
    "#<Encoding:#{@ruby_encoding.name}>"
  end

  def inspect : String
    to_s
  end

  def ==(other : RubyObject) : Bool
    other.is_a?(RubyEncodingObject) && other.ruby_encoding == @ruby_encoding
  end

  def hash : UInt64
    @ruby_encoding.value.to_u64
  end

  def class_name : String
    "Encoding"
  end
end

# Codegen-targeted constant names. The compiler emits `Encoding::UTF_8`
# (and similar) as `Ruby_Encoding_UTF_8` etc. Aliases like `BINARY` and
# `ASCII` collapse onto their canonical members.
Ruby_Encoding_UTF_8        = RubyEncodingObject.for(RubyEncoding::UTF_8)
Ruby_Encoding_ASCII_8BIT   = RubyEncodingObject.for(RubyEncoding::ASCII_8BIT)
Ruby_Encoding_BINARY       = Ruby_Encoding_ASCII_8BIT
Ruby_Encoding_US_ASCII     = RubyEncodingObject.for(RubyEncoding::US_ASCII)
Ruby_Encoding_ASCII        = Ruby_Encoding_US_ASCII
Ruby_Encoding_UTF_16LE     = RubyEncodingObject.for(RubyEncoding::UTF_16LE)
Ruby_Encoding_UTF_16BE     = RubyEncodingObject.for(RubyEncoding::UTF_16BE)
Ruby_Encoding_UTF_32LE     = RubyEncodingObject.for(RubyEncoding::UTF_32LE)
Ruby_Encoding_UTF_32BE     = RubyEncodingObject.for(RubyEncoding::UTF_32BE)

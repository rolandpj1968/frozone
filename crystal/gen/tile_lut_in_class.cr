require "../src/frozone_crystal"

RUBY_NIL    = RubyNil::INSTANCE
RUBY_TRUE   = RubyBool::TRUE
RUBY_FALSE  = RubyBool::FALSE
RUBY_GLOBALS = {} of String => RubyObject
Ruby_ARGV   = RubyArray.new(ARGV.map { |s| RubyString.new(s).as(RubyObject) })
module Ruby_ENV
  def self.[](key : RubyObject) : RubyObject
    val = ENV[key.to_s]?
    val ? RubyString.new(val).as(RubyObject) : RUBY_NIL
  end
  def self.[]=(key : RubyObject, val : RubyObject) : RubyObject
    ENV[key.to_s] = val.to_s
    val
  end
end

Ruby_Arr_0 = RubyArray.new([RubyInteger.new(0_i64), RubyInteger.new(4_i64), RubyInteger.new(8_i64), RubyInteger.new(12_i64)] of RubyObject)
Ruby_Str_0 = RubyString.new("TILE_LUT[0].size = ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("TILE_LUT[0][0].size = ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("TILE_LUT[3][0xffff][7] = ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }

module Ruby_Optcarrot
    def to_s : String; "#<Optcarrot>"; end
    def inspect : String; "#<Optcarrot>"; end

end
class Ruby_PPU < RubyObject
    def to_s : String; "#<PPU>"; end
    def inspect : String; "#<PPU>"; end

      RESPOND_TO_TABLE = StaticArray[false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end

Ruby_Optcarrot::Ruby_PPU::Ruby_TILE_LUT = RubyTuple4.new(RubyInteger.new(0_i64), RubyInteger.new(4_i64), RubyInteger.new(8_i64), RubyInteger.new(12_i64)).map() { |attr| RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |j| RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(65536_i64), true).map() { |i| clr = ((i[(RubyInteger.new(15_i64) - j)] * RubyInteger.new(2_i64)) + i[(RubyInteger.new(7_i64) - j)])
if ((clr != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
  (attr | clr)
else
  RubyInteger.new(0_i64)
end } }.transpose }
STDOUT.puts(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("TILE_LUT[0].size = "); _s.concat_raw_bytes!((Ruby_Optcarrot::Ruby_PPU::Ruby_TILE_LUT[0_i64].size).to_s) }.to_s); RUBY_NIL
STDOUT.puts(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("TILE_LUT[0][0].size = "); _s.concat_raw_bytes!((Ruby_Optcarrot::Ruby_PPU::Ruby_TILE_LUT[0_i64][0_i64].size).to_s) }.to_s); RUBY_NIL
STDOUT.puts(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("TILE_LUT[3][0xffff][7] = "); _s.concat_raw_bytes!((Ruby_Optcarrot::Ruby_PPU::Ruby_TILE_LUT[3_i64][65535_i64][7_i64]).to_s) }.to_s); RUBY_NIL

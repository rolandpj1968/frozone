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

Ruby_Sym_0 = RubySymbol.from("all")
Ruby_Sym_1 = RubySymbol.from("none")
Ruby_Sym_2 = RubySymbol.from("mapping")
Ruby_Sym_3 = RubySymbol.from("peek_2xxx")
Ruby_Sym_4 = RubySymbol.from("poke_2000")
Ruby_Sym_5 = RubySymbol.from("poke_2001")
Ruby_Sym_6 = RubySymbol.from("peek_2002")
Ruby_Sym_7 = RubySymbol.from("poke_2xxx")
Ruby_Sym_8 = RubySymbol.from("poke_2003")
Ruby_Sym_9 = RubySymbol.from("peek_2004")
Ruby_Sym_10 = RubySymbol.from("poke_2004")
Ruby_Sym_11 = RubySymbol.from("poke_2005")
Ruby_Sym_12 = RubySymbol.from("poke_2006")
Ruby_Sym_13 = RubySymbol.from("peek_2007")
Ruby_Sym_14 = RubySymbol.from("poke_2007")
Ruby_Sym_15 = RubySymbol.from("peek_3000")
Ruby_Sym_16 = RubySymbol.from("peek_4014")
Ruby_Sym_17 = RubySymbol.from("poke_4014")
Ruby_Sym_18 = RubySymbol.from("done")
Ruby_Sym_19 = RubySymbol.from("ivar_localization")
Ruby_Sym_20 = RubySymbol.from("method_inlining")
Ruby_Sym_21 = RubySymbol.from("batch_render_pixels")
Ruby_Sym_22 = RubySymbol.from("fastpath")
Ruby_Sym_23 = RubySymbol.from("main_loop")
Ruby_Sym_24 = RubySymbol.from("make_sure_invariants")
Ruby_Sym_25 = RubySymbol.from("render_pixel")
Ruby_Sym_26 = RubySymbol.from("batch_render_eight_pixels")
Ruby_Sym_27 = RubySymbol.from("open_sprite")
Ruby_Arr_0 = RubyArray.new([RubyInteger.new(255_i64)] of RubyObject)
Ruby_Arr_1 = RubyArray.new([RubyInteger.new(0_i64), RubyInteger.new(1_i64), RubyInteger.new(0_i64), RubyInteger.new(1_i64)] of RubyObject)
Ruby_Arr_2 = RubyArray.new([RubyInteger.new(63_i64), RubyInteger.new(1_i64), RubyInteger.new(0_i64), RubyInteger.new(1_i64), RubyInteger.new(0_i64), RubyInteger.new(2_i64), RubyInteger.new(2_i64), RubyInteger.new(13_i64), RubyInteger.new(8_i64), RubyInteger.new(16_i64), RubyInteger.new(8_i64), RubyInteger.new(36_i64), RubyInteger.new(0_i64), RubyInteger.new(0_i64), RubyInteger.new(4_i64), RubyInteger.new(44_i64), RubyInteger.new(9_i64), RubyInteger.new(1_i64), RubyInteger.new(52_i64), RubyInteger.new(3_i64), RubyInteger.new(0_i64), RubyInteger.new(4_i64), RubyInteger.new(0_i64), RubyInteger.new(20_i64), RubyInteger.new(8_i64), RubyInteger.new(58_i64), RubyInteger.new(0_i64), RubyInteger.new(2_i64), RubyInteger.new(0_i64), RubyInteger.new(32_i64), RubyInteger.new(44_i64), RubyInteger.new(8_i64)] of RubyObject)
Ruby_Arr_3 = RubyArray.new([RubyInteger.new(0_i64)] of RubyObject)
Ruby_Arr_4 = RubyArray.new([RubyInteger.new(0_i64), RubyInteger.new(4_i64), RubyInteger.new(8_i64), RubyInteger.new(12_i64)] of RubyObject)
Ruby_Str_0 = RubyString.new("-").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("unknown optimization: `").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("'").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("`").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("' depends upon `").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("\n").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new(" ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("^ {").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("if ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("else").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("end").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("when ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("  ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("end\n").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new(", ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("^( *)\\b(").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("|").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new(")\\b(?:\\((.*?)\\))?\\n").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("\\b").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("\\b(?:\\(((?:@?\\w+, )*@?\\w+)\\))?").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("(").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("; ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new(")").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("(if|unless)\\s").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("if").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("true").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("__").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new(" = @").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new(" = ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("@(").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new(")\\b").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("begin").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("ensure").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("#<").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new(">").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("(generated PPU core)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("forever").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("ppu: scanline ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new(", hclk ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("->").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("PPU Fiber should have finished").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("/tmp/optcarrot/lib/optcarrot/ppu.rb").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("@any_show").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("@a12_monitor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("@hclk_target = (@vclk + @hclk) * RP2C02_CC").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("def self.run").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("  debug_logging(@scanline, @hclk, @hclk_target)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("@hclk + 8 <= @hclk_target").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("unless @any_show").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("  @bg_pixels[@hclk % 8] = 0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("  @output_pixels << @output_color[@scroll_addr_5_14 & 0x3f00 == 0x3f00 ? @scroll_addr_0_4 : 0]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("# batch-version of render_pixel").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("if @any_show").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("  if @sp_active").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("    if @bg_enabled").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("      pixel").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new(" = @bg_pixels[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("      if sprite = @sp_map[@hclk").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new(" + ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("        if pixel").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new(" % 4 == 0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("          pixel").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new(" = sprite[2]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new("        else").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new("          @sp_zero_hit = true if sprite[1]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new(" = sprite[2] unless sprite[0]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("        end").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("      end").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("      @output_pixels << ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("@output_color[pixel").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new(" << ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("    else").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new(" = (sprite = @sp_map[@hclk ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("]) ? sprite[2] : 0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("    end").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("  else").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("    if @bg_enabled # this is the true hot-spot").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("@output_color[@bg_pixels[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("]]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("      clr = @output_color[0]").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("clr").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("  end").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("[\n").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("false").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("while @hclk_target > @hclk").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_91 = RubyString.new("  case @hclk").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_92 = RubyString.new("  when ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_93 = RubyString.new("loaded ppu, TILE_LUT[0].size = ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_94 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_95 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_96 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_97 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_98 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_99 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_100 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_101 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_102 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_103 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_104 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_105 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_106 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_107 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_108 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_109 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_110 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_111 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_112 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_113 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_114 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_115 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_116 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_117 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_118 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_119 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_120 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_121 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_122 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_123 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_124 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_125 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_126 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_127 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_128 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_129 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_130 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_131 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_132 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_133 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_134 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_135 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_136 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_137 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_138 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_139 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_140 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_141 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_142 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_143 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_144 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_145 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_146 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_147 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_148 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_149 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_150 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_151 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_152 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_153 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_154 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_155 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_156 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_157 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_158 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_159 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_160 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_161 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_162 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_163 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_164 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_165 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_166 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_167 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_168 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_169 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_170 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_171 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_172 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_173 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_174 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_175 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_176 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_177 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }

# User-defined method stubs on RubyObject for polymorphic dispatch
class RubyObject
  def depends(*args) : RubyObject
    raise Exception.new("undefined method 'depends' for #{self.class}")
  end
  def gen(*args) : RubyObject
    raise Exception.new("undefined method 'gen' for #{self.class}")
  end
  def indent(*args) : RubyObject
    raise Exception.new("undefined method 'indent' for #{self.class}")
  end
  def branch(*args) : RubyObject
    raise Exception.new("undefined method 'branch' for #{self.class}")
  end
  def parse_method_definitions(*args) : RubyObject
    raise Exception.new("undefined method 'parse_method_definitions' for #{self.class}")
  end
  def expand_methods(*args) : RubyObject
    raise Exception.new("undefined method 'expand_methods' for #{self.class}")
  end
  def expand_inline_methods(*args) : RubyObject
    raise Exception.new("undefined method 'expand_inline_methods' for #{self.class}")
  end
  def replace_var(*args) : RubyObject
    raise Exception.new("undefined method 'replace_var' for #{self.class}")
  end
  def replace_cond_var(*args) : RubyObject
    raise Exception.new("undefined method 'replace_cond_var' for #{self.class}")
  end
  def remove_trivial_branches(*args) : RubyObject
    raise Exception.new("undefined method 'remove_trivial_branches' for #{self.class}")
  end
  def localize_instance_variables(*args) : RubyObject
    raise Exception.new("undefined method 'localize_instance_variables' for #{self.class}")
  end
  def reset(*args) : RubyObject
    raise Exception.new("undefined method 'reset' for #{self.class}")
  end
  def update_output_color(*args) : RubyObject
    raise Exception.new("undefined method 'update_output_color' for #{self.class}")
  end
  def setup_lut(*args) : RubyObject
    raise Exception.new("undefined method 'setup_lut' for #{self.class}")
  end
  def output_pixels(*args) : RubyObject
    raise Exception.new("undefined method 'output_pixels' for #{self.class}")
  end
  def set_chr_mem(*args) : RubyObject
    raise Exception.new("undefined method 'set_chr_mem' for #{self.class}")
  end
  def nametables=(val : RubyObject) : RubyObject
    raise Exception.new("undefined method 'nametables=' for #{self.class}")
  end
  def update(*args) : RubyObject
    raise Exception.new("undefined method 'update' for #{self.class}")
  end
  def setup_frame(*args) : RubyObject
    raise Exception.new("undefined method 'setup_frame' for #{self.class}")
  end
  def vsync(*args) : RubyObject
    raise Exception.new("undefined method 'vsync' for #{self.class}")
  end
  def monitor_a12_rising_edge(*args) : RubyObject
    raise Exception.new("undefined method 'monitor_a12_rising_edge' for #{self.class}")
  end
  def update_vram_addr(*args) : RubyObject
    raise Exception.new("undefined method 'update_vram_addr' for #{self.class}")
  end
  def update_scroll_address_line(*args) : RubyObject
    raise Exception.new("undefined method 'update_scroll_address_line' for #{self.class}")
  end
  def active?(*args) : RubyObject
    raise Exception.new("undefined method 'active?' for #{self.class}")
  end
  def sync(*args) : RubyObject
    raise Exception.new("undefined method 'sync' for #{self.class}")
  end
  def make_sure_invariants(*args) : RubyObject
    raise Exception.new("undefined method 'make_sure_invariants' for #{self.class}")
  end
  def io_latch_mask(*args) : RubyObject
    raise Exception.new("undefined method 'io_latch_mask' for #{self.class}")
  end
  def poke_2000(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2000' for #{self.class}")
  end
  def poke_2001(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2001' for #{self.class}")
  end
  def peek_2002(*args) : RubyObject
    raise Exception.new("undefined method 'peek_2002' for #{self.class}")
  end
  def poke_2003(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2003' for #{self.class}")
  end
  def poke_2004(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2004' for #{self.class}")
  end
  def peek_2004(*args) : RubyObject
    raise Exception.new("undefined method 'peek_2004' for #{self.class}")
  end
  def poke_2005(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2005' for #{self.class}")
  end
  def poke_2006(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2006' for #{self.class}")
  end
  def poke_2007(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2007' for #{self.class}")
  end
  def peek_2007(*args) : RubyObject
    raise Exception.new("undefined method 'peek_2007' for #{self.class}")
  end
  def poke_2xxx(*args) : RubyObject
    raise Exception.new("undefined method 'poke_2xxx' for #{self.class}")
  end
  def peek_2xxx(*args) : RubyObject
    raise Exception.new("undefined method 'peek_2xxx' for #{self.class}")
  end
  def peek_3000(*args) : RubyObject
    raise Exception.new("undefined method 'peek_3000' for #{self.class}")
  end
  def poke_4014(*args) : RubyObject
    raise Exception.new("undefined method 'poke_4014' for #{self.class}")
  end
  def peek_4014(*args) : RubyObject
    raise Exception.new("undefined method 'peek_4014' for #{self.class}")
  end
  def open_pattern(*args) : RubyObject
    raise Exception.new("undefined method 'open_pattern' for #{self.class}")
  end
  def open_sprite(*args) : RubyObject
    raise Exception.new("undefined method 'open_sprite' for #{self.class}")
  end
  def load_sprite(*args) : RubyObject
    raise Exception.new("undefined method 'load_sprite' for #{self.class}")
  end
  def update_address_line(*args) : RubyObject
    raise Exception.new("undefined method 'update_address_line' for #{self.class}")
  end
  def open_name(*args) : RubyObject
    raise Exception.new("undefined method 'open_name' for #{self.class}")
  end
  def fetch_name(*args) : RubyObject
    raise Exception.new("undefined method 'fetch_name' for #{self.class}")
  end
  def open_attr(*args) : RubyObject
    raise Exception.new("undefined method 'open_attr' for #{self.class}")
  end
  def fetch_attr(*args) : RubyObject
    raise Exception.new("undefined method 'fetch_attr' for #{self.class}")
  end
  def fetch_bg_pattern_0(*args) : RubyObject
    raise Exception.new("undefined method 'fetch_bg_pattern_0' for #{self.class}")
  end
  def fetch_bg_pattern_1(*args) : RubyObject
    raise Exception.new("undefined method 'fetch_bg_pattern_1' for #{self.class}")
  end
  def scroll_clock_x(*args) : RubyObject
    raise Exception.new("undefined method 'scroll_clock_x' for #{self.class}")
  end
  def scroll_reset_x(*args) : RubyObject
    raise Exception.new("undefined method 'scroll_reset_x' for #{self.class}")
  end
  def scroll_clock_y(*args) : RubyObject
    raise Exception.new("undefined method 'scroll_clock_y' for #{self.class}")
  end
  def preload_tiles(*args) : RubyObject
    raise Exception.new("undefined method 'preload_tiles' for #{self.class}")
  end
  def load_tiles(*args) : RubyObject
    raise Exception.new("undefined method 'load_tiles' for #{self.class}")
  end
  def evaluate_sprites_even(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_even' for #{self.class}")
  end
  def evaluate_sprites_odd(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_1(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_1' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_2(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_2' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_3(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_3' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_4(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_4' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_5(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_5' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_6(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_6' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_7(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_7' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_8(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_8' for #{self.class}")
  end
  def evaluate_sprites_odd_phase_9(*args) : RubyObject
    raise Exception.new("undefined method 'evaluate_sprites_odd_phase_9' for #{self.class}")
  end
  def load_extended_sprites(*args) : RubyObject
    raise Exception.new("undefined method 'load_extended_sprites' for #{self.class}")
  end
  def render_pixel(*args) : RubyObject
    raise Exception.new("undefined method 'render_pixel' for #{self.class}")
  end
  def batch_render_eight_pixels(*args) : RubyObject
    raise Exception.new("undefined method 'batch_render_eight_pixels' for #{self.class}")
  end
  def boot(*args) : RubyObject
    raise Exception.new("undefined method 'boot' for #{self.class}")
  end
  def vblank_0(*args) : RubyObject
    raise Exception.new("undefined method 'vblank_0' for #{self.class}")
  end
  def vblank_1(*args) : RubyObject
    raise Exception.new("undefined method 'vblank_1' for #{self.class}")
  end
  def vblank_2(*args) : RubyObject
    raise Exception.new("undefined method 'vblank_2' for #{self.class}")
  end
  def update_enabled_flags(*args) : RubyObject
    raise Exception.new("undefined method 'update_enabled_flags' for #{self.class}")
  end
  def update_enabled_flags_edge(*args) : RubyObject
    raise Exception.new("undefined method 'update_enabled_flags_edge' for #{self.class}")
  end
  def debug_logging(*args) : RubyObject
    raise Exception.new("undefined method 'debug_logging' for #{self.class}")
  end
  def run(*args) : RubyObject
    raise Exception.new("undefined method 'run' for #{self.class}")
  end
  def dispose(*args) : RubyObject
    raise Exception.new("undefined method 'dispose' for #{self.class}")
  end
  def wait_frame(*args) : RubyObject
    raise Exception.new("undefined method 'wait_frame' for #{self.class}")
  end
  def wait_zero_clocks(*args) : RubyObject
    raise Exception.new("undefined method 'wait_zero_clocks' for #{self.class}")
  end
  def wait_one_clock(*args) : RubyObject
    raise Exception.new("undefined method 'wait_one_clock' for #{self.class}")
  end
  def wait_two_clocks(*args) : RubyObject
    raise Exception.new("undefined method 'wait_two_clocks' for #{self.class}")
  end
  def main_loop(*args) : RubyObject
    raise Exception.new("undefined method 'main_loop' for #{self.class}")
  end
  def build(*args) : RubyObject
    raise Exception.new("undefined method 'build' for #{self.class}")
  end
  def parse_clock_handlers(*args) : RubyObject
    raise Exception.new("undefined method 'parse_clock_handlers' for #{self.class}")
  end
  def specialize_clock_handlers(*args) : RubyObject
    raise Exception.new("undefined method 'specialize_clock_handlers' for #{self.class}")
  end
  def add_fastpath(*args) : RubyObject
    raise Exception.new("undefined method 'add_fastpath' for #{self.class}")
  end
  def batch_render_pixels(*args) : RubyObject
    raise Exception.new("undefined method 'batch_render_pixels' for #{self.class}")
  end
  def oneline(*args) : RubyObject
    raise Exception.new("undefined method 'oneline' for #{self.class}")
  end
  def ppu_expand_methods(*args) : RubyObject
    raise Exception.new("undefined method 'ppu_expand_methods' for #{self.class}")
  end
  def split_mode(*args) : RubyObject
    raise Exception.new("undefined method 'split_mode' for #{self.class}")
  end
  def build_loop(*args) : RubyObject
    raise Exception.new("undefined method 'build_loop' for #{self.class}")
  end
  def rebuild_loop(*args) : RubyObject
    raise Exception.new("undefined method 'rebuild_loop' for #{self.class}")
  end
end

module Ruby_Optcarrot
    def to_s : String; "#<Optcarrot>"; end
    def inspect : String; "#<Optcarrot>"; end

end
module Ruby_CodeOptimizationHelper
    @loglevel : RubyObject = RUBY_NIL

    def to_s : String; "#<CodeOptimizationHelper>"; end
    def inspect : String; "#<CodeOptimizationHelper>"; end

  def initialize(loglevel : RubyObject, enabled_opts : RubyObject)
    @loglevel = loglevel
    options = ruby_class::Ruby_OPTIONS
    opts = RubyHash.new
    (_or0 = enabled_opts; _or0.truthy? ? _or0 : (enabled_opts = RubyArray.new([Ruby_Sym_0] of RubyObject)))
    default =     (_or1 = ((enabled_opts == RubyArray.new([Ruby_Sym_0] of RubyObject)) ? RUBY_TRUE : RUBY_FALSE); _or1.truthy? ? _or1 : ((_and2 = ((enabled_opts != RubyArray.new([] of RubyObject)) ? RUBY_TRUE : RUBY_FALSE); _and2.truthy? ? (enabled_opts.all?() { |opt|     opt.ruby_to_s.start_with?(Ruby_Str_0) }) : _and2)))
    options.each() { |opt|     opts[opt] = default }
        (enabled_opts - RubyTuple2.new(Ruby_Sym_1, Ruby_Sym_0)).each() { |opt|     val = RUBY_TRUE
    if opt.ruby_to_s.start_with?(Ruby_Str_0).truthy?
      opt = opt.ruby_to_s[RubyRange.new(RubyInteger.new(1_i64), RubyInteger.new(-1_i64), false)].to_sym
      val = RUBY_FALSE
    end
    unless options.include?(opt).truthy?
      raise RuntimeError.new(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("unknown optimization: `"); _s.concat_raw_bytes!((      opt).to_s); _s.concat_raw_bytes!("'") }.to_s)
    end
    opts[opt] = val }
    options.each() { |opt|     instance_variable_set(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@"); _s.concat_raw_bytes!((    opt).to_s) }.to_sym, opts[opt]) }
  end

  def depends(opt : RubyObject, depended_opt : RubyObject)
    if (_and3 = instance_variable_get(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@"); _s.concat_raw_bytes!((    opt).to_s) }.to_sym); _and3.truthy? ? (((instance_variable_get(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@"); _s.concat_raw_bytes!((    depended_opt).to_s) }.to_sym).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and3).truthy?
      raise RuntimeError.new(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("`"); _s.concat_raw_bytes!((      opt).to_s); _s.concat_raw_bytes!("' depends upon `"); _s.concat_raw_bytes!((      depended_opt).to_s); _s.concat_raw_bytes!("'") }.to_s)
    end
  end

  def gen(*codes : RubyObject)
    (codes.map() { |code|     code.ruby_to_s.chomp }.join(Ruby_Str_6) + Ruby_Str_6)
  end

  def indent(i : Int64, code : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    if (i > 0_i64)
      code.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral) {       ((Ruby_Str_7 * RubyInteger.new(i)) + (RUBY_GLOBALS["1"]? || RUBY_NIL)) }
    else
      if (i < 0_i64)
        code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral, Ruby_Str_10)
      else
        code
      end
    end
  end

  def indent(i : RubyObject, code : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    if ((i > RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      code.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral) {       ((Ruby_Str_7 * i) + (RUBY_GLOBALS["1"]? || RUBY_NIL)) }
    else
      if ((i < RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral, Ruby_Str_10)
      else
        code
      end
    end
  end

  def branch(cond : RubyObject, code1 : RubyObject, code2 : RubyObject)
    gen(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("if "); _s.concat_raw_bytes!((    cond).to_s) }, indent(RubyInteger.new(2_i64), code1), Ruby_Str_12, indent(RubyInteger.new(2_i64), code2), Ruby_Str_13)
  end

  def parse_method_definitions(file : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteral    src = Ruby_File.read(file)
    mdefs = RubyHash.new
    src.scan(Ruby_METHOD_DEFINITIONS_RE) { |indent, meth, params, body|     body = indent(((indent.size.-) - RubyInteger.new(2_i64)), body)
    body = body.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral) {     (((((RUBY_GLOBALS["1"]? || RUBY_NIL) + RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("when "); _s.concat_raw_bytes!((    (RUBY_GLOBALS["2"]? || RUBY_NIL)).to_s); _s.concat_raw_bytes!("\n") }) + (RUBY_GLOBALS["1"]? || RUBY_NIL)) + Ruby_Str_15) + (RUBY_GLOBALS["3"]? || RUBY_NIL)) }
    if ((body =~ ["RUBY_NIL # UNSUPPORTED: RegexpLiteral"]) ? RUBY_TRUE : RUBY_FALSE).truthy?
      body = (((Ruby_Str_11 + (RUBY_GLOBALS["1"]? || RUBY_NIL)) + indent(RubyInteger.new(2_i64), (RUBY_GLOBALS["'"]? || RUBY_NIL))) + Ruby_Str_16)
    end
    while body.gsub!(RUBY_NIL # UNSUPPORTED: RegexpLiteral) {     indent((RUBY_GLOBALS["1"]? || RUBY_NIL).size, gen((RUBY_GLOBALS["3"]? || RUBY_NIL), (Ruby_Str_15 + (RUBY_GLOBALS["2"]? || RUBY_NIL)), Ruby_Str_13)) }.truthy?
      RUBY_NIL
    end
    mdefs[meth.to_sym] = Ruby_MethodDef.[](if params.truthy?
      params.split(Ruby_Str_17)
    else
      RUBY_NIL
    end, body) }
    mdefs
  end

  def expand_methods(code : RubyObject, mdefs : RubyObject, meths : RubyObject = (mdefs.keys))
RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral) {     _ma4 = masgn_coerce(RubyTuple3.new((RUBY_GLOBALS["1"]? || RUBY_NIL), (RUBY_GLOBALS["2"]? || RUBY_NIL), (RUBY_GLOBALS["3"]? || RUBY_NIL)))
    indent = _ma4[0_i64]
    meth = _ma4[1_i64]
    args = _ma4[2_i64]
    body = mdefs[meth.to_sym]
    if (body.is_a?(Ruby_MethodDef) ? RUBY_TRUE : RUBY_FALSE)
      body = body.body
    end
    if args.truthy?
      mdefs[meth.to_sym].params.zip(args.split(Ruby_Str_17)) { |param, arg|       body = replace_var(body, param, arg) }
    end
    indent(indent.size, body) }
  end

  def expand_inline_methods(code : RubyObject, meth : RubyObject, mdef : RubyObject)
RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteral    code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral) {     args = (RUBY_GLOBALS["1"]? || RUBY_NIL)
    b = RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("("); _s.concat_raw_bytes!((    mdef.body.chomp.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral, Ruby_Str_10).gsub(Ruby_Str_6, Ruby_Str_24)).to_s); _s.concat_raw_bytes!(")") }
    if args.truthy?
      mdef.params.zip(args.split(Ruby_Str_17)) { |param, arg|       b = replace_var(b, param, arg) }
    end
    b }
  end

  def replace_var(code : RubyObject, var : RubyObject, bool : RubyObject)
RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteralRUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    re = if var.start_with?(Ruby_Str_3).truthy?
      RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral
    else
      RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral
    end
    code.gsub(re) {     bool }
  end

  def replace_cond_var(code : RubyObject, var : RubyObject, bool : RubyObject)
RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral) {     (((RUBY_GLOBALS["1"]? || RUBY_NIL) + Ruby_Str_7) + bool) }
  end

  def remove_trivial_branches(code : RubyObject)
    code = code.dup
    while code.gsub!(Ruby_TRIVIAL_BRANCH_RE) {     if ((    (((RUBY_GLOBALS["2"]? || RUBY_NIL) == Ruby_Str_27) ? RUBY_TRUE : RUBY_FALSE) ==     (((RUBY_GLOBALS["3"]? || RUBY_NIL) == Ruby_Str_28) ? RUBY_TRUE : RUBY_FALSE)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      indent(RubyInteger.new(-2_i64), (RUBY_GLOBALS["4"]? || RUBY_NIL))
    else
      if (RUBY_GLOBALS["5"]? || RUBY_NIL).truthy?
        indent(RubyInteger.new(-2_i64), (RUBY_GLOBALS["5"]? || RUBY_NIL))
      else
        Ruby_Str_10
      end
    end }.truthy?
      RUBY_NIL
    end
    code
  end

  def localize_instance_variables(code : RubyObject, ivars : RubyObject = (RUBY_NIL # UNSUPPORTED: RegexpLiteralcode.scan(RUBY_NIL # UNSUPPORTED: RegexpLiteral).uniq.sort))
RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral    ivars = ivars.map() { |ivar|     ivar.ruby_to_s[RubyRange.new(RubyInteger.new(1_i64), RubyInteger.new(-1_i64), false)] }
    _ma5 = masgn_coerce(RubyTuple2.new(RubyArray.new([] of RubyObject), RubyArray.new([] of RubyObject)))
    inits = _ma5[0_i64]
    finals = _ma5[1_i64]
    ivars.each() { |ivar|     lvar = RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("__"); _s.concat_raw_bytes!((    ivar).to_s); _s.concat_raw_bytes!("__") }
    (inits << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!((    lvar).to_s); _s.concat_raw_bytes!(" = @"); _s.concat_raw_bytes!((    ivar).to_s) })
    (finals << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@"); _s.concat_raw_bytes!((    ivar).to_s); _s.concat_raw_bytes!(" = "); _s.concat_raw_bytes!((    lvar).to_s) }) }
    code = code.gsub(RUBY_NIL # UNSUPPORTED: InterpolatedRegexpLiteral) {     RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("__"); _s.concat_raw_bytes!((    (RUBY_GLOBALS["1"]? || RUBY_NIL)).to_s); _s.concat_raw_bytes!("__") } }
    gen(Ruby_Str_34, indent(RubyInteger.new(2_i64), inits.join(Ruby_Str_6)), indent(RubyInteger.new(2_i64), code), Ruby_Str_35, indent(RubyInteger.new(2_i64), finals.join(Ruby_Str_6)), Ruby_Str_13)
  end

end
class Ruby_MethodDef < RubyObject
  @params : RubyObject = RUBY_NIL
  @body : RubyObject = RUBY_NIL

  def to_s : String; "#<MethodDef>"; end
  def inspect : String; "#<MethodDef>"; end

  def initialize(@params : RubyObject = RUBY_NIL, @body : RubyObject = RUBY_NIL); end

  def params : RubyObject; @params; end
  def params=(v : RubyObject) : RubyObject; @params = v; v; end
  def body : RubyObject; @body; end
  def body=(v : RubyObject) : RubyObject; @body = v; v; end

      RESPOND_TO_TABLE = StaticArray[false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
class Ruby_PPU < RubyObject
    @conf : RubyObject = RUBY_NIL
    @cpu : RubyObject = RUBY_NIL
    @nmt_mem : RubyArray = RubyArray.new
    @nmt_ref : RubyObject = RUBY_NIL
    @output_color : RubyObject = RUBY_NIL
    @output_pixels : RubyArray = RubyArray.new
    @palette : RubyObject = RUBY_NIL
    @a12_monitor : RubyObject = RUBY_NIL
    @a12_state : Ruby_PPU | RubyNil = RUBY_NIL
    @any_show : RubyObject = RUBY_NIL
    @bg_enabled : RubyObject = RUBY_NIL
    @bg_pattern : RubyInteger | RubyNil = RUBY_NIL
    @bg_pattern_base : RubyObject = RUBY_NIL
    @bg_pattern_base_15 : RubyObject = RUBY_NIL
    @bg_pattern_lut : RubyObject = RUBY_NIL
    @bg_pattern_lut_fetched : RubyObject = RUBY_NIL
    @bg_pixels : RubyObject = RUBY_NIL
    @bg_show : RubyObject = RUBY_NIL
    @bg_show_edge : RubyObject = RUBY_NIL
    @coloring : RubyObject = RUBY_NIL
    @emphasis : RubyObject = RUBY_NIL
    @hclk : RubyObject = RUBY_NIL
    @hclk_target : RubyObject = RUBY_NIL
    @io_addr : RubyObject = RUBY_NIL
    @io_buffer : RubyObject = RUBY_NIL
    @io_latch : RubyObject = RUBY_NIL
    @io_pattern : RubyInteger | RubyNil = RUBY_NIL
    @name_io_addr : RubyObject = RUBY_NIL
    @need_nmi : RubyObject = RUBY_NIL
    @odd_frame : RubyObject = RUBY_NIL
    @palette_ram : RubyArray = RubyArray.new
    @pattern_end : RubyObject = RUBY_NIL
    @regs_oam : RubyObject = RUBY_NIL
    @run : RubyObject = RUBY_NIL
    @scanline : RubyObject = RUBY_NIL
    @scroll_addr_0_4 : RubyObject = RUBY_NIL
    @scroll_addr_5_14 : RubyObject = RUBY_NIL
    @scroll_latch : RubyObject = RUBY_NIL
    @scroll_toggle : RubyObject = RUBY_NIL
    @scroll_xfine : RubyInteger | RubyNil = RUBY_NIL
    @sp_active : RubyObject = RUBY_NIL
    @sp_addr : RubyObject = RUBY_NIL
    @sp_base : RubyObject = RUBY_NIL
    @sp_buffer : RubyObject = RUBY_NIL
    @sp_buffered : RubyInteger | RubyNil = RUBY_NIL
    @sp_enabled : RubyObject = RUBY_NIL
    @sp_height : RubyObject = RUBY_NIL
    @sp_index : RubyInteger | RubyNil = RUBY_NIL
    @sp_latch : RubyInteger | RubyNil = RUBY_NIL
    @sp_limit : RubyObject = RUBY_NIL
    @sp_map : RubyObject = RUBY_NIL
    @sp_map_buffer : RubyObject = RUBY_NIL
    @sp_overflow : RubyObject = RUBY_NIL
    @sp_phase : RubyObject = RUBY_NIL
    @sp_ram : RubyObject = RUBY_NIL
    @sp_show : RubyObject = RUBY_NIL
    @sp_show_edge : RubyObject = RUBY_NIL
    @sp_visible : RubyObject = RUBY_NIL
    @sp_zero_hit : RubyObject = RUBY_NIL
    @sp_zero_in_line : RubyObject = RUBY_NIL
    @vblank : RubyObject = RUBY_NIL
    @vblanking : RubyObject = RUBY_NIL
    @vclk : RubyInteger | RubyNil = RUBY_NIL
    @vram_addr_inc : RubyObject = RUBY_NIL
    @attr_lut : RubyObject = RUBY_NIL
    @lut_update : RubyObject = RUBY_NIL
    @name_lut : RubyObject = RUBY_NIL
    @chr_mem : RubyObject = RUBY_NIL
    @chr_mem_writable : RubyObject = RUBY_NIL
    @fiber : RubyObject = RUBY_NIL

    def to_s : String; "#<PPU>"; end
    Ruby_RP2C02_CC = RubyInteger.new(4_i64)
  Ruby_RP2C02_HACTIVE = RubyInteger.new(1024_i64)
  Ruby_RP2C02_HBLANK = RubyInteger.new(340_i64)
  Ruby_RP2C02_HSYNC = RubyInteger.new(1364_i64)
  Ruby_RP2C02_VACTIVE = RubyInteger.new(240_i64)
  Ruby_RP2C02_VSLEEP = RubyInteger.new(1_i64)
  Ruby_RP2C02_VINT = RubyInteger.new(20_i64)
  Ruby_RP2C02_VDUMMY = RubyInteger.new(1_i64)
  Ruby_RP2C02_VBLANK = RubyInteger.new(22_i64)
  Ruby_RP2C02_VSYNC = RubyInteger.new(262_i64)
  Ruby_RP2C02_HVSYNCBOOT = RubyInteger.new(328608_i64)
  Ruby_RP2C02_HVINT = RubyInteger.new(27280_i64)
  Ruby_RP2C02_HVSYNC_0 = RubyInteger.new(357368_i64)
  Ruby_RP2C02_HVSYNC_1 = RubyInteger.new(357364_i64)
  Ruby_SCANLINE_HDUMMY = RubyInteger.new(-1_i64)
  Ruby_SCANLINE_VBLANK = RubyInteger.new(240_i64)
  Ruby_HCLOCK_DUMMY = RubyInteger.new(341_i64)
  Ruby_HCLOCK_VBLANK_0 = RubyInteger.new(681_i64)
  Ruby_HCLOCK_VBLANK_1 = RubyInteger.new(682_i64)
  Ruby_HCLOCK_VBLANK_2 = RubyInteger.new(684_i64)
  Ruby_HCLOCK_BOOT = RubyInteger.new(685_i64)
  Ruby_DUMMY_FRAME = RubyArray.new([RubyInteger.new(6479_i64), RubyInteger.new(27280_i64), RubyInteger.new(357368_i64)] of RubyObject)
  Ruby_BOOT_FRAME = RubyArray.new([RubyInteger.new(81467_i64), RubyInteger.new(328608_i64), RubyInteger.new(328608_i64)] of RubyObject)

  def inspect : String
(begin
      RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("#<"); _s.concat_raw_bytes!((      ruby_class).to_s); _s.concat_raw_bytes!(">") }
    end).to_s
  end

  def initialize(conf : RubyObject, cpu : RubyObject, palette : RubyObject)
    @conf = conf
    @cpu = cpu
    @palette = palette
    if @conf.load_ppu.truthy?
      eval(Ruby_File.read(@conf.load_ppu))
    else
      if @conf.opt_ppu.truthy?
        eval(Ruby_OptimizedCodeBuilder.new(@conf.loglevel, @conf.opt_ppu).build, RUBY_NIL, Ruby_Str_38)
      end
    end
    @nmt_mem = RubyTuple2.new((RubyTuple1.new(RubyInteger.new(255_i64)) * RubyInteger.new(1024_i64)), (RubyTuple1.new(RubyInteger.new(255_i64)) * RubyInteger.new(1024_i64)))
    @nmt_ref = RubyTuple4.new(RubyInteger.new(0_i64), RubyInteger.new(1_i64), RubyInteger.new(0_i64), RubyInteger.new(1_i64)).map() { |i|     @nmt_mem[i] }
    @output_pixels = RubyArray.new([] of RubyObject)
    @output_color = (RubyTuple1.new(@palette[0_i64]) * RubyInteger.new(32_i64))
    reset(mapping: RUBY_FALSE)
    setup_lut
  end

  def reset(opt : RubyObject = (RubyHash.new))
    if opt.fetch(Ruby_Sym_2, RUBY_TRUE).truthy?
      @cpu.add_mappings(RubyInteger.new(8192_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_3), method(Ruby_Sym_4))
      @cpu.add_mappings(RubyInteger.new(8193_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_3), method(Ruby_Sym_5))
      @cpu.add_mappings(RubyInteger.new(8194_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_6), method(Ruby_Sym_7))
      @cpu.add_mappings(RubyInteger.new(8195_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_3), method(Ruby_Sym_8))
      @cpu.add_mappings(RubyInteger.new(8196_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_9), method(Ruby_Sym_10))
      @cpu.add_mappings(RubyInteger.new(8197_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_3), method(Ruby_Sym_11))
      @cpu.add_mappings(RubyInteger.new(8198_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_3), method(Ruby_Sym_12))
      @cpu.add_mappings(RubyInteger.new(8199_i64).step(RubyInteger.new(16383_i64), RubyInteger.new(8_i64)), method(Ruby_Sym_13), method(Ruby_Sym_14))
      @cpu.add_mappings(RubyInteger.new(12288_i64), method(Ruby_Sym_15), method(Ruby_Sym_4))
      @cpu.add_mappings(RubyInteger.new(16404_i64), method(Ruby_Sym_16), method(Ruby_Sym_17))
    end
    @palette_ram = Ruby_Arr_2
    @coloring = RubyInteger.new(63_i64)
    @emphasis = RubyInteger.new(0_i64)
    update_output_color
    @run = RUBY_TRUE
    @hclk = Ruby_HCLOCK_BOOT
    @vclk = RubyInteger.new(0_i64)
    @hclk_target = Ruby_FOREVER_CLOCK
    @io_latch = RubyInteger.new(0_i64)
    @io_buffer = RubyInteger.new(232_i64)
    @regs_oam = RubyInteger.new(0_i64)
    @vram_addr_inc = RubyInteger.new(1_i64)
    @need_nmi = RUBY_FALSE
    @pattern_end = RubyInteger.new(4080_i64)
    @any_show = RUBY_FALSE
    @sp_overflow = RUBY_FALSE
    @sp_zero_hit = RUBY_FALSE
    @vblanking = @vblank = RUBY_FALSE
    @io_addr = RubyInteger.new(0_i64)
    @io_pattern = RubyInteger.new(0_i64)
    @a12_monitor = RUBY_NIL
    @a12_state = RUBY_NIL
    @odd_frame = RUBY_FALSE
    @scanline = Ruby_SCANLINE_VBLANK
    @scroll_toggle = RUBY_FALSE
    @scroll_latch = RubyInteger.new(0_i64)
    @scroll_xfine = RubyInteger.new(0_i64)
    @scroll_addr_0_4 = @scroll_addr_5_14 = RubyInteger.new(0_i64)
    @name_io_addr = RubyInteger.new(8192_i64)
    @bg_enabled = RUBY_FALSE
    @bg_show = RUBY_FALSE
    @bg_show_edge = RUBY_FALSE
    @bg_pixels = (RubyTuple1.new(RubyInteger.new(0_i64)) * RubyInteger.new(16_i64))
    @bg_pattern_base = RubyInteger.new(0_i64)
    @bg_pattern_base_15 = RubyInteger.new(0_i64)
    @bg_pattern = RubyInteger.new(0_i64)
    @bg_pattern_lut = Ruby_TILE_LUT[0_i64]
    @bg_pattern_lut_fetched = Ruby_TILE_LUT[0_i64]
    @sp_enabled = RUBY_FALSE
    @sp_active = RUBY_FALSE
    @sp_show = RUBY_FALSE
    @sp_show_edge = RUBY_FALSE
    @sp_base = RubyInteger.new(0_i64)
    @sp_height = RubyInteger.new(8_i64)
    @sp_phase = RubyInteger.new(0_i64)
    @sp_ram = (RubyTuple1.new(RubyInteger.new(255_i64)) * RubyInteger.new(256_i64))
    @sp_index = RubyInteger.new(0_i64)
    @sp_addr = RubyInteger.new(0_i64)
    @sp_latch = RubyInteger.new(0_i64)
    @sp_limit = (    if @conf.sprite_limit.truthy?
      RubyInteger.new(8_i64)
    else
      RubyInteger.new(32_i64)
    end * RubyInteger.new(4_i64))
    @sp_buffer = (RubyTuple1.new(RubyInteger.new(0_i64)) * @sp_limit)
    @sp_buffered = RubyInteger.new(0_i64)
    @sp_visible = RUBY_FALSE
    @sp_map = (RubyTuple1.new(RUBY_NIL) * RubyInteger.new(264_i64))
    @sp_map_buffer =     RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(264_i64), true).map() {     RubyTuple3.new(RUBY_FALSE, RUBY_FALSE, RubyInteger.new(0_i64)) }
    @sp_zero_in_line = RUBY_FALSE
  end

  def update_output_color
    32_i64.times { |i|     @output_color[i] = @palette[((@palette_ram[i] & @coloring) | @emphasis)] }
  end

  def setup_lut
    @lut_update = RubyHash.new.compare_by_identity
    @name_lut =     RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(65535_i64), false).map() { |i|     nmt_bank = @nmt_ref[((i >> RubyInteger.new(10_i64)) & RubyInteger.new(3_i64))]
    nmt_idx = (i.to_i64 & 1023_i64)
    fixed = (    ((i >> RubyInteger.new(12_i64)) & RubyInteger.new(7_i64)) |     (i[15_i64] << RubyInteger.new(12_i64)))
    (    (_iorw_r6 =     (_iorw_r7 =     (_iorw_r8 = @lut_update; _iorw_i8 = nmt_bank; _iorw_c8 = _iorw_r8[_iorw_i8]; _iorw_c8.truthy? ? _iorw_c8 : (_iorw_r8[_iorw_i8] = RubyArray.new([] of RubyObject))); _iorw_i7 = RubyInteger.new(nmt_idx); _iorw_c7 = _iorw_r7[_iorw_i7]; _iorw_c7.truthy? ? _iorw_c7 : (_iorw_r7[_iorw_i7] = RubyTuple2.new(RUBY_NIL, RUBY_NIL))); _iorw_i6 = RubyInteger.new(0_i64); _iorw_c6 = _iorw_r6[_iorw_i6]; _iorw_c6.truthy? ? _iorw_c6 : (_iorw_r6[_iorw_i6] = RubyArray.new([] of RubyObject))) << RubyTuple2.new(i, fixed))
    ((nmt_bank[nmt_idx] << RubyInteger.new(4_i64)) | fixed) }
    entries = RubyHash.new
    @attr_lut =     RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(32767_i64), false).map() { |i|     io_addr = (((RubyInteger.new(9152_i64) |     (i & RubyInteger.new(3072_i64))) |     ((i >> RubyInteger.new(4_i64)) & RubyInteger.new(56_i64))) |     ((i >> RubyInteger.new(2_i64)) & RubyInteger.new(7_i64))).to_i64
    nmt_bank = @nmt_ref[((io_addr >> 10_i64) & 3_i64)]
    nmt_idx = (io_addr & 1023_i64)
    attr_shift = (    (i & RubyInteger.new(2_i64)) |     ((i >> RubyInteger.new(4_i64)) & RubyInteger.new(4_i64))).to_i64
    key = RubyArray.new([RubyInteger.new(io_addr), RubyInteger.new(attr_shift)] of RubyObject)
    (_iorw_r9 = entries; _iorw_i9 = key; _iorw_c9 = _iorw_r9[_iorw_i9]; _iorw_c9.truthy? ? _iorw_c9 : (_iorw_r9[_iorw_i9] = RubyTuple3.new(RubyInteger.new(io_addr), Ruby_TILE_LUT[((nmt_bank[nmt_idx] >> RubyInteger.new(attr_shift)) & RubyInteger.new(3_i64))], RubyInteger.new(attr_shift))))
    (    (_iorw_r10 =     (_iorw_r11 =     (_iorw_r12 = @lut_update; _iorw_i12 = nmt_bank; _iorw_c12 = _iorw_r12[_iorw_i12]; _iorw_c12.truthy? ? _iorw_c12 : (_iorw_r12[_iorw_i12] = RubyArray.new([] of RubyObject))); _iorw_i11 = RubyInteger.new(nmt_idx); _iorw_c11 = _iorw_r11[_iorw_i11]; _iorw_c11.truthy? ? _iorw_c11 : (_iorw_r11[_iorw_i11] = RubyTuple2.new(RUBY_NIL, RUBY_NIL))); _iorw_i10 = RubyInteger.new(1_i64); _iorw_c10 = _iorw_r10[_iorw_i10]; _iorw_c10.truthy? ? _iorw_c10 : (_iorw_r10[_iorw_i10] = RubyArray.new([] of RubyObject))) << entries[key])
    entries[key] }.freeze
    entries.each_value() { |a|     a.uniq!() { |entry|     entry.object_id } }
  end

    def output_pixels : RubyArray; @output_pixels; end
  def set_chr_mem(mem : RubyObject, writable : RubyObject)
    @chr_mem = mem
    @chr_mem_writable = writable
  end

  def nametables=(mode : RubyObject)
    update(Ruby_RP2C02_CC)
    idxs = Ruby_NMT_TABLE[mode]
    if     RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(3_i64), false).all?() { |i|     @nmt_ref[i].equal?(@nmt_mem[idxs[i]]) }.truthy?
      return
    end
    @nmt_ref[0_i64] = @nmt_mem[idxs[0_i64]]
    @nmt_ref[1_i64] = @nmt_mem[idxs[1_i64]]
    @nmt_ref[2_i64] = @nmt_mem[idxs[2_i64]]
    @nmt_ref[3_i64] = @nmt_mem[idxs[3_i64]]
    setup_lut
  end

  def update(data_setup : RubyObject)
    sync((data_setup + @cpu.update))
  end

  def setup_frame
    @output_pixels.clear
    @odd_frame = ((@odd_frame.truthy?) ? RUBY_FALSE : RUBY_TRUE)
    _ma13 = masgn_coerce(if ((@hclk == Ruby_HCLOCK_DUMMY) ? RUBY_TRUE : RUBY_FALSE).truthy?
      Ruby_DUMMY_FRAME
    else
      Ruby_BOOT_FRAME
    end)
    @vclk = _ma13[0_i64]
    @hclk_target = _ma13[1_i64]
    @cpu.next_frame_clock= = _ma13[2_i64]
  end

  def vsync
    if ((@hclk_target != Ruby_FOREVER_CLOCK) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @hclk_target = Ruby_FOREVER_CLOCK
      run
    end
    while ((@output_pixels.size < RubyInteger.new(256_i64 * 240_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      (@output_pixels << @palette[15_i64])
    end
  end

  def monitor_a12_rising_edge(monitor : RubyObject)
    @a12_monitor = monitor
  end

  def update_vram_addr
    if ((@vram_addr_inc == RubyInteger.new(32_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      if active?.truthy?
        if (((@scroll_addr_5_14 & RubyInteger.new(28672_i64)) == RubyInteger.new(28672_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
          @scroll_addr_5_14 = (@scroll_addr_5_14 & RubyInteger.new(4095_i64))
          _case_subj = (@scroll_addr_5_14 & RubyInteger.new(992_i64))
          if (RubyInteger.new(928_i64)) == _case_subj
            @scroll_addr_5_14 = (@scroll_addr_5_14 ^ RubyInteger.new(2048_i64))
          elsif (RubyInteger.new(992_i64)) == _case_subj
            @scroll_addr_5_14 = (@scroll_addr_5_14 & RubyInteger.new(31744_i64))
          else
            @scroll_addr_5_14 = (@scroll_addr_5_14 + RubyInteger.new(32_i64))
          end
        else
          @scroll_addr_5_14 = (@scroll_addr_5_14 + RubyInteger.new(4096_i64))
        end
      else
        @scroll_addr_5_14 = (@scroll_addr_5_14 + RubyInteger.new(32_i64))
      end
    else
      if ((@scroll_addr_0_4 < RubyInteger.new(31_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @scroll_addr_0_4 = (@scroll_addr_0_4 + RubyInteger.new(1_i64))
      else
        @scroll_addr_0_4 = RubyInteger.new(0_i64)
        @scroll_addr_5_14 = (@scroll_addr_5_14 + RubyInteger.new(32_i64))
      end
    end
    update_scroll_address_line
  end

  def update_scroll_address_line
    @name_io_addr = ((    (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(4095_i64)) | RubyInteger.new(8192_i64))
    if @a12_monitor.truthy?
      a12_state = (((@scroll_addr_5_14 & RubyInteger.new(12288_i64)) == RubyInteger.new(4096_i64)) ? RUBY_TRUE : RUBY_FALSE)
      if (_and14 = ((@a12_state.truthy?) ? RUBY_FALSE : RUBY_TRUE); _and14.truthy? ? (a12_state) : _and14).truthy?
        @a12_monitor.a12_signaled(@cpu.current_clock)
      end
      @a12_state = a12_state
    end
  end

  def active?
    (_and15 = ((@scanline != Ruby_SCANLINE_VBLANK) ? RUBY_TRUE : RUBY_FALSE); _and15.truthy? ? (@any_show) : _and15)
  end

  def sync(elapsed : RubyObject)
    unless ((@hclk_target < elapsed) ? RUBY_TRUE : RUBY_FALSE).truthy?
      return
    end
    @hclk_target = ((elapsed / Ruby_RP2C02_CC) - @vclk)
    run
  end

  def make_sure_invariants
    @name_io_addr = ((    (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(4095_i64)) | RubyInteger.new(8192_i64))
    @bg_pattern_lut_fetched = Ruby_TILE_LUT[((@nmt_ref[((@io_addr >> RubyInteger.new(10_i64)) & RubyInteger.new(3_i64))][(@io_addr & RubyInteger.new(1023_i64))] >>     (    (@scroll_addr_0_4 & RubyInteger.new(2_i64)) |     (@scroll_addr_5_14[6_i64] * RubyInteger.new(4_i64)))) & RubyInteger.new(3_i64))]
  end

  def io_latch_mask(data : RubyObject)
    if active?.truthy?
      RubyInteger.new(255_i64)
    else
      if (((@regs_oam & RubyInteger.new(3_i64)) == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        (data & RubyInteger.new(227_i64))
      else
        data
      end
    end
  end

  def poke_2000(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    need_nmi_old = @need_nmi
    @scroll_latch = (    (@scroll_latch & RubyInteger.new(29695_i64)) | (    (data & RubyInteger.new(3_i64)) << RubyInteger.new(10_i64)))
    @vram_addr_inc = if ((data[2_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyInteger.new(32_i64)
    else
      RubyInteger.new(1_i64)
    end
    @sp_base = if ((data[3_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyInteger.new(4096_i64)
    else
      RubyInteger.new(0_i64)
    end
    @bg_pattern_base = if ((data[4_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyInteger.new(4096_i64)
    else
      RubyInteger.new(0_i64)
    end
    @sp_height = if ((data[5_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyInteger.new(16_i64)
    else
      RubyInteger.new(8_i64)
    end
    @need_nmi = ((data[7_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
    @io_latch = data
    @pattern_end = if (_or16 = ((@sp_base != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _or16.truthy? ? _or16 : (((@sp_height == RubyInteger.new(16_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      RubyInteger.new(8176_i64)
    else
      RubyInteger.new(4080_i64)
    end
    @bg_pattern_base_15 = (@bg_pattern_base[12_i64] << RubyInteger.new(15_i64))
    if (_and17 = (_and18 = @need_nmi; _and18.truthy? ? (@vblank) : _and18); _and17.truthy? ? (((need_nmi_old.truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and17).truthy?
      clock = (@cpu.current_clock + Ruby_RP2C02_CC)
      if ((clock < Ruby_RP2C02_HVINT) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @cpu.do_nmi(clock)
      end
    end
  end

  def poke_2001(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    _ma19 = masgn_coerce(RubyTuple2.new(@bg_show, @bg_show_edge))
    bg_show_old = _ma19[0_i64]
    bg_show_edge_old = _ma19[1_i64]
    _ma20 = masgn_coerce(RubyTuple2.new(@sp_show, @sp_show_edge))
    sp_show_old = _ma20[0_i64]
    sp_show_edge_old = _ma20[1_i64]
    any_show_old = @any_show
    _ma21 = masgn_coerce(RubyTuple2.new(@coloring, @emphasis))
    coloring_old = _ma21[0_i64]
    emphasis_old = _ma21[1_i64]
    @bg_show = ((data[3_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
    @bg_show_edge = (_and22 = ((data[1_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE); _and22.truthy? ? (@bg_show) : _and22)
    @sp_show = ((data[4_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
    @sp_show_edge = (_and23 = ((data[2_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE); _and23.truthy? ? (@sp_show) : _and23)
    @any_show = (_or24 = @bg_show; _or24.truthy? ? _or24 : (@sp_show))
    @coloring = if ((data[0_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyInteger.new(48_i64)
    else
      RubyInteger.new(63_i64)
    end
    @emphasis = (    (data & RubyInteger.new(224_i64)) << RubyInteger.new(1_i64))
    @io_latch = data
    if (_or25 = (_or26 = (_or27 = ((bg_show_old != @bg_show) ? RUBY_TRUE : RUBY_FALSE); _or27.truthy? ? _or27 : (((bg_show_edge_old != @bg_show_edge) ? RUBY_TRUE : RUBY_FALSE))); _or26.truthy? ? _or26 : (((sp_show_old != @sp_show) ? RUBY_TRUE : RUBY_FALSE))); _or25.truthy? ? _or25 : (((sp_show_edge_old != @sp_show_edge) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      if (_or28 = ((@hclk < RubyInteger.new(8_i64)) ? RUBY_TRUE : RUBY_FALSE); _or28.truthy? ? _or28 : (((@hclk >= RubyInteger.new(248_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
        update_enabled_flags_edge
      else
        update_enabled_flags
      end
      if (_and29 = any_show_old; _and29.truthy? ? (((@any_show.truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and29).truthy?
        update_scroll_address_line
      end
    end
    if (_or30 = ((coloring_old != @coloring) ? RUBY_TRUE : RUBY_FALSE); _or30.truthy? ? _or30 : (((emphasis_old != @emphasis) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      update_output_color
    end
  end

  def peek_2002(_addr : RubyObject)
    update(Ruby_RP2C02_CC)
    v = (@io_latch & RubyInteger.new(31_i64))
    if @vblank.truthy?
      v = (v | RubyInteger.new(128_i64))
    end
    if @sp_zero_hit.truthy?
      v = (v | RubyInteger.new(64_i64))
    end
    if @sp_overflow.truthy?
      v = (v | RubyInteger.new(32_i64))
    end
    @io_latch = v
    @scroll_toggle = RUBY_FALSE
    @vblanking = @vblank = RUBY_FALSE
    @io_latch
  end

  def poke_2003(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    @regs_oam = @io_latch = data
  end

  def poke_2004(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    @io_latch = @sp_ram[@regs_oam] = io_latch_mask(data)
    @regs_oam = (    (@regs_oam + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
  end

  def peek_2004(_addr : RubyObject)
    if (_or31 = ((@any_show.truthy?) ? RUBY_FALSE : RUBY_TRUE); _or31.truthy? ? _or31 : ((((@cpu.current_clock -     (@cpu.next_frame_clock - (    RubyInteger.new(341_i64 * 241_i64) * Ruby_RP2C02_CC))) >= (    RubyInteger.new(341_i64 * 240_i64) * Ruby_RP2C02_CC)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      @io_latch = @sp_ram[@regs_oam]
    else
      update(Ruby_RP2C02_CC)
      @io_latch = @sp_latch
    end
  end

  def poke_2005(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    @io_latch = data
    @scroll_toggle = ((@scroll_toggle.truthy?) ? RUBY_FALSE : RUBY_TRUE)
    if @scroll_toggle.truthy?
      @scroll_latch = ((@scroll_latch & RubyInteger.new(32736_i64)) |       (data >> RubyInteger.new(3_i64)))
      xfine = (RubyInteger.new(8_i64) -       (data & RubyInteger.new(7_i64)))
      @bg_pixels.rotate!((@scroll_xfine - xfine))
      @scroll_xfine = xfine
    else
      @scroll_latch = (      (@scroll_latch & RubyInteger.new(3103_i64)) |       (      ((data << RubyInteger.new(2_i64)) | (data << RubyInteger.new(12_i64))) & RubyInteger.new(29664_i64)))
    end
  end

  def poke_2006(_addr : RubyObject, data : RubyObject)
    update(Ruby_RP2C02_CC)
    @io_latch = data
    @scroll_toggle = ((@scroll_toggle.truthy?) ? RUBY_FALSE : RUBY_TRUE)
    if @scroll_toggle.truthy?
      @scroll_latch = ((@scroll_latch & RubyInteger.new(255_i64)) | (      (data & RubyInteger.new(63_i64)) << RubyInteger.new(8_i64)))
    else
      @scroll_latch = (      (@scroll_latch & RubyInteger.new(32512_i64)) | data)
      @scroll_addr_0_4 = (@scroll_latch & RubyInteger.new(31_i64))
      @scroll_addr_5_14 = (@scroll_latch & RubyInteger.new(32736_i64))
      update_scroll_address_line
    end
  end

  def poke_2007(_addr : RubyObject, data : RubyObject)
    update((Ruby_RP2C02_CC * RubyInteger.new(4_i64)))
    addr = (@scroll_addr_0_4 | @scroll_addr_5_14)
    update_vram_addr
    @io_latch = data
    if (((addr & RubyInteger.new(16128_i64)) == RubyInteger.new(16128_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      addr = (addr & RubyInteger.new(31_i64))
      final = @palette[((data & @coloring) | @emphasis)]
      @palette_ram[addr] = data
      @output_color[addr] = final
      if (((addr & RubyInteger.new(3_i64)) == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @palette_ram[(addr ^ RubyInteger.new(16_i64))] = data
        @output_color[(addr ^ RubyInteger.new(16_i64))] = final
      end
    else
      addr = (addr & RubyInteger.new(16383_i64))
      if ((addr >= RubyInteger.new(8192_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        nmt_bank = @nmt_ref[((addr >> RubyInteger.new(10_i64)) & RubyInteger.new(3_i64))]
        nmt_idx = (addr & RubyInteger.new(1023_i64))
        if ((nmt_bank[nmt_idx] != data) ? RUBY_TRUE : RUBY_FALSE).truthy?
          nmt_bank[nmt_idx] = data
          _ma32 = masgn_coerce(@lut_update[nmt_bank][nmt_idx])
          name_lut_update = _ma32[0_i64]
          attr_lut_update = _ma32[1_i64]
          if name_lut_update.truthy?
            name_lut_update.each() { |i, b|             @name_lut[i] = ((data << RubyInteger.new(4_i64)) | b) }
          end
          if attr_lut_update.truthy?
            attr_lut_update.each() { |a|             a[1_i64] = Ruby_TILE_LUT[((data >> a[2_i64]) & RubyInteger.new(3_i64))] }
          end
        end
      else
        if @chr_mem_writable.truthy?
          @chr_mem[addr] = data
        end
      end
    end
  end

  def peek_2007(_addr : RubyObject)
    update(Ruby_RP2C02_CC)
    addr = (    (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(16383_i64))
    update_vram_addr
    @io_latch = if ((    (addr & RubyInteger.new(16128_i64)) != RubyInteger.new(16128_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @io_buffer
    else
      (@palette_ram[(addr & RubyInteger.new(31_i64))] & @coloring)
    end
    @io_buffer = if ((addr >= RubyInteger.new(8192_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @nmt_ref[((addr >> RubyInteger.new(10_i64)) & RubyInteger.new(3_i64))][(addr & RubyInteger.new(1023_i64))]
    else
      @chr_mem[addr]
    end
    @io_latch
  end

  def poke_2xxx(_addr : RubyObject, data : RubyObject)
    @io_latch = data
  end

  def peek_2xxx(_addr : RubyObject)
    @io_latch
  end

  def peek_3000(_addr : RubyObject)
    update(Ruby_RP2C02_CC)
    @io_latch
  end

  def poke_4014(_addr : RubyObject, data : RubyObject)
    if @cpu.odd_clock?.truthy?
      @cpu.steal_clocks(Ruby_CPU::Ruby_CLK_1)
    end
    update(Ruby_RP2C02_CC)
    @cpu.steal_clocks(Ruby_CPU::Ruby_CLK_1)
    data = (data << RubyInteger.new(8_i64))
    if (_and33 = (_and34 = ((@regs_oam == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _and34.truthy? ? (((data < RubyInteger.new(8192_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and34); _and33.truthy? ? (    (_or35 = ((@any_show.truthy?) ? RUBY_FALSE : RUBY_TRUE); _or35.truthy? ? _or35 : (((@cpu.current_clock <= (Ruby_RP2C02_HVINT - (Ruby_CPU::Ruby_CLK_1 * RubyInteger.new(512_i64)))) ? RUBY_TRUE : RUBY_FALSE)))) : _and33).truthy?
      @cpu.steal_clocks((Ruby_CPU::Ruby_CLK_1 * RubyInteger.new(512_i64)))
      @cpu.sprite_dma((data & RubyInteger.new(2047_i64)), @sp_ram)
      @io_latch = @sp_ram[255_i64]
    else
      while (((data & RubyInteger.new(255_i64)) != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        begin
          @io_latch = @cpu.fetch(data)
          data = (data + RubyInteger.new(1_i64))
          @cpu.steal_clocks(Ruby_CPU::Ruby_CLK_1)
          update(Ruby_RP2C02_CC)
          @cpu.steal_clocks(Ruby_CPU::Ruby_CLK_1)
          @io_latch = io_latch_mask(@io_latch)
          @sp_ram[@regs_oam] = @io_latch
          @regs_oam = (          (@regs_oam + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
        end
      end
    end
  end

  def peek_4014(_addr : RubyObject)
    RubyInteger.new(64_i64)
  end

  def open_pattern(exp : RubyObject)
    unless @any_show.truthy?
      return
    end
    @io_addr = exp
    update_address_line
  end

  def open_sprite(buffer_idx : Int64)
    flip_v = @sp_buffer[(buffer_idx + 2_i64)][7_i64]
    tmp = (    (@scanline - @sp_buffer[buffer_idx]) ^     (flip_v * RubyInteger.new(15_i64)))
    byte1 = @sp_buffer[(buffer_idx + 1_i64)]
    addr = if ((@sp_height == RubyInteger.new(16_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      ((      (      (byte1 & RubyInteger.new(1_i64)) << RubyInteger.new(12_i64)) |       (      (byte1 & RubyInteger.new(254_i64)) << RubyInteger.new(4_i64))) |       (tmp[3_i64] * RubyInteger.new(16_i64)))
    else
      (@sp_base | (byte1 << RubyInteger.new(4_i64)))
    end
    (addr |     (tmp & RubyInteger.new(7_i64)))
  end

  def open_sprite(buffer_idx : RubyObject)
    flip_v = @sp_buffer[(buffer_idx + RubyInteger.new(2_i64))][7_i64]
    tmp = (    (@scanline - @sp_buffer[buffer_idx]) ^     (flip_v * RubyInteger.new(15_i64)))
    byte1 = @sp_buffer[(buffer_idx + RubyInteger.new(1_i64))]
    addr = if ((@sp_height == RubyInteger.new(16_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      ((      (      (byte1 & RubyInteger.new(1_i64)) << RubyInteger.new(12_i64)) |       (      (byte1 & RubyInteger.new(254_i64)) << RubyInteger.new(4_i64))) |       (tmp[3_i64] * RubyInteger.new(16_i64)))
    else
      (@sp_base | (byte1 << RubyInteger.new(4_i64)))
    end
    (addr |     (tmp & RubyInteger.new(7_i64)))
  end

  def load_sprite(pat0 : RubyObject, pat1 : RubyObject, buffer_idx : Int64)
    byte2 = @sp_buffer[(buffer_idx + 2_i64)]
    pos = Ruby_SP_PIXEL_POSITIONS[byte2[6_i64]]
    pat = ((    ((pat0 >> RubyInteger.new(1_i64)) & RubyInteger.new(85_i64)) |     (pat1 & RubyInteger.new(170_i64))) | (    (    (pat0 & RubyInteger.new(85_i64)) |     ((pat1 << RubyInteger.new(1_i64)) & RubyInteger.new(170_i64))) << RubyInteger.new(8_i64)))
    x_base = @sp_buffer[(buffer_idx + 3_i64)]
    palette_base = (RubyInteger.new(16_i64) +     (    (byte2 & RubyInteger.new(3_i64)) << RubyInteger.new(2_i64)))
    (_or36 = @sp_visible; _or36.truthy? ? _or36 : (@sp_visible = @sp_map.clear))
    8_i64.times { |dx|     x = (x_base + RubyInteger.new(dx))
    clr = (    (pat >>     (pos[dx] * RubyInteger.new(2_i64))) & RubyInteger.new(3_i64))
    if (_or37 = @sp_map[x]; _or37.truthy? ? _or37 : (((clr == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      next
    end
    @sp_map[x] = sprite = @sp_map_buffer[x]
    sprite[0_i64] = ((byte2[5_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
    sprite[1_i64] = (_and38 = ((buffer_idx == 0_i64) ? RUBY_TRUE : RUBY_FALSE); _and38.truthy? ? (@sp_zero_in_line) : _and38)
    sprite[2_i64] = (palette_base + clr) }
    @sp_active = @sp_enabled
  end

  def load_sprite(pat0 : RubyObject, pat1 : RubyObject, buffer_idx : RubyObject)
    byte2 = @sp_buffer[(buffer_idx + RubyInteger.new(2_i64))]
    pos = Ruby_SP_PIXEL_POSITIONS[byte2[6_i64]]
    pat = ((    ((pat0 >> RubyInteger.new(1_i64)) & RubyInteger.new(85_i64)) |     (pat1 & RubyInteger.new(170_i64))) | (    (    (pat0 & RubyInteger.new(85_i64)) |     ((pat1 << RubyInteger.new(1_i64)) & RubyInteger.new(170_i64))) << RubyInteger.new(8_i64)))
    x_base = @sp_buffer[(buffer_idx + RubyInteger.new(3_i64))]
    palette_base = (RubyInteger.new(16_i64) +     (    (byte2 & RubyInteger.new(3_i64)) << RubyInteger.new(2_i64)))
    (_or39 = @sp_visible; _or39.truthy? ? _or39 : (@sp_visible = @sp_map.clear))
    8_i64.times { |dx|     x = (x_base + RubyInteger.new(dx))
    clr = (    (pat >>     (pos[dx] * RubyInteger.new(2_i64))) & RubyInteger.new(3_i64))
    if (_or40 = @sp_map[x]; _or40.truthy? ? _or40 : (((clr == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      next
    end
    @sp_map[x] = sprite = @sp_map_buffer[x]
    sprite[0_i64] = ((byte2[5_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
    sprite[1_i64] = (_and41 = ((buffer_idx == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _and41.truthy? ? (@sp_zero_in_line) : _and41)
    sprite[2_i64] = (palette_base + clr) }
    @sp_active = @sp_enabled
  end

  def update_address_line
    if @a12_monitor.truthy?
      a12_state = ((@io_addr[12_i64] == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)
      if (_and42 = ((@a12_state.truthy?) ? RUBY_FALSE : RUBY_TRUE); _and42.truthy? ? (a12_state) : _and42).truthy?
        @a12_monitor.a12_signaled((        (@vclk + @hclk) * Ruby_RP2C02_CC))
      end
      @a12_state = a12_state
    end
  end

  def open_name
    unless @any_show.truthy?
      return
    end
    @io_addr = @name_io_addr
    update_address_line
  end

  def fetch_name
    unless @any_show.truthy?
      return
    end
    @io_pattern = @name_lut[((@scroll_addr_0_4 + @scroll_addr_5_14) + @bg_pattern_base_15)]
  end

  def open_attr
    unless @any_show.truthy?
      return
    end
    _ma43 = masgn_coerce(@attr_lut[(@scroll_addr_0_4 + @scroll_addr_5_14)])
    @io_addr = _ma43[0_i64]
    @bg_pattern_lut_fetched = _ma43[1_i64]
    update_address_line
  end

  def fetch_attr
    unless @any_show.truthy?
      return
    end
    @bg_pattern_lut = @bg_pattern_lut_fetched
  end

  def fetch_bg_pattern_0
    unless @any_show.truthy?
      return
    end
    @bg_pattern = @chr_mem[(@io_addr & RubyInteger.new(8191_i64))]
  end

  def fetch_bg_pattern_1
    unless @any_show.truthy?
      return
    end
    @bg_pattern = (@bg_pattern | (@chr_mem[(@io_addr & RubyInteger.new(8191_i64))] * RubyInteger.new(256_i64)))
  end

  def scroll_clock_x
    unless @any_show.truthy?
      return
    end
    if ((@scroll_addr_0_4 < RubyInteger.new(31_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @scroll_addr_0_4 = (@scroll_addr_0_4 + RubyInteger.new(1_i64))
      @name_io_addr = (@name_io_addr + RubyInteger.new(1_i64))
    else
      @scroll_addr_0_4 = RubyInteger.new(0_i64)
      @scroll_addr_5_14 = (@scroll_addr_5_14 ^ RubyInteger.new(1024_i64))
      @name_io_addr = (@name_io_addr ^ RubyInteger.new(1055_i64))
    end
  end

  def scroll_reset_x
    unless @any_show.truthy?
      return
    end
    @scroll_addr_0_4 = (@scroll_latch & RubyInteger.new(31_i64))
    @scroll_addr_5_14 = (    (@scroll_addr_5_14 & RubyInteger.new(31712_i64)) |     (@scroll_latch & RubyInteger.new(1024_i64)))
    @name_io_addr = ((    (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(4095_i64)) | RubyInteger.new(8192_i64))
  end

  def scroll_clock_y
    unless @any_show.truthy?
      return
    end
    if (((@scroll_addr_5_14 & RubyInteger.new(28672_i64)) != RubyInteger.new(28672_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @scroll_addr_5_14 = (@scroll_addr_5_14 + RubyInteger.new(4096_i64))
    else
      mask = (@scroll_addr_5_14 & RubyInteger.new(992_i64))
      if ((mask == RubyInteger.new(928_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @scroll_addr_5_14 = (@scroll_addr_5_14 ^ RubyInteger.new(2048_i64))
        @scroll_addr_5_14 = (@scroll_addr_5_14 & RubyInteger.new(3072_i64))
      else
        if ((mask == RubyInteger.new(992_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
          @scroll_addr_5_14 = (@scroll_addr_5_14 & RubyInteger.new(3072_i64))
        else
          @scroll_addr_5_14 = (          (@scroll_addr_5_14 & RubyInteger.new(4064_i64)) + RubyInteger.new(32_i64))
        end
      end
    end
    @name_io_addr = ((    (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(4095_i64)) | RubyInteger.new(8192_i64))
  end

  def preload_tiles
    unless @any_show.truthy?
      return
    end
    @bg_pixels[@scroll_xfine] = RubyInteger.new(8_i64)
  end

  def load_tiles
    unless @any_show.truthy?
      return
    end
    @bg_pixels.rotate!(RubyInteger.new(8_i64))
    @bg_pixels[@scroll_xfine] = RubyInteger.new(8_i64)
  end

  def evaluate_sprites_even
    unless @any_show.truthy?
      return
    end
    @sp_latch = @sp_ram[@sp_addr]
  end

  def evaluate_sprites_odd
    unless @any_show.truthy?
      return
    end
    if @sp_phase.truthy?
      if ((@sp_phase == RubyInteger.new(9_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        evaluate_sprites_odd_phase_9
      else
        _case_subj = @sp_phase
        if (RubyInteger.new(2_i64)) == _case_subj
          evaluate_sprites_odd_phase_2
        elsif (RubyInteger.new(3_i64)) == _case_subj
          evaluate_sprites_odd_phase_3
        elsif (RubyInteger.new(4_i64)) == _case_subj
          evaluate_sprites_odd_phase_4
        elsif (RubyInteger.new(5_i64)) == _case_subj
          evaluate_sprites_odd_phase_5
        elsif (RubyInteger.new(6_i64)) == _case_subj
          evaluate_sprites_odd_phase_6
        elsif (RubyInteger.new(7_i64)) == _case_subj
          evaluate_sprites_odd_phase_7
        elsif (RubyInteger.new(8_i64)) == _case_subj
          evaluate_sprites_odd_phase_8
        end
      end
    else
      evaluate_sprites_odd_phase_1
    end
  end

  def evaluate_sprites_odd_phase_1
    @sp_index = (@sp_index + RubyInteger.new(1_i64))
    if (_and44 = ((@sp_latch <= @scanline) ? RUBY_TRUE : RUBY_FALSE); _and44.truthy? ? (((@scanline < (@sp_latch + @sp_height)) ? RUBY_TRUE : RUBY_FALSE)) : _and44).truthy?
      @sp_addr = (@sp_addr + RubyInteger.new(1_i64))
      @sp_phase = RubyInteger.new(2_i64)
      @sp_buffer[@sp_buffered] = @sp_latch
    else
      if ((@sp_index == RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @sp_addr = RubyInteger.new(0_i64)
        @sp_phase = RubyInteger.new(9_i64)
      else
        if ((@sp_index == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
          @sp_addr = RubyInteger.new(8_i64)
        else
          @sp_addr = (@sp_addr + RubyInteger.new(4_i64))
        end
      end
    end
  end

  def evaluate_sprites_odd_phase_2
    @sp_addr = (@sp_addr + RubyInteger.new(1_i64))
    @sp_phase = RubyInteger.new(3_i64)
    @sp_buffer[(@sp_buffered + RubyInteger.new(1_i64))] = @sp_latch
  end

  def evaluate_sprites_odd_phase_3
    @sp_addr = (@sp_addr + RubyInteger.new(1_i64))
    @sp_phase = RubyInteger.new(4_i64)
    @sp_buffer[(@sp_buffered + RubyInteger.new(2_i64))] = @sp_latch
  end

  def evaluate_sprites_odd_phase_4
    @sp_buffer[(@sp_buffered + RubyInteger.new(3_i64))] = @sp_latch
    @sp_buffered = (@sp_buffered + RubyInteger.new(4_i64))
    if ((@sp_index != RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @sp_phase = if ((@sp_buffered != @sp_limit) ? RUBY_TRUE : RUBY_FALSE).truthy?
        RUBY_NIL
      else
        RubyInteger.new(5_i64)
      end
      if ((@sp_index != RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @sp_addr = (@sp_addr + RubyInteger.new(1_i64))
        (_or45 = @sp_zero_in_line; _or45.truthy? ? _or45 : (@sp_zero_in_line = ((@sp_index == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)))
      else
        @sp_addr = RubyInteger.new(8_i64)
      end
    else
      @sp_addr = RubyInteger.new(0_i64)
      @sp_phase = RubyInteger.new(9_i64)
    end
  end

  def evaluate_sprites_odd_phase_5
    if (_and46 = ((@sp_latch <= @scanline) ? RUBY_TRUE : RUBY_FALSE); _and46.truthy? ? (((@scanline < (@sp_latch + @sp_height)) ? RUBY_TRUE : RUBY_FALSE)) : _and46).truthy?
      @sp_phase = RubyInteger.new(6_i64)
      @sp_addr = (      (@sp_addr + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
      @sp_overflow = RUBY_TRUE
    else
      @sp_addr = (      (      (@sp_addr + RubyInteger.new(4_i64)) & RubyInteger.new(252_i64)) +       (      (@sp_addr + RubyInteger.new(1_i64)) & RubyInteger.new(3_i64)))
      if ((@sp_addr <= RubyInteger.new(5_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @sp_phase = RubyInteger.new(9_i64)
        @sp_addr = (@sp_addr & RubyInteger.new(252_i64))
      end
    end
  end

  def evaluate_sprites_odd_phase_6
    @sp_phase = RubyInteger.new(7_i64)
    @sp_addr = (    (@sp_addr + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
  end

  def evaluate_sprites_odd_phase_7
    @sp_phase = RubyInteger.new(8_i64)
    @sp_addr = (    (@sp_addr + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
  end

  def evaluate_sprites_odd_phase_8
    @sp_phase = RubyInteger.new(9_i64)
    @sp_addr = (    (@sp_addr + RubyInteger.new(1_i64)) & RubyInteger.new(255_i64))
    if (((@sp_addr & RubyInteger.new(3_i64)) == RubyInteger.new(3_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      @sp_addr = (@sp_addr + RubyInteger.new(1_i64))
    end
    @sp_addr = (@sp_addr & RubyInteger.new(252_i64))
  end

  def evaluate_sprites_odd_phase_9
    @sp_addr = (    (@sp_addr + RubyInteger.new(4_i64)) & RubyInteger.new(255_i64))
  end

  def load_extended_sprites
    unless @any_show.truthy?
      return
    end
    if ((RubyInteger.new(32_i64) < @sp_buffered) ? RUBY_TRUE : RUBY_FALSE).truthy?
      buffer_idx = 32_i64
      while ((RubyInteger.new(buffer_idx) != @sp_buffered) ? RUBY_TRUE : RUBY_FALSE).truthy?
        begin
          addr = open_sprite(buffer_idx)
          pat0 = @chr_mem[addr]
          pat1 = @chr_mem[(addr | RubyInteger.new(8_i64))]
          if (_or47 = ((pat0 != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _or47.truthy? ? _or47 : (((pat1 != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
            load_sprite(pat0, pat1, RubyInteger.new(buffer_idx))
          end
          buffer_idx = (buffer_idx + 4_i64)
        end
      end
    end
  end

  def render_pixel
    if @any_show.truthy?
      pixel = if @bg_enabled.truthy?
        @bg_pixels[(@hclk % RubyInteger.new(8_i64))]
      else
        RubyInteger.new(0_i64)
      end.to_i64
      if (_and48 = @sp_active; _and48.truthy? ? (      sprite = @sp_map[@hclk]) : _and48).truthy?
        if ((pixel % 4_i64) == 0_i64)
          pixel = sprite[2_i64].to_i64
        else
          if (_and49 = sprite[1_i64]; _and49.truthy? ? (((@hclk != RubyInteger.new(255_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and49).truthy?
            @sp_zero_hit = RUBY_TRUE
          end
          unless sprite[0_i64].truthy?
            pixel = sprite[2_i64].to_i64
          end
        end
      end
    else
      pixel = if (((@scroll_addr_5_14 & RubyInteger.new(16128_i64)) == RubyInteger.new(16128_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @scroll_addr_0_4
      else
        RubyInteger.new(0_i64)
      end.to_i64
      @bg_pixels[(@hclk % RubyInteger.new(8_i64))] = RubyInteger.new(0_i64)
    end
    (@output_pixels << @output_color[pixel])
  end

  def batch_render_eight_pixels
RUBY_NIL
  end

  def boot
    @vblank = RUBY_TRUE
    @hclk = Ruby_HCLOCK_DUMMY
    @hclk_target = Ruby_FOREVER_CLOCK
  end

  def vblank_0
    @vblanking = RUBY_TRUE
    @hclk = Ruby_HCLOCK_VBLANK_1
  end

  def vblank_1
    (_or50 = @vblank; _or50.truthy? ? _or50 : (@vblank = @vblanking))
    @vblanking = RUBY_FALSE
    @sp_visible = RUBY_FALSE
    @sp_active = RUBY_FALSE
    @hclk = Ruby_HCLOCK_VBLANK_2
  end

  def vblank_2
    (_or51 = @vblank; _or51.truthy? ? _or51 : (@vblank = @vblanking))
    @vblanking = RUBY_FALSE
    @hclk = Ruby_HCLOCK_DUMMY
    @hclk_target = Ruby_FOREVER_CLOCK
    if (_and52 = @need_nmi; _and52.truthy? ? (@vblank) : _and52).truthy?
      @cpu.do_nmi(@cpu.next_frame_clock)
    end
  end

  def update_enabled_flags
    unless @any_show.truthy?
      return
    end
    @bg_enabled = @bg_show
    @sp_enabled = @sp_show
    @sp_active = (_and53 = @sp_enabled; _and53.truthy? ? (@sp_visible) : _and53)
  end

  def update_enabled_flags_edge
    @bg_enabled = @bg_show_edge
    @sp_enabled = @sp_show_edge
    @sp_active = (_and54 = @sp_enabled; _and54.truthy? ? (@sp_visible) : _and54)
  end

  def debug_logging(scanline : RubyObject, hclk : RubyObject, hclk_target : RubyObject)
    if ((hclk == Ruby_FOREVER_CLOCK) ? RUBY_TRUE : RUBY_FALSE).truthy?
      hclk = Ruby_Str_39
    end
    if ((hclk_target == Ruby_FOREVER_CLOCK) ? RUBY_TRUE : RUBY_FALSE).truthy?
      hclk_target = Ruby_Str_39
    end
    @conf.debug(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("ppu: scanline "); _s.concat_raw_bytes!((    scanline).to_s); _s.concat_raw_bytes!(", hclk "); _s.concat_raw_bytes!((    hclk).to_s); _s.concat_raw_bytes!("->"); _s.concat_raw_bytes!((    hclk_target).to_s) })
  end

  def run
    (_or55 = @fiber; _or55.truthy? ? _or55 : (@fiber = Ruby_Fiber.new() {     main_loop
    Ruby_Sym_18 }))
    if ((@conf.loglevel >= RubyInteger.new(3_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      debug_logging(@scanline, @hclk, @hclk_target)
    end
    make_sure_invariants
    unless @fiber.resume.truthy?
      @hclk_target = (      (@vclk + @hclk) * Ruby_RP2C02_CC)
    end
  end

  def dispose
    @run = RUBY_FALSE
    unless (_or56 = @fiber.ruby_nil?; _or56.truthy? ? _or56 : (((@fiber.resume == Ruby_Sym_18) ? RUBY_TRUE : RUBY_FALSE))).truthy?
      raise RuntimeError.new("PPU Fiber should have finished")
    end
    @fiber = RUBY_NIL
  end

  def wait_frame
    Ruby_Fiber.ruby_yield(RUBY_TRUE)
  end

  def wait_zero_clocks
    if ((@hclk_target <= @hclk) ? RUBY_TRUE : RUBY_FALSE).truthy?
      Ruby_Fiber.ruby_yield
    end
  end

  def wait_one_clock
    @hclk = (@hclk + RubyInteger.new(1_i64))
    if ((@hclk_target <= @hclk) ? RUBY_TRUE : RUBY_FALSE).truthy?
      Ruby_Fiber.ruby_yield
    end
  end

  def wait_two_clocks
    @hclk = (@hclk + RubyInteger.new(2_i64))
    if ((@hclk_target <= @hclk) ? RUBY_TRUE : RUBY_FALSE).truthy?
      Ruby_Fiber.ruby_yield
    end
  end

  def main_loop
    boot
    wait_frame
    while @run.truthy?
      RubyInteger.new(341_i64).step(RubyInteger.new(589_i64), RubyInteger.new(8_i64)) {       if ((@hclk == RubyInteger.new(341_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @sp_overflow = @sp_zero_hit = @vblanking = @vblank = RUBY_FALSE
        @scanline = Ruby_SCANLINE_HDUMMY
      end
      open_name
      wait_two_clocks
      open_attr
      wait_two_clocks
      open_pattern(@bg_pattern_base)
      wait_two_clocks
      open_pattern((@io_addr | RubyInteger.new(8_i64)))
      wait_two_clocks }
      RubyInteger.new(597_i64).step(RubyInteger.new(653_i64), RubyInteger.new(8_i64)) {       if @any_show.truthy?
        if ((@hclk == RubyInteger.new(645_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
          @scroll_addr_0_4 = (@scroll_latch & RubyInteger.new(31_i64))
          @scroll_addr_5_14 = (@scroll_latch & RubyInteger.new(32736_i64))
          @name_io_addr = ((          (@scroll_addr_0_4 | @scroll_addr_5_14) & RubyInteger.new(4095_i64)) | RubyInteger.new(8192_i64))
        end
      end
      open_name
      wait_two_clocks
      open_attr
      wait_two_clocks
      open_pattern(@pattern_end)
      wait_two_clocks
      open_pattern((@io_addr | RubyInteger.new(8_i64)))
      if ((@hclk == RubyInteger.new(659_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
        @hclk = RubyInteger.new(320_i64)
        @vclk = (@vclk + Ruby_HCLOCK_DUMMY)
        @hclk_target = (@hclk_target - Ruby_HCLOCK_DUMMY)
      else
        wait_two_clocks
      end
      wait_zero_clocks }
      while true
        load_extended_sprites
        open_name
        if @any_show.truthy?
          @sp_latch = @sp_ram[0_i64]
        end
        @sp_buffered = RubyInteger.new(0_i64)
        @sp_zero_in_line = RUBY_FALSE
        @sp_index = RubyInteger.new(0_i64)
        @sp_phase = RubyInteger.new(0_i64)
        wait_one_clock
        fetch_name
        wait_one_clock
        open_attr
        wait_one_clock
        fetch_attr
        scroll_clock_x
        wait_one_clock
        open_pattern(@io_pattern)
        wait_one_clock
        fetch_bg_pattern_0
        wait_one_clock
        open_pattern((@io_pattern | RubyInteger.new(8_i64)))
        wait_one_clock
        fetch_bg_pattern_1
        wait_one_clock
        preload_tiles
        open_name
        wait_one_clock
        fetch_name
        wait_one_clock
        open_attr
        wait_one_clock
        fetch_attr
        scroll_clock_x
        wait_one_clock
        open_pattern(@io_pattern)
        wait_one_clock
        fetch_bg_pattern_0
        wait_one_clock
        open_pattern((@io_pattern | RubyInteger.new(8_i64)))
        wait_one_clock
        fetch_bg_pattern_1
        wait_one_clock
        open_name
        wait_one_clock
        if @any_show.truthy?
          update_enabled_flags_edge
          if (_and57 = ((@scanline == Ruby_SCANLINE_HDUMMY) ? RUBY_TRUE : RUBY_FALSE); _and57.truthy? ? (@odd_frame) : _and57).truthy?
            @cpu.next_frame_clock = Ruby_RP2C02_HVSYNC_1
          end
        end
        wait_one_clock
        open_name
        @scanline = (@scanline + RubyInteger.new(1_i64))
        if ((@scanline != Ruby_SCANLINE_VBLANK) ? RUBY_TRUE : RUBY_FALSE).truthy?
          if @any_show.truthy?
            line = if (_or58 = ((@scanline != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _or58.truthy? ? _or58 : (((@odd_frame.truthy?) ? RUBY_FALSE : RUBY_TRUE))).truthy?
              RubyInteger.new(341_i64)
            else
              RubyInteger.new(340_i64)
            end.to_i64
          else
            update_enabled_flags_edge
            line = 341_i64
          end
          @hclk = RubyInteger.new(0_i64)
          @vclk = (@vclk + RubyInteger.new(line))
          @hclk_target = if ((@hclk_target <= RubyInteger.new(line)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            RubyInteger.new(0_i64)
          else
            (@hclk_target - RubyInteger.new(line))
          end
        else
          @hclk = Ruby_HCLOCK_VBLANK_0
          wait_zero_clocks
          break
        end
        wait_zero_clocks
        RubyInteger.new(0_i64).step(RubyInteger.new(248_i64), RubyInteger.new(8_i64)) {         if @any_show.truthy?
          if ((@hclk == RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            @sp_addr = (@regs_oam & RubyInteger.new(248_i64))
            @sp_phase = RUBY_NIL
            @sp_latch = RubyInteger.new(255_i64)
          end
          load_tiles
          batch_render_eight_pixels
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_even
          end
          open_name
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          fetch_name
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_odd
          end
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_even
          end
          open_attr
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          fetch_attr
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_odd
          end
          if ((@hclk == RubyInteger.new(251_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            scroll_clock_y
          end
          scroll_clock_x
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_even
          end
          open_pattern(@io_pattern)
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          fetch_bg_pattern_0
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_odd
          end
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_even
          end
          open_pattern((@io_pattern | RubyInteger.new(8_i64)))
        end
        render_pixel
        wait_one_clock
        if @any_show.truthy?
          fetch_bg_pattern_1
          if ((@hclk >= RubyInteger.new(64_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            evaluate_sprites_odd
          end
        end
        render_pixel
        if @any_show.truthy?
          if ((@hclk != RubyInteger.new(255_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            update_enabled_flags
          end
        end
        wait_one_clock }
        RubyInteger.new(256_i64).step(RubyInteger.new(312_i64), RubyInteger.new(8_i64)) {         if ((@hclk == RubyInteger.new(256_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
          open_name
          if @any_show.truthy?
            @sp_latch = RubyInteger.new(255_i64)
          end
          wait_one_clock
          scroll_reset_x
          @sp_visible = RUBY_FALSE
          @sp_active = RUBY_FALSE
          wait_one_clock
        else
          open_name
          wait_two_clocks
        end
        open_attr
        wait_two_clocks
        if @any_show.truthy?
          buffer_idx = (          (@hclk - RubyInteger.new(260_i64)) / RubyInteger.new(2_i64))
          open_pattern(if ((buffer_idx >= @sp_buffered) ? RUBY_TRUE : RUBY_FALSE).truthy?
            @pattern_end
          else
            open_sprite(buffer_idx)
          end)
          if ((@hclk == RubyInteger.new(316_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
            if ((@scanline == RubyInteger.new(238_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
              @regs_oam = RubyInteger.new(0_i64)
            end
          end
        end
        wait_one_clock
        if @any_show.truthy?
          if (((          (@hclk - RubyInteger.new(261_i64)) / RubyInteger.new(2_i64)) < @sp_buffered) ? RUBY_TRUE : RUBY_FALSE).truthy?
            @io_pattern = @chr_mem[(@io_addr & RubyInteger.new(8191_i64))]
          end
        end
        wait_one_clock
        open_pattern((@io_addr | RubyInteger.new(8_i64)))
        wait_one_clock
        if @any_show.truthy?
          buffer_idx = (          (@hclk - RubyInteger.new(263_i64)) / RubyInteger.new(2_i64))
          if ((buffer_idx < @sp_buffered) ? RUBY_TRUE : RUBY_FALSE).truthy?
            pat0 = @io_pattern
            pat1 = @chr_mem[(@io_addr & RubyInteger.new(8191_i64))]
            if (_or59 = ((pat0 != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _or59.truthy? ? _or59 : (((pat1 != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE))).truthy?
              load_sprite(pat0, pat1, buffer_idx)
            end
          end
        end
        wait_one_clock }
      end
      vblank_0
      wait_zero_clocks
      vblank_1
      wait_zero_clocks
      vblank_2
      wait_frame
    end
  end

      RESPOND_TO_TABLE = StaticArray[false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
class Ruby_OptimizedCodeBuilder < RubyObject
    def to_s : String; "#<OptimizedCodeBuilder>"; end
    def inspect : String; "#<OptimizedCodeBuilder>"; end
  Ruby_OPTIONS = RubyArray.new([RubySymbol.new(:method_inlining), RubySymbol.new(:ivar_localization), RubySymbol.new(:split_show_mode), RubySymbol.new(:split_a12_checks), RubySymbol.new(:clock_specialization), RubySymbol.new(:fastpath), RubySymbol.new(:batch_render_pixels), RubySymbol.new(:oneline)] of RubyObject)

  def build
    depends(Ruby_Sym_19, Ruby_Sym_20)
    depends(Ruby_Sym_21, Ruby_Sym_22)
    mdefs = parse_method_definitions(Ruby_Str_44)
    handlers = parse_clock_handlers(mdefs[Ruby_Sym_23].body)
    if @clock_specialization.truthy?
      handlers = specialize_clock_handlers(handlers)
    end
    if @fastpath.truthy?
      handlers = add_fastpath(handlers) { |fastpath, hclk|       if @batch_render_pixels.truthy?
        batch_render_pixels(fastpath, hclk)
      else
        fastpath
      end }
    end
    code = build_loop(handlers)
    if @method_inlining.truthy?
      code = ppu_expand_methods(code, mdefs)
    end
    if @split_show_mode.truthy?
      _ma60 = masgn_coerce(split_mode(code, Ruby_Str_45))
      code = _ma60[0_i64]
      code_no_show = _ma60[1_i64]
      if @split_a12_checks.truthy?
        _ma61 = masgn_coerce(split_mode(code, Ruby_Str_46))
        code = _ma61[0_i64]
        code_no_a12 = _ma61[1_i64]
        code = branch(Ruby_Str_46, code, code_no_a12)
      end
      code = branch(Ruby_Str_45, code, code_no_show)
    end
    code = gen(mdefs[Ruby_Sym_24].body, code, Ruby_Str_47)
    if @ivar_localization.truthy?
      code = localize_instance_variables(code)
    end
    code = gen(Ruby_Str_48, # UNSUPPORTED_SPLAT(    if ((@loglevel >= RubyInteger.new(3_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyArray.new([Ruby_Str_49] of RubyObject)
    else
      RubyArray.new([] of RubyObject)
    end), indent(RubyInteger.new(2_i64), code), Ruby_Str_13)
    if @oneline.truthy?
      code = oneline(code)
    end
    code
  end

  def parse_clock_handlers(main_loop : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteral    handlers = RubyHash.new
    main_loop.scan(RUBY_NIL # UNSUPPORTED: RegexpLiteral) { |indent, hclks, body|     body = indent((indent.size.-), body)
    body = body.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral, Ruby_Str_10)
    body = expand_methods(body, Ruby_COMMANDS)
    if ((hclks =~ ["RUBY_NIL # UNSUPPORTED: RegexpLiteral"]) ? RUBY_TRUE : RUBY_FALSE).truthy?
      _ma62 = masgn_coerce(RubyTuple3.new((RUBY_GLOBALS["1"]? || RUBY_NIL).to_i, (RUBY_GLOBALS["2"]? || RUBY_NIL).to_i, (RUBY_GLOBALS["3"]? || RUBY_NIL).to_i))
      first = _ma62[0_i64]
      second = _ma62[1_i64]
      last = _ma62[2_i64]
      first.step(last, (second - first)) { |hclk|       handlers[hclk] = body }
    else
      handlers[hclks.to_i64] = body
    end }
    handlers
  end

  def specialize_clock_handlers(handlers : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteral    handlers.each() { |hclk, handler|     handler = handler.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral) {     hclk.send((RUBY_GLOBALS["1"]? || RUBY_NIL).to_sym, (RUBY_GLOBALS["2"]? || RUBY_NIL).to_i) }
    handlers[hclk] = remove_trivial_branches(handler) }
  end

  def add_fastpath(handlers : RubyObject)
    handlers.each() { |hclk, handler|     unless (_and63 = (((hclk % RubyInteger.new(8_i64)) == RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE); _and63.truthy? ? (((hclk < RubyInteger.new(256_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and63).truthy?
      next
    end
    fastpath = gen(# UNSUPPORTED_SPLAT(    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |i|     handlers[(hclk + i)] }))
    fastpath = yield (fastpath), (hclk)
    handlers[hclk] = branch(Ruby_Str_50, fastpath, handler) }
  end

  def batch_render_pixels(fastpath : RubyObject, hclk : RubyObject)
RUBY_NIL # UNSUPPORTED: SplatArg    fastpath = expand_methods(fastpath, render_pixel: gen(Ruby_Str_51, Ruby_Str_52, Ruby_Str_53, Ruby_Str_13))
    expand_methods(fastpath, batch_render_eight_pixels: gen(Ruby_Str_54, Ruby_Str_55, Ruby_Str_56, Ruby_Str_57, # UNSUPPORTED_SPLAT(    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).flat_map() { |i|     RubyArray.new([RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("      pixel"); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!(" = @bg_pixels["); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!("]") }, RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("      if sprite = @sp_map[@hclk"); _s.concat_raw_bytes!((    if ((i != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!(" + "); _s.concat_raw_bytes!((      i).to_s) }
    else
      Ruby_Str_10
    end).to_s); _s.concat_raw_bytes!("]") }, RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("        if pixel"); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!(" % 4 == 0") }, RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("          pixel"); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!(" = sprite[2]") }, Ruby_Str_67, RUBY_NIL # UNSUPPORTED: SplatArg, RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("          pixel"); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!(" = sprite[2] unless sprite[0]") }, Ruby_Str_70, Ruby_Str_71] of RubyObject) }), (Ruby_Str_72 + (    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |n|     RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@output_color[pixel"); _s.concat_raw_bytes!((    n).to_s); _s.concat_raw_bytes!("]") } } * Ruby_Str_74)), Ruby_Str_75, # UNSUPPORTED_SPLAT(    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |i|     RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("      pixel"); _s.concat_raw_bytes!((    i).to_s); _s.concat_raw_bytes!(" = (sprite = @sp_map[@hclk "); _s.concat_raw_bytes!((    if ((i != RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE).truthy?
      RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!(" + "); _s.concat_raw_bytes!((      i).to_s) }
    else
      Ruby_Str_10
    end).to_s); _s.concat_raw_bytes!("]) ? sprite[2] : 0") } }), (Ruby_Str_72 + (    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |n|     RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@output_color[pixel"); _s.concat_raw_bytes!((    n).to_s); _s.concat_raw_bytes!("]") } } * Ruby_Str_74)), Ruby_Str_78, Ruby_Str_79, Ruby_Str_80, (Ruby_Str_72 + (    RubyRange.new(RubyInteger.new(0_i64), RubyInteger.new(7_i64), false).map() { |n|     RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@output_color[@bg_pixels["); _s.concat_raw_bytes!((    n).to_s); _s.concat_raw_bytes!("]]") } } * Ruby_Str_74)), Ruby_Str_75, Ruby_Str_83, (Ruby_Str_72 + ((RubyTuple1.new(Ruby_Str_84) * RubyInteger.new(8_i64)) * Ruby_Str_74)), Ruby_Str_78, Ruby_Str_85, Ruby_Str_13))
  end

  def oneline(code : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteralRUBY_NIL # UNSUPPORTED: RegexpLiteral    code.gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral, Ruby_Str_10).gsub(Ruby_Str_86, Ruby_Str_87).gsub(RUBY_NIL # UNSUPPORTED: RegexpLiteral, Ruby_Str_60).tr(Ruby_Str_6, Ruby_Str_88)
  end

  def ppu_expand_methods(code : RubyObject, mdefs : RubyObject)
    code = expand_inline_methods(code, Ruby_Sym_27, mdefs[Ruby_Sym_27])
    expand_methods(expand_methods(code, mdefs), mdefs)
  end

  def split_mode(code : RubyObject, cond : RubyObject)
    RubyTuple2.new(Ruby_Str_28, Ruby_Str_89).map() { |bool|     rebuild_loop(remove_trivial_branches(replace_cond_var(code, cond, bool))) }
  end

  def build_loop(handlers : RubyHash)
    clauses = RubyHash.new
    handlers.sort.each() { |hclk, handler|     (    (_iorw_r64 = clauses; _iorw_i64 = handler; _iorw_c64 = _iorw_r64[_iorw_i64]; _iorw_c64.truthy? ? _iorw_c64 : (_iorw_r64[_iorw_i64] = RubyArray.new([] of RubyObject))) << hclk) }
    gen(Ruby_Str_90, Ruby_Str_91, # UNSUPPORTED_SPLAT(clauses.invert.sort.map() { |hclks, handler|     (RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("  when "); _s.concat_raw_bytes!((    (hclks * Ruby_Str_17)).to_s); _s.concat_raw_bytes!("\n") } + indent(RubyInteger.new(4_i64), handler)) }), Ruby_Str_85, Ruby_Str_13)
  end

  def build_loop(handlers : RubyObject)
    clauses = RubyHash.new
    handlers.sort.each() { |hclk, handler|     (    (_iorw_r65 = clauses; _iorw_i65 = handler; _iorw_c65 = _iorw_r65[_iorw_i65]; _iorw_c65.truthy? ? _iorw_c65 : (_iorw_r65[_iorw_i65] = RubyArray.new([] of RubyObject))) << hclk) }
    gen(Ruby_Str_90, Ruby_Str_91, # UNSUPPORTED_SPLAT(clauses.invert.sort.map() { |hclks, handler|     (RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("  when "); _s.concat_raw_bytes!((    (hclks * Ruby_Str_17)).to_s); _s.concat_raw_bytes!("\n") } + indent(RubyInteger.new(4_i64), handler)) }), Ruby_Str_85, Ruby_Str_13)
  end

  def rebuild_loop(code : RubyObject)
RUBY_NIL # UNSUPPORTED: RegexpLiteral    handlers = RubyHash.new
    code.scan(RUBY_NIL # UNSUPPORTED: RegexpLiteral) { |hclks, handler|     hclks.split(Ruby_Str_17).each() { |hclk|     handlers[hclk.to_i64] = indent(RubyInteger.new(-4_i64), handler) } }
    build_loop(handlers)
  end

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
STDOUT.puts(RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("loaded ppu, TILE_LUT[0].size = "); _s.concat_raw_bytes!((Ruby_Optcarrot::Ruby_PPU::Ruby_TILE_LUT[0_i64].size).to_s) }.to_s); RUBY_NIL

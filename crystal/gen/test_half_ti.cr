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

Ruby_Sym_0 = RubySymbol.from("i64")
Ruby_Sym_1 = RubySymbol.from("bottom")
Ruby_Sym_2 = RubySymbol.from("f64")
Ruby_Sym_3 = RubySymbol.from("array_scalar")
Ruby_Sym_4 = RubySymbol.from("class_type")
Ruby_Sym_5 = RubySymbol.from("Integer")
Ruby_Sym_6 = RubySymbol.from("Float")
Ruby_Sym_7 = RubySymbol.from("Numeric")
Ruby_Sym_8 = RubySymbol.from("Array")
Ruby_Sym_9 = RubySymbol.from("Hash")
Ruby_Sym_10 = RubySymbol.from("NilClass")
Ruby_Sym_11 = RubySymbol.from("unknown")
Ruby_Sym_12 = RubySymbol.from("array_i64")
Ruby_Sym_13 = RubySymbol.from("array_f64")
Ruby_Sym_14 = RubySymbol.from("class")
Ruby_Sym_15 = RubySymbol.from("nullable")
Ruby_Sym_16 = RubySymbol.from("exact")
Ruby_Sym_17 = RubySymbol.from("elem")
Ruby_Sym_18 = RubySymbol.from("key")
Ruby_Sym_19 = RubySymbol.from("val")
Ruby_Sym_20 = RubySymbol.from("Object")
Ruby_Sym_21 = RubySymbol.from("class_name")
Ruby_Sym_22 = RubySymbol.from("needs_join")
Ruby_Sym_23 = RubySymbol.from("const")
Ruby_Sym_24 = RubySymbol.from("kwparam")
Ruby_Sym_25 = RubySymbol.from("new")
Ruby_Sym_26 = RubySymbol.from("param")
Ruby_Sym_27 = RubySymbol.from("__execute__")
Ruby_Sym_28 = RubySymbol.from("constructor_param")
Ruby_Sym_29 = RubySymbol.from("return")
Ruby_Sym_30 = RubySymbol.from("local")
Ruby_Sym_31 = RubySymbol.from("array_elem")
Ruby_Sym_32 = RubySymbol.from("raw?")
Ruby_Sym_33 = RubySymbol.from("sub")
Ruby_Sym_34 = RubySymbol.from("<<")
Ruby_Sym_35 = RubySymbol.from("push")
Ruby_Sym_36 = RubySymbol.from("[]")
Ruby_Sym_37 = RubySymbol.from("depth")
Ruby_Sym_38 = RubySymbol.from("[]=")
Ruby_Sym_39 = RubySymbol.from("block_param")
Ruby_Sym_40 = RubySymbol.from("Range")
Ruby_Sym_41 = RubySymbol.from("initialize")
Ruby_Sym_42 = RubySymbol.from("ivar")
Ruby_Sym_43 = RubySymbol.from("raw")
Ruby_Sym_44 = RubySymbol.from("map")
Ruby_Sym_45 = RubySymbol.from("Math")
Ruby_Sym_46 = RubySymbol.from("to_a")
Ruby_Sym_47 = RubySymbol.from("to_ary")
Ruby_Sym_48 = RubySymbol.from("String")
Ruby_Sym_49 = RubySymbol.from("getbyte")
Ruby_Sym_50 = RubySymbol.from("ord")
Ruby_Sym_51 = RubySymbol.from("bytesize")
Ruby_Sym_52 = RubySymbol.from("Random")
Ruby_Sym_53 = RubySymbol.from("rand")
Ruby_Sym_54 = RubySymbol.from("max")
Ruby_Sym_55 = RubySymbol.from("min")
Ruby_Sym_56 = RubySymbol.from("sum")
Ruby_Sym_57 = RubySymbol.from("first")
Ruby_Sym_58 = RubySymbol.from("last")
Ruby_Sym_59 = RubySymbol.from("dup")
Ruby_Sym_60 = RubySymbol.from("clone")
Ruby_Sym_61 = RubySymbol.from("freeze")
Ruby_Sym_62 = RubySymbol.from("+")
Ruby_Sym_63 = RubySymbol.from("-")
Ruby_Sym_64 = RubySymbol.from("*")
Ruby_Sym_65 = RubySymbol.from("%")
Ruby_Sym_66 = RubySymbol.from("&")
Ruby_Sym_67 = RubySymbol.from("|")
Ruby_Sym_68 = RubySymbol.from("^")
Ruby_Sym_69 = RubySymbol.from(">>")
Ruby_Sym_70 = RubySymbol.from("times")
Ruby_Sym_71 = RubySymbol.from("upto")
Ruby_Sym_72 = RubySymbol.from("downto")
Ruby_Sym_73 = RubySymbol.from("each")
Ruby_Sym_74 = RubySymbol.from("flat_map")
Ruby_Sym_75 = RubySymbol.from("select")
Ruby_Sym_76 = RubySymbol.from("reject")
Ruby_Sym_77 = RubySymbol.from("filter")
Ruby_Sym_78 = RubySymbol.from("each_with_object")
Ruby_Sym_79 = RubySymbol.from("min_by")
Ruby_Sym_80 = RubySymbol.from("max_by")
Ruby_Sym_81 = RubySymbol.from("sort_by")
Ruby_Sym_82 = RubySymbol.from("any?")
Ruby_Sym_83 = RubySymbol.from("all?")
Ruby_Sym_84 = RubySymbol.from("none?")
Ruby_Sym_85 = RubySymbol.from("find")
Ruby_Sym_86 = RubySymbol.from("detect")
Ruby_Sym_87 = RubySymbol.from("count")
Ruby_Sym_88 = RubySymbol.from("reduce")
Ruby_Sym_89 = RubySymbol.from("inject")
Ruby_Sym_90 = RubySymbol.from("each_with_index")
Ruby_Sym_91 = RubySymbol.from("body")
Ruby_Sym_92 = RubySymbol.from("block_node")
Ruby_Sym_93 = RubySymbol.from("stop")
Ruby_Sym_94 = RubySymbol.from("superclass")
Ruby_Sym_95 = RubySymbol.from("BasicObject")
Ruby_Sym_96 = RubySymbol.from("nil_type?")
Ruby_Sym_97 = RubySymbol.from("class_object")
Ruby_Sym_98 = RubySymbol.from("to_legacy")
Ruby_Str_0 = RubyString.new("UInt8").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("UInt16").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("UInt32").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("UInt64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Int8").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Int16").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Int32").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Int64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Type::BOTTOM").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("Type::I64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Type::F64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("Type::").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("ARRAY_I64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("ARRAY_F64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Type.of(:").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("nullable: true").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("exact: true").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("elem: ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("key: ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("val: ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new(", ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new(")").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("Type(").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Float64").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Array(").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("RubyObject").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Ruby_").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("=").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("#<TypeEnv ").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new(" typed slots>").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_91 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_92 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_93 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_94 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_95 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_96 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_97 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_98 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_99 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_100 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_101 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_102 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_103 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_104 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_105 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_106 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_107 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_108 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_109 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_110 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_111 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_112 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_113 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_114 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_115 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_116 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_117 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }

# User-defined method stubs on RubyObject for polymorphic dispatch
class RubyObject
  def kind(*args) : RubyObject
    raise Exception.new("undefined method 'kind' for #{self.class}")
  end
  def class_name(*args) : RubyObject
    raise Exception.new("undefined method 'class_name' for #{self.class}")
  end
  def elem(*args) : RubyObject
    raise Exception.new("undefined method 'elem' for #{self.class}")
  end
  def key(*args) : RubyObject
    raise Exception.new("undefined method 'key' for #{self.class}")
  end
  def val(*args) : RubyObject
    raise Exception.new("undefined method 'val' for #{self.class}")
  end
  def int_min(*args) : RubyObject
    raise Exception.new("undefined method 'int_min' for #{self.class}")
  end
  def int_max(*args) : RubyObject
    raise Exception.new("undefined method 'int_max' for #{self.class}")
  end
  def int_bounds(*args) : RubyObject
    raise Exception.new("undefined method 'int_bounds' for #{self.class}")
  end
  def narrowest_int_type(*args) : RubyObject
    raise Exception.new("undefined method 'narrowest_int_type' for #{self.class}")
  end
  def bottom?(*args) : RubyObject
    raise Exception.new("undefined method 'bottom?' for #{self.class}")
  end
  def i64?(*args) : RubyObject
    raise Exception.new("undefined method 'i64?' for #{self.class}")
  end
  def f64?(*args) : RubyObject
    raise Exception.new("undefined method 'f64?' for #{self.class}")
  end
  def raw?(*args) : RubyObject
    raise Exception.new("undefined method 'raw?' for #{self.class}")
  end
  def array_scalar?(*args) : RubyObject
    raise Exception.new("undefined method 'array_scalar?' for #{self.class}")
  end
  def class_type?(*args) : RubyObject
    raise Exception.new("undefined method 'class_type?' for #{self.class}")
  end
  def nullable?(*args) : RubyObject
    raise Exception.new("undefined method 'nullable?' for #{self.class}")
  end
  def exact?(*args) : RubyObject
    raise Exception.new("undefined method 'exact?' for #{self.class}")
  end
  def numeric?(*args) : RubyObject
    raise Exception.new("undefined method 'numeric?' for #{self.class}")
  end
  def array?(*args) : RubyObject
    raise Exception.new("undefined method 'array?' for #{self.class}")
  end
  def array_like?(*args) : RubyObject
    raise Exception.new("undefined method 'array_like?' for #{self.class}")
  end
  def hash_type?(*args) : RubyObject
    raise Exception.new("undefined method 'hash_type?' for #{self.class}")
  end
  def nil_type?(*args) : RubyObject
    raise Exception.new("undefined method 'nil_type?' for #{self.class}")
  end
  def eql?(*args) : RubyObject
    raise Exception.new("undefined method 'eql?' for #{self.class}")
  end
  def to_crystal(*args) : RubyObject
    raise Exception.new("undefined method 'to_crystal' for #{self.class}")
  end
  def to_crystal_storage(*args) : RubyObject
    raise Exception.new("undefined method 'to_crystal_storage' for #{self.class}")
  end
  def native?(*args) : RubyObject
    raise Exception.new("undefined method 'native?' for #{self.class}")
  end
  def generic_compatible?(*args) : RubyObject
    raise Exception.new("undefined method 'generic_compatible?' for #{self.class}")
  end
  def class_to_crystal(*args) : RubyObject
    raise Exception.new("undefined method 'class_to_crystal' for #{self.class}")
  end
  def to_legacy(*args) : RubyObject
    raise Exception.new("undefined method 'to_legacy' for #{self.class}")
  end
  def boxed_class_name(*args) : RubyObject
    raise Exception.new("undefined method 'boxed_class_name' for #{self.class}")
  end
  def to_class_type(*args) : RubyObject
    raise Exception.new("undefined method 'to_class_type' for #{self.class}")
  end
  def merge_params(*args) : RubyObject
    raise Exception.new("undefined method 'merge_params' for #{self.class}")
  end
  def merge_param(*args) : RubyObject
    raise Exception.new("undefined method 'merge_param' for #{self.class}")
  end
  def env(*args) : RubyObject
    raise Exception.new("undefined method 'env' for #{self.class}")
  end
  def join(*args) : RubyObject
    raise Exception.new("undefined method 'join' for #{self.class}")
  end
  def run(*args) : RubyObject
    raise Exception.new("undefined method 'run' for #{self.class}")
  end
  def seed_constants(*args) : RubyObject
    raise Exception.new("undefined method 'seed_constants' for #{self.class}")
  end
  def update_call_sites(*args) : RubyObject
    raise Exception.new("undefined method 'update_call_sites' for #{self.class}")
  end
  def seed_call_block_params(*args) : RubyObject
    raise Exception.new("undefined method 'seed_call_block_params' for #{self.class}")
  end
  def propagate_kw_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_kw_args' for #{self.class}")
  end
  def propagate_positional_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_positional_args' for #{self.class}")
  end
  def propagate_free_call_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_free_call_args' for #{self.class}")
  end
  def propagate_constructor_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_constructor_args' for #{self.class}")
  end
  def propagate_class_method_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_class_method_args' for #{self.class}")
  end
  def propagate_instance_method_args(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_instance_method_args' for #{self.class}")
  end
  def propagate_execute_block(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_execute_block' for #{self.class}")
  end
  def propagate_method(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_method' for #{self.class}")
  end
  def propagate_locals(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_locals' for #{self.class}")
  end
  def strip_int_bounds(*args) : RubyObject
    raise Exception.new("undefined method 'strip_int_bounds' for #{self.class}")
  end
  def propagate_masgn_from_calls(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_masgn_from_calls' for #{self.class}")
  end
  def last_expression(*args) : RubyObject
    raise Exception.new("undefined method 'last_expression' for #{self.class}")
  end
  def propagate_array_locals(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_array_locals' for #{self.class}")
  end
  def collect_array_elem_writes(*args) : RubyObject
    raise Exception.new("undefined method 'collect_array_elem_writes' for #{self.class}")
  end
  def propagate_for_targets(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_for_targets' for #{self.class}")
  end
  def for_loop_elem_type(*args) : RubyObject
    raise Exception.new("undefined method 'for_loop_elem_type' for #{self.class}")
  end
  def propagate_ivars(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_ivars' for #{self.class}")
  end
  def seed_constructor_params(*args) : RubyObject
    raise Exception.new("undefined method 'seed_constructor_params' for #{self.class}")
  end
  def propagate_ivars_from_initialize(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_ivars_from_initialize' for #{self.class}")
  end
  def propagate_ivars_from_other_methods(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_ivars_from_other_methods' for #{self.class}")
  end
  def propagate_ivars_from_setter_calls(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_ivars_from_setter_calls' for #{self.class}")
  end
  def propagate_ivar_array_elem_writes(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_ivar_array_elem_writes' for #{self.class}")
  end
  def each_user_method(*args) : RubyObject
    raise Exception.new("undefined method 'each_user_method' for #{self.class}")
  end
  def collect_ivar_array_elem_writes(*args) : RubyObject
    raise Exception.new("undefined method 'collect_ivar_array_elem_writes' for #{self.class}")
  end
  def collect_setter_calls(*args) : RubyObject
    raise Exception.new("undefined method 'collect_setter_calls' for #{self.class}")
  end
  def infer_expr(*args) : RubyObject
    raise Exception.new("undefined method 'infer_expr' for #{self.class}")
  end
  def infer_expr_uncached(*args) : RubyObject
    raise Exception.new("undefined method 'infer_expr_uncached' for #{self.class}")
  end
  def infer_array_literal_type(*args) : RubyObject
    raise Exception.new("undefined method 'infer_array_literal_type' for #{self.class}")
  end
  def infer_hash_literal_type(*args) : RubyObject
    raise Exception.new("undefined method 'infer_hash_literal_type' for #{self.class}")
  end
  def infer_local_var_type(*args) : RubyObject
    raise Exception.new("undefined method 'infer_local_var_type' for #{self.class}")
  end
  def infer_if_type(*args) : RubyObject
    raise Exception.new("undefined method 'infer_if_type' for #{self.class}")
  end
  def infer_short_circuit_type(*args) : RubyObject
    raise Exception.new("undefined method 'infer_short_circuit_type' for #{self.class}")
  end
  def infer_call(*args) : RubyObject
    raise Exception.new("undefined method 'infer_call' for #{self.class}")
  end
  def try_infer_array_factory(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_array_factory' for #{self.class}")
  end
  def try_infer_map_factory(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_map_factory' for #{self.class}")
  end
  def seed_iteration_block_params(*args) : RubyObject
    raise Exception.new("undefined method 'seed_iteration_block_params' for #{self.class}")
  end
  def try_infer_class_new(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_class_new' for #{self.class}")
  end
  def try_infer_math_call(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_math_call' for #{self.class}")
  end
  def try_infer_subscript_read(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_subscript_read' for #{self.class}")
  end
  def try_infer_range_to_a(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_range_to_a' for #{self.class}")
  end
  def try_infer_builtin_method(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_builtin_method' for #{self.class}")
  end
  def try_infer_arith_op(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_arith_op' for #{self.class}")
  end
  def propagate_int_bounds(*args) : RubyObject
    raise Exception.new("undefined method 'propagate_int_bounds' for #{self.class}")
  end
  def try_infer_max_min_two_arg(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_max_min_two_arg' for #{self.class}")
  end
  def try_infer_class_method_call(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_class_method_call' for #{self.class}")
  end
  def try_infer_instance_method_call(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_instance_method_call' for #{self.class}")
  end
  def try_infer_free_call(*args) : RubyObject
    raise Exception.new("undefined method 'try_infer_free_call' for #{self.class}")
  end
  def infer_block_return(*args) : RubyObject
    raise Exception.new("undefined method 'infer_block_return' for #{self.class}")
  end
  def seed_block_params(*args) : RubyObject
    raise Exception.new("undefined method 'seed_block_params' for #{self.class}")
  end
  def block_param_types(*args) : RubyObject
    raise Exception.new("undefined method 'block_param_types' for #{self.class}")
  end
  def infer_body_return(*args) : RubyObject
    raise Exception.new("undefined method 'infer_body_return' for #{self.class}")
  end
  def scan_returns(*args) : RubyObject
    raise Exception.new("undefined method 'scan_returns' for #{self.class}")
  end
  def collect_assignments(*args) : RubyObject
    raise Exception.new("undefined method 'collect_assignments' for #{self.class}")
  end
  def collect_ivar_assignments(*args) : RubyObject
    raise Exception.new("undefined method 'collect_ivar_assignments' for #{self.class}")
  end
  def escapes?(*args) : RubyObject
    raise Exception.new("undefined method 'escapes?' for #{self.class}")
  end
  def escapes_only_via_return_array?(*args) : RubyObject
    raise Exception.new("undefined method 'escapes_only_via_return_array?' for #{self.class}")
  end
  def writes_consistent?(*args) : RubyObject
    raise Exception.new("undefined method 'writes_consistent?' for #{self.class}")
  end
  def walk(*args) : RubyObject
    raise Exception.new("undefined method 'walk' for #{self.class}")
  end
  def build_class_ancestors(*args) : RubyObject
    raise Exception.new("undefined method 'build_class_ancestors' for #{self.class}")
  end
  def compute_user_ancestors(*args) : RubyObject
    raise Exception.new("undefined method 'compute_user_ancestors' for #{self.class}")
  end
  def ancestors_of(*args) : RubyObject
    raise Exception.new("undefined method 'ancestors_of' for #{self.class}")
  end
  def lca_type(*args) : RubyObject
    raise Exception.new("undefined method 'lca_type' for #{self.class}")
  end
  def resolve_param_joins(*args) : RubyObject
    raise Exception.new("undefined method 'resolve_param_joins' for #{self.class}")
  end
  def needs_param_resolution?(*args) : RubyObject
    raise Exception.new("undefined method 'needs_param_resolution?' for #{self.class}")
  end
  def best_constructor_param_types(*args) : RubyObject
    raise Exception.new("undefined method 'best_constructor_param_types' for #{self.class}")
  end
  def vm_object_type(*args) : RubyObject
    raise Exception.new("undefined method 'vm_object_type' for #{self.class}")
  end
  def array_new_call?(*args) : RubyObject
    raise Exception.new("undefined method 'array_new_call?' for #{self.class}")
  end
  def each_user_instance_method(*args) : RubyObject
    raise Exception.new("undefined method 'each_user_instance_method' for #{self.class}")
  end
  def param_index(*args) : RubyObject
    raise Exception.new("undefined method 'param_index' for #{self.class}")
  end
  def param_names_for(*args) : RubyObject
    raise Exception.new("undefined method 'param_names_for' for #{self.class}")
  end
  def method_for_key(*args) : RubyObject
    raise Exception.new("undefined method 'method_for_key' for #{self.class}")
  end
  def raw(*args) : RubyObject
    raise Exception.new("undefined method 'raw' for #{self.class}")
  end
  def typed?(*args) : RubyObject
    raise Exception.new("undefined method 'typed?' for #{self.class}")
  end
  def slots(*args) : RubyObject
    raise Exception.new("undefined method 'slots' for #{self.class}")
  end
  def type_of(*args) : RubyObject
    raise Exception.new("undefined method 'type_of' for #{self.class}")
  end
  def type_at(*args) : RubyObject
    raise Exception.new("undefined method 'type_at' for #{self.class}")
  end
  def each_typed(*args) : RubyObject
    raise Exception.new("undefined method 'each_typed' for #{self.class}")
  end
  def join!(*args) : RubyObject
    raise Exception.new("undefined method 'join!' for #{self.class}")
  end
end

module Ruby_Frozone
  module Ruby_Compiler
        def to_s : String; "#<Compiler>"; end
        def inspect : String; "#<Compiler>"; end

    class Ruby_Type < RubyObject
            @class_name : RubyObject = RUBY_NIL
            @elem : RubyObject = RUBY_NIL
            @exact : RubyObject = RUBY_NIL
            @int_max : RubyObject = RUBY_NIL
            @int_min : RubyObject = RUBY_NIL
            @key : RubyObject = RUBY_NIL
            @kind : RubyObject = RUBY_NIL
            @nullable : RubyObject = RUBY_NIL
            @val : RubyObject = RUBY_NIL

                  Ruby_CRYSTAL_CLASS_NAMES = RubyHash.new.tap { |h| h[RubySymbol.from("Object")] = RubyString.new("RubyGenericObject"); h[RubySymbol.from("Integer")] = RubyString.new("RubyInteger"); h[RubySymbol.from("Float")] = RubyString.new("RubyFloat"); h[RubySymbol.from("String")] = RubyString.new("RubyString"); h[RubySymbol.from("Symbol")] = RubyString.new("RubySymbol"); h[RubySymbol.from("Array")] = RubyString.new("RubyArray"); h[RubySymbol.from("Hash")] = RubyString.new("RubyHash"); h[RubySymbol.from("NilClass")] = RubyString.new("RubyNil"); h[RubySymbol.from("Numeric")] = Ruby_Str_25; h[RubySymbol.from("Struct")] = Ruby_Str_25; h[RubySymbol.from("Math")] = RubyString.new("RubyMath"); h[RubySymbol.from("Random")] = RubyString.new("Ruby_Random"); h[RubySymbol.from("Proc")] = RubyString.new("RubyProc") }

            def kind : RubyObject; @kind; end
            def class_name : RubyObject; @class_name; end
            def elem : RubyObject; @elem; end
            def key : RubyObject; @key; end
            def val : RubyObject; @val; end
            def int_min : RubyObject; @int_min; end
            def int_max : RubyObject; @int_max; end
      def initialize(kind : RubyObject, *, class_name : RubyObject = (RUBY_NIL), nullable : RubyObject = (RUBY_FALSE), exact : RubyObject = (RUBY_FALSE), elem : RubyObject = (RUBY_NIL), key : RubyObject = (RUBY_NIL), val : RubyObject = (RUBY_NIL), int_min : RubyObject = (RUBY_NIL), int_max : RubyObject = (RUBY_NIL))
        @kind = kind
        @class_name = class_name
        @nullable = nullable
        @exact = exact
        @elem = elem
        @key = key
        @val = val
        @int_min = int_min
        @int_max = int_max
        freeze
      end

      def int_bounds
        unless ((_and0 = (_and1 = ((@kind == Ruby_Sym_0) ? RUBY_TRUE : RUBY_FALSE); _and1.truthy? ? (@int_min) : _and1); _and0.truthy? ? (@int_max) : _and0)).truthy?
          return RUBY_NIL
        end
        RubyTuple2.new(@int_min, @int_max)
      end

      def narrowest_int_type
        unless (        b = int_bounds).truthy?
          return RUBY_NIL
        end
        _ma2 = masgn_coerce(b)
        min = _ma2[0_i64]
        max = _ma2[1_i64]
        if (((min >= RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          if (((max <= RubyInteger.new(255_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            return Ruby_Str_0
          end
          if (((max <= RubyInteger.new(65535_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            return Ruby_Str_1
          end
          if (((max <= RubyInteger.new(4294967295_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            return Ruby_Str_2
          end
          return Ruby_Str_3
        end
        if ((_and3 = ((min >= RubyInteger.new(-128_i64)) ? RUBY_TRUE : RUBY_FALSE); _and3.truthy? ? (((max <= RubyInteger.new(127_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and3)).truthy?
          return Ruby_Str_4
        end
        if ((_and4 = ((min >= RubyInteger.new(-32768_i64)) ? RUBY_TRUE : RUBY_FALSE); _and4.truthy? ? (((max <= RubyInteger.new(32767_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and4)).truthy?
          return Ruby_Str_5
        end
        if ((_and5 = ((min >= RubyInteger.new(-2147483648_i64)) ? RUBY_TRUE : RUBY_FALSE); _and5.truthy? ? (((max <= RubyInteger.new(2147483647_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and5)).truthy?
          return Ruby_Str_6
        end
        Ruby_Str_7
      end

      def bottom?
        ((@kind == Ruby_Sym_1) ? RUBY_TRUE : RUBY_FALSE)
      end

      def i64?
        ((@kind == Ruby_Sym_0) ? RUBY_TRUE : RUBY_FALSE)
      end

      def f64?
        ((@kind == Ruby_Sym_2) ? RUBY_TRUE : RUBY_FALSE)
      end

      def raw?
        (_or6 = ((@kind == Ruby_Sym_0) ? RUBY_TRUE : RUBY_FALSE); _or6.truthy? ? _or6 : (((@kind == Ruby_Sym_2) ? RUBY_TRUE : RUBY_FALSE)))
      end

      def array_scalar?
        ((@kind == Ruby_Sym_3) ? RUBY_TRUE : RUBY_FALSE)
      end

      def class_type?
        ((@kind == Ruby_Sym_4) ? RUBY_TRUE : RUBY_FALSE)
      end

      def nullable?
        @nullable
      end

      def exact?
        @exact
      end

      def numeric?
        (_or7 = raw?; _or7.truthy? ? _or7 : (        (_and8 = class_type?; _and8.truthy? ? (RubyTuple3.new(Ruby_Sym_5, Ruby_Sym_6, Ruby_Sym_7).include?(@class_name)) : _and8)))
      end

      def array?
        (_and9 = class_type?; _and9.truthy? ? (((@class_name == Ruby_Sym_8) ? RUBY_TRUE : RUBY_FALSE)) : _and9)
      end

      def array_like?
        (_or10 = array_scalar?; _or10.truthy? ? _or10 : (array?))
      end

      def hash_type?
        (_and11 = class_type?; _and11.truthy? ? (((@class_name == Ruby_Sym_9) ? RUBY_TRUE : RUBY_FALSE)) : _and11)
      end

      def nil_type?
        (_and12 = class_type?; _and12.truthy? ? (((@class_name == Ruby_Sym_10) ? RUBY_TRUE : RUBY_FALSE)) : _and12)
      end

      def ==(other : RubyObject) : Bool
((begin
          unless (other.is_a?(Ruby_Type) ? RUBY_TRUE : RUBY_FALSE)
            return RUBY_FALSE.truthy?
          end
          (_and13 = (_and14 = (_and15 = (_and16 = (_and17 = (_and18 = (_and19 = (_and20 = ((@kind == other.kind) ? RUBY_TRUE : RUBY_FALSE); _and20.truthy? ? (((@class_name == other.class_name) ? RUBY_TRUE : RUBY_FALSE)) : _and20); _and19.truthy? ? (((@nullable == other.nullable?) ? RUBY_TRUE : RUBY_FALSE)) : _and19); _and18.truthy? ? (((@exact == other.exact?) ? RUBY_TRUE : RUBY_FALSE)) : _and18); _and17.truthy? ? (((@elem == other.elem) ? RUBY_TRUE : RUBY_FALSE)) : _and17); _and16.truthy? ? (((@key == other.key) ? RUBY_TRUE : RUBY_FALSE)) : _and16); _and15.truthy? ? (((@val == other.val) ? RUBY_TRUE : RUBY_FALSE)) : _and15); _and14.truthy? ? (((@int_min == other.int_min) ? RUBY_TRUE : RUBY_FALSE)) : _and14); _and13.truthy? ? (((@int_max == other.int_max) ? RUBY_TRUE : RUBY_FALSE)) : _and13)
        end) || RUBY_NIL).truthy?
      end

      def eql?(other : RubyObject)
        unless (other.is_a?(Ruby_Type) ? RUBY_TRUE : RUBY_FALSE)
          return RUBY_FALSE
        end
        (_and21 = (_and22 = (_and23 = (_and24 = (_and25 = (_and26 = (_and27 = (_and28 = ((@kind == other.kind) ? RUBY_TRUE : RUBY_FALSE); _and28.truthy? ? (((@class_name == other.class_name) ? RUBY_TRUE : RUBY_FALSE)) : _and28); _and27.truthy? ? (((@nullable == other.nullable?) ? RUBY_TRUE : RUBY_FALSE)) : _and27); _and26.truthy? ? (((@exact == other.exact?) ? RUBY_TRUE : RUBY_FALSE)) : _and26); _and25.truthy? ? (((@elem == other.elem) ? RUBY_TRUE : RUBY_FALSE)) : _and25); _and24.truthy? ? (((@key == other.key) ? RUBY_TRUE : RUBY_FALSE)) : _and24); _and23.truthy? ? (((@val == other.val) ? RUBY_TRUE : RUBY_FALSE)) : _and23); _and22.truthy? ? (((@int_min == other.int_min) ? RUBY_TRUE : RUBY_FALSE)) : _and22); _and21.truthy? ? (((@int_max == other.int_max) ? RUBY_TRUE : RUBY_FALSE)) : _and21)
      end

      def hash
        RubyArray.new([@kind, @class_name, @nullable, @exact, @elem, @key, @val, @int_min, @int_max] of RubyObject).hash
      end

      def inspect : String
(begin
          _case_subj = @kind
          if (Ruby_Sym_1) == _case_subj
            Ruby_Str_8
          elsif (Ruby_Sym_0) == _case_subj
            Ruby_Str_9
          elsif (Ruby_Sym_2) == _case_subj
            Ruby_Str_10
          elsif (Ruby_Sym_3) == _case_subj
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type::"); _s.concat_raw_bytes!((            if (@elem.i64?).truthy?
              Ruby_Str_12
            else
              Ruby_Str_13
            end).to_s) }
          elsif (Ruby_Sym_4) == _case_subj
            parts = RubyArray.new([RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type.of(:"); _s.concat_raw_bytes!((            @class_name).to_s) }] of RubyObject)
            if (@nullable).truthy?
              (parts << Ruby_Str_15)
            end
            if (@exact).truthy?
              (parts << Ruby_Str_16)
            end
            if (@elem).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("elem: "); _s.concat_raw_bytes!((              @elem.ruby_inspect).to_s) })
            end
            if (@key).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("key: "); _s.concat_raw_bytes!((              @key.ruby_inspect).to_s) })
            end
            if (@val).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("val: "); _s.concat_raw_bytes!((              @val.ruby_inspect).to_s) })
            end
            (parts.join(Ruby_Str_20) + Ruby_Str_21)
          else
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type("); _s.concat_raw_bytes!((            @kind).to_s); _s.concat_raw_bytes!(")") }
          end
        end).to_s
      end

      def to_s : String
(begin
          _case_subj = @kind
          if (Ruby_Sym_1) == _case_subj
            Ruby_Str_8
          elsif (Ruby_Sym_0) == _case_subj
            Ruby_Str_9
          elsif (Ruby_Sym_2) == _case_subj
            Ruby_Str_10
          elsif (Ruby_Sym_3) == _case_subj
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type::"); _s.concat_raw_bytes!((            if (@elem.i64?).truthy?
              Ruby_Str_12
            else
              Ruby_Str_13
            end).to_s) }
          elsif (Ruby_Sym_4) == _case_subj
            parts = RubyArray.new([RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type.of(:"); _s.concat_raw_bytes!((            @class_name).to_s) }] of RubyObject)
            if (@nullable).truthy?
              (parts << Ruby_Str_15)
            end
            if (@exact).truthy?
              (parts << Ruby_Str_16)
            end
            if (@elem).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("elem: "); _s.concat_raw_bytes!((              @elem.ruby_inspect).to_s) })
            end
            if (@key).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("key: "); _s.concat_raw_bytes!((              @key.ruby_inspect).to_s) })
            end
            if (@val).truthy?
              (parts << RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("val: "); _s.concat_raw_bytes!((              @val.ruby_inspect).to_s) })
            end
            (parts.join(Ruby_Str_20) + Ruby_Str_21)
          else
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Type("); _s.concat_raw_bytes!((            @kind).to_s); _s.concat_raw_bytes!(")") }
          end
        end).to_s
      end

      def to_crystal
        _case_subj = @kind
        if (Ruby_Sym_0) == _case_subj
          Ruby_Str_7
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_Str_23
        elsif (Ruby_Sym_3) == _case_subj
          RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Array("); _s.concat_raw_bytes!((          @elem.to_crystal_storage).to_s); _s.concat_raw_bytes!(")") }
        elsif (Ruby_Sym_4) == _case_subj
          class_to_crystal
        else
          Ruby_Str_25
        end
      end

      def to_crystal_storage
        _case_subj = @kind
        if (Ruby_Sym_0) == _case_subj
          (_or29 = narrowest_int_type; _or29.truthy? ? _or29 : (Ruby_Str_7))
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_Str_23
        elsif (Ruby_Sym_3) == _case_subj
          RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Array("); _s.concat_raw_bytes!((          @elem.to_crystal_storage).to_s); _s.concat_raw_bytes!(")") }
        elsif (Ruby_Sym_4) == _case_subj
          if ((_and30 = array?; _and30.truthy? ? (@elem.native?) : _and30)).truthy?
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Array("); _s.concat_raw_bytes!((            @elem.to_crystal_storage).to_s); _s.concat_raw_bytes!(")") }
          else
            class_to_crystal
          end
        else
          Ruby_Str_25
        end
      end

      def native?
        (_or31 = (_or32 = raw?; _or32.truthy? ? _or32 : (array_scalar?)); _or31.truthy? ? _or31 : (        (_and33 = array?; _and33.truthy? ? (@elem.native?) : _and33)))
      end

      def generic_compatible?
        (((native?).truthy?) ? RUBY_FALSE : RUBY_TRUE)
      end

      def class_to_crystal
        if ((_and34 = array?; _and34.truthy? ? (@elem.native?) : _and34)).truthy?
          return RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Array("); _s.concat_raw_bytes!((          @elem.to_crystal_storage).to_s); _s.concat_raw_bytes!(")") }
        end
        (_or35 = Ruby_CRYSTAL_CLASS_NAMES[@class_name]; _or35.truthy? ? _or35 : (RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("Ruby_"); _s.concat_raw_bytes!((        @class_name).to_s) }))
      end

      def to_legacy
        _case_subj = @kind
        if (Ruby_Sym_1) == _case_subj
          Ruby_Sym_11
        elsif (Ruby_Sym_0) == _case_subj
          Ruby_Sym_0
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_Sym_2
        elsif (Ruby_Sym_3) == _case_subj
          if (@elem.i64?).truthy?
            Ruby_Sym_12
          else
            Ruby_Sym_13
          end
        elsif (Ruby_Sym_4) == _case_subj
          h = RubyHash.new.tap { |_h| _h.store(Ruby_Sym_14, @class_name) }
          if (@nullable).truthy?
            h[Ruby_Sym_15] = RUBY_TRUE
          end
          if (@exact).truthy?
            h[Ruby_Sym_16] = RUBY_TRUE
          end
          if (@elem).truthy?
            h[Ruby_Sym_17] = @elem.to_legacy
          end
          if (@key).truthy?
            h[Ruby_Sym_18] = @key.to_legacy
          end
          if (@val).truthy?
            h[Ruby_Sym_19] = @val.to_legacy
          end
          h.freeze
        end
      end

      def boxed_class_name
        _case_subj = @kind
        if (Ruby_Sym_0) == _case_subj
          Ruby_Sym_5
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_Sym_6
        elsif (Ruby_Sym_3) == _case_subj
          Ruby_Sym_8
        elsif (Ruby_Sym_4) == _case_subj
          @class_name
        else
          Ruby_Sym_20
        end
      end

      def to_class_type
        _case_subj = @kind
        if (Ruby_Sym_0) == _case_subj
          Ruby_INTEGER
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_FLOAT
        elsif (Ruby_Sym_3) == _case_subj
          if (@elem.i64?).truthy?
            Ruby_Type.array(elem: Ruby_I64)
          else
            Ruby_Type.array(elem: Ruby_F64)
          end
        elsif (Ruby_Sym_4) == _case_subj
          self
        else
          Ruby_OBJECT
        end
      end

      def merge_params(other : RubyObject)
        new_nullable = (_or36 = @nullable; _or36.truthy? ? _or36 : (other.nullable?))
        new_elem = merge_param(@elem, other.elem)
        new_key = merge_param(@key, other.key)
        new_val = merge_param(@val, other.val)
        if ((_and37 = (_and38 = (_and39 = ((new_nullable == @nullable) ? RUBY_TRUE : RUBY_FALSE); _and39.truthy? ? (new_elem.equal?(@elem)) : _and39); _and38.truthy? ? (new_key.equal?(@key)) : _and38); _and37.truthy? ? (new_val.equal?(@val)) : _and37)).truthy?
          self
        else
          if ((_and40 = (_and41 = (_and42 = ((new_nullable == other.nullable?) ? RUBY_TRUE : RUBY_FALSE); _and42.truthy? ? (new_elem.equal?(other.elem)) : _and42); _and41.truthy? ? (new_key.equal?(other.key)) : _and41); _and40.truthy? ? (new_val.equal?(other.val)) : _and40)).truthy?
            other
          else
            Ruby_Type.new(Ruby_Sym_4, class_name: @class_name, nullable: new_nullable, exact: (_and43 = @exact; _and43.truthy? ? (other.exact?) : _and43), elem: new_elem, key: new_key, val: new_val)
          end
        end
      end

      def merge_param(a : RubyObject, b : RubyObject)
        if ((_and44 = a; _and44.truthy? ? (b) : _and44)).truthy?
          Ruby_Sym_22
        else
          if (a).truthy?
            a
          else
            if (b).truthy?
              b
            end
          end
        end
      end

      def self.ruby_of(class_name : RubyObject, *, nullable : RubyObject = (RUBY_FALSE), exact : RubyObject = (RUBY_FALSE))
        if ((_and45 = (((nullable).truthy?) ? RUBY_FALSE : RUBY_TRUE); _and45.truthy? ? ((((exact).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and45)).truthy?
          _case_subj = class_name
          if (Ruby_Sym_10) == _case_subj
            return Ruby_NIL_CLASS
          elsif (Ruby_Sym_99) == _case_subj
            return Ruby_TRUE_CLASS
          elsif (Ruby_Sym_100) == _case_subj
            return Ruby_FALSE_CLASS
          elsif (Ruby_Sym_48) == _case_subj
            return Ruby_STRING
          elsif (Ruby_Sym_101) == _case_subj
            return Ruby_SYMBOL
          elsif (Ruby_Sym_5) == _case_subj
            return Ruby_INTEGER
          elsif (Ruby_Sym_6) == _case_subj
            return Ruby_FLOAT
          elsif (Ruby_Sym_7) == _case_subj
            return Ruby_NUMERIC
          elsif (Ruby_Sym_8) == _case_subj
            return Ruby_ARRAY
          elsif (Ruby_Sym_9) == _case_subj
            return Ruby_HASH
          elsif (Ruby_Sym_20) == _case_subj
            return Ruby_OBJECT
          elsif (Ruby_Sym_95) == _case_subj
            return Ruby_BASIC_OBJECT
          elsif (Ruby_Sym_40) == _case_subj
            return Ruby_RANGE
          elsif (Ruby_Sym_102) == _case_subj
            return Ruby_REGEXP
          elsif (Ruby_Sym_52) == _case_subj
            return Ruby_RANDOM
          elsif (Ruby_Sym_103) == _case_subj
            return Ruby_PROC
          end
        end
        new(Ruby_Sym_4, class_name: class_name, nullable: nullable, exact: exact)
      end

      def self.array(*, elem : RubyObject)
        new(Ruby_Sym_4, class_name: Ruby_Sym_8, elem: elem)
      end

      def self.i64_bounded(min : RubyObject, max : RubyObject)
        if ((_or46 = min.ruby_nil?; _or46.truthy? ? _or46 : (max.ruby_nil?))).truthy?
          return Ruby_I64
        end
        new(Ruby_Sym_0, int_min: min, int_max: max)
      end

      def self.hash_type(*, key : RubyObject = (RUBY_NIL), val : RubyObject = (RUBY_NIL))
        h = new(Ruby_Sym_4, class_name: Ruby_Sym_9, key: key, val: val)
        if (        (_and47 = key.ruby_nil?; _and47.truthy? ? (val.ruby_nil?) : _and47)).truthy?
          Ruby_HASH
        else
          h
        end
      end

      def self.nullable(loc_type : RubyObject)
        if (loc_type.nullable?).truthy?
          return loc_type
        end
        if (loc_type.nil_type?).truthy?
          return loc_type
        end
        _case_subj = loc_type.kind
        if (Ruby_Sym_1) == _case_subj
          Ruby_NIL_CLASS
        elsif (Ruby_Sym_0) == _case_subj
          self.ruby_of(Ruby_Sym_5, nullable: RUBY_TRUE)
        elsif (Ruby_Sym_2) == _case_subj
          self.ruby_of(Ruby_Sym_6, nullable: RUBY_TRUE)
        elsif (Ruby_Sym_4) == _case_subj
          new(Ruby_Sym_4, class_name: loc_type.class_name, nullable: RUBY_TRUE, exact: loc_type.exact?, elem: loc_type.elem, key: loc_type.key, val: loc_type.val)
        else
          loc_type
        end
      end

      def self.from_ti(ty : RubyObject, *, user_class_names : RubyObject = (Ruby_Set.new))
        if ((_or48 = ty.ruby_nil?; _or48.truthy? ? _or48 : (ty.bottom?))).truthy?
          return Ruby_BOTTOM
        end
        if ((_or49 = ty.raw?; _or49.truthy? ? _or49 : (ty.array_scalar?))).truthy?
          return ty
        end
        unless (ty.class_type?).truthy?
          return Ruby_BOTTOM
        end
        _case_subj = ty.class_name
        if (Ruby_Sym_8) == _case_subj
          if (ty.elem).truthy?
            mapped_elem = self.from_ti(ty.elem, user_class_names: user_class_names)
            if (mapped_elem.native?).truthy?
              Ruby_Type.array(elem: mapped_elem)
            else
              Ruby_BOTTOM
            end
          else
            Ruby_BOTTOM
          end
        elsif (Ruby_Sym_9) == _case_subj || (Ruby_Sym_103) == _case_subj
          self.ruby_of(ty.class_name)
        elsif (Ruby_Sym_48) == _case_subj || (Ruby_Sym_101) == _case_subj || (Ruby_Sym_5) == _case_subj || (Ruby_Sym_6) == _case_subj || (Ruby_Sym_10) == _case_subj || (Ruby_Sym_99) == _case_subj || (Ruby_Sym_100) == _case_subj || (Ruby_Sym_20) == _case_subj || (Ruby_Sym_7) == _case_subj || (Ruby_Sym_95) == _case_subj || (Ruby_Sym_104) == _case_subj || (Ruby_Sym_105) == _case_subj
          Ruby_BOTTOM
        else
          cls = ty.class_name
          if ((_or50 = user_class_names.include?(cls); _or50.truthy? ? _or50 : (Ruby_CRYSTAL_CLASS_NAMES.key?(cls)))).truthy?
            self.ruby_of(cls)
          else
            Ruby_BOTTOM
          end
        end
      end

      def self.from_legacy(v : RubyObject)
        _case_subj = v
        if _case_subj.is_a?(Ruby_Type)
          v
        elsif (Ruby_Sym_11) == _case_subj
          Ruby_BOTTOM
        elsif (Ruby_Sym_0) == _case_subj
          Ruby_I64
        elsif (Ruby_Sym_2) == _case_subj
          Ruby_F64
        elsif (Ruby_Sym_12) == _case_subj
          Ruby_ARRAY_I64
        elsif (Ruby_Sym_13) == _case_subj
          Ruby_ARRAY_F64
        elsif (RubyHash) == _case_subj
          cls = v[Ruby_Sym_14]
          nullable = (_or51 = v[Ruby_Sym_15]; _or51.truthy? ? _or51 : (RUBY_FALSE))
          exact = (_or52 = v[Ruby_Sym_16]; _or52.truthy? ? _or52 : (RUBY_FALSE))
          elem = if (v.key?(Ruby_Sym_17)).truthy?
            self.from_legacy(v[Ruby_Sym_17])
          else
            RUBY_NIL
          end
          key = if (v.key?(Ruby_Sym_18)).truthy?
            self.from_legacy(v[Ruby_Sym_18])
          else
            RUBY_NIL
          end
          val = if (v.key?(Ruby_Sym_19)).truthy?
            self.from_legacy(v[Ruby_Sym_19])
          else
            RUBY_NIL
          end
          if ((_or53 = (_or54 = elem; _or54.truthy? ? _or54 : (key)); _or53.truthy? ? _or53 : (val))).truthy?
            new(Ruby_Sym_4, class_name: cls, nullable: nullable, exact: exact, elem: elem, key: key, val: val)
          else
            self.ruby_of(cls, nullable: nullable, exact: exact)
          end
        elsif _case_subj.ruby_nil?
          Ruby_BOTTOM
        else
          Ruby_BOTTOM
        end
      end

              RESPOND_TO_TABLE = StaticArray[false]

            def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
        sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
        idx = sym.method_index
        (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
            end

    end
    class Ruby_TypeInference < RubyObject
            @ancestors_cache : RubyHash = RubyHash.new
            @constants : RubyObject = RUBY_NIL
            @env : Ruby_TypeEnv | RubyNil = RUBY_NIL
            @execute_block : RubyObject = RUBY_NIL
            @user_classes : RubyObject = RUBY_NIL
            @user_methods : RubyObject = RUBY_NIL
            @_assign_cache : RubyHash = RubyHash.new
            @_elem_write_cache : RubyHash = RubyHash.new
            @ivar_param_seeds : RubyObject = RUBY_NIL

            def to_s : String; "#<TypeInference>"; end
            def inspect : String; "#<TypeInference>"; end
      Ruby_ARITH_OPS = Ruby_Set.new
      Ruby_BUILTIN_ANCESTORS = RubyHash.new.tap { |h| h[RubySymbol.from("BasicObject")] = RubyArray.new([] of RubyObject); h[RubySymbol.from("Object")] = RubyArray.new([RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Numeric")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Integer")] = RubyArray.new([RubySymbol.from("Numeric"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Float")] = RubyArray.new([RubySymbol.from("Numeric"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Complex")] = RubyArray.new([RubySymbol.from("Numeric"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Rational")] = RubyArray.new([RubySymbol.from("Numeric"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("String")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Symbol")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Array")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Hash")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("NilClass")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("TrueClass")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("FalseClass")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Module")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Class")] = RubyArray.new([RubySymbol.from("Module"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Proc")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Range")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Regexp")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Encoding")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("IO")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("File")] = RubyArray.new([RubySymbol.from("IO"), RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Comparable")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Enumerable")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Set")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Struct")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject); h[RubySymbol.from("Random")] = RubyArray.new([RubySymbol.from("Object"), RubySymbol.from("BasicObject")] of RubyObject) }
      Ruby_MATH_FLOAT_METHODS = Ruby_Set.new
      Ruby_ARRAY_INT_METHODS = Ruby_Set.new
      Ruby_INT_INT_METHODS = Ruby_Set.new
      Ruby_FLOAT_FLOAT_METHODS = Ruby_Set.new
      Ruby_FLOAT_INT_METHODS = Ruby_Set.new
      Ruby_COERCE_TO_FLOAT = Ruby_Set.new
      Ruby_COERCE_TO_INT = Ruby_Set.new

      def initialize(*, user_methods : RubyObject, user_classes : RubyObject, execute_block : RubyObject, constants : RubyObject = (RubyHash.new))
        @user_methods = user_methods
        @user_classes = user_classes
        @execute_block = execute_block
        @constants = constants
        @env = Ruby_TypeEnv.new(self)
        @ancestors_cache = RubyHash.new
        build_class_ancestors
      end

            def env : Ruby_TypeEnv; @env; end
      def join(a : RubyObject, b : RubyObject)
        if (a.bottom?).truthy?
          return b
        end
        if (b.bottom?).truthy?
          return a
        end
        if (((a == b) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return a
        end
        if ((_and55 = a.i64?; _and55.truthy? ? (b.i64?) : _and55)).truthy?
          _ma56 = masgn_coerce(RubyTuple2.new(a.int_bounds, b.int_bounds))
          ab = _ma56[0_i64]
          bb = _ma56[1_i64]
          unless ((_and57 = ab; _and57.truthy? ? (bb) : _and57)).truthy?
            return Ruby_Type::Ruby_I64
          end
          return Ruby_Type.i64_bounded(RubyTuple2.new(ab[0_i64], bb[0_i64]).min, RubyTuple2.new(ab[1_i64], bb[1_i64]).max)
        end
        if ((_or58 = (((a.class_type?).truthy?) ? RUBY_FALSE : RUBY_TRUE); _or58.truthy? ? _or58 : ((((b.class_type?).truthy?) ? RUBY_FALSE : RUBY_TRUE)))).truthy?
          return join(a.to_class_type, b.to_class_type)
        end
        if (((a.class_name == b.class_name) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          merged = a.merge_params(b)
          resolve_param_joins(a, b, merged)
        else
          if (a.nil_type?).truthy?
            Ruby_Type.nullable(b)
          else
            if (b.nil_type?).truthy?
              Ruby_Type.nullable(a)
            else
              lca_type(a.class_name, b.class_name)
            end
          end
        end
      end

      def run(*, iterations : RubyObject = (RubyInteger.new(10_i64)))
        seed_constants
        @_assign_cache = RubyHash.new
        @_elem_write_cache = RubyHash.new
        iterations.times() do 
          changed = RUBY_FALSE
          @_expr_cache = RubyHash.new
          changed = (changed | update_call_sites(@execute_block.body, Ruby_TOP_LEVEL_CTX))
          @user_methods.each() { |mkey, method|             changed = (changed | update_call_sites(method.body, Ruby_TypeContext.new(mkey, RUBY_NIL))) }
          @user_classes.each() { |cname, klass|             each_user_instance_method(cname, klass) { |mkey, method|               changed = (changed | update_call_sites(method.body, Ruby_TypeContext.new(mkey, cname))) } }
          @_expr_cache = RubyHash.new
          changed = (changed | propagate_execute_block)
          @user_methods.each() { |mkey, method|             changed = (changed | propagate_method(mkey, method, Ruby_TypeContext.new(mkey, RUBY_NIL))) }
          @_expr_cache = RubyHash.new
          @user_classes.each() do |cname, klass| 
            changed = (changed | propagate_ivars(cname, klass))
            each_user_instance_method(cname, klass) { |mkey, method|               changed = (changed | propagate_method(mkey, method, Ruby_TypeContext.new(mkey, cname))) }
          end
          unless (changed).truthy?
            break
          end
        end
        @env
      end

      def seed_constants
        @constants.each() do |name, value| 
          ty = vm_object_type(value)
          if (ty).truthy?
            @env.join!(RubyTuple2.new(Ruby_Sym_23, name), ty)
          end
        end
      end

      def update_call_sites(node : RubyObject, ctx : Ruby_TypeContext)
        unless (node).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        walk(node) do |n| 
          unless n.ruby_is_a?(Ruby_Ast::Ruby_MethodCall)
            next
          end
          changed = (changed | seed_call_block_params(n, ctx))
          if           (_or59 = n.arg_nodes; _or59.truthy? ? _or59 : (RubyArray.new([] of RubyObject))).empty?
            next
          end
          changed = (changed | propagate_kw_args(n, ctx))
          changed = (changed | propagate_positional_args(n, ctx))
        end
        changed
      end

      def update_call_sites(node : RubyObject, ctx : RubyObject)
        unless (node).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        walk(node) do |n| 
          unless n.ruby_is_a?(Ruby_Ast::Ruby_MethodCall)
            next
          end
          changed = (changed | seed_call_block_params(n, ctx))
          if           (_or60 = n.arg_nodes; _or60.truthy? ? _or60 : (RubyArray.new([] of RubyObject))).empty?
            next
          end
          changed = (changed | propagate_kw_args(n, ctx))
          changed = (changed | propagate_positional_args(n, ctx))
        end
        changed
      end

      def seed_call_block_params(call : RubyObject, ctx : Ruby_TypeContext)
        blk = call.block_node
        unless (blk).truthy?
          return RUBY_FALSE
        end
        ptypes = block_param_types(call.name, call.receiver_node, ctx)
        unless ptypes.empty?
          seed_block_params(blk, ptypes, ctx)
        end
        RUBY_FALSE
      end

      def seed_call_block_params(call : RubyObject, ctx : RubyObject)
        blk = call.block_node
        unless (blk).truthy?
          return RUBY_FALSE
        end
        ptypes = block_param_types(call.name, call.receiver_node, ctx)
        unless ptypes.empty?
          seed_block_params(blk, ptypes, ctx)
        end
        RUBY_FALSE
      end

      def propagate_kw_args(call : RubyObject, ctx : Ruby_TypeContext)
        kw_args = (_or61 = call.kw_arg_nodes; _or61.truthy? ? _or61 : (RubyHash.new))
        if kw_args.empty?
          return RUBY_FALSE
        end
        recv = call.receiver_node
        mkey = if recv.ruby_nil?
          call.name
        else
          if recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead)
            RubyArray.new([recv.name, call.name] of RubyObject)
          end
        end
        unless (mkey).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        kw_args.each() do |kw_name_node, val_node| 
          kw_sym = if kw_name_node.ruby_is_a?(Ruby_Ast::Ruby_SymbolLiteral)
            kw_name_node.value
          else
            RUBY_NIL
          end
          unless (kw_sym).truthy?
            next
          end
          ty = infer_expr(val_node, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_24, mkey, kw_sym] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_kw_args(call : RubyObject, ctx : RubyObject)
        kw_args = (_or62 = call.kw_arg_nodes; _or62.truthy? ? _or62 : (RubyHash.new))
        if kw_args.empty?
          return RUBY_FALSE
        end
        recv = call.receiver_node
        mkey = if recv.ruby_nil?
          call.name
        else
          if recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead)
            RubyArray.new([recv.name, call.name] of RubyObject)
          end
        end
        unless (mkey).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        kw_args.each() do |kw_name_node, val_node| 
          kw_sym = if kw_name_node.ruby_is_a?(Ruby_Ast::Ruby_SymbolLiteral)
            kw_name_node.value
          else
            RUBY_NIL
          end
          unless (kw_sym).truthy?
            next
          end
          ty = infer_expr(val_node, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_24, mkey, kw_sym] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_positional_args(call : RubyObject, ctx : Ruby_TypeContext)
        recv = call.receiver_node
        if recv.ruby_nil?
          propagate_free_call_args(call, ctx)
        else
          if ((_and63 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and63.truthy? ? (((call.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)) : _and63)).truthy?
            propagate_constructor_args(call, ctx, recv.name)
          else
            if ((_and64 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and64.truthy? ? (@user_classes.key?(recv.name)) : _and64)).truthy?
              propagate_class_method_args(call, ctx, RubyTuple2.new(recv.name, call.name))
            else
              if (recv).truthy?
                propagate_instance_method_args(call, ctx)
              else
                RUBY_FALSE
              end
            end
          end
        end
      end

      def propagate_positional_args(call : RubyObject, ctx : RubyObject)
        recv = call.receiver_node
        if recv.ruby_nil?
          propagate_free_call_args(call, ctx)
        else
          if ((_and65 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and65.truthy? ? (((call.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)) : _and65)).truthy?
            propagate_constructor_args(call, ctx, recv.name)
          else
            if ((_and66 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and66.truthy? ? (@user_classes.key?(recv.name)) : _and66)).truthy?
              propagate_class_method_args(call, ctx, RubyTuple2.new(recv.name, call.name))
            else
              if (recv).truthy?
                propagate_instance_method_args(call, ctx)
              else
                RUBY_FALSE
              end
            end
          end
        end
      end

      def propagate_free_call_args(call : RubyObject, ctx : Ruby_TypeContext)
        changed = RUBY_FALSE
                (_or67 = call.arg_nodes; _or67.truthy? ? _or67 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          if (ty.bottom?).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, call.name, i] of RubyObject), ty))
          if (ctx.as(Ruby_TypeContext).class_name).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, RubyArray.new([ctx.as(Ruby_TypeContext).class_name, call.name] of RubyObject), i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_free_call_args(call : RubyObject, ctx : RubyObject)
        changed = RUBY_FALSE
                (_or68 = call.arg_nodes; _or68.truthy? ? _or68 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          if (ty.bottom?).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, call.name, i] of RubyObject), ty))
          if (ctx.class_name).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, RubyArray.new([ctx.class_name, call.name] of RubyObject), i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_constructor_args(call : RubyObject, ctx : Ruby_TypeContext, class_sym : RubyObject)
        ctor_ctx = (_or69 = ctx.as(Ruby_TypeContext).method_key; _or69.truthy? ? _or69 : (Ruby_Sym_27))
        changed = RUBY_FALSE
                (_or70 = call.arg_nodes; _or70.truthy? ? _or70 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_28, class_sym, i, ctor_ctx] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_constructor_args(call : RubyObject, ctx : RubyObject, class_sym : RubyObject)
        ctor_ctx = (_or71 = ctx.method_key; _or71.truthy? ? _or71 : (Ruby_Sym_27))
        changed = RUBY_FALSE
                (_or72 = call.arg_nodes; _or72.truthy? ? _or72 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_28, class_sym, i, ctor_ctx] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_class_method_args(call : RubyObject, ctx : Ruby_TypeContext, mkey : RubyObject)
        changed = RUBY_FALSE
                (_or73 = call.arg_nodes; _or73.truthy? ? _or73 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, mkey, i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_class_method_args(call : RubyObject, ctx : RubyObject, mkey : RubyObject)
        changed = RUBY_FALSE
                (_or74 = call.arg_nodes; _or74.truthy? ? _or74 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, mkey, i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_instance_method_args(call : RubyObject, ctx : Ruby_TypeContext)
        recv_ty = infer_expr(call.receiver_node, ctx)
        unless (recv_ty.class_type?).truthy?
          return RUBY_FALSE
        end
        mkey = RubyArray.new([recv_ty.class_name, call.name] of RubyObject)
        changed = RUBY_FALSE
                (_or75 = call.arg_nodes; _or75.truthy? ? _or75 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, mkey, i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_instance_method_args(call : RubyObject, ctx : RubyObject)
        recv_ty = infer_expr(call.receiver_node, ctx)
        unless (recv_ty.class_type?).truthy?
          return RUBY_FALSE
        end
        mkey = RubyArray.new([recv_ty.class_name, call.name] of RubyObject)
        changed = RUBY_FALSE
                (_or76 = call.arg_nodes; _or76.truthy? ? _or76 : (RubyArray.new([] of RubyObject))).each_with_index() do |arg, i| 
          ty = infer_expr(arg, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, mkey, i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_execute_block
        unless (@execute_block.body).truthy?
          return RUBY_FALSE
        end
        changed = propagate_for_targets(@execute_block.body, Ruby_TOP_LEVEL_CTX)
        changed = (changed | propagate_locals(@execute_block.body, Ruby_TOP_LEVEL_CTX))
        changed = (changed | propagate_masgn_from_calls(@execute_block.body, Ruby_TOP_LEVEL_CTX))
        changed
      end

      def propagate_method(mkey : RubyObject, method : RubyObject, ctx : Ruby_TypeContext)
        unless (method.body).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
                (_or77 = method.optional_kw_params; _or77.truthy? ? _or77 : (RubyArray.new([] of RubyObject))).each() do |kw_name, default_node| 
          unless (default_node).truthy?
            next
          end
          ty = infer_expr(default_node, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_24, mkey, kw_name] of RubyObject), ty))
          end
        end
        changed = (changed | propagate_array_locals(method.body, ctx))
        changed = (changed | propagate_for_targets(method.body, ctx))
        changed = (changed | propagate_locals(method.body, ctx))
        changed = (changed | propagate_masgn_from_calls(method.body, ctx))
        ret_ty = infer_body_return(method.body, ctx)
        unless (ret_ty.bottom?).truthy?
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_29, mkey] of RubyObject), ret_ty))
        end
        changed
      end

      def propagate_method(mkey : RubyObject, method : RubyObject, ctx : RubyObject)
        unless (method.body).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
                (_or78 = method.optional_kw_params; _or78.truthy? ? _or78 : (RubyArray.new([] of RubyObject))).each() do |kw_name, default_node| 
          unless (default_node).truthy?
            next
          end
          ty = infer_expr(default_node, ctx)
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_24, mkey, kw_name] of RubyObject), ty))
          end
        end
        changed = (changed | propagate_array_locals(method.body, ctx))
        changed = (changed | propagate_for_targets(method.body, ctx))
        changed = (changed | propagate_locals(method.body, ctx))
        changed = (changed | propagate_masgn_from_calls(method.body, ctx))
        ret_ty = infer_body_return(method.body, ctx)
        unless (ret_ty.bottom?).truthy?
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_29, mkey] of RubyObject), ret_ty))
        end
        changed
      end

      def propagate_locals(body : RubyObject, ctx : Ruby_TypeContext)
        assignments = (_iorw_r79 = @_assign_cache; _iorw_i79 = ctx.as(Ruby_TypeContext).method_key; _iorw_c79 = _iorw_r79[_iorw_i79]; _iorw_c79.truthy? ? _iorw_c79 : (_iorw_r79[_iorw_i79] = collect_assignments(body)))
        if assignments.empty?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        loop do
          iter_changed = RUBY_FALSE
          assignments.each() do |name, rhs_nodes| 
            ty = rhs_nodes.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, rhs|               join(acc, infer_expr(rhs, ctx)) }
            if (ty.bottom?).truthy?
              next
            end
            ty = strip_int_bounds(ty)
            iter_changed = (iter_changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, name] of RubyObject), ty))
          end
          changed = (changed | iter_changed)
          unless (iter_changed).truthy?
            break
          end
        end
        changed
      end

      def propagate_locals(body : RubyObject, ctx : RubyObject)
        assignments = (_iorw_r80 = @_assign_cache; _iorw_i80 = ctx.method_key; _iorw_c80 = _iorw_r80[_iorw_i80]; _iorw_c80.truthy? ? _iorw_c80 : (_iorw_r80[_iorw_i80] = collect_assignments(body)))
        if assignments.empty?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        loop do
          iter_changed = RUBY_FALSE
          assignments.each() do |name, rhs_nodes| 
            ty = rhs_nodes.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, rhs|               join(acc, infer_expr(rhs, ctx)) }
            if (ty.bottom?).truthy?
              next
            end
            ty = strip_int_bounds(ty)
            iter_changed = (iter_changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.method_key, name] of RubyObject), ty))
          end
          changed = (changed | iter_changed)
          unless (iter_changed).truthy?
            break
          end
        end
        changed
      end

      def strip_int_bounds(ty : RubyObject)
        unless (ty.is_a?(Ruby_Type) ? RUBY_TRUE : RUBY_FALSE)
          return ty
        end
        if ((_and81 = ty.i64?; _and81.truthy? ? (ty.int_bounds) : _and81)).truthy?
          return Ruby_Type::Ruby_I64
        end
        if ((_and82 = ty.array?; _and82.truthy? ? (ty.elem) : _and82)).truthy?
          new_elem = strip_int_bounds(ty.elem)
          if (((new_elem != ty.elem) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            return Ruby_Type.array(elem: new_elem)
          end
        end
        ty
      end

      def propagate_masgn_from_calls(body : RubyObject, ctx : Ruby_TypeContext)
        changed = RUBY_FALSE
        walk(body) do |node| 
          unless node.ruby_is_a?(Ruby_Ast::Ruby_MultipleAssignment)
            next
          end
          targets = (_or83 = node.targets; _or83.truthy? ? _or83 : (RubyArray.new([] of RubyObject)))
          value = node.value_node
          unless ((_and84 = value.ruby_is_a?(Ruby_Ast::Ruby_MethodCall); _and84.truthy? ? (value.receiver_node.ruby_nil?) : _and84)).truthy?
            next
          end
          method_name = value.name
          method = @user_methods[method_name]
          unless (method).truthy?
            next
          end
          ret_node = last_expression(method.body)
          unless ret_node.ruby_is_a?(Ruby_Ast::Ruby_ArrayLiteral)
            next
          end
          ret_elems = (_or85 = ret_node.element_nodes; _or85.truthy? ? _or85 : (RubyArray.new([] of RubyObject)))
          targets.each_with_index() do |t, i| 
            unless ((_and86 = ((t[0_i64] == Ruby_Sym_30) ? RUBY_TRUE : RUBY_FALSE); _and86.truthy? ? (ret_elems[i]) : _and86)).truthy?
              next
            end
            callee_ctx : Ruby_TypeContext = Ruby_TypeContext.new(method_name, RUBY_NIL)
            elem_ty = infer_expr(ret_elems[i], callee_ctx)
            if (elem_ty.bottom?).truthy?
              next
            end
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, t[1_i64]] of RubyObject), elem_ty))
          end
        end
        changed
      end

      def propagate_masgn_from_calls(body : RubyObject, ctx : RubyObject)
        changed = RUBY_FALSE
        walk(body) do |node| 
          unless node.ruby_is_a?(Ruby_Ast::Ruby_MultipleAssignment)
            next
          end
          targets = (_or87 = node.targets; _or87.truthy? ? _or87 : (RubyArray.new([] of RubyObject)))
          value = node.value_node
          unless ((_and88 = value.ruby_is_a?(Ruby_Ast::Ruby_MethodCall); _and88.truthy? ? (value.receiver_node.ruby_nil?) : _and88)).truthy?
            next
          end
          method_name = value.name
          method = @user_methods[method_name]
          unless (method).truthy?
            next
          end
          ret_node = last_expression(method.body)
          unless ret_node.ruby_is_a?(Ruby_Ast::Ruby_ArrayLiteral)
            next
          end
          ret_elems = (_or89 = ret_node.element_nodes; _or89.truthy? ? _or89 : (RubyArray.new([] of RubyObject)))
          targets.each_with_index() do |t, i| 
            unless ((_and90 = ((t[0_i64] == Ruby_Sym_30) ? RUBY_TRUE : RUBY_FALSE); _and90.truthy? ? (ret_elems[i]) : _and90)).truthy?
              next
            end
            callee_ctx = Ruby_TypeContext.new(method_name, RUBY_NIL)
            elem_ty = infer_expr(ret_elems[i], callee_ctx)
            if (elem_ty.bottom?).truthy?
              next
            end
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.method_key, t[1_i64]] of RubyObject), elem_ty))
          end
        end
        changed
      end

      def last_expression(node : RubyObject)
        unless (node).truthy?
          return RUBY_NIL
        end
        _case_subj = node
        if (Ruby_Ast::Ruby_Sequence) == _case_subj
          last_expression(node.nodes.last)
        else
          node
        end
      end

      def propagate_array_locals(body : RubyObject, ctx : Ruby_TypeContext)
        unless (body).truthy?
          return RUBY_FALSE
        end
        assignments = (_iorw_r91 = @_assign_cache; _iorw_i91 = ctx.as(Ruby_TypeContext).method_key; _iorw_c91 = _iorw_r91[_iorw_i91]; _iorw_c91.truthy? ? _iorw_c91 : (_iorw_r91[_iorw_i91] = collect_assignments(body)))
        param_names = param_names_for(ctx)
        changed = RUBY_FALSE
        assignments.each() do |name, rhs_nodes| 
          if (param_names.include?(name)).truthy?
            next
          end
          unless (((rhs_nodes.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          rhs = rhs_nodes.first
          unless (array_new_call?(rhs)).truthy?
            next
          end
          args = (_or92 = rhs.arg_nodes; _or92.truthy? ? _or92 : (RubyArray.new([] of RubyObject)))
          unless (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          fill_ty = infer_expr(args[1_i64], ctx)
          unless (fill_ty.raw?).truthy?
            next
          end
          if ((_and93 = escapes?(name, body, ctx); _and93.truthy? ? ((((escapes_only_via_return_array?(name, body)).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and93)).truthy?
            next
          end
          unless (writes_consistent?(name, body, ctx, fill_ty)).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_31, ctx.as(Ruby_TypeContext).method_key, name] of RubyObject), fill_ty))
        end
        elem_writes = (_iorw_r94 = @_elem_write_cache; _iorw_i94 = ctx.as(Ruby_TypeContext).method_key; _iorw_c94 = _iorw_r94[_iorw_i94]; _iorw_c94.truthy? ? _iorw_c94 : (_iorw_r94[_iorw_i94] = collect_array_elem_writes(body)))
        elem_writes.each() do |key, value_nodes| 
          if (key.is_a?(RubySymbol) ? RUBY_TRUE : RUBY_FALSE)
            if (param_names.include?(key)).truthy?
              next
            end
            types = value_nodes.map() { |v|               infer_expr(v, ctx) }
            unless (types.all?() { |_sym2proc| _sym2proc.raw?.as(RubyObject) }).truthy?
              next
            end
            unique = types.uniq
            unless (((unique.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
              next
            end
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_31, ctx.as(Ruby_TypeContext).method_key, key] of RubyObject), unique[0_i64]))
          else
            if ((_and95 = (key.is_a?(RubyArray) ? RUBY_TRUE : RUBY_FALSE); _and95.truthy? ? (((key[0_i64] == Ruby_Sym_33) ? RUBY_TRUE : RUBY_FALSE)) : _and95)).truthy?
              arr_name = key[1_i64]
              types = value_nodes.map() { |v|                 infer_expr(v, ctx) }
              unless (types.all?() { |_sym2proc| _sym2proc.raw?.as(RubyObject) }).truthy?
                next
              end
              unique = types.uniq
              unless (((unique.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
                next
              end
              local_ty = @env.type_of(RubyArray.new([Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, arr_name] of RubyObject))
              if (local_ty.array?).truthy?
                inner = Ruby_Type.array(elem: unique[0_i64])
                changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, arr_name] of RubyObject), Ruby_Type.array(elem: inner)))
              end
            end
          end
        end
        changed
      end

      def propagate_array_locals(body : RubyObject, ctx : RubyObject)
        unless (body).truthy?
          return RUBY_FALSE
        end
        assignments = (_iorw_r96 = @_assign_cache; _iorw_i96 = ctx.method_key; _iorw_c96 = _iorw_r96[_iorw_i96]; _iorw_c96.truthy? ? _iorw_c96 : (_iorw_r96[_iorw_i96] = collect_assignments(body)))
        param_names = param_names_for(ctx)
        changed = RUBY_FALSE
        assignments.each() do |name, rhs_nodes| 
          if (param_names.include?(name)).truthy?
            next
          end
          unless (((rhs_nodes.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          rhs = rhs_nodes.first
          unless (array_new_call?(rhs)).truthy?
            next
          end
          args = (_or97 = rhs.arg_nodes; _or97.truthy? ? _or97 : (RubyArray.new([] of RubyObject)))
          unless (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          fill_ty = infer_expr(args[1_i64], ctx)
          unless (fill_ty.raw?).truthy?
            next
          end
          if ((_and98 = escapes?(name, body, ctx); _and98.truthy? ? ((((escapes_only_via_return_array?(name, body)).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and98)).truthy?
            next
          end
          unless (writes_consistent?(name, body, ctx, fill_ty)).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_31, ctx.method_key, name] of RubyObject), fill_ty))
        end
        elem_writes = (_iorw_r99 = @_elem_write_cache; _iorw_i99 = ctx.method_key; _iorw_c99 = _iorw_r99[_iorw_i99]; _iorw_c99.truthy? ? _iorw_c99 : (_iorw_r99[_iorw_i99] = collect_array_elem_writes(body)))
        elem_writes.each() do |key, value_nodes| 
          if (key.is_a?(RubySymbol) ? RUBY_TRUE : RUBY_FALSE)
            if (param_names.include?(key)).truthy?
              next
            end
            types = value_nodes.map() { |v|               infer_expr(v, ctx) }
            unless (types.all?() { |_sym2proc| _sym2proc.raw?.as(RubyObject) }).truthy?
              next
            end
            unique = types.uniq
            unless (((unique.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
              next
            end
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_31, ctx.method_key, key] of RubyObject), unique[0_i64]))
          else
            if ((_and100 = (key.is_a?(RubyArray) ? RUBY_TRUE : RUBY_FALSE); _and100.truthy? ? (((key[0_i64] == Ruby_Sym_33) ? RUBY_TRUE : RUBY_FALSE)) : _and100)).truthy?
              arr_name = key[1_i64]
              types = value_nodes.map() { |v|                 infer_expr(v, ctx) }
              unless (types.all?() { |_sym2proc| _sym2proc.raw?.as(RubyObject) }).truthy?
                next
              end
              unique = types.uniq
              unless (((unique.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
                next
              end
              local_ty = @env.type_of(RubyArray.new([Ruby_Sym_30, ctx.method_key, arr_name] of RubyObject))
              if (local_ty.array?).truthy?
                inner = Ruby_Type.array(elem: unique[0_i64])
                changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_30, ctx.method_key, arr_name] of RubyObject), Ruby_Type.array(elem: inner)))
              end
            end
          end
        end
        changed
      end

      def collect_array_elem_writes(node : RubyObject, result : RubyObject = (RubyHash.new() { |h, k|   h[k] = RubyArray.new([] of RubyObject) }), *, depth : RubyObject = (RubyInteger.new(0_i64)))
        unless (node).truthy?
          return result
        end
        _case_subj = node
        if (Ruby_Ast::Ruby_MethodCall) == _case_subj
          args = (_or101 = node.arg_nodes; _or101.truthy? ? _or101 : (RubyArray.new([] of RubyObject)))
          recv = node.receiver_node
          if ((_and102 =           (_or103 = ((node.name == Ruby_Sym_34) ? RUBY_TRUE : RUBY_FALSE); _or103.truthy? ? _or103 : (((node.name == Ruby_Sym_35) ? RUBY_TRUE : RUBY_FALSE))); _and102.truthy? ? (((args.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and102)).truthy?
            if recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)
              (result[recv.name] << args[0_i64])
            else
              if ((_and104 = (_and105 = recv.ruby_is_a?(Ruby_Ast::Ruby_MethodCall); _and105.truthy? ? (((recv.name == Ruby_Sym_36) ? RUBY_TRUE : RUBY_FALSE)) : _and105); _and104.truthy? ? (recv.receiver_node.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)) : _and104)).truthy?
                (result[RubyTuple2.new(Ruby_Sym_33, recv.receiver_node.name)] << args[0_i64])
              end
            end
          end
          collect_array_elem_writes(recv, result, depth: depth)
          args.each() { |a|             collect_array_elem_writes(a, result, depth: depth) }
          blk = node.block_node
          if blk.ruby_is_a?(Ruby_Ast::Ruby_Block)
            collect_array_elem_writes(blk.body, result, depth: depth)
          end
        elsif (Ruby_Ast::Ruby_AttributeWrite) == _case_subj
          if (((node.name == Ruby_Sym_38) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            recv = node.receiver_node
            args = (_or106 = node.arg_nodes; _or106.truthy? ? _or106 : (RubyArray.new([] of RubyObject)))
            if ((_and107 = recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead); _and107.truthy? ? (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and107)).truthy?
              (result[recv.name] << args[1_i64])
            end
          end
        elsif (Ruby_Ast::Ruby_Sequence) == _case_subj
          node.nodes.each() { |n|             collect_array_elem_writes(n, result, depth: depth) }
        elsif (Ruby_Ast::Ruby_If) == _case_subj
          collect_array_elem_writes(node.then_node, result, depth: depth)
          collect_array_elem_writes(node.else_node, result, depth: depth)
        elsif (Ruby_Ast::Ruby_While) == _case_subj || (Ruby_Ast::Ruby_Until) == _case_subj
          collect_array_elem_writes(node.body_node, result, depth: depth)
        elsif (Ruby_Ast::Ruby_Block) == _case_subj
          collect_array_elem_writes(node.body, result, depth: depth)
        end
        result
      end

      def propagate_for_targets(body : RubyObject, ctx : Ruby_TypeContext)
        unless (body).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        walk(body) do |node| 
          unless node.ruby_is_a?(Ruby_Ast::Ruby_ForLoop)
            next
          end
          target = node.target
          unless (((target[0_i64] == Ruby_Sym_30) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          name = target[1_i64]
          coll_node = node.collection_node
          coll_ty = infer_expr(coll_node, ctx)
          elem_ty = for_loop_elem_type(coll_ty)
          if ((_or108 = elem_ty.ruby_nil?; _or108.truthy? ? _or108 : (elem_ty.bottom?))).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_39, ctx.as(Ruby_TypeContext).method_key, name] of RubyObject), elem_ty))
        end
        changed
      end

      def propagate_for_targets(body : RubyObject, ctx : RubyObject)
        unless (body).truthy?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        walk(body) do |node| 
          unless node.ruby_is_a?(Ruby_Ast::Ruby_ForLoop)
            next
          end
          target = node.target
          unless (((target[0_i64] == Ruby_Sym_30) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            next
          end
          name = target[1_i64]
          coll_node = node.collection_node
          coll_ty = infer_expr(coll_node, ctx)
          elem_ty = for_loop_elem_type(coll_ty)
          if ((_or109 = elem_ty.ruby_nil?; _or109.truthy? ? _or109 : (elem_ty.bottom?))).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_39, ctx.method_key, name] of RubyObject), elem_ty))
        end
        changed
      end

      def for_loop_elem_type(coll_ty : RubyObject)
        if ((_and110 = coll_ty.class_type?; _and110.truthy? ? (((coll_ty.class_name == Ruby_Sym_40) ? RUBY_TRUE : RUBY_FALSE)) : _and110)).truthy?
          return Ruby_Type::Ruby_I64
        end
        if ((_and111 = coll_ty.array?; _and111.truthy? ? (coll_ty.elem) : _and111)).truthy?
          return coll_ty.elem
        end
        RUBY_NIL
      end

      def propagate_ivars(class_name : RubyObject, klass : RubyObject)
        begin
          init =           (_or112 = klass.methods_table; _or112.truthy? ? _or112 : (RubyHash.new))[Ruby_Sym_41]
          unless ((_and113 = init.ruby_is_a?(Ruby_Vm::Ruby_Method); _and113.truthy? ? (init.body) : _and113)).truthy?
            return RUBY_FALSE
          end
          req_params = (_or114 = init.required_params; _or114.truthy? ? _or114 : (RubyArray.new([] of RubyObject)))
          param_types = if req_params.empty?
            RubyArray.new([] of RubyObject)
          else
            best_constructor_param_types(class_name, req_params.size)
          end
          unless (param_types).truthy?
            return RUBY_FALSE
          end
          old_seeds = @ivar_param_seeds
          @ivar_param_seeds = req_params.zip(param_types).to_h
          changed = RUBY_FALSE
          changed = (changed | seed_constructor_params(class_name, param_types))
          changed = (changed | propagate_ivars_from_initialize(class_name, init))
          changed = (changed | propagate_ivars_from_other_methods(class_name, klass))
          changed = (changed | propagate_ivars_from_setter_calls(class_name, klass))
          changed = (changed | propagate_ivar_array_elem_writes(class_name, klass))
          changed
        ensure
          if (RUBY_NIL).truthy?
            @ivar_param_seeds = old_seeds
          end
        end
      end

      def seed_constructor_params(class_name : RubyObject, param_types : RubyObject)
        changed = RUBY_FALSE
        param_types.each_with_index() do |ty, i| 
          unless (ty.bottom?).truthy?
            changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_26, RubyArray.new([class_name, Ruby_Sym_41] of RubyObject), i] of RubyObject), ty))
          end
        end
        changed
      end

      def propagate_ivars_from_initialize(class_name : RubyObject, init : RubyObject)
        ctx : Ruby_TypeContext = Ruby_TypeContext.new(RubyTuple2.new(class_name, Ruby_Sym_41), class_name)
        changed = RUBY_FALSE
        collect_ivar_assignments(init.body).each() do |ivar_name, rhs_nodes| 
          ty = rhs_nodes.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, rhs|             join(acc, infer_expr(rhs, ctx)) }
          if (ty.bottom?).truthy?
            next
          end
          changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_42, class_name, ivar_name] of RubyObject), ty))
        end
        changed
      end

      def propagate_ivars_from_other_methods(class_name : RubyObject, klass : RubyObject)
        changed = RUBY_FALSE
                (_or115 = klass.methods_table; _or115.truthy? ? _or115 : (RubyHash.new)).each() do |mname, method| 
          if ((_or116 = (_or117 = ((mname == Ruby_Sym_41) ? RUBY_TRUE : RUBY_FALSE); _or117.truthy? ? _or117 : (((method.ruby_is_a?(Ruby_Vm::Ruby_Method)) ? RUBY_FALSE : RUBY_TRUE))); _or116.truthy? ? _or116 : ((((method.body).truthy?) ? RUBY_FALSE : RUBY_TRUE)))).truthy?
            next
          end
          method_ctx : Ruby_TypeContext = Ruby_TypeContext.new(RubyTuple2.new(class_name, mname), class_name)
          collect_ivar_assignments(method.body).each() do |ivar_name, rhs_nodes| 
            rhs_nodes.each() do |rhs| 
              ty = infer_expr(rhs, method_ctx)
              if ((_or118 = ty.ruby_nil?; _or118.truthy? ? _or118 : (ty.bottom?))).truthy?
                next
              end
              changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_42, class_name, ivar_name] of RubyObject), ty))
            end
          end
        end
        changed
      end

      def propagate_ivars_from_setter_calls(class_name : RubyObject, klass : RubyObject)
        accessor_names : Ruby_Set = Ruby_Set.new
                (_or119 = klass.methods_table; _or119.truthy? ? _or119 : (RubyHash.new)).each_key() do |mn| 
          if ((_and120 = mn.ruby_to_s.end_with?(Ruby_Str_27); _and120.truthy? ? (((mn != Ruby_Sym_41) ? RUBY_TRUE : RUBY_FALSE)) : _and120)).truthy?
            accessor_names.as(Ruby_Set).<<(mn.ruby_to_s.chomp(Ruby_Str_27).to_sym)
          end
        end
        if accessor_names.as(Ruby_Set).empty?
          return RUBY_FALSE
        end
        changed = RUBY_FALSE
        each_user_method() do |mkey, method| 
          unless (method.body).truthy?
            next
          end
          method_ctx = Ruby_TypeContext.new(mkey, if (mkey.is_a?(RubyArray) ? RUBY_TRUE : RUBY_FALSE)
            mkey[0_i64]
          else
            RUBY_NIL
          end)
          collect_setter_calls(method.body, class_name, accessor_names, method_ctx) { |attr_name, ty|             changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_42, class_name, RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("@"); _s.concat_raw_bytes!((            attr_name).to_s) }.to_sym] of RubyObject), ty)) }
        end
        changed
      end

      def propagate_ivar_array_elem_writes(class_name : RubyObject, klass : RubyObject)
        changed = RUBY_FALSE
                (_or121 = klass.methods_table; _or121.truthy? ? _or121 : (RubyHash.new)).each() do |mname, method| 
          unless ((_and122 = method.ruby_is_a?(Ruby_Vm::Ruby_Method); _and122.truthy? ? (method.body) : _and122)).truthy?
            next
          end
          method_ctx = Ruby_TypeContext.new(RubyTuple2.new(class_name, mname), class_name)
          collect_ivar_array_elem_writes(method.body, class_name, method_ctx) do |ivar_name, elem_ty| 
            current = @env.type_of(RubyArray.new([Ruby_Sym_42, class_name, ivar_name] of RubyObject))
            if ((_and123 = current.array?; _and123.truthy? ? ((((current.elem).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and123)).truthy?
              changed = (changed | @env.join!(RubyArray.new([Ruby_Sym_42, class_name, ivar_name] of RubyObject), Ruby_Type.array(elem: elem_ty)))
            end
          end
        end
        changed
      end

      def each_user_method(&block)
        @user_methods.each() { |_blkarg| (block).as(RubyProc).call(_blkarg) }
        @user_classes.each() do |cname, ck| 
                    (_or124 = ck.methods_table; _or124.truthy? ? _or124 : (RubyHash.new)).each() do |mn, m| 
            if m.ruby_is_a?(Ruby_Vm::Ruby_Method)
              yield (RubyTuple2.new(RubyTuple2.new(cname, mn), m))
            end
          end
        end
      end

      def collect_ivar_array_elem_writes(node : RubyObject, class_name : RubyObject, ctx : Ruby_TypeContext, &block)
        unless (node).truthy?
          return
        end
        if ((_and125 = node.ruby_is_a?(Ruby_Ast::Ruby_AttributeWrite); _and125.truthy? ? (((node.name == Ruby_Sym_38) ? RUBY_TRUE : RUBY_FALSE)) : _and125)).truthy?
          recv = node.receiver_node
          args = (_or126 = node.arg_nodes; _or126.truthy? ? _or126 : (RubyArray.new([] of RubyObject)))
          if ((_and127 = recv.ruby_is_a?(Ruby_Ast::Ruby_InstanceVariableRead); _and127.truthy? ? (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and127)).truthy?
            ivar_name = recv.name
            val_ty = infer_expr(args[1_i64], ctx)
            unless (val_ty.bottom?).truthy?
              raw = if (val_ty.raw?).truthy?
                val_ty
              else
                if ((_and128 = val_ty.class_type?; _and128.truthy? ? (((val_ty.class_name == Ruby_Sym_6) ? RUBY_TRUE : RUBY_FALSE)) : _and128)).truthy?
                  Ruby_Type::Ruby_F64
                else
                  if ((_and129 = val_ty.class_type?; _and129.truthy? ? (((val_ty.class_name == Ruby_Sym_5) ? RUBY_TRUE : RUBY_FALSE)) : _and129)).truthy?
                    Ruby_Type::Ruby_I64
                  end
                end
              end
              if (raw).truthy?
                yield (ivar_name), (raw)
              end
            end
          end
        end
        node.children.each() { |c|           collect_ivar_array_elem_writes(c, class_name, ctx) { |_blkarg| (block).as(RubyProc).call(_blkarg) } }
      end

      def collect_ivar_array_elem_writes(node : RubyObject, class_name : RubyObject, ctx : RubyObject, &block)
        unless (node).truthy?
          return
        end
        if ((_and130 = node.ruby_is_a?(Ruby_Ast::Ruby_AttributeWrite); _and130.truthy? ? (((node.name == Ruby_Sym_38) ? RUBY_TRUE : RUBY_FALSE)) : _and130)).truthy?
          recv = node.receiver_node
          args = (_or131 = node.arg_nodes; _or131.truthy? ? _or131 : (RubyArray.new([] of RubyObject)))
          if ((_and132 = recv.ruby_is_a?(Ruby_Ast::Ruby_InstanceVariableRead); _and132.truthy? ? (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and132)).truthy?
            ivar_name = recv.name
            val_ty = infer_expr(args[1_i64], ctx)
            unless (val_ty.bottom?).truthy?
              raw = if (val_ty.raw?).truthy?
                val_ty
              else
                if ((_and133 = val_ty.class_type?; _and133.truthy? ? (((val_ty.class_name == Ruby_Sym_6) ? RUBY_TRUE : RUBY_FALSE)) : _and133)).truthy?
                  Ruby_Type::Ruby_F64
                else
                  if ((_and134 = val_ty.class_type?; _and134.truthy? ? (((val_ty.class_name == Ruby_Sym_5) ? RUBY_TRUE : RUBY_FALSE)) : _and134)).truthy?
                    Ruby_Type::Ruby_I64
                  end
                end
              end
              if (raw).truthy?
                yield (ivar_name), (raw)
              end
            end
          end
        end
        node.children.each() { |c|           collect_ivar_array_elem_writes(c, class_name, ctx) { |_blkarg| (block).as(RubyProc).call(_blkarg) } }
      end

      def collect_setter_calls(node : RubyObject, class_name : RubyObject, accessor_names : Ruby_Set, ctx : Ruby_TypeContext, &block)
        unless (node).truthy?
          return
        end
        if node.ruby_is_a?(Ruby_Ast::Ruby_AttributeWrite)
          name_sym = node.name
          attr = name_sym.ruby_to_s.chomp(Ruby_Str_27).to_sym
          if (accessor_names.as(Ruby_Set).include?(attr)).truthy?
            recv = node.receiver_node
            recv_cls = RUBY_NIL
            if recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)
              recv_ty = @env.type_of(RubyArray.new([Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, recv.name] of RubyObject))
              if (recv_ty.class_type?).truthy?
                recv_cls = recv_ty.class_name
              end
            end
            if (recv_cls.as(RubyNil).==(class_name)).truthy?
              args = (_or135 = node.arg_nodes; _or135.truthy? ? _or135 : (RubyArray.new([] of RubyObject)))
              if (args[0_i64]).truthy?
                ty = infer_expr(args[0_i64], ctx)
                unless (ty.bottom?).truthy?
                  (block).call(attr, ty)
                end
              end
            end
          end
        end
        node.children.each() { |c|           collect_setter_calls(c, class_name, accessor_names, ctx) { |_blkarg| (block).as(RubyProc).call(_blkarg) } }
      end

      def collect_setter_calls(node : RubyObject, class_name : RubyObject, accessor_names : RubyObject, ctx : RubyObject, &block)
        unless (node).truthy?
          return
        end
        if node.ruby_is_a?(Ruby_Ast::Ruby_AttributeWrite)
          name_sym = node.name
          attr = name_sym.ruby_to_s.chomp(Ruby_Str_27).to_sym
          if (accessor_names.include?(attr)).truthy?
            recv = node.receiver_node
            recv_cls = RUBY_NIL
            if recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)
              recv_ty = @env.type_of(RubyArray.new([Ruby_Sym_30, ctx.method_key, recv.name] of RubyObject))
              if (recv_ty.class_type?).truthy?
                recv_cls = recv_ty.class_name
              end
            end
            if (recv_cls.as(RubyNil).==(class_name)).truthy?
              args = (_or136 = node.arg_nodes; _or136.truthy? ? _or136 : (RubyArray.new([] of RubyObject)))
              if (args[0_i64]).truthy?
                ty = infer_expr(args[0_i64], ctx)
                unless (ty.bottom?).truthy?
                  (block).call(attr, ty)
                end
              end
            end
          end
        end
        node.children.each() { |c|           collect_setter_calls(c, class_name, accessor_names, ctx) { |_blkarg| (block).as(RubyProc).call(_blkarg) } }
      end

      def infer_expr(node : RubyObject, ctx : Ruby_TypeContext)
        unless (node).truthy?
          return Ruby_Type::Ruby_BOTTOM
        end
        cache_key = RubyArray.new([node, ctx.as(Ruby_TypeContext).method_key] of RubyObject)
        if (@_expr_cache.key?(cache_key)).truthy?
          return @_expr_cache[cache_key]
        end
        result = infer_expr_uncached(node, ctx)
        @_expr_cache[cache_key] = result
      end

      def infer_expr(node : RubyObject, ctx : RubyObject)
        unless (node).truthy?
          return Ruby_Type::Ruby_BOTTOM
        end
        cache_key = RubyArray.new([node, ctx.method_key] of RubyObject)
        if (@_expr_cache.key?(cache_key)).truthy?
          return @_expr_cache[cache_key]
        end
        result = infer_expr_uncached(node, ctx)
        @_expr_cache[cache_key] = result
      end

      def infer_expr_uncached(node : RubyObject, ctx : Ruby_TypeContext)
        _case_subj = node
        if (Ruby_Ast::Ruby_IntegerLiteral) == _case_subj
          v = if (node.value.respond_to?(Ruby_Sym_43)).truthy?
            node.value.raw
          else
            node.value
          end
          if (v.is_a?(RubyInteger) ? RUBY_TRUE : RUBY_FALSE)
            Ruby_Type.i64_bounded(v, v)
          else
            Ruby_Type::Ruby_I64
          end
        elsif (Ruby_Ast::Ruby_FloatLiteral) == _case_subj
          Ruby_Type::Ruby_F64
        elsif (Ruby_Ast::Ruby_NilLiteral) == _case_subj
          Ruby_Type::Ruby_NIL_CLASS
        elsif (Ruby_Ast::Ruby_TrueLiteral) == _case_subj
          Ruby_Type::Ruby_TRUE_CLASS
        elsif (Ruby_Ast::Ruby_FalseLiteral) == _case_subj
          Ruby_Type::Ruby_FALSE_CLASS
        elsif (Ruby_Ast::Ruby_StringLiteral) == _case_subj
          Ruby_Type::Ruby_STRING
        elsif (Ruby_Ast::Ruby_SymbolLiteral) == _case_subj
          Ruby_Type::Ruby_SYMBOL
        elsif (Ruby_Ast::Ruby_RangeLiteral) == _case_subj
          Ruby_Type::Ruby_RANGE
        elsif (Ruby_Ast::Ruby_RegexpLiteral) == _case_subj
          Ruby_Type::Ruby_REGEXP
        elsif (Ruby_Ast::Ruby_ArrayLiteral) == _case_subj
          infer_array_literal_type(node, ctx)
        elsif (Ruby_Ast::Ruby_HashLiteral) == _case_subj
          infer_hash_literal_type(node, ctx)
        elsif (Ruby_Ast::Ruby_Sequence) == _case_subj
          infer_expr(node.nodes.last, ctx)
        elsif (Ruby_Ast::Ruby_LocalVariableRead) == _case_subj
          infer_local_var_type(node, ctx)
        elsif (Ruby_Ast::Ruby_InstanceVariableRead) == _case_subj
          @env.type_of(RubyTuple3.new(Ruby_Sym_42, ctx.as(Ruby_TypeContext).class_name, node.name))
        elsif (Ruby_Ast::Ruby_ConstantRead) == _case_subj
          @env.type_of(RubyTuple2.new(Ruby_Sym_23, node.name))
        elsif (Ruby_Ast::Ruby_LocalVariableWrite) == _case_subj
          infer_expr(node.value_node, ctx)
        elsif (Ruby_Ast::Ruby_If) == _case_subj
          infer_if_type(node, ctx)
        elsif (Ruby_Ast::Ruby_MethodCall) == _case_subj
          infer_call(node, ctx)
        elsif (Ruby_Ast::Ruby_Or) == _case_subj
          infer_short_circuit_type(node, ctx)
        elsif (Ruby_Ast::Ruby_And) == _case_subj
          infer_short_circuit_type(node, ctx)
        else
          Ruby_Type::Ruby_BOTTOM
        end
      end

      def infer_expr_uncached(node : RubyObject, ctx : RubyObject)
        _case_subj = node
        if (Ruby_Ast::Ruby_IntegerLiteral) == _case_subj
          v = if (node.value.respond_to?(Ruby_Sym_43)).truthy?
            node.value.raw
          else
            node.value
          end
          if (v.is_a?(RubyInteger) ? RUBY_TRUE : RUBY_FALSE)
            Ruby_Type.i64_bounded(v, v)
          else
            Ruby_Type::Ruby_I64
          end
        elsif (Ruby_Ast::Ruby_FloatLiteral) == _case_subj
          Ruby_Type::Ruby_F64
        elsif (Ruby_Ast::Ruby_NilLiteral) == _case_subj
          Ruby_Type::Ruby_NIL_CLASS
        elsif (Ruby_Ast::Ruby_TrueLiteral) == _case_subj
          Ruby_Type::Ruby_TRUE_CLASS
        elsif (Ruby_Ast::Ruby_FalseLiteral) == _case_subj
          Ruby_Type::Ruby_FALSE_CLASS
        elsif (Ruby_Ast::Ruby_StringLiteral) == _case_subj
          Ruby_Type::Ruby_STRING
        elsif (Ruby_Ast::Ruby_SymbolLiteral) == _case_subj
          Ruby_Type::Ruby_SYMBOL
        elsif (Ruby_Ast::Ruby_RangeLiteral) == _case_subj
          Ruby_Type::Ruby_RANGE
        elsif (Ruby_Ast::Ruby_RegexpLiteral) == _case_subj
          Ruby_Type::Ruby_REGEXP
        elsif (Ruby_Ast::Ruby_ArrayLiteral) == _case_subj
          infer_array_literal_type(node, ctx)
        elsif (Ruby_Ast::Ruby_HashLiteral) == _case_subj
          infer_hash_literal_type(node, ctx)
        elsif (Ruby_Ast::Ruby_Sequence) == _case_subj
          infer_expr(node.nodes.last, ctx)
        elsif (Ruby_Ast::Ruby_LocalVariableRead) == _case_subj
          infer_local_var_type(node, ctx)
        elsif (Ruby_Ast::Ruby_InstanceVariableRead) == _case_subj
          @env.type_of(RubyTuple3.new(Ruby_Sym_42, ctx.class_name, node.name))
        elsif (Ruby_Ast::Ruby_ConstantRead) == _case_subj
          @env.type_of(RubyTuple2.new(Ruby_Sym_23, node.name))
        elsif (Ruby_Ast::Ruby_LocalVariableWrite) == _case_subj
          infer_expr(node.value_node, ctx)
        elsif (Ruby_Ast::Ruby_If) == _case_subj
          infer_if_type(node, ctx)
        elsif (Ruby_Ast::Ruby_MethodCall) == _case_subj
          infer_call(node, ctx)
        elsif (Ruby_Ast::Ruby_Or) == _case_subj
          infer_short_circuit_type(node, ctx)
        elsif (Ruby_Ast::Ruby_And) == _case_subj
          infer_short_circuit_type(node, ctx)
        else
          Ruby_Type::Ruby_BOTTOM
        end
      end

      def infer_array_literal_type(node : RubyObject, ctx : Ruby_TypeContext)
        elems = (_or137 = node.element_nodes; _or137.truthy? ? _or137 : (RubyArray.new([] of RubyObject)))
        if elems.empty?
          return Ruby_Type::Ruby_ARRAY
        end
        elem_ty = elems.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, e|           join(acc, infer_expr(e, ctx)) }
        if (elem_ty.bottom?).truthy?
          Ruby_Type::Ruby_ARRAY
        else
          Ruby_Type.array(elem: elem_ty)
        end
      end

      def infer_array_literal_type(node : RubyObject, ctx : RubyObject)
        elems = (_or138 = node.element_nodes; _or138.truthy? ? _or138 : (RubyArray.new([] of RubyObject)))
        if elems.empty?
          return Ruby_Type::Ruby_ARRAY
        end
        elem_ty = elems.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, e|           join(acc, infer_expr(e, ctx)) }
        if (elem_ty.bottom?).truthy?
          Ruby_Type::Ruby_ARRAY
        else
          Ruby_Type.array(elem: elem_ty)
        end
      end

      def infer_hash_literal_type(node : RubyObject, ctx : Ruby_TypeContext)
        pairs = (_or139 = node.kv_nodes; _or139.truthy? ? _or139 : (RubyArray.new([] of RubyObject)))
        if pairs.empty?
          return Ruby_Type::Ruby_HASH
        end
        key_ty = pairs.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, (k, _)|           join(acc, infer_expr(k, ctx)) }
        val_ty = pairs.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, (_, v)|           join(acc, infer_expr(v, ctx)) }
        Ruby_Type.hash_type(key: if (key_ty.bottom?).truthy?
          RUBY_NIL
        else
          key_ty
        end, val: if (val_ty.bottom?).truthy?
          RUBY_NIL
        else
          val_ty
        end)
      end

      def infer_hash_literal_type(node : RubyObject, ctx : RubyObject)
        pairs = (_or140 = node.kv_nodes; _or140.truthy? ? _or140 : (RubyArray.new([] of RubyObject)))
        if pairs.empty?
          return Ruby_Type::Ruby_HASH
        end
        key_ty = pairs.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, (k, _)|           join(acc, infer_expr(k, ctx)) }
        val_ty = pairs.reduce(Ruby_Type::Ruby_BOTTOM) { |acc, (_, v)|           join(acc, infer_expr(v, ctx)) }
        Ruby_Type.hash_type(key: if (key_ty.bottom?).truthy?
          RUBY_NIL
        else
          key_ty
        end, val: if (val_ty.bottom?).truthy?
          RUBY_NIL
        else
          val_ty
        end)
      end

      def infer_local_var_type(node : RubyObject, ctx : Ruby_TypeContext)
        name = node.name
        if (@ivar_param_seeds.key?(name)).truthy?
          return @ivar_param_seeds[name]
        end
        idx = param_index(ctx, name)
        if (idx).truthy?
          pv = @env.type_of(RubyArray.new([Ruby_Sym_26, ctx.as(Ruby_TypeContext).method_key, idx] of RubyObject))
          unless (pv.bottom?).truthy?
            return pv
          end
        end
        kp = @env.type_of(RubyArray.new([Ruby_Sym_24, ctx.as(Ruby_TypeContext).method_key, name] of RubyObject))
        unless (kp.bottom?).truthy?
          return kp
        end
        bp = @env.type_of(RubyArray.new([Ruby_Sym_39, ctx.as(Ruby_TypeContext).method_key, name] of RubyObject))
        unless (bp.bottom?).truthy?
          return bp
        end
        @env.type_of(RubyTuple3.new(Ruby_Sym_30, ctx.as(Ruby_TypeContext).method_key, name))
      end

      def infer_local_var_type(node : RubyObject, ctx : RubyObject)
        name = node.name
        if (@ivar_param_seeds.key?(name)).truthy?
          return @ivar_param_seeds[name]
        end
        idx = param_index(ctx, name)
        if (idx).truthy?
          pv = @env.type_of(RubyArray.new([Ruby_Sym_26, ctx.method_key, idx] of RubyObject))
          unless (pv.bottom?).truthy?
            return pv
          end
        end
        kp = @env.type_of(RubyArray.new([Ruby_Sym_24, ctx.method_key, name] of RubyObject))
        unless (kp.bottom?).truthy?
          return kp
        end
        bp = @env.type_of(RubyArray.new([Ruby_Sym_39, ctx.method_key, name] of RubyObject))
        unless (bp.bottom?).truthy?
          return bp
        end
        @env.type_of(RubyTuple3.new(Ruby_Sym_30, ctx.method_key, name))
      end

      def infer_if_type(node : RubyObject, ctx : Ruby_TypeContext)
        t = infer_expr(node.then_node, ctx)
        e_ty = if (node.else_node).truthy?
          infer_expr(node.else_node, ctx)
        else
          Ruby_Type::Ruby_NIL_CLASS
        end
        if (e_ty.bottom?).truthy?
          return t
        end
        if (t.bottom?).truthy?
          return e_ty
        end
        join(t, e_ty)
      end

      def infer_if_type(node : RubyObject, ctx : RubyObject)
        t = infer_expr(node.then_node, ctx)
        e_ty = if (node.else_node).truthy?
          infer_expr(node.else_node, ctx)
        else
          Ruby_Type::Ruby_NIL_CLASS
        end
        if (e_ty.bottom?).truthy?
          return t
        end
        if (t.bottom?).truthy?
          return e_ty
        end
        join(t, e_ty)
      end

      def infer_short_circuit_type(node : RubyObject, ctx : Ruby_TypeContext)
        lt = infer_expr(node.left_node, ctx)
        rt = infer_expr(node.right_node, ctx)
        if (lt.bottom?).truthy?
          return rt
        end
        if (rt.bottom?).truthy?
          return lt
        end
        join(lt, rt)
      end

      def infer_short_circuit_type(node : RubyObject, ctx : RubyObject)
        lt = infer_expr(node.left_node, ctx)
        rt = infer_expr(node.right_node, ctx)
        if (lt.bottom?).truthy?
          return rt
        end
        if (rt.bottom?).truthy?
          return lt
        end
        join(lt, rt)
      end

      def infer_call(node : RubyObject, ctx : Ruby_TypeContext)
        result = (_or141 = try_infer_array_factory(node, ctx); _or141.truthy? ? _or141 : (try_infer_map_factory(node, ctx)))
        if (result).truthy?
          return result
        end
        seed_iteration_block_params(node, ctx)
        (_or142 = (_or143 = (_or144 = (_or145 = (_or146 = (_or147 = (_or148 = (_or149 = (_or150 = (_or151 = try_infer_class_new(node, ctx); _or151.truthy? ? _or151 : (try_infer_math_call(node, ctx))); _or150.truthy? ? _or150 : (try_infer_subscript_read(node, ctx))); _or149.truthy? ? _or149 : (try_infer_range_to_a(node, ctx))); _or148.truthy? ? _or148 : (try_infer_builtin_method(node, ctx))); _or147.truthy? ? _or147 : (try_infer_arith_op(node, ctx))); _or146.truthy? ? _or146 : (try_infer_max_min_two_arg(node, ctx))); _or145.truthy? ? _or145 : (try_infer_class_method_call(node, ctx))); _or144.truthy? ? _or144 : (try_infer_instance_method_call(node, ctx))); _or143.truthy? ? _or143 : (try_infer_free_call(node, ctx))); _or142.truthy? ? _or142 : (Ruby_Type::Ruby_BOTTOM))
      end

      def infer_call(node : RubyObject, ctx : RubyObject)
        result = (_or152 = try_infer_array_factory(node, ctx); _or152.truthy? ? _or152 : (try_infer_map_factory(node, ctx)))
        if (result).truthy?
          return result
        end
        seed_iteration_block_params(node, ctx)
        (_or153 = (_or154 = (_or155 = (_or156 = (_or157 = (_or158 = (_or159 = (_or160 = (_or161 = (_or162 = try_infer_class_new(node, ctx); _or162.truthy? ? _or162 : (try_infer_math_call(node, ctx))); _or161.truthy? ? _or161 : (try_infer_subscript_read(node, ctx))); _or160.truthy? ? _or160 : (try_infer_range_to_a(node, ctx))); _or159.truthy? ? _or159 : (try_infer_builtin_method(node, ctx))); _or158.truthy? ? _or158 : (try_infer_arith_op(node, ctx))); _or157.truthy? ? _or157 : (try_infer_max_min_two_arg(node, ctx))); _or156.truthy? ? _or156 : (try_infer_class_method_call(node, ctx))); _or155.truthy? ? _or155 : (try_infer_instance_method_call(node, ctx))); _or154.truthy? ? _or154 : (try_infer_free_call(node, ctx))); _or153.truthy? ? _or153 : (Ruby_Type::Ruby_BOTTOM))
      end

      def try_infer_array_factory(node : RubyObject, ctx : Ruby_TypeContext)
        unless (((node.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        unless ((_and163 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and163.truthy? ? (((recv.name == Ruby_Sym_8) ? RUBY_TRUE : RUBY_FALSE)) : _and163)).truthy?
          return RUBY_NIL
        end
        blk = node.block_node
        args = (_or164 = node.arg_nodes; _or164.truthy? ? _or164 : (RubyArray.new([] of RubyObject)))
        if (blk).truthy?
          elem_ty = infer_block_return(blk, RubyArray.new([Ruby_Type::Ruby_I64] of RubyObject), ctx)
          return (if (elem_ty.bottom?).truthy?
            Ruby_Type::Ruby_ARRAY
          else
            Ruby_Type.array(elem: elem_ty)
          end)
        else
          if (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            fill_ty = infer_expr(args[1_i64], ctx)
            return (if (fill_ty.bottom?).truthy?
              Ruby_Type::Ruby_ARRAY
            else
              Ruby_Type.array(elem: fill_ty)
            end)
          end
        end
        RUBY_NIL
      end

      def try_infer_array_factory(node : RubyObject, ctx : RubyObject)
        unless (((node.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        unless ((_and165 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and165.truthy? ? (((recv.name == Ruby_Sym_8) ? RUBY_TRUE : RUBY_FALSE)) : _and165)).truthy?
          return RUBY_NIL
        end
        blk = node.block_node
        args = (_or166 = node.arg_nodes; _or166.truthy? ? _or166 : (RubyArray.new([] of RubyObject)))
        if (blk).truthy?
          elem_ty = infer_block_return(blk, RubyArray.new([Ruby_Type::Ruby_I64] of RubyObject), ctx)
          return (if (elem_ty.bottom?).truthy?
            Ruby_Type::Ruby_ARRAY
          else
            Ruby_Type.array(elem: elem_ty)
          end)
        else
          if (((args.size == RubyInteger.new(2_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            fill_ty = infer_expr(args[1_i64], ctx)
            return (if (fill_ty.bottom?).truthy?
              Ruby_Type::Ruby_ARRAY
            else
              Ruby_Type.array(elem: fill_ty)
            end)
          end
        end
        RUBY_NIL
      end

      def try_infer_map_factory(node : RubyObject, ctx : Ruby_TypeContext)
        unless ((_and167 = (_and168 = ((node.name == Ruby_Sym_44) ? RUBY_TRUE : RUBY_FALSE); _and168.truthy? ? (node.block_node) : _and168); _and167.truthy? ? (node.receiver_node) : _and167)).truthy?
          return RUBY_NIL
        end
        recv_ty = infer_expr(node.receiver_node, ctx)
        unless (recv_ty.array?).truthy?
          return RUBY_NIL
        end
        elem_in = (_or169 = recv_ty.elem; _or169.truthy? ? _or169 : (Ruby_Type::Ruby_BOTTOM))
        elem_out = infer_block_return(node.block_node, RubyArray.new([elem_in] of RubyObject), ctx)
        if (elem_out.bottom?).truthy?
          Ruby_Type::Ruby_ARRAY
        else
          Ruby_Type.array(elem: elem_out)
        end
      end

      def try_infer_map_factory(node : RubyObject, ctx : RubyObject)
        unless ((_and170 = (_and171 = ((node.name == Ruby_Sym_44) ? RUBY_TRUE : RUBY_FALSE); _and171.truthy? ? (node.block_node) : _and171); _and170.truthy? ? (node.receiver_node) : _and170)).truthy?
          return RUBY_NIL
        end
        recv_ty = infer_expr(node.receiver_node, ctx)
        unless (recv_ty.array?).truthy?
          return RUBY_NIL
        end
        elem_in = (_or172 = recv_ty.elem; _or172.truthy? ? _or172 : (Ruby_Type::Ruby_BOTTOM))
        elem_out = infer_block_return(node.block_node, RubyArray.new([elem_in] of RubyObject), ctx)
        if (elem_out.bottom?).truthy?
          Ruby_Type::Ruby_ARRAY
        else
          Ruby_Type.array(elem: elem_out)
        end
      end

      def seed_iteration_block_params(node : RubyObject, ctx : Ruby_TypeContext)
        unless (node.block_node).truthy?
          return
        end
        ptypes = block_param_types(node.name, node.receiver_node, ctx)
        unless ptypes.empty?
          seed_block_params(node.block_node, ptypes, ctx)
        end
      end

      def seed_iteration_block_params(node : RubyObject, ctx : RubyObject)
        unless (node.block_node).truthy?
          return
        end
        ptypes = block_param_types(node.name, node.receiver_node, ctx)
        unless ptypes.empty?
          seed_block_params(node.block_node, ptypes, ctx)
        end
      end

      def try_infer_class_new(node : RubyObject, ctx : Ruby_TypeContext)
        unless (((node.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        if recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead)
          Ruby_Type.ruby_of(recv.name)
        else
          RUBY_NIL
        end
      end

      def try_infer_class_new(node : RubyObject, ctx : RubyObject)
        unless (((node.name == Ruby_Sym_25) ? RUBY_TRUE : RUBY_FALSE)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        if recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead)
          Ruby_Type.ruby_of(recv.name)
        else
          RUBY_NIL
        end
      end

      def try_infer_math_call(node : RubyObject, ctx : Ruby_TypeContext)
        recv = node.receiver_node
        unless ((_and173 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and173.truthy? ? (((recv.name == Ruby_Sym_45) ? RUBY_TRUE : RUBY_FALSE)) : _and173)).truthy?
          return RUBY_NIL
        end
        if (Ruby_MATH_FLOAT_METHODS.include?(node.name)).truthy?
          Ruby_Type::Ruby_F64
        else
          RUBY_NIL
        end
      end

      def try_infer_math_call(node : RubyObject, ctx : RubyObject)
        recv = node.receiver_node
        unless ((_and174 = recv.ruby_is_a?(Ruby_Ast::Ruby_ConstantRead); _and174.truthy? ? (((recv.name == Ruby_Sym_45) ? RUBY_TRUE : RUBY_FALSE)) : _and174)).truthy?
          return RUBY_NIL
        end
        if (Ruby_MATH_FLOAT_METHODS.include?(node.name)).truthy?
          Ruby_Type::Ruby_F64
        else
          RUBY_NIL
        end
      end

      def try_infer_subscript_read(node : RubyObject, ctx : Ruby_TypeContext)
        args = (_or175 = node.arg_nodes; _or175.truthy? ? _or175 : (RubyArray.new([] of RubyObject)))
        unless ((_and176 = ((node.name == Ruby_Sym_36) ? RUBY_TRUE : RUBY_FALSE); _and176.truthy? ? (((args.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and176)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        if recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)
          ae = @env.type_of(RubyArray.new([Ruby_Sym_31, ctx.as(Ruby_TypeContext).method_key, recv.name] of RubyObject))
          unless (ae.bottom?).truthy?
            return ae
          end
        end
        recv_ty = infer_expr(recv, ctx)
        if ((_and177 = recv_ty.array?; _and177.truthy? ? (recv_ty.elem) : _and177)).truthy?
          recv_ty.elem
        else
          RUBY_NIL
        end
      end

      def try_infer_subscript_read(node : RubyObject, ctx : RubyObject)
        args = (_or178 = node.arg_nodes; _or178.truthy? ? _or178 : (RubyArray.new([] of RubyObject)))
        unless ((_and179 = ((node.name == Ruby_Sym_36) ? RUBY_TRUE : RUBY_FALSE); _and179.truthy? ? (((args.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and179)).truthy?
          return RUBY_NIL
        end
        recv = node.receiver_node
        if recv.ruby_is_a?(Ruby_Ast::Ruby_LocalVariableRead)
          ae = @env.type_of(RubyArray.new([Ruby_Sym_31, ctx.method_key, recv.name] of RubyObject))
          unless (ae.bottom?).truthy?
            return ae
          end
        end
        recv_ty = infer_expr(recv, ctx)
        if ((_and180 = recv_ty.array?; _and180.truthy? ? (recv_ty.elem) : _and180)).truthy?
          recv_ty.elem
        else
          RUBY_NIL
        end
      end

      def try_infer_range_to_a(node : RubyObject, ctx : Ruby_TypeContext)
        unless ((_or181 = ((node.name == Ruby_Sym_46) ? RUBY_TRUE : RUBY_FALSE); _or181.truthy? ? _or181 : (((node.name == Ruby_Sym_47) ? RUBY_TRUE : RUBY_FALSE)))).truthy?
          return RUBY_NIL
        end
        unwrapped = node.receiver_node
        while ((_and182 = unwrapped.ruby_is_a?(Ruby_Ast::Ruby_Sequence); _and182.truthy? ? (((unwrapped.nodes.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and182)).truthy?
          unwrapped = unwrapped.nodes.first
        end
        unless unwrapped.ruby_is_a?(Ruby_Ast::Ruby_RangeLiteral)
          return RUBY_NIL
        end
        begin_ty = infer_expr(unwrapped.begin_node, ctx)
        if (begin_ty.raw?).truthy?
          Ruby_Type.array(elem: begin_ty)
        else
          Ruby_Type::Ruby_ARRAY
        end
      end

      def try_infer_range_to_a(node : RubyObject, ctx : RubyObject)
        unless ((_or183 = ((node.name == Ruby_Sym_46) ? RUBY_TRUE : RUBY_FALSE); _or183.truthy? ? _or183 : (((node.name == Ruby_Sym_47) ? RUBY_TRUE : RUBY_FALSE)))).truthy?
          return RUBY_NIL
        end
        unwrapped = node.receiver_node
        while ((_and184 = unwrapped.ruby_is_a?(Ruby_Ast::Ruby_Sequence); _and184.truthy? ? (((unwrapped.nodes.size == RubyInteger.new(1_i64)) ? RUBY_TRUE : RUBY_FALSE)) : _and184)).truthy?
          unwrapped = unwrapped.nodes.first
        end
        unless unwrapped.ruby_is_a?(Ruby_Ast::Ruby_RangeLiteral)
          return RUBY_NIL
        end
        begin_ty = infer_expr(unwrapped.begin_node, ctx)
        if (begin_ty.raw?).truthy?
          Ruby_Type.array(elem: begin_ty)
        else
          Ruby_Type::Ruby_ARRAY
        end
      end

      def try_infer_builtin_method(node : RubyObject, ctx : Ruby_TypeContext)
        recv = node.receiver_node
        unless (recv).truthy?
          return RUBY_NIL
        end
        name = node.name
        recv_ty = infer_expr(recv, ctx)
        if ((_and185 = Ruby_COERCE_TO_FLOAT.include?(name); _and185.truthy? ? ((((recv_ty.bottom?).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and185)).truthy?
          return Ruby_Type::Ruby_F64
        end
        if ((_and186 = Ruby_COERCE_TO_INT.include?(name); _and186.truthy? ? ((((recv_ty.bottom?).truthy?) ? RUBY_FALSE : RUBY_TRUE)) : _and186)).truthy?
          return Ruby_Type::Ruby_I64
        end
        if (recv_ty.class_type?).truthy?
          cn = recv_ty.class_name
          if ((_and187 = ((cn == Ruby_Sym_8) ? RUBY_TRUE : RUBY_FALSE); _and187.truthy? ? (Ruby_ARRAY_INT_METHODS.include?(name)) : _and187)).truthy?
            return Ruby_Type::Ruby_I64
          end
          if ((_and188 = ((cn == Ruby_Sym_5) ? RUBY_TRUE : RUBY_FALSE); _and188.truthy? ? (Ruby_INT_INT_METHODS.include?(name)) : _and188)).truthy?
            return Ruby_Type::Ruby_I64
          end
          if ((_and189 = ((cn == Ruby_Sym_6) ? RUBY_TRUE : RUBY_FALSE); _and189.truthy? ? (Ruby_FLOAT_FLOAT_METHODS.include?(name)) : _and189)).truthy?
            return Ruby_Type::Ruby_F64
          end
          if ((_and190 = ((cn == Ruby_Sym_6) ? RUBY_TRUE : RUBY_FALSE); _and190.truthy? ? (Ruby_FLOAT_INT_METHODS.include?(name)) : _and190)).truthy?
            return Ruby_Type::Ruby_I64
          end
          if ((_and191 = ((cn == Ruby_Sym_48) ? RUBY_TRUE : RUBY_FALSE); _and191.truthy? ? (RubyTuple3.new(Ruby_Sym_49, Ruby_Sym_50, Ruby_Sym_51).include?(name)) : _and191)).truthy?
            return Ruby_Type::Ruby_I64
          end
          if ((_and192 = ((cn == Ruby_Sym_52) ? RUBY_TRUE : RUBY_FALSE); _and192.truthy? ? (((name == Ruby_Sym_53) ? RUBY_TRUE : RUBY_FALSE)) : _and192)).truthy?
            return             if             (_or193 = node.arg_nodes; _or193.truthy? ? _or193 : (RubyArray.new([] of RubyObject))).empty?
              Ruby_Type::Ruby_F64
            else
              Ruby_Type::Ruby_I64
            end
          end
        end
        if ((_and194 = (_and195 = recv_ty.array?; _and195.truthy? ? (recv_ty.elem) : _and195); _and194.truthy? ? (RubyTuple5.new(Ruby_Sym_54, Ruby_Sym_55, Ruby_Sym_56, Ruby_Sym_57, Ruby_Sym_58).include?(name)) : _and194)).truthy?
          return recv_ty.elem
        end
        if ((_and196 = (((recv_ty.bottom?).truthy?) ? RUBY_FALSE : RUBY_TRUE); _and196.truthy? ? (        (_or197 = (_or198 = ((name == Ruby_Sym_59) ? RUBY_TRUE : RUBY_FALSE); _or198.truthy? ? _or198 : (((name == Ruby_Sym_60) ? RUBY_TRUE : RUBY_FALSE))); _or197.truthy? ? _or197 : (((name == Ruby_Sym_61) ? RUBY_TRUE : RUBY_FALSE)))) : _and196)).truthy?
          return recv_ty
        end
        RUBY_NIL
      end

      class Ruby_TypeEnv < RubyObject
                @ti : RubyObject = RUBY_NIL
                @typed_slots : RubyHash = RubyHash.new

                def to_s : String; "#<TypeEnv>"; end
        
        def initialize(ti : RubyObject)
          @typed_slots = RubyHash.new
          @ti = ti
        end

        def raw(slot : RubyObject)
          t = @typed_slots[slot]
          if (t).truthy?
            t.to_legacy
          else
            Ruby_Sym_11
          end
        end

        def typed?(slot : RubyObject)
          @typed_slots.key?(slot)
        end

        def [](slot : RubyObject)
          t = @typed_slots[slot]
          if (t).truthy?
            t.to_legacy
          else
            RUBY_NIL
          end
        end

        def slots
          @typed_slots.transform_values() { |_sym2proc| _sym2proc.to_legacy.as(RubyObject) }
        end

        def type_of(slot : RubyObject)
          @typed_slots.fetch(slot, Ruby_Type::Ruby_BOTTOM)
        end

        def type_at(slot : RubyObject)
          @typed_slots[slot]
        end

        def each_typed(&block)
          @typed_slots.each() { |_blkarg| (block).as(RubyProc).call(_blkarg) }
        end

        def join!(slot : RubyObject, loc_type : RubyObject)
          unless (loc_type).truthy?
            return RUBY_FALSE
          end
          unless (loc_type.is_a?(Ruby_Type) ? RUBY_TRUE : RUBY_FALSE)
            loc_type = Ruby_Type.from_legacy(loc_type)
          end
          if (loc_type.bottom?).truthy?
            return RUBY_FALSE
          end
          current = @typed_slots.fetch(slot, Ruby_Type::Ruby_BOTTOM)
          merged = @ti.join(current, loc_type)
          if (((merged == current) ? RUBY_TRUE : RUBY_FALSE)).truthy?
            return RUBY_FALSE
          end
          @typed_slots[slot] = merged
          RUBY_TRUE
        end

        def inspect : String
(begin
            RubyString.new(encoding: RubyEncoding::UTF_8).tap { |_s| _s.concat_raw_bytes!("#<TypeEnv "); _s.concat_raw_bytes!((            @typed_slots.size).to_s); _s.concat_raw_bytes!(" typed slots>") }
          end).to_s
        end

                  RESPOND_TO_TABLE = StaticArray[false]

                def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
          sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
          idx = sym.method_index
          (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
                end

      end
      class Ruby_TypeContext < RubyObject
        @method_key : RubyObject = RUBY_NIL
        @class_name : RubyObject = RUBY_NIL

        def to_s : String; "#<TypeContext>"; end
        def inspect : String; "#<TypeContext>"; end

        def initialize(@method_key : RubyObject = RUBY_NIL, @class_name : RubyObject = RUBY_NIL); end

        def method_key : RubyObject; @method_key; end
        def method_key=(v : RubyObject) : RubyObject; @method_key = v; v; end
        def class_name : RubyObject; @class_name; end
        def class_name=(v : RubyObject) : RubyObject; @class_name = v; v; end

                  RESPOND_TO_TABLE = StaticArray[false]

                def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
          sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
          idx = sym.method_index
          (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
                end

      end
    end
  end
end

t = Ruby_Frozone::Ruby_Compiler::Ruby_Type.new(Ruby_Sym_0)
STDOUT.puts(t.kind.ruby_to_s.to_s); RUBY_NIL
STDOUT.puts(t.i64?.ruby_to_s.to_s); RUBY_NIL
STDOUT.puts(t.numeric?.ruby_to_s.to_s); RUBY_NIL
t2 = Ruby_Frozone::Ruby_Compiler::Ruby_Type.new(Ruby_Sym_2)
STDOUT.puts(t2.f64?.ruby_to_s.to_s); RUBY_NIL
STDOUT.puts(t2.to_crystal.to_s); RUBY_NIL

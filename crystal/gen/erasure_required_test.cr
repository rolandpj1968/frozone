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

Ruby_Str_0 = RubyString.new("invalid").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_1 = RubyString.new("BUG: should have raised").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_2 = RubyString.new("Argument list too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_3 = RubyString.new("Permission denied").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_4 = RubyString.new("Address already in use").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_5 = RubyString.new("Cannot assign requested address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_6 = RubyString.new("Address family not supported by protocol").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_7 = RubyString.new("Resource temporarily unavailable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_8 = RubyString.new("Operation already in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_9 = RubyString.new("Bad file descriptor").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_10 = RubyString.new("Device or resource busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_11 = RubyString.new("No child processes").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_12 = RubyString.new("Invalid or incomplete multibyte or wide character").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_13 = RubyString.new("Software caused connection abort").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_14 = RubyString.new("Connection refused").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_15 = RubyString.new("Connection reset by peer").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_16 = RubyString.new("Resource deadlock avoided").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_17 = RubyString.new("Numerical argument out of domain").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_18 = RubyString.new("File exists").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_19 = RubyString.new("Bad address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_20 = RubyString.new("File too large").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_21 = RubyString.new("No route to host").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_22 = RubyString.new("Operation now in progress").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_23 = RubyString.new("Interrupted system call").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_24 = RubyString.new("Invalid argument").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_25 = RubyString.new("Input/output error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_26 = RubyString.new("Transport endpoint is already connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_27 = RubyString.new("Is a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_28 = RubyString.new("Too many levels of symbolic links").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_29 = RubyString.new("Too many open files").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_30 = RubyString.new("Message too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_31 = RubyString.new("File name too long").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_32 = RubyString.new("Network is down").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_33 = RubyString.new("Network is unreachable").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_34 = RubyString.new("Too many open files in system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_35 = RubyString.new("No such device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_36 = RubyString.new("No such file or directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_37 = RubyString.new("Exec format error").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_38 = RubyString.new("Cannot allocate memory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_39 = RubyString.new("No space left on device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_40 = RubyString.new("Function not implemented").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_41 = RubyString.new("Transport endpoint is not connected").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_42 = RubyString.new("Not a directory").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_43 = RubyString.new("Directory not empty").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_44 = RubyString.new("Operation not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_45 = RubyString.new("Inappropriate ioctl for device").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_46 = RubyString.new("No such device or address").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_47 = RubyString.new("Value too large for defined data type").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_48 = RubyString.new("Operation not permitted").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_49 = RubyString.new("Broken pipe").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_50 = RubyString.new("Protocol not supported").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_51 = RubyString.new("Numerical result out of range").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_52 = RubyString.new("Read-only file system").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_53 = RubyString.new("Illegal seek").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_54 = RubyString.new("No such process").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_55 = RubyString.new("Connection timed out").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_56 = RubyString.new("Text file busy").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_57 = RubyString.new("Invalid cross-device link").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_58 = RubyString.new("3.1.2").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_59 = RubyString.new("0").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_60 = RubyString.new("T").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_61 = RubyString.new("F").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_62 = RubyString.new("i").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_63 = RubyString.new("l").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_64 = RubyString.new("f").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_65 = RubyString.new("\"").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_66 = RubyString.new(":").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_67 = RubyString.new(";").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_68 = RubyString.new("[").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_69 = RubyString.new("{").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_70 = RubyString.new("}").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_71 = RubyString.new("o").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_72 = RubyString.new("S").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_73 = RubyString.new("c").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_74 = RubyString.new("m").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_75 = RubyString.new("I").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_76 = RubyString.new("@").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_77 = RubyString.new("C").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_78 = RubyString.new("u").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_79 = RubyString.new("U").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_80 = RubyString.new("e").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_81 = RubyString.new("/").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_82 = RubyString.new("d").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_83 = RubyString.new("ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_84 = RubyString.new("/home/rolandpj/.rbenv/versions/4.0.1/bin/ruby").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_85 = RubyString.new("4.0.1").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_86 = RubyString.new("x86_64-linux").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_87 = RubyString.new("2025-01-01").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_88 = RubyString.new("frozone 4.0.1 (x86_64-linux)").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_89 = RubyString.new("frozone - Copyright (C) 2024 frozone").tap { |_s| _s.freeze_known_ascii! }
Ruby_Str_90 = RubyString.new("1.1").tap { |_s| _s.freeze_known_ascii! }

# User-defined method stubs on RubyObject for polymorphic dispatch
class RubyObject
  def memoized_result(*args) : RubyObject
    raise Exception.new("undefined method 'memoized_result' for #{self.class}")
  end
  def expensive_compute(*args) : RubyObject
    raise Exception.new("undefined method 'expensive_compute' for #{self.class}")
  end
  def process(*args) : RubyObject
    raise Exception.new("undefined method 'process' for #{self.class}")
  end
  def __prepend_super_process_0(*args) : RubyObject
    raise Exception.new("undefined method '__prepend_super_process_0' for #{self.class}")
  end
end

# Pre-intern method-name symbols with compile-time indices for O(1) respond_to?
RubySymbol.from("!").method_index = 1
RubySymbol.from("!=").method_index = 2
RubySymbol.from("!~").method_index = 3
RubySymbol.from("%").method_index = 4
RubySymbol.from("&").method_index = 5
RubySymbol.from("*").method_index = 6
RubySymbol.from("**").method_index = 7
RubySymbol.from("+").method_index = 8
RubySymbol.from("+@").method_index = 9
RubySymbol.from("-").method_index = 10
RubySymbol.from("-@").method_index = 11
RubySymbol.from("/").method_index = 12
RubySymbol.from("<").method_index = 13
RubySymbol.from("<<").method_index = 14
RubySymbol.from("<=").method_index = 15
RubySymbol.from("<=>").method_index = 16
RubySymbol.from("==").method_index = 17
RubySymbol.from("===").method_index = 18
RubySymbol.from("=~").method_index = 19
RubySymbol.from(">").method_index = 20
RubySymbol.from(">=").method_index = 21
RubySymbol.from(">>").method_index = 22
RubySymbol.from("Array").method_index = 23
RubySymbol.from("Complex").method_index = 24
RubySymbol.from("Float").method_index = 25
RubySymbol.from("Hash").method_index = 26
RubySymbol.from("Integer").method_index = 27
RubySymbol.from("Rational").method_index = 28
RubySymbol.from("String").method_index = 29
RubySymbol.from("[]").method_index = 30
RubySymbol.from("[]=").method_index = 31
RubySymbol.from("^").method_index = 32
RubySymbol.from("__add_owned_mutex").method_index = 33
RubySymbol.from("__add_thread").method_index = 34
RubySymbol.from("__advance__").method_index = 35
RubySymbol.from("__array_rand_int__").method_index = 36
RubySymbol.from("__ascii_lower__").method_index = 37
RubySymbol.from("__ascii_upper__").method_index = 38
RubySymbol.from("__bang__").method_index = 39
RubySymbol.from("__bang_self__").method_index = 40
RubySymbol.from("__binomial_coeff__").method_index = 41
RubySymbol.from("__bitwise_op__").method_index = 42
RubySymbol.from("__bsearch_float__").method_index = 43
RubySymbol.from("__bsearch_int_any__").method_index = 44
RubySymbol.from("__bsearch_int_min__").method_index = 45
RubySymbol.from("__bsearch_integer__").method_index = 46
RubySymbol.from("__bsearch_size__").method_index = 47
RubySymbol.from("__bsearch_validate__").method_index = 48
RubySymbol.from("__bytes_ascii__?").method_index = 49
RubySymbol.from("__callee__").method_index = 50
RubySymbol.from("__check_frozen__").method_index = 51
RubySymbol.from("__check_zero_divisor__").method_index = 52
RubySymbol.from("__cmp__").method_index = 53
RubySymbol.from("__coerce_and_compare__").method_index = 54
RubySymbol.from("__coerce_binop__").method_index = 55
RubySymbol.from("__coerce_count__").method_index = 56
RubySymbol.from("__coerce_ivar_name__").method_index = 57
RubySymbol.from("__coerce_load_path__").method_index = 58
RubySymbol.from("__coerce_op__").method_index = 59
RubySymbol.from("__coerce_to_ary__").method_index = 60
RubySymbol.from("__coerce_to_hash__").method_index = 61
RubySymbol.from("__coerce_to_int__").method_index = 62
RubySymbol.from("__coerce_to_io__").method_index = 63
RubySymbol.from("__coerce_to_pair__").method_index = 64
RubySymbol.from("__coerce_to_path__").method_index = 65
RubySymbol.from("__coerce_to_str__").method_index = 66
RubySymbol.from("__coerce_var_key").method_index = 67
RubySymbol.from("__combination_r__").method_index = 68
RubySymbol.from("__compare__").method_index = 69
RubySymbol.from("__complex_coerce_op__").method_index = 70
RubySymbol.from("__cover_value__?").method_index = 71
RubySymbol.from("__default_cmp__").method_index = 72
RubySymbol.from("__dir__").method_index = 73
RubySymbol.from("__do_flatten__").method_index = 74
RubySymbol.from("__encoding_compat__").method_index = 75
RubySymbol.from("__ensure_fiber__").method_index = 76
RubySymbol.from("__ensure_real_strict__").method_index = 77
RubySymbol.from("__fiber_vars").method_index = 78
RubySymbol.from("__fill_range_bounds__").method_index = 79
RubySymbol.from("__flatten_into__").method_index = 80
RubySymbol.from("__float_to_ord__").method_index = 81
RubySymbol.from("__force_unlock").method_index = 82
RubySymbol.from("__format_imag__").method_index = 83
RubySymbol.from("__format_single_full_message__").method_index = 84
RubySymbol.from("__full_message_dm__").method_index = 85
RubySymbol.from("__id__").method_index = 86
RubySymbol.from("__init_main").method_index = 87
RubySymbol.from("__inspect_key__").method_index = 88
RubySymbol.from("__just_build_pad__").method_index = 89
RubySymbol.from("__just_coerce_args__").method_index = 90
RubySymbol.from("__kernel_exit__").method_index = 91
RubySymbol.from("__load_entries__").method_index = 92
RubySymbol.from("__map_ascii_bytes__").method_index = 93
RubySymbol.from("__merge__").method_index = 94
RubySymbol.from("__merge_sort__").method_index = 95
RubySymbol.from("__method__").method_index = 96
RubySymbol.from("__mutex_done_count").method_index = 97
RubySymbol.from("__mutex_done_count=").method_index = 98
RubySymbol.from("__mutex_seen_count").method_index = 99
RubySymbol.from("__mutex_seen_count=").method_index = 100
RubySymbol.from("__mutex_skip_count").method_index = 101
RubySymbol.from("__mutex_skip_count=").method_index = 102
RubySymbol.from("__next_values_raw__").method_index = 103
RubySymbol.from("__ord_to_float__").method_index = 104
RubySymbol.from("__param_sig__").method_index = 105
RubySymbol.from("__parse_reduce_args__").method_index = 106
RubySymbol.from("__parse_sep_limit__").method_index = 107
RubySymbol.from("__peek_values_raw__").method_index = 108
RubySymbol.from("__permutation_r__").method_index = 109
RubySymbol.from("__prepend_super_process_0").method_index = 110
RubySymbol.from("__puts_array__").method_index = 111
RubySymbol.from("__puts_scalar__").method_index = 112
RubySymbol.from("__raise_backtrace").method_index = 113
RubySymbol.from("__raise_backtrace=").method_index = 114
RubySymbol.from("__raise_cause").method_index = 115
RubySymbol.from("__raise_cause=").method_index = 116
RubySymbol.from("__raise_exception").method_index = 117
RubySymbol.from("__raise_exception=").method_index = 118
RubySymbol.from("__raise_zero_division__").method_index = 119
RubySymbol.from("__rational_coerce__").method_index = 120
RubySymbol.from("__reject_float_index__").method_index = 121
RubySymbol.from("__remove_owned_mutex").method_index = 122
RubySymbol.from("__remove_thread").method_index = 123
RubySymbol.from("__repeated_combination_r__").method_index = 124
RubySymbol.from("__repeated_permutation_r__").method_index = 125
RubySymbol.from("__require_integer__").method_index = 126
RubySymbol.from("__reverse_each_size__").method_index = 127
RubySymbol.from("__run_block").method_index = 128
RubySymbol.from("__send__").method_index = 129
RubySymbol.from("__set_group").method_index = 130
RubySymbol.from("__simplest_rational__").method_index = 131
RubySymbol.from("__slice_arith_seq__").method_index = 132
RubySymbol.from("__slice_int__").method_index = 133
RubySymbol.from("__slice_range__").method_index = 134
RubySymbol.from("__start_init").method_index = 135
RubySymbol.from("__step_each__").method_index = 136
RubySymbol.from("__step_enum__").method_index = 137
RubySymbol.from("__step_float__").method_index = 138
RubySymbol.from("__step_float_negative__").method_index = 139
RubySymbol.from("__step_float_positive__").method_index = 140
RubySymbol.from("__step_float_unbounded__").method_index = 141
RubySymbol.from("__step_integer__").method_index = 142
RubySymbol.from("__step_plus__").method_index = 143
RubySymbol.from("__step_size__").method_index = 144
RubySymbol.from("__step_succ__").method_index = 145
RubySymbol.from("__stop_seen").method_index = 146
RubySymbol.from("__stop_seen=").method_index = 147
RubySymbol.from("__str_args__").method_index = 148
RubySymbol.from("__succ_bytes_array__").method_index = 149
RubySymbol.from("__succ_carry_alnum__").method_index = 150
RubySymbol.from("__succ_carry_non_alnum__").method_index = 151
RubySymbol.from("__succ_find_leftmost_alnum__").method_index = 152
RubySymbol.from("__succ_find_rightmost_alnum__").method_index = 153
RubySymbol.from("__try_coerce_to_ary__").method_index = 154
RubySymbol.from("__try_coerce_to_hash__").method_index = 155
RubySymbol.from("__try_coerce_to_io__").method_index = 156
RubySymbol.from("__try_coerce_to_str__").method_index = 157
RubySymbol.from("__unpack_enum_args__").method_index = 158
RubySymbol.from("__wakeup_count").method_index = 159
RubySymbol.from("__wakeup_count=").method_index = 160
RubySymbol.from("__with_coercion__").method_index = 161
RubySymbol.from("_check_open").method_index = 162
RubySymbol.from("_check_readable").method_index = 163
RubySymbol.from("_check_writable").method_index = 164
RubySymbol.from("_chomp").method_index = 165
RubySymbol.from("_coerce_exact_number").method_index = 166
RubySymbol.from("_dump").method_index = 167
RubySymbol.from("_int_mode_to_str").method_index = 168
RubySymbol.from("_normalize_sep_limit").method_index = 169
RubySymbol.from("_puts_args").method_index = 170
RubySymbol.from("_unget_str").method_index = 171
RubySymbol.from("_write_str").method_index = 172
RubySymbol.from("`").method_index = 173
RubySymbol.from("abort").method_index = 174
RubySymbol.from("abort_on_exception").method_index = 175
RubySymbol.from("abort_on_exception=").method_index = 176
RubySymbol.from("abs").method_index = 177
RubySymbol.from("abs2").method_index = 178
RubySymbol.from("add").method_index = 179
RubySymbol.from("add?").method_index = 180
RubySymbol.from("add_trace_func").method_index = 181
RubySymbol.from("advise").method_index = 182
RubySymbol.from("alias_method").method_index = 183
RubySymbol.from("alive?").method_index = 184
RubySymbol.from("all?").method_index = 185
RubySymbol.from("allbits?").method_index = 186
RubySymbol.from("allocate").method_index = 187
RubySymbol.from("ancestors").method_index = 188
RubySymbol.from("angle").method_index = 189
RubySymbol.from("any?").method_index = 190
RubySymbol.from("anybits?").method_index = 191
RubySymbol.from("append").method_index = 192
RubySymbol.from("append_as_bytes").method_index = 193
RubySymbol.from("append_bytes").method_index = 194
RubySymbol.from("append_features").method_index = 195
RubySymbol.from("arg").method_index = 196
RubySymbol.from("args").method_index = 197
RubySymbol.from("arity").method_index = 198
RubySymbol.from("ascii_compatible?").method_index = 199
RubySymbol.from("ascii_only?").method_index = 200
RubySymbol.from("asctime").method_index = 201
RubySymbol.from("assoc").method_index = 202
RubySymbol.from("at").method_index = 203
RubySymbol.from("at_exit").method_index = 204
RubySymbol.from("atime").method_index = 205
RubySymbol.from("attached_object").method_index = 206
RubySymbol.from("attr").method_index = 207
RubySymbol.from("attr_accessor").method_index = 208
RubySymbol.from("attr_reader").method_index = 209
RubySymbol.from("attr_writer").method_index = 210
RubySymbol.from("autoclose=").method_index = 211
RubySymbol.from("autoclose?").method_index = 212
RubySymbol.from("autoload").method_index = 213
RubySymbol.from("autoload?").method_index = 214
RubySymbol.from("b").method_index = 215
RubySymbol.from("backtrace").method_index = 216
RubySymbol.from("backtrace_locations").method_index = 217
RubySymbol.from("begin").method_index = 218
RubySymbol.from("between?").method_index = 219
RubySymbol.from("bind").method_index = 220
RubySymbol.from("bind_call").method_index = 221
RubySymbol.from("binding").method_index = 222
RubySymbol.from("binmode").method_index = 223
RubySymbol.from("binmode?").method_index = 224
RubySymbol.from("birthtime").method_index = 225
RubySymbol.from("bit_length").method_index = 226
RubySymbol.from("block_given?").method_index = 227
RubySymbol.from("blocking?").method_index = 228
RubySymbol.from("broadcast").method_index = 229
RubySymbol.from("bsearch").method_index = 230
RubySymbol.from("bsearch_index").method_index = 231
RubySymbol.from("bytebegin").method_index = 232
RubySymbol.from("byteend").method_index = 233
RubySymbol.from("byteindex").method_index = 234
RubySymbol.from("byteoffset").method_index = 235
RubySymbol.from("byterindex").method_index = 236
RubySymbol.from("bytes").method_index = 237
RubySymbol.from("bytesize").method_index = 238
RubySymbol.from("byteslice").method_index = 239
RubySymbol.from("bytesplice").method_index = 240
RubySymbol.from("call").method_index = 241
RubySymbol.from("caller").method_index = 242
RubySymbol.from("caller_locations").method_index = 243
RubySymbol.from("capitalize").method_index = 244
RubySymbol.from("capitalize!").method_index = 245
RubySymbol.from("captures").method_index = 246
RubySymbol.from("casecmp").method_index = 247
RubySymbol.from("casecmp?").method_index = 248
RubySymbol.from("casefold?").method_index = 249
RubySymbol.from("catch").method_index = 250
RubySymbol.from("cause").method_index = 251
RubySymbol.from("ceil").method_index = 252
RubySymbol.from("ceildiv").method_index = 253
RubySymbol.from("center").method_index = 254
RubySymbol.from("chain").method_index = 255
RubySymbol.from("chars").method_index = 256
RubySymbol.from("chdir").method_index = 257
RubySymbol.from("children").method_index = 258
RubySymbol.from("chmod").method_index = 259
RubySymbol.from("chomp").method_index = 260
RubySymbol.from("chomp!").method_index = 261
RubySymbol.from("chop").method_index = 262
RubySymbol.from("chop!").method_index = 263
RubySymbol.from("chown").method_index = 264
RubySymbol.from("chr").method_index = 265
RubySymbol.from("chunk").method_index = 266
RubySymbol.from("chunk_while").method_index = 267
RubySymbol.from("clamp").method_index = 268
RubySymbol.from("class").method_index = 269
RubySymbol.from("class_eval").method_index = 270
RubySymbol.from("class_exec").method_index = 271
RubySymbol.from("class_variable_defined?").method_index = 272
RubySymbol.from("class_variable_get").method_index = 273
RubySymbol.from("class_variable_set").method_index = 274
RubySymbol.from("class_variables").method_index = 275
RubySymbol.from("classify").method_index = 276
RubySymbol.from("clear").method_index = 277
RubySymbol.from("clone").method_index = 278
RubySymbol.from("close").method_index = 279
RubySymbol.from("close_on_exec=").method_index = 280
RubySymbol.from("close_on_exec?").method_index = 281
RubySymbol.from("close_read").method_index = 282
RubySymbol.from("close_write").method_index = 283
RubySymbol.from("closed?").method_index = 284
RubySymbol.from("closed_read?").method_index = 285
RubySymbol.from("closed_write?").method_index = 286
RubySymbol.from("codepoints").method_index = 287
RubySymbol.from("coerce").method_index = 288
RubySymbol.from("collect").method_index = 289
RubySymbol.from("collect!").method_index = 290
RubySymbol.from("collect_concat").method_index = 291
RubySymbol.from("combination").method_index = 292
RubySymbol.from("compact").method_index = 293
RubySymbol.from("compact!").method_index = 294
RubySymbol.from("compare_by_identity").method_index = 295
RubySymbol.from("compare_by_identity?").method_index = 296
RubySymbol.from("concat").method_index = 297
RubySymbol.from("conj").method_index = 298
RubySymbol.from("conjugate").method_index = 299
RubySymbol.from("const_added").method_index = 300
RubySymbol.from("const_defined?").method_index = 301
RubySymbol.from("const_get").method_index = 302
RubySymbol.from("const_missing").method_index = 303
RubySymbol.from("const_set").method_index = 304
RubySymbol.from("const_source_location").method_index = 305
RubySymbol.from("constants").method_index = 306
RubySymbol.from("count").method_index = 307
RubySymbol.from("cover?").method_index = 308
RubySymbol.from("crypt").method_index = 309
RubySymbol.from("ctime").method_index = 310
RubySymbol.from("curry").method_index = 311
RubySymbol.from("cycle").method_index = 312
RubySymbol.from("day").method_index = 313
RubySymbol.from("deconstruct").method_index = 314
RubySymbol.from("deconstruct_keys").method_index = 315
RubySymbol.from("dedup").method_index = 316
RubySymbol.from("default").method_index = 317
RubySymbol.from("default=").method_index = 318
RubySymbol.from("default_proc").method_index = 319
RubySymbol.from("default_proc=").method_index = 320
RubySymbol.from("define_method").method_index = 321
RubySymbol.from("define_singleton_method").method_index = 322
RubySymbol.from("delete").method_index = 323
RubySymbol.from("delete!").method_index = 324
RubySymbol.from("delete?").method_index = 325
RubySymbol.from("delete_at").method_index = 326
RubySymbol.from("delete_if").method_index = 327
RubySymbol.from("delete_prefix").method_index = 328
RubySymbol.from("delete_prefix!").method_index = 329
RubySymbol.from("delete_suffix").method_index = 330
RubySymbol.from("delete_suffix!").method_index = 331
RubySymbol.from("denominator").method_index = 332
RubySymbol.from("deprecate_constant").method_index = 333
RubySymbol.from("deq").method_index = 334
RubySymbol.from("detailed_message").method_index = 335
RubySymbol.from("detect").method_index = 336
RubySymbol.from("difference").method_index = 337
RubySymbol.from("dig").method_index = 338
RubySymbol.from("digits").method_index = 339
RubySymbol.from("disjoint?").method_index = 340
RubySymbol.from("div").method_index = 341
RubySymbol.from("divide").method_index = 342
RubySymbol.from("divmod").method_index = 343
RubySymbol.from("downcase").method_index = 344
RubySymbol.from("downcase!").method_index = 345
RubySymbol.from("downto").method_index = 346
RubySymbol.from("drop").method_index = 347
RubySymbol.from("drop_while").method_index = 348
RubySymbol.from("dst?").method_index = 349
RubySymbol.from("dummy?").method_index = 350
RubySymbol.from("dump").method_index = 351
RubySymbol.from("dup").method_index = 352
RubySymbol.from("each").method_index = 353
RubySymbol.from("each_byte").method_index = 354
RubySymbol.from("each_char").method_index = 355
RubySymbol.from("each_child").method_index = 356
RubySymbol.from("each_codepoint").method_index = 357
RubySymbol.from("each_cons").method_index = 358
RubySymbol.from("each_entry").method_index = 359
RubySymbol.from("each_grapheme_cluster").method_index = 360
RubySymbol.from("each_index").method_index = 361
RubySymbol.from("each_key").method_index = 362
RubySymbol.from("each_line").method_index = 363
RubySymbol.from("each_pair").method_index = 364
RubySymbol.from("each_slice").method_index = 365
RubySymbol.from("each_value").method_index = 366
RubySymbol.from("each_with_index").method_index = 367
RubySymbol.from("each_with_object").method_index = 368
RubySymbol.from("empty?").method_index = 369
RubySymbol.from("enclose").method_index = 370
RubySymbol.from("enclosed?").method_index = 371
RubySymbol.from("encode").method_index = 372
RubySymbol.from("encode!").method_index = 373
RubySymbol.from("encoding").method_index = 374
RubySymbol.from("end").method_index = 375
RubySymbol.from("end_with?").method_index = 376
RubySymbol.from("enq").method_index = 377
RubySymbol.from("entries").method_index = 378
RubySymbol.from("enum_for").method_index = 379
RubySymbol.from("eof").method_index = 380
RubySymbol.from("eof?").method_index = 381
RubySymbol.from("eql?").method_index = 382
RubySymbol.from("equal?").method_index = 383
RubySymbol.from("errno").method_index = 384
RubySymbol.from("eval").method_index = 385
RubySymbol.from("even?").method_index = 386
RubySymbol.from("except").method_index = 387
RubySymbol.from("exception").method_index = 388
RubySymbol.from("exclude_end?").method_index = 389
RubySymbol.from("exec").method_index = 390
RubySymbol.from("exit").method_index = 391
RubySymbol.from("exit!").method_index = 392
RubySymbol.from("exit_value").method_index = 393
RubySymbol.from("expensive_compute").method_index = 394
RubySymbol.from("extend").method_index = 395
RubySymbol.from("extend_object").method_index = 396
RubySymbol.from("extended").method_index = 397
RubySymbol.from("external_encoding").method_index = 398
RubySymbol.from("fail").method_index = 399
RubySymbol.from("fcntl").method_index = 400
RubySymbol.from("fdiv").method_index = 401
RubySymbol.from("feed").method_index = 402
RubySymbol.from("fetch").method_index = 403
RubySymbol.from("fetch_values").method_index = 404
RubySymbol.from("fileno").method_index = 405
RubySymbol.from("fill").method_index = 406
RubySymbol.from("filter").method_index = 407
RubySymbol.from("filter!").method_index = 408
RubySymbol.from("filter_map").method_index = 409
RubySymbol.from("find").method_index = 410
RubySymbol.from("find_all").method_index = 411
RubySymbol.from("find_index").method_index = 412
RubySymbol.from("finite?").method_index = 413
RubySymbol.from("first").method_index = 414
RubySymbol.from("fixed_encoding?").method_index = 415
RubySymbol.from("flat_map").method_index = 416
RubySymbol.from("flatten").method_index = 417
RubySymbol.from("flatten!").method_index = 418
RubySymbol.from("flock").method_index = 419
RubySymbol.from("floor").method_index = 420
RubySymbol.from("flush").method_index = 421
RubySymbol.from("force_encoding").method_index = 422
RubySymbol.from("fork").method_index = 423
RubySymbol.from("format").method_index = 424
RubySymbol.from("freeze").method_index = 425
RubySymbol.from("friday?").method_index = 426
RubySymbol.from("frozen?").method_index = 427
RubySymbol.from("fsync").method_index = 428
RubySymbol.from("full_message").method_index = 429
RubySymbol.from("gcd").method_index = 430
RubySymbol.from("gcdlcm").method_index = 431
RubySymbol.from("getbyte").method_index = 432
RubySymbol.from("getc").method_index = 433
RubySymbol.from("getgm").method_index = 434
RubySymbol.from("getlocal").method_index = 435
RubySymbol.from("gets").method_index = 436
RubySymbol.from("getutc").method_index = 437
RubySymbol.from("global_variables").method_index = 438
RubySymbol.from("gmt?").method_index = 439
RubySymbol.from("gmt_offset").method_index = 440
RubySymbol.from("gmtime").method_index = 441
RubySymbol.from("gmtoff").method_index = 442
RubySymbol.from("grapheme_clusters").method_index = 443
RubySymbol.from("grep").method_index = 444
RubySymbol.from("grep_v").method_index = 445
RubySymbol.from("group").method_index = 446
RubySymbol.from("group_by").method_index = 447
RubySymbol.from("gsub").method_index = 448
RubySymbol.from("gsub!").method_index = 449
RubySymbol.from("has_key?").method_index = 450
RubySymbol.from("has_value?").method_index = 451
RubySymbol.from("hash").method_index = 452
RubySymbol.from("hex").method_index = 453
RubySymbol.from("hour").method_index = 454
RubySymbol.from("httpdate").method_index = 455
RubySymbol.from("i").method_index = 456
RubySymbol.from("id2name").method_index = 457
RubySymbol.from("imag").method_index = 458
RubySymbol.from("imaginary").method_index = 459
RubySymbol.from("import_methods").method_index = 460
RubySymbol.from("include").method_index = 461
RubySymbol.from("include?").method_index = 462
RubySymbol.from("included").method_index = 463
RubySymbol.from("included_modules").method_index = 464
RubySymbol.from("index").method_index = 465
RubySymbol.from("infinite?").method_index = 466
RubySymbol.from("inherited").method_index = 467
RubySymbol.from("initialize_clone").method_index = 468
RubySymbol.from("initialize_copy").method_index = 469
RubySymbol.from("initialize_dup").method_index = 470
RubySymbol.from("inject").method_index = 471
RubySymbol.from("insert").method_index = 472
RubySymbol.from("inspect").method_index = 473
RubySymbol.from("instance_eval").method_index = 474
RubySymbol.from("instance_exec").method_index = 475
RubySymbol.from("instance_method").method_index = 476
RubySymbol.from("instance_methods").method_index = 477
RubySymbol.from("instance_of?").method_index = 478
RubySymbol.from("instance_variable_defined?").method_index = 479
RubySymbol.from("instance_variable_get").method_index = 480
RubySymbol.from("instance_variable_set").method_index = 481
RubySymbol.from("instance_variables").method_index = 482
RubySymbol.from("integer?").method_index = 483
RubySymbol.from("intern").method_index = 484
RubySymbol.from("internal_encoding").method_index = 485
RubySymbol.from("intersect?").method_index = 486
RubySymbol.from("intersection").method_index = 487
RubySymbol.from("invert").method_index = 488
RubySymbol.from("ioctl").method_index = 489
RubySymbol.from("is_a?").method_index = 490
RubySymbol.from("isatty").method_index = 491
RubySymbol.from("isdst").method_index = 492
RubySymbol.from("iso8601").method_index = 493
RubySymbol.from("itself").method_index = 494
RubySymbol.from("join").method_index = 495
RubySymbol.from("keep_if").method_index = 496
RubySymbol.from("key").method_index = 497
RubySymbol.from("key?").method_index = 498
RubySymbol.from("keys").method_index = 499
RubySymbol.from("kill").method_index = 500
RubySymbol.from("kind_of?").method_index = 501
RubySymbol.from("lambda").method_index = 502
RubySymbol.from("lambda?").method_index = 503
RubySymbol.from("last").method_index = 504
RubySymbol.from("lazy").method_index = 505
RubySymbol.from("lcm").method_index = 506
RubySymbol.from("length").method_index = 507
RubySymbol.from("linear_time?").method_index = 508
RubySymbol.from("lineno").method_index = 509
RubySymbol.from("lineno=").method_index = 510
RubySymbol.from("lines").method_index = 511
RubySymbol.from("list").method_index = 512
RubySymbol.from("ljust").method_index = 513
RubySymbol.from("load").method_index = 514
RubySymbol.from("local_variable_defined?").method_index = 515
RubySymbol.from("local_variable_get").method_index = 516
RubySymbol.from("local_variable_set").method_index = 517
RubySymbol.from("local_variables").method_index = 518
RubySymbol.from("localtime").method_index = 519
RubySymbol.from("lock").method_index = 520
RubySymbol.from("locked?").method_index = 521
RubySymbol.from("loop").method_index = 522
RubySymbol.from("lstat").method_index = 523
RubySymbol.from("lstrip").method_index = 524
RubySymbol.from("lstrip!").method_index = 525
RubySymbol.from("magnitude").method_index = 526
RubySymbol.from("map").method_index = 527
RubySymbol.from("map!").method_index = 528
RubySymbol.from("marshal_dump").method_index = 529
RubySymbol.from("marshal_load").method_index = 530
RubySymbol.from("match").method_index = 531
RubySymbol.from("match?").method_index = 532
RubySymbol.from("match_length").method_index = 533
RubySymbol.from("max").method_index = 534
RubySymbol.from("max=").method_index = 535
RubySymbol.from("max_by").method_index = 536
RubySymbol.from("mday").method_index = 537
RubySymbol.from("member?").method_index = 538
RubySymbol.from("members").method_index = 539
RubySymbol.from("memoized_result").method_index = 540
RubySymbol.from("merge").method_index = 541
RubySymbol.from("merge!").method_index = 542
RubySymbol.from("message").method_index = 543
RubySymbol.from("method").method_index = 544
RubySymbol.from("method_added").method_index = 545
RubySymbol.from("method_defined?").method_index = 546
RubySymbol.from("method_missing").method_index = 547
RubySymbol.from("method_removed").method_index = 548
RubySymbol.from("method_undefined").method_index = 549
RubySymbol.from("methods").method_index = 550
RubySymbol.from("min").method_index = 551
RubySymbol.from("min_by").method_index = 552
RubySymbol.from("minmax").method_index = 553
RubySymbol.from("minmax_by").method_index = 554
RubySymbol.from("module_eval").method_index = 555
RubySymbol.from("module_exec").method_index = 556
RubySymbol.from("module_function").method_index = 557
RubySymbol.from("modulo").method_index = 558
RubySymbol.from("mon").method_index = 559
RubySymbol.from("monday?").method_index = 560
RubySymbol.from("month").method_index = 561
RubySymbol.from("mtime").method_index = 562
RubySymbol.from("name").method_index = 563
RubySymbol.from("name=").method_index = 564
RubySymbol.from("named_captures").method_index = 565
RubySymbol.from("names").method_index = 566
RubySymbol.from("nan?").method_index = 567
RubySymbol.from("native_thread_id").method_index = 568
RubySymbol.from("negative?").method_index = 569
RubySymbol.from("new").method_index = 570
RubySymbol.from("next").method_index = 571
RubySymbol.from("next!").method_index = 572
RubySymbol.from("next_bang").method_index = 573
RubySymbol.from("next_float").method_index = 574
RubySymbol.from("next_values").method_index = 575
RubySymbol.from("nil?").method_index = 576
RubySymbol.from("nobits?").method_index = 577
RubySymbol.from("none?").method_index = 578
RubySymbol.from("nonzero?").method_index = 579
RubySymbol.from("nsec").method_index = 580
RubySymbol.from("num_waiting").method_index = 581
RubySymbol.from("numerator").method_index = 582
RubySymbol.from("object_id").method_index = 583
RubySymbol.from("oct").method_index = 584
RubySymbol.from("odd?").method_index = 585
RubySymbol.from("offset").method_index = 586
RubySymbol.from("one?").method_index = 587
RubySymbol.from("open").method_index = 588
RubySymbol.from("options").method_index = 589
RubySymbol.from("ord").method_index = 590
RubySymbol.from("original_name").method_index = 591
RubySymbol.from("overlap?").method_index = 592
RubySymbol.from("owned?").method_index = 593
RubySymbol.from("owner").method_index = 594
RubySymbol.from("p").method_index = 595
RubySymbol.from("pack").method_index = 596
RubySymbol.from("parameters").method_index = 597
RubySymbol.from("partition").method_index = 598
RubySymbol.from("path").method_index = 599
RubySymbol.from("peek").method_index = 600
RubySymbol.from("peek_values").method_index = 601
RubySymbol.from("pending_interrupt?").method_index = 602
RubySymbol.from("permutation").method_index = 603
RubySymbol.from("phase").method_index = 604
RubySymbol.from("pid").method_index = 605
RubySymbol.from("polar").method_index = 606
RubySymbol.from("pop").method_index = 607
RubySymbol.from("pos").method_index = 608
RubySymbol.from("pos=").method_index = 609
RubySymbol.from("positive?").method_index = 610
RubySymbol.from("post_match").method_index = 611
RubySymbol.from("pow").method_index = 612
RubySymbol.from("pp").method_index = 613
RubySymbol.from("pre_match").method_index = 614
RubySymbol.from("pread").method_index = 615
RubySymbol.from("pred").method_index = 616
RubySymbol.from("prepend").method_index = 617
RubySymbol.from("prepend_features").method_index = 618
RubySymbol.from("prepended").method_index = 619
RubySymbol.from("pretty_inspect").method_index = 620
RubySymbol.from("pretty_print").method_index = 621
RubySymbol.from("pretty_print_cycle").method_index = 622
RubySymbol.from("prev_float").method_index = 623
RubySymbol.from("print").method_index = 624
RubySymbol.from("printf").method_index = 625
RubySymbol.from("priority").method_index = 626
RubySymbol.from("priority=").method_index = 627
RubySymbol.from("private").method_index = 628
RubySymbol.from("private_class_method").method_index = 629
RubySymbol.from("private_constant").method_index = 630
RubySymbol.from("private_instance_methods").method_index = 631
RubySymbol.from("private_method_defined?").method_index = 632
RubySymbol.from("private_methods").method_index = 633
RubySymbol.from("proc").method_index = 634
RubySymbol.from("process").method_index = 635
RubySymbol.from("product").method_index = 636
RubySymbol.from("proper_subset?").method_index = 637
RubySymbol.from("proper_superset?").method_index = 638
RubySymbol.from("protected").method_index = 639
RubySymbol.from("protected_instance_methods").method_index = 640
RubySymbol.from("protected_method_defined?").method_index = 641
RubySymbol.from("protected_methods").method_index = 642
RubySymbol.from("public").method_index = 643
RubySymbol.from("public_class_method").method_index = 644
RubySymbol.from("public_constant").method_index = 645
RubySymbol.from("public_instance_method").method_index = 646
RubySymbol.from("public_instance_methods").method_index = 647
RubySymbol.from("public_method").method_index = 648
RubySymbol.from("public_method_defined?").method_index = 649
RubySymbol.from("public_methods").method_index = 650
RubySymbol.from("public_send").method_index = 651
RubySymbol.from("push").method_index = 652
RubySymbol.from("putc").method_index = 653
RubySymbol.from("puts").method_index = 654
RubySymbol.from("pwrite").method_index = 655
RubySymbol.from("quo").method_index = 656
RubySymbol.from("raise").method_index = 657
RubySymbol.from("rand").method_index = 658
RubySymbol.from("random_number").method_index = 659
RubySymbol.from("rassoc").method_index = 660
RubySymbol.from("rationalize").method_index = 661
RubySymbol.from("read").method_index = 662
RubySymbol.from("read_nonblock").method_index = 663
RubySymbol.from("readable?").method_index = 664
RubySymbol.from("readable_real?").method_index = 665
RubySymbol.from("readbyte").method_index = 666
RubySymbol.from("readchar").method_index = 667
RubySymbol.from("readline").method_index = 668
RubySymbol.from("readlines").method_index = 669
RubySymbol.from("readpartial").method_index = 670
RubySymbol.from("real").method_index = 671
RubySymbol.from("real?").method_index = 672
RubySymbol.from("reason").method_index = 673
RubySymbol.from("receiver").method_index = 674
RubySymbol.from("rect").method_index = 675
RubySymbol.from("rectangular").method_index = 676
RubySymbol.from("reduce").method_index = 677
RubySymbol.from("refine").method_index = 678
RubySymbol.from("refinements").method_index = 679
RubySymbol.from("regexp").method_index = 680
RubySymbol.from("rehash").method_index = 681
RubySymbol.from("reject").method_index = 682
RubySymbol.from("reject!").method_index = 683
RubySymbol.from("remainder").method_index = 684
RubySymbol.from("remove_class_variable").method_index = 685
RubySymbol.from("remove_const").method_index = 686
RubySymbol.from("remove_instance_variable").method_index = 687
RubySymbol.from("remove_method").method_index = 688
RubySymbol.from("reopen").method_index = 689
RubySymbol.from("repeated_combination").method_index = 690
RubySymbol.from("repeated_permutation").method_index = 691
RubySymbol.from("replace").method_index = 692
RubySymbol.from("replicate").method_index = 693
RubySymbol.from("report_on_exception").method_index = 694
RubySymbol.from("report_on_exception=").method_index = 695
RubySymbol.from("require").method_index = 696
RubySymbol.from("require_relative").method_index = 697
RubySymbol.from("resolve_feature_path").method_index = 698
RubySymbol.from("respond_to?").method_index = 699
RubySymbol.from("respond_to_missing?").method_index = 700
RubySymbol.from("result").method_index = 701
RubySymbol.from("resume").method_index = 702
RubySymbol.from("reverse").method_index = 703
RubySymbol.from("reverse!").method_index = 704
RubySymbol.from("reverse_each").method_index = 705
RubySymbol.from("rewind").method_index = 706
RubySymbol.from("rfc2822").method_index = 707
RubySymbol.from("rfc822").method_index = 708
RubySymbol.from("rindex").method_index = 709
RubySymbol.from("rjust").method_index = 710
RubySymbol.from("rotate").method_index = 711
RubySymbol.from("rotate!").method_index = 712
RubySymbol.from("round").method_index = 713
RubySymbol.from("rpartition").method_index = 714
RubySymbol.from("rstrip").method_index = 715
RubySymbol.from("rstrip!").method_index = 716
RubySymbol.from("ruby2_keywords").method_index = 717
RubySymbol.from("run").method_index = 718
RubySymbol.from("sample").method_index = 719
RubySymbol.from("saturday?").method_index = 720
RubySymbol.from("scan").method_index = 721
RubySymbol.from("scrub").method_index = 722
RubySymbol.from("scrub!").method_index = 723
RubySymbol.from("sec").method_index = 724
RubySymbol.from("seed").method_index = 725
RubySymbol.from("seek").method_index = 726
RubySymbol.from("select").method_index = 727
RubySymbol.from("select!").method_index = 728
RubySymbol.from("send").method_index = 729
RubySymbol.from("set_backtrace").method_index = 730
RubySymbol.from("set_encoding").method_index = 731
RubySymbol.from("set_encoding_by_bom").method_index = 732
RubySymbol.from("set_temporary_name").method_index = 733
RubySymbol.from("set_trace_func").method_index = 734
RubySymbol.from("setbyte").method_index = 735
RubySymbol.from("shift").method_index = 736
RubySymbol.from("shuffle").method_index = 737
RubySymbol.from("shuffle!").method_index = 738
RubySymbol.from("signal").method_index = 739
RubySymbol.from("signm").method_index = 740
RubySymbol.from("signo").method_index = 741
RubySymbol.from("singleton_class").method_index = 742
RubySymbol.from("singleton_class?").method_index = 743
RubySymbol.from("singleton_method").method_index = 744
RubySymbol.from("singleton_method_added").method_index = 745
RubySymbol.from("singleton_method_removed").method_index = 746
RubySymbol.from("singleton_method_undefined").method_index = 747
RubySymbol.from("singleton_methods").method_index = 748
RubySymbol.from("size").method_index = 749
RubySymbol.from("sleep").method_index = 750
RubySymbol.from("slice").method_index = 751
RubySymbol.from("slice!").method_index = 752
RubySymbol.from("slice_after").method_index = 753
RubySymbol.from("slice_before").method_index = 754
RubySymbol.from("slice_when").method_index = 755
RubySymbol.from("sort").method_index = 756
RubySymbol.from("sort!").method_index = 757
RubySymbol.from("sort_by").method_index = 758
RubySymbol.from("sort_by!").method_index = 759
RubySymbol.from("source").method_index = 760
RubySymbol.from("source_location").method_index = 761
RubySymbol.from("spawn").method_index = 762
RubySymbol.from("split").method_index = 763
RubySymbol.from("sprintf").method_index = 764
RubySymbol.from("squeeze").method_index = 765
RubySymbol.from("squeeze!").method_index = 766
RubySymbol.from("srand").method_index = 767
RubySymbol.from("start_with?").method_index = 768
RubySymbol.from("stat").method_index = 769
RubySymbol.from("state").method_index = 770
RubySymbol.from("status").method_index = 771
RubySymbol.from("step").method_index = 772
RubySymbol.from("stop?").method_index = 773
RubySymbol.from("storage").method_index = 774
RubySymbol.from("storage=").method_index = 775
RubySymbol.from("store").method_index = 776
RubySymbol.from("strftime").method_index = 777
RubySymbol.from("string").method_index = 778
RubySymbol.from("string=").method_index = 779
RubySymbol.from("strip").method_index = 780
RubySymbol.from("strip!").method_index = 781
RubySymbol.from("sub").method_index = 782
RubySymbol.from("sub!").method_index = 783
RubySymbol.from("subclasses").method_index = 784
RubySymbol.from("subsec").method_index = 785
RubySymbol.from("subset?").method_index = 786
RubySymbol.from("subtract").method_index = 787
RubySymbol.from("succ").method_index = 788
RubySymbol.from("succ!").method_index = 789
RubySymbol.from("succ_bang").method_index = 790
RubySymbol.from("success?").method_index = 791
RubySymbol.from("sum").method_index = 792
RubySymbol.from("sunday?").method_index = 793
RubySymbol.from("super_method").method_index = 794
RubySymbol.from("superclass").method_index = 795
RubySymbol.from("superset?").method_index = 796
RubySymbol.from("suppress_keyword_warning").method_index = 797
RubySymbol.from("suppress_warning").method_index = 798
RubySymbol.from("swapcase").method_index = 799
RubySymbol.from("swapcase!").method_index = 800
RubySymbol.from("sync").method_index = 801
RubySymbol.from("sync=").method_index = 802
RubySymbol.from("synchronize").method_index = 803
RubySymbol.from("syscall").method_index = 804
RubySymbol.from("sysread").method_index = 805
RubySymbol.from("sysseek").method_index = 806
RubySymbol.from("system").method_index = 807
RubySymbol.from("syswrite").method_index = 808
RubySymbol.from("tag").method_index = 809
RubySymbol.from("take").method_index = 810
RubySymbol.from("take_while").method_index = 811
RubySymbol.from("tally").method_index = 812
RubySymbol.from("tap").method_index = 813
RubySymbol.from("target").method_index = 814
RubySymbol.from("tell").method_index = 815
RubySymbol.from("terminate").method_index = 816
RubySymbol.from("test").method_index = 817
RubySymbol.from("then").method_index = 818
RubySymbol.from("thread_variable?").method_index = 819
RubySymbol.from("thread_variable_get").method_index = 820
RubySymbol.from("thread_variable_set").method_index = 821
RubySymbol.from("thread_variables").method_index = 822
RubySymbol.from("throw").method_index = 823
RubySymbol.from("thursday?").method_index = 824
RubySymbol.from("times").method_index = 825
RubySymbol.from("to_a").method_index = 826
RubySymbol.from("to_ary").method_index = 827
RubySymbol.from("to_c").method_index = 828
RubySymbol.from("to_enum").method_index = 829
RubySymbol.from("to_f").method_index = 830
RubySymbol.from("to_h").method_index = 831
RubySymbol.from("to_hash").method_index = 832
RubySymbol.from("to_i").method_index = 833
RubySymbol.from("to_int").method_index = 834
RubySymbol.from("to_io").method_index = 835
RubySymbol.from("to_path").method_index = 836
RubySymbol.from("to_proc").method_index = 837
RubySymbol.from("to_r").method_index = 838
RubySymbol.from("to_s").method_index = 839
RubySymbol.from("to_set").method_index = 840
RubySymbol.from("to_str").method_index = 841
RubySymbol.from("to_sym").method_index = 842
RubySymbol.from("to_time").method_index = 843
RubySymbol.from("tr").method_index = 844
RubySymbol.from("tr!").method_index = 845
RubySymbol.from("tr_s").method_index = 846
RubySymbol.from("tr_s!").method_index = 847
RubySymbol.from("trace_var").method_index = 848
RubySymbol.from("transfer").method_index = 849
RubySymbol.from("transform_keys").method_index = 850
RubySymbol.from("transform_keys!").method_index = 851
RubySymbol.from("transform_values").method_index = 852
RubySymbol.from("transform_values!").method_index = 853
RubySymbol.from("transpose").method_index = 854
RubySymbol.from("trap").method_index = 855
RubySymbol.from("truncate").method_index = 856
RubySymbol.from("try_lock").method_index = 857
RubySymbol.from("tty?").method_index = 858
RubySymbol.from("tuesday?").method_index = 859
RubySymbol.from("tv_nsec").method_index = 860
RubySymbol.from("tv_sec").method_index = 861
RubySymbol.from("tv_usec").method_index = 862
RubySymbol.from("unbind").method_index = 863
RubySymbol.from("undef_method").method_index = 864
RubySymbol.from("undefined_instance_methods").method_index = 865
RubySymbol.from("undump").method_index = 866
RubySymbol.from("ungetbyte").method_index = 867
RubySymbol.from("ungetc").method_index = 868
RubySymbol.from("unicode_normalize").method_index = 869
RubySymbol.from("unicode_normalize!").method_index = 870
RubySymbol.from("unicode_normalized?").method_index = 871
RubySymbol.from("union").method_index = 872
RubySymbol.from("uniq").method_index = 873
RubySymbol.from("uniq!").method_index = 874
RubySymbol.from("unlock").method_index = 875
RubySymbol.from("unpack").method_index = 876
RubySymbol.from("unpack1").method_index = 877
RubySymbol.from("unshift").method_index = 878
RubySymbol.from("untrace_var").method_index = 879
RubySymbol.from("upcase").method_index = 880
RubySymbol.from("upcase!").method_index = 881
RubySymbol.from("update").method_index = 882
RubySymbol.from("upto").method_index = 883
RubySymbol.from("usec").method_index = 884
RubySymbol.from("using").method_index = 885
RubySymbol.from("utc").method_index = 886
RubySymbol.from("utc?").method_index = 887
RubySymbol.from("utc_offset").method_index = 888
RubySymbol.from("valid_encoding?").method_index = 889
RubySymbol.from("value").method_index = 890
RubySymbol.from("value?").method_index = 891
RubySymbol.from("values").method_index = 892
RubySymbol.from("values_at").method_index = 893
RubySymbol.from("wait").method_index = 894
RubySymbol.from("wakeup").method_index = 895
RubySymbol.from("warn").method_index = 896
RubySymbol.from("warn_ancestors").method_index = 897
RubySymbol.from("wday").method_index = 898
RubySymbol.from("wednesday?").method_index = 899
RubySymbol.from("with").method_index = 900
RubySymbol.from("with_index").method_index = 901
RubySymbol.from("with_object").method_index = 902
RubySymbol.from("writable?").method_index = 903
RubySymbol.from("writable_real?").method_index = 904
RubySymbol.from("write").method_index = 905
RubySymbol.from("write_nonblock").method_index = 906
RubySymbol.from("xmlschema").method_index = 907
RubySymbol.from("yday").method_index = 908
RubySymbol.from("year").method_index = 909
RubySymbol.from("yield").method_index = 910
RubySymbol.from("yield_self").method_index = 911
RubySymbol.from("zero?").method_index = 912
RubySymbol.from("zip").method_index = 913
RubySymbol.from("zone").method_index = 914
RubySymbol.from("|").method_index = 915
RubySymbol.from("~").method_index = 916

module Ruby_Defaults
    def to_s : String; "#<Defaults>"; end
    def inspect : String; "#<Defaults>"; end
  Ruby_TIMEOUT = RubyInteger.new(30_i64)
  Ruby_MAX_RETRIES = RubyInteger.new(3_i64)

end
class Ruby_BaseClient < RubyObject
    def to_s : String; "#<BaseClient>"; end
    def inspect : String; "#<BaseClient>"; end
  Ruby_TIMEOUT = RubyInteger.new(30_i64)
  Ruby_MAX_RETRIES = RubyInteger.new(3_i64)

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
class Ruby_HttpClient < ::Ruby_BaseClient
    def to_s : String; "#<HttpClient>"; end
    def inspect : String; "#<HttpClient>"; end

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
module Ruby_Protocols
    def to_s : String; "#<Protocols>"; end
    def inspect : String; "#<Protocols>"; end
  Ruby_VERSION = Ruby_Str_90

end
module Ruby_Networking
    def to_s : String; "#<Networking>"; end
    def inspect : String; "#<Networking>"; end

end
class Ruby_Server < RubyObject
    def to_s : String; "#<Server>"; end
    def inspect : String; "#<Server>"; end
  Ruby_VERSION = Ruby_Str_90

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
class Ruby_WebServer < ::Ruby_Server
    def to_s : String; "#<WebServer>"; end
    def inspect : String; "#<WebServer>"; end

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
module Ruby_Memoizable
    @_memo : RubyObject = RUBY_NIL

    def to_s : String; "#<Memoizable>"; end
    def inspect : String; "#<Memoizable>"; end

  def memoized_result
    (_or0 = @_memo; _or0.truthy? ? _or0 : (@_memo = expensive_compute))
  end

end
class Ruby_Calculator < RubyObject
    @_memo : RubyObject = RUBY_NIL

    def to_s : String; "#<Calculator>"; end
    def inspect : String; "#<Calculator>"; end

  def expensive_compute
    RubyInteger.new(6_i64 * 7_i64)
  end

  def memoized_result
    (_or1 = @_memo; _or1.truthy? ? _or1 : (@_memo = expensive_compute))
  end

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, true, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end
module Ruby_Validation
    def to_s : String; "#<Validation>"; end
    def inspect : String; "#<Validation>"; end

  def process(x : RubyObject)
    if (((x < RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
      raise RuntimeError.new("invalid")
    end
    super
  end

end
class Ruby_Processor < RubyObject
    def to_s : String; "#<Processor>"; end
    def inspect : String; "#<Processor>"; end

  def process(x : Int64)
    if (x < 0_i64)
      raise RuntimeError.new("invalid")
    end
    __prepend_super_process_0(x)
  end

  def process(x : RubyObject)
    if (((x < RubyInteger.new(0_i64)) ? RUBY_TRUE : RUBY_FALSE)).truthy?
      raise RuntimeError.new("invalid")
    end
    __prepend_super_process_0(x)
  end

  def __prepend_super_process_0(x : RubyObject)
    (x * RubyInteger.new(2_i64))
  end

      RESPOND_TO_TABLE = StaticArray[false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, true, false, true, false, false, false, false, true, true, true, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, true, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, true, false, false, true, true, true, false, false, true, true, true, true, true, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, true, false, false, false, false, false, false, true, false, false, false, false, false, true, false, true, true, false, true, true, false, false, true, true, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, true, false, false, false, false, false, false, false, true, false, true, true, true, true, true, false, true, false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, true, false, false, false, true, true, false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false]

    def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool
    sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)
    idx = sym.method_index
    (idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE
    end

end

STDOUT.puts(Ruby_HttpClient::Ruby_TIMEOUT.to_s); RUBY_NIL
STDOUT.puts(Ruby_HttpClient::Ruby_MAX_RETRIES.to_s); RUBY_NIL
STDOUT.puts(Ruby_WebServer::Ruby_VERSION.to_s); RUBY_NIL
c : Ruby_Calculator = Ruby_Calculator.new
STDOUT.puts(c.as(Ruby_Calculator).memoized_result.to_s); RUBY_NIL
STDOUT.puts(c.as(Ruby_Calculator).memoized_result.to_s); RUBY_NIL
STDOUT.puts(Ruby_Processor.new.process(RubyInteger.new(5_i64)).to_s); RUBY_NIL
begin
  Ruby_Processor.new.process(RubyInteger.new(-1_i64))
  STDOUT.puts(Ruby_Str_1.to_s); RUBY_NIL
rescue e : Exception
  STDOUT.puts(e.message.to_s); RUBY_NIL
end

#include "../runtime/frozone.hpp"


struct Ruby_Type {
  struct Impl {
    RubySymbol iv_kind;
    int64_t iv_class_name = 0;
    int64_t iv_nullable = 0;
    int64_t iv_exact = 0;
    int64_t iv_elem = 0;
    int64_t iv_key = 0;
    int64_t iv_val = 0;
    int64_t iv_int_min = 0;
    int64_t iv_int_max = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_Type() = default;
  Ruby_Type(const RubyNil&) {}
  Ruby_Type(auto kind, int64_t class_name = RUBY_NIL, bool nullable = false, bool exact = false, int64_t elem = RUBY_NIL, int64_t key = RUBY_NIL, int64_t val = RUBY_NIL, int64_t int_min = RUBY_NIL, int64_t int_max = RUBY_NIL) : p(std::make_shared<Impl>()) {
    p->iv_kind = kind;
    p->iv_class_name = class_name;
    p->iv_nullable = nullable;
    p->iv_exact = exact;
    p->iv_elem = elem;
    p->iv_key = key;
    p->iv_val = val;
    p->iv_int_min = int_min;
    p->iv_int_max = int_max;
    0LL;
  }

  auto kind() {
    return p->iv_kind;
  }

  auto class_name() {
    return p->iv_class_name;
  }

  auto elem() {
    return p->iv_elem;
  }

  auto key() {
    return p->iv_key;
  }

  auto val() {
    return p->iv_val;
  }

  auto int_min() {
    return p->iv_int_min;
  }

  auto int_max() {
    return p->iv_int_max;
  }

  auto int_bounds() {
    if (!(({ auto _l = (({ auto _l = ((p->iv_kind == ruby_sym("i64"))); (_l) ? decltype((p->iv_int_min))(p->iv_int_min) : decltype((p->iv_int_min))(_l); })); (_l) ? decltype((p->iv_int_max))(p->iv_int_max) : decltype((p->iv_int_max))(_l); }))) {
      return RubyArray<int64_t>(RUBY_NIL);
    }
    return ({ auto _e0 = p->iv_int_min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = p->iv_int_max; _a; });
  }

  auto narrowest_int_type() {
    std::decay_t<decltype(int_bounds())> b{};
    if (!((b = int_bounds()))) {
      return RubyString(RUBY_NIL);
    }
    auto _masgn1 = b;
    auto min = _masgn1[INT64_C(0)];
    auto max = _masgn1[INT64_C(1)];
    if ((min >= INT64_C(0))) {
      if ((max <= INT64_C(255))) {
      return RubyString("UInt8", 5);
    };
      if ((max <= INT64_C(65535))) {
      return RubyString("UInt16", 6);
    };
      if ((max <= INT64_C(4294967295))) {
      return RubyString("UInt32", 6);
    };
      return RubyString("UInt64", 6);
    }
    if (({ auto _l = ((min >= INT64_C(-128))); (_l) ? decltype(((max <= INT64_C(127))))((max <= INT64_C(127))) : decltype(((max <= INT64_C(127))))(_l); })) {
      return RubyString("Int8", 4);
    }
    if (({ auto _l = ((min >= INT64_C(-32768))); (_l) ? decltype(((max <= INT64_C(32767))))((max <= INT64_C(32767))) : decltype(((max <= INT64_C(32767))))(_l); })) {
      return RubyString("Int16", 5);
    }
    if (({ auto _l = ((min >= INT64_C(-2147483648))); (_l) ? decltype(((max <= INT64_C(2147483647))))((max <= INT64_C(2147483647))) : decltype(((max <= INT64_C(2147483647))))(_l); })) {
      return RubyString("Int32", 5);
    }
    return RubyString("Int64", 5);
  }

  auto bottom_q() {
    return (p->iv_kind == ruby_sym("bottom"));
  }

  auto i64_q() {
    return (p->iv_kind == ruby_sym("i64"));
  }

  auto f64_q() {
    return (p->iv_kind == ruby_sym("f64"));
  }

  auto raw_q() {
    return ({ auto _l = ((p->iv_kind == ruby_sym("i64"))); (_l) ? decltype(((p->iv_kind == ruby_sym("f64"))))(_l) : ((p->iv_kind == ruby_sym("f64"))); });
  }

  auto array_scalar_q() {
    return (p->iv_kind == ruby_sym("array_scalar"));
  }

  auto class_type_q() {
    return (p->iv_kind == ruby_sym("class_type"));
  }

  auto nullable_q() {
    return p->iv_nullable;
  }

  auto exact_q() {
    return p->iv_exact;
  }

  auto numeric_q() {
    return ({ auto _l = (raw_q()); (_l) ? decltype((({ auto _l = (class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)))(_l); })))(_l) : (({ auto _l = (class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(p->iv_class_name)))(_l); })); });
  }

  auto array_q() {
    return ({ auto _l = (class_type_q()); (_l) ? decltype(((p->iv_class_name == ruby_sym("Array"))))((p->iv_class_name == ruby_sym("Array"))) : decltype(((p->iv_class_name == ruby_sym("Array"))))(_l); });
  }

  auto array_like_q() {
    return ({ auto _l = (array_scalar_q()); (_l) ? decltype((array_q()))(_l) : (array_q()); });
  }

  auto hash_type_q() {
    return ({ auto _l = (class_type_q()); (_l) ? decltype(((p->iv_class_name == ruby_sym("Hash"))))((p->iv_class_name == ruby_sym("Hash"))) : decltype(((p->iv_class_name == ruby_sym("Hash"))))(_l); });
  }

  auto nil_type_q() {
    return ({ auto _l = (class_type_q()); (_l) ? decltype(((p->iv_class_name == ruby_sym("NilClass"))))((p->iv_class_name == ruby_sym("NilClass"))) : decltype(((p->iv_class_name == ruby_sym("NilClass"))))(_l); });
  }

  auto operator==(auto other) {
    if (!(true)) {
      return false;
    }
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = ((p->iv_kind == other.kind())); (_l) ? decltype(((p->iv_class_name == other.class_name())))((p->iv_class_name == other.class_name())) : decltype(((p->iv_class_name == other.class_name())))(_l); })); (_l) ? decltype(((p->iv_nullable == other.nullable_q())))((p->iv_nullable == other.nullable_q())) : decltype(((p->iv_nullable == other.nullable_q())))(_l); })); (_l) ? decltype(((p->iv_exact == other.exact_q())))((p->iv_exact == other.exact_q())) : decltype(((p->iv_exact == other.exact_q())))(_l); })); (_l) ? decltype(((p->iv_elem == other.elem())))((p->iv_elem == other.elem())) : decltype(((p->iv_elem == other.elem())))(_l); })); (_l) ? decltype(((p->iv_key == other.key())))((p->iv_key == other.key())) : decltype(((p->iv_key == other.key())))(_l); })); (_l) ? decltype(((p->iv_val == other.val())))((p->iv_val == other.val())) : decltype(((p->iv_val == other.val())))(_l); })); (_l) ? decltype(((p->iv_int_min == other.int_min())))((p->iv_int_min == other.int_min())) : decltype(((p->iv_int_min == other.int_min())))(_l); })); (_l) ? decltype(((p->iv_int_max == other.int_max())))((p->iv_int_max == other.int_max())) : decltype(((p->iv_int_max == other.int_max())))(_l); });
  }

  auto eql_q(auto other) {
    if (!(true)) {
      return false;
    }
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = ((p->iv_kind == other.kind())); (_l) ? decltype(((p->iv_class_name == other.class_name())))((p->iv_class_name == other.class_name())) : decltype(((p->iv_class_name == other.class_name())))(_l); })); (_l) ? decltype(((p->iv_nullable == other.nullable_q())))((p->iv_nullable == other.nullable_q())) : decltype(((p->iv_nullable == other.nullable_q())))(_l); })); (_l) ? decltype(((p->iv_exact == other.exact_q())))((p->iv_exact == other.exact_q())) : decltype(((p->iv_exact == other.exact_q())))(_l); })); (_l) ? decltype(((p->iv_elem == other.elem())))((p->iv_elem == other.elem())) : decltype(((p->iv_elem == other.elem())))(_l); })); (_l) ? decltype(((p->iv_key == other.key())))((p->iv_key == other.key())) : decltype(((p->iv_key == other.key())))(_l); })); (_l) ? decltype(((p->iv_val == other.val())))((p->iv_val == other.val())) : decltype(((p->iv_val == other.val())))(_l); })); (_l) ? decltype(((p->iv_int_min == other.int_min())))((p->iv_int_min == other.int_min())) : decltype(((p->iv_int_min == other.int_min())))(_l); })); (_l) ? decltype(((p->iv_int_max == other.int_max())))((p->iv_int_max == other.int_max())) : decltype(((p->iv_int_max == other.int_max())))(_l); });
  }

  auto hash() {
    return ({ auto _e0 = p->iv_kind; auto _a = RubyArray<decltype(_e0)>(9); _a[0] = _e0; _a[1] = p->iv_class_name; _a[2] = p->iv_nullable; _a[3] = p->iv_exact; _a[4] = p->iv_elem; _a[5] = p->iv_key; _a[6] = p->iv_val; _a[7] = p->iv_int_min; _a[8] = p->iv_int_max; _a; }).hash();
  }

  auto inspect() {
    RubyArray<RubyString> parts;
    if ((p->iv_kind == ruby_sym("bottom"))) {
      return RubyString("Type::BOTTOM", 12);
    } else if ((p->iv_kind == ruby_sym("i64"))) {
      return RubyString("Type::I64", 9);
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return RubyString("Type::F64", 9);
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      return (RubyString("Type::", 6) + ruby_to_s((p->iv_elem.i64_q() ? (RubyString("ARRAY_I64", 9)) : (RubyString("ARRAY_F64", 9)))));
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return (parts = ({ auto _e0 = (RubyString("Type.of(:", 9) + ruby_to_s(p->iv_class_name)); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; })); if (p->iv_nullable) {
        (parts << RubyString("nullable: true", 14));
      }; if (p->iv_exact) {
        (parts << RubyString("exact: true", 11));
      }; if (p->iv_elem) {
        (parts << (RubyString("elem: ", 6) + ruby_to_s(p->iv_elem.inspect())));
      }; if (p->iv_key) {
        (parts << (RubyString("key: ", 5) + ruby_to_s(p->iv_key.inspect())));
      }; if (p->iv_val) {
        (parts << (RubyString("val: ", 5) + ruby_to_s(p->iv_val.inspect())));
      }; (parts.join(RubyString(", ", 2)) + RubyString(")", 1));
    } else {
      return (RubyString("Type(", 5) + ruby_to_s(p->iv_kind) + RubyString(")", 1));
    }
  }

  auto to_s() {
    RubyArray<RubyString> parts;
    if ((p->iv_kind == ruby_sym("bottom"))) {
      return RubyString("Type::BOTTOM", 12);
    } else if ((p->iv_kind == ruby_sym("i64"))) {
      return RubyString("Type::I64", 9);
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return RubyString("Type::F64", 9);
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      return (RubyString("Type::", 6) + ruby_to_s((p->iv_elem.i64_q() ? (RubyString("ARRAY_I64", 9)) : (RubyString("ARRAY_F64", 9)))));
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return (parts = ({ auto _e0 = (RubyString("Type.of(:", 9) + ruby_to_s(p->iv_class_name)); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; })); if (p->iv_nullable) {
        (parts << RubyString("nullable: true", 14));
      }; if (p->iv_exact) {
        (parts << RubyString("exact: true", 11));
      }; if (p->iv_elem) {
        (parts << (RubyString("elem: ", 6) + ruby_to_s(p->iv_elem.inspect())));
      }; if (p->iv_key) {
        (parts << (RubyString("key: ", 5) + ruby_to_s(p->iv_key.inspect())));
      }; if (p->iv_val) {
        (parts << (RubyString("val: ", 5) + ruby_to_s(p->iv_val.inspect())));
      }; (parts.join(RubyString(", ", 2)) + RubyString(")", 1));
    } else {
      return (RubyString("Type(", 5) + ruby_to_s(p->iv_kind) + RubyString(")", 1));
    }
  }

  auto to_crystal() {
    if ((p->iv_kind == ruby_sym("i64"))) {
      return RubyString("Int64", 5);
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return RubyString("Float64", 7);
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      return (RubyString("Array(", 6) + ruby_to_s(p->iv_elem.to_crystal_storage()) + RubyString(")", 1));
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return class_to_crystal();
    } else {
      return RubyString("RubyObject", 10);
    }
  }

  auto to_crystal_storage() {
    if ((p->iv_kind == ruby_sym("i64"))) {
      return ({ auto _l = (narrowest_int_type()); (_l) ? decltype((RubyString("Int64", 5)))(_l) : (RubyString("Int64", 5)); });
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return RubyString("Float64", 7);
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      return (RubyString("Array(", 6) + ruby_to_s(p->iv_elem.to_crystal_storage()) + RubyString(")", 1));
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      if (({ auto _l = (array_q()); (_l) ? decltype((p->iv_elem.native_q()))(p->iv_elem.native_q()) : decltype((p->iv_elem.native_q()))(_l); })) {
        return (RubyString("Array(", 6) + ruby_to_s(p->iv_elem.to_crystal_storage()) + RubyString(")", 1));
      } else {
        return class_to_crystal();
      }
    } else {
      return RubyString("RubyObject", 10);
    }
  }

  auto native_q() {
    return ({ auto _l = (({ auto _l = (raw_q()); (_l) ? decltype((array_scalar_q()))(_l) : (array_scalar_q()); })); (_l) ? decltype((({ auto _l = (array_q()); (_l) ? decltype((p->iv_elem.native_q()))(p->iv_elem.native_q()) : decltype((p->iv_elem.native_q()))(_l); })))(_l) : (({ auto _l = (array_q()); (_l) ? decltype((p->iv_elem.native_q()))(p->iv_elem.native_q()) : decltype((p->iv_elem.native_q()))(_l); })); });
  }

  auto generic_compatible_q() {
    return (!(native_q()));
  }

  auto class_to_crystal() {
    if (({ auto _l = (array_q()); (_l) ? decltype((p->iv_elem.native_q()))(p->iv_elem.native_q()) : decltype((p->iv_elem.native_q()))(_l); })) {
      return (RubyString("Array(", 6) + ruby_to_s(p->iv_elem.to_crystal_storage()) + RubyString(")", 1));
    }
    return ({ auto _l = (CRYSTAL_CLASS_NAMES[p->iv_class_name]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(p->iv_class_name))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(p->iv_class_name))); });
  }

  auto to_legacy() {
    RubyHash<RubySymbol, int64_t> h;
    if ((p->iv_kind == ruby_sym("bottom"))) {
      return ruby_sym("unknown");
    } else if ((p->iv_kind == ruby_sym("i64"))) {
      return ruby_sym("i64");
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return ruby_sym("f64");
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      if (p->iv_elem.i64_q()) {
        return ruby_sym("array_i64");
      } else {
        return ruby_sym("array_f64");
      }
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return (h = ({ RubyHash<RubySymbol, int64_t> _h; _h.store(ruby_sym("class"), p->iv_class_name); _h; })); if (p->iv_nullable) {
        h[ruby_sym("nullable")] = true;
      }; if (p->iv_exact) {
        h[ruby_sym("exact")] = true;
      }; if (p->iv_elem) {
        h[ruby_sym("elem")] = p->iv_elem.to_legacy();
      }; if (p->iv_key) {
        h[ruby_sym("key")] = p->iv_key.to_legacy();
      }; if (p->iv_val) {
        h[ruby_sym("val")] = p->iv_val.to_legacy();
      }; h;
    }
    return RUBY_NIL;
  }

  auto boxed_class_name() {
    if ((p->iv_kind == ruby_sym("i64"))) {
      return ruby_sym("Integer");
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return ruby_sym("Float");
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      return ruby_sym("Array");
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return p->iv_class_name;
    } else {
      return ruby_sym("Object");
    }
  }

  auto to_class_type() {
    if ((p->iv_kind == ruby_sym("i64"))) {
      return INTEGER;
    } else if ((p->iv_kind == ruby_sym("f64"))) {
      return FLOAT;
    } else if ((p->iv_kind == ruby_sym("array_scalar"))) {
      if (p->iv_elem.i64_q()) {
        return Type.array();
      } else {
        return Type.array();
      }
    } else if ((p->iv_kind == ruby_sym("class_type"))) {
      return /* UNSUPPORTED: SelfLiteral */;
    } else {
      return OBJECT;
    }
  }

  auto merge_params(auto other) {
    std::decay_t<decltype(merge_param(p->iv_elem, other.elem()))> new_elem{};
    std::decay_t<decltype(merge_param(p->iv_key, other.key()))> new_key{};
    std::decay_t<decltype(merge_param(p->iv_val, other.val()))> new_val{};
    auto new_nullable = ({ auto _l = (p->iv_nullable); (_l) ? decltype((other.nullable_q()))(_l) : (other.nullable_q()); });
    (new_elem = merge_param(p->iv_elem, other.elem()));
    (new_key = merge_param(p->iv_key, other.key()));
    (new_val = merge_param(p->iv_val, other.val()));
    if (({ auto _l = (({ auto _l = (({ auto _l = ((new_nullable == p->iv_nullable)); (_l) ? decltype((new_elem.equal_q(p->iv_elem)))(new_elem.equal_q(p->iv_elem)) : decltype((new_elem.equal_q(p->iv_elem)))(_l); })); (_l) ? decltype((new_key.equal_q(p->iv_key)))(new_key.equal_q(p->iv_key)) : decltype((new_key.equal_q(p->iv_key)))(_l); })); (_l) ? decltype((new_val.equal_q(p->iv_val)))(new_val.equal_q(p->iv_val)) : decltype((new_val.equal_q(p->iv_val)))(_l); })) {
      return /* UNSUPPORTED: SelfLiteral */;
    } else {
      if (({ auto _l = (({ auto _l = (({ auto _l = ((new_nullable == other.nullable_q())); (_l) ? decltype((new_elem.equal_q(other.elem())))(new_elem.equal_q(other.elem())) : decltype((new_elem.equal_q(other.elem())))(_l); })); (_l) ? decltype((new_key.equal_q(other.key())))(new_key.equal_q(other.key())) : decltype((new_key.equal_q(other.key())))(_l); })); (_l) ? decltype((new_val.equal_q(other.val())))(new_val.equal_q(other.val())) : decltype((new_val.equal_q(other.val())))(_l); })) {
        return other;
      } else {
        return Ruby_Type(ruby_sym("class_type"));
      }
    }
  }

  auto merge_param(auto a, auto b) {
    if (({ auto _l = (a); (_l) ? decltype((b))(b) : decltype((b))(_l); })) {
      return ruby_sym("needs_join");
    } else {
      if (a) {
        return a;
      } else {
        if (b) {
          return b;
        }
        return RubySymbol(RUBY_NIL);
      }
    }
  }

  static auto of(auto class_name, bool nullable = false, bool exact = false) {
    if (({ auto _l = ((!(nullable))); (_l) ? decltype(((!(exact))))((!(exact))) : decltype(((!(exact))))(_l); })) {
      ({ auto _cs = class_name; ((_cs == ruby_sym("NilClass"))) ? (return NIL_CLASS) : (((_cs == ruby_sym("TrueClass"))) ? (return TRUE_CLASS) : (((_cs == ruby_sym("FalseClass"))) ? (return FALSE_CLASS) : (((_cs == ruby_sym("String"))) ? (return STRING) : (((_cs == ruby_sym("Symbol"))) ? (return SYMBOL) : (((_cs == ruby_sym("Integer"))) ? (return INTEGER) : (((_cs == ruby_sym("Float"))) ? (return FLOAT) : (((_cs == ruby_sym("Numeric"))) ? (return NUMERIC) : (((_cs == ruby_sym("Array"))) ? (return ARRAY) : (((_cs == ruby_sym("Hash"))) ? (return HASH) : (((_cs == ruby_sym("Object"))) ? (return OBJECT) : (((_cs == ruby_sym("BasicObject"))) ? (return BASIC_OBJECT) : (((_cs == ruby_sym("Range"))) ? (return RANGE) : (((_cs == ruby_sym("Regexp"))) ? (return REGEXP) : (((_cs == ruby_sym("Random"))) ? (return RANDOM) : (((_cs == ruby_sym("Proc"))) ? (return PROC) : (RUBY_NIL)))))))))))))))); });
    }
    return rb_new(ruby_sym("class_type"));
  }

  static auto array(auto elem) {
    return rb_new(ruby_sym("class_type"));
  }

  static auto i64_bounded(auto min, auto max) {
    if (({ auto _l = (ruby_nil_q(min)); (_l) ? decltype((ruby_nil_q(max)))(_l) : (ruby_nil_q(max)); })) {
      return I64;
    }
    return rb_new(ruby_sym("i64"));
  }

  static auto hash_type(int64_t key = RUBY_NIL, int64_t val = RUBY_NIL) {
    std::decay_t<decltype(rb_new(ruby_sym("class_type")))> h{};
    (h = rb_new(ruby_sym("class_type")));
    if (({ auto _l = (ruby_nil_q(key)); (_l) ? decltype((ruby_nil_q(val)))(ruby_nil_q(val)) : decltype((ruby_nil_q(val)))(_l); })) {
      return HASH;
    } else {
      return h;
    }
  }

  static auto nullable(auto type) {
    if (type.nullable_q()) {
      return type;
    }
    if (type.nil_type_q()) {
      return type;
    }
    if ((type.kind() == ruby_sym("bottom"))) {
      return NIL_CLASS;
    } else if ((type.kind() == ruby_sym("i64"))) {
      return of(ruby_sym("Integer"));
    } else if ((type.kind() == ruby_sym("f64"))) {
      return of(ruby_sym("Float"));
    } else if ((type.kind() == ruby_sym("class_type"))) {
      return rb_new(ruby_sym("class_type"));
    } else {
      return type;
    }
  }

  static auto from_ti(auto ty, Ruby_Set user_class_names = Ruby_Set()) {
    std::decay_t<decltype(from_ti(ty.elem()))> mapped_elem{};
    std::decay_t<decltype(ty.class_name())> cls{};
    if (({ auto _l = (ruby_nil_q(ty)); (_l) ? decltype((ty.bottom_q()))(_l) : (ty.bottom_q()); })) {
      return BOTTOM;
    }
    if (({ auto _l = (ty.raw_q()); (_l) ? decltype((ty.array_scalar_q()))(_l) : (ty.array_scalar_q()); })) {
      return ty;
    }
    if (!(ty.class_type_q())) {
      return BOTTOM;
    }
    if ((ty.class_name() == ruby_sym("Array"))) {
      if (ty.elem()) {
        return (mapped_elem = from_ti(ty.elem())); (mapped_elem.native_q() ? (Type.array()) : (BOTTOM));
      } else {
        return BOTTOM;
      }
    } else if ((ty.class_name() == ruby_sym("Hash")) || (ty.class_name() == ruby_sym("Proc"))) {
      return of(ty.class_name());
    } else if ((ty.class_name() == ruby_sym("String")) || (ty.class_name() == ruby_sym("Symbol")) || (ty.class_name() == ruby_sym("Integer")) || (ty.class_name() == ruby_sym("Float")) || (ty.class_name() == ruby_sym("NilClass")) || (ty.class_name() == ruby_sym("TrueClass")) || (ty.class_name() == ruby_sym("FalseClass")) || (ty.class_name() == ruby_sym("Object")) || (ty.class_name() == ruby_sym("Numeric")) || (ty.class_name() == ruby_sym("BasicObject")) || (ty.class_name() == ruby_sym("Comparable")) || (ty.class_name() == ruby_sym("Enumerable"))) {
      return BOTTOM;
    } else {
      return (cls = ty.class_name()); (({ auto _l = (user_class_names.include_q(cls)); (_l) ? decltype((CRYSTAL_CLASS_NAMES.key_q(cls)))(_l) : (CRYSTAL_CLASS_NAMES.key_q(cls)); }) ? (of(cls)) : (BOTTOM));
    }
  }

  static auto from_legacy(auto v) {
    std::decay_t<decltype(v[ruby_sym("class")])> cls{};
    bool nullable = false;
    bool exact = false;
    if ((v == Type)) {
      return v;
    } else if ((v == ruby_sym("unknown"))) {
      return BOTTOM;
    } else if ((v == ruby_sym("i64"))) {
      return I64;
    } else if ((v == ruby_sym("f64"))) {
      return F64;
    } else if ((v == ruby_sym("array_i64"))) {
      return ARRAY_I64;
    } else if ((v == ruby_sym("array_f64"))) {
      return ARRAY_F64;
    } else if ((v == INT64_C(0) /* ::Hash */)) {
      return (cls = v[ruby_sym("class")]); (nullable = ({ auto _l = (v[ruby_sym("nullable")]); (_l) ? decltype((false))(_l) : (false); })); (exact = ({ auto _l = (v[ruby_sym("exact")]); (_l) ? decltype((false))(_l) : (false); })); auto elem = (v.key_q(ruby_sym("elem")) ? (from_legacy(v[ruby_sym("elem")])) : (RUBY_NIL)); auto key = (v.key_q(ruby_sym("key")) ? (from_legacy(v[ruby_sym("key")])) : (RUBY_NIL)); auto val = (v.key_q(ruby_sym("val")) ? (from_legacy(v[ruby_sym("val")])) : (RUBY_NIL)); (({ auto _l = (({ auto _l = (elem); (_l) ? decltype((key))(_l) : (key); })); (_l) ? decltype((val))(_l) : (val); }) ? (rb_new(ruby_sym("class_type"))) : (of(cls)));
    } else if ((v == RUBY_NIL)) {
      return BOTTOM;
    } else {
      return BOTTOM;
    }
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Type>() { return "Type"; }





int main() {
  std::decay_t<decltype(INT64_C(0) /* ::Type */.rb_new(ruby_sym("i64")))> t{};
  std::decay_t<decltype(INT64_C(0) /* ::Type */.rb_new(ruby_sym("f64")))> t2{};
  (t = INT64_C(0) /* ::Type */.rb_new(ruby_sym("i64")));
  ruby_puts(ruby_to_s(t.kind()));
  ruby_puts(ruby_to_s(t.i64_q()));
  ruby_puts(ruby_to_s(t.numeric_q()));
  (t2 = INT64_C(0) /* ::Type */.rb_new(ruby_sym("f64")));
  ruby_puts(ruby_to_s(t2.f64_q()));
  ruby_puts(t2.to_crystal());
  return 0;
}

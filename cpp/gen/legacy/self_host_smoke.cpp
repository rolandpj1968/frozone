#include "../runtime/frozone.hpp"


struct Ruby_CrystalEmitter : public RubyObject {
  inline static const RubyString CRYSTAL_DIR = RubyString("/home/rolandpj/src/frozone/crystal", 34);
  gc_ref<RubyObject> iv_output_dir = nullptr;
  gc_ref<RubyObject> iv_out = nullptr;
  RubyArray<int64_t> iv_errors;
  int64_t iv_indent = 0;
  gc_ref<Ruby_Set> iv_user_methods;
  gc_ref<Ruby_Set> iv_exception_classes;
  bool iv_in_exception_class = false;
  int64_t iv_temp_counter = 0;
  RubyHash<RubySymbol, int64_t> iv_literal_symbols;
  RubyHash<RubySymbol, int64_t> iv_literal_arrays;
  RubyHash<RubySymbol, int64_t> iv_literal_strings;
  gc_ref<RubyObject> iv__declared_locals = nullptr;
  gc_ref<RubyObject> iv_cctx = nullptr;
  gc_ref<RubyObject> iv_gctx = nullptr;
  gc_ref<RubyObject> iv_mctx = nullptr;
  gc_ref<RubyObject> iv_current_block_param_name = nullptr;
  bool iv__inside_nested_expr = false;

  Ruby_CrystalEmitter() = default;
  Ruby_CrystalEmitter(int64_t output_dir = CRYSTAL_DIR) {
    iv_out = (RubyString("", 0));
    iv_indent = INT64_C(0);
    iv_errors = RubyArray_I64(0);
    iv_output_dir = output_dir;
    iv_user_methods = gc_new<Ruby_Set>();
    iv_exception_classes = gc_new<Ruby_Set>();
    iv_in_exception_class = false;
    iv_temp_counter = INT64_C(0);
    iv_literal_symbols = RubyHash<RubySymbol, int64_t>{};
    iv_literal_arrays = RubyHash<RubySymbol, int64_t>{};
    iv_literal_strings = RubyHash<RubySymbol, int64_t>{};
  }
  const char* rb_class_name() const override { return "CrystalEmitter"; }

  RubyObject* output_dir() {
    std::fprintf(stderr, "frozone: called TI-gap stub output_dir\n"); std::abort();
    return nullptr;
  }

  RubyObject* out() {
    std::fprintf(stderr, "frozone: called TI-gap stub out\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> errors() {
    return iv_errors;
  }

  RubyObject* generate(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub generate\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_symbol_literals(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_symbol_literals\n"); std::abort();
    return nullptr;
  }

  bool all_literal_numeric_q(auto node) {
    std::decay_t<decltype(node.element_nodes())> elems{};
    (elems = node.element_nodes());
    if (({ auto _l = (ruby_nil_q(elems)); (_l) ? decltype((elems.empty_q()))(_l) : (elems.empty_q()); })) {
      return false;
    }
    return elems.all_q();
  }

  RubyObject* literal_array_key(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub literal_array_key\n"); std::abort();
    return nullptr;
  }

  RubyNil literal_array_index(auto node) {
    std::decay_t<decltype(iv_literal_arrays[literal_array_key(node)])> entry{};
    if (!(all_literal_numeric_q(node))) {
      return RubyNil(RUBY_NIL);
    }
    (entry = iv_literal_arrays[literal_array_key(node)]);
    if (entry) {
      return entry[INT64_C(0)];
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* emit_literal_symbols() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_literal_symbols\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_user_methods(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_user_methods\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_user_method_stubs() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_user_method_stubs\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_header() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_header\n"); std::abort();
    return nullptr;
  }

  RubyString cr_nil() {
    return RubyString("RUBY_NIL", 8);
  }

  RubyString cr_true() {
    return RubyString("RUBY_TRUE", 9);
  }

  RubyString cr_false() {
    return RubyString("RUBY_FALSE", 10);
  }

  RubyObject* cr_integer(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_integer\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_float(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_float\n"); std::abort();
    return nullptr;
  }

  RubyString float_bits_expr(auto val) {
    std::decay_t<decltype(val.inspect())> s{};
    if (({ auto _l = ((val == 0.0)); (_l) ? decltype(((!(val.negative_q()))))((!(val.negative_q()))) : decltype(((!(val.negative_q()))))(_l); })) {
      return RubyString("0.0_f64", 7);
    }
    (s = val.inspect());
    if (s.=~(/* UNSUPPORTED: RegexpLiteral */)) {
      return (ruby_to_s(s) + RubyString("_f64", 4));
    } else {
      return auto bits = ({ auto _e0 = val; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }).pack(RubyString("d", 1)).unpack1(RubyString("q", 1)); (ruby_to_s(bits) + RubyString("_i64.unsafe_as(Float64)", 23));
    }
  }

  RubyObject* cr_string(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_string\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_symbol(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_symbol\n"); std::abort();
    return nullptr;
  }

  RubyString cr_self() {
    return RubyString("self", 4);
  }

  RubyObject* cr_local_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_local_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_local_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_local_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_ivar_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_ivar_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_ivar_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_ivar_write\n"); std::abort();
    return nullptr;
  }

  RubyNil cr_constant_read(auto node) {
    return ({ auto _l = (RUBY_TO_CRYSTAL_TYPE[node.name()]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(node.name())))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(node.name())))); });
  }

  RubyString cr_constant_path(auto node) {
    std::decay_t<decltype(node.parent_node())> parent{};
    std::decay_t<decltype(node.name())> name{};
    (parent = node.parent_node());
    (name = node.name());
    if (({ auto _l = (true); (_l) ? decltype(((parent.name() == ruby_sym("Math"))))((parent.name() == ruby_sym("Math"))) : decltype(((parent.name() == ruby_sym("Math"))))(_l); })) {
      return ({ auto _cs = name; ((_cs == ruby_sym("PI"))) ? (RubyString("RubyFloat.new(Math::PI)", 23)) : (((_cs == ruby_sym("E"))) ? (RubyString("RubyFloat.new(Math::E)", 22)) : ((RubyString("RubyMath.", 9) + ruby_to_s(crystal_method_name(name))))); });
    } else {
      if (({ auto _l = (true); (_l) ? decltype(((parent.name() == ruby_sym("Encoding"))))((parent.name() == ruby_sym("Encoding"))) : decltype(((parent.name() == ruby_sym("Encoding"))))(_l); })) {
        return (RubyString("Ruby_Encoding_", 14) + ruby_to_s(crystal_constant(name)));
      } else {
        if (true) {
          return ({ auto _l = (RUBY_TO_CRYSTAL_TYPE[name]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(name)))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(name)))); });
        } else {
          if (({ auto _l = (true); (_l) ? decltype((true))(_l) : (true); })) {
            return (ruby_to_s(cr(parent)) + RubyString("::Ruby_", 7) + ruby_to_s(crystal_constant(name)));
          } else {
            if (({ auto _l = (({ auto _l = (self_class_receiver_q(parent)); (_l) ? decltype((/* UNSUPPORTED: DefinedExpr */))(/* UNSUPPORTED: DefinedExpr */) : decltype((/* UNSUPPORTED: DefinedExpr */))(_l); })); (_l) ? decltype((iv_cctx->name()))(iv_cctx->name()) : decltype((iv_cctx->name()))(_l); })) {
              return (RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(iv_cctx->name())) + RubyString("::Ruby_", 7) + ruby_to_s(crystal_constant(name)));
            } else {
              return RubyString("RUBY_NIL", 8);
            }
          }
        }
      }
    }
  }

  RubyObject* self_class_receiver_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub self_class_receiver_q\n"); std::abort();
    return nullptr;
  }

  RubyNil ivar_class_receiver_q(auto node) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(iv_cctx->typed_ivars()[recv.name()])> ct{};
    if (!(({ auto _l = (true); (_l) ? decltype(((node.name() == ruby_sym("class"))))((node.name() == ruby_sym("class"))) : decltype(((node.name() == ruby_sym("class"))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (recv = node.receiver_node());
    if (!(true)) {
      return RubyNil(RUBY_NIL);
    }
    if (!(({ auto _l = (/* UNSUPPORTED: DefinedExpr */); (_l) ? decltype((iv_cctx->typed_ivars()))(iv_cctx->typed_ivars()) : decltype((iv_cctx->typed_ivars()))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (ct = iv_cctx->typed_ivars()[recv.name()]);
    if (true) {
      return ct[INT64_C(1)];
    } else {
      return ct;
    }
  }

  RubyObject* cr_constant_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_constant_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_constant_path_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_constant_path_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_class_var_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_class_var_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_class_var_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_class_var_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_sequence(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_sequence\n"); std::abort();
    return nullptr;
  }

  RubyString cr_method_call(auto node) {
    return default_method_call(node);
  }

  RubyString default_method_call(auto node) {
    std::decay_t<decltype(node.name())> name{};
    RubyArray<int64_t> args;
    std::decay_t<decltype(crystal_method_name(args[INT64_C(0)].value()))> new_name{};
    std::decay_t<decltype(crystal_method_name(args[INT64_C(1)].value()))> old_name{};
    RubyString indent_str;
    RubyNil cr_type;
    std::decay_t<decltype(node.arg_nodes()[INT64_C(0)])> arg{};
    std::decay_t<decltype(ruby_to_s(arg.name()))> const_name{};
    RubyNil crystal_type;
    RubyString recv_str;
    RubyNil cls_name;
    std::decay_t<decltype(node.block_node())> blk{};
    int64_t nparams = 0;
    std::decay_t<decltype(crystal_method_name(name))> cname{};
    (name = node.name());
    if (ruby_nil_q(node.receiver_node())) {
      ({ auto _cs = name; ((_cs == ruby_sym("puts"))) ? (return cr_puts(node)) : (((_cs == ruby_sym("print"))) ? (return cr_print(node)) : (((_cs == ruby_sym("p"))) ? (return cr_p(node)) : (((_cs == ruby_sym("raise"))) ? (return cr_raise(node)) : (((_cs == ruby_sym("require")) || (_cs == ruby_sym("require_relative"))) ? (return cr_require_call(node)) : (((_cs == ruby_sym("block_given?"))) ? (return RubyString("block_given?", 12)) : (((_cs == ruby_sym("instance_variables"))) ? (return RubyString("instance_variables", 18)) : (((_cs == ruby_sym("instance_variable_get"))) ? ((args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map().join(RubyString(", ", 2))); return (RubyString("instance_variable_get(", 22) + ruby_to_s(args) + RubyString(")", 1))) : (((_cs == ruby_sym("send"))) ? ((args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map().join(RubyString(", ", 2))); return (RubyString("send(", 5) + ruby_to_s(args) + RubyString(")", 1))) : (((_cs == ruby_sym("loop"))) ? (return cr_loop_call(node)) : (((_cs == ruby_sym("Rational")) || (_cs == ruby_sym("Integer")) || (_cs == ruby_sym("Float")) || (_cs == ruby_sym("Complex")) || (_cs == ruby_sym("String")) || (_cs == ruby_sym("Array"))) ? ((args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map().join(RubyString(", ", 2))); return (RubyString("ruby_", 5) + ruby_to_s(name) + RubyString("(", 1) + ruby_to_s(args) + RubyString(")", 1))) : (((_cs == ruby_sym("alias_method"))) ? ((args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })); if (({ auto _l = (({ auto _l = ((args.len() == INT64_C(2))); (_l) ? decltype((true))(true) : decltype((true))(_l); })); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
      (new_name = crystal_method_name(args[INT64_C(0)].value()));
      (old_name = crystal_method_name(args[INT64_C(1)].value()));
      return (RubyString("def ", 4) + ruby_to_s(new_name) + RubyString("(*args); ", 9) + ruby_to_s(old_name) + RubyString("(*args); end", 12));
    }; return RubyString("# alias_method (unsupported args)", 33)) : (((_cs == ruby_sym("attr_accessor"))) ? (return cr_attr_methods(node)) : (((_cs == ruby_sym("attr_reader"))) ? (return cr_attr_methods(node)) : (((_cs == ruby_sym("attr_writer"))) ? (return cr_attr_methods(node)) : (((_cs == ruby_sym("include")) || (_cs == ruby_sym("extend")) || (_cs == ruby_sym("prepend"))) ? (auto mods = node.arg_nodes().filter_map(); (indent_str = (RubyString("  ", 2) * iv_indent)); if (({ auto _l = ((name == ruby_sym("include"))); (_l) ? decltype(((!(mods.empty_q()))))((!(mods.empty_q()))) : decltype(((!(mods.empty_q()))))(_l); })) {
      auto core_mods = mods.select();
      if (!(core_mods.empty_q())) {
      return core_mods.map().join((RubyString("\n", 1) + ruby_to_s(indent_str)));
    };
    }; return (RubyString("# ", 2) + ruby_to_s(name) + RubyString(" ", 1) + ruby_to_s(node.arg_nodes().map().join(RubyString(", ", 2))))) : (RUBY_NIL)))))))))))))))); });
    }
    if (({ auto _l = (node.receiver_node()); (_l) ? decltype((operator_q(name)))(operator_q(name)) : decltype((operator_q(name)))(_l); })) {
      return cr_operator(node, name);
    }
    if (({ auto _l = ((name == ruby_sym("new"))); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
      (cr_type = RUBY_TO_CRYSTAL_TYPE[node.receiver_node().name()]);
      if (cr_type) {
      return (ruby_to_s(cr_type) + RubyString(".new", 4) + ruby_to_s(cr_call_args(node)));
    };
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = ((name == ruby_sym("new"))); (_l) ? decltype((true))(true) : decltype((true))(_l); })); (_l) ? decltype(((node.receiver_node().name() == ruby_sym("Proc"))))((node.receiver_node().name() == ruby_sym("Proc"))) : decltype(((node.receiver_node().name() == ruby_sym("Proc"))))(_l); })); (_l) ? decltype((node.block_node()))(node.block_node()) : decltype((node.block_node()))(_l); })) {
      return cr_proc_new(node.block_node());
    }
    if (({ auto _l = (({ auto _l = ((name == ruby_sym("lambda"))); (_l) ? decltype((ruby_nil_q(node.receiver_node())))(ruby_nil_q(node.receiver_node())) : decltype((ruby_nil_q(node.receiver_node())))(_l); })); (_l) ? decltype((node.block_node()))(node.block_node()) : decltype((node.block_node()))(_l); })) {
      return cr_proc_new(node.block_node());
    }
    if (({ auto _l = ((name == ruby_sym("call"))); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); })) {
      return cr_proc_call(node);
    }
    if (({ auto _l = (({ auto _l = ((name == ruby_sym("[]"))); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); })); (_l) ? decltype(((node.arg_nodes().len() == INT64_C(1))))((node.arg_nodes().len() == INT64_C(1))) : decltype(((node.arg_nodes().len() == INT64_C(1))))(_l); })) {
      return (ruby_to_s(cr(node.receiver_node())) + RubyString("[", 1) + ruby_to_s(cr(node.arg_nodes()[INT64_C(0)])) + RubyString("]", 1));
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = ((name == ruby_sym("is_a?"))); (_l) ? decltype(((name == ruby_sym("kind_of?"))))(_l) : ((name == ruby_sym("kind_of?"))); })); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); })); (_l) ? decltype(((node.arg_nodes().len() == INT64_C(1))))((node.arg_nodes().len() == INT64_C(1))) : decltype(((node.arg_nodes().len() == INT64_C(1))))(_l); })) {
      (arg = node.arg_nodes()[INT64_C(0)]);
      if (true) {
      (const_name = ruby_to_s(arg.name()));
      (crystal_type = ({ auto _l = (RUBY_TO_CRYSTAL_TYPE[arg.name()]); (_l) ? decltype(((BUILTIN_SUPERCLASSES.include_q(const_name) ? ((RubyString("Ruby", 4) + ruby_to_s(const_name))) : ((RubyString("Ruby_", 5) + ruby_to_s(const_name))))))(_l) : ((BUILTIN_SUPERCLASSES.include_q(const_name) ? ((RubyString("Ruby", 4) + ruby_to_s(const_name))) : ((RubyString("Ruby_", 5) + ruby_to_s(const_name))))); }));
      return (RubyString("(", 1) + ruby_to_s(cr(node.receiver_node())) + RubyString(".is_a?(", 7) + ruby_to_s(crystal_type) + RubyString(") ? RUBY_TRUE : RUBY_FALSE)", 27));
    } else {
      if (true) {
      return (RubyString("(", 1) + ruby_to_s(cr(node.receiver_node())) + RubyString(".is_a?(", 7) + ruby_to_s(cr(arg)) + RubyString(") ? RUBY_TRUE : RUBY_FALSE)", 27));
    };
    };
    }
    if (self_class_receiver_q(node.receiver_node())) {
      if ((name == ruby_sym("respond_to?"))) {
      return RubyString("RUBY_FALSE", 10);
    };
      if ((name == ruby_sym("send"))) {
      return RubyString("RUBY_NIL", 8);
    };
    }
    (recv_str = if (node.receiver_node()) {
      if (({ auto _l = (({ auto _l = (self_class_receiver_q(node.receiver_node())); (_l) ? decltype((/* UNSUPPORTED: DefinedExpr */))(/* UNSUPPORTED: DefinedExpr */) : decltype((/* UNSUPPORTED: DefinedExpr */))(_l); })); (_l) ? decltype((iv_cctx->name()))(iv_cctx->name()) : decltype((iv_cctx->name()))(_l); })) {
      (RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(iv_cctx->name())) + RubyString(".", 1));
    } else {
      ((cls_name = ivar_class_receiver_q(node.receiver_node())) ? ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(cls_name)) + RubyString(".", 1))) : ((ruby_to_s(cr(node.receiver_node())) + RubyString(".", 1))));
    };
    } else {
      RubyString("", 0);
    })
    if (({ auto _l = (({ auto _l = (node.receiver_node()); (_l) ? decltype((node.block_node()))(node.block_node()) : decltype((node.block_node()))(_l); })); (_l) ? decltype((({ auto _e0 = ruby_sym("each"); auto _a = RubyArray<decltype(_e0)>(11); _a[0] = _e0; _a[1] = ruby_sym("each_with_index"); _a[2] = ruby_sym("map"); _a[3] = ruby_sym("select"); _a[4] = ruby_sym("reject"); _a[5] = ruby_sym("flat_map"); _a[6] = ruby_sym("any?"); _a[7] = ruby_sym("all?"); _a[8] = ruby_sym("none?"); _a[9] = ruby_sym("count"); _a[10] = ruby_sym("collect"); _a; }).include_q(name)))(({ auto _e0 = ruby_sym("each"); auto _a = RubyArray<decltype(_e0)>(11); _a[0] = _e0; _a[1] = ruby_sym("each_with_index"); _a[2] = ruby_sym("map"); _a[3] = ruby_sym("select"); _a[4] = ruby_sym("reject"); _a[5] = ruby_sym("flat_map"); _a[6] = ruby_sym("any?"); _a[7] = ruby_sym("all?"); _a[8] = ruby_sym("none?"); _a[9] = ruby_sym("count"); _a[10] = ruby_sym("collect"); _a; }).include_q(name)) : decltype((({ auto _e0 = ruby_sym("each"); auto _a = RubyArray<decltype(_e0)>(11); _a[0] = _e0; _a[1] = ruby_sym("each_with_index"); _a[2] = ruby_sym("map"); _a[3] = ruby_sym("select"); _a[4] = ruby_sym("reject"); _a[5] = ruby_sym("flat_map"); _a[6] = ruby_sym("any?"); _a[7] = ruby_sym("all?"); _a[8] = ruby_sym("none?"); _a[9] = ruby_sym("count"); _a[10] = ruby_sym("collect"); _a; }).include_q(name)))(_l); })) {
      (blk = node.block_node());
      (nparams = (true ? (({ auto _l = (blk.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len()) : (INT64_C(1))));
      if ((nparams <= INT64_C(1))) {
      (recv_str = (ruby_to_s(cr(node.receiver_node())) + RubyString(".as(RubyArray).", 15)));
    };
    }
    (cname = crystal_method_name(name));
    if (({ auto _l = (recv_str.empty_q()); (_l) ? decltype((({ auto _l = (BINARY_OPS.include_q(name)); (_l) ? decltype((UNARY_OPS.include_q(name)))(_l) : (UNARY_OPS.include_q(name)); })))(({ auto _l = (BINARY_OPS.include_q(name)); (_l) ? decltype((UNARY_OPS.include_q(name)))(_l) : (UNARY_OPS.include_q(name)); })) : decltype((({ auto _l = (BINARY_OPS.include_q(name)); (_l) ? decltype((UNARY_OPS.include_q(name)))(_l) : (UNARY_OPS.include_q(name)); })))(_l); })) {
      (recv_str = RubyString("self.", 5));
    }
    return (ruby_to_s(recv_str) + ruby_to_s(cname) + ruby_to_s(cr_call_args(node)));
  }

  RubyObject* operator_q(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub operator_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_attribute_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_attribute_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* default_attribute_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub default_attribute_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_operator(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_operator\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_operator_recv(auto recv) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_operator_recv\n"); std::abort();
    return nullptr;
  }

  bool recv_contains_assignment_q(auto node) {
    if (({ auto _l = (true); (_l) ? decltype((true))(_l) : (true); })) {
      return true;
    }
    if (({ auto _l = (true); (_l) ? decltype((true))(_l) : (true); })) {
      return true;
    }
    if (true) {
      return true;
    }
    return ({ auto _l = (({ auto _l = (true); (_l) ? decltype(((node.nodes().len() == INT64_C(1))))((node.nodes().len() == INT64_C(1))) : decltype(((node.nodes().len() == INT64_C(1))))(_l); })); (_l) ? decltype((recv_contains_assignment_q(node.nodes().first())))(recv_contains_assignment_q(node.nodes().first())) : decltype((recv_contains_assignment_q(node.nodes().first())))(_l); });
  }

  RubyString cr_puts(auto node) {
    std::decay_t<decltype(node.arg_nodes())> args{};
    (args = node.arg_nodes());
    if (args.empty_q()) {
      return RubyString("STDOUT.puts; RUBY_NIL", 21);
    }
    if ((args.len() == INT64_C(1))) {
      return (RubyString("ruby_puts(", 10) + ruby_to_s(cr(args[INT64_C(0)])) + RubyString("); RUBY_NIL", 11));
    }
    return (ruby_to_s(args.map().join()) + RubyString("RUBY_NIL", 8));
  }

  RubyObject* cr_print(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_print\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_p(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_p\n"); std::abort();
    return nullptr;
  }

  RubyString cr_raise(auto node) {
    std::decay_t<decltype(node.arg_nodes())> args{};
    std::decay_t<decltype(args[INT64_C(0)])> arg{};
    RubyString body;
    std::decay_t<decltype(args[INT64_C(0)])> exc_node{};
    std::decay_t<decltype(args[INT64_C(1)])> msg_node{};
    RubyString ctor;
    bool is_user_exc = false;
    RubyString suffix;
    (args = node.arg_nodes());
    if (args.empty_q()) {
      return RubyString("raise RuntimeError.new", 22);
    }
    if ((args.len() == INT64_C(1))) {
      (arg = args[INT64_C(0)]);
      (body = ({ auto _cs = arg; ((_cs == INT64_C(0) /* ::StringLiteral */)) ? ((RubyString("RuntimeError.new(", 17) + ruby_to_s(crystal_string_literal(arg.value().raw())) + RubyString(")", 1))) : (((_cs == INT64_C(0) /* ::InterpolatedString */)) ? ((RubyString("RuntimeError.new(", 17) + ruby_to_s(cr(arg)) + RubyString(".to_s)", 6))) : (((_cs == INT64_C(0) /* ::ConstantRead */)) ? ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(arg.name())) + RubyString(".new", 4))) : (cr(arg)))); }));
      return (RubyString("raise ", 6) + ruby_to_s(body));
    }
    (exc_node = args[INT64_C(0)]);
    (msg_node = args[INT64_C(1)]);
    (ctor = (true ? ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(exc_node.name())) + RubyString(".new", 4))) : ((ruby_to_s(cr(exc_node)) + RubyString(".new", 4)))));
    (is_user_exc = if (true) {
      iv_exception_classes->include_q(exc_node.name());
    } else {
      if (true) {
      true;
    };
    })
    (suffix = (is_user_exc ? (RubyString("", 0)) : (RubyString(".to_s", 5))));
    return (RubyString("raise ", 6) + ruby_to_s(ctor) + RubyString("(", 1) + ruby_to_s(cr(msg_node)) + ruby_to_s(suffix) + RubyString(")", 1));
  }

  RubyObject* cr_rescue(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_rescue\n"); std::abort();
    return nullptr;
  }

  RubyString cr_super(auto node) {
    std::decay_t<decltype(node.arg_nodes())> args{};
    RubyString suffix;
    (args = node.arg_nodes());
    if (({ auto _l = (({ auto _l = (node.forwarding()); (_l) ? decltype((ruby_nil_q(args)))(_l) : (ruby_nil_q(args)); })); (_l) ? decltype((args.empty_q()))(_l) : (args.empty_q()); })) {
      return RubyString("super", 5);
    }
    (suffix = (iv_in_exception_class ? (RubyString(".to_s", 5)) : (RubyString("", 0))));
    return (RubyString("super(", 6) + ruby_to_s(args.map().join(RubyString(", ", 2))) + RubyString(")", 1));
  }

  RubyObject* cr_require_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_require_call\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_attr_methods(auto node, auto reader, auto writer) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_attr_methods\n"); std::abort();
    return nullptr;
  }

  RubyString cr_call_args(auto node) {
    RubyNil block_node;
    RubyArray<int64_t> parts;
    RubyString s;
    (block_node = node.block_node());
    if (({ auto _l = (block_node); (_l) ? decltype((callee_ignores_block_q(node)))(callee_ignores_block_q(node)) : decltype((callee_ignores_block_q(node)))(_l); })) {
      (block_node = RUBY_NIL);
    }
    if (({ auto _l = (({ auto _l = (node.arg_nodes().empty_q()); (_l) ? decltype((node.kw_arg_nodes().empty_q()))(node.kw_arg_nodes().empty_q()) : decltype((node.kw_arg_nodes().empty_q()))(_l); })); (_l) ? decltype((ruby_nil_q(block_node)))(ruby_nil_q(block_node)) : decltype((ruby_nil_q(block_node)))(_l); })) {
      return RubyString("", 0);
    }
    (parts = RubyArray_I64(0));
    { auto _coll = node.arg_nodes(); for (auto& arg : *_coll.data) {
      (true ? ((parts << (RubyString("*", 1) + ruby_to_s(cr(arg.value_node()))))) : ((parts << cr(arg))));
    } }
    { auto _coll = node.kw_arg_nodes(); for (auto& kw_name : *_coll.data) {
      auto key = (true ? (kw_name.value()) : (kw_name));
      (parts << (ruby_to_s(key) + RubyString(": ", 2) + ruby_to_s(cr(val_node))));
    } }
    (s = (RubyString("(", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString(")", 1)));
    if (block_node) {
      (s = (s + RubyString(" ", 1)));
      (s = (s + (true ? (cr_block_arg(block_node)) : (cr_block(block_node)))));
    }
    return s;
  }

  bool callee_ignores_block_q(auto node) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    int64_t cls = 0;
    if (!(({ auto _l = (/* UNSUPPORTED: DefinedExpr */); (_l) ? decltype((iv_gctx->method_uses_block()))(iv_gctx->method_uses_block()) : decltype((iv_gctx->method_uses_block()))(_l); }))) {
      return false;
    }
    (recv = node.receiver_node());
    if (ruby_nil_q(recv)) {
      auto uses = iv_gctx->method_uses_block()[({ auto _e0 = RUBY_NIL; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; })];
      return (uses == false);
    }
    (cls = try {
      expr_class(recv);
    } catch (Ruby_StandardError&) {
      RUBY_NIL;
    })
    if (!(cls)) {
      return false;
    }
    return (iv_gctx->method_uses_block()[({ auto _e0 = cls; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; })] == false);
  }

  gc_ref<RubyObject> cr_block(auto node) {
    RubyString param_str;
    RubyNil body;
    RubyString indent_str;
    auto params = (({ auto _l = (node.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }) + ({ auto _l = (node.optional_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map());
    (params = (params + ({ auto _e0 = node.rest_param(); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }).compact()));
    (param_str = (params.empty_q() ? (RubyString("", 0)) : ((RubyString("|", 1) + ruby_to_s(params.map().join(RubyString(", ", 2))) + RubyString("| ", 2)))));
    (body = RUBY_NIL);
    indented([&]() { return (body = cr(node.body())); });
    if (body.include_q(RubyString("\n", 1))) {
      return coerce_to_ref<RubyObject>((indent_str = (RubyString("  ", 2) * iv_indent)); (RubyString("do ", 3) + ruby_to_s(param_str) + RubyString("\n", 1) + ruby_to_s(body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("end", 3)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("{ ", 2) + ruby_to_s(param_str) + ruby_to_s(body) + RubyString(" }", 2)));
    }
  }

  RubyObject* cr_block_param(auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_block_param\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_block_param_destructure(auto h) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_block_param_destructure\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> cr_block_arg(auto block_arg_node) {
    std::decay_t<decltype(block_arg_node.value_node())> value_node{};
    std::decay_t<decltype(crystal_method_name(value_node.value()))> method_name{};
    (value_node = block_arg_node.value_node());
    if (true) {
      return coerce_to_ref<RubyObject>((method_name = crystal_method_name(value_node.value())); (RubyString("{ |_sym2proc| _sym2proc.", 24) + ruby_to_s(method_name) + RubyString(".as(RubyObject) }", 17)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("{ |_blkarg| (", 13) + ruby_to_s(cr(value_node)) + RubyString(").as(RubyProc).call(_blkarg) }", 30)));
    }
  }

  gc_ref<RubyObject> cr_if(auto node) {
    std::decay_t<decltype(cr_truthy(node.pred_node()))> pred{};
    RubyString indent_str;
    RubyNil body;
    RubyNil then_body;
    RubyNil else_body;
    (pred = cr_truthy(node.pred_node()));
    (indent_str = (RubyString("  ", 2) * iv_indent));
    if (({ auto _l = (true); (_l) ? decltype((node.else_node()))(node.else_node()) : decltype((node.else_node()))(_l); })) {
      (body = RUBY_NIL);
      indented([&]() { return (body = cr(node.else_node())); });
      return (RubyString("unless ", 7) + ruby_to_s(pred) + RubyString("\n", 1) + ruby_to_s(body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("end", 3));
    }
    (then_body = RUBY_NIL);
    indented([&]() { return (then_body = cr(node.then_node())); });
    (true ? (RUBY_NIL) : ((then_body = (RubyString("  ", 2) + ruby_to_s(indent_str) + ruby_to_s(then_body)))));
    if (node.else_node()) {
      return coerce_to_ref<RubyObject>((else_body = RUBY_NIL); indented([&]() { return (else_body = cr(node.else_node())); }); (true ? (RUBY_NIL) : ((else_body = (RubyString("  ", 2) + ruby_to_s(indent_str) + ruby_to_s(else_body))))); (RubyString("if ", 3) + ruby_to_s(pred) + RubyString("\n", 1) + ruby_to_s(then_body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("else\n", 5) + ruby_to_s(else_body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("end", 3)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("if ", 3) + ruby_to_s(pred) + RubyString("\n", 1) + ruby_to_s(then_body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("end", 3)));
    }
  }

  RubyObject* cr_for_loop(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_for_loop\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_while(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_while\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_until(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_until\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_loop(auto keyword, auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_loop\n"); std::abort();
    return nullptr;
  }

  RubyString cr_return(auto node) {
    std::decay_t<decltype(cr(node.value_node()))> val{};
    if (!(node.value_node())) {
      return RubyString("return", 6);
    }
    (val = cr(node.value_node()));
    if (val.include_q(RubyString("\n", 1))) {
      (val = (RubyString("(", 1) + ruby_to_s(val) + RubyString(")", 1)));
    }
    return (RubyString("return ", 7) + ruby_to_s(val));
  }

  RubyString cr_next(auto node) {
    std::decay_t<decltype(node.value_node())> val{};
    (val = node.value_node());
    if (({ auto _l = (ruby_nil_q(val)); (_l) ? decltype((true))(_l) : (true); })) {
      return RubyString("next", 4);
    } else {
      return (RubyString("next (", 6) + ruby_to_s(cr(val)) + RubyString(")", 1));
    }
  }

  RubyString cr_break(auto node) {
    std::decay_t<decltype(node.value_node())> val{};
    (val = node.value_node());
    if (({ auto _l = (ruby_nil_q(val)); (_l) ? decltype((true))(_l) : (true); })) {
      return RubyString("break", 5);
    } else {
      return (RubyString("break (", 7) + ruby_to_s(cr(val)) + RubyString(")", 1));
    }
  }

  RubyString cr_loop_call(auto node) {
    RubyString indent_str;
    RubyNil body;
    if (!(node.block_node())) {
      return RubyString("loop do\nend", 11);
    }
    (indent_str = (RubyString("  ", 2) * iv_indent));
    (body = RUBY_NIL);
    indented([&]() { return (body = cr(node.block_node().body())); });
    return (RubyString("loop do\n", 8) + ruby_to_s(body) + RubyString("\n", 1) + ruby_to_s(indent_str) + RubyString("end", 3));
  }

  RubyObject* cr_lambda(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_lambda\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_proc_new(auto block_node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_proc_new\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_proc_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_proc_call\n"); std::abort();
    return nullptr;
  }

  RubyNil cr_global_var_read(auto node) {
    RubyNil mapped;
    (mapped = MAPPED_GLOBALS[node.name()]);
    return ({ auto _l = (mapped); (_l) ? decltype(((RubyString("(RUBY_GLOBALS[", 14) + ruby_to_s(ruby_to_s(node.name()).sub(/* UNSUPPORTED: RegexpLiteral */, RubyString("", 0)).inspect()) + RubyString("]? || RUBY_NIL)", 15))))(_l) : ((RubyString("(RUBY_GLOBALS[", 14) + ruby_to_s(ruby_to_s(node.name()).sub(/* UNSUPPORTED: RegexpLiteral */, RubyString("", 0)).inspect()) + RubyString("]? || RUBY_NIL)", 15))); });
  }

  RubyObject* cr_global_var_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_global_var_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_index_or_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_index_or_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_index_and_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_index_and_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_index_op_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_index_op_write\n"); std::abort();
    return nullptr;
  }

  RubyString cr_yield(auto node) {
    std::decay_t<decltype(node.arg_nodes())> args{};
    (args = node.arg_nodes());
    if (args.empty_q()) {
      return RubyString("yield", 5);
    }
    return (RubyString("yield ", 6) + ruby_to_s(args.map().join(RubyString(", ", 2))));
  }

  RubyObject* cr_and(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_and\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_or(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_or\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_truthy(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_truthy\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> boolean_valued_q(auto node) {
    std::decay_t<decltype(RUBY_TO_CRYSTAL_METHOD.fetch(node.name(), node.name()))> crystal_name{};
    if ((node == INT64_C(0) /* ::TrueLiteral */) || (node == INT64_C(0) /* ::FalseLiteral */)) {
      return coerce_to_ref<RubyObject>(true);
    } else if ((node == INT64_C(0) /* ::MethodCall */)) {
      return coerce_to_ref<RubyObject>((crystal_name = RUBY_TO_CRYSTAL_METHOD.fetch(node.name(), node.name())); BOOL_METHODS.include_q(crystal_name));
    } else {
      return coerce_to_ref<RubyObject>(false);
    }
  }

  RubyObject* comparison_op_call_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub comparison_op_call_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* type_check_cond_q(auto cond) {
    std::fprintf(stderr, "frozone: called TI-gap stub type_check_cond_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_case(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_case\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_case_native(auto subj_name, auto whens, auto else_n) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_case_native\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_case_if_chain(auto subj_var, auto whens, auto else_n) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_case_if_chain\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> cr_case_match(auto cond_node, auto subj_var) {
    std::decay_t<decltype(cond_node.name())> type_name{};
    RubyNil crystal_type;
    if ((cond_node == INT64_C(0) /* ::NilLiteral */)) {
      return coerce_to_ref<RubyObject>((ruby_to_s(subj_var) + RubyString(".ruby_nil?", 10)));
    } else if ((cond_node == INT64_C(0) /* ::TrueLiteral */)) {
      return coerce_to_ref<RubyObject>((ruby_to_s(subj_var) + RubyString(".truthy? && !", 13) + ruby_to_s(subj_var) + RubyString(".ruby_nil?", 10)));
    } else if ((cond_node == INT64_C(0) /* ::FalseLiteral */)) {
      return coerce_to_ref<RubyObject>((RubyString("!", 1) + ruby_to_s(subj_var) + RubyString(".truthy?", 8)));
    } else if ((cond_node == INT64_C(0) /* ::ConstantRead */)) {
      return coerce_to_ref<RubyObject>((type_name = cond_node.name()); (crystal_type = ({ auto _l = (RUBY_TO_CRYSTAL_TYPE[type_name]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(type_name)))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(type_name)))); })); (ruby_to_s(subj_var) + RubyString(".is_a?(", 7) + ruby_to_s(crystal_type) + RubyString(")", 1)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("(", 1) + ruby_to_s(cr(cond_node)) + RubyString(") == ", 5) + ruby_to_s(subj_var)));
    }
  }

  RubyObject* cr_array_literal(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_array_literal\n"); std::abort();
    return nullptr;
  }

  RubyString cr_hash_literal(auto node) {
    std::decay_t<decltype(node.kv_nodes())> pairs{};
    (pairs = node.kv_nodes());
    if (pairs.empty_q()) {
      return RubyString("RubyHash.new", 12);
    }
    auto stores = pairs.map().join(RubyString("; ", 2));
    return (RubyString("RubyHash.new.tap { |_h| ", 24) + ruby_to_s(stores) + RubyString(" }", 2));
  }

  RubyObject* cr_range_literal(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_range_literal\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_multiple_assignment(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_multiple_assignment\n"); std::abort();
    return nullptr;
  }

  RubyObject* default_multiple_assignment(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub default_multiple_assignment\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_masgn_assign(auto target, auto value_code) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_masgn_assign\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> default_masgn_assign(auto target, auto value_code) {
    if ((target[INT64_C(0)] == ruby_sym("local")) || (target[INT64_C(0)] == ruby_sym("local_splat"))) {
      return coerce_to_ref<RubyObject>((ruby_to_s(crystal_local(target[INT64_C(1)])) + RubyString(" = ", 3) + ruby_to_s(value_code)));
    } else if ((target[INT64_C(0)] == ruby_sym("ivar")) || (target[INT64_C(0)] == ruby_sym("ivar_splat"))) {
      return coerce_to_ref<RubyObject>((ruby_to_s(target[INT64_C(1)]) + RubyString(" = ", 3) + ruby_to_s(value_code)));
    } else if ((target[INT64_C(0)] == ruby_sym("const")) || (target[INT64_C(0)] == ruby_sym("const_splat"))) {
      return coerce_to_ref<RubyObject>((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(target[INT64_C(1)])) + RubyString(" = ", 3) + ruby_to_s(value_code)));
    } else if ((target[INT64_C(0)] == ruby_sym("index")) || (target[INT64_C(0)] == ruby_sym("index_splat"))) {
      return coerce_to_ref<RubyObject>(auto idxs = target[INT64_C(2)].map().join(RubyString(", ", 2)); (ruby_to_s(cr(target[INT64_C(1)])) + RubyString("[", 1) + ruby_to_s(idxs) + RubyString("] = ", 4) + ruby_to_s(value_code)));
    } else if ((target[INT64_C(0)] == ruby_sym("call")) || (target[INT64_C(0)] == ruby_sym("call_splat"))) {
      return coerce_to_ref<RubyObject>((ruby_to_s(cr(target[INT64_C(1)])) + RubyString(".", 1) + ruby_to_s(crystal_method_name(target[INT64_C(2)])) + RubyString(" = ", 3) + ruby_to_s(value_code)));
    } else if ((target[INT64_C(0)] == ruby_sym("splat_nil"))) {
      return coerce_to_ref<RubyObject>(RubyString("", 0));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("# UNSUPPORTED masgn target: ", 28) + ruby_to_s(target[INT64_C(0)])));
    }
  }

  RubyObject* cr_interpolated_string(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_interpolated_string\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_method_def(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_method_def\n"); std::abort();
    return nullptr;
  }

  RubyString cr_param_list(auto node) {
    RubyArray<int64_t> parts;
    std::decay_t<decltype(node.rest_param())> rp{};
    RubyArray<int64_t> req_kw;
    RubyArray<int64_t> opt_kw;
    std::decay_t<decltype(node.kw_rest_param())> kr{};
    std::decay_t<decltype(node.block_param())> bp{};
    (parts = RubyArray_I64(0));
    { auto _coll = node.required_params(); for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject", 13)));
    } }
    { auto _coll = node.optional_params(); for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject = ", 16) + ruby_to_s((rb_default ? ((RubyString("(", 1) + ruby_to_s(codegen_inline(rb_default)) + RubyString(")", 1))) : (RubyString("RUBY_NIL", 8))))));
    } }
    (rp = node.rest_param());
    if (rp) {
      (parts << (RubyString("*", 1) + ruby_to_s(crystal_local(rp)) + RubyString(" : RubyObject", 13)));
    }
    { auto _coll = node.post_params(); for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject", 13)));
    } }
    (req_kw = ({ auto _l = (node.required_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    (opt_kw = ({ auto _l = (node.optional_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    (kr = node.kw_rest_param());
    if (({ auto _l = (({ auto _l = ((!(req_kw.empty_q()))); (_l) ? decltype(((!(opt_kw.empty_q()))))(_l) : ((!(opt_kw.empty_q()))); })); (_l) ? decltype(((!(rp))))((!(rp))) : decltype(((!(rp))))(_l); })) {
      (parts << RubyString("*", 1));
    }
    { auto _coll = req_kw; for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject", 13)));
    } }
    { auto _coll = opt_kw; for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject = ", 16) + ruby_to_s((rb_default ? ((RubyString("(", 1) + ruby_to_s(codegen_inline(rb_default)) + RubyString(")", 1))) : (RubyString("RUBY_NIL", 8))))));
    } }
    if (kr) {
      (parts << (RubyString("**", 2) + ruby_to_s(crystal_local(kr))));
    }
    (bp = node.block_param());
    if (bp) {
      (parts << (RubyString("&", 1) + ruby_to_s(crystal_local(bp))));
    }
    if (parts.empty_q()) {
      return RubyString("", 0);
    } else {
      return (RubyString("(", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString(")", 1));
    }
  }

  RubyObject* cr_class_def(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_class_def\n"); std::abort();
    return nullptr;
  }

  bool has_initialize_q(auto body) {
    if (!(body)) {
      return false;
    }
    if ((body == INT64_C(0) /* ::Sequence */)) {
      return body.nodes().any_q();
    } else if ((body == INT64_C(0) /* ::MethodDef */)) {
      return (body.name() == ruby_sym("initialize"));
    } else {
      return false;
    }
  }

  RubyObject* cr_module_def(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_module_def\n"); std::abort();
    return nullptr;
  }

  RubyObject* write() {
    std::fprintf(stderr, "frozone: called TI-gap stub write\n"); std::abort();
    return nullptr;
  }

  RubyObject* line(auto str) {
    std::fprintf(stderr, "frozone: called TI-gap stub line\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_indent() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_indent\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_newline() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_newline\n"); std::abort();
    return nullptr;
  }

  int64_t indented() {
    iv_indent = (iv_indent + INT64_C(1));
    _block();
    return iv_indent = (iv_indent - INT64_C(1));
  }

  RubyObject* crystal_constant(auto sym_or_str) {
    std::fprintf(stderr, "frozone: called TI-gap stub crystal_constant\n"); std::abort();
    return nullptr;
  }

  RubyObject* crystal_string_literal(auto str) {
    std::fprintf(stderr, "frozone: called TI-gap stub crystal_string_literal\n"); std::abort();
    return nullptr;
  }

  RubyObject* crystal_method_name(auto sym) {
    std::fprintf(stderr, "frozone: called TI-gap stub crystal_method_name\n"); std::abort();
    return nullptr;
  }

  RubyObject* crystal_local(auto sym) {
    std::fprintf(stderr, "frozone: called TI-gap stub crystal_local\n"); std::abort();
    return nullptr;
  }

  RubyObject* codegen_inline(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub codegen_inline\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_cvars(auto node, auto seen) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_cvars\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_ivars(auto node, auto seen) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_ivars\n"); std::abort();
    return nullptr;
  }

  RubyString unsupported_b(auto node, auto msg = RUBY_NIL) {
    std::decay_t<decltype(ruby_class(node).name().split(RubyString("::", 2)).last())> name{};
    RubyString message;
    (name = ruby_class(node).name().split(RubyString("::", 2)).last());
    (message = (msg ? ((ruby_to_s(name) + RubyString(": ", 2) + ruby_to_s(msg))) : (name)));
    (iv_errors << message);
    return RubyString("RUBY_NIL", 8);
  }

};
template<> inline const char* ruby_class_name<Ruby_CrystalEmitter>() { return "CrystalEmitter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_CrystalEmitter> : dustman::FieldList<Ruby_CrystalEmitter, &Ruby_CrystalEmitter::iv_user_methods, &Ruby_CrystalEmitter::iv_exception_classes> {};
#endif

struct Ruby_TypeMapper : public RubyObject {
  RubyHash<RubySymbol, int64_t> iv_local_types;
  RubyHash<RubySymbol, int64_t> iv_locals;
  RubyHash<RubySymbol, int64_t> iv_arrays;
  RubyHash<RubySymbol, int64_t> iv_class_locals;
  RubyHash<RubySymbol, int64_t> iv_local_array_elems;
  RubyHash<RubySymbol, int64_t> iv_block_params;
  RubyHash<RubySymbol, int64_t> iv_class_params;
  RubyHash<RubySymbol, int64_t> iv_inferred_params;
  RubyHash<RubySymbol, int64_t> iv_typed_params;
  RubyHash<RubySymbol, int64_t> iv_typed_method_returns;
  RubyHash<RubySymbol, int64_t> iv_instance_method_raw_returns;
  RubyHash<RubySymbol, int64_t> iv_const_raw_types;
  RubyHash<RubySymbol, int64_t> iv_typed_ivars;
  gc_ref<RubyObject> iv_user_class_names = nullptr;
  gc_ref<Ruby_TypeEnv> iv_env;
  gc_ref<RubyObject> iv_user_methods = nullptr;
  gc_ref<RubyObject> iv_user_classes = nullptr;
  gc_ref<RubyObject> iv_opt_flags = nullptr;

  Ruby_TypeMapper() = default;
  Ruby_TypeMapper(auto env, auto user_methods, auto user_classes, auto opt_flags) {
    iv_env = env;
    iv_user_methods = user_methods;
    iv_user_classes = user_classes;
    iv_opt_flags = opt_flags;
    iv_user_class_names = user_classes.keys().to_set();
    iv_local_types = RubyHash<RubySymbol, int64_t>{};
    iv_locals = RubyHash<RubySymbol, int64_t>{};
    iv_arrays = RubyHash<RubySymbol, int64_t>{};
    iv_class_locals = RubyHash<RubySymbol, int64_t>{};
    iv_local_array_elems = RubyHash<RubySymbol, int64_t>{};
    iv_block_params = RubyHash<RubySymbol, int64_t>{};
    iv_class_params = RubyHash<RubySymbol, int64_t>{};
    iv_inferred_params = RubyHash<RubySymbol, int64_t>{};
    iv_typed_params = RubyHash<RubySymbol, int64_t>{};
    iv_typed_method_returns = RubyHash<RubySymbol, int64_t>{};
    iv_instance_method_raw_returns = RubyHash<RubySymbol, int64_t>{};
    iv_const_raw_types = RubyHash<RubySymbol, int64_t>{};
    iv_typed_ivars = RubyHash<RubySymbol, int64_t>{};
  }
  const char* rb_class_name() const override { return "TypeMapper"; }

  RubyHash<RubySymbol, int64_t> local_types() {
    return iv_local_types;
  }

  RubyHash<RubySymbol, int64_t> locals() {
    return iv_locals;
  }

  RubyHash<RubySymbol, int64_t> arrays() {
    return iv_arrays;
  }

  RubyHash<RubySymbol, int64_t> class_locals() {
    return iv_class_locals;
  }

  RubyHash<RubySymbol, int64_t> local_array_elems() {
    return iv_local_array_elems;
  }

  RubyHash<RubySymbol, int64_t> block_params() {
    return iv_block_params;
  }

  RubyHash<RubySymbol, int64_t> class_params() {
    return iv_class_params;
  }

  RubyHash<RubySymbol, int64_t> inferred_params() {
    return iv_inferred_params;
  }

  RubyHash<RubySymbol, int64_t> typed_params() {
    return iv_typed_params;
  }

  RubyHash<RubySymbol, int64_t> typed_method_returns() {
    return iv_typed_method_returns;
  }

  RubyHash<RubySymbol, int64_t> instance_method_raw_returns() {
    return iv_instance_method_raw_returns;
  }

  RubyHash<RubySymbol, int64_t> const_raw_types() {
    return iv_const_raw_types;
  }

  RubyHash<RubySymbol, int64_t> typed_ivars() {
    return iv_typed_ivars;
  }

  RubyObject* user_class_names() {
    std::fprintf(stderr, "frozone: called TI-gap stub user_class_names\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_b() {
    std::fprintf(stderr, "frozone: called TI-gap stub build_b\n"); std::abort();
    return nullptr;
  }

  RubyObject* opt_q(auto flag) {
    std::fprintf(stderr, "frozone: called TI-gap stub opt_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* unpack_slots() {
    std::fprintf(stderr, "frozone: called TI-gap stub unpack_slots\n"); std::abort();
    return nullptr;
  }

  RubyNil unpack_local(auto slot, auto ty) {
    std::decay_t<decltype(slot[INT64_C(1)])> mkey{};
    std::decay_t<decltype(slot[INT64_C(2)])> name{};
    std::decay_t<decltype(Type.from_ti(ty))> ct{};
    std::decay_t<decltype(ty.class_name())> cls{};
    auto _t1_0 = slot[INT64_C(1)];
    auto _t1_1 = slot[INT64_C(2)];
    mkey = _t1_0;
    name = _t1_1;
    (ct = Type.from_ti(ty));
    (ct.bottom_q() ? (RUBY_NIL) : (/* UNSUPPORTED: IndexOrWrite */[name] = ct));
    if (({ auto _l = (ty.class_type_q()); (_l) ? decltype((opt_q(ruby_sym("devirtualize"))))(opt_q(ruby_sym("devirtualize"))) : decltype((opt_q(ruby_sym("devirtualize"))))(_l); })) {
      (cls = ty.class_name());
      auto skip_builtin = ({ auto _e0 = ruby_sym("Object"); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = ruby_sym("BasicObject"); _a[2] = ruby_sym("Numeric"); _a[3] = ruby_sym("Array"); _a[4] = ruby_sym("Hash"); _a; }).include_q(cls);
      if (({ auto _l = ((!(skip_builtin))); (_l) ? decltype((({ auto _l = (iv_user_class_names->include_q(cls)); (_l) ? decltype((INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)))(_l) : (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)); })))(({ auto _l = (iv_user_class_names->include_q(cls)); (_l) ? decltype((INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)))(_l) : (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)); })) : decltype((({ auto _l = (iv_user_class_names->include_q(cls)); (_l) ? decltype((INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)))(_l) : (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls)); })))(_l); })) {
      /* UNSUPPORTED: IndexOrWrite */[name] = (ty.nullable_q() ? (({ auto _e0 = cls; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("nullable"); _a; })) : (cls));
    };
    }
    if (({ auto _l = (({ auto _l = (ty.array_q()); (_l) ? decltype((opt_q(ruby_sym("native_arrays"))))(opt_q(ruby_sym("native_arrays"))) : decltype((opt_q(ruby_sym("native_arrays"))))(_l); })); (_l) ? decltype((ty.elem().raw_q()))(ty.elem().raw_q()) : decltype((ty.elem().raw_q()))(_l); })) {
      /* UNSUPPORTED: IndexOrWrite */[name] = ty.elem();
    }
    if (({ auto _l = (opt_q(ruby_sym("unbox_locals"))); (_l) ? decltype((ty.raw_q()))(ty.raw_q()) : decltype((ty.raw_q()))(_l); })) {
      return /* UNSUPPORTED: IndexOrWrite */[name] = ty;
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* unpack_block_param(auto slot, auto ty) {
    std::fprintf(stderr, "frozone: called TI-gap stub unpack_block_param\n"); std::abort();
    return nullptr;
  }

  RubyObject* unpack_array_elem(auto slot, auto ty) {
    std::fprintf(stderr, "frozone: called TI-gap stub unpack_array_elem\n"); std::abort();
    return nullptr;
  }

  RubyNil unpack_const(auto slot, auto ty) {
    if (!(opt_q(ruby_sym("unbox_locals")))) {
      return RubyNil(RUBY_NIL);
    }
    if (ty.raw_q()) {
      iv_const_raw_types[slot[INT64_C(1)]] = ty;
      return RubyNil(RUBY_NIL);
    }
    if (({ auto _l = (ty.array_q()); (_l) ? decltype((ty.elem().raw_q()))(ty.elem().raw_q()) : decltype((ty.elem().raw_q()))(_l); })) {
      return iv_const_raw_types[slot[INT64_C(1)]] = (ty.elem().f64_q() ? (INT64_C(0) /* ::ARRAY_F64 */) : (INT64_C(0) /* ::ARRAY_I64 */));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil unpack_ivar(auto slot, auto ty) {
    if (!(opt_q(ruby_sym("typed_ivars")))) {
      return RubyNil(RUBY_NIL);
    }
    if (ty.raw_q()) {
      /* UNSUPPORTED: IndexOrWrite */[slot[INT64_C(2)]] = ty;
      return RubyNil(RUBY_NIL);
    }
    if (({ auto _l = (ty.array_q()); (_l) ? decltype((ty.elem().raw_q()))(ty.elem().raw_q()) : decltype((ty.elem().raw_q()))(_l); })) {
      return /* UNSUPPORTED: IndexOrWrite */[slot[INT64_C(2)]] = (ty.elem().f64_q() ? (INT64_C(0) /* ::ARRAY_F64 */) : (INT64_C(0) /* ::ARRAY_I64 */));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil unpack_return(auto slot, auto ty) {
    std::decay_t<decltype(slot[INT64_C(1)])> mkey{};
    std::decay_t<decltype(ty)> raw{};
    std::decay_t<decltype(iv_typed_params[mkey])> params{};
    if (!(({ auto _l = (({ auto _l = (opt_q(ruby_sym("method_specialization"))); (_l) ? decltype((opt_q(ruby_sym("raw_returns"))))(_l) : (opt_q(ruby_sym("raw_returns"))); })); (_l) ? decltype((opt_q(ruby_sym("accessor_inline"))))(_l) : (opt_q(ruby_sym("accessor_inline"))); }))) {
      return RubyNil(RUBY_NIL);
    }
    if (!(ty.raw_q())) {
      return RubyNil(RUBY_NIL);
    }
    (mkey = slot[INT64_C(1)]);
    (raw = ty);
    if (true) {
      return (params = iv_typed_params[mkey]); if (({ auto _l = (params); (_l) ? decltype((params.any_q()))(params.any_q()) : decltype((params.any_q()))(_l); })) {
        return RubyNil(RUBY_NIL);
      }; iv_typed_method_returns[mkey] = raw;
    } else {
      if (({ auto _l = (true); (_l) ? decltype(((mkey.len() == INT64_C(2))))((mkey.len() == INT64_C(2))) : decltype(((mkey.len() == INT64_C(2))))(_l); })) {
        return ({ auto _masgn = mkey; auto cname = _masgn[INT64_C(0)]; auto fname = _masgn[INT64_C(1)]; }); if (iv_user_class_names->include_q(cname)) {
          (params = iv_class_params[mkey]);
          (({ auto _l = (({ auto _l = (params); (_l) ? decltype((params.any_q()))(params.any_q()) : decltype((params.any_q()))(_l); })); (_l) ? decltype((params.any_q()))(params.any_q()) : decltype((params.any_q()))(_l); }) ? (RUBY_NIL) : (iv_instance_method_raw_returns[({ auto _e0 = cname; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = fname; _a; })] = raw));
        };
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* build_top_level_params() {
    std::fprintf(stderr, "frozone: called TI-gap stub build_top_level_params\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_eigenclass_params() {
    std::fprintf(stderr, "frozone: called TI-gap stub build_eigenclass_params\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_class_params() {
    std::fprintf(stderr, "frozone: called TI-gap stub build_class_params\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_method_params(auto klass, auto cname) {
    std::fprintf(stderr, "frozone: called TI-gap stub build_method_params\n"); std::abort();
    return nullptr;
  }

  RubyNil raw_type(auto ty) {
    if (ty.raw_q()) {
      return ty;
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

};
template<> inline const char* ruby_class_name<Ruby_TypeMapper>() { return "TypeMapper"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TypeMapper> : dustman::FieldList<Ruby_TypeMapper, &Ruby_TypeMapper::iv_env> {};
#endif

struct Ruby_Type : public RubyObject {
  RubySymbol iv_kind;
  RubyNil iv_class_name;
  RubyNil iv_elem;
  RubyNil iv_key;
  RubyNil iv_val;
  RubyNil iv_int_min;
  RubyNil iv_int_max;
  bool iv_nullable = false;
  bool iv_exact = false;

  Ruby_Type() = default;
  Ruby_Type(auto kind, int64_t class_name = RUBY_NIL, bool nullable = false, bool exact = false, int64_t elem = RUBY_NIL, int64_t key = RUBY_NIL, int64_t val = RUBY_NIL, int64_t int_min = RUBY_NIL, int64_t int_max = RUBY_NIL) {
    iv_kind = kind;
    iv_class_name = class_name;
    iv_nullable = nullable;
    iv_exact = exact;
    iv_elem = elem;
    iv_key = key;
    iv_val = val;
    iv_int_min = int_min;
    iv_int_max = int_max;
    0LL;
  }
  const char* rb_class_name() const override { return "Type"; }

  RubySymbol kind() {
    return iv_kind;
  }

  RubyNil class_name() {
    return iv_class_name;
  }

  RubyNil elem() {
    return iv_elem;
  }

  RubyNil key() {
    return iv_key;
  }

  RubyNil val() {
    return iv_val;
  }

  RubyNil int_min() {
    return iv_int_min;
  }

  RubyNil int_max() {
    return iv_int_max;
  }

  RubyArray<RubyNil> int_bounds() {
    if (!(({ auto _l = (({ auto _l = ((iv_kind == ruby_sym("i64"))); (_l) ? decltype((iv_int_min))(iv_int_min) : decltype((iv_int_min))(_l); })); (_l) ? decltype((iv_int_max))(iv_int_max) : decltype((iv_int_max))(_l); }))) {
      return RubyArray<RubyNil>(RUBY_NIL);
    }
    return ({ auto _e0 = iv_int_min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_int_max; _a; });
  }

  RubyString narrowest_int_type() {
    RubyArray<int64_t> b;
    if (!((b = int_bounds()))) {
      return RubyString(RUBY_NIL);
    }
    auto _masgn2 = b;
    auto min = _masgn2[INT64_C(0)];
    auto max = _masgn2[INT64_C(1)];
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

  RubyObject* bottom_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub bottom_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* i64_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub i64_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* f64_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub f64_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* raw_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub raw_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* array_scalar_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub array_scalar_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* class_type_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub class_type_q\n"); std::abort();
    return nullptr;
  }

  bool nullable_q() {
    return iv_nullable;
  }

  bool exact_q() {
    return iv_exact;
  }

  RubyObject* numeric_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub numeric_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* array_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub array_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* array_like_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub array_like_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* hash_type_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub hash_type_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* nil_type_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub nil_type_q\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> contains_gc_refs_q() {
    if ((iv_kind == ruby_sym("bottom")) || (iv_kind == ruby_sym("i64")) || (iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(false);
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      if (iv_elem) {
        return coerce_to_ref<RubyObject>(iv_elem.contains_gc_refs_q());
      } else {
        return coerce_to_ref<RubyObject>(false);
      }
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>(if (VALUE_TYPED_BUILTINS.include_q(iv_class_name)) {
        return false;
      }; if (NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)) {
        return false;
      }; ({ auto _cs = iv_class_name; ((_cs == ruby_sym("Array"))) ? ((iv_elem ? (iv_elem.contains_gc_refs_q()) : (false))) : (((_cs == ruby_sym("Hash"))) ? (({ auto _l = (({ auto _l = (({ auto _l = (iv_key); (_l) ? decltype((iv_key.contains_gc_refs_q()))(iv_key.contains_gc_refs_q()) : decltype((iv_key.contains_gc_refs_q()))(_l); })); (_l) ? decltype((({ auto _l = (iv_val); (_l) ? decltype((iv_val.contains_gc_refs_q()))(iv_val.contains_gc_refs_q()) : decltype((iv_val.contains_gc_refs_q()))(_l); })))(_l) : (({ auto _l = (iv_val); (_l) ? decltype((iv_val.contains_gc_refs_q()))(iv_val.contains_gc_refs_q()) : decltype((iv_val.contains_gc_refs_q()))(_l); })); })); (_l) ? decltype((false))(_l) : (false); })) : (((_cs == RUBY_NIL)) ? (false) : (true))); }));
    }
    return RUBY_NIL;
  }

  gc_ref<RubyObject> ruby_object_convertible_q() {
    if ((iv_kind == ruby_sym("bottom")) || (iv_kind == ruby_sym("i64")) || (iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(true);
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      return coerce_to_ref<RubyObject>(true);
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>(if (NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)) {
        return false;
      }; true);
    }
    return RUBY_NIL;
  }

  gc_ref<RubyObject> user_class_pointer_q() {
    if (!(class_type_q())) {
      return false;
    }
    if (ruby_nil_q(iv_class_name)) {
      return false;
    }
    if (VALUE_TYPED_BUILTINS.include_q(iv_class_name)) {
      return false;
    }
    if (NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)) {
      return false;
    }
    if (({ auto _e0 = ruby_sym("Object"); auto _a = RubyArray<decltype(_e0)>(4); _a[0] = _e0; _a[1] = ruby_sym("BasicObject"); _a[2] = ruby_sym("Array"); _a[3] = ruby_sym("Hash"); _a; }).include_q(iv_class_name)) {
      return false;
    }
    return coerce_to_ref<RubyObject>(true);
  }

  gc_ref<RubyObject> emitted_as_pointer_q() {
    if (!(class_type_q())) {
      return false;
    }
    if (ruby_nil_q(iv_class_name)) {
      return false;
    }
    if (VALUE_TYPED_BUILTINS.include_q(iv_class_name)) {
      return false;
    }
    if (({ auto _e0 = ruby_sym("Array"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Hash"); _a; }).include_q(iv_class_name)) {
      return false;
    }
    return coerce_to_ref<RubyObject>(true);
  }

  bool renders_as_optional_q() {
    if (!(nullable_q())) {
      return false;
    }
    return ({ auto _l = (({ auto _l = (i64_q()); (_l) ? decltype((f64_q()))(_l) : (f64_q()); })); (_l) ? decltype((({ auto _l = (class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)))(_l); })))(_l) : (({ auto _l = (class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a[2] = ruby_sym("Numeric"); _a; }).include_q(iv_class_name)))(_l); })); });
  }

  bool operator==(auto other) {
    if (!(true)) {
      return false;
    }
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = ((iv_kind == other.kind())); (_l) ? decltype(((iv_class_name == other.class_name())))((iv_class_name == other.class_name())) : decltype(((iv_class_name == other.class_name())))(_l); })); (_l) ? decltype(((iv_nullable == other.nullable_q())))((iv_nullable == other.nullable_q())) : decltype(((iv_nullable == other.nullable_q())))(_l); })); (_l) ? decltype(((iv_exact == other.exact_q())))((iv_exact == other.exact_q())) : decltype(((iv_exact == other.exact_q())))(_l); })); (_l) ? decltype(((iv_elem == other.elem())))((iv_elem == other.elem())) : decltype(((iv_elem == other.elem())))(_l); })); (_l) ? decltype(((iv_key == other.key())))((iv_key == other.key())) : decltype(((iv_key == other.key())))(_l); })); (_l) ? decltype(((iv_val == other.val())))((iv_val == other.val())) : decltype(((iv_val == other.val())))(_l); })); (_l) ? decltype(((iv_int_min == other.int_min())))((iv_int_min == other.int_min())) : decltype(((iv_int_min == other.int_min())))(_l); })); (_l) ? decltype(((iv_int_max == other.int_max())))((iv_int_max == other.int_max())) : decltype(((iv_int_max == other.int_max())))(_l); });
  }

  bool eql_q(auto other) {
    if (!(true)) {
      return false;
    }
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = ((iv_kind == other.kind())); (_l) ? decltype(((iv_class_name == other.class_name())))((iv_class_name == other.class_name())) : decltype(((iv_class_name == other.class_name())))(_l); })); (_l) ? decltype(((iv_nullable == other.nullable_q())))((iv_nullable == other.nullable_q())) : decltype(((iv_nullable == other.nullable_q())))(_l); })); (_l) ? decltype(((iv_exact == other.exact_q())))((iv_exact == other.exact_q())) : decltype(((iv_exact == other.exact_q())))(_l); })); (_l) ? decltype(((iv_elem == other.elem())))((iv_elem == other.elem())) : decltype(((iv_elem == other.elem())))(_l); })); (_l) ? decltype(((iv_key == other.key())))((iv_key == other.key())) : decltype(((iv_key == other.key())))(_l); })); (_l) ? decltype(((iv_val == other.val())))((iv_val == other.val())) : decltype(((iv_val == other.val())))(_l); })); (_l) ? decltype(((iv_int_min == other.int_min())))((iv_int_min == other.int_min())) : decltype(((iv_int_min == other.int_min())))(_l); })); (_l) ? decltype(((iv_int_max == other.int_max())))((iv_int_max == other.int_max())) : decltype(((iv_int_max == other.int_max())))(_l); });
  }

  RubyObject* hash() {
    std::fprintf(stderr, "frozone: called TI-gap stub hash\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> inspect() {
    RubyArray<int64_t> parts;
    if ((iv_kind == ruby_sym("bottom"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::BOTTOM", 12));
    } else if ((iv_kind == ruby_sym("i64"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::I64", 9));
    } else if ((iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::F64", 9));
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      return coerce_to_ref<RubyObject>((RubyString("Type::", 6) + ruby_to_s((iv_elem.i64_q() ? (RubyString("ARRAY_I64", 9)) : (RubyString("ARRAY_F64", 9))))));
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>((parts = ({ auto _e0 = (RubyString("Type.of(:", 9) + ruby_to_s(iv_class_name)); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; })); if (iv_nullable) {
        (parts << RubyString("nullable: true", 14));
      }; if (iv_exact) {
        (parts << RubyString("exact: true", 11));
      }; if (iv_elem) {
        (parts << (RubyString("elem: ", 6) + ruby_to_s(iv_elem.inspect())));
      }; if (iv_key) {
        (parts << (RubyString("key: ", 5) + ruby_to_s(iv_key.inspect())));
      }; if (iv_val) {
        (parts << (RubyString("val: ", 5) + ruby_to_s(iv_val.inspect())));
      }; (parts.join(RubyString(", ", 2)) + RubyString(")", 1)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("Type(", 5) + ruby_to_s(iv_kind) + RubyString(")", 1)));
    }
  }

  gc_ref<RubyObject> to_s() {
    RubyArray<int64_t> parts;
    if ((iv_kind == ruby_sym("bottom"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::BOTTOM", 12));
    } else if ((iv_kind == ruby_sym("i64"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::I64", 9));
    } else if ((iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(RubyString("Type::F64", 9));
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      return coerce_to_ref<RubyObject>((RubyString("Type::", 6) + ruby_to_s((iv_elem.i64_q() ? (RubyString("ARRAY_I64", 9)) : (RubyString("ARRAY_F64", 9))))));
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>((parts = ({ auto _e0 = (RubyString("Type.of(:", 9) + ruby_to_s(iv_class_name)); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; })); if (iv_nullable) {
        (parts << RubyString("nullable: true", 14));
      }; if (iv_exact) {
        (parts << RubyString("exact: true", 11));
      }; if (iv_elem) {
        (parts << (RubyString("elem: ", 6) + ruby_to_s(iv_elem.inspect())));
      }; if (iv_key) {
        (parts << (RubyString("key: ", 5) + ruby_to_s(iv_key.inspect())));
      }; if (iv_val) {
        (parts << (RubyString("val: ", 5) + ruby_to_s(iv_val.inspect())));
      }; (parts.join(RubyString(", ", 2)) + RubyString(")", 1)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("Type(", 5) + ruby_to_s(iv_kind) + RubyString(")", 1)));
    }
  }

  RubyObject* to_crystal() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_crystal\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> to_cpp(int64_t wrapper = RUBY_NIL) {
    RubyString elem_cpp;
    if ((iv_kind == ruby_sym("bottom"))) {
      return coerce_to_ref<RubyObject>(RubyString("auto", 4));
    } else if ((iv_kind == ruby_sym("i64"))) {
      if (nullable_q()) {
        return coerce_to_ref<RubyObject>(RubyString("std::optional<int64_t>", 22));
      } else {
        return coerce_to_ref<RubyObject>(RubyString("int64_t", 7));
      }
    } else if ((iv_kind == ruby_sym("f64"))) {
      if (nullable_q()) {
        return coerce_to_ref<RubyObject>(RubyString("std::optional<double>", 21));
      } else {
        return coerce_to_ref<RubyObject>(RubyString("double", 6));
      }
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      return coerce_to_ref<RubyObject>((elem_cpp = (iv_elem.i64_q() ? (RubyString("int64_t", 7)) : (RubyString("double", 6)))); (RubyString("RubyArray<", 10) + ruby_to_s(elem_cpp) + RubyString(">", 1)));
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>(class_to_cpp());
    } else {
      return coerce_to_ref<RubyObject>(RubyString("auto", 4));
    }
  }

  RubyObject* to_cpp_ref() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_cpp_ref\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_cpp_local() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_cpp_local\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> class_to_cpp(int64_t wrapper = RUBY_NIL) {
    RubyString elem_cpp;
    RubyString key_cpp;
    RubyString val_cpp;
    if ((iv_class_name == ruby_sym("Integer")) || (iv_class_name == ruby_sym("Numeric"))) {
      if (nullable_q()) {
        return coerce_to_ref<RubyObject>(RubyString("std::optional<int64_t>", 22));
      } else {
        return coerce_to_ref<RubyObject>(RubyString("int64_t", 7));
      }
    } else if ((iv_class_name == ruby_sym("Float"))) {
      if (nullable_q()) {
        return coerce_to_ref<RubyObject>(RubyString("std::optional<double>", 21));
      } else {
        return coerce_to_ref<RubyObject>(RubyString("double", 6));
      }
    } else if ((iv_class_name == ruby_sym("String"))) {
      return coerce_to_ref<RubyObject>(RubyString("RubyString", 10));
    } else if ((iv_class_name == ruby_sym("Symbol"))) {
      return coerce_to_ref<RubyObject>(RubyString("RubySymbol", 10));
    } else if ((iv_class_name == ruby_sym("Array"))) {
      return coerce_to_ref<RubyObject>((elem_cpp = (iv_elem ? (iv_elem.to_cpp()) : (RubyString("int64_t", 7)))); if ((elem_cpp == RubyString("auto", 4))) {
        (elem_cpp = RubyString("int64_t", 7));
      }; (RubyString("RubyArray<", 10) + ruby_to_s(elem_cpp) + RubyString(">", 1)));
    } else if ((iv_class_name == ruby_sym("Hash"))) {
      return coerce_to_ref<RubyObject>((key_cpp = (iv_key ? (iv_key.to_cpp()) : (RubyString("RubySymbol", 10)))); if ((key_cpp == RubyString("auto", 4))) {
        (key_cpp = RubyString("RubySymbol", 10));
      }; (val_cpp = (iv_val ? (iv_val.to_cpp()) : (RubyString("int64_t", 7)))); if ((val_cpp == RubyString("auto", 4))) {
        (val_cpp = RubyString("int64_t", 7));
      }; (RubyString("RubyHash<", 9) + ruby_to_s(key_cpp) + RubyString(", ", 2) + ruby_to_s(val_cpp) + RubyString(">", 1)));
    } else if ((iv_class_name == ruby_sym("NilClass"))) {
      return coerce_to_ref<RubyObject>(RubyString("RubyNil", 7));
    } else if ((iv_class_name == ruby_sym("TrueClass")) || (iv_class_name == ruby_sym("FalseClass"))) {
      return coerce_to_ref<RubyObject>(RubyString("bool", 4));
    } else if ((iv_class_name == RUBY_NIL)) {
      return coerce_to_ref<RubyObject>(RubyString("auto", 4));
    } else if ((iv_class_name == ruby_sym("Object")) || (iv_class_name == ruby_sym("BasicObject"))) {
      if (wrapper) {
        return coerce_to_ref<RubyObject>((ruby_to_s(wrapper) + RubyString("<RubyObject>", 12)));
      } else {
        return coerce_to_ref<RubyObject>(RubyString("RubyObject*", 11));
      }
    } else if ((iv_class_name == ruby_sym("Tree"))) {
      return coerce_to_ref<RubyObject>(RubyString("RubyTree", 8));
    } else {
      if (({ auto _l = (wrapper); (_l) ? decltype(((!(NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)))))((!(NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)))) : decltype(((!(NON_GC_BUILTIN_CLASSES.include_q(iv_class_name)))))(_l); })) {
        return coerce_to_ref<RubyObject>((ruby_to_s(wrapper) + RubyString("<Ruby_", 6) + ruby_to_s(iv_class_name) + RubyString(">", 1)));
      } else {
        return coerce_to_ref<RubyObject>((RubyString("Ruby_", 5) + ruby_to_s(iv_class_name) + RubyString("*", 1)));
      }
    }
  }

  RubyObject* to_crystal_storage() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_crystal_storage\n"); std::abort();
    return nullptr;
  }

  RubyObject* native_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub native_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* generic_compatible_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub generic_compatible_q\n"); std::abort();
    return nullptr;
  }

  RubyNil class_to_crystal() {
    if (({ auto _l = (array_q()); (_l) ? decltype((iv_elem.native_q()))(iv_elem.native_q()) : decltype((iv_elem.native_q()))(_l); })) {
      return (RubyString("Array(", 6) + ruby_to_s(iv_elem.to_crystal_storage()) + RubyString(")", 1));
    }
    return ({ auto _l = (CRYSTAL_CLASS_NAMES[iv_class_name]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(iv_class_name))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(iv_class_name))); });
  }

  gc_ref<RubyObject> to_legacy() {
    RubyHash<RubySymbol, RubyNil> h;
    if ((iv_kind == ruby_sym("bottom"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("unknown"));
    } else if ((iv_kind == ruby_sym("i64"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("i64"));
    } else if ((iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("f64"));
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      if (iv_elem.i64_q()) {
        return coerce_to_ref<RubyObject>(ruby_sym("array_i64"));
      } else {
        return coerce_to_ref<RubyObject>(ruby_sym("array_f64"));
      }
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>((h = ({ RubyHash<RubySymbol, RubyNil> _h; _h.store(ruby_sym("class"), iv_class_name); _h; })); if (iv_nullable) {
        h[ruby_sym("nullable")] = true;
      }; if (iv_exact) {
        h[ruby_sym("exact")] = true;
      }; if (iv_elem) {
        h[ruby_sym("elem")] = iv_elem.to_legacy();
      }; if (iv_key) {
        h[ruby_sym("key")] = iv_key.to_legacy();
      }; if (iv_val) {
        h[ruby_sym("val")] = iv_val.to_legacy();
      }; h);
    }
    return RUBY_NIL;
  }

  gc_ref<RubyObject> boxed_class_name() {
    if ((iv_kind == ruby_sym("i64"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("Integer"));
    } else if ((iv_kind == ruby_sym("f64"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("Float"));
    } else if ((iv_kind == ruby_sym("array_scalar"))) {
      return coerce_to_ref<RubyObject>(ruby_sym("Array"));
    } else if ((iv_kind == ruby_sym("class_type"))) {
      return coerce_to_ref<RubyObject>(iv_class_name);
    } else {
      return coerce_to_ref<RubyObject>(ruby_sym("Object"));
    }
  }

  RubyObject* to_class_type() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_class_type\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Type> merge_params(auto other) {
    bool new_nullable = false;
    RubySymbol new_elem;
    RubySymbol new_key;
    RubySymbol new_val;
    (new_nullable = ({ auto _l = (iv_nullable); (_l) ? decltype((other.nullable_q()))(_l) : (other.nullable_q()); }));
    (new_elem = merge_param(iv_elem, other.elem()));
    (new_key = merge_param(iv_key, other.key()));
    (new_val = merge_param(iv_val, other.val()));
    if (({ auto _l = (({ auto _l = (({ auto _l = ((new_nullable == iv_nullable)); (_l) ? decltype((new_elem.equal_q(iv_elem)))(new_elem.equal_q(iv_elem)) : decltype((new_elem.equal_q(iv_elem)))(_l); })); (_l) ? decltype((new_key.equal_q(iv_key)))(new_key.equal_q(iv_key)) : decltype((new_key.equal_q(iv_key)))(_l); })); (_l) ? decltype((new_val.equal_q(iv_val)))(new_val.equal_q(iv_val)) : decltype((new_val.equal_q(iv_val)))(_l); })) {
      return (*this);
    } else {
      if (({ auto _l = (({ auto _l = (({ auto _l = ((new_nullable == other.nullable_q())); (_l) ? decltype((new_elem.equal_q(other.elem())))(new_elem.equal_q(other.elem())) : decltype((new_elem.equal_q(other.elem())))(_l); })); (_l) ? decltype((new_key.equal_q(other.key())))(new_key.equal_q(other.key())) : decltype((new_key.equal_q(other.key())))(_l); })); (_l) ? decltype((new_val.equal_q(other.val())))(new_val.equal_q(other.val())) : decltype((new_val.equal_q(other.val())))(_l); })) {
        return other;
      } else {
        return gc_new<Ruby_Type>(ruby_sym("class_type"));
      }
    }
  }

  RubySymbol merge_param(auto a, auto b) {
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

  static RubyObject* union_representation(auto types) {
    std::fprintf(stderr, "frozone: called TI-gap stub union_representation\n"); std::abort();
    return nullptr;
  }

  static RubyObject* of(auto class_name, auto nullable, auto exact) {
    std::fprintf(stderr, "frozone: called TI-gap stub of\n"); std::abort();
    return nullptr;
  }

  static RubyObject* array(auto elem) {
    std::fprintf(stderr, "frozone: called TI-gap stub array\n"); std::abort();
    return nullptr;
  }

  static RubyObject* i64_bounded(auto min, auto max) {
    std::fprintf(stderr, "frozone: called TI-gap stub i64_bounded\n"); std::abort();
    return nullptr;
  }

  static RubyObject* hash_type(auto key, auto val) {
    std::fprintf(stderr, "frozone: called TI-gap stub hash_type\n"); std::abort();
    return nullptr;
  }

  static RubyObject* nullable(auto type) {
    std::fprintf(stderr, "frozone: called TI-gap stub nullable\n"); std::abort();
    return nullptr;
  }

  static RubyObject* from_ti(auto ty, auto user_class_names) {
    std::fprintf(stderr, "frozone: called TI-gap stub from_ti\n"); std::abort();
    return nullptr;
  }

  static RubyObject* from_legacy(auto v) {
    std::fprintf(stderr, "frozone: called TI-gap stub from_legacy\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Type>() { return "Type"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Type> : dustman::FieldList<Ruby_Type> {};
#endif

struct Ruby_TypeEnv : public RubyObject {
  gc_ref<RubyObject> iv_typed_slots = nullptr;
  gc_ref<RubyObject> iv_ti = nullptr;

  Ruby_TypeEnv() = default;
  Ruby_TypeEnv(auto ti) {
    iv_typed_slots = RubyHash<RubySymbol, int64_t>{};
    iv_ti = ti;
  }
  const char* rb_class_name() const override { return "TypeEnv"; }

  RubySymbol raw(auto slot) {
    std::decay_t<decltype(iv_typed_slots->operator[](slot))> t{};
    (t = iv_typed_slots->operator[](slot));
    if (t) {
      return t.to_legacy();
    } else {
      return ruby_sym("unknown");
    }
  }

  RubyObject* typed_q(auto slot) {
    std::fprintf(stderr, "frozone: called TI-gap stub typed_q\n"); std::abort();
    return nullptr;
  }

  RubyNil operator[](auto slot) {
    std::decay_t<decltype(iv_typed_slots->operator[](slot))> t{};
    (t = iv_typed_slots->operator[](slot));
    if (t) {
      return t.to_legacy();
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* slots() {
    std::fprintf(stderr, "frozone: called TI-gap stub slots\n"); std::abort();
    return nullptr;
  }

  RubyObject* type_of(auto slot) {
    std::fprintf(stderr, "frozone: called TI-gap stub type_of\n"); std::abort();
    return nullptr;
  }

  RubyObject* type_at(auto slot) {
    std::fprintf(stderr, "frozone: called TI-gap stub type_at\n"); std::abort();
    return nullptr;
  }

  RubyObject* each_typed(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub each_typed\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> join_b(auto slot, auto type) {
    std::decay_t<decltype(iv_typed_slots->fetch(slot, INT64_C(0) /* ::BOTTOM */))> current{};
    std::decay_t<decltype(iv_ti->join(current, type))> merged{};
    if (!(type)) {
      return false;
    }
    (true ? (RUBY_NIL) : ((type = Type.from_legacy(type))));
    if (type.bottom_q()) {
      return false;
    }
    (current = iv_typed_slots->fetch(slot, INT64_C(0) /* ::BOTTOM */));
    (merged = iv_ti->join(current, type));
    if ((merged == current)) {
      return false;
    }
    iv_typed_slots[slot] = merged;
    return coerce_to_ref<RubyObject>(true);
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_TypeEnv>() { return "TypeEnv"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TypeEnv> : dustman::FieldList<Ruby_TypeEnv> {};
#endif

struct Ruby_TypeContext : public RubyObject {
  int64_t iv_method_key = 0;
  int64_t iv_class_name = 0;

  Ruby_TypeContext() = default;
  Ruby_TypeContext(auto _method_key, auto _class_name) {
    iv_method_key = _method_key;
    iv_class_name = _class_name;
  }
  const char* rb_class_name() const override { return "TypeContext"; }

  auto method_key() const { return iv_method_key; }
  void set_method_key(auto v) { iv_method_key = v; }
  auto class_name() const { return iv_class_name; }
  void set_class_name(auto v) { iv_class_name = v; }

};
template<> inline const char* ruby_class_name<Ruby_TypeContext>() { return "TypeContext"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TypeContext> : dustman::FieldList<Ruby_TypeContext> {};
#endif

struct Ruby_TypeInference : public RubyObject {
  gc_ref<RubyObject> iv_user_methods = nullptr;
  gc_ref<RubyObject> iv_user_classes = nullptr;
  gc_ref<RubyObject> iv_execute_block = nullptr;
  RubyHash<RubySymbol, int64_t> iv_constants;
  gc_ref<Ruby_TypeEnv> iv_env;
  RubyHash<RubySymbol, int64_t> iv_ancestors_cache;
  RubyHash<RubySymbol, int64_t> iv__assign_cache;
  RubyHash<RubySymbol, int64_t> iv__elem_write_cache;
  gc_ref<RubyObject> iv__expr_cache = nullptr;
  gc_ref<RubyObject> iv_ivar_param_seeds = nullptr;
  gc_ref<RubyObject> iv__widened_array_ivars = nullptr;

  Ruby_TypeInference() = default;
  Ruby_TypeInference(auto user_methods, auto user_classes, auto execute_block, RubyHash<RubySymbol, int64_t> constants = RubyHash<RubySymbol, int64_t>{}) {
    iv_user_methods = user_methods;
    iv_user_classes = user_classes;
    iv_execute_block = execute_block;
    iv_constants = constants;
    if (ENV[RubyString("TI_DBG_USERS", 12)]) {
      warn((RubyString("[TI_DBG] user_methods keys: ", 28) + ruby_to_s(user_methods.keys().inspect())));
    }
    iv_env = gc_new<Ruby_TypeEnv>((*this));
    iv_ancestors_cache = RubyHash<RubySymbol, int64_t>{};
    build_class_ancestors();
  }
  const char* rb_class_name() const override { return "TypeInference"; }

  gc_ref<Ruby_TypeEnv> env() {
    return iv_env;
  }

  gc_ref<RubyObject> join(auto a, auto b) {
    std::decay_t<decltype(a.int_bounds())> ab{};
    std::decay_t<decltype(b.int_bounds())> bb{};
    std::decay_t<decltype(a.merge_params(b))> merged{};
    if (a.bottom_q()) {
      return b;
    }
    if (b.bottom_q()) {
      return a;
    }
    if ((a == b)) {
      return a;
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (a.class_type_q()); (_l) ? decltype((b.class_type_q()))(b.class_type_q()) : decltype((b.class_type_q()))(_l); })); (_l) ? decltype(((a.class_name() == b.class_name())))((a.class_name() == b.class_name())) : decltype(((a.class_name() == b.class_name())))(_l); })); (_l) ? decltype((({ auto _e0 = ruby_sym("Array"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Hash"); _a; }).include_q(a.class_name())))(({ auto _e0 = ruby_sym("Array"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Hash"); _a; }).include_q(a.class_name())) : decltype((({ auto _e0 = ruby_sym("Array"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Hash"); _a; }).include_q(a.class_name())))(_l); })); (_l) ? decltype((({ auto _l = (type_contains_q(a, b)); (_l) ? decltype((type_contains_q(b, a)))(_l) : (type_contains_q(b, a)); })))(({ auto _l = (type_contains_q(a, b)); (_l) ? decltype((type_contains_q(b, a)))(_l) : (type_contains_q(b, a)); })) : decltype((({ auto _l = (type_contains_q(a, b)); (_l) ? decltype((type_contains_q(b, a)))(_l) : (type_contains_q(b, a)); })))(_l); })) {
      return widen_recursive(a, b);
    }
    if (({ auto _l = (a.i64_q()); (_l) ? decltype((b.i64_q()))(b.i64_q()) : decltype((b.i64_q()))(_l); })) {
      auto _t3_0 = a.int_bounds();
      auto _t3_1 = b.int_bounds();
      ab = _t3_0;
      bb = _t3_1;
      if (!(({ auto _l = (ab); (_l) ? decltype((bb))(bb) : decltype((bb))(_l); }))) {
      return INT64_C(0) /* ::I64 */;
    };
      return Type.i64_bounded((((ab[INT64_C(0)]) < (bb[INT64_C(0)])) ? (ab[INT64_C(0)]) : (bb[INT64_C(0)])), (((ab[INT64_C(1)]) > (bb[INT64_C(1)])) ? (ab[INT64_C(1)]) : (bb[INT64_C(1)])));
    }
    if (({ auto _l = (({ auto _l = (a.i64_q()); (_l) ? decltype((b.f64_q()))(b.f64_q()) : decltype((b.f64_q()))(_l); })); (_l) ? decltype((({ auto _l = (a.f64_q()); (_l) ? decltype((b.i64_q()))(b.i64_q()) : decltype((b.i64_q()))(_l); })))(_l) : (({ auto _l = (a.f64_q()); (_l) ? decltype((b.i64_q()))(b.i64_q()) : decltype((b.i64_q()))(_l); })); })) {
      return INT64_C(0) /* ::F64 */;
    }
    if (({ auto _l = (a.class_type_q()); (_l) ? decltype((b.class_type_q()))(b.class_type_q()) : decltype((b.class_type_q()))(_l); })) {
      int64_t int_like = /* UNSUPPORTED: Lambda */;
      if (({ auto _l = (({ auto _l = (int_like[a.class_name()]); (_l) ? decltype(((b.class_name() == ruby_sym("Float"))))((b.class_name() == ruby_sym("Float"))) : decltype(((b.class_name() == ruby_sym("Float"))))(_l); })); (_l) ? decltype((({ auto _l = (int_like[b.class_name()]); (_l) ? decltype(((a.class_name() == ruby_sym("Float"))))((a.class_name() == ruby_sym("Float"))) : decltype(((a.class_name() == ruby_sym("Float"))))(_l); })))(_l) : (({ auto _l = (int_like[b.class_name()]); (_l) ? decltype(((a.class_name() == ruby_sym("Float"))))((a.class_name() == ruby_sym("Float"))) : decltype(((a.class_name() == ruby_sym("Float"))))(_l); })); })) {
      return INT64_C(0) /* ::F64 */;
    };
    }
    if (({ auto _l = ((!(a.class_type_q()))); (_l) ? decltype(((!(b.class_type_q()))))(_l) : ((!(b.class_type_q()))); })) {
      return join(a.to_class_type(), b.to_class_type());
    }
    if ((a.class_name() == b.class_name())) {
      return coerce_to_ref<RubyObject>((merged = a.merge_params(b)); resolve_param_joins(a, b, merged));
    } else {
      if (a.nil_type_q()) {
        return coerce_to_ref<RubyObject>(Type.nullable(b));
      } else {
        if (b.nil_type_q()) {
          return coerce_to_ref<RubyObject>(Type.nullable(a));
        } else {
          return coerce_to_ref<RubyObject>(lca_type(a.class_name(), b.class_name()));
        }
      }
    }
  }

  gc_ref<RubyObject> type_contains_q(auto haystack, auto needle, auto seen = RUBY_NIL) {
    if (!(({ auto _l = (true); (_l) ? decltype((true))(true) : decltype((true))(_l); }))) {
      return false;
    }
    if ((haystack == needle)) {
      return true;
    }
    ({ auto _l = (seen); (_l) ? decltype(((seen = RubyHash<RubySymbol, int64_t>{})))(_l) : ((seen = RubyHash<RubySymbol, int64_t>{})); });
    if (seen[haystack.object_id()]) {
      return false;
    }
    seen[haystack.object_id()] = true;
    return coerce_to_ref<RubyObject>(({ auto _e0 = haystack.elem(); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = haystack.key(); _a[2] = haystack.val(); _a; }).any_q());
  }

  gc_ref<Ruby_Type> widen_recursive(auto a, auto b) {
    if (!(({ auto _l = (a.class_type_q()); (_l) ? decltype((b.class_type_q()))(b.class_type_q()) : decltype((b.class_type_q()))(_l); }))) {
      return INT64_C(0) /* ::BASIC_OBJECT */;
    }
    if (!((a.class_name() == b.class_name()))) {
      return INT64_C(0) /* ::BASIC_OBJECT */;
    }
    if ((a.class_name() == ruby_sym("Array"))) {
      return Type.array();
    } else if ((a.class_name() == ruby_sym("Hash"))) {
      return gc_new<Ruby_Type>(ruby_sym("class_type"));
    } else {
      return INT64_C(0) /* ::BASIC_OBJECT */;
    }
  }

  gc_ref<Ruby_TypeEnv> run(int64_t iterations = INT64_C(10)) {
    bool changed = false;
    RubyNil pattern;
    seed_constants();
    iv__assign_cache = RubyHash<RubySymbol, int64_t>{};
    iv__elem_write_cache = RubyHash<RubySymbol, int64_t>{};
    for (int64_t _i = 0; _i < iterations; _i++) {
      (changed = false);
      iv__expr_cache = RubyHash<RubySymbol, int64_t>{};
      (changed = (changed | update_call_sites(iv_execute_block->body(), TOP_LEVEL_CTX)));
      { auto _coll = iv_user_methods; for (auto& mkey : *_coll.data) {
        (changed = (changed | update_call_sites(method.body(), gc_new<Ruby_TypeContext>(mkey, RUBY_NIL))));
      } };
      { auto _coll = iv_user_classes; for (auto& cname : *_coll.data) {
        each_user_instance_method(cname, klass, [&](auto mkey, auto method) { return (changed = (changed | update_call_sites(method.body(), gc_new<Ruby_TypeContext>(mkey, cname)))); });
      } };
      iv__expr_cache = RubyHash<RubySymbol, int64_t>{};
      (changed = (changed | propagate_execute_block()));
      { auto _coll = iv_user_methods; for (auto& mkey : *_coll.data) {
        (changed = (changed | propagate_method(mkey, method, gc_new<Ruby_TypeContext>(mkey, RUBY_NIL))));
      } };
      iv__expr_cache = RubyHash<RubySymbol, int64_t>{};
      { auto _coll = iv_user_classes; for (auto& cname : *_coll.data) {
        (changed = (changed | propagate_ivars(cname, klass)));
        each_user_instance_method(cname, klass, [&](auto mkey, auto method) { return (changed = (changed | propagate_method(mkey, method, gc_new<Ruby_TypeContext>(mkey, cname)))); });
      } };
      if (!(changed)) {
        break;
      };
    }
    if (ENV[RubyString("TI_DBG_SLOTS", 12)]) {
      (pattern = ENV[RubyString("TI_DBG_SLOTS", 12)]);
      /* UNSUPPORTED: GlobalVariableRead */.puts((RubyString("\n=== TI slots matching ", 23) + ruby_to_s(pattern.inspect()) + RubyString(" ===", 4)));
      { auto _coll = iv_env->slots().sort_by(); for (auto& k : *_coll.data) {
      if (ruby_to_s(k).include_q(pattern)) {
        /* UNSUPPORTED: GlobalVariableRead */.puts((RubyString("  ", 2) + ruby_to_s(k.inspect()) + RubyString(" = ", 3) + ruby_to_s(v.inspect())));
      };
    } };
    }
    return iv_env;
  }

  RubyObject* seed_constants() {
    std::fprintf(stderr, "frozone: called TI-gap stub seed_constants\n"); std::abort();
    return nullptr;
  }

  bool update_call_sites(auto node, gc_ref<Ruby_TypeContext> ctx) {
    bool changed = false;
    if (!(node)) {
      return false;
    }
    (changed = false);
    walk(node, [&](auto n) { return if (!(({ auto _l = (true); (_l) ? decltype((true))(_l) : (true); }))) {
      continue;
    }; if (true) {
      (changed = (changed | seed_call_block_params(n, ctx)));
    }; auto has_pos = (!(({ auto _l = (n.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q())); auto has_kw = ({ auto _l = (true); (_l) ? decltype(((!(({ auto _l = (n.kw_arg_nodes()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).empty_q()))))((!(({ auto _l = (n.kw_arg_nodes()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).empty_q()))) : decltype(((!(({ auto _l = (n.kw_arg_nodes()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).empty_q()))))(_l); }); if (!(({ auto _l = (has_pos); (_l) ? decltype((has_kw))(_l) : (has_kw); }))) {
      continue;
    }; if (({ auto _l = (true); (_l) ? decltype((has_kw))(has_kw) : decltype((has_kw))(_l); })) {
      (changed = (changed | propagate_kw_args(n, ctx)));
    }; if (has_pos) {
      (changed = (changed | propagate_positional_args(n, ctx)));
    }; })
    return changed;
  }

  bool seed_call_block_params(auto call, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(call.block_node())> blk{};
    std::decay_t<decltype(block_param_types(call.name(), call.receiver_node(), ctx))> ptypes{};
    (blk = call.block_node());
    if (!(blk)) {
      return false;
    }
    (ptypes = block_param_types(call.name(), call.receiver_node(), ctx));
    (ptypes.empty_q() ? (RUBY_NIL) : (seed_block_params(blk, ptypes, ctx)));
    return false;
  }

  bool propagate_kw_args(auto call, gc_ref<Ruby_TypeContext> ctx) {
    RubyHash<RubySymbol, int64_t> kw_args;
    std::decay_t<decltype(call.receiver_node())> recv{};
    RubyArray<int64_t> mkey;
    bool changed = false;
    RubyNil kw_sym;
    (kw_args = ({ auto _l = (call.kw_arg_nodes()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }));
    if (kw_args.empty_q()) {
      return false;
    }
    (recv = call.receiver_node());
    (mkey = if (ruby_nil_q(recv)) {
      call.name();
    } else {
      if (true) {
      ({ auto _e0 = recv.name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = call.name(); _a; });
    };
    })
    if (!(mkey)) {
      return false;
    }
    (changed = false);
    { auto _coll = kw_args; for (auto& kw_name_node : *_coll.data) {
      (kw_sym = (true ? (kw_name_node.value()) : (RUBY_NIL)));
      if (!(kw_sym)) {
        continue;
      };
      auto ty = infer_expr(val_node, ctx);
      (ty.bottom_q() ? (RUBY_NIL) : ((changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("kwparam"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = mkey; _a[2] = kw_sym; _a; }), ty)))));
    } }
    return changed;
  }

  bool propagate_positional_args(auto call, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(call.receiver_node())> recv{};
    (recv = call.receiver_node());
    if (ruby_nil_q(recv)) {
      return propagate_free_call_args(call, ctx);
    } else {
      if (({ auto _l = (constant_ref_q(recv)); (_l) ? decltype(((call.name() == ruby_sym("new"))))((call.name() == ruby_sym("new"))) : decltype(((call.name() == ruby_sym("new"))))(_l); })) {
        return propagate_constructor_args(call, ctx, recv.name());
      } else {
        if (({ auto _l = (constant_ref_q(recv)); (_l) ? decltype((({ auto _l = (iv_user_classes->key_q(recv.name())); (_l) ? decltype((iv_user_methods->key_q(call.name())))(_l) : (iv_user_methods->key_q(call.name())); })))(({ auto _l = (iv_user_classes->key_q(recv.name())); (_l) ? decltype((iv_user_methods->key_q(call.name())))(_l) : (iv_user_methods->key_q(call.name())); })) : decltype((({ auto _l = (iv_user_classes->key_q(recv.name())); (_l) ? decltype((iv_user_methods->key_q(call.name())))(_l) : (iv_user_methods->key_q(call.name())); })))(_l); })) {
          return propagate_class_method_args(call, ctx, ({ auto _e0 = recv.name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = call.name(); _a; }));
        } else {
          if (recv) {
            return propagate_instance_method_args(call, ctx);
          } else {
            return false;
          }
        }
      }
    }
  }

  RubyObject* constant_ref_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub constant_ref_q\n"); std::abort();
    return nullptr;
  }

  bool propagate_free_call_args(auto call, gc_ref<Ruby_TypeContext> ctx) {
    bool changed = false;
    (changed = false);
    ({ auto _l = (call.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).each_with_index();
    return changed;
  }

  bool propagate_constructor_args(auto call, gc_ref<Ruby_TypeContext> ctx, auto class_sym) {
    RubySymbol ctor_ctx;
    bool changed = false;
    (ctor_ctx = ({ auto _l = (ctx->method_key()); (_l) ? decltype((ruby_sym("__execute__")))(_l) : (ruby_sym("__execute__")); }));
    (changed = false);
    ({ auto _l = (call.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).each_with_index();
    return changed;
  }

  bool propagate_class_method_args(auto call, gc_ref<Ruby_TypeContext> ctx, auto mkey) {
    bool changed = false;
    RubyArray<int64_t> effective_key;
    (changed = false);
    (effective_key = (({ auto _l = (true); (_l) ? decltype((iv_user_methods->key_q(mkey[INT64_C(1)])))(iv_user_methods->key_q(mkey[INT64_C(1)])) : decltype((iv_user_methods->key_q(mkey[INT64_C(1)])))(_l); }) ? (mkey[INT64_C(1)]) : (mkey)));
    ({ auto _l = (call.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).each_with_index();
    return changed;
  }

  bool propagate_instance_method_args(auto call, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(infer_expr(call.receiver_node(), ctx))> recv_ty{};
    RubyArray<int64_t> mkey;
    bool changed = false;
    (recv_ty = infer_expr(call.receiver_node(), ctx));
    if (!(recv_ty.class_type_q())) {
      return false;
    }
    (mkey = ({ auto _e0 = recv_ty.class_name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = call.name(); _a; }));
    (changed = false);
    ({ auto _l = (call.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).each_with_index();
    return changed;
  }

  bool propagate_execute_block() {
    bool changed = false;
    if (!(iv_execute_block->body())) {
      return false;
    }
    (changed = propagate_for_targets(iv_execute_block->body(), TOP_LEVEL_CTX));
    (changed = (changed | propagate_locals(iv_execute_block->body(), TOP_LEVEL_CTX)));
    (changed = (changed | propagate_masgn_from_calls(iv_execute_block->body(), TOP_LEVEL_CTX)));
    return changed;
  }

  bool propagate_method(auto mkey, auto method, gc_ref<Ruby_TypeContext> ctx) {
    bool changed = false;
    std::decay_t<decltype(infer_body_return(method.body(), ctx))> ret_ty{};
    if (!(method.body())) {
      return false;
    }
    (changed = false);
    { auto _coll = ({ auto _l = (method.optional_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }); for (auto& kw_name : *_coll.data) {
      if (!(default_node)) {
        continue;
      };
      auto ty = infer_expr(default_node, ctx);
      (ty.bottom_q() ? (RUBY_NIL) : ((changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("kwparam"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = mkey; _a[2] = kw_name; _a; }), ty)))));
    } }
    (changed = (changed | propagate_array_locals(method.body(), ctx)));
    (changed = (changed | propagate_for_targets(method.body(), ctx)));
    (changed = (changed | propagate_locals(method.body(), ctx)));
    (changed = (changed | propagate_masgn_from_calls(method.body(), ctx)));
    (ret_ty = infer_body_return(method.body(), ctx));
    if (({ auto _l = (ENV[RubyString("TI_DBG_USERS", 12)]); (_l) ? decltype(((mkey == ruby_sym("sd_solve"))))((mkey == ruby_sym("sd_solve"))) : decltype(((mkey == ruby_sym("sd_solve"))))(_l); })) {
      warn((RubyString("[TI_DBG] propagate_method ", 26) + ruby_to_s(mkey.inspect()) + RubyString(": ret=", 6) + ruby_to_s(ret_ty.inspect())));
    }
    (ret_ty.bottom_q() ? (RUBY_NIL) : ((changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("return"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mkey; _a; }), ret_ty)))));
    return changed;
  }

  bool propagate_locals(auto body, gc_ref<Ruby_TypeContext> ctx) {
    int64_t assignments = 0;
    bool changed = false;
    bool iter_changed = false;
    (assignments = /* UNSUPPORTED: IndexOrWrite */);
    if (assignments.empty_q()) {
      return false;
    }
    (changed = false);
    while (true) {
      (iter_changed = false);
      { auto _coll = assignments; for (auto& name : *_coll.data) {
        auto ty = rhs_nodes.reduce(INT64_C(0) /* ::BOTTOM */);
        if (ty.bottom_q()) {
          continue;
        };
        (ty = strip_int_bounds(ty));
        (iter_changed = (iter_changed | iv_env->join_b(({ auto _e0 = ruby_sym("local"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = name; _a; }), ty)));
      } };
      (changed = (changed | iter_changed));
      if (!(iter_changed)) {
        break;
      };
    }
    return changed;
  }

  RubyObject* strip_int_bounds(auto ty) {
    std::fprintf(stderr, "frozone: called TI-gap stub strip_int_bounds\n"); std::abort();
    return nullptr;
  }

  bool propagate_masgn_from_calls(auto body, gc_ref<Ruby_TypeContext> ctx) {
    bool changed = false;
    RubyArray<int64_t> targets;
    RubyNil ret_node;
    RubyArray<int64_t> ret_elems;
    gc_local<Ruby_TypeContext> callee_ctx = nullptr;
    (changed = false);
    walk(body, [&](auto node) { return if (!(true)) {
      continue;
    }; (targets = ({ auto _l = (node.targets()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })); auto value = node.value_node(); if (!(({ auto _l = (true); (_l) ? decltype((ruby_nil_q(value.receiver_node())))(ruby_nil_q(value.receiver_node())) : decltype((ruby_nil_q(value.receiver_node())))(_l); }))) {
      continue;
    }; auto method_name = value.name(); auto method = iv_user_methods->operator[](method_name); if (!(method)) {
      continue;
    }; (ret_node = last_expression(method.body())); if (!(true)) {
      continue;
    }; (ret_elems = ({ auto _l = (ret_node.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })); targets.each_with_index(); })
    return changed;
  }

  RubyNil last_expression(auto node) {
    if (!(node)) {
      return RubyNil(RUBY_NIL);
    }
    if ((node == INT64_C(0) /* ::Sequence */)) {
      return last_expression(node.nodes().last());
    } else {
      return node;
    }
  }

  bool propagate_array_locals(auto body, gc_ref<Ruby_TypeContext> ctx) {
    int64_t assignments = 0;
    RubyArray<int64_t> param_names;
    bool changed = false;
    RubyArray<int64_t> args;
    std::decay_t<decltype(infer_expr(args[INT64_C(1)], ctx))> fill_ty{};
    int64_t elem_writes = 0;
    if (!(body)) {
      return false;
    }
    (assignments = /* UNSUPPORTED: IndexOrWrite */);
    (param_names = param_names_for(ctx));
    (changed = false);
    { auto _coll = assignments; for (auto& name : *_coll.data) {
      if (param_names.include_q(name)) {
        continue;
      };
      if (!((rhs_nodes.len() == INT64_C(1)))) {
        continue;
      };
      auto rhs = rhs_nodes.first();
      if (!(array_new_call_q(rhs))) {
        continue;
      };
      (args = ({ auto _l = (rhs.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
      if (!((args.len() == INT64_C(2)))) {
        continue;
      };
      (fill_ty = infer_expr(args[INT64_C(1)], ctx));
      if (!(fill_ty.raw_q())) {
        continue;
      };
      if (({ auto _l = (escapes_q(name, body, ctx)); (_l) ? decltype(((!(escapes_only_via_return_array_q(name, body)))))((!(escapes_only_via_return_array_q(name, body)))) : decltype(((!(escapes_only_via_return_array_q(name, body)))))(_l); })) {
        continue;
      };
      if (!(writes_consistent_q(name, body, ctx, fill_ty))) {
        continue;
      };
      (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("array_elem"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = name; _a; }), fill_ty)));
    } }
    (elem_writes = /* UNSUPPORTED: IndexOrWrite */);
    { auto _coll = elem_writes; for (auto& key : *_coll.data) {
      if (true) {
        if (param_names.include_q(key)) {
        continue;
      };
        auto types = value_nodes.map();
        if (!(types.all_q())) {
        continue;
      };
        auto unique = types.uniq();
        if (!((unique.len() == INT64_C(1)))) {
        continue;
      };
        (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("array_elem"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = key; _a; }), unique[INT64_C(0)])));
      } else {
        if (({ auto _l = (true); (_l) ? decltype(((key[INT64_C(0)] == ruby_sym("sub"))))((key[INT64_C(0)] == ruby_sym("sub"))) : decltype(((key[INT64_C(0)] == ruby_sym("sub"))))(_l); })) {
        auto arr_name = key[INT64_C(1)];
        (types = value_nodes.map());
        if (!(types.all_q())) {
        continue;
      };
        (unique = types.uniq());
        if (!((unique.len() == INT64_C(1)))) {
        continue;
      };
        auto local_ty = iv_env->type_of(({ auto _e0 = ruby_sym("local"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = arr_name; _a; }));
        if (local_ty.array_q()) {
        auto inner = Type.array();
        (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("local"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = arr_name; _a; }), Type.array())));
      };
      };
      };
    } }
    return changed;
  }

  RubyObject* collect_array_elem_writes(auto node, auto result, auto depth) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_array_elem_writes\n"); std::abort();
    return nullptr;
  }

  bool propagate_for_targets(auto body, gc_ref<Ruby_TypeContext> ctx) {
    bool changed = false;
    RubyNil elem_ty;
    if (!(body)) {
      return false;
    }
    (changed = false);
    walk(body, [&](auto node) { return if (!(true)) {
      continue;
    }; auto target = node.target(); if (!((target[INT64_C(0)] == ruby_sym("local")))) {
      continue;
    }; auto name = target[INT64_C(1)]; auto coll_node = node.collection_node(); auto coll_ty = infer_expr(coll_node, ctx); (elem_ty = for_loop_elem_type(coll_ty)); if (({ auto _l = (ruby_nil_q(elem_ty)); (_l) ? decltype((elem_ty.bottom_q()))(_l) : (elem_ty.bottom_q()); })) {
      continue;
    }; (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("block_param"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = name; _a; }), elem_ty))); })
    return changed;
  }

  RubyNil for_loop_elem_type(auto coll_ty) {
    if (({ auto _l = (coll_ty.class_type_q()); (_l) ? decltype(((coll_ty.class_name() == ruby_sym("Range"))))((coll_ty.class_name() == ruby_sym("Range"))) : decltype(((coll_ty.class_name() == ruby_sym("Range"))))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    }
    if (({ auto _l = (coll_ty.array_q()); (_l) ? decltype((coll_ty.elem()))(coll_ty.elem()) : decltype((coll_ty.elem()))(_l); })) {
      return coll_ty.elem();
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* propagate_ivars(auto class_name, auto klass) {
    std::fprintf(stderr, "frozone: called TI-gap stub propagate_ivars\n"); std::abort();
    return nullptr;
  }

  bool seed_setter_params_from_ivars(auto class_name, auto klass) {
    bool changed = false;
    RubyArray<int64_t> req;
    (changed = false);
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if (!(true)) {
        continue;
      };
      if (!(ruby_to_s(mname).end_with_q(RubyString("=", 1)))) {
        continue;
      };
      (req = ({ auto _l = (method.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
      if (!((req.len() == INT64_C(1)))) {
        continue;
      };
      auto ivar_sym = (RubyString("@", 1) + ruby_to_s(ruby_to_s(mname).chomp(RubyString("=", 1)))).to_sym();
      auto iv_ty = iv_env->type_of(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_sym; _a; }));
      if (iv_ty.bottom_q()) {
        continue;
      };
      (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("param"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }); _a[2] = INT64_C(0); _a; }), iv_ty)));
    } }
    return changed;
  }

  bool seed_constructor_params(auto class_name, auto param_types) {
    bool changed = false;
    (changed = false);
    param_types.each_with_index();
    return changed;
  }

  bool propagate_ivars_from_initialize(auto class_name, auto init) {
    gc_local<Ruby_TypeContext> ctx = nullptr;
    bool changed = false;
    (ctx = gc_new<Ruby_TypeContext>(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("initialize"); _a; }), class_name));
    (changed = false);
    { auto _coll = collect_ivar_assignments(init.body()); for (auto& ivar_name : *_coll.data) {
      auto ty = rhs_nodes.reduce(INT64_C(0) /* ::BOTTOM */);
      if (ty.bottom_q()) {
        continue;
      };
      (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; }), ty)));
    } }
    return changed;
  }

  bool propagate_ivars_from_other_methods(auto class_name, auto klass) {
    bool changed = false;
    gc_local<Ruby_TypeContext> method_ctx = nullptr;
    (changed = false);
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if (({ auto _l = (({ auto _l = ((mname == ruby_sym("initialize"))); (_l) ? decltype(((!(true))))(_l) : ((!(true))); })); (_l) ? decltype(((!(method.body()))))(_l) : ((!(method.body()))); })) {
        continue;
      };
      (method_ctx = gc_new<Ruby_TypeContext>(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), class_name));
      { auto _coll = collect_ivar_assignments(method.body()); for (auto& ivar_name : *_coll.data) {
        { auto _coll = rhs_nodes; for (auto& rhs : *_coll.data) {
          auto ty = infer_expr(rhs, method_ctx);
          if (({ auto _l = (ruby_nil_q(ty)); (_l) ? decltype((ty.bottom_q()))(_l) : (ty.bottom_q()); })) {
            continue;
          };
          (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; }), ty)));
        } };
      } };
    } }
    return changed;
  }

  bool propagate_ivars_from_setter_calls(auto class_name, auto klass) {
    gc_local<Ruby_Set> accessor_names = nullptr;
    bool changed = false;
    gc_local<Ruby_TypeContext> method_ctx = nullptr;
    (accessor_names = gc_new<Ruby_Set>());
    ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).each_key();
    if (accessor_names->empty_q()) {
      return false;
    }
    (changed = false);
    each_user_method([&](auto mkey, auto method) { return if (!(method.body())) {
      continue;
    }; (method_ctx = gc_new<Ruby_TypeContext>(mkey, (true ? (mkey[INT64_C(0)]) : (RUBY_NIL)))); collect_setter_calls(method.body(), class_name, accessor_names, method_ctx, [&](auto attr_name, auto ty) { return (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = (RubyString("@", 1) + ruby_to_s(attr_name)).to_sym(); _a; }), ty))); }); })
    return changed;
  }

  bool propagate_ivar_array_elem_writes(auto class_name, auto klass) {
    bool changed = false;
    gc_local<Ruby_TypeContext> method_ctx = nullptr;
    (changed = false);
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if (!(({ auto _l = (true); (_l) ? decltype((method.body()))(method.body()) : decltype((method.body()))(_l); }))) {
        continue;
      };
      (method_ctx = gc_new<Ruby_TypeContext>(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), class_name));
      collect_ivar_array_elem_writes(method.body(), class_name, method_ctx, [&](auto ivar_name, auto elem_ty) { return if (({ auto _l = (iv__widened_array_ivars); (_l) ? decltype((iv__widened_array_ivars = gc_new<Ruby_Set>()))(_l) : (iv__widened_array_ivars = gc_new<Ruby_Set>()); }).include_q(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ivar_name; _a; }))) {
        continue;
      }; auto current = iv_env->type_of(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; })); if (({ auto _l = (current.array_q()); (_l) ? decltype(((!(current.elem()))))((!(current.elem()))) : decltype(((!(current.elem()))))(_l); })) {
        (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; }), Type.array())));
      }; });
    } }
    return changed;
  }

  bool widen_ivar_arrays_from_mutations(auto class_name, auto klass) {
    bool changed = false;
    gc_local<Ruby_TypeContext> method_ctx = nullptr;
    RubyArray<int64_t> widened_key;
    (changed = false);
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if (!(({ auto _l = (true); (_l) ? decltype((method.body()))(method.body()) : decltype((method.body()))(_l); }))) {
        continue;
      };
      (method_ctx = gc_new<Ruby_TypeContext>(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), class_name));
      collect_ivar_array_mutations(method.body(), method_ctx, [&](auto ivar_name, auto val_ty) { return (widened_key = ({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ivar_name; _a; })); if (({ auto _l = (iv__widened_array_ivars); (_l) ? decltype((iv__widened_array_ivars = gc_new<Ruby_Set>()))(_l) : (iv__widened_array_ivars = gc_new<Ruby_Set>()); }).include_q(widened_key)) {
        continue;
      }; auto current = iv_env->type_of(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; })); if (!(current.array_q())) {
        continue;
      }; if (!(({ auto _l = (val_ty.raw_q()); (_l) ? decltype((({ auto _l = (val_ty.class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())))(_l); })))(_l) : (({ auto _l = (val_ty.class_type_q()); (_l) ? decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())))(({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())) : decltype((({ auto _e0 = ruby_sym("Integer"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("Float"); _a; }).include_q(val_ty.class_name())))(_l); })); }))) {
        (iv__widened_array_ivars << widened_key);
        (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; }), INT64_C(0) /* ::ARRAY */)));
      }; });
    } }
    return changed;
  }

  bool widen_scalar_ivars_from_mutations(auto class_name, auto klass) {
    bool changed = false;
    gc_local<Ruby_TypeContext> method_ctx = nullptr;
    RubyArray<RubySymbol> widened_key;
    (changed = false);
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if ((mname == ruby_sym("initialize"))) {
        continue;
      };
      if (!(({ auto _l = (true); (_l) ? decltype((method.body()))(method.body()) : decltype((method.body()))(_l); }))) {
        continue;
      };
      (method_ctx = gc_new<Ruby_TypeContext>(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), class_name));
      collect_ivar_typed_writes(method.body(), method_ctx, [&](auto ivar_name, auto val_ty) { return (widened_key = ({ auto _e0 = ruby_sym("scalar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; })); if (({ auto _l = (iv__widened_array_ivars); (_l) ? decltype((iv__widened_array_ivars = gc_new<Ruby_Set>()))(_l) : (iv__widened_array_ivars = gc_new<Ruby_Set>()); }).include_q(widened_key)) {
        continue;
      }; auto current = iv_env->type_of(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; })); if (!(current.raw_q())) {
        continue;
      }; if (({ auto _l = (val_ty.raw_q()); (_l) ? decltype((val_ty.bottom_q()))(_l) : (val_ty.bottom_q()); })) {
        continue;
      }; (iv__widened_array_ivars << widened_key); (changed = (changed | iv_env->join_b(({ auto _e0 = ruby_sym("ivar"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = class_name; _a[2] = ivar_name; _a; }), INT64_C(0) /* ::BOTTOM */))); });
    } }
    return changed;
  }

  RubyObject* collect_ivar_typed_writes(auto node, auto ctx, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_ivar_typed_writes\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_ivar_array_mutations(auto node, auto ctx, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_ivar_array_mutations\n"); std::abort();
    return nullptr;
  }

  RubyObject* each_user_method(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub each_user_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_ivar_array_elem_writes(auto node, auto class_name, auto ctx, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_ivar_array_elem_writes\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_setter_calls(auto node, auto class_name, auto accessor_names, auto ctx, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_setter_calls\n"); std::abort();
    return nullptr;
  }

  RubyObject* infer_expr(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* infer_expr_uncached(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_expr_uncached\n"); std::abort();
    return nullptr;
  }

  RubyObject* infer_array_literal_type(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_array_literal_type\n"); std::abort();
    return nullptr;
  }

  bool tree_node_literal_q(auto node) {
    RubyArray<int64_t> elems;
    (elems = ({ auto _l = (node.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (!((elems.len() == INT64_C(2)))) {
      return false;
    }
    return elems.all_q();
  }

  RubyObject* infer_hash_literal_type(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_hash_literal_type\n"); std::abort();
    return nullptr;
  }

  RubyObject* infer_local_var_type(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_local_var_type\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> infer_if_type(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(infer_expr(node.then_node(), ctx))> t{};
    int64_t e_ty = 0;
    (t = infer_expr(node.then_node(), ctx));
    (e_ty = (node.else_node() ? (infer_expr(node.else_node(), ctx)) : (INT64_C(0) /* ::NIL_CLASS */)));
    if (e_ty.bottom_q()) {
      return t;
    }
    if (t.bottom_q()) {
      return e_ty;
    }
    return coerce_to_ref<RubyObject>(join(t, e_ty));
  }

  gc_ref<RubyObject> infer_short_circuit_type(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(infer_expr(node.left_node(), ctx))> lt{};
    std::decay_t<decltype(infer_expr(node.right_node(), ctx))> rt{};
    (lt = infer_expr(node.left_node(), ctx));
    (rt = infer_expr(node.right_node(), ctx));
    if (lt.bottom_q()) {
      return rt;
    }
    if (rt.bottom_q()) {
      return lt;
    }
    return coerce_to_ref<RubyObject>(join(lt, rt));
  }

  RubyNil infer_call(auto node, gc_ref<Ruby_TypeContext> ctx) {
    RubyNil result;
    (result = ({ auto _l = (try_infer_array_factory(node, ctx)); (_l) ? decltype((try_infer_map_factory(node, ctx)))(_l) : (try_infer_map_factory(node, ctx)); }));
    if (result) {
      return result;
    }
    seed_iteration_block_params(node, ctx);
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (try_infer_class_new(node, ctx)); (_l) ? decltype((try_infer_math_call(node, ctx)))(_l) : (try_infer_math_call(node, ctx)); })); (_l) ? decltype((try_infer_subscript_read(node, ctx)))(_l) : (try_infer_subscript_read(node, ctx)); })); (_l) ? decltype((try_infer_range_to_a(node, ctx)))(_l) : (try_infer_range_to_a(node, ctx)); })); (_l) ? decltype((try_infer_builtin_method(node, ctx)))(_l) : (try_infer_builtin_method(node, ctx)); })); (_l) ? decltype((try_infer_arith_op(node, ctx)))(_l) : (try_infer_arith_op(node, ctx)); })); (_l) ? decltype((try_infer_max_min_two_arg(node, ctx)))(_l) : (try_infer_max_min_two_arg(node, ctx)); })); (_l) ? decltype((try_infer_class_method_call(node, ctx)))(_l) : (try_infer_class_method_call(node, ctx)); })); (_l) ? decltype((try_infer_instance_method_call(node, ctx)))(_l) : (try_infer_instance_method_call(node, ctx)); })); (_l) ? decltype((try_infer_free_call(node, ctx)))(_l) : (try_infer_free_call(node, ctx)); })); (_l) ? decltype((INT64_C(0) /* ::BOTTOM */))(_l) : (INT64_C(0) /* ::BOTTOM */); });
  }

  RubyNil try_infer_array_factory(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(node.block_node())> blk{};
    RubyArray<int64_t> args;
    std::decay_t<decltype(infer_expr(args[INT64_C(1)], ctx))> fill_ty{};
    if (!((node.name() == ruby_sym("new")))) {
      return RubyNil(RUBY_NIL);
    }
    (recv = node.receiver_node());
    if (!(({ auto _l = (true); (_l) ? decltype(((recv.name() == ruby_sym("Array"))))((recv.name() == ruby_sym("Array"))) : decltype(((recv.name() == ruby_sym("Array"))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (blk = node.block_node());
    (args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (blk) {
      return auto elem_ty = infer_block_return(blk, ({ auto _e0 = INT64_C(0) /* ::I64 */; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }), ctx); return (elem_ty.bottom_q() ? (INT64_C(0) /* ::ARRAY */) : (Type.array()));
    } else {
      if ((args.len() == INT64_C(2))) {
        return (fill_ty = infer_expr(args[INT64_C(1)], ctx)); return (fill_ty.bottom_q() ? (INT64_C(0) /* ::ARRAY */) : (Type.array()));
      } else {
        if ((args.len() == INT64_C(1))) {
          return INT64_C(0) /* ::ARRAY */;
        }
        return RubyNil(RUBY_NIL);
      }
    }
  }

  RubyNil try_infer_map_factory(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(infer_expr(node.receiver_node(), ctx))> recv_ty{};
    int64_t elem_in = 0;
    if (!(({ auto _l = (({ auto _l = ((node.name() == ruby_sym("map"))); (_l) ? decltype((node.block_node()))(node.block_node()) : decltype((node.block_node()))(_l); })); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (recv_ty = infer_expr(node.receiver_node(), ctx));
    if (!(recv_ty.array_q())) {
      return RubyNil(RUBY_NIL);
    }
    (elem_in = ({ auto _l = (recv_ty.elem()); (_l) ? decltype((INT64_C(0) /* ::BOTTOM */))(_l) : (INT64_C(0) /* ::BOTTOM */); }));
    auto elem_out = infer_block_return(node.block_node(), ({ auto _e0 = elem_in; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }), ctx);
    if (elem_out.bottom_q()) {
      return INT64_C(0) /* ::ARRAY */;
    } else {
      return Type.array();
    }
  }

  RubyNil seed_iteration_block_params(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(block_param_types(node.name(), node.receiver_node(), ctx))> ptypes{};
    if (!(node.block_node())) {
      return RubyNil(RUBY_NIL);
    }
    (ptypes = block_param_types(node.name(), node.receiver_node(), ctx));
    if (ptypes.empty_q()) {
      return RubyNil(RUBY_NIL);
    } else {
      return seed_block_params(node.block_node(), ptypes, ctx);
    }
  }

  RubyNil try_infer_class_new(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    if (!((node.name() == ruby_sym("new")))) {
      return RubyNil(RUBY_NIL);
    }
    (recv = node.receiver_node());
    if (true) {
      return Type.of(recv.name());
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyNil try_infer_math_call(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    (recv = node.receiver_node());
    if (!(({ auto _l = (true); (_l) ? decltype(((recv.name() == ruby_sym("Math"))))((recv.name() == ruby_sym("Math"))) : decltype(((recv.name() == ruby_sym("Math"))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    if (MATH_FLOAT_METHODS.include_q(node.name())) {
      return INT64_C(0) /* ::F64 */;
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyNil try_infer_subscript_read(auto node, gc_ref<Ruby_TypeContext> ctx) {
    RubyArray<int64_t> args;
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(infer_expr(recv, ctx))> recv_ty{};
    (args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (!(({ auto _l = ((node.name() == ruby_sym("[]"))); (_l) ? decltype(((args.len() == INT64_C(1))))((args.len() == INT64_C(1))) : decltype(((args.len() == INT64_C(1))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (recv = node.receiver_node());
    if (true) {
      auto ae = iv_env->type_of(({ auto _e0 = ruby_sym("array_elem"); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ctx->method_key(); _a[2] = recv.name(); _a; }));
      if (!(ae.bottom_q())) {
      return ae;
    };
    }
    (recv_ty = infer_expr(recv, ctx));
    if (({ auto _l = (recv_ty.array_q()); (_l) ? decltype((recv_ty.elem()))(recv_ty.elem()) : decltype((recv_ty.elem()))(_l); })) {
      return recv_ty.elem();
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyNil try_infer_range_to_a(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> unwrapped{};
    std::decay_t<decltype(infer_expr(unwrapped.begin_node(), ctx))> begin_ty{};
    if (!(({ auto _l = ((node.name() == ruby_sym("to_a"))); (_l) ? decltype(((node.name() == ruby_sym("to_ary"))))(_l) : ((node.name() == ruby_sym("to_ary"))); }))) {
      return RubyNil(RUBY_NIL);
    }
    (unwrapped = node.receiver_node());
    while (({ auto _l = (true); (_l) ? decltype(((unwrapped.nodes().len() == INT64_C(1))))((unwrapped.nodes().len() == INT64_C(1))) : decltype(((unwrapped.nodes().len() == INT64_C(1))))(_l); })) {
      (unwrapped = unwrapped.nodes().first());
    }
    if (!(true)) {
      return RubyNil(RUBY_NIL);
    }
    (begin_ty = infer_expr(unwrapped.begin_node(), ctx));
    if (begin_ty.raw_q()) {
      return Type.array();
    } else {
      return INT64_C(0) /* ::ARRAY */;
    }
  }

  RubyNil try_infer_builtin_method(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(node.name())> name{};
    std::decay_t<decltype(infer_expr(recv, ctx))> recv_ty{};
    std::decay_t<decltype(recv_ty.class_name())> cn{};
    (recv = node.receiver_node());
    if (!(recv)) {
      return RubyNil(RUBY_NIL);
    }
    (name = node.name());
    (recv_ty = infer_expr(recv, ctx));
    if (({ auto _l = (COERCE_TO_FLOAT.include_q(name)); (_l) ? decltype(((!(recv_ty.bottom_q()))))((!(recv_ty.bottom_q()))) : decltype(((!(recv_ty.bottom_q()))))(_l); })) {
      return INT64_C(0) /* ::F64 */;
    }
    if (({ auto _l = (COERCE_TO_INT.include_q(name)); (_l) ? decltype(((!(recv_ty.bottom_q()))))((!(recv_ty.bottom_q()))) : decltype(((!(recv_ty.bottom_q()))))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    }
    if (({ auto _l = (({ auto _l = (recv_ty.i64_q()); (_l) ? decltype((({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Integer"))))((recv_ty.class_name() == ruby_sym("Integer"))) : decltype(((recv_ty.class_name() == ruby_sym("Integer"))))(_l); })))(_l) : (({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Integer"))))((recv_ty.class_name() == ruby_sym("Integer"))) : decltype(((recv_ty.class_name() == ruby_sym("Integer"))))(_l); })); })); (_l) ? decltype((INT_INT_METHODS.include_q(name)))(INT_INT_METHODS.include_q(name)) : decltype((INT_INT_METHODS.include_q(name)))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    }
    if (({ auto _l = (({ auto _l = (recv_ty.f64_q()); (_l) ? decltype((({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Float"))))((recv_ty.class_name() == ruby_sym("Float"))) : decltype(((recv_ty.class_name() == ruby_sym("Float"))))(_l); })))(_l) : (({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Float"))))((recv_ty.class_name() == ruby_sym("Float"))) : decltype(((recv_ty.class_name() == ruby_sym("Float"))))(_l); })); })); (_l) ? decltype((FLOAT_FLOAT_METHODS.include_q(name)))(FLOAT_FLOAT_METHODS.include_q(name)) : decltype((FLOAT_FLOAT_METHODS.include_q(name)))(_l); })) {
      return INT64_C(0) /* ::F64 */;
    }
    if (({ auto _l = (({ auto _l = (recv_ty.f64_q()); (_l) ? decltype((({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Float"))))((recv_ty.class_name() == ruby_sym("Float"))) : decltype(((recv_ty.class_name() == ruby_sym("Float"))))(_l); })))(_l) : (({ auto _l = (recv_ty.class_type_q()); (_l) ? decltype(((recv_ty.class_name() == ruby_sym("Float"))))((recv_ty.class_name() == ruby_sym("Float"))) : decltype(((recv_ty.class_name() == ruby_sym("Float"))))(_l); })); })); (_l) ? decltype((FLOAT_INT_METHODS.include_q(name)))(FLOAT_INT_METHODS.include_q(name)) : decltype((FLOAT_INT_METHODS.include_q(name)))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    }
    if (recv_ty.class_type_q()) {
      (cn = recv_ty.class_name());
      if (({ auto _l = ((cn == ruby_sym("Array"))); (_l) ? decltype((ARRAY_INT_METHODS.include_q(name)))(ARRAY_INT_METHODS.include_q(name)) : decltype((ARRAY_INT_METHODS.include_q(name)))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    };
      if (({ auto _l = ((cn == ruby_sym("String"))); (_l) ? decltype((({ auto _e0 = ruby_sym("getbyte"); auto _a = RubyArray<decltype(_e0)>(6); _a[0] = _e0; _a[1] = ruby_sym("ord"); _a[2] = ruby_sym("bytesize"); _a[3] = ruby_sym("size"); _a[4] = ruby_sym("length"); _a[5] = ruby_sym("setbyte"); _a; }).include_q(name)))(({ auto _e0 = ruby_sym("getbyte"); auto _a = RubyArray<decltype(_e0)>(6); _a[0] = _e0; _a[1] = ruby_sym("ord"); _a[2] = ruby_sym("bytesize"); _a[3] = ruby_sym("size"); _a[4] = ruby_sym("length"); _a[5] = ruby_sym("setbyte"); _a; }).include_q(name)) : decltype((({ auto _e0 = ruby_sym("getbyte"); auto _a = RubyArray<decltype(_e0)>(6); _a[0] = _e0; _a[1] = ruby_sym("ord"); _a[2] = ruby_sym("bytesize"); _a[3] = ruby_sym("size"); _a[4] = ruby_sym("length"); _a[5] = ruby_sym("setbyte"); _a; }).include_q(name)))(_l); })) {
      return INT64_C(0) /* ::I64 */;
    };
      if (({ auto _l = ((cn == ruby_sym("String"))); (_l) ? decltype((({ auto _e0 = ruby_sym("b"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("upcase"); _a[2] = ruby_sym("downcase"); _a[3] = ruby_sym("capitalize"); _a[4] = ruby_sym("reverse"); _a[5] = ruby_sym("chomp"); _a[6] = ruby_sym("chop"); _a[7] = ruby_sym("strip"); _a[8] = ruby_sym("lstrip"); _a[9] = ruby_sym("rstrip"); _a; }).include_q(name)))(({ auto _e0 = ruby_sym("b"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("upcase"); _a[2] = ruby_sym("downcase"); _a[3] = ruby_sym("capitalize"); _a[4] = ruby_sym("reverse"); _a[5] = ruby_sym("chomp"); _a[6] = ruby_sym("chop"); _a[7] = ruby_sym("strip"); _a[8] = ruby_sym("lstrip"); _a[9] = ruby_sym("rstrip"); _a; }).include_q(name)) : decltype((({ auto _e0 = ruby_sym("b"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("upcase"); _a[2] = ruby_sym("downcase"); _a[3] = ruby_sym("capitalize"); _a[4] = ruby_sym("reverse"); _a[5] = ruby_sym("chomp"); _a[6] = ruby_sym("chop"); _a[7] = ruby_sym("strip"); _a[8] = ruby_sym("lstrip"); _a[9] = ruby_sym("rstrip"); _a; }).include_q(name)))(_l); })) {
      return INT64_C(0) /* ::STRING */;
    };
      if (({ auto _l = (({ auto _l = ((cn == ruby_sym("String"))); (_l) ? decltype((({ auto _l = ((name == ruby_sym("*"))); (_l) ? decltype(((name == ruby_sym("+"))))(_l) : ((name == ruby_sym("+"))); })))(({ auto _l = ((name == ruby_sym("*"))); (_l) ? decltype(((name == ruby_sym("+"))))(_l) : ((name == ruby_sym("+"))); })) : decltype((({ auto _l = ((name == ruby_sym("*"))); (_l) ? decltype(((name == ruby_sym("+"))))(_l) : ((name == ruby_sym("+"))); })))(_l); })); (_l) ? decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(1))))((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(1))) : decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(1))))(_l); })) {
      return INT64_C(0) /* ::STRING */;
    };
      if (({ auto _l = (({ auto _l = ((cn == ruby_sym("String"))); (_l) ? decltype(((name == ruby_sym("[]"))))((name == ruby_sym("[]"))) : decltype(((name == ruby_sym("[]"))))(_l); })); (_l) ? decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(2))))((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(2))) : decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() == INT64_C(2))))(_l); })) {
      return INT64_C(0) /* ::STRING */;
    };
      if (({ auto _l = ((cn == ruby_sym("String"))); (_l) ? decltype(((name == ruby_sym("slice"))))((name == ruby_sym("slice"))) : decltype(((name == ruby_sym("slice"))))(_l); })) {
      return INT64_C(0) /* ::STRING */;
    };
      if (({ auto _l = ((cn == ruby_sym("Random"))); (_l) ? decltype(((name == ruby_sym("rand"))))((name == ruby_sym("rand"))) : decltype(((name == ruby_sym("rand"))))(_l); })) {
      return (({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q() ? (INT64_C(0) /* ::F64 */) : (INT64_C(0) /* ::I64 */));
    };
    }
    if (({ auto _l = (({ auto _l = (recv_ty.array_q()); (_l) ? decltype((recv_ty.elem()))(recv_ty.elem()) : decltype((recv_ty.elem()))(_l); })); (_l) ? decltype((({ auto _e0 = ruby_sym("max"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("min"); _a[2] = ruby_sym("sum"); _a[3] = ruby_sym("first"); _a[4] = ruby_sym("last"); _a[5] = ruby_sym("fetch"); _a[6] = ruby_sym("at"); _a[7] = ruby_sym("[]"); _a[8] = ruby_sym("pop"); _a[9] = ruby_sym("shift"); _a; }).include_q(name)))(({ auto _e0 = ruby_sym("max"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("min"); _a[2] = ruby_sym("sum"); _a[3] = ruby_sym("first"); _a[4] = ruby_sym("last"); _a[5] = ruby_sym("fetch"); _a[6] = ruby_sym("at"); _a[7] = ruby_sym("[]"); _a[8] = ruby_sym("pop"); _a[9] = ruby_sym("shift"); _a; }).include_q(name)) : decltype((({ auto _e0 = ruby_sym("max"); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = ruby_sym("min"); _a[2] = ruby_sym("sum"); _a[3] = ruby_sym("first"); _a[4] = ruby_sym("last"); _a[5] = ruby_sym("fetch"); _a[6] = ruby_sym("at"); _a[7] = ruby_sym("[]"); _a[8] = ruby_sym("pop"); _a[9] = ruby_sym("shift"); _a; }).include_q(name)))(_l); })) {
      return recv_ty.elem();
    }
    if (({ auto _l = ((!(recv_ty.bottom_q()))); (_l) ? decltype((({ auto _l = (({ auto _l = ((name == ruby_sym("dup"))); (_l) ? decltype(((name == ruby_sym("clone"))))(_l) : ((name == ruby_sym("clone"))); })); (_l) ? decltype(((name == ruby_sym("freeze"))))(_l) : ((name == ruby_sym("freeze"))); })))(({ auto _l = (({ auto _l = ((name == ruby_sym("dup"))); (_l) ? decltype(((name == ruby_sym("clone"))))(_l) : ((name == ruby_sym("clone"))); })); (_l) ? decltype(((name == ruby_sym("freeze"))))(_l) : ((name == ruby_sym("freeze"))); })) : decltype((({ auto _l = (({ auto _l = ((name == ruby_sym("dup"))); (_l) ? decltype(((name == ruby_sym("clone"))))(_l) : ((name == ruby_sym("clone"))); })); (_l) ? decltype(((name == ruby_sym("freeze"))))(_l) : ((name == ruby_sym("freeze"))); })))(_l); })) {
      return recv_ty;
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil try_infer_arith_op(auto node, gc_ref<Ruby_TypeContext> ctx) {
    RubyArray<int64_t> args;
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(infer_expr(recv, ctx))> rt{};
    std::decay_t<decltype(infer_expr(args[INT64_C(0)], ctx))> at{};
    (args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    (recv = node.receiver_node());
    if (!(recv)) {
      return RubyNil(RUBY_NIL);
    }
    if (({ auto _l = (args.empty_q()); (_l) ? decltype((({ auto _l = ((node.name() == ruby_sym("-@"))); (_l) ? decltype(((node.name() == ruby_sym("+@"))))(_l) : ((node.name() == ruby_sym("+@"))); })))(({ auto _l = ((node.name() == ruby_sym("-@"))); (_l) ? decltype(((node.name() == ruby_sym("+@"))))(_l) : ((node.name() == ruby_sym("+@"))); })) : decltype((({ auto _l = ((node.name() == ruby_sym("-@"))); (_l) ? decltype(((node.name() == ruby_sym("+@"))))(_l) : ((node.name() == ruby_sym("+@"))); })))(_l); })) {
      (rt = infer_expr(recv, ctx));
      if (({ auto _l = (rt.f64_q()); (_l) ? decltype((rt.i64_q()))(_l) : (rt.i64_q()); })) {
      return rt;
    };
      return RubyNil(RUBY_NIL);
    }
    if (!(({ auto _l = (ARITH_OPS.include_q(node.name())); (_l) ? decltype(((args.len() == INT64_C(1))))((args.len() == INT64_C(1))) : decltype(((args.len() == INT64_C(1))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (rt = infer_expr(recv, ctx));
    (at = infer_expr(args[INT64_C(0)], ctx));
    if (({ auto _l = (rt.bottom_q()); (_l) ? decltype((at.bottom_q()))(_l) : (at.bottom_q()); })) {
      return INT64_C(0) /* ::BOTTOM */;
    }
    if (({ auto _l = (rt.raw_q()); (_l) ? decltype((at.raw_q()))(at.raw_q()) : decltype((at.raw_q()))(_l); })) {
      if (({ auto _l = (rt.f64_q()); (_l) ? decltype((at.f64_q()))(_l) : (at.f64_q()); })) {
      return INT64_C(0) /* ::F64 */;
    };
      return propagate_int_bounds(node.name(), rt, at);
    }
    return INT64_C(0) /* ::BOTTOM */;
  }

  RubyObject* propagate_int_bounds(auto op, auto lhs, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub propagate_int_bounds\n"); std::abort();
    return nullptr;
  }

  RubyNil try_infer_max_min_two_arg(auto node, gc_ref<Ruby_TypeContext> ctx) {
    RubyArray<int64_t> args;
    std::decay_t<decltype(infer_expr(args[INT64_C(0)], ctx))> at{};
    std::decay_t<decltype(infer_expr(args[INT64_C(1)], ctx))> bt{};
    (args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (!(({ auto _l = (({ auto _l = ((node.name() == ruby_sym("max"))); (_l) ? decltype(((node.name() == ruby_sym("min"))))(_l) : ((node.name() == ruby_sym("min"))); })); (_l) ? decltype(((args.len() == INT64_C(2))))((args.len() == INT64_C(2))) : decltype(((args.len() == INT64_C(2))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (at = infer_expr(args[INT64_C(0)], ctx));
    (bt = infer_expr(args[INT64_C(1)], ctx));
    if (({ auto _l = (at.bottom_q()); (_l) ? decltype((bt.bottom_q()))(_l) : (bt.bottom_q()); })) {
      return RubyNil(RUBY_NIL);
    }
    if (({ auto _l = (at.raw_q()); (_l) ? decltype((bt.raw_q()))(bt.raw_q()) : decltype((bt.raw_q()))(_l); })) {
      return (({ auto _l = (at.f64_q()); (_l) ? decltype((bt.f64_q()))(_l) : (bt.f64_q()); }) ? (INT64_C(0) /* ::F64 */) : (INT64_C(0) /* ::I64 */));
    }
    if (!(({ auto _l = (at.numeric_q()); (_l) ? decltype((bt.numeric_q()))(bt.numeric_q()) : decltype((bt.numeric_q()))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = (at.f64_q()); (_l) ? decltype((bt.f64_q()))(_l) : (bt.f64_q()); })); (_l) ? decltype((({ auto _l = (at.class_type_q()); (_l) ? decltype(((at.class_name() == ruby_sym("Float"))))((at.class_name() == ruby_sym("Float"))) : decltype(((at.class_name() == ruby_sym("Float"))))(_l); })))(_l) : (({ auto _l = (at.class_type_q()); (_l) ? decltype(((at.class_name() == ruby_sym("Float"))))((at.class_name() == ruby_sym("Float"))) : decltype(((at.class_name() == ruby_sym("Float"))))(_l); })); })); (_l) ? decltype((({ auto _l = (bt.class_type_q()); (_l) ? decltype(((bt.class_name() == ruby_sym("Float"))))((bt.class_name() == ruby_sym("Float"))) : decltype(((bt.class_name() == ruby_sym("Float"))))(_l); })))(_l) : (({ auto _l = (bt.class_type_q()); (_l) ? decltype(((bt.class_name() == ruby_sym("Float"))))((bt.class_name() == ruby_sym("Float"))) : decltype(((bt.class_name() == ruby_sym("Float"))))(_l); })); })) {
      return INT64_C(0) /* ::F64 */;
    }
    if (({ auto _l = (at.raw_q()); (_l) ? decltype((bt.raw_q()))(_l) : (bt.raw_q()); })) {
      return INT64_C(0) /* ::I64 */;
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyNil try_infer_class_method_call(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    (recv = node.receiver_node());
    if (!(constant_ref_q(recv))) {
      return RubyNil(RUBY_NIL);
    }
    if (iv_user_methods->key_q(node.name())) {
      auto flat = iv_env->type_of(({ auto _e0 = ruby_sym("return"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }));
      if (!(flat.bottom_q())) {
      return flat;
    };
    }
    if (!(iv_user_classes->key_q(recv.name()))) {
      return RubyNil(RUBY_NIL);
    }
    auto ret = iv_env->type_of(({ auto _e0 = ruby_sym("return"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = recv.name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }); _a; }));
    if (ret.bottom_q()) {
      return RubyNil(RUBY_NIL);
    } else {
      return ret;
    }
  }

  RubyNil try_infer_instance_method_call(auto node, gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(infer_expr(recv, ctx))> recv_ty{};
    (recv = node.receiver_node());
    if (!(recv)) {
      return RubyNil(RUBY_NIL);
    }
    (recv_ty = infer_expr(recv, ctx));
    if (!(recv_ty.class_type_q())) {
      return RubyNil(RUBY_NIL);
    }
    return iv_env->type_of(({ auto _e0 = ruby_sym("return"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = recv_ty.class_name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }); _a; }));
  }

  RubyNil try_infer_free_call(auto node, gc_ref<Ruby_TypeContext> _ctx) {
    if (ruby_nil_q(node.receiver_node())) {
      return iv_env->type_of(({ auto _e0 = ruby_sym("return"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }));
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* infer_block_return(auto block_node, auto param_types, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_block_return\n"); std::abort();
    return nullptr;
  }

  RubyObject* seed_block_params(auto block_node, auto param_types, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub seed_block_params\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> block_param_types(auto method_name, auto recv_node, gc_ref<Ruby_TypeContext> ctx) {
    int64_t recv_ty = 0;
    if ((method_name == ruby_sym("times")) || (method_name == ruby_sym("upto")) || (method_name == ruby_sym("downto"))) {
      return coerce_to_ref<RubyObject>(({ auto _e0 = INT64_C(0) /* ::I64 */; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    } else if ((method_name == ruby_sym("each")) || (method_name == ruby_sym("map")) || (method_name == ruby_sym("flat_map")) || (method_name == ruby_sym("select")) || (method_name == ruby_sym("reject")) || (method_name == ruby_sym("filter")) || (method_name == ruby_sym("each_with_object")) || (method_name == ruby_sym("min_by")) || (method_name == ruby_sym("max_by")) || (method_name == ruby_sym("sort_by")) || (method_name == ruby_sym("any?")) || (method_name == ruby_sym("all?")) || (method_name == ruby_sym("none?")) || (method_name == ruby_sym("find")) || (method_name == ruby_sym("detect")) || (method_name == ruby_sym("count")) || (method_name == ruby_sym("sum")) || (method_name == ruby_sym("reduce")) || (method_name == ruby_sym("inject"))) {
      return coerce_to_ref<RubyObject>((recv_ty = (recv_node ? (infer_expr(recv_node, ctx)) : (INT64_C(0) /* ::BOTTOM */))); if (recv_ty.class_type_q()) {
        if (recv_ty.array_q()) {
        return ({ auto _e0 = ({ auto _l = (recv_ty.elem()); (_l) ? decltype((INT64_C(0) /* ::BOTTOM */))(_l) : (INT64_C(0) /* ::BOTTOM */); }); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; });
      };
        if ((recv_ty.class_name() == ruby_sym("Range"))) {
        return ({ auto _e0 = INT64_C(0) /* ::I64 */; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; });
      };
      }; RubyArray_I64(0));
    } else if ((method_name == ruby_sym("each_with_index"))) {
      return coerce_to_ref<RubyObject>((recv_ty = (recv_node ? (infer_expr(recv_node, ctx)) : (INT64_C(0) /* ::BOTTOM */))); (recv_ty.array_q() ? (({ auto _e0 = ({ auto _l = (recv_ty.elem()); (_l) ? decltype((INT64_C(0) /* ::BOTTOM */))(_l) : (INT64_C(0) /* ::BOTTOM */); }); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = INT64_C(0) /* ::I64 */; _a; })) : (({ auto _e0 = INT64_C(0) /* ::BOTTOM */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = INT64_C(0) /* ::I64 */; _a; }))));
    } else {
      return coerce_to_ref<RubyObject>(RubyArray_I64(0));
    }
  }

  RubyObject* infer_body_return(auto node, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_body_return\n"); std::abort();
    return nullptr;
  }

  bool infinite_loop_q(auto node) {
    std::decay_t<decltype(node.condition_node())> cond{};
    std::decay_t<decltype(({ auto _cs = node; ((_cs == INT64_C(0) /* ::While */)) ? (true) : (((_cs == INT64_C(0) /* ::Until */)) ? (true) : (RUBY_NIL)); }))> cond_is_constant_true{};
    (cond = node.condition_node());
    while (({ auto _l = (true); (_l) ? decltype(((cond.nodes().len() == INT64_C(1))))((cond.nodes().len() == INT64_C(1))) : decltype(((cond.nodes().len() == INT64_C(1))))(_l); })) {
      (cond = cond.nodes().first());
    }
    if (!(cond)) {
      return false;
    }
    (cond_is_constant_true = ({ auto _cs = node; ((_cs == INT64_C(0) /* ::While */)) ? (true) : (((_cs == INT64_C(0) /* ::Until */)) ? (true) : (RUBY_NIL)); }));
    if (!(cond_is_constant_true)) {
      return false;
    }
    return (!(contains_break_q(node.body_node())));
  }

  gc_ref<RubyObject> contains_break_q(auto node) {
    if (!(node)) {
      return false;
    }
    if (true) {
      return true;
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = (true); (_l) ? decltype((true))(_l) : (true); })); (_l) ? decltype((true))(_l) : (true); })); (_l) ? decltype((({ auto _l = (true); (_l) ? decltype((({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())))(({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())) : decltype((({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())))(_l); })))(_l) : (({ auto _l = (true); (_l) ? decltype((({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())))(({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())) : decltype((({ auto _e0 = ruby_sym("times"); auto _a = RubyArray<decltype(_e0)>(8); _a[0] = _e0; _a[1] = ruby_sym("each"); _a[2] = ruby_sym("each_with_index"); _a[3] = ruby_sym("upto"); _a[4] = ruby_sym("downto"); _a[5] = ruby_sym("map"); _a[6] = ruby_sym("select"); _a[7] = ruby_sym("reject"); _a; }).include_q(node.name())))(_l); })); })) {
      return false;
    }
    return coerce_to_ref<RubyObject>(node.children().any_q());
  }

  RubyObject* scan_returns(auto node, auto ctx, auto acc) {
    std::fprintf(stderr, "frozone: called TI-gap stub scan_returns\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_assignments(auto node, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_assignments\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_ivar_assignments(auto node, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_ivar_assignments\n"); std::abort();
    return nullptr;
  }

  RubyObject* escapes_q(auto name, auto body, auto ctx) {
    std::fprintf(stderr, "frozone: called TI-gap stub escapes_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* escapes_only_via_return_array_q(auto name, auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub escapes_only_via_return_array_q\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> writes_consistent_q(auto name, auto body, gc_ref<Ruby_TypeContext> ctx, auto elem_ty) {
    gc_local<RubyObject> ok = nullptr;
    RubyArray<int64_t> args;
    std::decay_t<decltype(infer_expr(args[INT64_C(1)], ctx))> val_ty{};
    (ok = true);
    walk(body, [&](auto node) { return if (!(({ auto _l = (({ auto _l = (true); (_l) ? decltype(((node.name() == ruby_sym("[]="))))((node.name() == ruby_sym("[]="))) : decltype(((node.name() == ruby_sym("[]="))))(_l); })); (_l) ? decltype((node.receiver_node().then()))(node.receiver_node().then()) : decltype((node.receiver_node().then()))(_l); }))) {
      continue;
    }; (args = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })); if (args[INT64_C(1)]) {
      (val_ty = infer_expr(args[INT64_C(1)], ctx));
    }; if (({ auto _l = (ruby_nil_q(val_ty)); (_l) ? decltype((val_ty.bottom_q()))(_l) : (val_ty.bottom_q()); })) {
      continue;
    }; (({ auto _l = ((val_ty == elem_ty)); (_l) ? decltype((({ auto _l = (val_ty.i64_q()); (_l) ? decltype((elem_ty.f64_q()))(elem_ty.f64_q()) : decltype((elem_ty.f64_q()))(_l); })))(_l) : (({ auto _l = (val_ty.i64_q()); (_l) ? decltype((elem_ty.f64_q()))(elem_ty.f64_q()) : decltype((elem_ty.f64_q()))(_l); })); }) ? (RUBY_NIL) : ((ok = false))); })
    return coerce_to_ref<RubyObject>(ok);
  }

  RubyObject* walk(auto node, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub walk\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_class_ancestors() {
    std::fprintf(stderr, "frozone: called TI-gap stub build_class_ancestors\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> compute_user_ancestors(auto klass) {
    RubyArray<int64_t> chain;
    RubyNil current;
    std::decay_t<decltype(current.name())> cname{};
    (chain = RubyArray_I64(0));
    (current = (false ? (klass.superclass()) : (RUBY_NIL)));
    while (current) {
      (cname = current.name());
      if (!(cname)) {
      break;
    };
      (chain << cname);
      if (BUILTIN_ANCESTORS.key_q(cname)) {
      chain.concat(BUILTIN_ANCESTORS[cname]);
      break;
    };
      (current = current.superclass());
    }
    (chain = (chain | ({ auto _e0 = ruby_sym("Object"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ruby_sym("BasicObject"); _a; })));
    return chain;
  }

  RubyObject* ancestors_of(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub ancestors_of\n"); std::abort();
    return nullptr;
  }

  RubyObject* lca_type(auto a_name, auto b_name) {
    std::fprintf(stderr, "frozone: called TI-gap stub lca_type\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Type> resolve_param_joins(auto a, auto b, auto merged) {
    gc_local<RubyObject> elem = nullptr;
    gc_local<RubyObject> key = nullptr;
    gc_local<RubyObject> val = nullptr;
    if (!(needs_param_resolution_q(merged))) {
      return merged;
    }
    (elem = ((merged.elem() == ruby_sym("needs_join")) ? (join(a.elem(), b.elem())) : (merged.elem())));
    (key = ((merged.key() == ruby_sym("needs_join")) ? (join(a.key(), b.key())) : (merged.key())));
    (val = ((merged.val() == ruby_sym("needs_join")) ? (join(a.val(), b.val())) : (merged.val())));
    return gc_new<Ruby_Type>(ruby_sym("class_type"));
  }

  RubyObject* needs_param_resolution_q(auto t) {
    std::fprintf(stderr, "frozone: called TI-gap stub needs_param_resolution_q\n"); std::abort();
    return nullptr;
  }

  RubyNil best_constructor_param_types(auto class_name, auto param_count) {
    std::decay_t<decltype(iv_env->slots())> slots{};
    gc_local<Ruby_Set> contexts = nullptr;
    (slots = iv_env->slots());
    (contexts = gc_new<Ruby_Set>());
    slots.each_key();
    if (contexts->empty_q()) {
      return RubyNil(RUBY_NIL);
    }
    return param_count.times().map();
  }

  RubyObject* vm_object_type(auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub vm_object_type\n"); std::abort();
    return nullptr;
  }

  bool array_new_call_q(auto node) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    if (!(true)) {
      return false;
    }
    if (!((node.name() == ruby_sym("new")))) {
      return false;
    }
    (recv = node.receiver_node());
    if (!(({ auto _l = (true); (_l) ? decltype(((recv.name() == ruby_sym("Array"))))((recv.name() == ruby_sym("Array"))) : decltype(((recv.name() == ruby_sym("Array"))))(_l); }))) {
      return false;
    }
    return ruby_nil_q(node.block_node());
  }

  RubyNil each_user_instance_method(auto class_name, auto klass) {
    std::decay_t<decltype(klass.eigenclass())> eigenclass{};
    { auto _coll = ({ auto _l = (klass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
      if (!(({ auto _l = (true); (_l) ? decltype((method.body()))(method.body()) : decltype((method.body()))(_l); }))) {
        continue;
      };
      _block(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), method);
    } }
    (eigenclass = klass.eigenclass());
    if (eigenclass) {
      return { auto _coll = ({ auto _l = (eigenclass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& mname : *_coll.data) {
        if (!(({ auto _l = (true); (_l) ? decltype((method.body()))(method.body()) : decltype((method.body()))(_l); }))) {
          continue;
        };
        _block(({ auto _e0 = class_name; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mname; _a; }), method);
      } };
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* param_index(auto ctx, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub param_index\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> param_names_for(gc_ref<Ruby_TypeContext> ctx) {
    std::decay_t<decltype(ctx->method_key())> mkey{};
    std::decay_t<decltype(method_for_key(mkey))> method{};
    (mkey = ctx->method_key());
    if (!(mkey)) {
      return RubyArray_I64(0);
    }
    (method = method_for_key(mkey));
    if (!(method)) {
      return RubyArray_I64(0);
    }
    return (((({ auto _l = (method.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }) + ({ auto _l = (method.optional_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map()) + ({ auto _e0 = method.rest_param(); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }).compact()) + ({ auto _l = (method.post_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
  }

  RubyObject* method_for_key(auto mkey) {
    std::fprintf(stderr, "frozone: called TI-gap stub method_for_key\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_TypeInference>() { return "TypeInference"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TypeInference> : dustman::FieldList<Ruby_TypeInference, &Ruby_TypeInference::iv_env> {};
#endif

struct Ruby_MethodContext : public RubyObject {
  RubyHash<RubySymbol, int64_t> iv_typed_locals;
  RubyHash<RubySymbol, int64_t> iv_typed_array_locals;
  RubyHash<RubySymbol, int64_t> iv_native_array_locals;
  RubyHash<RubySymbol, int64_t> iv_class_locals;
  RubyHash<RubySymbol, int64_t> iv_local_array_elems;
  RubyHash<RubySymbol, int64_t> iv_local_types;
  RubyHash<RubySymbol, int64_t> iv_block_params;
  RubyHash<RubySymbol, int64_t> iv_raw_block_params;
  gc_ref<Ruby_Set> iv_param_set;
  RubyNil iv_method_body;
  RubyNil iv_block_param_name;
  gc_ref<RubyObject> iv_suppress_typed_call_args;
  bool iv_emit_crystal_tuple = false;
  gc_ref<RubyObject> iv_suppress_tuple_literals;
  gc_ref<RubyObject> iv_bool_return;
  gc_ref<RubyObject> iv_int32_return;
  bool iv_class_method = false;
  gc_ref<RubyObject> iv_current_method_obj = nullptr;

  Ruby_MethodContext() {
    iv_typed_locals = RubyHash<RubySymbol, int64_t>{};
    iv_typed_array_locals = RubyHash<RubySymbol, int64_t>{};
    iv_native_array_locals = RubyHash<RubySymbol, int64_t>{};
    iv_class_locals = RubyHash<RubySymbol, int64_t>{};
    iv_local_array_elems = RubyHash<RubySymbol, int64_t>{};
    iv_local_types = RubyHash<RubySymbol, int64_t>{};
    iv_block_params = RubyHash<RubySymbol, int64_t>{};
    iv_raw_block_params = RubyHash<RubySymbol, int64_t>{};
    iv_param_set = gc_new<Ruby_Set>();
    iv_method_body = RUBY_NIL;
    iv_block_param_name = RUBY_NIL;
    iv_suppress_typed_call_args = coerce_to_ref<RubyObject>(false);
    iv_emit_crystal_tuple = false;
    iv_suppress_tuple_literals = coerce_to_ref<RubyObject>(false);
  }
  const char* rb_class_name() const override { return "MethodContext"; }

  RubyHash<RubySymbol, int64_t> typed_locals() {
    return iv_typed_locals;
  }

  RubyHash<RubySymbol, int64_t> set_typed_locals(auto __anon_req__) {
    iv_typed_locals = __anon_req__;
    return iv_typed_locals;
  }

  RubyHash<RubySymbol, int64_t> typed_array_locals() {
    return iv_typed_array_locals;
  }

  RubyHash<RubySymbol, int64_t> set_typed_array_locals(auto __anon_req__) {
    iv_typed_array_locals = __anon_req__;
    return iv_typed_array_locals;
  }

  RubyHash<RubySymbol, int64_t> native_array_locals() {
    return iv_native_array_locals;
  }

  RubyHash<RubySymbol, int64_t> set_native_array_locals(auto __anon_req__) {
    iv_native_array_locals = __anon_req__;
    return iv_native_array_locals;
  }

  RubyHash<RubySymbol, int64_t> class_locals() {
    return iv_class_locals;
  }

  RubyHash<RubySymbol, int64_t> set_class_locals(auto __anon_req__) {
    iv_class_locals = __anon_req__;
    return iv_class_locals;
  }

  RubyHash<RubySymbol, int64_t> local_array_elems() {
    return iv_local_array_elems;
  }

  RubyHash<RubySymbol, int64_t> set_local_array_elems(auto __anon_req__) {
    iv_local_array_elems = __anon_req__;
    return iv_local_array_elems;
  }

  RubyHash<RubySymbol, int64_t> local_types() {
    return iv_local_types;
  }

  RubyHash<RubySymbol, int64_t> set_local_types(auto __anon_req__) {
    iv_local_types = __anon_req__;
    return iv_local_types;
  }

  RubyHash<RubySymbol, int64_t> block_params() {
    return iv_block_params;
  }

  RubyHash<RubySymbol, int64_t> set_block_params(auto __anon_req__) {
    iv_block_params = __anon_req__;
    return iv_block_params;
  }

  RubyHash<RubySymbol, int64_t> raw_block_params() {
    return iv_raw_block_params;
  }

  RubyHash<RubySymbol, int64_t> set_raw_block_params(auto __anon_req__) {
    iv_raw_block_params = __anon_req__;
    return iv_raw_block_params;
  }

  gc_ref<Ruby_Set> param_set() {
    return iv_param_set;
  }

  gc_ref<Ruby_Set> set_param_set(gc_ref<Ruby_Set> __anon_req__) {
    iv_param_set = __anon_req__;
    return iv_param_set;
  }

  RubyNil method_body() {
    return iv_method_body;
  }

  RubyNil set_method_body(auto __anon_req__) {
    iv_method_body = __anon_req__;
    return iv_method_body;
  }

  RubyNil block_param_name() {
    return iv_block_param_name;
  }

  RubyNil set_block_param_name(auto __anon_req__) {
    iv_block_param_name = __anon_req__;
    return iv_block_param_name;
  }

  gc_ref<RubyObject> suppress_typed_call_args() {
    return iv_suppress_typed_call_args;
  }

  gc_ref<RubyObject> set_suppress_typed_call_args(gc_ref<RubyObject> __anon_req__) {
    iv_suppress_typed_call_args = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_suppress_typed_call_args;
  }

  bool emit_crystal_tuple() {
    return iv_emit_crystal_tuple;
  }

  bool set_emit_crystal_tuple(auto __anon_req__) {
    iv_emit_crystal_tuple = __anon_req__;
    return iv_emit_crystal_tuple;
  }

  gc_ref<RubyObject> suppress_tuple_literals() {
    return iv_suppress_tuple_literals;
  }

  gc_ref<RubyObject> set_suppress_tuple_literals(gc_ref<RubyObject> __anon_req__) {
    iv_suppress_tuple_literals = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_suppress_tuple_literals;
  }

  gc_ref<RubyObject> bool_return() {
    return iv_bool_return;
  }

  gc_ref<RubyObject> set_bool_return(gc_ref<RubyObject> __anon_req__) {
    iv_bool_return = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_bool_return;
  }

  gc_ref<RubyObject> int32_return() {
    return iv_int32_return;
  }

  gc_ref<RubyObject> set_int32_return(gc_ref<RubyObject> __anon_req__) {
    iv_int32_return = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_int32_return;
  }

  bool class_method() {
    return iv_class_method;
  }

  bool set_class_method(auto __anon_req__) {
    iv_class_method = __anon_req__;
    return iv_class_method;
  }

  RubyObject* current_method_obj() {
    std::fprintf(stderr, "frozone: called TI-gap stub current_method_obj\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_current_method_obj(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_current_method_obj\n"); std::abort();
    return nullptr;
  }

  RubyObject* param_q(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub param_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* native_array_elem(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub native_array_elem\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_MethodContext>() { return "MethodContext"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_MethodContext> : dustman::FieldList<Ruby_MethodContext, &Ruby_MethodContext::iv_param_set, &Ruby_MethodContext::iv_suppress_typed_call_args, &Ruby_MethodContext::iv_suppress_tuple_literals, &Ruby_MethodContext::iv_bool_return, &Ruby_MethodContext::iv_int32_return> {};
#endif

struct Ruby_ClassContext : public RubyObject {
  RubyNil iv_name;
  RubyHash<RubySymbol, int64_t> iv_ivars;
  RubyHash<RubySymbol, int64_t> iv_typed_ivars;
  RubyNil iv_eigen_methods;
  gc_ref<Ruby_Set> iv_parent_ivars;

  Ruby_ClassContext() {
    iv_name = RUBY_NIL;
    iv_ivars = RubyHash<RubySymbol, int64_t>{};
    iv_typed_ivars = RubyHash<RubySymbol, int64_t>{};
    iv_eigen_methods = RUBY_NIL;
    iv_parent_ivars = gc_new<Ruby_Set>();
  }
  const char* rb_class_name() const override { return "ClassContext"; }

  RubyNil name() {
    return iv_name;
  }

  RubyNil set_name(auto __anon_req__) {
    iv_name = __anon_req__;
    return iv_name;
  }

  RubyHash<RubySymbol, int64_t> ivars() {
    return iv_ivars;
  }

  RubyHash<RubySymbol, int64_t> set_ivars(auto __anon_req__) {
    iv_ivars = __anon_req__;
    return iv_ivars;
  }

  RubyHash<RubySymbol, int64_t> typed_ivars() {
    return iv_typed_ivars;
  }

  RubyHash<RubySymbol, int64_t> set_typed_ivars(auto __anon_req__) {
    iv_typed_ivars = __anon_req__;
    return iv_typed_ivars;
  }

  RubyNil eigen_methods() {
    return iv_eigen_methods;
  }

  RubyNil set_eigen_methods(auto __anon_req__) {
    iv_eigen_methods = __anon_req__;
    return iv_eigen_methods;
  }

  gc_ref<Ruby_Set> parent_ivars() {
    return iv_parent_ivars;
  }

  gc_ref<Ruby_Set> set_parent_ivars(gc_ref<Ruby_Set> __anon_req__) {
    iv_parent_ivars = __anon_req__;
    return iv_parent_ivars;
  }

};
template<> inline const char* ruby_class_name<Ruby_ClassContext>() { return "ClassContext"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_ClassContext> : dustman::FieldList<Ruby_ClassContext, &Ruby_ClassContext::iv_parent_ivars> {};
#endif

struct Ruby_GlobalContext : public RubyObject {
  gc_ref<Ruby_Set> iv_user_class_names;
  RubyHash<RubySymbol, int64_t> iv_locals;
  RubyHash<RubySymbol, int64_t> iv_arrays;
  RubyHash<RubySymbol, int64_t> iv_class_locals;
  RubyHash<RubySymbol, int64_t> iv_local_array_elems;
  RubyHash<RubySymbol, int64_t> iv_local_types;
  RubyHash<RubySymbol, int64_t> iv_block_params;
  RubyHash<RubySymbol, int64_t> iv_class_params;
  RubyHash<RubySymbol, int64_t> iv_inferred_params;
  RubyHash<RubySymbol, int64_t> iv_typed_params;
  RubyHash<RubySymbol, int64_t> iv_typed_method_returns;
  RubyHash<RubySymbol, int64_t> iv_instance_method_raw_returns;
  RubyHash<RubySymbol, int64_t> iv_const_raw_types;
  RubyHash<RubySymbol, int64_t> iv_inferred_kw_params;
  RubyHash<RubySymbol, int64_t> iv_typed_ivars;
  RubyHash<RubySymbol, int64_t> iv_class_typed_ivars;
  RubyHash<RubySymbol, int64_t> iv_method_uses_block;

  Ruby_GlobalContext() {
    iv_user_class_names = gc_new<Ruby_Set>();
    iv_method_uses_block = RubyHash<RubySymbol, int64_t>{};
    iv_locals = RubyHash<RubySymbol, int64_t>{};
    iv_arrays = RubyHash<RubySymbol, int64_t>{};
    iv_class_locals = RubyHash<RubySymbol, int64_t>{};
    iv_local_array_elems = RubyHash<RubySymbol, int64_t>{};
    iv_local_types = RubyHash<RubySymbol, int64_t>{};
    iv_block_params = RubyHash<RubySymbol, int64_t>{};
    iv_class_params = RubyHash<RubySymbol, int64_t>{};
    iv_inferred_params = RubyHash<RubySymbol, int64_t>{};
    iv_typed_params = RubyHash<RubySymbol, int64_t>{};
    iv_typed_method_returns = RubyHash<RubySymbol, int64_t>{};
    iv_instance_method_raw_returns = RubyHash<RubySymbol, int64_t>{};
    iv_const_raw_types = RubyHash<RubySymbol, int64_t>{};
    iv_inferred_kw_params = RubyHash<RubySymbol, int64_t>{};
    iv_typed_ivars = RubyHash<RubySymbol, int64_t>{};
    iv_class_typed_ivars = RubyHash<RubySymbol, int64_t>{};
  }
  const char* rb_class_name() const override { return "GlobalContext"; }

  gc_ref<Ruby_Set> user_class_names() {
    return iv_user_class_names;
  }

  gc_ref<Ruby_Set> set_user_class_names(gc_ref<Ruby_Set> __anon_req__) {
    iv_user_class_names = __anon_req__;
    return iv_user_class_names;
  }

  RubyHash<RubySymbol, int64_t> locals() {
    return iv_locals;
  }

  RubyHash<RubySymbol, int64_t> set_locals(auto __anon_req__) {
    iv_locals = __anon_req__;
    return iv_locals;
  }

  RubyHash<RubySymbol, int64_t> arrays() {
    return iv_arrays;
  }

  RubyHash<RubySymbol, int64_t> set_arrays(auto __anon_req__) {
    iv_arrays = __anon_req__;
    return iv_arrays;
  }

  RubyHash<RubySymbol, int64_t> class_locals() {
    return iv_class_locals;
  }

  RubyHash<RubySymbol, int64_t> set_class_locals(auto __anon_req__) {
    iv_class_locals = __anon_req__;
    return iv_class_locals;
  }

  RubyHash<RubySymbol, int64_t> local_array_elems() {
    return iv_local_array_elems;
  }

  RubyHash<RubySymbol, int64_t> set_local_array_elems(auto __anon_req__) {
    iv_local_array_elems = __anon_req__;
    return iv_local_array_elems;
  }

  RubyHash<RubySymbol, int64_t> local_types() {
    return iv_local_types;
  }

  RubyHash<RubySymbol, int64_t> set_local_types(auto __anon_req__) {
    iv_local_types = __anon_req__;
    return iv_local_types;
  }

  RubyHash<RubySymbol, int64_t> block_params() {
    return iv_block_params;
  }

  RubyHash<RubySymbol, int64_t> set_block_params(auto __anon_req__) {
    iv_block_params = __anon_req__;
    return iv_block_params;
  }

  RubyHash<RubySymbol, int64_t> class_params() {
    return iv_class_params;
  }

  RubyHash<RubySymbol, int64_t> set_class_params(auto __anon_req__) {
    iv_class_params = __anon_req__;
    return iv_class_params;
  }

  RubyHash<RubySymbol, int64_t> inferred_params() {
    return iv_inferred_params;
  }

  RubyHash<RubySymbol, int64_t> set_inferred_params(auto __anon_req__) {
    iv_inferred_params = __anon_req__;
    return iv_inferred_params;
  }

  RubyHash<RubySymbol, int64_t> typed_params() {
    return iv_typed_params;
  }

  RubyHash<RubySymbol, int64_t> set_typed_params(auto __anon_req__) {
    iv_typed_params = __anon_req__;
    return iv_typed_params;
  }

  RubyHash<RubySymbol, int64_t> typed_method_returns() {
    return iv_typed_method_returns;
  }

  RubyHash<RubySymbol, int64_t> set_typed_method_returns(auto __anon_req__) {
    iv_typed_method_returns = __anon_req__;
    return iv_typed_method_returns;
  }

  RubyHash<RubySymbol, int64_t> instance_method_raw_returns() {
    return iv_instance_method_raw_returns;
  }

  RubyHash<RubySymbol, int64_t> set_instance_method_raw_returns(auto __anon_req__) {
    iv_instance_method_raw_returns = __anon_req__;
    return iv_instance_method_raw_returns;
  }

  RubyHash<RubySymbol, int64_t> const_raw_types() {
    return iv_const_raw_types;
  }

  RubyHash<RubySymbol, int64_t> set_const_raw_types(auto __anon_req__) {
    iv_const_raw_types = __anon_req__;
    return iv_const_raw_types;
  }

  RubyHash<RubySymbol, int64_t> inferred_kw_params() {
    return iv_inferred_kw_params;
  }

  RubyHash<RubySymbol, int64_t> set_inferred_kw_params(auto __anon_req__) {
    iv_inferred_kw_params = __anon_req__;
    return iv_inferred_kw_params;
  }

  RubyHash<RubySymbol, int64_t> typed_ivars() {
    return iv_typed_ivars;
  }

  RubyHash<RubySymbol, int64_t> set_typed_ivars(auto __anon_req__) {
    iv_typed_ivars = __anon_req__;
    return iv_typed_ivars;
  }

  RubyHash<RubySymbol, int64_t> class_typed_ivars() {
    return iv_class_typed_ivars;
  }

  RubyHash<RubySymbol, int64_t> set_class_typed_ivars(auto __anon_req__) {
    iv_class_typed_ivars = __anon_req__;
    return iv_class_typed_ivars;
  }

  RubyHash<RubySymbol, int64_t> method_uses_block() {
    return iv_method_uses_block;
  }

  RubyHash<RubySymbol, int64_t> set_method_uses_block(auto __anon_req__) {
    iv_method_uses_block = __anon_req__;
    return iv_method_uses_block;
  }

  RubyObject* load_from_mapper_b(auto mapper) {
    std::fprintf(stderr, "frozone: called TI-gap stub load_from_mapper_b\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_GlobalContext>() { return "GlobalContext"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_GlobalContext> : dustman::FieldList<Ruby_GlobalContext, &Ruby_GlobalContext::iv_user_class_names> {};
#endif

struct Ruby_CompileContext : public RubyObject {
  gc_ref<RubyObject> iv_top_level_scope = nullptr;
  RubyNil iv_stub_file;
  gc_ref<Ruby_Set> iv_masgn_return_methods;
  gc_ref<Ruby_Set> iv_object_instance_methods;
  gc_ref<Ruby_Set> iv_user_methods;
  RubyHash<RubyString, int64_t> iv_method_index;
  gc_ref<RubyObject> iv_in_execute_block;

  Ruby_CompileContext() = default;
  Ruby_CompileContext(auto top_level_scope, int64_t stub_file = RUBY_NIL) {
    iv_top_level_scope = top_level_scope;
    iv_stub_file = stub_file;
    iv_masgn_return_methods = nullptr;
    iv_object_instance_methods = gc_new<Ruby_Set>();
    iv_user_methods = gc_new<Ruby_Set>();
    iv_method_index = RubyHash<RubySymbol, int64_t>{};
    iv_in_execute_block = coerce_to_ref<RubyObject>(false);
  }
  const char* rb_class_name() const override { return "CompileContext"; }

  RubyObject* top_level_scope() {
    std::fprintf(stderr, "frozone: called TI-gap stub top_level_scope\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_top_level_scope(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_top_level_scope\n"); std::abort();
    return nullptr;
  }

  RubyNil stub_file() {
    return iv_stub_file;
  }

  RubyNil set_stub_file(auto __anon_req__) {
    iv_stub_file = __anon_req__;
    return iv_stub_file;
  }

  gc_ref<Ruby_Set> masgn_return_methods() {
    return iv_masgn_return_methods;
  }

  gc_ref<Ruby_Set> set_masgn_return_methods(gc_ref<Ruby_Set> __anon_req__) {
    iv_masgn_return_methods = __anon_req__;
    return iv_masgn_return_methods;
  }

  gc_ref<Ruby_Set> object_instance_methods() {
    return iv_object_instance_methods;
  }

  gc_ref<Ruby_Set> set_object_instance_methods(gc_ref<Ruby_Set> __anon_req__) {
    iv_object_instance_methods = __anon_req__;
    return iv_object_instance_methods;
  }

  gc_ref<Ruby_Set> user_methods() {
    return iv_user_methods;
  }

  gc_ref<Ruby_Set> set_user_methods(gc_ref<Ruby_Set> __anon_req__) {
    iv_user_methods = __anon_req__;
    return iv_user_methods;
  }

  RubyHash<RubyString, int64_t> method_index() {
    return iv_method_index;
  }

  RubyHash<RubyString, int64_t> set_method_index(auto __anon_req__) {
    iv_method_index = __anon_req__;
    return iv_method_index;
  }

  gc_ref<RubyObject> in_execute_block() {
    return iv_in_execute_block;
  }

  gc_ref<RubyObject> set_in_execute_block(gc_ref<RubyObject> __anon_req__) {
    iv_in_execute_block = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_execute_block;
  }

  RubyObject* bench_stub_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub bench_stub_q\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_CompileContext>() { return "CompileContext"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_CompileContext> : dustman::FieldList<Ruby_CompileContext, &Ruby_CompileContext::iv_masgn_return_methods, &Ruby_CompileContext::iv_object_instance_methods, &Ruby_CompileContext::iv_user_methods, &Ruby_CompileContext::iv_in_execute_block> {};
#endif

struct Ruby_RawCtx : public RubyObject {
  int64_t iv_typed_locals = 0;
  int64_t iv_raw_block_params = 0;
  int64_t iv_class_locals = 0;
  int64_t iv_local_array_elems = 0;
  int64_t iv_typed_array_locals = 0;
  int64_t iv_native_array_locals = 0;
  int64_t iv_ivars = 0;

  Ruby_RawCtx() = default;
  Ruby_RawCtx(auto _typed_locals, auto _raw_block_params, auto _class_locals, auto _local_array_elems, auto _typed_array_locals, auto _native_array_locals, auto _ivars) {
    iv_typed_locals = _typed_locals;
    iv_raw_block_params = _raw_block_params;
    iv_class_locals = _class_locals;
    iv_local_array_elems = _local_array_elems;
    iv_typed_array_locals = _typed_array_locals;
    iv_native_array_locals = _native_array_locals;
    iv_ivars = _ivars;
  }
  const char* rb_class_name() const override { return "RawCtx"; }

  auto typed_locals() const { return iv_typed_locals; }
  void set_typed_locals(auto v) { iv_typed_locals = v; }
  auto raw_block_params() const { return iv_raw_block_params; }
  void set_raw_block_params(auto v) { iv_raw_block_params = v; }
  auto class_locals() const { return iv_class_locals; }
  void set_class_locals(auto v) { iv_class_locals = v; }
  auto local_array_elems() const { return iv_local_array_elems; }
  void set_local_array_elems(auto v) { iv_local_array_elems = v; }
  auto typed_array_locals() const { return iv_typed_array_locals; }
  void set_typed_array_locals(auto v) { iv_typed_array_locals = v; }
  auto native_array_locals() const { return iv_native_array_locals; }
  void set_native_array_locals(auto v) { iv_native_array_locals = v; }
  auto ivars() const { return iv_ivars; }
  void set_ivars(auto v) { iv_ivars = v; }

};
template<> inline const char* ruby_class_name<Ruby_RawCtx>() { return "RawCtx"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_RawCtx> : dustman::FieldList<Ruby_RawCtx> {};
#endif

struct Ruby_Codegen : public Ruby_CrystalEmitter {
  inline static const int64_t MAX_TUPLE_SIZE = 8LL;
  inline static const RubyString CRYSTAL_DIR = RubyString("/home/rolandpj/src/frozone/crystal", 34);
  gc_ref<RubyObject> iv_opt_flags = nullptr;
  gc_ref<Ruby_CompileContext> iv_cc;
  gc_ref<Ruby_MethodContext> iv_mctx;
  gc_ref<Ruby_ClassContext> iv_cctx;
  gc_ref<Ruby_GlobalContext> iv_gctx;
  gc_ref<RubyObject> iv__pre_scan_symbol_count = nullptr;
  gc_ref<RubyObject> iv_literal_symbols = nullptr;
  gc_ref<RubyObject> iv_literal_arrays = nullptr;
  gc_ref<RubyObject> iv_literal_strings = nullptr;
  gc_ref<RubyObject> iv_out = nullptr;
  gc_ref<Ruby_Set> iv__declared_locals;
  gc_ref<RubyObject> iv__top_level_const_names = nullptr;
  gc_ref<RubyObject> iv__user_class_cache = nullptr;
  gc_ref<RubyObject> iv__declared_typed_locals = nullptr;
  gc_ref<RubyObject> iv__inside_nested_expr = nullptr;
  gc_ref<RubyObject> iv_temp_counter = nullptr;
  gc_ref<RubyObject> iv_indent = nullptr;
  gc_ref<RubyObject> iv_user_overridden_ops = nullptr;
  gc_ref<RubyObject> iv__constructor_param_types = nullptr;
  gc_ref<RubyObject> iv_output_dir = nullptr;
  gc_ref<RubyObject> iv_errors = nullptr;
  gc_ref<RubyObject> iv_exception_classes = nullptr;
  gc_ref<RubyObject> iv_user_methods = nullptr;
  gc_ref<RubyObject> iv_current_block_param_name = nullptr;
  gc_ref<RubyObject> iv_in_exception_class = nullptr;

  Ruby_Codegen() = default;
  Ruby_Codegen(int64_t opt_level = RUBY_NIL) {
    /* UNSUPPORTED: Super */;
    auto level = ({ auto _l = (opt_level); (_l) ? decltype(((int64_t)(ENV.fetch(RubyString("FROZONE_OPT_LEVEL", 17), RubyString("2", 1)))))(_l) : ((int64_t)(ENV.fetch(RubyString("FROZONE_OPT_LEVEL", 17), RubyString("2", 1)))); });
    auto enabled = OPT_LEVELS.fetch(level, OPT_FLAGS).to_set();
    { auto _coll = OPT_FLAGS; for (auto& flag : *_coll.data) {
      RubyString env_key = (RubyString("FROZONE_NO_", 11) + ruby_to_s(flag.upcase()));
      if (ENV[env_key]) {
        enabled.rb_delete(flag);
      };
    } }
    iv_opt_flags = enabled;
  }
  const char* rb_class_name() const override { return "Codegen"; }

  RubyObject* opt_q(auto flag) {
    std::fprintf(stderr, "frozone: called TI-gap stub opt_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* generate(auto execute_block, auto top_level_scope, auto globals, auto stub_file) {
    std::fprintf(stderr, "frozone: called TI-gap stub generate\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_late_symbols() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_late_symbols\n"); std::abort();
    return nullptr;
  }

  RubyObject* bench_stub_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub bench_stub_q\n"); std::abort();
    return nullptr;
  }

  RubyNil receiver_known_class(auto recv) {
    std::decay_t<decltype(iv_mctx->class_locals()[recv.name()])> cls_entry{};
    if (!(true)) {
      return RubyNil(RUBY_NIL);
    }
    (cls_entry = iv_mctx->class_locals()[recv.name()]);
    if (true) {
      return cls_entry[INT64_C(0)];
    } else {
      return cls_entry;
    }
  }

  RubyNil lookup_vm_class(auto name) {
    std::decay_t<decltype(iv_cc->top_level_scope().constants_table().fetch(name, RUBY_NIL))> val{};
    (val = iv_cc->top_level_scope().constants_table().fetch(name, RUBY_NIL));
    if (true) {
      return val;
    } else {
      return RubyNil(RUBY_NIL);
    }
  }

  bool user_source_location_q(auto loc) {
    if (ruby_nil_q(loc)) {
      return false;
    }
    auto file = (true ? (ruby_to_s(loc.first())) : (ruby_to_s(loc).sub(/* UNSUPPORTED: RegexpLiteral */, RubyString("", 0))));
    if (({ auto _l = (iv_cc->stub_file()); (_l) ? decltype(((file == iv_cc->stub_file())))((file == iv_cc->stub_file())) : decltype(((file == iv_cc->stub_file())))(_l); })) {
      return false;
    }
    return CORE_PATH_MARKERS.none_q();
  }

  RubyObject* emit_bench_harness_require() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_bench_harness_require\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_user_methods_from_scope(auto scope, auto visited) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_user_methods_from_scope\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_user_methods_from_block(auto block_node) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_user_methods_from_block\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_symbol_literals_from_scope(auto scope, auto visited) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_symbol_literals_from_scope\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_string_constants_from_scope(auto scope, auto visited) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_string_constants_from_scope\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_user_classes(auto scope, auto visited) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_user_classes\n"); std::abort();
    return nullptr;
  }

  bool has_user_descendants_q(auto mod, Ruby_Set* visited = gc_new<Ruby_Set>()) {
    RubyHash<RubySymbol, int64_t> const_locs;
    if (visited.include_q(mod.object_id())) {
      return false;
    }
    (visited << mod.object_id());
    (const_locs = ({ auto _l = (mod.constants_locations()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }));
    return mod.constants_table().any_q();
  }

  RubyNil emit_user_class(auto name, auto mod, int64_t const_loc = RUBY_NIL, Ruby_Set* visited = gc_new<Ruby_Set>()) {
    RubyHash<RubySymbol, int64_t> user_methods;
    bool has_own = false;
    gc_local<Ruby_ClassContext> old_cctx = nullptr;
    std::decay_t<decltype(iv_gctx->typed_ivars().fetch(name, RubyHash<RubySymbol, int64_t>{}))> ivars{};
    std::decay_t<decltype(collect_eigen_method_names(mod))> eigen_names{};
    if (({ auto _l = (({ auto _l = (true); (_l) ? decltype((struct_subclass_q(mod)))(struct_subclass_q(mod)) : decltype((struct_subclass_q(mod)))(_l); })); (_l) ? decltype(((mod.name() != ruby_sym("Struct"))))((mod.name() != ruby_sym("Struct"))) : decltype(((mod.name() != ruby_sym("Struct"))))(_l); })) {
      emit_struct_subclass(name, mod);
      return RubyNil(RUBY_NIL);
    }
    (user_methods = collect_class_user_methods(mod));
    (has_own = ({ auto _l = (user_methods.any_q()); (_l) ? decltype((user_source_location_q(const_loc)))(_l) : (user_source_location_q(const_loc)); }));
    if (has_own) {
      return emit_class_header(name, mod); (old_cctx = iv_cctx); iv_cctx = gc_new<Ruby_ClassContext>(); iv_cctx->set_name(name); iv_cctx->set_parent_ivars(collect_parent_ivars(mod)); (ivars = iv_gctx->typed_ivars().fetch(name, RubyHash<RubySymbol, int64_t>{})); (iv_cctx->parent_ivars().empty_q() ? (RUBY_NIL) : ((ivars = ivars.reject()))); iv_cctx->set_ivars(ivars); iv_cctx->set_typed_ivars(iv_gctx->class_typed_ivars().fetch(name, RubyHash<RubySymbol, int64_t>{})); indented([&]() { return emit_ivar_declarations(user_methods); emit_default_stringifiers(name, user_methods); emit_user_constants(mod); emit_newline(); (eigen_names = collect_eigen_method_names(mod)); emit_instance_methods(name, user_methods, eigen_names); emit_alias_forwarding_methods(mod, user_methods); emit_class_methods(name, mod, eigen_names); if (true) {
        emit_respond_to(mod);
      }; emit_user_classes(mod, visited); }); iv_cctx = old_cctx; iv_cctx->set_eigen_methods(RUBY_NIL); emit_indent(); write(RubyString("end", 3)); emit_newline();
    } else {
      if (has_user_descendants_q(mod)) {
        return emit_indent(); write((RubyString("module Ruby_", 12) + ruby_to_s(crystal_constant(name)))); emit_newline(); indented([&]() { return emit_user_classes(mod, visited); }); emit_indent(); write(RubyString("end", 3)); emit_newline();
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* emit_struct_subclass(auto name, auto cls) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_struct_subclass\n"); std::abort();
    return nullptr;
  }

  RubyNil struct_members_for(auto cls) {
    std::decay_t<decltype(cls.get_ivar(ruby_sym("@members")))> members_obj{};
    (members_obj = cls.get_ivar(ruby_sym("@members")));
    if (!(false)) {
      return RubyNil(RUBY_NIL);
    }
    return members_obj.raw().map();
  }

  RubyHash<RubySymbol, int64_t> collect_class_user_methods(auto mod) {
    gc_local<RubyObject> is_struct = nullptr;
    (is_struct = ({ auto _l = (true); (_l) ? decltype((struct_subclass_q(mod)))(struct_subclass_q(mod)) : decltype((struct_subclass_q(mod)))(_l); }));
    auto methods = mod.methods_table().select();
    return ({ auto _l = (methods); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); });
  }

  RubyObject* emit_class_header(auto name, auto mod) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_class_header\n"); std::abort();
    return nullptr;
  }

  RubyObject* crystal_superclass_path(auto cls) {
    std::fprintf(stderr, "frozone: called TI-gap stub crystal_superclass_path\n"); std::abort();
    return nullptr;
  }

  RubyNil emit_ivar_declarations(auto user_methods) {
    gc_local<Ruby_Set> parent_ivars = nullptr;
    auto all_ivars = user_methods.each_with_object(RubyArray_I64(0)).uniq();
    (parent_ivars = iv_cctx->parent_ivars());
    (parent_ivars->empty_q() ? (RUBY_NIL) : (all_ivars.reject_b()));
    { auto _coll = all_ivars; for (auto& iv : *_coll.data) {
      ({ auto _masgn = ivar_type_annotation(iv.to_sym()); auto type_ann = _masgn[INT64_C(0)]; auto rb_default = _masgn[INT64_C(1)]; });
      emit_indent();
      line((ruby_to_s(iv) + RubyString(" : ", 3) + ruby_to_s(type_ann) + RubyString(" = ", 3) + ruby_to_s(rb_default)));
    } }
    if (all_ivars.empty_q()) {
      return RubyNil(RUBY_NIL);
    } else {
      return emit_newline();
    }
  }

  gc_ref<Ruby_Set> collect_parent_ivars(auto mod) {
    gc_local<Ruby_Set> result = nullptr;
    RubyNil sc;
    std::decay_t<decltype(sc.name())> sc_name{};
    RubyHash<RubySymbol, int64_t> sc_methods;
    if (!(true)) {
      return gc_new<Ruby_Set>();
    }
    (result = gc_new<Ruby_Set>());
    (sc = mod.superclass());
    while (({ auto _l = (sc); (_l) ? decltype(((!(sc.equal_q(INT64_C(0) /* ::OBJECT_CLASS */)))))((!(sc.equal_q(INT64_C(0) /* ::OBJECT_CLASS */)))) : decltype(((!(sc.equal_q(INT64_C(0) /* ::OBJECT_CLASS */)))))(_l); })) {
      (sc_name = sc.name());
      if (({ auto _l = (sc_name); (_l) ? decltype(((!(SKIP_CONSTANTS.include_q(sc_name)))))((!(SKIP_CONSTANTS.include_q(sc_name)))) : decltype(((!(SKIP_CONSTANTS.include_q(sc_name)))))(_l); })) {
      (sc_methods = collect_class_user_methods(sc));
      { auto _coll = sc_methods; for (auto& _ : *_coll.data) {
      if (m.body()) {
        result->merge(collect_ivars(m.body()));
      };
    } };
    };
      (sc = (true ? (sc.superclass()) : (RUBY_NIL)));
    }
    return result;
  }

  RubyArray<RubyString> ivar_type_annotation(auto iv_sym) {
    std::decay_t<decltype(iv_cctx->ivars()[iv_sym])> ivt{};
    std::decay_t<decltype(iv_cctx->typed_ivars()[iv_sym])> ct{};
    RubyNil crystal_cls;
    (ivt = iv_cctx->ivars()[iv_sym]);
    if (ivt.f64_q()) {
      return ({ auto _e0 = RubyString("Float64", 7); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("0.0_f64", 7); _a; });
    }
    if (ivt.i64_q()) {
      return ({ auto _e0 = RubyString("Int64", 5); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("0_i64", 5); _a; });
    }
    if ((ivt == INT64_C(0) /* ::ARRAY_F64 */)) {
      return ({ auto _e0 = RubyString("Array(Float64)", 14); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("Array(Float64).new", 18); _a; });
    }
    if ((ivt == INT64_C(0) /* ::ARRAY_I64 */)) {
      return ({ auto _e0 = RubyString("Array(Int64)", 12); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("Array(Int64).new", 16); _a; });
    }
    (ct = iv_cctx->typed_ivars()[iv_sym]);
    if (!(ct)) {
      return ({ auto _e0 = RubyString("RubyObject", 10); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("RUBY_NIL", 8); _a; });
    }
    auto _masgn4 = ct;
    auto kind = _masgn4[INT64_C(0)];
    auto cls = _masgn4[INT64_C(1)];
    (crystal_cls = ({ auto _l = (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */[cls]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(cls)))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(cls)))); }));
    if (({ auto _l = ((kind == ruby_sym("class_or_nil"))); (_l) ? decltype(((cls == iv_cctx->name())))((cls == iv_cctx->name())) : decltype(((cls == iv_cctx->name())))(_l); })) {
      return ({ auto _e0 = (ruby_to_s(crystal_cls) + RubyString(" | RubyNil", 10)); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("RUBY_NIL", 8); _a; });
    }
    auto rb_default = ({ RubyHash<RubySymbol, RubyString> _h; _h.store(ruby_sym("Array"), RubyString("RubyArray.new", 13)); _h.store(ruby_sym("Hash"), RubyString("RubyHash.new", 12)); _h.store(ruby_sym("String"), RubyString("RubyString.new", 14)); _h; })[cls];
    if (rb_default) {
      return ({ auto _e0 = crystal_cls; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = rb_default; _a; });
    } else {
      return ({ auto _e0 = (ruby_to_s(crystal_cls) + RubyString(" | RubyNil", 10)); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("RUBY_NIL", 8); _a; });
    }
  }

  RubyNil emit_default_stringifiers(auto name, auto user_methods) {
    emit_indent();
    (user_methods.key_q(ruby_sym("to_s")) ? (RUBY_NIL) : (line((RubyString("def to_s : String; \"#<", 22) + ruby_to_s(name) + RubyString(">\"; end", 7)))));
    emit_indent();
    if (user_methods.key_q(ruby_sym("inspect"))) {
      return RubyNil(RUBY_NIL);
    } else {
      return line((RubyString("def inspect : String; \"#<", 25) + ruby_to_s(name) + RubyString(">\"; end", 7)));
    }
  }

  gc_ref<Ruby_Set> collect_eigen_method_names(auto mod) {
    std::decay_t<decltype(mod.eigenclass())> eigenclass{};
    ({ auto _l = ((eigenclass = mod.eigenclass())); (_l) ? decltype((return gc_new<Ruby_Set>()))(_l) : (return gc_new<Ruby_Set>()); });
    return ({ auto _l = (eigenclass.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).select().keys().to_set();
  }

  RubyObject* emit_instance_methods(auto class_name, auto user_methods, auto eigen_names) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_instance_methods\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_alias_forwarding_methods(auto mod, auto user_methods) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_alias_forwarding_methods\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_instance_method_overloads(auto class_name, auto mname, auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_instance_method_overloads\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_class_methods(auto class_name, auto mod, auto eigen_names) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_class_methods\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_eigenclass_accessors(auto mod, auto eigenclass) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_eigenclass_accessors\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_class_method_overloads(auto class_name, auto mname, auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_class_method_overloads\n"); std::abort();
    return nullptr;
  }

  RubyObject* build_method_index(auto scope) {
    std::fprintf(stderr, "frozone: called TI-gap stub build_method_index\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_method_index_table() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_method_index_table\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_respond_to(auto klass) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_respond_to\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_user_method_stubs() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_user_method_stubs\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_user_top_level_methods(auto scope) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_user_top_level_methods\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_top_level_method_overloads(auto name, auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_top_level_method_overloads\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_specialized_top_level_overload(auto name, auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_specialized_top_level_overload\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_typed_top_level_overload(auto name, auto method, auto inferred) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_typed_top_level_overload\n"); std::abort();
    return nullptr;
  }

  RubyNil compute_generic_top_level_params(auto name, auto inferred, auto has_complex_params, auto all_native, auto some_raw) {
    if (has_complex_params) {
      return inferred.map();
    } else {
      if (iv_gctx->typed_params()[name]) {
        return RubyNil(RUBY_NIL);
      } else {
        if (({ auto _l = (all_native); (_l) ? decltype((some_raw))(_l) : (some_raw); })) {
          return RubyNil(RUBY_NIL);
        } else {
          return inferred.map();
        }
      }
    }
  }

  RubyObject* emit_top_level_method_object_copies(auto user_methods_on_object) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_top_level_method_object_copies\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_vm_method(auto name, auto method, auto param_types, auto class_method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_vm_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* collect_param_set(auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub collect_param_set\n"); std::abort();
    return nullptr;
  }

  bool generic_with_specialized_q(auto name, auto class_method) {
    return ({ auto _l = (({ auto _l = (class_method); (_l) ? decltype((iv_cctx->eigen_methods().any_q()))(iv_cctx->eigen_methods().any_q()) : decltype((iv_cctx->eigen_methods().any_q()))(_l); })); (_l) ? decltype((({ auto _l = (iv_gctx->inferred_params()[name]); (_l) ? decltype((iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l) : (iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]); }).any_q()))(({ auto _l = (iv_gctx->inferred_params()[name]); (_l) ? decltype((iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l) : (iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]); }).any_q()) : decltype((({ auto _l = (iv_gctx->inferred_params()[name]); (_l) ? decltype((iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l) : (iv_gctx->class_params()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]); }).any_q()))(_l); });
  }

  RubyHash<RubySymbol, int64_t> setup_method_context(auto name, auto method, auto param_types, auto class_method, auto param_set, auto mkey) {
    gc_local<RubyObject> no_opts = nullptr;
    iv_mctx = gc_new<Ruby_MethodContext>();
    iv_mctx->set_param_set(param_set);
    (no_opts = ({ auto _l = (generic_with_specialized_q(name, class_method)); (_l) ? decltype((ruby_nil_q(param_types)))(ruby_nil_q(param_types)) : decltype((ruby_nil_q(param_types)))(_l); }));
    iv_mctx->set_suppress_typed_call_args(no_opts);
    iv_mctx->set_typed_locals((({ auto _l = ((!(no_opts))); (_l) ? decltype((opt_q(ruby_sym("unbox_locals"))))(opt_q(ruby_sym("unbox_locals"))) : decltype((opt_q(ruby_sym("unbox_locals"))))(_l); }) ? (reject_params(iv_gctx->locals()[mkey], param_set)) : (RubyHash<RubySymbol, int64_t>{})));
    iv_mctx->set_typed_array_locals((opt_q(ruby_sym("native_arrays")) ? (reject_params(iv_gctx->arrays()[mkey], param_set)) : (RubyHash<RubySymbol, int64_t>{})));
    iv_mctx->set_class_locals((opt_q(ruby_sym("devirtualize")) ? (reject_params(iv_gctx->class_locals()[mkey], param_set)) : (RubyHash<RubySymbol, int64_t>{})));
    iv_mctx->set_local_array_elems((opt_q(ruby_sym("native_arrays")) ? (reject_params(iv_gctx->local_array_elems()[mkey], param_set)) : (RubyHash<RubySymbol, int64_t>{})));
    iv_mctx->set_block_params(reject_params(iv_gctx->block_params()[mkey], param_set));
    iv_mctx->set_local_types(reject_params(iv_gctx->local_types()[mkey], param_set));
    iv_mctx->set_method_body(method.body());
    iv_mctx->set_block_param_name(method.block_param());
    return iv_mctx->set_native_array_locals(RubyHash<RubySymbol, int64_t>{});
  }

  RubyHash<RubySymbol, int64_t> reject_params(auto hash, auto param_set, bool keep_params = false) {
    if (!(hash)) {
      return RubyHash<RubySymbol, int64_t>{};
    }
    if (keep_params) {
      return hash;
    } else {
      return hash.reject();
    }
  }

  RubyNil register_native_array_locals(auto method, auto param_types, auto param_set) {
    if (opt_q(ruby_sym("native_arrays"))) {
      { auto _coll = detect_nested_array_locals(method.body(), param_set); for (auto& lname : *_coll.data) {
      iv_mctx->native_array_locals()[lname] = Type.array();
    } };
    }
    if (param_types) {
      register_typed_param_locals(method, param_types);
    }
    if (opt_q(ruby_sym("native_arrays"))) {
      register_ti_nested_arrays(param_set);
    }
    if (({ auto _l = (opt_q(ruby_sym("native_arrays"))); (_l) ? decltype((iv_mctx->local_array_elems().any_q()))(iv_mctx->local_array_elems().any_q()) : decltype((iv_mctx->local_array_elems().any_q()))(_l); })) {
      return register_aliased_native_arrays(method);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* register_typed_param_locals(auto method, auto param_types) {
    std::fprintf(stderr, "frozone: called TI-gap stub register_typed_param_locals\n"); std::abort();
    return nullptr;
  }

  RubyObject* register_ti_nested_arrays(auto param_set) {
    std::fprintf(stderr, "frozone: called TI-gap stub register_ti_nested_arrays\n"); std::abort();
    return nullptr;
  }

  RubyObject* register_aliased_native_arrays(auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub register_aliased_native_arrays\n"); std::abort();
    return nullptr;
  }

  RubyObject* infer_method_local_types(auto name, auto method, auto param_types, auto param_set, auto class_method) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_method_local_types\n"); std::abort();
    return nullptr;
  }

  RubyArray<RubyNil> compute_return_kind(auto name, auto param_types, auto class_method) {
    std::decay_t<decltype(STRING_RETURN_METHODS.include_q(name))> string_return{};
    gc_local<RubyObject> has_specialized = nullptr;
    RubyNil raw_return;
    (string_return = STRING_RETURN_METHODS.include_q(name));
    auto bool_return = ({ auto _l = (({ auto _e0 = ruby_sym("=="); auto _a = RubyArray<decltype(_e0)>(7); _a[0] = _e0; _a[1] = ruby_sym("!="); _a[2] = ruby_sym("<"); _a[3] = ruby_sym("<="); _a[4] = ruby_sym(">"); _a[5] = ruby_sym(">="); _a[6] = ruby_sym("equal?"); _a; }).include_q(name)); (_l) ? decltype(((!(class_method))))((!(class_method))) : decltype(((!(class_method))))(_l); });
    (has_specialized = generic_with_specialized_q(name, class_method));
    auto has_any_raw_param = param_types.any_q();
    (raw_return = ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (has_any_raw_param); (_l) ? decltype(((!(has_specialized))))((!(has_specialized))) : decltype(((!(has_specialized))))(_l); })); (_l) ? decltype((opt_q(ruby_sym("raw_returns"))))(opt_q(ruby_sym("raw_returns"))) : decltype((opt_q(ruby_sym("raw_returns"))))(_l); })); (_l) ? decltype(((!(iv_gctx->typed_params()[name]))))((!(iv_gctx->typed_params()[name]))) : decltype(((!(iv_gctx->typed_params()[name]))))(_l); })); (_l) ? decltype((({ auto _l = (iv_gctx->typed_method_returns()[name]); (_l) ? decltype((({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })))(_l) : (({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })); })))(({ auto _l = (iv_gctx->typed_method_returns()[name]); (_l) ? decltype((({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })))(_l) : (({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })); })) : decltype((({ auto _l = (iv_gctx->typed_method_returns()[name]); (_l) ? decltype((({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })))(_l) : (({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]) : decltype((iv_gctx->instance_method_raw_returns()[({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = name; _a; })]))(_l); })); })))(_l); }));
    auto int32_return = ({ auto _l = ((name == ruby_sym("<=>"))); (_l) ? decltype(((!(class_method))))((!(class_method))) : decltype(((!(class_method))))(_l); });
    return ({ auto _e0 = string_return; auto _a = RubyArray<decltype(_e0)>(4); _a[0] = _e0; _a[1] = bool_return; _a[2] = raw_return; _a[3] = int32_return; _a; });
  }

  RubyObject* emit_method_signature(auto name, auto method, auto param_types, auto class_method, auto return_kind) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_method_signature\n"); std::abort();
    return nullptr;
  }

  bool emit_method_body(auto method, auto name, auto return_kind) {
    gc_local<Ruby_Set> param_names = nullptr;
    std::decay_t<decltype(raw_lines(method.body()))> lines{};
    iv__declared_locals = gc_new<Ruby_Set>();
    (param_names = gc_new<Ruby_Set>((({ auto _l = (method.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }) + ({ auto _l = (method.optional_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map())));
    param_names->merge(({ auto _l = (method.required_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    param_names->merge(({ auto _l = (method.optional_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map());
    if (method.rest_param()) {
      (param_names << method.rest_param());
    }
    if (method.kw_rest_param()) {
      (param_names << method.kw_rest_param());
    }
    auto pre_decl = ({ auto _l = (method.locals()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).reject();
    (pre_decl.empty_q() ? (RUBY_NIL) : (indented([&]() { return { auto _coll = pre_decl; for (auto& l : *_coll.data) {
      (iv__declared_locals << crystal_local(l));
      emit_indent();
      line((ruby_to_s(crystal_local(l)) + RubyString(" = RUBY_NIL", 11)));
    } }; })))
    auto _masgn5 = return_kind;
    auto string_return = _masgn5[INT64_C(0)];
    auto bool_return = _masgn5[INT64_C(1)];
    auto raw_return = _masgn5[INT64_C(2)];
    auto int32_return = _masgn5[INT64_C(3)];
    if (int32_return) {
      return iv_mctx->set_int32_return(true); indented([&]() { return write(RubyString("((begin", 7)); emit_newline(); indented([&]() { return emit(method.body()); }); emit_newline(); emit_indent(); write(RubyString("end) || RUBY_NIL).to_i64.to_i32", 31)); }); iv_mctx->set_int32_return(false);
    } else {
      if (bool_return) {
        return iv_mctx->set_bool_return(true); indented([&]() { return write(RubyString("((begin", 7)); emit_newline(); indented([&]() { return emit(method.body()); }); emit_newline(); emit_indent(); write(RubyString("end) || RUBY_NIL).truthy?", 25)); }); iv_mctx->set_bool_return(false);
      } else {
        if (string_return) {
          return indented([&]() { return write(RubyString("(begin", 6)); emit_newline(); indented([&]() { return emit(method.body()); }); emit_newline(); emit_indent(); write(RubyString("end).to_s", 9)); });
        } else {
          if (raw_return) {
            return indented([&]() { return (lines = raw_lines(method.body())); lines.each_with_index(); });
          } else {
            return iv_mctx->set_emit_crystal_tuple(iv_cc->masgn_return_methods().include_q(name)); indented([&]() { return emit(method.body()); }); iv_mctx->set_emit_crystal_tuple(false);
          }
        }
      }
    }
  }

  RubyObject* emit_global_initializers(auto globals) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_global_initializers\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_user_constants(auto scope) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_user_constants\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> vm_value_to_crystal(auto value, int64_t const_name = RUBY_NIL) {
    std::decay_t<decltype(iv_literal_strings->operator[](value.raw()))> idx{};
    RubyString narrow;
    RubyNil suffix;
    RubyString sentinel;
    std::decay_t<decltype(value.class_object())> klass{};
    std::decay_t<decltype(klass.name())> class_name{};
    std::decay_t<decltype(klass.methods_table().fetch(ruby_sym("initialize"), RUBY_NIL))> init{};
    if ((value == INT64_C(0) /* ::IntegerObject */)) {
      return coerce_to_ref<RubyObject>((RubyString("RubyInteger.new(", 16) + ruby_to_s(value.raw()) + RubyString("_i64)", 5)));
    } else if ((value == INT64_C(0) /* ::FloatObject */)) {
      return coerce_to_ref<RubyObject>((RubyString("RubyFloat.new(", 14) + ruby_to_s(float_bits_expr(value.raw())) + RubyString(")", 1)));
    } else if ((value == INT64_C(0) /* ::StringObject */)) {
      if ((idx = iv_literal_strings->operator[](value.raw()))) {
        return coerce_to_ref<RubyObject>((RubyString("Ruby_Str_", 9) + ruby_to_s(idx)));
      } else {
        return coerce_to_ref<RubyObject>((RubyString("RubyString.new(", 15) + ruby_to_s(value.raw().inspect()) + RubyString(")", 1)));
      }
    } else if ((value == INT64_C(0) /* ::NilObject */)) {
      return coerce_to_ref<RubyObject>(RubyString("RUBY_NIL", 8));
    } else if ((value == INT64_C(0) /* ::TrueObject */)) {
      return coerce_to_ref<RubyObject>(RubyString("RUBY_TRUE", 9));
    } else if ((value == INT64_C(0) /* ::FalseObject */)) {
      return coerce_to_ref<RubyObject>(RubyString("RUBY_FALSE", 10));
    } else if ((value == INT64_C(0) /* ::SymbolObject */)) {
      return coerce_to_ref<RubyObject>((RubyString("RubySymbol.from(", 16) + ruby_to_s(ruby_to_s(value.raw()).inspect()) + RubyString(")", 1)));
    } else if ((value == INT64_C(0) /* ::ArrayObject */)) {
      return coerce_to_ref<RubyObject>(if (({ auto _l = (const_name); (_l) ? decltype(((iv_gctx->const_raw_types()[const_name] == INT64_C(0) /* ::ARRAY_I64 */)))((iv_gctx->const_raw_types()[const_name] == INT64_C(0) /* ::ARRAY_I64 */)) : decltype(((iv_gctx->const_raw_types()[const_name] == INT64_C(0) /* ::ARRAY_I64 */)))(_l); })) {
        auto min = value.raw().map().min();
        auto max = value.raw().map().max();
        auto elem_ty = Type.i64_bounded(min, max);
        (narrow = ({ auto _l = (elem_ty.narrowest_int_type()); (_l) ? decltype((RubyString("Int64", 5)))(_l) : (RubyString("Int64", 5)); }));
        (suffix = CRYSTAL_INT_SUFFIX[narrow]);
        auto elems = value.raw().map().join(RubyString(", ", 2));
        return (RubyString("[", 1) + ruby_to_s(elems) + RubyString("] of ", 5) + ruby_to_s(narrow));
      }; if (({ auto _l = ((value.raw().len() > INT64_C(256))); (_l) ? decltype((value.raw().all_q()))(value.raw().all_q()) : decltype((value.raw().all_q()))(_l); })) {
        auto bytes = value.raw().map().join(RubyString(", ", 2));
        return (RubyString("RubyArray.new(Bytes[", 20) + ruby_to_s(bytes) + RubyString("].to_a.map { |b| RubyInteger.new(b.to_i64).as(RubyObject) })", 60));
      }; if (({ auto _l = ((value.raw().len() > INT64_C(256))); (_l) ? decltype((value.raw().all_q()))(value.raw().all_q()) : decltype((value.raw().all_q()))(_l); })) {
        (sentinel = RubyString("Int64::MIN", 10));
        (elems = value.raw().map().join(RubyString(", ", 2)));
        return (RubyString("RubyArray.new([", 15) + ruby_to_s(elems) + RubyString("].map { |v| v == ", 17) + ruby_to_s(sentinel) + RubyString(" ? RUBY_NIL : RubyInteger.new(v).as(RubyObject) })", 50));
      }; if ((value.raw().len() > INT64_C(100000))) {
        return gc_ref<RubyObject>(nullptr);
      }; (elems = value.raw().map()); if (elems.any_q()) {
        return gc_ref<RubyObject>(nullptr);
      }; (RubyString("RubyArray.new([", 15) + ruby_to_s(elems.join(RubyString(", ", 2))) + RubyString("] of RubyObject)", 16)));
    } else if ((value == INT64_C(0) /* ::HashObject */)) {
      return coerce_to_ref<RubyObject>(auto pairs = value.raw().map(); if (({ auto _l = (pairs.any_q()); (_l) ? decltype(((pairs.len() > INT64_C(500))))(_l) : ((pairs.len() > INT64_C(500))); })) {
        return gc_ref<RubyObject>(nullptr);
      }; if (pairs.empty_q()) {
        RubyString("RubyHash.new", 12);
      } else {
        auto sets = pairs.map().join(RubyString("; ", 2));
        (RubyString("RubyHash.new.tap { |h| ", 23) + ruby_to_s(sets) + RubyString(" }", 2));
      });
    } else if ((value == INT64_C(0) /* ::ObjectObject */)) {
      return coerce_to_ref<RubyObject>((klass = value.class_object()); if (!(true)) {
        return gc_ref<RubyObject>(nullptr);
      }; (class_name = klass.name()); if (!(({ auto _l = (class_name); (_l) ? decltype(((!(SKIP_CONSTANTS.include_q(class_name)))))((!(SKIP_CONSTANTS.include_q(class_name)))) : decltype(((!(SKIP_CONSTANTS.include_q(class_name)))))(_l); }))) {
        return gc_ref<RubyObject>(nullptr);
      }; (init = klass.methods_table().fetch(ruby_sym("initialize"), RUBY_NIL)); if (!(true)) {
        return gc_ref<RubyObject>(nullptr);
      }; (({ auto _l = (init.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q() ? ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(class_name)) + RubyString(".new", 4))) : (RUBY_NIL)));
    } else {
      return gc_ref<RubyObject>(nullptr);
    }
  }

  RubyObject* param_name_q(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub param_name_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* complex_native_type_q(auto t) {
    std::fprintf(stderr, "frozone: called TI-gap stub complex_native_type_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* returns_array_literal_q(auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub returns_array_literal_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* run_type_inference(auto execute_block, auto top_level_scope) {
    std::fprintf(stderr, "frozone: called TI-gap stub run_type_inference\n"); std::abort();
    return nullptr;
  }

  bool raw_passable_arg_q(auto node) {
    if (!(node_raw_type(node))) {
      return false;
    }
    if ((node == INT64_C(0) /* ::LocalVariableRead */)) {
      return true;
    } else if ((node == INT64_C(0) /* ::IntegerLiteral */) || (node == INT64_C(0) /* ::FloatLiteral */)) {
      return true;
    } else if ((node == INT64_C(0) /* ::ConstantRead */)) {
      return iv_gctx->const_raw_types().key_q(node.name());
    } else if ((node == INT64_C(0) /* ::MethodCall */)) {
      return ({ auto _l = (({ auto _l = (ARITH_OPS_UNBOX.include_q(node.name())); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); })); (_l) ? decltype((node_raw_type(node.receiver_node())))(node_raw_type(node.receiver_node())) : decltype((node_raw_type(node.receiver_node())))(_l); });
    } else {
      return false;
    }
  }

  gc_ref<Ruby_Set> collect_masgn_return_methods(auto body, auto scope) {
    gc_local<Ruby_Set> result = nullptr;
    (result = gc_new<Ruby_Set>());
    int64_t collect_masgn_rhs = /* UNSUPPORTED: Lambda */;
    collect_masgn_rhs(body);
    ({ auto _l = (scope.methods_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).each_value();
    return result;
  }

  RubyObject* last_body_expression(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub last_body_expression\n"); std::abort();
    return nullptr;
  }

  bool crystal_bool_emittable_q(auto node) {
    if (!(opt_q(ruby_sym("condition_simplify")))) {
      return false;
    }
    if ((node == INT64_C(0) /* ::And */)) {
      return ({ auto _l = (crystal_bool_emittable_q(node.left_node())); (_l) ? decltype((crystal_bool_emittable_q(node.right_node())))(crystal_bool_emittable_q(node.right_node())) : decltype((crystal_bool_emittable_q(node.right_node())))(_l); });
    } else if ((node == INT64_C(0) /* ::Or */)) {
      return ({ auto _l = (crystal_bool_emittable_q(node.left_node())); (_l) ? decltype((crystal_bool_emittable_q(node.right_node())))(crystal_bool_emittable_q(node.right_node())) : decltype((crystal_bool_emittable_q(node.right_node())))(_l); });
    } else if ((node == INT64_C(0) /* ::MethodCall */)) {
      if (comparison_op_call_q(node)) {
        return ({ auto _l = (node_raw_type(node.receiver_node())); (_l) ? decltype((node_raw_type(node.arg_nodes()[INT64_C(0)])))(node_raw_type(node.arg_nodes()[INT64_C(0)])) : decltype((node_raw_type(node.arg_nodes()[INT64_C(0)])))(_l); });
      } else {
        return false;
      }
    } else if ((node == INT64_C(0) /* ::TrueLiteral */) || (node == INT64_C(0) /* ::FalseLiteral */)) {
      return true;
    } else {
      return false;
    }
  }

  gc_ref<RubyObject> cr_crystal_bool(auto node) {
    RubyNil rt;
    RubyNil at;
    int64_t ty = 0;
    RubySymbol recv_str;
    if ((node == INT64_C(0) /* ::And */)) {
      return coerce_to_ref<RubyObject>((RubyString("(", 1) + ruby_to_s(cr_crystal_bool(node.left_node())) + RubyString(" && ", 4) + ruby_to_s(cr_crystal_bool(node.right_node())) + RubyString(")", 1)));
    } else if ((node == INT64_C(0) /* ::Or */)) {
      return coerce_to_ref<RubyObject>((RubyString("(", 1) + ruby_to_s(cr_crystal_bool(node.left_node())) + RubyString(" || ", 4) + ruby_to_s(cr_crystal_bool(node.right_node())) + RubyString(")", 1)));
    } else if ((node == INT64_C(0) /* ::MethodCall */)) {
      return coerce_to_ref<RubyObject>((rt = node_raw_type(node.receiver_node())); (at = node_raw_type(node.arg_nodes()[INT64_C(0)])); (ty = (({ auto _l = (rt.f64_q()); (_l) ? decltype((at.f64_q()))(_l) : (at.f64_q()); }) ? (INT64_C(0) /* ::F64 */) : (INT64_C(0) /* ::I64 */))); (recv_str = raw_as(node.receiver_node(), ty)); if (recv_contains_assignment_q(node.receiver_node())) {
        (recv_str = (RubyString("(", 1) + ruby_to_s(recv_str) + RubyString(")", 1)));
      }; (RubyString("(", 1) + ruby_to_s(recv_str) + RubyString(" ", 1) + ruby_to_s(node.name()) + RubyString(" ", 1) + ruby_to_s(raw_as(node.arg_nodes()[INT64_C(0)], ty)) + RubyString(")", 1)));
    } else if ((node == INT64_C(0) /* ::TrueLiteral */)) {
      return coerce_to_ref<RubyObject>(RubyString("true", 4));
    } else if ((node == INT64_C(0) /* ::FalseLiteral */)) {
      return coerce_to_ref<RubyObject>(RubyString("false", 5));
    }
    return RUBY_NIL;
  }

  RubyObject* cr_and(auto node, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_and\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_or(auto node, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_or\n"); std::abort();
    return nullptr;
  }

  RubyString cr_super(auto node) {
    RubyNil cls;
    std::decay_t<decltype(cls.prepend_super_targets())> targets{};
    std::decay_t<decltype(targets[iv_mctx->current_method_obj().object_id()])> renamed{};
    std::decay_t<decltype(node.arg_nodes())> args{};
    std::decay_t<decltype(iv_mctx->current_method_obj())> method{};
    RubyArray<int64_t> param_names;
    if (({ auto _l = (iv_mctx->current_method_obj()); (_l) ? decltype((iv_cctx->name()))(iv_cctx->name()) : decltype((iv_cctx->name()))(_l); })) {
      (cls = lookup_vm_class(iv_cctx->name()));
      (targets = cls.prepend_super_targets());
      if (targets) {
      (renamed = targets[iv_mctx->current_method_obj().object_id()]);
      if (renamed) {
      (args = node.arg_nodes());
      if (({ auto _l = (({ auto _l = (node.forwarding()); (_l) ? decltype((ruby_nil_q(args)))(_l) : (ruby_nil_q(args)); })); (_l) ? decltype((args.empty_q()))(_l) : (args.empty_q()); })) {
      (method = iv_mctx->current_method_obj());
      (param_names = ({ auto _l = (method.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).map());
      return (param_names.empty_q() ? (ruby_to_s(crystal_method_name(renamed))) : ((ruby_to_s(crystal_method_name(renamed)) + RubyString("(", 1) + ruby_to_s(param_names.join(RubyString(", ", 2))) + RubyString(")", 1))));
    } else {
      return (ruby_to_s(crystal_method_name(renamed)) + RubyString("(", 1) + ruby_to_s(args.map().join(RubyString(", ", 2))) + RubyString(")", 1));
    };
    };
    };
    }
    (args = node.arg_nodes());
    if (({ auto _l = (({ auto _l = (node.forwarding()); (_l) ? decltype((ruby_nil_q(args)))(_l) : (ruby_nil_q(args)); })); (_l) ? decltype((args.empty_q()))(_l) : (args.empty_q()); })) {
      return RubyString("super", 5);
    }
    return (RubyString("super(", 6) + ruby_to_s(args.map().join(RubyString(", ", 2))) + RubyString(")", 1));
  }

  RubyString cr_param_list(auto node, int64_t param_types = RUBY_NIL) {
    RubyArray<RubyNil> mkey;
    RubyHash<RubySymbol, int64_t> kw_types;
    RubyArray<int64_t> parts;
    RubyArray<int64_t> req;
    std::decay_t<decltype(node.rest_param())> rp{};
    RubyArray<int64_t> req_kw;
    RubyArray<int64_t> opt_kw;
    std::decay_t<decltype(node.kw_rest_param())> kr{};
    RubyString raw_default;
    std::decay_t<decltype(node.block_param())> bp{};
    if (!(param_types)) {
      return /* UNSUPPORTED: Super */;
    }
    (mkey = (iv_cctx->name() ? (({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; })) : (node.name())));
    (kw_types = ({ auto _l = (iv_gctx->inferred_kw_params()[mkey]); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }));
    (parts = RubyArray_I64(0));
    (req = ({ auto _l = (node.required_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    auto types = (param_types + (({ auto _e0 = INT64_C(0) /* ::BOTTOM */; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }) * ((((req.len() - param_types.len())) > (INT64_C(0))) ? ((req.len() - param_types.len())) : (INT64_C(0)))));
    req.each_with_index();
    { auto _coll = node.optional_params(); for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject = ", 16) + ruby_to_s((rb_default ? ((RubyString("(", 1) + ruby_to_s(codegen_inline(rb_default)) + RubyString(")", 1))) : (RubyString("RUBY_NIL", 8))))));
    } }
    (rp = node.rest_param());
    if (rp) {
      (parts << (RubyString("*", 1) + ruby_to_s(crystal_local(rp)) + RubyString(" : RubyObject", 13)));
    }
    { auto _coll = node.post_params(); for (auto& p : *_coll.data) {
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject", 13)));
    } }
    (req_kw = ({ auto _l = (node.required_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    (opt_kw = ({ auto _l = (node.optional_kw_params()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    (kr = node.kw_rest_param());
    if (({ auto _l = (({ auto _l = ((!(req_kw.empty_q()))); (_l) ? decltype(((!(opt_kw.empty_q()))))(_l) : ((!(opt_kw.empty_q()))); })); (_l) ? decltype(((!(rp))))((!(rp))) : decltype(((!(rp))))(_l); })) {
      (parts << RubyString("*", 1));
    }
    { auto _coll = req_kw; for (auto& p : *_coll.data) {
      auto ct = kw_types[p];
      (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : ", 3) + ruby_to_s((ct ? (ct.to_crystal()) : (RubyString("RubyObject", 10))))));
    } }
    { auto _coll = opt_kw; for (auto& p : *_coll.data) {
      (ct = kw_types[p]);
      if (({ auto _l = (ct.raw_q()); (_l) ? decltype((rb_default))(rb_default) : decltype((rb_default))(_l); })) {
        (raw_default = (ct.i64_q() ? ((ruby_to_s(rb_default.value().raw()) + RubyString("_i64", 4))) : ((ruby_to_s(rb_default.value().raw()) + RubyString("_f64", 4)))));
        (parts << (ruby_to_s(crystal_local(p)) + RubyString(" : ", 3) + ruby_to_s(ct.to_crystal()) + RubyString(" = ", 3) + ruby_to_s(raw_default)));
      } else {
        (ct ? ((parts << (ruby_to_s(crystal_local(p)) + RubyString(" : ", 3) + ruby_to_s(ct.to_crystal()) + RubyString(" = ", 3) + ruby_to_s((rb_default ? ((RubyString("(", 1) + ruby_to_s(codegen_inline(rb_default)) + RubyString(")", 1))) : (RubyString("RUBY_NIL", 8))))))) : ((parts << (ruby_to_s(crystal_local(p)) + RubyString(" : RubyObject = ", 16) + ruby_to_s((rb_default ? ((RubyString("(", 1) + ruby_to_s(codegen_inline(rb_default)) + RubyString(")", 1))) : (RubyString("RUBY_NIL", 8))))))));
      };
    } }
    if (kr) {
      (parts << (RubyString("**", 2) + ruby_to_s(crystal_local(kr))));
    }
    (bp = node.block_param());
    if (bp) {
      (parts << (RubyString("&", 1) + ruby_to_s(crystal_local(bp))));
    }
    if (parts.empty_q()) {
      return RubyString("", 0);
    } else {
      return (RubyString("(", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString(")", 1));
    }
  }

  RubyNil crystal_class_name(auto cls) {
    return ({ auto _l = (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */[cls]); (_l) ? decltype(((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(cls)))))(_l) : ((RubyString("Ruby_", 5) + ruby_to_s(crystal_constant(cls)))); });
  }

  RubyNil crystal_class_fqn(auto cls_sym) {
    RubyNil cls_obj;
    if (INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */.key_q(cls_sym)) {
      return INT64_C(0) /* ::RUBY_TO_CRYSTAL_TYPE */[cls_sym];
    }
    (cls_obj = find_user_class_object(cls_sym));
    if (cls_obj) {
      return crystal_superclass_path(cls_obj);
    } else {
      return crystal_class_name(cls_sym);
    }
  }

  RubyNil find_user_class_object(auto sym, auto scope = RUBY_NIL, auto seen = RUBY_NIL) {
    RubyNil found;
    RubyNil nested;
    ({ auto _l = (iv__user_class_cache); (_l) ? decltype((iv__user_class_cache = RubyHash<RubySymbol, int64_t>{}))(_l) : (iv__user_class_cache = RubyHash<RubySymbol, int64_t>{}); });
    auto top_call = ({ auto _l = (ruby_nil_q(scope)); (_l) ? decltype((ruby_nil_q(seen)))(ruby_nil_q(seen)) : decltype((ruby_nil_q(seen)))(_l); });
    if (({ auto _l = (top_call); (_l) ? decltype((iv__user_class_cache->key_q(sym)))(iv__user_class_cache->key_q(sym)) : decltype((iv__user_class_cache->key_q(sym)))(_l); })) {
      return iv__user_class_cache->operator[](sym);
    }
    ({ auto _l = (scope); (_l) ? decltype(((scope = iv_cc->top_level_scope())))(_l) : ((scope = iv_cc->top_level_scope())); });
    ({ auto _l = (seen); (_l) ? decltype(((seen = RubyHash<RubySymbol, int64_t>{})))(_l) : ((seen = RubyHash<RubySymbol, int64_t>{})); });
    if (!(scope)) {
      return RubyNil(RUBY_NIL);
    }
    (found = RUBY_NIL);
    { auto _coll = ({ auto _l = (scope.constants_table()); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }); for (auto& _n : *_coll.data) {
      if (!(true)) {
        continue;
      };
      if (seen[v]) {
        continue;
      };
      seen[v] = true;
      if (({ auto _l = (true); (_l) ? decltype(((v.name() == sym)))((v.name() == sym)) : decltype(((v.name() == sym)))(_l); })) {
        (found = v);
        break;
      };
      (nested = find_user_class_object(sym, v, seen));
      if (nested) {
        (found = nested);
        break;
      };
    } }
    if (top_call) {
      iv__user_class_cache[sym] = found;
    }
    return found;
  }

  gc_ref<RubyObject> cr_return(auto node) {
    if (!(node.value_node())) {
      return /* UNSUPPORTED: Super */;
    }
    if (iv_mctx->bool_return()) {
      return coerce_to_ref<RubyObject>((RubyString("return ", 7) + ruby_to_s(cr(node.value_node())) + RubyString(".truthy?", 8)));
    } else {
      if (iv_mctx->int32_return()) {
        return coerce_to_ref<RubyObject>((RubyString("return ", 7) + ruby_to_s(cr(node.value_node())) + RubyString(".to_i64.to_i32", 14)));
      } else {
        return coerce_to_ref<RubyObject>(/* UNSUPPORTED: Super */);
      }
    }
  }

  RubyObject* cr_local_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_local_read\n"); std::abort();
    return nullptr;
  }

  RubyNil cr_local_write(auto node) {
    std::decay_t<decltype(node.name())> name{};
    RubyNil result;
    gc_local<RubyObject> old_suppress = nullptr;
    std::decay_t<decltype(crystal_local(name))> cname{};
    std::decay_t<decltype(cr(node.value_node()))> val{};
    (name = node.name());
    (result = ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (cr_try_nested_array_write(node, name)); (_l) ? decltype((cr_try_range_to_a_write(node, name)))(_l) : (cr_try_range_to_a_write(node, name)); })); (_l) ? decltype((cr_try_native_dup_write(node, name)))(_l) : (cr_try_native_dup_write(node, name)); })); (_l) ? decltype((cr_try_typed_array_write(node, name)))(_l) : (cr_try_typed_array_write(node, name)); })); (_l) ? decltype((cr_try_boxed_array_promote(node, name)))(_l) : (cr_try_boxed_array_promote(node, name)); })); (_l) ? decltype((cr_try_scalar_write(node, name)))(_l) : (cr_try_scalar_write(node, name)); })); (_l) ? decltype((cr_try_native_array_alias(node, name)))(_l) : (cr_try_native_array_alias(node, name)); })); (_l) ? decltype((cr_try_boxed_array_write(node, name)))(_l) : (cr_try_boxed_array_write(node, name)); })); (_l) ? decltype((cr_try_class_cast_write(node, name)))(_l) : (cr_try_class_cast_write(node, name)); }));
    if (result) {
      return result;
    }
    iv_mctx->typed_array_locals().rb_delete(name);
    (old_suppress = iv_mctx->suppress_tuple_literals());
    iv_mctx->set_suppress_tuple_literals(true);
    (cname = crystal_local(name));
    (val = cr(node.value_node()));
    iv_mctx->set_suppress_tuple_literals(old_suppress);
    ({ auto _l = (iv__declared_locals); (_l) ? decltype((iv__declared_locals = gc_new<Ruby_Set>()))(_l) : (iv__declared_locals = gc_new<Ruby_Set>()); });
    auto needs_fwd = ({ auto _l = ((!(iv__declared_locals->include_q(cname)))); (_l) ? decltype((val.match_q(/* UNSUPPORTED: InterpolatedRegexpLiteral */)))(val.match_q(/* UNSUPPORTED: InterpolatedRegexpLiteral */)) : decltype((val.match_q(/* UNSUPPORTED: InterpolatedRegexpLiteral */)))(_l); });
    (iv__declared_locals << cname);
    if (needs_fwd) {
      return (ruby_to_s(cname) + RubyString(" = RUBY_NIL; ", 13) + ruby_to_s(cname) + RubyString(" = ", 3) + ruby_to_s(val));
    } else {
      return (ruby_to_s(cname) + RubyString(" = ", 3) + ruby_to_s(val));
    }
  }

  RubyObject* cr_try_range_to_a_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_range_to_a_write\n"); std::abort();
    return nullptr;
  }

  RubyNil cr_try_nested_array_write(auto node, auto name) {
    std::decay_t<decltype(native_array_elem_type(name))> nat_elem{};
    std::decay_t<decltype(node.value_node())> rhs{};
    RubyNil blk;
    std::decay_t<decltype(blk.body())> inner{};
    std::decay_t<decltype(nat_elem.to_crystal())> inner_crystal{};
    RubyArray<int64_t> outer_args;
    RubyArray<int64_t> inner_args;
    RubySymbol fill_str;
    (nat_elem = native_array_elem_type(name));
    if (!(({ auto _l = (true); (_l) ? decltype((nat_elem.array_like_q()))(nat_elem.array_like_q()) : decltype((nat_elem.array_like_q()))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (rhs = node.value_node());
    (blk = (true ? (rhs.block_node()) : (RUBY_NIL)));
    if (!(true)) {
      return RubyNil(RUBY_NIL);
    }
    (inner = blk.body());
    if (({ auto _l = (true); (_l) ? decltype(((inner.nodes().len() == INT64_C(1))))((inner.nodes().len() == INT64_C(1))) : decltype(((inner.nodes().len() == INT64_C(1))))(_l); })) {
      (inner = inner.nodes().first());
    }
    (inner_crystal = nat_elem.to_crystal());
    (outer_args = ({ auto _l = (rhs.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (array_new_call_q(inner)) {
      return (inner_args = ({ auto _l = (inner.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })); (fill_str = raw_as(inner_args[INT64_C(1)], nat_elem.elem())); (ruby_to_s(crystal_local(name)) + RubyString(" = Array(", 9) + ruby_to_s(inner_crystal) + RubyString(").new(", 6) + ruby_to_s(coerce_i64(outer_args[INT64_C(0)])) + RubyString(") { ", 4) + ruby_to_s(inner_crystal) + RubyString(".new(", 5) + ruby_to_s(coerce_i64(inner_args[INT64_C(0)])) + RubyString(", ", 2) + ruby_to_s(fill_str) + RubyString(") }", 3));
    } else {
      if (({ auto _l = (true); (_l) ? decltype((({ auto _l = (inner.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q()))(({ auto _l = (inner.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q()) : decltype((({ auto _l = (inner.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).empty_q()))(_l); })) {
        return (ruby_to_s(crystal_local(name)) + RubyString(" = Array(", 9) + ruby_to_s(inner_crystal) + RubyString(").new(", 6) + ruby_to_s(coerce_i64(outer_args[INT64_C(0)])) + RubyString(") { ", 4) + ruby_to_s(inner_crystal) + RubyString(".new }", 6));
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* cr_try_typed_array_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_typed_array_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_boxed_array_promote(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_boxed_array_promote\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_native_dup_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_native_dup_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_scalar_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_scalar_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_native_array_alias(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_native_array_alias\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_boxed_array_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_boxed_array_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_class_cast_write(auto node, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_class_cast_write\n"); std::abort();
    return nullptr;
  }

  bool safe_for_type_annotation_q(auto val) {
    std::decay_t<decltype(iv_cctx->typed_ivars().dig(val.name()))> ct{};
    if (iv__inside_nested_expr) {
      return false;
    }
    if ((val == INT64_C(0) /* ::MethodCall */)) {
      return ({ auto _l = ((val.name() == ruby_sym("new"))); (_l) ? decltype((true))(true) : decltype((true))(_l); });
    } else if ((val == INT64_C(0) /* ::LocalVariableRead */)) {
      return iv__declared_typed_locals->include_q(val.name());
    } else if ((val == INT64_C(0) /* ::InstanceVariableRead */)) {
      return (ct = iv_cctx->typed_ivars().dig(val.name())); (!(({ auto _l = (({ auto _l = (true); (_l) ? decltype(((ct[INT64_C(0)] == ruby_sym("class_or_nil"))))((ct[INT64_C(0)] == ruby_sym("class_or_nil"))) : decltype(((ct[INT64_C(0)] == ruby_sym("class_or_nil"))))(_l); })); (_l) ? decltype(((ct[INT64_C(1)] != iv_cctx->name())))((ct[INT64_C(1)] != iv_cctx->name())) : decltype(((ct[INT64_C(1)] != iv_cctx->name())))(_l); })));
    } else {
      return false;
    }
  }

  gc_ref<RubyObject> cr_array_literal(auto node) {
    RubyArray<int64_t> elems;
    RubyArray<RubySymbol> parts;
    if (!(({ auto _l = (opt_q(ruby_sym("tuple_literals"))); (_l) ? decltype(((!(iv_mctx->suppress_tuple_literals()))))((!(iv_mctx->suppress_tuple_literals()))) : decltype(((!(iv_mctx->suppress_tuple_literals()))))(_l); }))) {
      return /* UNSUPPORTED: Super */;
    }
    (elems = ({ auto _l = (node.element_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }));
    if (!(({ auto _l = (({ auto _l = ((elems.len() >= INT64_C(1))); (_l) ? decltype(((elems.len() <= MAX_TUPLE_SIZE)))((elems.len() <= MAX_TUPLE_SIZE)) : decltype(((elems.len() <= MAX_TUPLE_SIZE)))(_l); })); (_l) ? decltype((elems.none_q()))(elems.none_q()) : decltype((elems.none_q()))(_l); }))) {
      return /* UNSUPPORTED: Super */;
    }
    if (iv_mctx->emit_crystal_tuple()) {
      return coerce_to_ref<RubyObject>((parts = elems.map()); (RubyString("{", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString("}", 1)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("RubyTuple", 9) + ruby_to_s(elems.len()) + RubyString(".new(", 5) + ruby_to_s(elems.map().join(RubyString(", ", 2))) + RubyString(")", 1)));
    }
  }

  RubyObject* cr_ivar_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_ivar_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_ivar_write(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_ivar_write\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> cr_index_op_write(auto node) {
    std::decay_t<decltype(node.index_arg_nodes().first())> idx{};
    std::decay_t<decltype(node.rb_operator())> op{};
    std::decay_t<decltype(node.receiver_node())> recv_node{};
    std::decay_t<decltype(node.value_node())> val_node{};
    RubyString r;
    RubyString i;
    RubyString recv_str;
    RubyString unbox;
    RubyString box;
    (idx = node.index_arg_nodes().first());
    (op = node.rb_operator());
    (recv_node = node.receiver_node());
    (val_node = node.value_node());
    auto recv_name = ({ auto _l = (true); (_l) ? decltype((recv_node.name()))(recv_node.name()) : decltype((recv_node.name()))(_l); });
    if (({ auto _l = (recv_name); (_l) ? decltype((auto nat_ty = native_array_elem_type(recv_name)))(auto nat_ty = native_array_elem_type(recv_name)) : decltype((auto nat_ty = native_array_elem_type(recv_name)))(_l); })) {
      return (ruby_to_s(crystal_local(recv_name)) + RubyString("[", 1) + ruby_to_s(coerce_i64(idx)) + RubyString("] ", 2) + ruby_to_s(op) + RubyString("= ", 2) + ruby_to_s(raw_as(val_node, nat_ty)));
    }
    if (!(({ auto _l = (idx); (_l) ? decltype((node_raw_type(idx)))(node_raw_type(idx)) : decltype((node_raw_type(idx)))(_l); }))) {
      return /* UNSUPPORTED: Super */;
    }
    (r = (RubyString("_iopw_r", 7) + ruby_to_s(iv_temp_counter)));
    (i = (RubyString("_iopw_i", 7) + ruby_to_s(iv_temp_counter)));
    iv_temp_counter = (iv_temp_counter + INT64_C(1));
    (recv_str = (recv_node ? (cr(recv_node)) : (RubyString("self", 4))));
    auto recv_elem_ty = ({ auto _l = (true); (_l) ? decltype((iv_mctx->local_array_elems()[recv_node.name()]))(iv_mctx->local_array_elems()[recv_node.name()]) : decltype((iv_mctx->local_array_elems()[recv_node.name()]))(_l); });
    if (recv_elem_ty) {
      return coerce_to_ref<RubyObject>((unbox = (recv_elem_ty.f64_q() ? (RubyString(".as(RubyFloat).to_f64", 21)) : (RubyString(".as(RubyInteger).to_i64", 23)))); (box = (recv_elem_ty.f64_q() ? (RubyString("RubyFloat", 9)) : (RubyString("RubyInteger", 11)))); (RubyString("(", 1) + ruby_to_s(r) + RubyString(" = ", 3) + ruby_to_s(recv_str) + RubyString("; ", 2) + ruby_to_s(i) + RubyString(" = ", 3) + ruby_to_s(raw(idx)) + RubyString("; ", 2) + ruby_to_s(r) + RubyString("[", 1) + ruby_to_s(i) + RubyString("] = ", 4) + ruby_to_s(box) + RubyString(".new(", 5) + ruby_to_s(r) + RubyString("[", 1) + ruby_to_s(i) + RubyString("]", 1) + ruby_to_s(unbox) + RubyString(" ", 1) + ruby_to_s(op) + RubyString(" ", 1) + ruby_to_s(raw_as(val_node, recv_elem_ty)) + RubyString("))", 2)));
    } else {
      return coerce_to_ref<RubyObject>((RubyString("(", 1) + ruby_to_s(r) + RubyString(" = ", 3) + ruby_to_s(recv_str) + RubyString("; ", 2) + ruby_to_s(i) + RubyString(" = ", 3) + ruby_to_s(raw(idx)) + RubyString("; ", 2) + ruby_to_s(r) + RubyString("[", 1) + ruby_to_s(i) + RubyString("] = (", 5) + ruby_to_s(r) + RubyString("[", 1) + ruby_to_s(i) + RubyString("] ", 2) + ruby_to_s(op) + RubyString(" ", 1) + ruby_to_s(cr(val_node)) + RubyString("))", 2)));
    }
  }

  RubyObject* cr_typed_call_args(auto args, auto param_types) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_typed_call_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_boxed(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_boxed\n"); std::abort();
    return nullptr;
  }

  RubyString cr_block_if_present(auto node) {
    std::decay_t<decltype(node.block_node())> blk{};
    (blk = node.block_node());
    if (!(({ auto _l = (blk); (_l) ? decltype(((!(true))))((!(true))) : decltype(((!(true))))(_l); }))) {
      return RubyString("", 0);
    }
    return (RubyString(" ", 1) + ruby_to_s(cr_block(blk)));
  }

  RubyString cr_method_call(auto node) {
    return ({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (cr_try_ivar_array_access(node)); (_l) ? decltype((cr_try_constant_fold(node)))(_l) : (cr_try_constant_fold(node)); })); (_l) ? decltype((cr_try_native_array_new(node)))(_l) : (cr_try_native_array_new(node)); })); (_l) ? decltype((cr_try_native_iteration(node)))(_l) : (cr_try_native_iteration(node)); })); (_l) ? decltype((cr_try_typed_instance_call(node)))(_l) : (cr_try_typed_instance_call(node)); })); (_l) ? decltype((cr_try_native_array_method(node)))(_l) : (cr_try_native_array_method(node)); })); (_l) ? decltype((cr_try_array_push(node)))(_l) : (cr_try_array_push(node)); })); (_l) ? decltype((cr_try_native_array_read(node)))(_l) : (cr_try_native_array_read(node)); })); (_l) ? decltype((cr_try_boxed_array_read(node)))(_l) : (cr_try_boxed_array_read(node)); })); (_l) ? decltype((cr_try_raw_index_read(node)))(_l) : (cr_try_raw_index_read(node)); })); (_l) ? decltype((cr_try_specialized_free_call(node)))(_l) : (cr_try_specialized_free_call(node)); })); (_l) ? decltype((cr_try_eigen_dispatch(node)))(_l) : (cr_try_eigen_dispatch(node)); })); (_l) ? decltype((cr_try_typed_free_call(node)))(_l) : (cr_try_typed_free_call(node)); })); (_l) ? decltype((cr_try_devirtualized_call(node)))(_l) : (cr_try_devirtualized_call(node)); })); (_l) ? decltype((cr_try_raw_arithmetic(node)))(_l) : (cr_try_raw_arithmetic(node)); })); (_l) ? decltype((default_method_call(node)))(_l) : (default_method_call(node)); });
  }

  RubyObject* cr_try_ivar_array_access(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_ivar_array_access\n"); std::abort();
    return nullptr;
  }

  RubyString cr_try_constant_fold(auto node) {
    RubyNil recv_class;
    RubyNil klass;
    RubyNil target;
    if (!(({ auto _l = (node.receiver_node()); (_l) ? decltype(((recv_class = receiver_known_class(node.receiver_node()))))((recv_class = receiver_known_class(node.receiver_node()))) : decltype(((recv_class = receiver_known_class(node.receiver_node()))))(_l); }))) {
      return RubyString(RUBY_NIL);
    }
    ({ auto _l = ((klass = lookup_vm_class(recv_class))); (_l) ? decltype((return RubyString(RUBY_NIL)))(_l) : (return RubyString(RUBY_NIL)); });
    if (({ auto _l = (({ auto _l = ((node.name() == ruby_sym("respond_to?"))); (_l) ? decltype((node.arg_nodes().len().between_q(INT64_C(1), INT64_C(2))))(node.arg_nodes().len().between_q(INT64_C(1), INT64_C(2))) : decltype((node.arg_nodes().len().between_q(INT64_C(1), INT64_C(2))))(_l); })); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
      if (klass.lookup_method(node.arg_nodes()[INT64_C(0)].value())) {
        return RubyString("RUBY_TRUE", 9);
      } else {
        return RubyString("RUBY_FALSE", 10);
      }
    } else {
      if (({ auto _l = (({ auto _l = (({ auto _l = ((node.name() == ruby_sym("is_a?"))); (_l) ? decltype(((node.name() == ruby_sym("kind_of?"))))(_l) : ((node.name() == ruby_sym("kind_of?"))); })); (_l) ? decltype(((node.arg_nodes().len() == INT64_C(1))))((node.arg_nodes().len() == INT64_C(1))) : decltype(((node.arg_nodes().len() == INT64_C(1))))(_l); })); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
        return ({ auto _l = ((target = lookup_vm_class(node.arg_nodes()[INT64_C(0)].name()))); (_l) ? decltype((return RubyString(RUBY_NIL)))(_l) : (return RubyString(RUBY_NIL)); }); (klass.ancestors_include_q(target) ? (RubyString("RUBY_TRUE", 9)) : (RubyString("RUBY_FALSE", 10)));
      }
      return RubyString(RUBY_NIL);
    }
  }

  RubyObject* cr_try_native_array_new(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_native_array_new\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> cr_try_native_iteration(auto node) {
    if (!(({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (opt_q(ruby_sym("native_iteration"))); (_l) ? decltype((node.block_node()))(node.block_node()) : decltype((node.block_node()))(_l); })); (_l) ? decltype(((!(true))))((!(true))) : decltype(((!(true))))(_l); })); (_l) ? decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() <= INT64_C(1))))((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() <= INT64_C(1))) : decltype(((({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); }).len() <= INT64_C(1))))(_l); })); (_l) ? decltype((node_raw_type(node.receiver_node()).i64_q()))(node_raw_type(node.receiver_node()).i64_q()) : decltype((node_raw_type(node.receiver_node()).i64_q()))(_l); }))) {
      return gc_ref<RubyObject>(nullptr);
    }
    if ((node.name() == ruby_sym("times"))) {
      return coerce_to_ref<RubyObject>((ruby_to_s(raw(node.receiver_node())) + RubyString(".times ", 7) + ruby_to_s(cr_native_iter_block(node.block_node()))));
    } else if ((node.name() == ruby_sym("upto"))) {
      return coerce_to_ref<RubyObject>(auto limit = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })[INT64_C(0)]; if (!(({ auto _l = (limit); (_l) ? decltype((node_raw_type(limit).i64_q()))(node_raw_type(limit).i64_q()) : decltype((node_raw_type(limit).i64_q()))(_l); }))) {
        return gc_ref<RubyObject>(nullptr);
      }; (RubyString("(", 1) + ruby_to_s(raw(node.receiver_node())) + RubyString("..", 2) + ruby_to_s(raw(limit)) + RubyString(").each ", 7) + ruby_to_s(cr_native_iter_block(node.block_node()))));
    } else if ((node.name() == ruby_sym("downto"))) {
      return coerce_to_ref<RubyObject>((limit = ({ auto _l = (node.arg_nodes()); (_l) ? decltype((RubyArray_I64(0)))(_l) : (RubyArray_I64(0)); })[INT64_C(0)]); if (!(({ auto _l = (limit); (_l) ? decltype((node_raw_type(limit).i64_q()))(node_raw_type(limit).i64_q()) : decltype((node_raw_type(limit).i64_q()))(_l); }))) {
        return gc_ref<RubyObject>(nullptr);
      }; (RubyString("(", 1) + ruby_to_s(raw(limit)) + RubyString("..", 2) + ruby_to_s(raw(node.receiver_node())) + RubyString(").reverse_each ", 15) + ruby_to_s(cr_native_iter_block(node.block_node()))));
    }
    return RUBY_NIL;
  }

  RubyObject* cr_try_typed_instance_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_typed_instance_call\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_native_array_method(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_native_array_method\n"); std::abort();
    return nullptr;
  }

  RubyNil cr_try_array_push(auto node) {
    std::decay_t<decltype(node.receiver_node())> recv{};
    std::decay_t<decltype(native_array_elem_type(recv.name()))> elem{};
    std::decay_t<decltype(native_array_elem_type(recv.receiver_node().name()))> arr_elem{};
    if (!(({ auto _l = (({ auto _l = ((node.name() == ruby_sym("<<"))); (_l) ? decltype((node.receiver_node()))(node.receiver_node()) : decltype((node.receiver_node()))(_l); })); (_l) ? decltype(((node.arg_nodes().len() == INT64_C(1))))((node.arg_nodes().len() == INT64_C(1))) : decltype(((node.arg_nodes().len() == INT64_C(1))))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    (recv = node.receiver_node());
    if (({ auto _l = (true); (_l) ? decltype(((elem = native_array_elem_type(recv.name()))))((elem = native_array_elem_type(recv.name()))) : decltype(((elem = native_array_elem_type(recv.name()))))(_l); })) {
      return (ruby_to_s(cr(recv)) + RubyString(" << ", 4) + ruby_to_s(raw_as(node.arg_nodes()[INT64_C(0)], elem)));
    } else {
      if (({ auto _l = (({ auto _l = (true); (_l) ? decltype(((recv.name() == ruby_sym("[]"))))((recv.name() == ruby_sym("[]"))) : decltype(((recv.name() == ruby_sym("[]"))))(_l); })); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
        return (arr_elem = native_array_elem_type(recv.receiver_node().name())); if (!(({ auto _l = (true); (_l) ? decltype((arr_elem.array_like_q()))(arr_elem.array_like_q()) : decltype((arr_elem.array_like_q()))(_l); }))) {
          return RubyNil(RUBY_NIL);
        }; (ruby_to_s(cr(recv)) + RubyString(" << ", 4) + ruby_to_s(raw_as(node.arg_nodes()[INT64_C(0)], arr_elem.elem())));
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* cr_try_native_array_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_native_array_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_boxed_array_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_boxed_array_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_raw_index_read(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_raw_index_read\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_specialized_free_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_specialized_free_call\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_eigen_dispatch(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_eigen_dispatch\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_typed_free_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_typed_free_call\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_devirtualized_call(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_devirtualized_call\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_try_raw_arithmetic(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_try_raw_arithmetic\n"); std::abort();
    return nullptr;
  }

  RubyString cr_call_args(auto node) {
    std::decay_t<decltype(node.arg_nodes())> args{};
    std::decay_t<decltype(node.kw_arg_nodes())> kw_args{};
    RubyNil callee_inferred;
    RubyString s;
    RubyNil has_typed_overload;
    if (!(opt_q(ruby_sym("unbox_locals")))) {
      return /* UNSUPPORTED: Super */;
    }
    if ((node.name() == ruby_sym("new"))) {
      return /* UNSUPPORTED: Super */;
    }
    (args = node.arg_nodes());
    (kw_args = node.kw_arg_nodes());
    if (({ auto _l = (({ auto _l = (args.empty_q()); (_l) ? decltype((kw_args.empty_q()))(kw_args.empty_q()) : decltype((kw_args.empty_q()))(_l); })); (_l) ? decltype((ruby_nil_q(node.block_node())))(ruby_nil_q(node.block_node())) : decltype((ruby_nil_q(node.block_node())))(_l); })) {
      return RubyString("", 0);
    }
    (callee_inferred = (ruby_nil_q(node.receiver_node()) ? (iv_gctx->inferred_params()[node.name()]) : (RUBY_NIL)));
    if (({ auto _l = (({ auto _l = (callee_inferred); (_l) ? decltype((callee_inferred.any_q()))(callee_inferred.any_q()) : decltype((callee_inferred.any_q()))(_l); })); (_l) ? decltype(((args.len() == callee_inferred.len())))((args.len() == callee_inferred.len())) : decltype(((args.len() == callee_inferred.len())))(_l); })) {
      auto parts = args.each_with_index().map();
      (parts = (parts + kw_args.map()));
      (s = (RubyString("(", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString(")", 1)));
      if (node.block_node()) {
      (s = (s + RubyString(" ", 1)));
      (s = (s + (true ? (cr_block_arg(node.block_node())) : (cr_block(node.block_node())))));
    };
      return s;
    }
    auto all_raw = args.all_q();
    (has_typed_overload = ({ auto _l = (({ auto _l = (iv_gctx->typed_params().key_q(node.name())); (_l) ? decltype((({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))) : decltype((iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(_l); })))(_l) : (({ auto _l = (iv_cctx->name()); (_l) ? decltype((iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))) : decltype((iv_gctx->class_params().key_q(({ auto _e0 = iv_cctx->name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(_l); })); })); (_l) ? decltype((({ auto _l = (true); (_l) ? decltype((iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))) : decltype((iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(_l); })))(_l) : (({ auto _l = (true); (_l) ? decltype((iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))) : decltype((iv_gctx->class_params().key_q(({ auto _e0 = node.receiver_node().name(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = node.name(); _a; }))))(_l); })); }));
    if (!(({ auto _l = (all_raw); (_l) ? decltype((has_typed_overload))(has_typed_overload) : decltype((has_typed_overload))(_l); }))) {
      return /* UNSUPPORTED: Super */;
    }
    (parts = args.map());
    (parts = (parts + kw_args.map()));
    (s = (RubyString("(", 1) + ruby_to_s(parts.join(RubyString(", ", 2))) + RubyString(")", 1)));
    if (node.block_node()) {
      (s = (s + RubyString(" ", 1)));
      (s = (s + (true ? (cr_block_arg(node.block_node())) : (cr_block(node.block_node())))));
    }
    return s;
  }

  RubyObject* cr_attribute_write(auto node, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_attribute_write\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_truthy(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_truthy\n"); std::abort();
    return nullptr;
  }

  RubyObject* comparison_op_call_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub comparison_op_call_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* user_overrides_comparison_q(auto op_name) {
    std::fprintf(stderr, "frozone: called TI-gap stub user_overrides_comparison_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* cr_multiple_assignment(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub cr_multiple_assignment\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> cr_masgn_assign(auto target, auto value_code) {
    std::decay_t<decltype(iv_cctx->ivars()[target[INT64_C(1)]])> ty{};
    std::decay_t<decltype(native_array_elem_type(target[INT64_C(1)].name()))> nat_ty{};
    RubyString coerce;
    if (({ auto _l = ((target[INT64_C(0)] == ruby_sym("ivar"))); (_l) ? decltype(((ty = iv_cctx->ivars()[target[INT64_C(1)]])))((ty = iv_cctx->ivars()[target[INT64_C(1)]])) : decltype(((ty = iv_cctx->ivars()[target[INT64_C(1)]])))(_l); })) {
      return coerce_to_ref<RubyObject>((ruby_to_s(target[INT64_C(1)]) + RubyString(" = ", 3) + ruby_to_s(value_code) + ruby_to_s((ty.f64_q() ? (RubyString(".to_f64", 7)) : (RubyString(".to_i64", 7))))));
    } else {
      if (({ auto _l = (({ auto _l = ((target[INT64_C(0)] == ruby_sym("local"))); (_l) ? decltype(((target[INT64_C(0)] == ruby_sym("local_splat"))))(_l) : ((target[INT64_C(0)] == ruby_sym("local_splat"))); })); (_l) ? decltype(((ty = iv_mctx->typed_locals()[target[INT64_C(1)]])))((ty = iv_mctx->typed_locals()[target[INT64_C(1)]])) : decltype(((ty = iv_mctx->typed_locals()[target[INT64_C(1)]])))(_l); })) {
        return coerce_to_ref<RubyObject>((ruby_to_s(crystal_local(target[INT64_C(1)])) + RubyString(" = ", 3) + ruby_to_s(value_code) + ruby_to_s((ty.f64_q() ? (RubyString(".to_f64", 7)) : (RubyString(".to_i64", 7))))));
      } else {
        if (({ auto _l = (({ auto _l = (({ auto _l = ((target[INT64_C(0)] == ruby_sym("index"))); (_l) ? decltype(((target[INT64_C(0)] == ruby_sym("index_splat"))))(_l) : ((target[INT64_C(0)] == ruby_sym("index_splat"))); })); (_l) ? decltype((true))(true) : decltype((true))(_l); })); (_l) ? decltype(((nat_ty = native_array_elem_type(target[INT64_C(1)].name()))))((nat_ty = native_array_elem_type(target[INT64_C(1)].name()))) : decltype(((nat_ty = native_array_elem_type(target[INT64_C(1)].name()))))(_l); })) {
          return coerce_to_ref<RubyObject>((coerce = (nat_ty.f64_q() ? (RubyString(".to_f64", 7)) : (RubyString(".to_i64", 7)))); auto idxs = target[INT64_C(2)].map().join(RubyString(", ", 2)); (ruby_to_s(crystal_local(target[INT64_C(1)].name())) + RubyString("[", 1) + ruby_to_s(idxs) + RubyString("] = ", 4) + ruby_to_s(value_code) + ruby_to_s(coerce)));
        } else {
          return coerce_to_ref<RubyObject>(default_masgn_assign(target, value_code));
        }
      }
    }
  }

  RubyObject* accessor_method_q(auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub accessor_method_q\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> struct_subclass_q(auto klass) {
    RubyNil c;
    (c = klass);
    while (({ auto _l = (c); (_l) ? decltype((true))(true) : decltype((true))(_l); })) {
      if ((c.name() == ruby_sym("Struct"))) {
      return true;
    };
      (c = c.superclass());
    }
    return coerce_to_ref<RubyObject>(false);
  }

  RubyObject* emit_accessor_method(auto mname, auto method) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_accessor_method\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Codegen>() { return "Codegen"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Codegen> : dustman::FieldList<Ruby_Codegen, &Ruby_Codegen::iv_cc, &Ruby_Codegen::iv_mctx, &Ruby_Codegen::iv_cctx, &Ruby_Codegen::iv_gctx, &Ruby_Codegen::iv__declared_locals> {};
#endif

struct Ruby_ParseError : public Ruby_StandardError {

  Ruby_ParseError() = default;
  const char* rb_class_name() const override { return "ParseError"; }

};
template<> inline const char* ruby_class_name<Ruby_ParseError>() { return "ParseError"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_ParseError> : dustman::FieldList<Ruby_ParseError> {};
#endif

struct Ruby_Parser : public RubyObject {
  inline static const RubyString Racc_Runtime_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version_R = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Type = RubyString("ruby", 4);
  gc_ref<RubyObject> iv_yydebug = nullptr;
  gc_ref<RubyObject> iv_racc_debug_out = nullptr;
  RubyArray<int64_t> iv_racc_state;
  RubyArray<int64_t> iv_racc_tstack;
  RubyArray<int64_t> iv_racc_vstack;
  RubyNil iv_racc_t;
  RubyNil iv_racc_val;
  bool iv_racc_read_next = false;
  int64_t iv_racc_error_status = 0;

  Ruby_Parser() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Parser"; }

  RubyObject* _racc_setup() {
    std::fprintf(stderr, "frozone: called TI-gap stub _racc_setup\n"); std::abort();
    return nullptr;
  }

  int64_t _racc_init_sysvars() {
    iv_racc_state = ({ auto _e0 = INT64_C(0); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; });
    iv_racc_tstack = RubyArray_I64(0);
    iv_racc_vstack = RubyArray_I64(0);
    iv_racc_t = RUBY_NIL;
    iv_racc_val = RUBY_NIL;
    iv_racc_read_next = true;
    false;
    return iv_racc_error_status = INT64_C(0);
  }

  RubyObject* do_parse() {
    std::fprintf(stderr, "frozone: called TI-gap stub do_parse\n"); std::abort();
    return nullptr;
  }

  RubyObject* next_token() {
    std::fprintf(stderr, "frozone: called TI-gap stub next_token\n"); std::abort();
    return nullptr;
  }

  RubyObject* _racc_do_parse_rb(auto arg, auto in_debug) {
    std::fprintf(stderr, "frozone: called TI-gap stub _racc_do_parse_rb\n"); std::abort();
    return nullptr;
  }

  RubyObject* yyparse(auto recv, auto mid) {
    std::fprintf(stderr, "frozone: called TI-gap stub yyparse\n"); std::abort();
    return nullptr;
  }

  RubyObject* _racc_yyparse_rb(auto recv, auto mid, auto arg, auto c_debug) {
    std::fprintf(stderr, "frozone: called TI-gap stub _racc_yyparse_rb\n"); std::abort();
    return nullptr;
  }

  RubyNil _racc_evalact(auto act, auto arg) {
    int64_t nerr = 0;
    auto _masgn6 = arg;
    auto action_table = _masgn6[INT64_C(0)];
    auto action_check = _masgn6[INT64_C(1)];
    auto _ = _masgn6[INT64_C(2)];
    auto action_pointer = _masgn6[INT64_C(3)];
    _ = _masgn6[INT64_C(4)];
    _ = _masgn6[INT64_C(5)];
    _ = _masgn6[INT64_C(6)];
    _ = _masgn6[INT64_C(7)];
    _ = _masgn6[INT64_C(8)];
    _ = _masgn6[INT64_C(9)];
    _ = _masgn6[INT64_C(10)];
    auto shift_n = _masgn6[INT64_C(11)];
    auto reduce_n = _masgn6[INT64_C(12)];
    /* UNSUPPORTED masgn target: splat_nil */;
    (nerr = INT64_C(0));
    if (({ auto _l = ((act > INT64_C(0))); (_l) ? decltype(((act < shift_n)))((act < shift_n)) : decltype(((act < shift_n)))(_l); })) {
      if ((iv_racc_error_status > INT64_C(0))) {
      ((iv_racc_t <= INT64_C(1)) ? (RUBY_NIL) : (iv_racc_error_status = (iv_racc_error_status - INT64_C(1))));
    };
      iv_racc_vstack.push(iv_racc_val);
      iv_racc_state.push(act);
      iv_racc_read_next = true;
      if (iv_yydebug) {
      iv_racc_tstack.push(iv_racc_t);
      racc_shift(iv_racc_t, iv_racc_tstack, iv_racc_vstack);
    };
    } else {
      if (({ auto _l = ((act < INT64_C(0))); (_l) ? decltype(((act > (-(reduce_n)))))((act > (-(reduce_n)))) : decltype(((act > (-(reduce_n)))))(_l); })) {
      auto code = catch(ruby_sym("racc_jump"), [&]() { return iv_racc_state.push(_racc_do_reduce(arg, act)); false; });
      if (code) {
      ({ auto _cs = code; ((_cs == INT64_C(1))) ? (true; return (-(reduce_n))) : (((_cs == INT64_C(2))) ? (return shift_n) : (throw Ruby_RuntimeError("[Racc Bug] unknown jump code"))); });
    };
    } else {
      if ((act == shift_n)) {
      if (iv_yydebug) {
      racc_accept();
    };
      rb_throw(ruby_sym("racc_end_parse"), iv_racc_vstack[INT64_C(0)]);
    } else {
      if ((act == (-(reduce_n)))) {
      ({ auto _cs = iv_racc_error_status; ((_cs == INT64_C(0))) ? (if (!(arg[INT64_C(21)])) {
      (nerr = (nerr + INT64_C(1)));
      on_error(iv_racc_t, iv_racc_val, iv_racc_vstack);
    }) : (((_cs == INT64_C(3))) ? (if ((iv_racc_t == INT64_C(0))) {
      rb_throw(ruby_sym("racc_end_parse"), RUBY_NIL);
    }; iv_racc_read_next = true) : (RUBY_NIL)); });
      false;
      iv_racc_error_status = INT64_C(3);
      while (true) {
      if (auto i = action_pointer[iv_racc_state[INT64_C(-1)]]) {
      (i = (i + INT64_C(1)));
      if (({ auto _l = (({ auto _l = ((i >= INT64_C(0))); (_l) ? decltype(((act = action_table[i])))((act = action_table[i])) : decltype(((act = action_table[i])))(_l); })); (_l) ? decltype(((action_check[i] == iv_racc_state[INT64_C(-1)])))((action_check[i] == iv_racc_state[INT64_C(-1)])) : decltype(((action_check[i] == iv_racc_state[INT64_C(-1)])))(_l); })) {
      break;
    };
    };
      if ((iv_racc_state.len() <= INT64_C(1))) {
      rb_throw(ruby_sym("racc_end_parse"), RUBY_NIL);
    };
      iv_racc_state.pop();
      iv_racc_vstack.pop();
      if (iv_yydebug) {
      iv_racc_tstack.pop();
      racc_e_pop(iv_racc_state, iv_racc_tstack, iv_racc_vstack);
    };
    };
      return act;
    } else {
      throw Ruby_RuntimeError();
    };
    };
    };
    }
    if (iv_yydebug) {
      racc_next_state(iv_racc_state[INT64_C(-1)], iv_racc_state);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* _racc_do_reduce(auto arg, auto act) {
    std::fprintf(stderr, "frozone: called TI-gap stub _racc_do_reduce\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_error(auto t, auto val, auto vstack) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_error\n"); std::abort();
    return nullptr;
  }

  RubyObject* yyerror() {
    std::fprintf(stderr, "frozone: called TI-gap stub yyerror\n"); std::abort();
    return nullptr;
  }

  RubyObject* yyaccept() {
    std::fprintf(stderr, "frozone: called TI-gap stub yyaccept\n"); std::abort();
    return nullptr;
  }

  int64_t yyerrok() {
    return iv_racc_error_status = INT64_C(0);
  }

  RubyObject* racc_read_token(auto t, auto tok, auto val) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_read_token\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_shift(auto tok, auto tstack, auto vstack) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_shift\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_reduce(auto toks, auto sim, auto tstack, auto vstack) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_reduce\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_accept() {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_accept\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_e_pop(auto state, auto tstack, auto vstack) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_e_pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_next_state(auto curstate, auto state) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_next_state\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_print_stacks(auto t, auto v) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_print_stacks\n"); std::abort();
    return nullptr;
  }

  RubyObject* racc_print_states(auto s) {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_print_states\n"); std::abort();
    return nullptr;
  }

  RubyNil racc_token2str(auto tok) {
    return ({ auto _l = (INT64_C(0) /* ::Racc_token_to_s_table */[tok]); (_l) ? decltype((throw Ruby_RuntimeError()))(_l) : (throw Ruby_RuntimeError()); });
  }

  RubyNil token_to_str(auto t) {
    return INT64_C(0) /* ::Racc_token_to_s_table */[t];
  }

  static RubyObject* racc_runtime_type() {
    std::fprintf(stderr, "frozone: called TI-gap stub racc_runtime_type\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Parser>() { return "Parser"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Parser> : dustman::FieldList<Ruby_Parser> {};
#endif

struct Ruby_Node : public RubyObject {
  gc_ref<RubyObject> iv_type = nullptr;
  gc_ref<RubyObject> iv_children = nullptr;
  gc_ref<RubyObject> iv_hash = nullptr;

  Ruby_Node() = default;
  Ruby_Node(auto type, RubyArray_I64 children = RubyArray_I64(0), RubyHash<RubySymbol, int64_t> properties = RubyHash<RubySymbol, int64_t>{}) {
    auto _t7_0 = type.to_sym();
    auto _t7_1 = children.to_a();
    iv_type = _t7_0;
    iv_children = _t7_1;
    assign_properties(properties);
    iv_hash = ({ auto _e0 = iv_type; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = iv_children; _a[2] = rb_class(); _a; }).hash();
    0LL;
  }
  const char* rb_class_name() const override { return "Node"; }

  RubyObject* type() {
    std::fprintf(stderr, "frozone: called TI-gap stub type\n"); std::abort();
    return nullptr;
  }

  RubyObject* children() {
    std::fprintf(stderr, "frozone: called TI-gap stub children\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_a() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_a\n"); std::abort();
    return nullptr;
  }

  RubyObject* hash() {
    std::fprintf(stderr, "frozone: called TI-gap stub hash\n"); std::abort();
    return nullptr;
  }

  RubyObject* eql_q(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub eql_q\n"); std::abort();
    return nullptr;
  }

  RubyNil assign_properties(auto properties) {
    { auto _coll = properties; for (auto& name : *_coll.data) {
      instance_variable_set((RubyString("@", 1) + ruby_to_s(name)).to_sym(), value);
    } }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* dup_() {
    std::fprintf(stderr, "frozone: called TI-gap stub dup_\n"); std::abort();
    return nullptr;
  }

  RubyObject* clone() {
    std::fprintf(stderr, "frozone: called TI-gap stub clone\n"); std::abort();
    return nullptr;
  }

  RubyObject* updated(auto type, auto children, auto properties) {
    std::fprintf(stderr, "frozone: called TI-gap stub updated\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> operator==(auto other) {
    if (equal_q(other)) {
      return coerce_to_ref<RubyObject>(true);
    } else {
      if (false) {
        return coerce_to_ref<RubyObject>((other = other.to_ast()); ({ auto _l = ((other.type() == type())); (_l) ? decltype(((other.children() == children())))((other.children() == children())) : decltype(((other.children() == children())))(_l); }));
      } else {
        return coerce_to_ref<RubyObject>(false);
      }
    }
  }

  RubyObject* concat(auto array) {
    std::fprintf(stderr, "frozone: called TI-gap stub concat\n"); std::abort();
    return nullptr;
  }

  RubyObject* +(auto array) {
    std::fprintf(stderr, "frozone: called TI-gap stub +\n"); std::abort();
    return nullptr;
  }

  RubyObject* append(auto element) {
    std::fprintf(stderr, "frozone: called TI-gap stub append\n"); std::abort();
    return nullptr;
  }

  RubyObject* <<(auto element) {
    std::fprintf(stderr, "frozone: called TI-gap stub <<\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_sexp(auto indent) {
    std::fprintf(stderr, "frozone: called TI-gap stub to_sexp\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_s(auto indent) {
    std::fprintf(stderr, "frozone: called TI-gap stub to_s\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect(auto indent) {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_ast() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_ast\n"); std::abort();
    return nullptr;
  }

  RubyArray<RubySymbol> to_sexp_array() {
    auto children_sexp_arrs = children().map();
    return ({ auto _e0 = type(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; });
  }

  RubyArray<RubySymbol> deconstruct() {
    return ({ auto _e0 = type(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; });
  }

  RubyObject* fancy_type() {
    std::fprintf(stderr, "frozone: called TI-gap stub fancy_type\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Node>() { return "Node"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Node> : dustman::FieldList<Ruby_Node> {};
#endif

struct Ruby_Processor : public RubyObject {

  Ruby_Processor() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Processor"; }

};
template<> inline const char* ruby_class_name<Ruby_Processor>() { return "Processor"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Processor> : dustman::FieldList<Ruby_Processor> {};
#endif

struct Ruby_Node : public Ruby_Node {
  gc_ref<RubyObject> iv_location = nullptr;
  gc_ref<RubyObject> iv_type = nullptr;
  gc_ref<RubyObject> iv_children = nullptr;
  gc_ref<RubyObject> iv_hash = nullptr;

  Ruby_Node() = default;
  Ruby_Node(auto type, RubyArray_I64 children = RubyArray_I64(0), RubyHash<RubySymbol, int64_t> properties = RubyHash<RubySymbol, int64_t>{}) {
    auto _t8_0 = type.to_sym();
    auto _t8_1 = children.to_a();
    iv_type = _t8_0;
    iv_children = _t8_1;
    assign_properties(properties);
    iv_hash = ({ auto _e0 = iv_type; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = iv_children; _a[2] = rb_class(); _a; }).hash();
    0LL;
  }
  const char* rb_class_name() const override { return "Node"; }

  RubyObject* location() {
    std::fprintf(stderr, "frozone: called TI-gap stub location\n"); std::abort();
    return nullptr;
  }

  RubyObject* loc() {
    std::fprintf(stderr, "frozone: called TI-gap stub loc\n"); std::abort();
    return nullptr;
  }

  RubyNil assign_properties(auto properties) {
    std::decay_t<decltype(properties[ruby_sym("location")])> location{};
    if ((location = properties[ruby_sym("location")])) {
      return if (false) {
        (location = location.dup_());
      }; location.set_node((*this)); iv_location = location;
    }
    return RubyNil(RUBY_NIL);
  }

};
template<> inline const char* ruby_class_name<Ruby_Node>() { return "Node"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Node> : dustman::FieldList<Ruby_Node> {};
#endif

struct Ruby_Processor : public RubyObject {

  Ruby_Processor() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Processor"; }

  RubyObject* process_regular_node(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub process_regular_node\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_dstr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_dstr\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_dsym(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_dsym\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_regexp(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_regexp\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_xstr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_xstr\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_splat(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_splat\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwsplat(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwsplat\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_array(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_array\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_pair(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_pair\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_hash(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_hash\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwargs(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwargs\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_irange(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_irange\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_erange(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_erange\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_var(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* process_variable_node(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub process_variable_node\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_lvar(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_lvar\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_ivar(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_ivar\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_gvar(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_gvar\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_cvar(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_cvar\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_back_ref(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_back_ref\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_nth_ref(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_nth_ref\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_vasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_vasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* process_var_asgn_node(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub process_var_asgn_node\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_lvasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_lvasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_ivasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_ivasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_gvasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_gvasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_cvasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_cvasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_and_asgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_and_asgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_or_asgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_or_asgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_op_asgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_op_asgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_mlhs(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_mlhs\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_masgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_masgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_const(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_const\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_casgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_casgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_args(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_argument(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_argument\n"); std::abort();
    return nullptr;
  }

  RubyObject* process_argument_node(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub process_argument_node\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_arg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_arg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_optarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_optarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_restarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_restarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_blockarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_blockarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_shadowarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_shadowarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwoptarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwoptarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwrestarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwrestarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_forward_arg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_forward_arg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_procarg0(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_procarg0\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_arg_expr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_arg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_restarg_expr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_restarg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_blockarg_expr(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_blockarg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_block_pass(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_block_pass\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_forwarded_restarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_forwarded_restarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_forwarded_kwrestarg(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_forwarded_kwrestarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_module(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_module\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_class(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_class\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_sclass(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_sclass\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_def(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_def\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_defs(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_defs\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_undef(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_undef\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_alias(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_alias\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_send(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_send\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_csend(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_csend\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_index(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_index\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_indexasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_indexasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_block(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_block\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_lambda(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_lambda\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_numblock(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_numblock\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_while(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_while\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_while_post(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_while_post\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_until(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_until\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_until_post(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_until_post\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_for(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_for\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_return(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_return\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_break(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_break\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_next(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_next\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_redo(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_redo\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_retry(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_retry\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_super(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_super\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_yield(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_yield\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_defined_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_defined_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_not(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_not\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_and(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_and\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_or(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_or\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_if(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_if\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_when(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_when\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_case(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_case\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_iflipflop(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_iflipflop\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_eflipflop(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_eflipflop\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_current_line(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_current_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_with_lvasgn(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_with_lvasgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_resbody(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_resbody\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_rescue(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_rescue\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_ensure(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_ensure\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_begin(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_kwbegin(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_kwbegin\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_preexe(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_preexe\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_postexe(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_postexe\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_case_match(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_case_match\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_in_match(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_in_match\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_pattern_p(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_pattern_p\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_in_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_in_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_if_guard(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_if_guard\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_unless_guard(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_unless_guard\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_var(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_rest(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_rest\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_pin(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_pin\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_alt(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_alt\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_match_as(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_match_as\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_array_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_array_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_array_pattern_with_tail(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_array_pattern_with_tail\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_hash_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_hash_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_const_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_const_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_find_pattern(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_find_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* on_empty_else(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_empty_else\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Processor>() { return "Processor"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Processor> : dustman::FieldList<Ruby_Processor> {};
#endif

struct Ruby_Buffer : public RubyObject {
  gc_ref<RubyObject> iv_name = nullptr;
  gc_ref<RubyObject> iv_first_line = nullptr;
  gc_ref<RubyObject> iv_source = nullptr;
  gc_ref<RubyObject> iv_lines = nullptr;
  gc_ref<RubyObject> iv_line_begins = nullptr;
  gc_ref<RubyObject> iv_slice_source = nullptr;
  gc_ref<RubyObject> iv_line_index_for_position = nullptr;
  gc_ref<RubyObject> iv_source_range = nullptr;

  Ruby_Buffer() = default;
  Ruby_Buffer(auto name, int64_t first_line = INT64_C(1), int64_t source = RUBY_NIL) {
    iv_name = ruby_to_s(name);
    iv_source = RUBY_NIL;
    iv_first_line = first_line;
    iv_lines = RUBY_NIL;
    iv_line_begins = RUBY_NIL;
    iv_slice_source = RUBY_NIL;
    iv_line_index_for_position = RubyHash<RubySymbol, int64_t>{};
    if (source) {
      /* UNSUPPORTED: NilClass */.set_source(source);
    }
  }
  const char* rb_class_name() const override { return "Buffer"; }

  RubyObject* name() {
    std::fprintf(stderr, "frozone: called TI-gap stub name\n"); std::abort();
    return nullptr;
  }

  RubyObject* first_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub first_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* read() {
    std::fprintf(stderr, "frozone: called TI-gap stub read\n"); std::abort();
    return nullptr;
  }

  RubyObject* source() {
    std::fprintf(stderr, "frozone: called TI-gap stub source\n"); std::abort();
    return nullptr;
  }

  RubyNil set_source(auto input) {
    if (false) {
      (input = input.dup_());
    }
    (input = rb_class().reencode_string(input));
    if (!(input.valid_encoding_q())) {
      throw Ruby_EncodingError((RubyString("invalid byte sequence in ", 25) + ruby_to_s(input.encoding().name())));
    }
    return /* UNSUPPORTED: NilClass */.set_raw_source(input);
  }

  RubyNil set_raw_source(auto input) {
    if (iv_source) {
      throw Ruby_ArgumentError(RubyString("Source::Buffer is immutable", 27));
    }
    iv_source = input.gsub(RubyString("\r\n", 2), RubyString("\n", 1));
    if (({ auto _l = (({ auto _l = ((!(iv_source->ascii_only_q()))); (_l) ? decltype(((iv_source->encoding() != INT64_C(0) /* ::UTF_32LE */)))((iv_source->encoding() != INT64_C(0) /* ::UTF_32LE */)) : decltype(((iv_source->encoding() != INT64_C(0) /* ::UTF_32LE */)))(_l); })); (_l) ? decltype(((iv_source->encoding() != INT64_C(0) /* ::BINARY */)))((iv_source->encoding() != INT64_C(0) /* ::BINARY */)) : decltype(((iv_source->encoding() != INT64_C(0) /* ::BINARY */)))(_l); })) {
      return iv_slice_source = iv_source->encode(INT64_C(0) /* ::UTF_32LE */);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* slice(auto start, auto length) {
    std::fprintf(stderr, "frozone: called TI-gap stub slice\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> decompose_position(auto position) {
    std::decay_t<decltype(line_index_for_position(position))> line_index{};
    std::decay_t<decltype(line_begins()[line_index])> line_begin{};
    (line_index = line_index_for_position(position));
    (line_begin = line_begins()[line_index]);
    return ({ auto _e0 = (iv_first_line + line_index); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = (position - line_begin); _a; });
  }

  RubyObject* line_for_position(auto position) {
    std::fprintf(stderr, "frozone: called TI-gap stub line_for_position\n"); std::abort();
    return nullptr;
  }

  RubyObject* column_for_position(auto position) {
    std::fprintf(stderr, "frozone: called TI-gap stub column_for_position\n"); std::abort();
    return nullptr;
  }

  RubyObject* source_lines() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_lines\n"); std::abort();
    return nullptr;
  }

  RubyObject* source_line(auto lineno) {
    std::fprintf(stderr, "frozone: called TI-gap stub source_line\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> line_range(auto lineno) {
    std::decay_t<decltype((lineno - iv_first_line))> index{};
    (index = (lineno - iv_first_line));
    if (({ auto _l = ((index < INT64_C(0))); (_l) ? decltype((((index + INT64_C(1)) >= line_begins().len())))(_l) : (((index + INT64_C(1)) >= line_begins().len())); })) {
      return throw Ruby_IndexError((RubyString("Parser::Source::Buffer: range for line ", 39) + ruby_to_s((ruby_to_s(lineno) + RubyString(" requested, valid line numbers are ", 35) + ruby_to_s(iv_first_line) + RubyString("..", 2))) + ruby_to_s(ruby_to_s(((iv_first_line + line_begins().len()) - INT64_C(2))))));
    } else {
      return gc_new<Ruby_Range>((*this), line_begins()[index], (line_begins()[(index + INT64_C(1))] - INT64_C(1)));
    }
  }

  gc_ref<Ruby_Range> source_range() {
    return ({ auto _l = (iv_source_range); (_l) ? decltype((iv_source_range = gc_new<Ruby_Range>((*this), INT64_C(0), source().len())))(_l) : (iv_source_range = gc_new<Ruby_Range>((*this), INT64_C(0), source().len())); });
  }

  RubyObject* last_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub last_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* freeze(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub freeze\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

  RubyObject* line_begins() {
    std::fprintf(stderr, "frozone: called TI-gap stub line_begins\n"); std::abort();
    return nullptr;
  }

  RubyObject* line_index_for_position(auto position) {
    std::fprintf(stderr, "frozone: called TI-gap stub line_index_for_position\n"); std::abort();
    return nullptr;
  }

  RubyObject* bsearch(auto line_begins, auto position) {
    std::fprintf(stderr, "frozone: called TI-gap stub bsearch\n"); std::abort();
    return nullptr;
  }

  static RubyObject* recognize_encoding(auto string) {
    std::fprintf(stderr, "frozone: called TI-gap stub recognize_encoding\n"); std::abort();
    return nullptr;
  }

  static RubyObject* reencode_string(auto input) {
    std::fprintf(stderr, "frozone: called TI-gap stub reencode_string\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Buffer>() { return "Buffer"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Buffer> : dustman::FieldList<Ruby_Buffer> {};
#endif

struct Ruby_Range : public RubyObject {
  gc_ref<RubyObject> iv_source_buffer = nullptr;
  std::optional<int64_t> iv_begin_pos;
  std::optional<int64_t> iv_end_pos;

  Ruby_Range() = default;
  Ruby_Range(auto source_buffer, auto begin_pos, auto end_pos) {
    if ((end_pos < begin_pos)) {
      throw Ruby_ArgumentError(RubyString("Parser::Source::Range: end_pos must not be less than begin_pos", 62));
    }
    if (ruby_nil_q(source_buffer)) {
      throw Ruby_ArgumentError(RubyString("Parser::Source::Range: source_buffer must not be nil", 52));
    }
    iv_source_buffer = source_buffer;
    auto _t9_0 = begin_pos;
    auto _t9_1 = end_pos;
    iv_begin_pos = _t9_0;
    iv_end_pos = _t9_1;
    0LL;
  }
  const char* rb_class_name() const override { return "Range"; }

  RubyObject* source_buffer() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_buffer\n"); std::abort();
    return nullptr;
  }

  std::optional<int64_t> begin_pos() {
    return iv_begin_pos;
  }

  std::optional<int64_t> end_pos() {
    return iv_end_pos;
  }

  gc_ref<Ruby_Range> begin() {
    return with();
  }

  gc_ref<Ruby_Range> end() {
    return with();
  }

  RubyObject* size() {
    std::fprintf(stderr, "frozone: called TI-gap stub size\n"); std::abort();
    return nullptr;
  }

  RubyObject* length() {
    std::fprintf(stderr, "frozone: called TI-gap stub length\n"); std::abort();
    return nullptr;
  }

  RubyObject* line() {
    std::fprintf(stderr, "frozone: called TI-gap stub line\n"); std::abort();
    return nullptr;
  }

  RubyObject* first_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub first_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* column() {
    std::fprintf(stderr, "frozone: called TI-gap stub column\n"); std::abort();
    return nullptr;
  }

  RubyObject* last_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub last_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* last_column() {
    std::fprintf(stderr, "frozone: called TI-gap stub last_column\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> column_range() {
    if ((line() != last_line())) {
      throw Ruby_RangeError((ruby_to_s(inspect()) + RubyString(" spans more than one line", 25)));
    }
    return last_column();
  }

  RubyObject* source_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* source() {
    std::fprintf(stderr, "frozone: called TI-gap stub source\n"); std::abort();
    return nullptr;
  }

  RubyObject* is_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub is_q\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> to_a() {
    return ruby_range_to_a(iv_begin_pos, iv_end_pos, true);
  }

  gc_ref<Ruby_Range> to_range() {
    return end_pos();
  }

  RubyObject* to_s() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_s\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> with(std::optional<int64_t> begin_pos = iv_begin_pos, std::optional<int64_t> end_pos = iv_end_pos) {
    return gc_new<Ruby_Range>(iv_source_buffer, begin_pos, end_pos);
  }

  gc_ref<Ruby_Range> adjust(int64_t begin_pos = INT64_C(0), int64_t end_pos = INT64_C(0)) {
    return gc_new<Ruby_Range>(iv_source_buffer, (iv_begin_pos + begin_pos), (iv_end_pos + end_pos));
  }

  gc_ref<Ruby_Range> resize(auto new_size) {
    return with();
  }

  gc_ref<Ruby_Range> join(auto other) {
    return gc_new<Ruby_Range>(iv_source_buffer, (((iv_begin_pos) < (other.begin_pos())) ? (iv_begin_pos) : (other.begin_pos())), (((iv_end_pos) > (other.end_pos())) ? (iv_end_pos) : (other.end_pos())));
  }

  gc_ref<Ruby_Range> intersect(auto other) {
    if (disjoint_q(other)) {
      return Ruby_Range*(RUBY_NIL);
    } else {
      return gc_new<Ruby_Range>(iv_source_buffer, (((iv_begin_pos) > (other.begin_pos())) ? (iv_begin_pos) : (other.begin_pos())), (((iv_end_pos) < (other.end_pos())) ? (iv_end_pos) : (other.end_pos())));
    }
  }

  RubyObject* disjoint_q(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub disjoint_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* overlaps_q(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub overlaps_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* contains_q(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub contains_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* contained_q(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub contained_q\n"); std::abort();
    return nullptr;
  }

  bool crossing_q(auto other) {
    if (!(overlaps_q(other))) {
      return false;
    }
    return ((iv_begin_pos.operator<=>(other.begin_pos()) * iv_end_pos.operator<=>(other.end_pos())) == INT64_C(1));
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyNil operator<=>(auto other) {
    if (!(({ auto _l = (true); (_l) ? decltype(((iv_source_buffer == other.source_buffer())))((iv_source_buffer == other.source_buffer())) : decltype(((iv_source_buffer == other.source_buffer())))(_l); }))) {
      return RubyNil(RUBY_NIL);
    }
    return ({ auto _l = (iv_begin_pos.operator<=>(other.begin_pos()).nonzero_q()); (_l) ? decltype((iv_end_pos.operator<=>(other.end_pos())))(_l) : (iv_end_pos.operator<=>(other.end_pos())); });
  }

  RubyObject* hash() {
    std::fprintf(stderr, "frozone: called TI-gap stub hash\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Range>() { return "Range"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Range> : dustman::FieldList<Ruby_Range> {};
#endif

struct Ruby_Associator : public RubyObject {
  gc_ref<RubyObject> iv_skip_directives = nullptr;
  gc_ref<RubyObject> iv_ast = nullptr;
  gc_ref<RubyObject> iv_comments = nullptr;
  gc_ref<RubyObject> iv_map_using = nullptr;
  gc_ref<RubyObject> iv_mapping = nullptr;
  gc_ref<RubyObject> iv_comment_num = nullptr;
  gc_ref<RubyObject> iv_current_comment = nullptr;

  Ruby_Associator() = default;
  Ruby_Associator(auto ast, auto comments) {
    iv_ast = ast;
    iv_comments = comments;
    iv_skip_directives = true;
  }
  const char* rb_class_name() const override { return "Associator"; }

  RubyObject* skip_directives() {
    std::fprintf(stderr, "frozone: called TI-gap stub skip_directives\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_skip_directives(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_skip_directives\n"); std::abort();
    return nullptr;
  }

  RubyObject* associate() {
    std::fprintf(stderr, "frozone: called TI-gap stub associate\n"); std::abort();
    return nullptr;
  }

  RubyObject* associate_locations() {
    std::fprintf(stderr, "frozone: called TI-gap stub associate_locations\n"); std::abort();
    return nullptr;
  }

  RubyObject* associate_by_identity() {
    std::fprintf(stderr, "frozone: called TI-gap stub associate_by_identity\n"); std::abort();
    return nullptr;
  }

  RubyObject* children_in_source_order(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub children_in_source_order\n"); std::abort();
    return nullptr;
  }

  RubyObject* do_associate() {
    std::fprintf(stderr, "frozone: called TI-gap stub do_associate\n"); std::abort();
    return nullptr;
  }

  RubyNil visit(auto node) {
    std::decay_t<decltype(node.location())> node_loc{};
    process_leading_comments(node);
    if (!(iv_current_comment)) {
      return RubyNil(RUBY_NIL);
    }
    (node_loc = node.location());
    if (({ auto _l = ((iv_current_comment->location().line() <= node_loc.last_line())); (_l) ? decltype((true))(_l) : (true); })) {
      return { auto _coll = children_in_source_order(node); for (auto& child : *_coll.data) {
        visit(child);
      } }; process_trailing_comments(node);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil process_leading_comments(auto node) {
    if ((node.type() == ruby_sym("begin"))) {
      return RubyNil(RUBY_NIL);
    }
    while (current_comment_before_q(node)) {
      associate_and_advance_comment(node);
    }
    return RubyNil();
  }

  RubyNil process_trailing_comments(auto node) {
    while (current_comment_before_end_q(node)) {
      associate_and_advance_comment(node);
    }
    while (current_comment_decorates_q(node)) {
      associate_and_advance_comment(node);
    }
    return RubyNil();
  }

  RubyObject* advance_comment() {
    std::fprintf(stderr, "frozone: called TI-gap stub advance_comment\n"); std::abort();
    return nullptr;
  }

  bool current_comment_before_q(auto node) {
    std::decay_t<decltype(iv_current_comment->location().expression())> comment_loc{};
    std::decay_t<decltype(node.location().expression())> node_loc{};
    if ((!(iv_current_comment))) {
      return false;
    }
    (comment_loc = iv_current_comment->location().expression());
    (node_loc = node.location().expression());
    return (comment_loc.end_pos() <= node_loc.begin_pos());
  }

  bool current_comment_before_end_q(auto node) {
    std::decay_t<decltype(iv_current_comment->location().expression())> comment_loc{};
    std::decay_t<decltype(node.location().expression())> node_loc{};
    if ((!(iv_current_comment))) {
      return false;
    }
    (comment_loc = iv_current_comment->location().expression());
    (node_loc = node.location().expression());
    return (comment_loc.end_pos() <= node_loc.end_pos());
  }

  bool current_comment_decorates_q(auto node) {
    if ((!(iv_current_comment))) {
      return false;
    }
    return (iv_current_comment->location().line() == node.location().last_line());
  }

  RubyObject* associate_and_advance_comment(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub associate_and_advance_comment\n"); std::abort();
    return nullptr;
  }

  RubyNil advance_through_directives() {
    if (({ auto _l = (iv_current_comment); (_l) ? decltype((iv_current_comment->text().start_with_q(RubyString("#!", 2))))(iv_current_comment->text().start_with_q(RubyString("#!", 2))) : decltype((iv_current_comment->text().start_with_q(RubyString("#!", 2))))(_l); })) {
      advance_comment();
    }
    if (({ auto _l = (iv_current_comment); (_l) ? decltype((iv_current_comment->text().=~(MAGIC_COMMENT_RE)))(iv_current_comment->text().=~(MAGIC_COMMENT_RE)) : decltype((iv_current_comment->text().=~(MAGIC_COMMENT_RE)))(_l); })) {
      advance_comment();
    }
    if (({ auto _l = (iv_current_comment); (_l) ? decltype((iv_current_comment->text().=~(INT64_C(0) /* ::ENCODING_RE */)))(iv_current_comment->text().=~(INT64_C(0) /* ::ENCODING_RE */)) : decltype((iv_current_comment->text().=~(INT64_C(0) /* ::ENCODING_RE */)))(_l); })) {
      return advance_comment();
    }
    return RubyNil(RUBY_NIL);
  }

};
template<> inline const char* ruby_class_name<Ruby_Associator>() { return "Associator"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Associator> : dustman::FieldList<Ruby_Associator> {};
#endif

struct Ruby_Comment : public RubyObject {
  gc_ref<RubyObject> iv_text = nullptr;
  gc_ref<RubyObject> iv_location = nullptr;

  Ruby_Comment() = default;
  Ruby_Comment(auto range) {
    iv_location = gc_new<Ruby_Map>(range);
    iv_text = range.source();
    0LL;
  }
  const char* rb_class_name() const override { return "Comment"; }

  RubyObject* text() {
    std::fprintf(stderr, "frozone: called TI-gap stub text\n"); std::abort();
    return nullptr;
  }

  RubyObject* location() {
    std::fprintf(stderr, "frozone: called TI-gap stub location\n"); std::abort();
    return nullptr;
  }

  RubyObject* loc() {
    std::fprintf(stderr, "frozone: called TI-gap stub loc\n"); std::abort();
    return nullptr;
  }

  RubySymbol type() {
    if (text().start_with_q(RubyString("#", 1))) {
      return ruby_sym("inline");
    } else {
      if (text().start_with_q(RubyString("=begin", 6))) {
        return ruby_sym("document");
      }
      return RubySymbol(RUBY_NIL);
    }
  }

  RubyObject* inline_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub inline_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* document_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub document_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* operator==(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub operator==\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

  static RubyObject* associate(auto ast, auto comments) {
    std::fprintf(stderr, "frozone: called TI-gap stub associate\n"); std::abort();
    return nullptr;
  }

  static RubyObject* associate_locations(auto ast, auto comments) {
    std::fprintf(stderr, "frozone: called TI-gap stub associate_locations\n"); std::abort();
    return nullptr;
  }

  static RubyObject* associate_by_identity(auto ast, auto comments) {
    std::fprintf(stderr, "frozone: called TI-gap stub associate_by_identity\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Comment>() { return "Comment"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Comment> : dustman::FieldList<Ruby_Comment> {};
#endif

struct Ruby_Action : public RubyObject {
  gc_ref<RubyObject> iv_range = nullptr;
  RubyNil iv_replacement;
  gc_ref<RubyObject> iv_allow_multiple_insertions = nullptr;
  gc_ref<RubyObject> iv_order = nullptr;

  Ruby_Action() = default;
  Ruby_Action(auto range, RubyString replacement = RubyString("", 0), bool allow_multiple_insertions = false, int64_t order = INT64_C(0)) {
    iv_range = range;
    iv_replacement = replacement;
    iv_allow_multiple_insertions = allow_multiple_insertions;
    iv_order = order;
    0LL;
  }
  const char* rb_class_name() const override { return "Action"; }

  RubyObject* range() {
    std::fprintf(stderr, "frozone: called TI-gap stub range\n"); std::abort();
    return nullptr;
  }

  RubyNil replacement() {
    return iv_replacement;
  }

  RubyObject* allow_multiple_insertions() {
    std::fprintf(stderr, "frozone: called TI-gap stub allow_multiple_insertions\n"); std::abort();
    return nullptr;
  }

  RubyObject* order() {
    std::fprintf(stderr, "frozone: called TI-gap stub order\n"); std::abort();
    return nullptr;
  }

  RubyObject* allow_multiple_insertions_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub allow_multiple_insertions_q\n"); std::abort();
    return nullptr;
  }

  std::optional<int64_t> operator<=>(auto other) {
    std::decay_t<decltype(range().begin_pos().operator<=>(other.range().begin_pos()))> result{};
    (result = range().begin_pos().operator<=>(other.range().begin_pos()));
    if (!(result.zero_q())) {
      return result;
    }
    return order().operator<=>(other.order());
  }

  RubyObject* to_s() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_s\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Action>() { return "Action"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Action> : dustman::FieldList<Ruby_Action> {};
#endif

struct Ruby_Rewriter : public RubyObject {
  inline static const RubyString DEPRECATION_WARNING = RubyString("Parser::Source::Rewriter is deprecated.\nPlease update your code to use Parser::Source::TreeRewriter instead", 107);
  gc_ref<RubyObject> iv_source_buffer = nullptr;
  gc_ref<RubyObject> iv_diagnostics = nullptr;
  gc_ref<RubyObject> iv_queue = nullptr;
  gc_ref<RubyObject> iv_clobber = nullptr;
  gc_ref<RubyObject> iv_insertions = nullptr;
  gc_ref<RubyObject> iv_insert_before_multi_order = nullptr;
  gc_ref<RubyObject> iv_insert_after_multi_order = nullptr;
  gc_ref<RubyObject> iv_pending_queue = nullptr;
  gc_ref<RubyObject> iv_pending_clobber = nullptr;
  gc_ref<RubyObject> iv_pending_insertions = nullptr;

  Ruby_Rewriter() = default;
  Ruby_Rewriter(auto source_buffer) {
    rb_class().warn_of_deprecation();
    iv_diagnostics = gc_new<Ruby_Engine>();
    iv_diagnostics->set_consumer([&](auto diag) { return /* UNSUPPORTED: GlobalVariableRead */.puts(diag.render()); });
    iv_source_buffer = source_buffer;
    iv_queue = RubyArray_I64(0);
    iv_clobber = INT64_C(0);
    iv_insertions = INT64_C(0);
    iv_insert_before_multi_order = INT64_C(0);
    iv_insert_after_multi_order = INT64_C(0);
    iv_pending_queue = RUBY_NIL;
    iv_pending_clobber = RUBY_NIL;
    iv_pending_insertions = RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Rewriter"; }

  RubyObject* source_buffer() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_buffer\n"); std::abort();
    return nullptr;
  }

  RubyObject* diagnostics() {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostics\n"); std::abort();
    return nullptr;
  }

  RubyObject* remove(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub remove\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before\n"); std::abort();
    return nullptr;
  }

  RubyObject* wrap(auto range, auto before, auto after) {
    std::fprintf(stderr, "frozone: called TI-gap stub wrap\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before_multi(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before_multi\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after_multi(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after_multi\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace\n"); std::abort();
    return nullptr;
  }

  RubyNil process() {
    int64_t adjustment = 0;
    std::decay_t<decltype(iv_source_buffer->source().dup_())> source{};
    if (in_transaction_q()) {
      throw Ruby_RuntimeError();
    }
    (adjustment = INT64_C(0));
    (source = iv_source_buffer->source().dup_());
    { auto _coll = iv_queue->sort(); for (auto& action : *_coll.data) {
      auto begin_pos = (action.range().begin_pos() + adjustment);
      auto end_pos = (begin_pos + action.range().len());
      source.slice_assign(begin_pos, (end_pos - 1), action.replacement());
      (adjustment = (adjustment + (action.replacement().len() - action.range().len())));
    } }
    return source;
  }

  RubyObject* transaction(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub transaction\n"); std::abort();
    return nullptr;
  }

  RubyObject* append(auto action) {
    std::fprintf(stderr, "frozone: called TI-gap stub append\n"); std::abort();
    return nullptr;
  }

  RubyObject* record_insertion(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub record_insertion\n"); std::abort();
    return nullptr;
  }

  RubyObject* record_replace(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub record_replace\n"); std::abort();
    return nullptr;
  }

  RubyObject* clobbered_position_mask(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub clobbered_position_mask\n"); std::abort();
    return nullptr;
  }

  RubyObject* adjacent_position_mask(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub adjacent_position_mask\n"); std::abort();
    return nullptr;
  }

  RubyObject* adjacent_insertion_mask(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub adjacent_insertion_mask\n"); std::abort();
    return nullptr;
  }

  RubyObject* clobbered_insertion_q(auto insertion) {
    std::fprintf(stderr, "frozone: called TI-gap stub clobbered_insertion_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* adjacent_insertions_q(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub adjacent_insertions_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* adjacent_updates_q(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub adjacent_updates_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace_compatible_with_insertion_q(auto replace, auto insertion) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace_compatible_with_insertion_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* can_merge_q(auto action, auto existing) {
    std::fprintf(stderr, "frozone: called TI-gap stub can_merge_q\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Action> merge_actions(auto action, auto existing) {
    auto actions = existing.push(action).sort_by();
    auto range = actions.first().range().join(actions.max_by().range());
    return gc_new<Ruby_Action>(range, merge_replacements(actions));
  }

  RubyObject* merge_actions_b(auto action, auto existing) {
    std::fprintf(stderr, "frozone: called TI-gap stub merge_actions_b\n"); std::abort();
    return nullptr;
  }

  RubyObject* merge_replacements(auto actions) {
    std::fprintf(stderr, "frozone: called TI-gap stub merge_replacements\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace_actions(auto old, auto updated) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace_actions\n"); std::abort();
    return nullptr;
  }

  RubyObject* raise_clobber_error(auto action, auto existing) {
    std::fprintf(stderr, "frozone: called TI-gap stub raise_clobber_error\n"); std::abort();
    return nullptr;
  }

  RubyObject* in_transaction_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub in_transaction_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* active_queue() {
    std::fprintf(stderr, "frozone: called TI-gap stub active_queue\n"); std::abort();
    return nullptr;
  }

  RubyObject* active_clobber() {
    std::fprintf(stderr, "frozone: called TI-gap stub active_clobber\n"); std::abort();
    return nullptr;
  }

  RubyObject* active_insertions() {
    std::fprintf(stderr, "frozone: called TI-gap stub active_insertions\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_active_clobber(auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_active_clobber\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_active_insertions(auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_active_insertions\n"); std::abort();
    return nullptr;
  }

  RubyObject* adjacent_q(auto range1, auto range2) {
    std::fprintf(stderr, "frozone: called TI-gap stub adjacent_q\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Rewriter>() { return "Rewriter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Rewriter> : dustman::FieldList<Ruby_Rewriter> {};
#endif

struct Ruby_Action : public RubyObject {
  gc_ref<RubyObject> iv_range = nullptr;
  RubyNil iv_replacement;
  RubyString iv_insert_before;
  RubyString iv_insert_after;
  RubyString iv_enforcer;
  RubyArray<int64_t> iv_children;

  Ruby_Action() = default;
  Ruby_Action(auto range, auto enforcer, RubyString insert_before = RubyString("", 0), int64_t replacement = RUBY_NIL, RubyString insert_after = RubyString("", 0), RubyArray_I64 children = RubyArray_I64(0)) {
    auto _t10_0 = range;
    auto _t10_1 = enforcer;
    auto _t10_2 = children;
    auto _t10_3 = insert_before;
    auto _t10_4 = replacement;
    auto _t10_5 = insert_after;
    iv_range = _t10_0;
    iv_enforcer = _t10_1;
    iv_children = _t10_2;
    iv_insert_before = _t10_3;
    iv_replacement = _t10_4;
    iv_insert_after = _t10_5;
    0LL;
  }
  const char* rb_class_name() const override { return "Action"; }

  RubyObject* range() {
    std::fprintf(stderr, "frozone: called TI-gap stub range\n"); std::abort();
    return nullptr;
  }

  RubyNil replacement() {
    return iv_replacement;
  }

  RubyString insert_before() {
    return iv_insert_before;
  }

  RubyString insert_after() {
    return iv_insert_after;
  }

  gc_ref<Ruby_Range> combine(auto action) {
    if (action.empty_q()) {
      return (*this);
    }
    return do_combine(action);
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> ordered_replacements() {
    RubyArray<int64_t> reps;
    (reps = RubyArray_I64(0));
    (iv_insert_before.empty_q() ? (RUBY_NIL) : ((reps << ({ auto _e0 = iv_range->begin(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_insert_before; _a; }))));
    if (iv_replacement) {
      (reps << ({ auto _e0 = iv_range; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_replacement; _a; }));
    }
    reps.concat(iv_children->flat_map());
    (iv_insert_after.empty_q() ? (RUBY_NIL) : ((reps << ({ auto _e0 = iv_range->end(); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_insert_after; _a; }))));
    return reps;
  }

  RubyObject* nested_actions() {
    std::fprintf(stderr, "frozone: called TI-gap stub nested_actions\n"); std::abort();
    return nullptr;
  }

  RubyObject* insertion_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub insertion_q\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> contract() {
    std::decay_t<decltype(iv_range->with())> range{};
    if (empty_q()) {
      throw Ruby_RuntimeError("Empty actions can not be contracted");
    }
    if (insertion_q()) {
      return (*this);
    }
    (range = iv_range->with());
    return with();
  }

  gc_ref<Ruby_Range> moved(auto source_buffer, auto offset) {
    gc_ref<Ruby_Range> moved_range;
    (moved_range = gc_new<Ruby_Range>(source_buffer, (iv_range->begin_pos() + offset), (iv_range->end_pos() + offset)));
    return with();
  }

  RubyArray<int64_t> children() {
    return iv_children;
  }

  RubyObject* with(auto range, auto enforcer, auto children, auto insert_before, auto replacement, auto insert_after) {
    std::fprintf(stderr, "frozone: called TI-gap stub with\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> do_combine(auto action) {
    if ((action.range() == iv_range)) {
      return merge(action);
    } else {
      return place_in_hierarchy(action);
    }
  }

  gc_ref<Ruby_Range> place_in_hierarchy(auto action) {
    RubyHash<RubySymbol, RubyNil> family;
    (family = analyse_hierarchy(action));
    if (family[ruby_sym("fusible")]) {
      return fuse_deletions(action, family[ruby_sym("fusible")], ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = /* UNSUPPORTED: SplatArg */; _a; }));
    } else {
      return auto extra_sibbling = if (family[ruby_sym("parent")]) {
        family[ruby_sym("parent")].do_combine(action);
      } else {
        (family[ruby_sym("child")] ? (action.with().combine_children(action.children())) : (action));
      }; with();
    }
  }

  RubyObject* combine_children(auto more_children) {
    std::fprintf(stderr, "frozone: called TI-gap stub combine_children\n"); std::abort();
    return nullptr;
  }

  RubyObject* fuse_deletions(auto action, auto fusible, auto other_sibblings) {
    std::fprintf(stderr, "frozone: called TI-gap stub fuse_deletions\n"); std::abort();
    return nullptr;
  }

  int64_t bsearch_child_index(int64_t from = INT64_C(0)) {
    int64_t size = 0;
    (size = iv_children.len());
    return ({ auto _l = (size.bsearch()); (_l) ? decltype((size))(_l) : (size); });
  }

  RubyHash<RubySymbol, RubyNil> analyse_hierarchy(auto action) {
    std::decay_t<decltype(action.range())> r{};
    int64_t start = 0;
    RubyNil fusible;
    (r = action.range());
    auto left_index = bsearch_child_index([&](auto child) { return (child.range().end_pos() > r.begin_pos()); });
    (start = ((left_index == INT64_C(0)) ? (INT64_C(0)) : ((left_index - INT64_C(1)))));
    auto right_index = bsearch_child_index(start, [&](auto child) { return (child.range().begin_pos() >= r.end_pos()); });
    auto center = (right_index - left_index);
    ({ auto _cs = center; ((_cs == INT64_C(0))) ? (RUBY_NIL) : (((_cs == INT64_C(-1))) ? ((left_index = (left_index - INT64_C(1))); (right_index = (right_index + INT64_C(1))); auto parent = iv_children->operator[](left_index)) : (auto overlap_left = iv_children->operator[](left_index).range().begin_pos().operator<=>(r.begin_pos()); auto overlap_right = iv_children->operator[]((right_index - INT64_C(1))).range().end_pos().operator<=>(r.end_pos()); if (({ auto _l = (({ auto _l = ((center == INT64_C(1))); (_l) ? decltype(((overlap_left <= INT64_C(0))))((overlap_left <= INT64_C(0))) : decltype(((overlap_left <= INT64_C(0))))(_l); })); (_l) ? decltype(((overlap_right >= INT64_C(0))))((overlap_right >= INT64_C(0))) : decltype(((overlap_right >= INT64_C(0))))(_l); })) {
      (parent = iv_children->operator[](left_index));
    } else {
      auto contained = iv_children->operator[](right_index);
      (fusible = check_fusible(action, if ((overlap_left < INT64_C(0))) {
      contained.shift();
    }, if ((overlap_right > INT64_C(0))) {
      contained.pop();
    }));
    })); })
    return ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("parent"), parent); _h.store(ruby_sym("sibbling_left"), iv_children->operator[](left_index)); _h.store(ruby_sym("sibbling_right"), iv_children->operator[](iv_children.len())); _h.store(ruby_sym("fusible"), fusible); _h.store(ruby_sym("child"), contained); _h; });
  }

  RubyNil check_fusible(auto action) {
    RubySymbol kind;
    fusible.compact_b();
    if (fusible.empty_q()) {
      return RubyNil(RUBY_NIL);
    }
    { auto _coll = fusible; for (auto& child : *_coll.data) {
      (kind = (({ auto _l = (action.insertion_q()); (_l) ? decltype((child.insertion_q()))(_l) : (child.insertion_q()); }) ? (ruby_sym("crossing_insertions")) : (ruby_sym("crossing_deletions"))));
      iv_enforcer(kind);
    } }
    return fusible;
  }

  RubyObject* merge(auto action) {
    std::fprintf(stderr, "frozone: called TI-gap stub merge\n"); std::abort();
    return nullptr;
  }

  RubyObject* call_enforcer_for_merge(auto action) {
    std::fprintf(stderr, "frozone: called TI-gap stub call_enforcer_for_merge\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> swallow(auto children) {
    iv_enforcer(ruby_sym("swallowed_insertions"));
    return RubyArray_I64(0);
  }

};
template<> inline const char* ruby_class_name<Ruby_Action>() { return "Action"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Action> : dustman::FieldList<Ruby_Action> {};
#endif

struct Ruby_TreeRewriter : public RubyObject {
  inline static const RubyString DEPRECATION_WARNING = RubyString("TreeRewriter#insert_before_multi and insert_before_multi exist only for legacy compatibility.\nPlease update your code to use `wrap`, `insert_before` or `insert_after` instead.", 175);
  gc_ref<RubyObject> iv_source_buffer = nullptr;
  gc_ref<RubyObject> iv_diagnostics = nullptr;
  gc_ref<RubyObject> iv_in_transaction = nullptr;
  gc_ref<RubyObject> iv_policy = nullptr;
  gc_ref<RubyObject> iv_enforcer = nullptr;
  gc_ref<RubyObject> iv_action_root = nullptr;

  Ruby_TreeRewriter() = default;
  Ruby_TreeRewriter(auto source_buffer, RubySymbol crossing_deletions = ruby_sym("accept"), RubySymbol different_replacements = ruby_sym("accept"), RubySymbol swallowed_insertions = ruby_sym("accept")) {
    iv_diagnostics = gc_new<Ruby_Engine>();
    iv_diagnostics->set_consumer(/* UNSUPPORTED: Lambda */);
    iv_source_buffer = source_buffer;
    iv_in_transaction = false;
    iv_policy = ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("crossing_deletions"), crossing_deletions); _h.store(ruby_sym("different_replacements"), different_replacements); _h.store(ruby_sym("swallowed_insertions"), swallowed_insertions); _h; });
    check_policy_validity();
    iv_enforcer = method(ruby_sym("enforce_policy"));
    auto all_encompassing_range = iv_source_buffer->source_range().adjust();
    iv_action_root = gc_new<Ruby_Action>(all_encompassing_range, iv_enforcer);
  }
  const char* rb_class_name() const override { return "TreeRewriter"; }

  RubyObject* source_buffer() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_buffer\n"); std::abort();
    return nullptr;
  }

  RubyObject* diagnostics() {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostics\n"); std::abort();
    return nullptr;
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* merge_b(auto with) {
    std::fprintf(stderr, "frozone: called TI-gap stub merge_b\n"); std::abort();
    return nullptr;
  }

  RubyObject* merge(auto with) {
    std::fprintf(stderr, "frozone: called TI-gap stub merge\n"); std::abort();
    return nullptr;
  }

  RubyObject* import_b(auto foreign_rewriter, auto offset) {
    std::fprintf(stderr, "frozone: called TI-gap stub import_b\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace\n"); std::abort();
    return nullptr;
  }

  RubyObject* wrap(auto range, auto insert_before, auto insert_after) {
    std::fprintf(stderr, "frozone: called TI-gap stub wrap\n"); std::abort();
    return nullptr;
  }

  RubyObject* remove(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub remove\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after\n"); std::abort();
    return nullptr;
  }

  RubyNil process() {
    std::decay_t<decltype(iv_source_buffer->source())> source{};
    RubyArray<int64_t> chunks;
    int64_t last_end = 0;
    (source = iv_source_buffer->source());
    (chunks = RubyArray_I64(0));
    (last_end = INT64_C(0));
    { auto _coll = iv_action_root->ordered_replacements(); for (auto& range : *_coll.data) {
      ((chunks << source[range.begin_pos()]) << replacement);
      (last_end = range.end_pos());
    } }
    (chunks << source[source.len()]);
    return chunks.join();
  }

  RubyObject* as_replacements() {
    std::fprintf(stderr, "frozone: called TI-gap stub as_replacements\n"); std::abort();
    return nullptr;
  }

  RubyObject* as_nested_actions() {
    std::fprintf(stderr, "frozone: called TI-gap stub as_nested_actions\n"); std::abort();
    return nullptr;
  }

  RubyObject* transaction(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub transaction\n"); std::abort();
    return nullptr;
  }

  RubyObject* in_transaction_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub in_transaction_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before_multi(auto range, auto text) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before_multi\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after_multi(auto range, auto text) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after_multi\n"); std::abort();
    return nullptr;
  }

  RubyObject* action_root() {
    std::fprintf(stderr, "frozone: called TI-gap stub action_root\n"); std::abort();
    return nullptr;
  }

  RubyObject* action_summary() {
    std::fprintf(stderr, "frozone: called TI-gap stub action_summary\n"); std::abort();
    return nullptr;
  }

  RubyObject* check_policy_validity() {
    std::fprintf(stderr, "frozone: called TI-gap stub check_policy_validity\n"); std::abort();
    return nullptr;
  }

  RubyObject* combine(auto range, auto attributes) {
    std::fprintf(stderr, "frozone: called TI-gap stub combine\n"); std::abort();
    return nullptr;
  }

  RubyObject* check_range_validity(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_range_validity\n"); std::abort();
    return nullptr;
  }

  RubyObject* enforce_policy(auto event, auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub enforce_policy\n"); std::abort();
    return nullptr;
  }

  RubyObject* trigger_policy(auto event, auto range, auto conflict) {
    std::fprintf(stderr, "frozone: called TI-gap stub trigger_policy\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_TreeRewriter>() { return "TreeRewriter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TreeRewriter> : dustman::FieldList<Ruby_TreeRewriter> {};
#endif

struct Ruby_Operator : public Ruby_Map {
  gc_ref<RubyObject> iv_operator = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Operator() = default;
  Ruby_Operator(auto operator, auto expression) {
    iv_operator = rb_operator;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Operator"; }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Operator>() { return "Operator"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Operator> : dustman::FieldList<Ruby_Operator> {};
#endif

struct Ruby_Collection : public Ruby_Map {
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Collection() = default;
  Ruby_Collection(auto begin_l, auto end_l, auto expression_l) {
    auto _t11_0 = begin_l;
    auto _t11_1 = end_l;
    iv_begin = _t11_0;
    iv_end = _t11_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Collection"; }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Collection>() { return "Collection"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Collection> : dustman::FieldList<Ruby_Collection> {};
#endif

struct Ruby_Constant : public Ruby_Map {
  gc_ref<RubyObject> iv_double_colon = nullptr;
  gc_ref<RubyObject> iv_name = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Constant() = default;
  Ruby_Constant(auto double_colon, auto name, auto expression) {
    auto _t12_0 = double_colon;
    auto _t12_1 = name;
    iv_double_colon = _t12_0;
    iv_name = _t12_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Constant"; }

  RubyObject* double_colon() {
    std::fprintf(stderr, "frozone: called TI-gap stub double_colon\n"); std::abort();
    return nullptr;
  }

  RubyObject* name() {
    std::fprintf(stderr, "frozone: called TI-gap stub name\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> with_operator(auto operator_l) {
    return with([&](auto map) { return map.update_operator(operator_l); });
  }

  RubyObject* update_operator(auto operator_l) {
    std::fprintf(stderr, "frozone: called TI-gap stub update_operator\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Constant>() { return "Constant"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Constant> : dustman::FieldList<Ruby_Constant> {};
#endif

struct Ruby_Variable : public Ruby_Map {
  gc_ref<RubyObject> iv_name = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Variable() = default;
  Ruby_Variable(auto name_l, int64_t expression_l = name_l) {
    iv_name = name_l;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Variable"; }

  RubyObject* name() {
    std::fprintf(stderr, "frozone: called TI-gap stub name\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> with_operator(auto operator_l) {
    return with([&](auto map) { return map.update_operator(operator_l); });
  }

  RubyObject* update_operator(auto operator_l) {
    std::fprintf(stderr, "frozone: called TI-gap stub update_operator\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Variable>() { return "Variable"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Variable> : dustman::FieldList<Ruby_Variable> {};
#endif

struct Ruby_Keyword : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Keyword() = default;
  Ruby_Keyword(auto keyword_l, auto begin_l, auto end_l, auto expression_l) {
    iv_keyword = keyword_l;
    auto _t13_0 = begin_l;
    auto _t13_1 = end_l;
    iv_begin = _t13_0;
    iv_end = _t13_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Keyword"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Keyword>() { return "Keyword"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Keyword> : dustman::FieldList<Ruby_Keyword> {};
#endif

struct Ruby_Definition : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  gc_ref<RubyObject> iv_name = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Definition() = default;
  Ruby_Definition(auto keyword_l, auto operator_l, auto name_l, auto end_l) {
    iv_keyword = keyword_l;
    iv_operator = operator_l;
    iv_name = name_l;
    iv_end = end_l;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Definition"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  RubyObject* name() {
    std::fprintf(stderr, "frozone: called TI-gap stub name\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Definition>() { return "Definition"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Definition> : dustman::FieldList<Ruby_Definition> {};
#endif

struct Ruby_MethodDefinition : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  gc_ref<RubyObject> iv_name = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  gc_ref<RubyObject> iv_assignment = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_MethodDefinition() = default;
  Ruby_MethodDefinition(auto keyword_l, auto operator_l, auto name_l, auto end_l, auto assignment_l, auto body_l) {
    iv_keyword = keyword_l;
    iv_operator = operator_l;
    iv_name = name_l;
    iv_end = end_l;
    iv_assignment = assignment_l;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "MethodDefinition"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  RubyObject* name() {
    std::fprintf(stderr, "frozone: called TI-gap stub name\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

  RubyObject* assignment() {
    std::fprintf(stderr, "frozone: called TI-gap stub assignment\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_MethodDefinition>() { return "MethodDefinition"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_MethodDefinition> : dustman::FieldList<Ruby_MethodDefinition> {};
#endif

struct Ruby_Send : public Ruby_Map {
  gc_ref<RubyObject> iv_dot = nullptr;
  gc_ref<RubyObject> iv_selector = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Send() = default;
  Ruby_Send(auto dot_l, auto selector_l, auto begin_l, auto end_l, auto expression_l) {
    iv_dot = dot_l;
    iv_selector = selector_l;
    auto _t14_0 = begin_l;
    auto _t14_1 = end_l;
    iv_begin = _t14_0;
    iv_end = _t14_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Send"; }

  RubyObject* dot() {
    std::fprintf(stderr, "frozone: called TI-gap stub dot\n"); std::abort();
    return nullptr;
  }

  RubyObject* selector() {
    std::fprintf(stderr, "frozone: called TI-gap stub selector\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> with_operator(auto operator_l) {
    return with([&](auto map) { return map.update_operator(operator_l); });
  }

  RubyObject* update_operator(auto operator_l) {
    std::fprintf(stderr, "frozone: called TI-gap stub update_operator\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Send>() { return "Send"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Send> : dustman::FieldList<Ruby_Send> {};
#endif

struct Ruby_Index : public Ruby_Map {
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_operator;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Index() = default;
  Ruby_Index(auto begin_l, auto end_l, auto expression_l) {
    auto _t15_0 = begin_l;
    auto _t15_1 = end_l;
    iv_begin = _t15_0;
    iv_end = _t15_1;
    iv_operator = RUBY_NIL;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Index"; }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

  RubyNil rb_operator() {
    return iv_operator;
  }

  gc_ref<Ruby_Range> with_operator(auto operator_l) {
    return with([&](auto map) { return map.update_operator(operator_l); });
  }

  RubyObject* update_operator(auto operator_l) {
    std::fprintf(stderr, "frozone: called TI-gap stub update_operator\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Index>() { return "Index"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Index> : dustman::FieldList<Ruby_Index> {};
#endif

struct Ruby_Condition : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_else = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Condition() = default;
  Ruby_Condition(auto keyword_l, auto begin_l, auto else_l, auto end_l, auto expression_l) {
    iv_keyword = keyword_l;
    auto _t16_0 = begin_l;
    auto _t16_1 = else_l;
    auto _t16_2 = end_l;
    iv_begin = _t16_0;
    iv_else = _t16_1;
    iv_end = _t16_2;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Condition"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_else() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_else\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Condition>() { return "Condition"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Condition> : dustman::FieldList<Ruby_Condition> {};
#endif

struct Ruby_Ternary : public Ruby_Map {
  gc_ref<RubyObject> iv_question = nullptr;
  gc_ref<RubyObject> iv_colon = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Ternary() = default;
  Ruby_Ternary(auto question_l, auto colon_l, auto expression_l) {
    auto _t17_0 = question_l;
    auto _t17_1 = colon_l;
    iv_question = _t17_0;
    iv_colon = _t17_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Ternary"; }

  RubyObject* question() {
    std::fprintf(stderr, "frozone: called TI-gap stub question\n"); std::abort();
    return nullptr;
  }

  RubyObject* colon() {
    std::fprintf(stderr, "frozone: called TI-gap stub colon\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Ternary>() { return "Ternary"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Ternary> : dustman::FieldList<Ruby_Ternary> {};
#endif

struct Ruby_For : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_in = nullptr;
  gc_ref<RubyObject> iv_begin = nullptr;
  gc_ref<RubyObject> iv_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_For() = default;
  Ruby_For(auto keyword_l, auto in_l, auto begin_l, auto end_l, auto expression_l) {
    auto _t18_0 = keyword_l;
    auto _t18_1 = in_l;
    iv_keyword = _t18_0;
    iv_in = _t18_1;
    auto _t19_0 = begin_l;
    auto _t19_1 = end_l;
    iv_begin = _t19_0;
    iv_end = _t19_1;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "For"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* in() {
    std::fprintf(stderr, "frozone: called TI-gap stub in\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* end() {
    std::fprintf(stderr, "frozone: called TI-gap stub end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_For>() { return "For"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_For> : dustman::FieldList<Ruby_For> {};
#endif

struct Ruby_RescueBody : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_assoc = nullptr;
  gc_ref<RubyObject> iv_begin = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_RescueBody() = default;
  Ruby_RescueBody(auto keyword_l, auto assoc_l, auto begin_l, auto expression_l) {
    iv_keyword = keyword_l;
    iv_assoc = assoc_l;
    iv_begin = begin_l;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "RescueBody"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* assoc() {
    std::fprintf(stderr, "frozone: called TI-gap stub assoc\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin() {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_RescueBody>() { return "RescueBody"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_RescueBody> : dustman::FieldList<Ruby_RescueBody> {};
#endif

struct Ruby_Heredoc : public Ruby_Map {
  gc_ref<RubyObject> iv_heredoc_body = nullptr;
  gc_ref<RubyObject> iv_heredoc_end = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Heredoc() = default;
  Ruby_Heredoc(auto begin_l, auto body_l, auto end_l) {
    iv_heredoc_body = body_l;
    iv_heredoc_end = end_l;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Heredoc"; }

  RubyObject* heredoc_body() {
    std::fprintf(stderr, "frozone: called TI-gap stub heredoc_body\n"); std::abort();
    return nullptr;
  }

  RubyObject* heredoc_end() {
    std::fprintf(stderr, "frozone: called TI-gap stub heredoc_end\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Heredoc>() { return "Heredoc"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Heredoc> : dustman::FieldList<Ruby_Heredoc> {};
#endif

struct Ruby_ObjcKwarg : public Ruby_Map {
  gc_ref<RubyObject> iv_keyword = nullptr;
  gc_ref<RubyObject> iv_operator = nullptr;
  gc_ref<RubyObject> iv_argument = nullptr;
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_ObjcKwarg() = default;
  Ruby_ObjcKwarg(auto keyword_l, auto operator_l, auto argument_l, auto expression_l) {
    auto _t20_0 = keyword_l;
    auto _t20_1 = operator_l;
    auto _t20_2 = argument_l;
    iv_keyword = _t20_0;
    iv_operator = _t20_1;
    iv_argument = _t20_2;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "ObjcKwarg"; }

  RubyObject* keyword() {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_operator() {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_operator\n"); std::abort();
    return nullptr;
  }

  RubyObject* argument() {
    std::fprintf(stderr, "frozone: called TI-gap stub argument\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_ObjcKwarg>() { return "ObjcKwarg"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_ObjcKwarg> : dustman::FieldList<Ruby_ObjcKwarg> {};
#endif

struct Ruby_Map : public RubyObject {
  RubyNil iv_node;
  gc_ref<RubyObject> iv_expression = nullptr;

  Ruby_Map() = default;
  Ruby_Map(auto expression) {
    iv_expression = expression;
  }
  const char* rb_class_name() const override { return "Map"; }

  RubyNil node() {
    return iv_node;
  }

  RubyObject* expression() {
    std::fprintf(stderr, "frozone: called TI-gap stub expression\n"); std::abort();
    return nullptr;
  }

  RubyNil initialize_copy(auto other) {
    /* UNSUPPORTED: Super */;
    return iv_node = RUBY_NIL;
  }

  RubyNil set_node(auto node) {
    iv_node = node;
    0LL;
    return iv_node;
  }

  RubyObject* line() {
    std::fprintf(stderr, "frozone: called TI-gap stub line\n"); std::abort();
    return nullptr;
  }

  RubyObject* first_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub first_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* column() {
    std::fprintf(stderr, "frozone: called TI-gap stub column\n"); std::abort();
    return nullptr;
  }

  RubyObject* last_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub last_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* last_column() {
    std::fprintf(stderr, "frozone: called TI-gap stub last_column\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Range> with_expression(auto expression_l) {
    return with([&](auto map) { return map.update_expression(expression_l); });
  }

  RubyObject* operator==(auto other) {
    std::fprintf(stderr, "frozone: called TI-gap stub operator==\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_hash() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_hash\n"); std::abort();
    return nullptr;
  }

  RubyObject* with(auto _block) {
    std::fprintf(stderr, "frozone: called TI-gap stub with\n"); std::abort();
    return nullptr;
  }

  RubyObject* update_expression(auto expression_l) {
    std::fprintf(stderr, "frozone: called TI-gap stub update_expression\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Map>() { return "Map"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Map> : dustman::FieldList<Ruby_Map> {};
#endif

struct Ruby_SyntaxError : public Ruby_StandardError {
  gc_ref<RubyObject> iv_diagnostic = nullptr;
  gc_ref<RubyObject> iv_backtrace = nullptr;
  gc_ref<RubyObject> iv_cause = nullptr;
  gc_ref<RubyObject> iv_message = nullptr;
  gc_ref<RubyObject> iv__has_locations = nullptr;
  gc_ref<RubyObject> iv_backtrace_locations = nullptr;

  Ruby_SyntaxError() = default;
  Ruby_SyntaxError(auto diagnostic) {
    iv_diagnostic = diagnostic;
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "SyntaxError"; }

  RubyObject* diagnostic() {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostic\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_SyntaxError>() { return "SyntaxError"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_SyntaxError> : dustman::FieldList<Ruby_SyntaxError> {};
#endif

struct Ruby_ClobberingError : public Ruby_RuntimeError {

  Ruby_ClobberingError() = default;
  const char* rb_class_name() const override { return "ClobberingError"; }

};
template<> inline const char* ruby_class_name<Ruby_ClobberingError>() { return "ClobberingError"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_ClobberingError> : dustman::FieldList<Ruby_ClobberingError> {};
#endif

struct Ruby_UnknownEncodingInMagicComment : public Ruby_ArgumentError {

  Ruby_UnknownEncodingInMagicComment() = default;
  const char* rb_class_name() const override { return "UnknownEncodingInMagicComment"; }

};
template<> inline const char* ruby_class_name<Ruby_UnknownEncodingInMagicComment>() { return "UnknownEncodingInMagicComment"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_UnknownEncodingInMagicComment> : dustman::FieldList<Ruby_UnknownEncodingInMagicComment> {};
#endif

struct Ruby_Engine : public RubyObject {
  gc_ref<RubyObject> iv_consumer = nullptr;
  bool iv_all_errors_are_fatal = false;
  bool iv_ignore_warnings = false;

  Ruby_Engine() = default;
  Ruby_Engine(auto consumer = RUBY_NIL) {
    iv_consumer = consumer;
    iv_all_errors_are_fatal = false;
    iv_ignore_warnings = false;
  }
  const char* rb_class_name() const override { return "Engine"; }

  RubyObject* consumer() {
    std::fprintf(stderr, "frozone: called TI-gap stub consumer\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_consumer(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_consumer\n"); std::abort();
    return nullptr;
  }

  bool all_errors_are_fatal() {
    return iv_all_errors_are_fatal;
  }

  bool set_all_errors_are_fatal(auto __anon_req__) {
    iv_all_errors_are_fatal = __anon_req__;
    return iv_all_errors_are_fatal;
  }

  bool ignore_warnings() {
    return iv_ignore_warnings;
  }

  bool set_ignore_warnings(auto __anon_req__) {
    iv_ignore_warnings = __anon_req__;
    return iv_ignore_warnings;
  }

  RubyObject* process(auto diagnostic) {
    std::fprintf(stderr, "frozone: called TI-gap stub process\n"); std::abort();
    return nullptr;
  }

  bool ignore_q(auto diagnostic) {
    return ({ auto _l = (iv_ignore_warnings); (_l) ? decltype(((diagnostic.level() == ruby_sym("warning"))))((diagnostic.level() == ruby_sym("warning"))) : decltype(((diagnostic.level() == ruby_sym("warning"))))(_l); });
  }

  bool raise_q(auto diagnostic) {
    return ({ auto _l = (({ auto _l = (iv_all_errors_are_fatal); (_l) ? decltype(((diagnostic.level() == ruby_sym("error"))))((diagnostic.level() == ruby_sym("error"))) : decltype(((diagnostic.level() == ruby_sym("error"))))(_l); })); (_l) ? decltype(((diagnostic.level() == ruby_sym("fatal"))))(_l) : ((diagnostic.level() == ruby_sym("fatal"))); });
  }

};
template<> inline const char* ruby_class_name<Ruby_Engine>() { return "Engine"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Engine> : dustman::FieldList<Ruby_Engine> {};
#endif

struct Ruby_Diagnostic : public RubyObject {
  RubySymbol iv_level;
  RubySymbol iv_reason;
  RubyHash<RubySymbol, RubyString> iv_arguments;
  RubyArray<RubyNil> iv_location;
  gc_ref<RubyObject> iv_highlights = nullptr;

  Ruby_Diagnostic() = default;
  Ruby_Diagnostic(auto level, auto reason, auto arguments, auto location, RubyArray_I64 highlights = RubyArray_I64(0)) {
    if (!(LEVELS.include_q(level))) {
      throw Ruby_ArgumentError((ruby_to_s((RubyString("Diagnostic#level must be one of ", 32) + ruby_to_s(LEVELS.join(RubyString(", ", 2))) + RubyString("; ", 2))) + ruby_to_s((ruby_to_s(level.inspect()) + RubyString(" provided.", 10)))));
    }
    if (!(location)) {
      throw Ruby_RuntimeError("Expected a location");
    }
    iv_level = level;
    iv_reason = reason;
    iv_arguments = ({ auto _l = (arguments); (_l) ? decltype((RubyHash<RubySymbol, int64_t>{}))(_l) : (RubyHash<RubySymbol, int64_t>{}); }).dup_();
    iv_location = location;
    iv_highlights = highlights.dup_();
    0LL;
  }
  const char* rb_class_name() const override { return "Diagnostic"; }

  RubySymbol level() {
    return iv_level;
  }

  RubySymbol reason() {
    return iv_reason;
  }

  RubyHash<RubySymbol, RubyString> arguments() {
    return iv_arguments;
  }

  RubyArray<RubyNil> location() {
    return iv_location;
  }

  RubyObject* highlights() {
    std::fprintf(stderr, "frozone: called TI-gap stub highlights\n"); std::abort();
    return nullptr;
  }

  RubyNil message() {
    return Messages.compile(iv_reason, iv_arguments);
  }

  RubyObject* render() {
    std::fprintf(stderr, "frozone: called TI-gap stub render\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> render_line(auto range, bool ellipsis = false, bool range_end = false) {
    std::decay_t<decltype(range.source_line())> source_line{};
    RubyString highlight_line;
    std::decay_t<decltype(range.source_buffer().line_range(range.line()))> line_range{};
    (source_line = range.source_line());
    (highlight_line = (RubyString(" ", 1) * source_line.len()));
    { auto _coll = iv_highlights; for (auto& highlight : *_coll.data) {
      (line_range = range.source_buffer().line_range(range.line()));
      if ((highlight = highlight.intersect(line_range))) {
        highlight_line[highlight.column_range()] = (RubyString("~", 1) * highlight.len());
      };
    } }
    if (range.is_q(RubyString("\n", 1))) {
      (highlight_line = (highlight_line + RubyString("^", 1)));
    } else {
      (({ auto _l = ((!(range_end))); (_l) ? decltype(((range.len() >= INT64_C(1))))((range.len() >= INT64_C(1))) : decltype(((range.len() >= INT64_C(1))))(_l); }) ? (highlight_line[range.column_range()] = (RubyString("^", 1) + (RubyString("~", 1) * (range.len() - INT64_C(1))))) : (highlight_line[range.column_range()] = (RubyString("~", 1) * range.len())));
    }
    if (ellipsis) {
      (highlight_line = (highlight_line + RubyString("...", 3)));
    }
    return ({ auto _e0 = source_line; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = highlight_line; _a; }).map();
  }

  RubyArray<RubyNil> first_line_only(auto range) {
    if ((range.line() != range.last_line())) {
      return range.resize(range.source().=~(/* UNSUPPORTED: RegexpLiteral */));
    } else {
      return range;
    }
  }

  RubyArray<RubyNil> last_line_only(auto range) {
    if ((range.line() != range.last_line())) {
      return range.adjust();
    } else {
      return range;
    }
  }

};
template<> inline const char* ruby_class_name<Ruby_Diagnostic>() { return "Diagnostic"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Diagnostic> : dustman::FieldList<Ruby_Diagnostic> {};
#endif

struct Ruby_StaticEnvironment : public RubyObject {
  RubyNil iv_variables;
  RubyArray<int64_t> iv_stack;

  Ruby_StaticEnvironment() {
    reset();
  }
  const char* rb_class_name() const override { return "StaticEnvironment"; }

  RubyArray<int64_t> reset() {
    iv_variables = Ruby_Set::operator[]();
    return iv_stack = RubyArray_I64(0);
  }

  RubyObject* extend_static() {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_static\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_dynamic() {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_dynamic\n"); std::abort();
    return nullptr;
  }

  RubyObject* unextend() {
    std::fprintf(stderr, "frozone: called TI-gap stub unextend\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub declare\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_q(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare_forward_args() {
    std::fprintf(stderr, "frozone: called TI-gap stub declare_forward_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_forward_args_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_forward_args_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare_anonymous_blockarg() {
    std::fprintf(stderr, "frozone: called TI-gap stub declare_anonymous_blockarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_blockarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_blockarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_blockarg_in_current_scpe_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_blockarg_in_current_scpe_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* parent_has_anonymous_blockarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub parent_has_anonymous_blockarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare_anonymous_restarg() {
    std::fprintf(stderr, "frozone: called TI-gap stub declare_anonymous_restarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_restarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_restarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_restarg_in_current_scope_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_restarg_in_current_scope_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* parent_has_anonymous_restarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub parent_has_anonymous_restarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare_anonymous_kwrestarg() {
    std::fprintf(stderr, "frozone: called TI-gap stub declare_anonymous_kwrestarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_kwrestarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_kwrestarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_anonymous_kwrestarg_in_current_scope_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_anonymous_kwrestarg_in_current_scope_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* parent_has_anonymous_kwrestarg_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub parent_has_anonymous_kwrestarg_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_StaticEnvironment>() { return "StaticEnvironment"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_StaticEnvironment> : dustman::FieldList<Ruby_StaticEnvironment> {};
#endif

struct Ruby_Literal : public RubyObject {
  inline static const int64_t SPACE = 32LL;
  inline static const int64_t TAB = 9LL;
  gc_ref<RubyObject> iv_heredoc_e = nullptr;
  gc_ref<RubyObject> iv_str_s = nullptr;
  gc_ref<RubyObject> iv_dedent_level = nullptr;
  gc_ref<RubyObject> iv_saved_herebody_s = nullptr;
  gc_ref<RubyObject> iv_lexer = nullptr;
  gc_ref<RubyObject> iv_nesting = nullptr;
  gc_ref<RubyObject> iv_str_type = nullptr;
  gc_ref<RubyObject> iv_start_tok = nullptr;
  gc_ref<RubyObject> iv_interpolate = nullptr;
  gc_ref<RubyObject> iv_start_delim = nullptr;
  gc_ref<RubyObject> iv_end_delim = nullptr;
  gc_ref<RubyObject> iv_indent = nullptr;
  gc_ref<RubyObject> iv_label_allowed = nullptr;
  gc_ref<RubyObject> iv_dedent_body = nullptr;
  gc_ref<RubyObject> iv_interp_braces = nullptr;
  gc_ref<RubyObject> iv_space_emitted = nullptr;
  gc_ref<RubyObject> iv_monolithic = nullptr;
  gc_ref<RubyObject> iv_buffer = nullptr;
  gc_ref<RubyObject> iv_buffer_s = nullptr;
  gc_ref<RubyObject> iv_buffer_e = nullptr;

  Ruby_Literal() = default;
  Ruby_Literal(auto lexer, auto str_type, auto delimiter, auto str_s, auto heredoc_e = RUBY_NIL, bool indent = false, bool dedent_body = false, bool label_allowed = false) {
    iv_lexer = lexer;
    iv_nesting = INT64_C(1);
    (str_type = coerce_encoding(str_type));
    (delimiter = coerce_encoding(delimiter));
    (TYPES.include_q(str_type) ? (RUBY_NIL) : (lexer.send(ruby_sym("diagnostic"), ruby_sym("error"), ruby_sym("unexpected_percent_str"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("type"), str_type); _h; }), iv_lexer->send(ruby_sym("range"), str_s, (str_s + INT64_C(2))))));
    iv_str_type = str_type;
    iv_str_s = str_s;
    auto _masgn21 = TYPES[str_type];
    iv_start_tok = _masgn21[INT64_C(0)];
    iv_interpolate = _masgn21[INT64_C(1)];
    iv_start_delim = (DELIMITERS.include_q(delimiter) ? (delimiter) : (RUBY_NIL));
    iv_end_delim = DELIMITERS.fetch(delimiter, delimiter);
    iv_heredoc_e = heredoc_e;
    iv_indent = indent;
    iv_label_allowed = label_allowed;
    iv_dedent_body = dedent_body;
    iv_dedent_level = RUBY_NIL;
    iv_interp_braces = INT64_C(0);
    iv_space_emitted = true;
    iv_monolithic = ({ auto _l = (({ auto _l = ((iv_start_tok == ruby_sym("tSTRING_BEG"))); (_l) ? decltype((({ auto _e0 = RubyString("'", 1); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("\"", 1); _a; }).include_q(str_type)))(({ auto _e0 = RubyString("'", 1); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("\"", 1); _a; }).include_q(str_type)) : decltype((({ auto _e0 = RubyString("'", 1); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyString("\"", 1); _a; }).include_q(str_type)))(_l); })); (_l) ? decltype(((!(heredoc_q()))))((!(heredoc_q()))) : decltype(((!(heredoc_q()))))(_l); });
    if (iv_str_type->start_with_q(RubyString("%", 1))) {
      iv_str_type = (iv_str_type + delimiter);
    }
    clear_buffer();
    (iv_monolithic ? (RUBY_NIL) : (emit_start_tok()));
  }
  const char* rb_class_name() const override { return "Literal"; }

  RubyObject* heredoc_e() {
    std::fprintf(stderr, "frozone: called TI-gap stub heredoc_e\n"); std::abort();
    return nullptr;
  }

  RubyObject* str_s() {
    std::fprintf(stderr, "frozone: called TI-gap stub str_s\n"); std::abort();
    return nullptr;
  }

  RubyObject* dedent_level() {
    std::fprintf(stderr, "frozone: called TI-gap stub dedent_level\n"); std::abort();
    return nullptr;
  }

  RubyObject* saved_herebody_s() {
    std::fprintf(stderr, "frozone: called TI-gap stub saved_herebody_s\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_saved_herebody_s(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_saved_herebody_s\n"); std::abort();
    return nullptr;
  }

  RubyObject* interpolate_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub interpolate_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* words_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub words_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* regexp_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub regexp_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* heredoc_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub heredoc_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* plain_heredoc_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub plain_heredoc_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* squiggly_heredoc_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub squiggly_heredoc_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* backslash_delimited_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub backslash_delimited_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* type() {
    std::fprintf(stderr, "frozone: called TI-gap stub type\n"); std::abort();
    return nullptr;
  }

  bool munge_escape_q(auto character) {
    (character = coerce_encoding(character));
    if (({ auto _l = (words_q()); (_l) ? decltype((character.=~(/* UNSUPPORTED: RegexpLiteral */)))(character.=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((character.=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      return true;
    } else {
      return ({ auto _e0 = RubyString("\\", 1); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = iv_start_delim; _a[2] = iv_end_delim; _a; }).include_q(character);
    }
  }

  RubyNil nest_and_try_closing(auto delimiter, auto ts, auto te, auto lookahead = RUBY_NIL) {
    (delimiter = coerce_encoding(delimiter));
    if (({ auto _l = (iv_start_delim); (_l) ? decltype(((iv_start_delim == delimiter)))((iv_start_delim == delimiter)) : decltype(((iv_start_delim == delimiter)))(_l); })) {
      iv_nesting = (iv_nesting + INT64_C(1));
    } else {
      if (delimiter_q(delimiter)) {
      iv_nesting = (iv_nesting - INT64_C(1));
    };
    }
    if ((iv_nesting == INT64_C(0))) {
      return if (words_q()) {
        extend_space(ts, ts);
      }; if (({ auto _l = (({ auto _l = (({ auto _l = (({ auto _l = (lookahead); (_l) ? decltype((iv_label_allowed))(iv_label_allowed) : decltype((iv_label_allowed))(_l); })); (_l) ? decltype(((lookahead[INT64_C(0)] == RubyString(":", 1))))((lookahead[INT64_C(0)] == RubyString(":", 1))) : decltype(((lookahead[INT64_C(0)] == RubyString(":", 1))))(_l); })); (_l) ? decltype(((lookahead[INT64_C(1)] != RubyString(":", 1))))((lookahead[INT64_C(1)] != RubyString(":", 1))) : decltype(((lookahead[INT64_C(1)] != RubyString(":", 1))))(_l); })); (_l) ? decltype(((iv_start_tok == ruby_sym("tSTRING_BEG"))))((iv_start_tok == ruby_sym("tSTRING_BEG"))) : decltype(((iv_start_tok == ruby_sym("tSTRING_BEG"))))(_l); })) {
        flush_string();
        emit(ruby_sym("tLABEL_END"), iv_end_delim, ts, (te + INT64_C(1)));
      } else {
        if (iv_monolithic) {
        emit(ruby_sym("tSTRING"), iv_buffer, iv_str_s, te);
      } else {
        (heredoc_q() ? (RUBY_NIL) : (flush_string()));
        emit(ruby_sym("tSTRING_END"), iv_end_delim, ts, te);
      };
      };
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* infer_indent_level(auto line) {
    std::fprintf(stderr, "frozone: called TI-gap stub infer_indent_level\n"); std::abort();
    return nullptr;
  }

  RubyObject* start_interp_brace() {
    std::fprintf(stderr, "frozone: called TI-gap stub start_interp_brace\n"); std::abort();
    return nullptr;
  }

  RubyObject* end_interp_brace_and_try_closing() {
    std::fprintf(stderr, "frozone: called TI-gap stub end_interp_brace_and_try_closing\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_string(auto string, auto ts, auto te) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string\n"); std::abort();
    return nullptr;
  }

  bool flush_string() {
    if (iv_monolithic) {
      emit_start_tok();
      iv_monolithic = false;
    }
    if (iv_buffer->empty_q()) {
      return bool(RUBY_NIL);
    } else {
      return emit(ruby_sym("tSTRING_CONTENT"), iv_buffer, iv_buffer_s, iv_buffer_e); clear_buffer(); extend_content();
    }
  }

  bool extend_content() {
    return iv_space_emitted = false;
  }

  bool extend_space(auto ts, auto te) {
    flush_string();
    if (iv_space_emitted) {
      return bool(RUBY_NIL);
    } else {
      return emit(ruby_sym("tSPACE"), RUBY_NIL, ts, te); iv_space_emitted = true;
    }
  }

  RubyObject* supports_line_continuation_via_slash_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub supports_line_continuation_via_slash_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* delimiter_q(auto delimiter) {
    std::fprintf(stderr, "frozone: called TI-gap stub delimiter_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* coerce_encoding(auto string) {
    std::fprintf(stderr, "frozone: called TI-gap stub coerce_encoding\n"); std::abort();
    return nullptr;
  }

  RubyNil clear_buffer() {
    iv_buffer = RubyString("", 0).dup_();
    iv_buffer->force_encoding(iv_lexer->source_buffer().source().encoding());
    iv_buffer_s = RUBY_NIL;
    return iv_buffer_e = RUBY_NIL;
  }

  RubyObject* emit_start_tok() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_start_tok\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit(auto token, auto type, auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Literal>() { return "Literal"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Literal> : dustman::FieldList<Ruby_Literal> {};
#endif

struct Ruby_StackState : public RubyObject {
  RubyString iv_name;
  int64_t iv_stack = 0;

  Ruby_StackState() = default;
  Ruby_StackState(auto name) {
    iv_name = name;
    clear();
  }
  const char* rb_class_name() const override { return "StackState"; }

  int64_t clear() {
    return iv_stack = INT64_C(0);
  }

  gc_ref<RubyObject> push(gc_ref<RubyObject> bit) {
    int64_t bit_value = 0;
    (bit_value = (bit ? (INT64_C(1)) : (INT64_C(0))));
    iv_stack = ((iv_stack << INT64_C(1)) | bit_value);
    return coerce_to_ref<RubyObject>(bit);
  }

  RubyObject* pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* lexpop() {
    std::fprintf(stderr, "frozone: called TI-gap stub lexpop\n"); std::abort();
    return nullptr;
  }

  RubyObject* active_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub active_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* to_s() {
    std::fprintf(stderr, "frozone: called TI-gap stub to_s\n"); std::abort();
    return nullptr;
  }

  RubyObject* inspect() {
    std::fprintf(stderr, "frozone: called TI-gap stub inspect\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_StackState>() { return "StackState"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_StackState> : dustman::FieldList<Ruby_StackState> {};
#endif

struct Ruby_Dedenter : public RubyObject {
  inline static const int64_t TAB_WIDTH = 8LL;
  gc_ref<RubyObject> iv_dedent_level = nullptr;
  gc_ref<RubyObject> iv_at_line_begin = nullptr;
  gc_ref<RubyObject> iv_indent_level = nullptr;

  Ruby_Dedenter() = default;
  Ruby_Dedenter(auto dedent_level) {
    iv_dedent_level = dedent_level;
    iv_at_line_begin = true;
    iv_indent_level = INT64_C(0);
  }
  const char* rb_class_name() const override { return "Dedenter"; }

  RubyObject* dedent(auto string) {
    std::fprintf(stderr, "frozone: called TI-gap stub dedent\n"); std::abort();
    return nullptr;
  }

  bool interrupt() {
    return iv_at_line_begin = false;
  }

};
template<> inline const char* ruby_class_name<Ruby_Dedenter>() { return "Dedenter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Dedenter> : dustman::FieldList<Ruby_Dedenter> {};
#endif

struct Ruby_Lexer : public RubyObject {
  RubyNil iv_source_buffer;
  gc_ref<RubyObject> iv_diagnostics = nullptr;
  gc_ref<Ruby_StaticEnvironment> iv_static_env;
  bool iv_force_utf32 = false;
  gc_ref<Ruby_StackState> iv_cond;
  gc_ref<Ruby_StackState> iv_cmdarg;
  gc_ref<Ruby_Context> iv_context;
  gc_ref<RubyObject> iv_command_start;
  RubyArray<int64_t> iv_tokens;
  RubyArray<int64_t> iv_comments;
  int64_t iv_paren_nest = 0;
  gc_ref<RubyObject> iv_cmdarg_stack = nullptr;
  gc_ref<RubyObject> iv_cond_stack = nullptr;
  RubyArray<int64_t> iv_lambda_stack;
  int64_t iv_version = 0;
  RubyArray<int64_t> iv__lex_actions;
  gc_ref<RubyObject> iv_emit_integer = nullptr;
  gc_ref<RubyObject> iv_emit_rational = nullptr;
  gc_ref<RubyObject> iv_emit_imaginary = nullptr;
  gc_ref<RubyObject> iv_emit_imaginary_rational = nullptr;
  gc_ref<RubyObject> iv_emit_integer_re = nullptr;
  RubyNil iv_ts;
  RubyNil iv_te;
  gc_ref<RubyObject> iv_emit_integer_if = nullptr;
  gc_ref<RubyObject> iv_emit_integer_rescue = nullptr;
  gc_ref<RubyObject> iv_emit_float = nullptr;
  gc_ref<RubyObject> iv_emit_imaginary_float = nullptr;
  gc_ref<RubyObject> iv_emit_float_if = nullptr;
  gc_ref<RubyObject> iv_emit_float_rescue = nullptr;
  gc_ref<RubyObject> iv_cs = nullptr;
  RubyNil iv_source_pts;
  int64_t iv_p = 0;
  int64_t iv_act = 0;
  RubyArray<int64_t> iv_stack;
  int64_t iv_top = 0;
  RubyArray<int64_t> iv_token_queue;
  RubyNil iv_eq_begin_s;
  RubyNil iv_sharp_s;
  RubyNil iv_newline_s;
  RubyNil iv_num_base;
  RubyNil iv_num_digits_s;
  RubyNil iv_num_suffix_s;
  RubyNil iv_num_xfrm;
  gc_ref<RubyObject> iv_cs_before_block_comment = nullptr;
  gc_ref<RubyObject> iv_strings = nullptr;

  Ruby_Lexer() = default;
  Ruby_Lexer(auto version) {
    iv_version = version;
    iv_static_env = nullptr;
    iv_context = nullptr;
    iv_tokens = RUBY_NIL;
    iv_comments = RUBY_NIL;
    iv__lex_actions = (rb_class().respond_to_q(ruby_sym("_lex_actions"), true) ? (rb_class().send(ruby_sym("_lex_actions"))) : (RubyArray_I64(0)));
    iv_emit_integer = [&](auto chars, auto p) { return emit(ruby_sym("tINTEGER"), chars); p; };
    iv_emit_rational = [&](auto chars, auto p) { return emit(ruby_sym("tRATIONAL"), Rational(chars)); p; };
    iv_emit_imaginary = [&](auto chars, auto p) { return emit(ruby_sym("tIMAGINARY"), Complex(INT64_C(0), chars)); p; };
    iv_emit_imaginary_rational = [&](auto chars, auto p) { return emit(ruby_sym("tIMAGINARY"), Complex(INT64_C(0), Rational(chars))); p; };
    iv_emit_integer_re = [&](auto chars, auto p) { return emit(ruby_sym("tINTEGER"), chars, iv_ts, (iv_te - INT64_C(2))); (p - INT64_C(2)); };
    iv_emit_integer_if = [&](auto chars, auto p) { return emit(ruby_sym("tINTEGER"), chars, iv_ts, (iv_te - INT64_C(2))); (p - INT64_C(2)); };
    iv_emit_integer_rescue = [&](auto chars, auto p) { return emit(ruby_sym("tINTEGER"), chars, iv_ts, (iv_te - INT64_C(6))); (p - INT64_C(6)); };
    iv_emit_float = [&](auto chars, auto p) { return emit(ruby_sym("tFLOAT"), construct_float(chars)); p; };
    iv_emit_imaginary_float = [&](auto chars, auto p) { return emit(ruby_sym("tIMAGINARY"), Complex(INT64_C(0), construct_float(chars))); p; };
    iv_emit_float_if = [&](auto chars, auto p) { return emit(ruby_sym("tFLOAT"), construct_float(chars), iv_ts, (iv_te - INT64_C(2))); (p - INT64_C(2)); };
    iv_emit_float_rescue = [&](auto chars, auto p) { return emit(ruby_sym("tFLOAT"), construct_float(chars), iv_ts, (iv_te - INT64_C(6))); (p - INT64_C(6)); };
    reset();
  }
  const char* rb_class_name() const override { return "Lexer"; }

  RubyNil source_buffer() {
    return iv_source_buffer;
  }

  RubyObject* diagnostics() {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostics\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_diagnostics(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_diagnostics\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_StaticEnvironment> static_env() {
    return iv_static_env;
  }

  gc_ref<Ruby_StaticEnvironment> set_static_env(gc_ref<Ruby_StaticEnvironment> __anon_req__) {
    iv_static_env = __anon_req__;
    return iv_static_env;
  }

  bool force_utf32() {
    return iv_force_utf32;
  }

  bool set_force_utf32(auto __anon_req__) {
    iv_force_utf32 = __anon_req__;
    return iv_force_utf32;
  }

  gc_ref<Ruby_StackState> cond() {
    return iv_cond;
  }

  gc_ref<Ruby_StackState> set_cond(gc_ref<Ruby_StackState> __anon_req__) {
    iv_cond = __anon_req__;
    return iv_cond;
  }

  gc_ref<Ruby_StackState> cmdarg() {
    return iv_cmdarg;
  }

  gc_ref<Ruby_StackState> set_cmdarg(gc_ref<Ruby_StackState> __anon_req__) {
    iv_cmdarg = __anon_req__;
    return iv_cmdarg;
  }

  gc_ref<Ruby_Context> context() {
    return iv_context;
  }

  gc_ref<Ruby_Context> set_context(gc_ref<Ruby_Context> __anon_req__) {
    iv_context = __anon_req__;
    return iv_context;
  }

  gc_ref<RubyObject> command_start() {
    return iv_command_start;
  }

  gc_ref<RubyObject> set_command_start(gc_ref<RubyObject> __anon_req__) {
    iv_command_start = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_command_start;
  }

  RubyArray<int64_t> tokens() {
    return iv_tokens;
  }

  RubyArray<int64_t> set_tokens(auto __anon_req__) {
    iv_tokens = __anon_req__;
    return iv_tokens;
  }

  RubyArray<int64_t> comments() {
    return iv_comments;
  }

  RubyArray<int64_t> set_comments(auto __anon_req__) {
    iv_comments = __anon_req__;
    return iv_comments;
  }

  int64_t paren_nest() {
    return iv_paren_nest;
  }

  RubyObject* cmdarg_stack() {
    std::fprintf(stderr, "frozone: called TI-gap stub cmdarg_stack\n"); std::abort();
    return nullptr;
  }

  RubyObject* cond_stack() {
    std::fprintf(stderr, "frozone: called TI-gap stub cond_stack\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> lambda_stack() {
    return iv_lambda_stack;
  }

  int64_t version() {
    return iv_version;
  }

  RubyObject* construct_float(auto chars) {
    std::fprintf(stderr, "frozone: called TI-gap stub construct_float\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_LexerStrings> reset(bool reset_state = true) {
    if (reset_state) {
      iv_cs = rb_class().lex_en_line_begin();
      iv_cond = gc_new<Ruby_StackState>(RubyString("cond", 4));
      iv_cmdarg = gc_new<Ruby_StackState>(RubyString("cmdarg", 6));
      iv_cond_stack = RubyArray_I64(0);
      iv_cmdarg_stack = RubyArray_I64(0);
    }
    iv_force_utf32 = false;
    iv_source_pts = RUBY_NIL;
    iv_p = INT64_C(0);
    iv_ts = RUBY_NIL;
    iv_te = RUBY_NIL;
    iv_act = INT64_C(0);
    iv_stack = RubyArray_I64(0);
    iv_top = INT64_C(0);
    iv_token_queue = RubyArray_I64(0);
    iv_eq_begin_s = RUBY_NIL;
    iv_sharp_s = RUBY_NIL;
    iv_newline_s = RUBY_NIL;
    iv_num_base = RUBY_NIL;
    iv_num_digits_s = RUBY_NIL;
    iv_num_suffix_s = RUBY_NIL;
    iv_num_xfrm = RUBY_NIL;
    iv_paren_nest = INT64_C(0);
    iv_lambda_stack = RubyArray_I64(0);
    iv_command_start = coerce_to_ref<RubyObject>(true);
    iv_cs_before_block_comment = rb_class().lex_en_line_begin();
    return iv_strings = gc_new<Ruby_LexerStrings>((*this), iv_version);
  }

  RubyNil set_source_buffer(auto source_buffer) {
    std::decay_t<decltype(iv_source_buffer->source())> source{};
    iv_source_buffer = source_buffer;
    if (iv_source_buffer) {
      (source = iv_source_buffer->source());
      ((source.encoding() == INT64_C(0) /* ::UTF_8 */) ? (iv_source_pts = source.unpack(RubyString("U*", 2))) : (iv_source_pts = source.unpack(RubyString("C*", 2))));
      if ((iv_source_pts[INT64_C(0)] == INT64_C(65279))) {
      iv_p = INT64_C(1);
    };
    } else {
      iv_source_pts = RUBY_NIL;
    }
    iv_strings->set_source_buffer(iv_source_buffer);
    return iv_strings->set_source_pts(iv_source_pts);
  }

  RubyObject* encoding() {
    std::fprintf(stderr, "frozone: called TI-gap stub encoding\n"); std::abort();
    return nullptr;
  }

  RubyObject* state() {
    std::fprintf(stderr, "frozone: called TI-gap stub state\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_state(auto state) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_state\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_StackState> push_cmdarg() {
    iv_cmdarg_stack->push(iv_cmdarg);
    return iv_cmdarg = gc_new<Ruby_StackState>((RubyString("cmdarg.", 7) + ruby_to_s(iv_cmdarg_stack->count())));
  }

  RubyObject* pop_cmdarg() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop_cmdarg\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_StackState> push_cond() {
    iv_cond_stack->push(iv_cond);
    return iv_cond = gc_new<Ruby_StackState>((RubyString("cond.", 5) + ruby_to_s(iv_cond_stack->count())));
  }

  RubyObject* pop_cond() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop_cond\n"); std::abort();
    return nullptr;
  }

  RubyObject* dedent_level() {
    std::fprintf(stderr, "frozone: called TI-gap stub dedent_level\n"); std::abort();
    return nullptr;
  }

  RubyArray<gc_ref<RubyObject>> advance() {
    std::decay_t<decltype(rb_class())> klass{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_keys")))> _lex_trans_keys{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_key_spans")))> _lex_key_spans{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_index_offsets")))> _lex_index_offsets{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_indicies")))> _lex_indicies{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_targs")))> _lex_trans_targs{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_actions")))> _lex_trans_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_to_state_actions")))> _lex_to_state_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_from_state_actions")))> _lex_from_state_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_eof_trans")))> _lex_eof_trans{};
    RubyArray<int64_t> _lex_actions;
    std::decay_t<decltype((iv_source_pts.len() + INT64_C(2)))> pe{};
    int64_t p = 0;
    std::decay_t<decltype(pe)> eof{};
    gc_local<RubyObject> cmd_state = nullptr;
    bool testEof = false;
    int64_t _goto_level = 0;
    int64_t _resume = 0;
    int64_t _eof_trans = 0;
    int64_t _again = 0;
    int64_t _test_eof = 0;
    int64_t _out = 0;
    int64_t _wide = 0;
    int64_t tm = 0;
    int64_t heredoc_e = 0;
    RubySymbol diag_msg;
    std::decay_t<decltype(tok())> ident_tok{};
    RubyNil ident_ts;
    RubyNil ident_te;
    RubyString type;
    std::decay_t<decltype(tok()[INT64_C(-1)].chr())> delimiter{};
    std::decay_t<decltype(tok((iv_ts + INT64_C(1))))> gvar_name{};
    std::decay_t<decltype(tok(iv_ts, (iv_te - INT64_C(2))))> ident{};
    std::decay_t<decltype(((iv_te - INT64_C(1)) == iv_newline_s))> followed_by_nl{};
    gc_local<RubyObject> nl_emitted = nullptr;
    RubyNil dots_te;
    RubyString digits;
    int64_t new_herebody_s = 0;
    std::decay_t<decltype((!(/* UNSUPPORTED: GlobalVariableRead */.empty_q())))> dedent_body{};
    if (!(iv_token_queue.empty_q())) {
      return iv_token_queue.shift();
    }
    (klass = rb_class());
    (_lex_trans_keys = klass.send(ruby_sym("_lex_trans_keys")));
    (_lex_key_spans = klass.send(ruby_sym("_lex_key_spans")));
    (_lex_index_offsets = klass.send(ruby_sym("_lex_index_offsets")));
    (_lex_indicies = klass.send(ruby_sym("_lex_indicies")));
    (_lex_trans_targs = klass.send(ruby_sym("_lex_trans_targs")));
    (_lex_trans_actions = klass.send(ruby_sym("_lex_trans_actions")));
    (_lex_to_state_actions = klass.send(ruby_sym("_lex_to_state_actions")));
    (_lex_from_state_actions = klass.send(ruby_sym("_lex_from_state_actions")));
    (_lex_eof_trans = klass.send(ruby_sym("_lex_eof_trans")));
    (_lex_actions = iv__lex_actions);
    (pe = (iv_source_pts.len() + INT64_C(2)));
    auto _t22_0 = iv_p;
    auto _t22_1 = pe;
    p = _t22_0;
    eof = _t22_1;
    (cmd_state = iv_command_start);
    iv_command_start = coerce_to_ref<RubyObject>(false);
          (testEof = false);
      auto _masgn23 = RUBY_NIL;
      auto _slen = _masgn23[INT64_C(0)];
      auto _trans = _masgn23[INT64_C(1)];
      auto _keys = _masgn23[INT64_C(2)];
      auto _inds = _masgn23[INT64_C(3)];
      auto _acts = _masgn23[INT64_C(4)];
      auto _nacts = _masgn23[INT64_C(5)];
      (_goto_level = INT64_C(0));
      (_resume = INT64_C(10));
      (_eof_trans = INT64_C(15));
      (_again = INT64_C(20));
      (_test_eof = INT64_C(30));
      (_out = INT64_C(40));
      while (true) {
      if ((_goto_level <= INT64_C(0))) {
      if ((p == pe)) {
      (_goto_level = _test_eof);
      continue;
    };
      if ((iv_cs == INT64_C(0))) {
      (_goto_level = _out);
      continue;
    };
    };
      if ((_goto_level <= _resume)) {
      ({ auto _cs = _lex_from_state_actions[iv_cs]; ((_cs == INT64_C(85))) ? (      iv_ts = p;) : (RUBY_NIL); });
      (_keys = (iv_cs << INT64_C(1)));
      (_inds = _lex_index_offsets[iv_cs]);
      (_slen = _lex_key_spans[iv_cs]);
      (_wide = ({ auto _l = (iv_source_pts[p]); (_l) ? decltype((INT64_C(0)))(_l) : (INT64_C(0)); }));
      (_trans = (({ auto _l = (({ auto _l = ((_slen > INT64_C(0))); (_l) ? decltype(((_lex_trans_keys[_keys] <= _wide)))((_lex_trans_keys[_keys] <= _wide)) : decltype(((_lex_trans_keys[_keys] <= _wide)))(_l); })); (_l) ? decltype(((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])))((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])) : decltype(((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])))(_l); }) ? (_lex_indicies[((_inds + _wide) - _lex_trans_keys[_keys])]) : (_lex_indicies[(_inds + _slen)])));
    };
      if ((_goto_level <= _eof_trans)) {
      iv_cs = _lex_trans_targs[_trans];
      if ((_lex_trans_actions[_trans] != INT64_C(0))) {
      ({ auto _cs = _lex_trans_actions[_trans]; ((_cs == INT64_C(14))) ? (      iv_newline_s = p;) : (((_cs == INT64_C(15))) ? (      (p = on_newline(p));) : (((_cs == INT64_C(45))) ? (      iv_sharp_s = (p - INT64_C(1));) : (((_cs == INT64_C(49))) ? (      emit_comment_from_range(p, pe);) : (((_cs == INT64_C(190))) ? (      (tm = p);) : (((_cs == INT64_C(22))) ? (      (tm = p);) : (((_cs == INT64_C(24))) ? (      (tm = p);) : (((_cs == INT64_C(26))) ? (      (tm = p);) : (((_cs == INT64_C(56))) ? (      (heredoc_e = p);) : (((_cs == INT64_C(229))) ? (      (tm = (p - INT64_C(1)));
      (diag_msg = ruby_sym("ivar_name"));) : (((_cs == INT64_C(232))) ? (      (tm = (p - INT64_C(2)));
      (diag_msg = ruby_sym("cvar_name"));) : (((_cs == INT64_C(244))) ? (      (tm = p);) : (((_cs == INT64_C(188))) ? (      (ident_tok = tok());
      (ident_ts = iv_ts);
      (ident_te = iv_te);) : (((_cs == INT64_C(331))) ? (      iv_num_base = INT64_C(16);
      iv_num_digits_s = p;) : (((_cs == INT64_C(325))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = p;) : (((_cs == INT64_C(328))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = p;) : (((_cs == INT64_C(322))) ? (      iv_num_base = INT64_C(2);
      iv_num_digits_s = p;) : (((_cs == INT64_C(337))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;) : (((_cs == INT64_C(299))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = iv_ts;) : (((_cs == INT64_C(314))) ? (      iv_num_suffix_s = p;) : (((_cs == INT64_C(307))) ? (      iv_num_suffix_s = p;) : (((_cs == INT64_C(304))) ? (      iv_num_suffix_s = p;) : (((_cs == INT64_C(74))) ? (      (tm = p);) : (((_cs == INT64_C(65))) ? (      iv_te = (p + INT64_C(1));) : (((_cs == INT64_C(1))) ? (      iv_te = (p + INT64_C(1));
            emit_global_var();
      iv_cs = stack_pop();
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(87))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_global_var();
      iv_cs = stack_pop();
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(89))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_class_var();
      iv_cs = stack_pop();
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(88))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_instance_var();
      iv_cs = stack_pop();
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(110))) ? (      iv_te = (p + INT64_C(1));
            emit_table(KEYWORDS_BEGIN);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(96))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tIDENTIFIER"));
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(3))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
      iv_cs = INT64_C(516);
            iv_stack[iv_top] = iv_cs;
      iv_top = (iv_top + INT64_C(1));
      iv_cs = INT64_C(129);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(93))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(105))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(5))) ? (      iv_te = (p + INT64_C(1));
            if (version_q(INT64_C(23))) {
      auto _t24_0 = tok()[(INT64_C(-2) + 1LL)];
      auto _t24_1 = tok()[INT64_C(-1)].chr();
      type = _t24_0;
      delimiter = _t24_1;
      iv_strings->push_literal(type, delimiter, iv_ts);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;
    } else {
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;
    };;) : (((_cs == INT64_C(92))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(91))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(109))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(KEYWORDS_BEGIN);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(106))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tCONSTANT"));
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(108))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tIDENTIFIER"));
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(103))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
      iv_cs = INT64_C(516);
            iv_stack[iv_top] = iv_cs;
      iv_top = (iv_top + INT64_C(1));
      iv_cs = INT64_C(129);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(99))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(104))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(97))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(102))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(4))) ? (            (p = (iv_te - INT64_C(1)));;
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(2))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(95))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(4))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS_BEGIN);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(5))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tCONSTANT"));
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(6))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tIDENTIFIER"));
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (RUBY_NIL))); });) : (((_cs == INT64_C(7))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tLABEL"), tok(iv_ts, (iv_te - INT64_C(2))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(501);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(8))) ? (      iv_te = (p + INT64_C(1));
            if (({ auto _l = ((iv_version >= INT64_C(31))); (_l) ? decltype((iv_context->in_argdef()))(iv_context->in_argdef()) : decltype((iv_context->in_argdef()))(_l); })) {
      emit(ruby_sym("tBDOT3"), RubyString("...", 3));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      (p = (p - INT64_C(3)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;
    };;) : (((_cs == INT64_C(112))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(111))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(114))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(113))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(6))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(120))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(119))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(118))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(130))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tCONSTANT"));
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(121))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tIDENTIFIER"));
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(126))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(124))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(129))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(153))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(136))) ? (      iv_te = (p + INT64_C(1));
            check_ambiguous_slash(tm);
      (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(142))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(10))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(144))) ? (      iv_te = (p + INT64_C(1));
            (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(25))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(131))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(132))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(143))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(139))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_prefix"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("prefix"), tok(tm, iv_te)); _h; }), range(tm, iv_te));
      (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(141))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(135))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(134))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(152))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(11))) ? (            (p = (iv_te - INT64_C(1)));;) : (((_cs == INT64_C(27))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(9))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(33))) ? (            (p = (iv_te - INT64_C(1)));;
      check_ambiguous_slash(tm);
      (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;) : (((_cs == INT64_C(34))) ? (            (p = (iv_te - INT64_C(1)));;
      diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_prefix"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("prefix"), tok(tm, iv_te)); _h; }), range(tm, iv_te));
      (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;) : (((_cs == INT64_C(39))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;) : (            (p = (iv_te - INT64_C(1)));;))); });) : (((_cs == INT64_C(29))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(276);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(157))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(158))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(276);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(30))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(276);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(28))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(46))) ? (            (p = (iv_te - INT64_C(1)));;
      (iv_cond->active_q() ? (emit(ruby_sym("kDO_COND"), RubyString("do", 2), (iv_te - INT64_C(2)), iv_te)) : (emit(ruby_sym("kDO"), RubyString("do", 2), (iv_te - INT64_C(2)), iv_te)));
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(47))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(276);
      (_goto_level = _again);
      continue;;) : (RUBY_NIL)); });) : (((_cs == INT64_C(168))) ? (      iv_te = (p + INT64_C(1));
            emit_do(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(161))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(162))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(163))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(166))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(172))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(171))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(180))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(174))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(178))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(173))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(54))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(55))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;) : (RUBY_NIL)); });) : (((_cs == INT64_C(42))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tUNARY_NUM"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(214))) ? (      iv_te = (p + INT64_C(1));
            (type = (delimiter = tok()[INT64_C(0)].chr()));
      iv_strings->push_literal(type, delimiter, iv_ts);
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(206))) ? (      iv_te = (p + INT64_C(1));
            auto _t25_0 = iv_source_buffer->slice(iv_ts, INT64_C(1)).chr();
      auto _t25_1 = tok()[INT64_C(-1)].chr();
      type = _t25_0;
      delimiter = _t25_1;
      iv_strings->push_literal(type, delimiter, iv_ts);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(40))) ? (      iv_te = (p + INT64_C(1));
            auto _t26_0 = tok()[(INT64_C(-2) + 1LL)];
      auto _t26_1 = tok()[INT64_C(-1)].chr();
      type = _t26_0;
      delimiter = _t26_1;
      iv_strings->push_literal(type, delimiter, iv_ts);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(227))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
      (p = (p - INT64_C(1)));
      emit(ruby_sym("tSYMBEG"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
            iv_cs = INT64_C(134);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(215))) ? (      iv_te = (p + INT64_C(1));
            auto _t27_0 = tok();
      auto _t27_1 = tok()[INT64_C(-1)].chr();
      type = _t27_0;
      delimiter = _t27_1;
      iv_strings->push_literal(type, delimiter, iv_ts);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(226))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), (iv_ts + INT64_C(2))));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(54))) ? (      iv_te = (p + INT64_C(1));
            (gvar_name = tok((iv_ts + INT64_C(1))));
      if (({ auto _l = (({ auto _l = ((iv_version >= INT64_C(33))); (_l) ? decltype((gvar_name.start_with_q(RubyString("$0", 2))))(gvar_name.start_with_q(RubyString("$0", 2))) : decltype((gvar_name.start_with_q(RubyString("$0", 2))))(_l); })); (_l) ? decltype(((gvar_name.len() > INT64_C(2))))((gvar_name.len() > INT64_C(2))) : decltype(((gvar_name.len() > INT64_C(2))))(_l); })) {
      diagnostic(ruby_sym("error"), ruby_sym("gvar_name"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), gvar_name); _h; }), range((iv_ts + INT64_C(1)), iv_te));
    };
      emit(ruby_sym("tSYMBOL"), gvar_name, iv_ts);
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(236))) ? (      iv_te = (p + INT64_C(1));
            auto _masgn28 = iv_strings->read_character_constant(iv_ts);
      p = _masgn28[INT64_C(0)];
      auto next_state = _masgn28[INT64_C(1)];
      (p = (p - INT64_C(1)));
      if (iv_token_queue.empty_q()) {
            iv_cs = next_state;
      (_goto_level = _again);
      continue;;
    } else {
      iv_cs = next_state;
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(237))) ? (      iv_te = (p + INT64_C(1));
            diagnostic(ruby_sym("fatal"), ruby_sym("incomplete_escape"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(216))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION_BEGIN);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(37))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
      if (version_q(INT64_C(18))) {
      (ident = tok(iv_ts, (iv_te - INT64_C(2))));
      emit((iv_source_buffer->slice(iv_ts, INT64_C(1)).=~(/* UNSUPPORTED: RegexpLiteral */) ? (ruby_sym("tCONSTANT")) : (ruby_sym("tIDENTIFIER"))), ident, iv_ts, (iv_te - INT64_C(2)));
      (p = (p - INT64_C(1)));
      (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(ident)))(iv_static_env->declared_q(ident)) : decltype((iv_static_env->declared_q(ident)))(_l); }) ? (iv_cs = INT64_C(516)) : (iv_cs = arg_or_cmdarg(cmd_state)));
    } else {
      emit(ruby_sym("tLABEL"), tok(iv_ts, (iv_te - INT64_C(2))), iv_ts, (iv_te - INT64_C(1)));
      iv_cs = INT64_C(501);
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(34))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tIDENTIFIER"), ident_tok, ident_ts, ident_te);
      (p = (ident_te - INT64_C(1)));
      (({ auto _l = (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(ident_tok)))(iv_static_env->declared_q(ident_tok)) : decltype((iv_static_env->declared_q(ident_tok)))(_l); })); (_l) ? decltype(((iv_version < INT64_C(25))))((iv_version < INT64_C(25))) : decltype(((iv_version < INT64_C(25))))(_l); }) ? (iv_cs = INT64_C(247)) : (iv_cs = INT64_C(307)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(200))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
      iv_cs_before_block_comment = iv_cs;
            iv_cs = INT64_C(710);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(41))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(183))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(210))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tUNARY_NUM"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(209))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSTAR"), RubyString("*", 1));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(205))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("fatal"), ruby_sym("string_eof"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(234))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("error"), ruby_sym("unterminated_heredoc_id"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(217))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (gvar_name = tok((iv_ts + INT64_C(1))));
      if (({ auto _l = (({ auto _l = ((iv_version >= INT64_C(33))); (_l) ? decltype((gvar_name.start_with_q(RubyString("$0", 2))))(gvar_name.start_with_q(RubyString("$0", 2))) : decltype((gvar_name.start_with_q(RubyString("$0", 2))))(_l); })); (_l) ? decltype(((gvar_name.len() > INT64_C(2))))((gvar_name.len() > INT64_C(2))) : decltype(((gvar_name.len() > INT64_C(2))))(_l); })) {
      diagnostic(ruby_sym("error"), ruby_sym("gvar_name"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), gvar_name); _h; }), range((iv_ts + INT64_C(1)), iv_te));
    };
      emit(ruby_sym("tSYMBOL"), gvar_name, iv_ts);
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(230))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_colon_with_digits(p, tm, diag_msg);
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(235))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("fatal"), ruby_sym("incomplete_escape"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(207))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION_BEGIN);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(211))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            ((iv_version >= INT64_C(27)) ? (emit(ruby_sym("tBDOT2"))) : (emit(ruby_sym("tDOT2"))));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(212))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (followed_by_nl = ((iv_te - INT64_C(1)) == iv_newline_s));
      (nl_emitted = false);
      (dots_te = (followed_by_nl ? ((iv_te - INT64_C(1))) : (iv_te)));
      if ((iv_version >= INT64_C(30))) {
      if (({ auto _l = (iv_lambda_stack.any_q()); (_l) ? decltype((((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)))(((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)) : decltype((((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)))(_l); })) {
      emit(ruby_sym("tDOT3"), RubyString("...", 3), iv_ts, dots_te);
    } else {
      emit(ruby_sym("tBDOT3"), RubyString("...", 3), iv_ts, dots_te);
      if (({ auto _l = (({ auto _l = ((iv_version >= INT64_C(31))); (_l) ? decltype((followed_by_nl))(followed_by_nl) : decltype((followed_by_nl))(_l); })); (_l) ? decltype((iv_context->in_argdef()))(iv_context->in_argdef()) : decltype((iv_context->in_argdef()))(_l); })) {
      emit(ruby_sym("tNL"), (iv_te - INT64_C(1)), iv_te);
      (nl_emitted = true);
    };
    };
    } else {
      ((iv_version >= INT64_C(27)) ? (emit(ruby_sym("tBDOT3"), RubyString("...", 3), iv_ts, dots_te)) : (emit(ruby_sym("tDOT3"), RubyString("...", 3), iv_ts, dots_te)));
    };
      if (({ auto _l = (followed_by_nl); (_l) ? decltype(((!(nl_emitted))))((!(nl_emitted))) : decltype(((!(nl_emitted))))(_l); })) {
      (p = (p - INT64_C(1)));
    };
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(187))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };;) : (((_cs == INT64_C(197))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(199))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
      iv_cs_before_block_comment = iv_cs;
            iv_cs = INT64_C(710);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(202))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(39))) ? (            (p = (iv_te - INT64_C(1)));;
            diagnostic(ruby_sym("fatal"), ruby_sym("string_eof"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(58))) ? (            (p = (iv_te - INT64_C(1)));;
            diagnostic(ruby_sym("error"), ruby_sym("unterminated_heredoc_id"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));;) : (((_cs == INT64_C(33))) ? (            (p = (iv_te - INT64_C(1)));;
            emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };;) : (((_cs == INT64_C(38))) ? (            (p = (iv_te - INT64_C(1)));;) : (((_cs == INT64_C(53))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(36))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(60))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tUNARY_NUM"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(67))) ? (            (p = (iv_te - INT64_C(1)));;
      diagnostic(ruby_sym("error"), ruby_sym("unterminated_heredoc_id"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));) : (((_cs == INT64_C(76))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((iv_version >= INT64_C(27))) {
      emit(ruby_sym("tPIPE"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      (p = (p - INT64_C(2)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;
    };) : (((_cs == INT64_C(80))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION_BEGIN);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(81))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("kRESCUE"), RubyString("rescue", 6), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(321);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(82))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS_BEGIN);
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(86))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;) : (((_cs == INT64_C(87))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };) : (((_cs == INT64_C(91))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;) : (RUBY_NIL))))))))); });) : (((_cs == INT64_C(247))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(248))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(249))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(253))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(61))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(257))) ? (      iv_te = (p + INT64_C(1));
            iv_strings->push_literal(tok(), tok(), iv_ts);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(256))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(255))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(259))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(258))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(60))) ? (            (p = (iv_te - INT64_C(1)));;
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(345);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(292))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tLAMBDA"), RubyString("->", 2), iv_ts, (iv_ts + INT64_C(2)));
      iv_lambda_stack.push(iv_paren_nest);
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(71))) ? (      iv_te = (p + INT64_C(1));
            emit_singleton_class();
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(267))) ? (      iv_te = (p + INT64_C(1));
            auto _t29_0 = tok();
      auto _t29_1 = tok()[INT64_C(-1)].chr();
      type = _t29_0;
      delimiter = _t29_1;
      iv_strings->push_literal(type, delimiter, iv_ts, RUBY_NIL, false, false, true);
            iv_cs = INT64_C(128);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(63))) ? (      iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_stack[iv_top] = iv_cs;
      iv_top = (iv_top + INT64_C(1));
      iv_cs = INT64_C(129);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(288))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(255);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(341))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(281))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(286))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tOP_ASGN"), tok(iv_ts, (iv_te - INT64_C(1))));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(272))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tEH"), RubyString("?", 1));
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(269))) ? (      iv_te = (p + INT64_C(1));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(271))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tSEMI"), RubyString(";", 1));
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(346))) ? (      iv_te = (p + INT64_C(1));
            diagnostic(ruby_sym("error"), ruby_sym("bare_backslash"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));
      (p = (p - INT64_C(1)));;) : (((_cs == INT64_C(266))) ? (      iv_te = (p + INT64_C(1));
            diagnostic(ruby_sym("fatal"), ruby_sym("unexpected"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok().inspect()[(INT64_C(-2) + 1LL)]); _h; }));;) : (((_cs == INT64_C(265))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(357))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(KEYWORDS);
      iv_cs = INT64_C(134);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(355))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_singleton_class();
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(354))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(KEYWORDS);
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(296))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("error"), ruby_sym("no_dot_digit_literal"));;) : (((_cs == INT64_C(343))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tCONSTANT"));
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(285))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_stack[iv_top] = iv_cs;
      iv_top = (iv_top + INT64_C(1));
      iv_cs = INT64_C(129);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(293))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(255);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(349))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };;) : (((_cs == INT64_C(291))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(287))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(280))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(294))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(278))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(284))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("fatal"), ruby_sym("unexpected"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok().inspect()[(INT64_C(-2) + 1LL)]); _h; }));;) : (((_cs == INT64_C(69))) ? (            (p = (iv_te - INT64_C(1)));;
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(64))) ? (            (p = (iv_te - INT64_C(1)));;
            diagnostic(ruby_sym("error"), ruby_sym("no_dot_digit_literal"));;) : (((_cs == INT64_C(68))) ? (            (p = (iv_te - INT64_C(1)));;
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(62))) ? (            (p = (iv_te - INT64_C(1)));;
            diagnostic(ruby_sym("fatal"), ruby_sym("unexpected"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok().inspect()[(INT64_C(-2) + 1LL)]); _h; }));;) : (((_cs == INT64_C(66))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(104))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLAMBEG"), RubyString("{", 1))) : (emit(ruby_sym("kDO_LAMBDA"), RubyString("do", 2))));
    } else {
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLCURLY"), RubyString("{", 1))) : (emit_do()));
    };
      if ((tok() == RubyString("{", 1))) {
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
    };
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(105))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(134);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(106))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_singleton_class();
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(107))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(108))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(109))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(321);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(110))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      if (({ auto _l = (version_q(INT64_C(18))); (_l) ? decltype(((tok() == RubyString("not", 3))))((tok() == RubyString("not", 3))) : decltype(((tok() == RubyString("not", 3))))(_l); })) {
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(111))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18))) {
      emit(ruby_sym("tIDENTIFIER"));
      (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); }) ? (RUBY_NIL) : (iv_cs = arg_or_cmdarg(cmd_state)));
    } else {
      emit(ruby_sym("k__ENCODING__"), RubyString("__ENCODING__", 12));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(112))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(113))) ? (            (p = (iv_te - INT64_C(1)));;
      (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(115))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      diagnostic(ruby_sym("error"), ruby_sym("trailing_in_number"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok((iv_te - INT64_C(1)), iv_te)); _h; }), range((iv_te - INT64_C(1)), iv_te));
    } else {
      emit(ruby_sym("tINTEGER"), (int64_t)(tok(iv_ts, (iv_te - INT64_C(1)))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(116))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      diagnostic(ruby_sym("error"), ruby_sym("trailing_in_number"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok((iv_te - INT64_C(1)), iv_te)); _h; }), range((iv_te - INT64_C(1)), iv_te));
    } else {
      emit(ruby_sym("tFLOAT"), (double)(tok(iv_ts, (iv_te - INT64_C(1)))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(117))) ? (            (p = (iv_te - INT64_C(1)));;
      (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(119))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tCONSTANT"));
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(123))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };) : (((_cs == INT64_C(124))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((tm == iv_te)) {
      emit(ruby_sym("tFID"));
    } else {
      emit(ruby_sym("tIDENTIFIER"), tok(iv_ts, tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
    };
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(126))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(127))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (RUBY_NIL)))))))))))))))))); });) : (((_cs == INT64_C(368))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      if ((iv_version < INT64_C(27))) {
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      emit(ruby_sym("tBDOT3"));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(80))) ? (      iv_te = (p + INT64_C(1));
            (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(362))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(365))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            if ((iv_version < INT64_C(27))) {
      emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(367))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      if ((iv_version < INT64_C(27))) {
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      emit(ruby_sym("tBDOT2"));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(366))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(364))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(75))) ? (            (p = (iv_te - INT64_C(1)));;
            if ((iv_version < INT64_C(27))) {
      emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(72))) ? (            (p = (iv_te - INT64_C(1)));;
            emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(76))) ? (      ({ auto _cs = iv_act; ((_cs == INT64_C(140))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((iv_version < INT64_C(27))) {
      emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(144))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tNL"), RUBY_NIL, iv_newline_s, (iv_newline_s + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(710);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (RUBY_NIL)); });) : (((_cs == INT64_C(371))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_comment(iv_eq_begin_s, iv_te);
            iv_cs = iv_cs_before_block_comment;
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(370))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            diagnostic(ruby_sym("fatal"), ruby_sym("embedded_document"), RUBY_NIL, range(iv_eq_begin_s, (iv_eq_begin_s + RubyString("=begin", 6).len())));;) : (((_cs == INT64_C(381))) ? (      iv_te = (p + INT64_C(1));
            iv_eq_begin_s = iv_ts;
            iv_cs = INT64_C(704);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(82))) ? (      iv_te = (p + INT64_C(1));
            (p = (pe - INT64_C(3)));;) : (((_cs == INT64_C(373))) ? (      iv_te = (p + INT64_C(1));
            (cmd_state = true);
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(508);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(374))) ? (      iv_te = (p + INT64_C(1));
            (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(375))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(380))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            iv_eq_begin_s = iv_ts;
            iv_cs = INT64_C(704);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(379))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (cmd_state = true);
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(508);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(81))) ? (            (p = (iv_te - INT64_C(1)));;
            (cmd_state = true);
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(508);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(86))) ? (      iv_te = (p + INT64_C(1));
            auto _masgn30 = iv_strings->advance(p);
      p = _masgn30[INT64_C(0)];
      next_state = _masgn30[INT64_C(1)];
      (p = (p - INT64_C(1)));
      iv_cs = next_state;
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(52))) ? (      iv_newline_s = p;;       emit_comment_from_range(p, pe);) : (((_cs == INT64_C(154))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(145))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (p = (tm - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(137))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(213))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (followed_by_nl = ((iv_te - INT64_C(1)) == iv_newline_s));
      (nl_emitted = false);
      (dots_te = (followed_by_nl ? ((iv_te - INT64_C(1))) : (iv_te)));
      if ((iv_version >= INT64_C(30))) {
      if (({ auto _l = (iv_lambda_stack.any_q()); (_l) ? decltype((((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)))(((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)) : decltype((((iv_lambda_stack.last() + INT64_C(1)) == iv_paren_nest)))(_l); })) {
      emit(ruby_sym("tDOT3"), RubyString("...", 3), iv_ts, dots_te);
    } else {
      emit(ruby_sym("tBDOT3"), RubyString("...", 3), iv_ts, dots_te);
      if (({ auto _l = (({ auto _l = ((iv_version >= INT64_C(31))); (_l) ? decltype((followed_by_nl))(followed_by_nl) : decltype((followed_by_nl))(_l); })); (_l) ? decltype((iv_context->in_argdef()))(iv_context->in_argdef()) : decltype((iv_context->in_argdef()))(_l); })) {
      emit(ruby_sym("tNL"), (iv_te - INT64_C(1)), iv_te);
      (nl_emitted = true);
    };
    };
    } else {
      ((iv_version >= INT64_C(27)) ? (emit(ruby_sym("tBDOT3"), RubyString("...", 3), iv_ts, dots_te)) : (emit(ruby_sym("tDOT3"), RubyString("...", 3), iv_ts, dots_te)));
    };
      if (({ auto _l = (followed_by_nl); (_l) ? decltype(((!(nl_emitted))))((!(nl_emitted))) : decltype(((!(nl_emitted))))(_l); })) {
      (p = (p - INT64_C(1)));
    };
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(201))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
      iv_cs_before_block_comment = iv_cs;
            iv_cs = INT64_C(710);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(295))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            if ((iv_paren_nest == INT64_C(0))) {
      diagnostic(ruby_sym("warning"), ruby_sym("triple_dot_at_eol"), RUBY_NIL, range(iv_ts, (iv_te - INT64_C(1))));
    };
      emit(ruby_sym("tDOT3"), RubyString("...", 3), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(372))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            emit_comment(iv_eq_begin_s, iv_te);
            iv_cs = iv_cs_before_block_comment;
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(369))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));) : (((_cs == INT64_C(382))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            iv_eq_begin_s = iv_ts;
            iv_cs = INT64_C(704);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(83))) ? (      iv_newline_s = p;;       iv_te = (p + INT64_C(1));
            (p = (pe - INT64_C(3)));;) : (((_cs == INT64_C(317))) ? (      iv_num_xfrm = iv_emit_rational;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(315))) ? (      iv_num_xfrm = iv_emit_imaginary;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(320))) ? (      iv_num_xfrm = iv_emit_imaginary_rational;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(318))) ? (      iv_num_xfrm = iv_emit_integer_re;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(316))) ? (      iv_num_xfrm = iv_emit_integer_if;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(319))) ? (      iv_num_xfrm = iv_emit_integer_rescue;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(308))) ? (      iv_num_xfrm = iv_emit_imaginary_float;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(309))) ? (      iv_num_xfrm = iv_emit_float_if;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(310))) ? (      iv_num_xfrm = iv_emit_rational;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(312))) ? (      iv_num_xfrm = iv_emit_imaginary_rational;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(311))) ? (      iv_num_xfrm = iv_emit_float_rescue;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(147))) ? (      e_lbrace();;       iv_te = p;
      (p = (p - INT64_C(1)));
            if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      emit(ruby_sym("tLAMBEG"), RubyString("{", 1), (iv_te - INT64_C(1)), iv_te);
    } else {
      emit(ruby_sym("tLCURLY"), RubyString("{", 1), (iv_te - INT64_C(1)), iv_te);
    };
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(169))) ? (      e_lbrace();;       iv_te = p;
      (p = (p - INT64_C(1)));
            if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      emit(ruby_sym("tLAMBEG"), RubyString("{", 1));
    } else {
      emit(ruby_sym("tLBRACE_ARG"), RubyString("{", 1));
    };
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(245))) ? (      e_lbrace();;       iv_te = p;
      (p = (p - INT64_C(1)));
            if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      iv_command_start = coerce_to_ref<RubyObject>(true);
      emit(ruby_sym("tLAMBEG"), RubyString("{", 1));
    } else {
      emit(ruby_sym("tLBRACE"), RubyString("{", 1));
    };
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(360))) ? (      e_lbrace();;       iv_te = p;
      (p = (p - INT64_C(1)));
            if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLAMBEG"), RubyString("{", 1))) : (emit(ruby_sym("kDO_LAMBDA"), RubyString("do", 2))));
    } else {
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLCURLY"), RubyString("{", 1))) : (emit_do()));
    };
      if ((tok() == RubyString("{", 1))) {
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
    };
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(361))) ? (      if (iv_strings->close_interp_on_current_literal(p)) {
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(128);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
      iv_paren_nest = (iv_paren_nest - INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_rbrace_rparen_rbrack();
      if (({ auto _l = ((tok() == RubyString("}", 1))); (_l) ? decltype(((tok() == RubyString("]", 1))))(_l) : ((tok() == RubyString("]", 1))); })) {
      ((iv_version >= INT64_C(25)) ? (iv_cs = INT64_C(516)) : (iv_cs = INT64_C(313)));
    } else {
      RUBY_NIL;
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(43))) ? (      (p = on_newline(p));;       iv_newline_s = p;) : (((_cs == INT64_C(16))) ? (      (p = on_newline(p));;       (tm = p);) : (((_cs == INT64_C(18))) ? (      (p = on_newline(p));;       (tm = p);) : (((_cs == INT64_C(20))) ? (      (p = on_newline(p));;       (tm = p);) : (((_cs == INT64_C(98))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(117))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(125))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(19))) ? (      (p = on_newline(p));;       iv_te = (p + INT64_C(1));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(156))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(148))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(167))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(179))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(175))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(44))) ? (      (p = on_newline(p));;       iv_te = (p + INT64_C(1));
            emit(ruby_sym("tUNARY_NUM"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(35))) ? (      (p = on_newline(p));;       iv_te = (p + INT64_C(1));
            emit(ruby_sym("tIDENTIFIER"), ident_tok, ident_ts, ident_te);
      (p = (ident_te - INT64_C(1)));
      (({ auto _l = (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(ident_tok)))(iv_static_env->declared_q(ident_tok)) : decltype((iv_static_env->declared_q(ident_tok)))(_l); })); (_l) ? decltype(((iv_version < INT64_C(25))))((iv_version < INT64_C(25))) : decltype(((iv_version < INT64_C(25))))(_l); }) ? (iv_cs = INT64_C(247)) : (iv_cs = INT64_C(307)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(198))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(254))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(250))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));
            if (iv_context->in_kwarg()) {
      (p = (p - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;
    } else {
            iv_cs = INT64_C(710);
      (_goto_level = _again);
      continue;;
    };;) : (((_cs == INT64_C(263))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(260))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));
                  iv_cs = INT64_C(710);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(347))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(279))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));
                  iv_cs = INT64_C(696);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(376))) ? (      (p = on_newline(p));;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(46))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);) : (((_cs == INT64_C(50))) ? (      emit_comment_from_range(p, pe);;       iv_newline_s = p;) : (((_cs == INT64_C(101))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(116))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(128))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(150))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));
                  iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(165))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(177))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(204))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(252))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(262))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(283))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(378))) ? (      emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(122))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tFID"), tok(iv_ts, tm), iv_ts, tm);
      iv_cs = arg_or_cmdarg(cmd_state);
      (p = (tm - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(218))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(189))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(276))) ? (      (tm = p);;       ({ auto _cs = iv_act; ((_cs == INT64_C(104))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((iv_lambda_stack.last() == iv_paren_nest)) {
      iv_lambda_stack.pop();
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLAMBEG"), RubyString("{", 1))) : (emit(ruby_sym("kDO_LAMBDA"), RubyString("do", 2))));
    } else {
      ((tok() == RubyString("{", 1)) ? (emit(ruby_sym("tLCURLY"), RubyString("{", 1))) : (emit_do()));
    };
      if ((tok() == RubyString("{", 1))) {
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
    };
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(105))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(134);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(106))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_singleton_class();
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(107))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(108))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(109))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      iv_cs = INT64_C(321);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(110))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
      if (({ auto _l = (version_q(INT64_C(18))); (_l) ? decltype(((tok() == RubyString("not", 3))))((tok() == RubyString("not", 3))) : decltype(((tok() == RubyString("not", 3))))(_l); })) {
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(111))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18))) {
      emit(ruby_sym("tIDENTIFIER"));
      (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); }) ? (RUBY_NIL) : (iv_cs = arg_or_cmdarg(cmd_state)));
    } else {
      emit(ruby_sym("k__ENCODING__"), RubyString("__ENCODING__", 12));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(112))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(113))) ? (            (p = (iv_te - INT64_C(1)));;
      (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(115))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      diagnostic(ruby_sym("error"), ruby_sym("trailing_in_number"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok((iv_te - INT64_C(1)), iv_te)); _h; }), range((iv_te - INT64_C(1)), iv_te));
    } else {
      emit(ruby_sym("tINTEGER"), (int64_t)(tok(iv_ts, (iv_te - INT64_C(1)))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(116))) ? (            (p = (iv_te - INT64_C(1)));;
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      diagnostic(ruby_sym("error"), ruby_sym("trailing_in_number"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("character"), tok((iv_te - INT64_C(1)), iv_te)); _h; }), range((iv_te - INT64_C(1)), iv_te));
    } else {
      emit(ruby_sym("tFLOAT"), (double)(tok(iv_ts, (iv_te - INT64_C(1)))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };) : (((_cs == INT64_C(117))) ? (            (p = (iv_te - INT64_C(1)));;
      (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(119))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tCONSTANT"));
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(123))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };) : (((_cs == INT64_C(124))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((tm == iv_te)) {
      emit(ruby_sym("tFID"));
    } else {
      emit(ruby_sym("tIDENTIFIER"), tok(iv_ts, tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
    };
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(126))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(127))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (RUBY_NIL)))))))))))))))))); });) : (((_cs == INT64_C(123))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tFID"), tok(iv_ts, tm), iv_ts, tm);
      iv_cs = arg_or_cmdarg(cmd_state);
      (p = (tm - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(219))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(191))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(277))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            if ((tm == iv_te)) {
      emit(ruby_sym("tFID"));
    } else {
      emit(ruby_sym("tIDENTIFIER"), tok(iv_ts, tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
    };
      iv_cs = INT64_C(276);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(220))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(192))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(221))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(193))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(225))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(196))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(224))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(195))) ? (      (tm = (p - INT64_C(2)));;       ({ auto _cs = iv_act; ((_cs == INT64_C(60))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tUNARY_NUM"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(67))) ? (            (p = (iv_te - INT64_C(1)));;
      diagnostic(ruby_sym("error"), ruby_sym("unterminated_heredoc_id"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));) : (((_cs == INT64_C(76))) ? (            (p = (iv_te - INT64_C(1)));;
      if ((iv_version >= INT64_C(27))) {
      emit(ruby_sym("tPIPE"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      (p = (p - INT64_C(2)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;
    };) : (((_cs == INT64_C(80))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(PUNCTUATION_BEGIN);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(81))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("kRESCUE"), RubyString("rescue", 6), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(321);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(82))) ? (            (p = (iv_te - INT64_C(1)));;
      emit_table(KEYWORDS_BEGIN);
      iv_command_start = coerce_to_ref<RubyObject>(true);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;) : (((_cs == INT64_C(86))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;) : (((_cs == INT64_C(87))) ? (            (p = (iv_te - INT64_C(1)));;
      emit(ruby_sym("tIDENTIFIER"));
      if (({ auto _l = ((!(ruby_nil_q(iv_static_env)))); (_l) ? decltype((iv_static_env->declared_q(tok())))(iv_static_env->declared_q(tok())) : decltype((iv_static_env->declared_q(tok())))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      if (({ auto _l = ((iv_version >= INT64_C(32))); (_l) ? decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(tok().=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((tok().=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })) {
      iv_cs = INT64_C(247);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = arg_or_cmdarg(cmd_state);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };
    };) : (((_cs == INT64_C(91))) ? (            (p = (iv_te - INT64_C(1)));;
      (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;) : (RUBY_NIL))))))))); });) : (((_cs == INT64_C(222))) ? (      (tm = (p - INT64_C(3)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(194))) ? (      (tm = (p - INT64_C(3)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
            iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(223))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tSYMBOL"), tok((iv_ts + INT64_C(1)), tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(342))) ? (      (tm = (p - INT64_C(2)));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tCONSTANT"), tok(iv_ts, tm), iv_ts, tm);
      (p = (tm - INT64_C(1)));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(146))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLBRACK"), RubyString("[", 1), (iv_te - INT64_C(1)), iv_te);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(238))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLBRACK"), RubyString("[", 1));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(345))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLBRACK2"), RubyString("[", 1));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(348))) ? (      iv_paren_nest = (iv_paren_nest - INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_rbrace_rparen_rbrack();
      if (({ auto _l = ((tok() == RubyString("}", 1))); (_l) ? decltype(((tok() == RubyString("]", 1))))(_l) : ((tok() == RubyString("]", 1))); })) {
      ((iv_version >= INT64_C(25)) ? (iv_cs = INT64_C(516)) : (iv_cs = INT64_C(313)));
    } else {
      RUBY_NIL;
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(138))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      if (version_q(INT64_C(18))) {
      iv_command_start = coerce_to_ref<RubyObject>(true);
    };;       iv_te = p;
      (p = (p - INT64_C(1)));
            if (version_q(INT64_C(18))) {
      emit(ruby_sym("tLPAREN2"), RubyString("(", 1), (iv_te - INT64_C(1)), iv_te);
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      emit(ruby_sym("tLPAREN_ARG"), RubyString("(", 1), (iv_te - INT64_C(1)), iv_te);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(151))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      if (version_q(INT64_C(18))) {
      iv_command_start = coerce_to_ref<RubyObject>(true);
    };;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLPAREN2"), RubyString("(", 1));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(159))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      if (version_q(INT64_C(18))) {
      iv_command_start = coerce_to_ref<RubyObject>(true);
    };;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLPAREN_ARG"), RubyString("(", 1), (iv_te - INT64_C(1)), iv_te);
      if (version_q(INT64_C(18))) {
      iv_cs = INT64_C(508);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    };;) : (((_cs == INT64_C(208))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      if (version_q(INT64_C(18))) {
      iv_command_start = coerce_to_ref<RubyObject>(true);
    };;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("tLPAREN"), RubyString("(", 1));
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(289))) ? (      iv_cond->push(false);
      iv_cmdarg->push(false);
      iv_paren_nest = (iv_paren_nest + INT64_C(1));
      if (version_q(INT64_C(18))) {
      iv_command_start = coerce_to_ref<RubyObject>(true);
    };;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_table(PUNCTUATION);
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(290))) ? (      iv_paren_nest = (iv_paren_nest - INT64_C(1));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_rbrace_rparen_rbrack();
      if (({ auto _l = ((tok() == RubyString("}", 1))); (_l) ? decltype(((tok() == RubyString("]", 1))))(_l) : ((tok() == RubyString("]", 1))); })) {
      ((iv_version >= INT64_C(25)) ? (iv_cs = INT64_C(516)) : (iv_cs = INT64_C(313)));
    } else {
      RUBY_NIL;
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(57))) ? (      (heredoc_e = p);;       iv_newline_s = p;) : (((_cs == INT64_C(233))) ? (      (new_herebody_s = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            tok(iv_ts, heredoc_e).=~(/* UNSUPPORTED: RegexpLiteral */);
      auto indent = ({ auto _l = ((!(/* UNSUPPORTED: GlobalVariableRead */.empty_q()))); (_l) ? decltype(((!(/* UNSUPPORTED: GlobalVariableRead */.empty_q()))))(_l) : ((!(/* UNSUPPORTED: GlobalVariableRead */.empty_q()))); });
      (dedent_body = (!(/* UNSUPPORTED: GlobalVariableRead */.empty_q())));
      (type = (/* UNSUPPORTED: GlobalVariableRead */.empty_q() ? (coerce_to_ref<RubyObject>(RubyString("<<\"", 3))) : (coerce_to_ref<RubyObject>((RubyString("<<", 2) + /* UNSUPPORTED: GlobalVariableRead */)))));
      (delimiter = /* UNSUPPORTED: GlobalVariableRead */);
      if ((iv_version >= INT64_C(27))) {
      if (({ auto _l = ((delimiter.count(RubyString("\n", 1)) > INT64_C(0))); (_l) ? decltype(((delimiter.count(RubyString("\r", 1)) > INT64_C(0))))(_l) : ((delimiter.count(RubyString("\r", 1)) > INT64_C(0))); })) {
      diagnostic(ruby_sym("error"), ruby_sym("unterminated_heredoc_id"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));
    };
    } else {
      if ((iv_version >= INT64_C(24))) {
      if ((delimiter.count(RubyString("\n", 1)) > INT64_C(0))) {
      if (delimiter.end_with_q(RubyString("\n", 1))) {
      diagnostic(ruby_sym("warning"), ruby_sym("heredoc_id_ends_with_nl"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));
      (delimiter = delimiter.rstrip());
    } else {
      diagnostic(ruby_sym("fatal"), ruby_sym("heredoc_id_has_newline"), RUBY_NIL, range(iv_ts, (iv_ts + INT64_C(1))));
    };
    };
    };
    };
      if (({ auto _l = (dedent_body); (_l) ? decltype((version_q(INT64_C(18), INT64_C(19), INT64_C(20), INT64_C(21), INT64_C(22))))(version_q(INT64_C(18), INT64_C(19), INT64_C(20), INT64_C(21), INT64_C(22))) : decltype((version_q(INT64_C(18), INT64_C(19), INT64_C(20), INT64_C(21), INT64_C(22))))(_l); })) {
      emit(ruby_sym("tLSHFT"), RubyString("<<", 2), iv_ts, (iv_ts + INT64_C(2)));
      (p = (iv_ts + INT64_C(1)));
      iv_cs = INT64_C(345);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;
    } else {
      iv_strings->push_literal(type, delimiter, iv_ts, heredoc_e, indent, dedent_body);
      /* UNSUPPORTED: CallOrWrite */;
      (p = (iv_strings->herebody_s() - INT64_C(1)));
      iv_cs = INT64_C(128);
    };;) : (((_cs == INT64_C(228))) ? (      (tm = (p - INT64_C(1)));
      (diag_msg = ruby_sym("ivar_name"));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_colon_with_digits(p, tm, diag_msg);
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(231))) ? (      (tm = (p - INT64_C(2)));
      (diag_msg = ruby_sym("cvar_name"));;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit_colon_with_digits(p, tm, diag_msg);
      iv_cs = INT64_C(516);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(241))) ? (      (tm = p);;       iv_te = p;
      (p = (p - INT64_C(1)));
            emit(ruby_sym("kRESCUE"), RubyString("rescue", 6), iv_ts, tm);
      (p = (tm - INT64_C(1)));
      iv_cs = INT64_C(321);
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(332))) ? (      iv_num_base = INT64_C(16);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(326))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(329))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(323))) ? (      iv_num_base = INT64_C(2);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(338))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(301))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;) : (((_cs == INT64_C(339))) ? (      iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;) : (((_cs == INT64_C(184))) ? (      iv_te = (p + INT64_C(1));;       iv_newline_s = p;) : (((_cs == INT64_C(305))) ? (      iv_te = (p + INT64_C(1));;       iv_num_suffix_s = p;) : (((_cs == INT64_C(107))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(4);) : (((_cs == INT64_C(94))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(5);) : (((_cs == INT64_C(90))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(6);) : (((_cs == INT64_C(12))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(33);) : (((_cs == INT64_C(140))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(34);) : (((_cs == INT64_C(13))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(39);) : (((_cs == INT64_C(133))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(40);) : (((_cs == INT64_C(160))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(46);) : (((_cs == INT64_C(31))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(47);) : (((_cs == INT64_C(181))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(54);) : (((_cs == INT64_C(170))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(55);) : (((_cs == INT64_C(55))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(67);) : (((_cs == INT64_C(246))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(76);) : (((_cs == INT64_C(185))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(80);) : (((_cs == INT64_C(240))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(81);) : (((_cs == INT64_C(239))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(82);) : (((_cs == INT64_C(59))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(86);) : (((_cs == INT64_C(182))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(87);) : (((_cs == INT64_C(186))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(91);) : (((_cs == INT64_C(356))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(104);) : (((_cs == INT64_C(351))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(105);) : (((_cs == INT64_C(359))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(107);) : (((_cs == INT64_C(352))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(108);) : (((_cs == INT64_C(353))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(109);) : (((_cs == INT64_C(358))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(110);) : (((_cs == INT64_C(350))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(111);) : (((_cs == INT64_C(344))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(112);) : (((_cs == INT64_C(270))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(113);) : (((_cs == INT64_C(303))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(116);) : (((_cs == INT64_C(67))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(117);) : (((_cs == INT64_C(273))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(119);) : (((_cs == INT64_C(264))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(123);) : (((_cs == INT64_C(275))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(124);) : (((_cs == INT64_C(268))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(126);) : (((_cs == INT64_C(274))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(127);) : (((_cs == INT64_C(73))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(140);) : (((_cs == INT64_C(363))) ? (      iv_te = (p + INT64_C(1));;       iv_act = INT64_C(144);) : (((_cs == INT64_C(47))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_newline_s = p;) : (((_cs == INT64_C(100))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(115))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(127))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(149))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));
                  iv_cs = INT64_C(516);
      (_goto_level = _again);
      continue;;;) : (((_cs == INT64_C(164))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(176))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(203))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(251))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(261))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(282))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(377))) ? (      iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_te = p;
      (p = (p - INT64_C(1)));) : (((_cs == INT64_C(334))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;) : (((_cs == INT64_C(298))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;) : (((_cs == INT64_C(313))) ? (      iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(306))) ? (      iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_float;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(302))) ? (      iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_float;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = tok(iv_ts, iv_num_suffix_s));
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tFLOAT"), Float(digits), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits, p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(155))) ? (      iv_te = (p + INT64_C(1));;       iv_newline_s = p;;       iv_act = INT64_C(40);) : (((_cs == INT64_C(21))) ? (      iv_te = (p + INT64_C(1));;       (p = on_newline(p));;       iv_act = INT64_C(39);) : (((_cs == INT64_C(32))) ? (      iv_te = (p + INT64_C(1));;       (p = on_newline(p));;       iv_act = INT64_C(47);) : (((_cs == INT64_C(79))) ? (      iv_te = (p + INT64_C(1));;       (p = on_newline(p));;       iv_act = INT64_C(140);) : (((_cs == INT64_C(51))) ? (      iv_te = (p + INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_act = INT64_C(60);) : (((_cs == INT64_C(70))) ? (      iv_te = (p + INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_act = INT64_C(106);) : (((_cs == INT64_C(78))) ? (      iv_te = (p + INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_act = INT64_C(140);) : (((_cs == INT64_C(23))) ? (      iv_te = (p + INT64_C(1));;       (tm = p);;       iv_act = INT64_C(34);) : (((_cs == INT64_C(243))) ? (      iv_te = (p + INT64_C(1));;       (tm = p);;       iv_act = INT64_C(86);) : (((_cs == INT64_C(242))) ? (      iv_te = (p + INT64_C(1));;       (tm = p);;       iv_act = INT64_C(87);) : (((_cs == INT64_C(335))) ? (      iv_te = (p + INT64_C(1));;       iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;;       iv_act = INT64_C(113);) : (((_cs == INT64_C(330))) ? (      iv_num_base = INT64_C(16);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(324))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(327))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(321))) ? (      iv_num_base = INT64_C(2);
      iv_num_digits_s = p;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(333))) ? (      iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(297))) ? (      iv_num_base = INT64_C(8);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_te = p;
      (p = (p - INT64_C(1)));
            (digits = numeric_literal_int());
      if (version_q(INT64_C(18), INT64_C(19), INT64_C(20))) {
      emit(ruby_sym("tINTEGER"), digits.to_i(iv_num_base), iv_ts, iv_num_suffix_s);
      (p = (iv_num_suffix_s - INT64_C(1)));
    } else {
      (p = iv_num_xfrm(digits.to_i(iv_num_base), p));
    };
            (p = (p + INT64_C(1)));
      (_goto_level = _out);
      continue;;;) : (((_cs == INT64_C(17))) ? (      iv_te = (p + INT64_C(1));;       (p = on_newline(p));;       (tm = p);;       iv_act = INT64_C(34);) : (((_cs == INT64_C(48))) ? (      iv_te = (p + INT64_C(1));;       iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_act = INT64_C(60);) : (((_cs == INT64_C(77))) ? (      iv_te = (p + INT64_C(1));;       iv_sharp_s = (p - INT64_C(1));;       emit_comment_from_range(p, pe);;       iv_act = INT64_C(140);) : (((_cs == INT64_C(340))) ? (      iv_te = (p + INT64_C(1));;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_act = INT64_C(115);) : (((_cs == INT64_C(336))) ? (      iv_te = (p + INT64_C(1));;       iv_num_base = INT64_C(10);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_act = INT64_C(115);) : (((_cs == INT64_C(300))) ? (      iv_te = (p + INT64_C(1));;       iv_num_base = INT64_C(8);
      iv_num_digits_s = iv_ts;;       iv_num_suffix_s = p;;       iv_num_xfrm = iv_emit_integer;;       iv_act = INT64_C(115);) : (RUBY_NIL)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))); });
    };
    };
      if ((_goto_level <= _again)) {
      ({ auto _cs = _lex_to_state_actions[iv_cs]; ((_cs == INT64_C(84))) ? (      iv_ts = RUBY_NIL;) : (RUBY_NIL); });
      if ((iv_cs == INT64_C(0))) {
      (_goto_level = _out);
      continue;
    };
      (p = (p + INT64_C(1)));
      if ((p != pe)) {
      (_goto_level = _resume);
      continue;
    };
    };
      if ((_goto_level <= _test_eof)) {
      if ((p == eof)) {
      if ((_lex_eof_trans[iv_cs] > INT64_C(0))) {
      (_trans = (_lex_eof_trans[iv_cs] - INT64_C(1)));
      (_goto_level = _eof_trans);
      continue;
    };
    };
    };
      if ((_goto_level <= _out)) {
      break;
    };
    };
    if (false) {
      testEof;
    }
    iv_p = p;
    if (iv_token_queue.any_q()) {
      return iv_token_queue.shift();
    } else {
      if ((iv_cs == klass.lex_error())) {
        return ({ auto _e0 = false; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = RubyString("$error", 6); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = range((p - INT64_C(1)), p); _a; }); _a; });
      } else {
        return (eof = iv_source_pts.len()); ({ auto _e0 = false; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = RubyString("$eof", 4); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = range(eof, eof); _a; }); _a; });
      }
    }
  }

  RubyObject* version_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub version_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* stack_pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub stack_pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* tok(auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub tok\n"); std::abort();
    return nullptr;
  }

  RubyObject* range(auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub range\n"); std::abort();
    return nullptr;
  }

  RubyArray<gc_ref<RubyObject>> emit(auto type, int64_t value = tok(), RubyNil s = iv_ts, RubyNil e = iv_te) {
    RubyArray<gc_ref<RubyObject>> token;
    (token = ({ auto _e0 = type; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = value; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = range(s, e); _a; }); _a; }));
    iv_token_queue.push(token);
    if (iv_tokens) {
      iv_tokens.push(token);
    }
    return token;
  }

  RubyObject* emit_table(auto table, auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_table\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_do(auto do_block) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_do\n"); std::abort();
    return nullptr;
  }

  RubyObject* arg_or_cmdarg(auto cmd_state) {
    std::fprintf(stderr, "frozone: called TI-gap stub arg_or_cmdarg\n"); std::abort();
    return nullptr;
  }

  RubyNil emit_comment(RubyNil s = iv_ts, RubyNil e = iv_te) {
    if (iv_comments) {
      iv_comments->push(gc_new<Ruby_Comment>(range(s, e)));
    }
    if (iv_tokens) {
      iv_tokens.push(({ auto _e0 = ruby_sym("tCOMMENT"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RubyTree(tok(s, e), range(s, e)); _a; }));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil emit_comment_from_range(auto p, auto pe) {
    return emit_comment(iv_sharp_s, ((p == pe) ? ((p - INT64_C(2))) : (p)));
  }

  RubyObject* diagnostic(auto type, auto reason, auto arguments, auto location, auto highlights) {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostic\n"); std::abort();
    return nullptr;
  }

  RubyNil e_lbrace() {
    std::decay_t<decltype(iv_strings->literal())> current_literal{};
    iv_cond->push(false);
    iv_cmdarg->push(false);
    (current_literal = iv_strings->literal());
    if (current_literal) {
      return current_literal.start_interp_brace();
    }
    return RubyNil(RUBY_NIL);
  }

  RubyString numeric_literal_int() {
    RubyString digits;
    std::decay_t<decltype(digits.index(/* UNSUPPORTED: RegexpLiteral */))> invalid_idx{};
    std::decay_t<decltype((iv_num_digits_s + invalid_idx))> invalid_s{};
    (digits = tok(iv_num_digits_s, iv_num_suffix_s));
    if (digits.end_with_q(RubyString("_", 1))) {
      diagnostic(ruby_sym("error"), ruby_sym("trailing_in_number"), ({ RubyHash<RubySymbol, RubyString> _h; _h.store(ruby_sym("character"), RubyString("_", 1)); _h; }), range((iv_te - INT64_C(1)), iv_te));
    } else {
      if (({ auto _l = (({ auto _l = (digits.empty_q()); (_l) ? decltype(((iv_num_base == INT64_C(8))))((iv_num_base == INT64_C(8))) : decltype(((iv_num_base == INT64_C(8))))(_l); })); (_l) ? decltype((version_q(INT64_C(18))))(version_q(INT64_C(18))) : decltype((version_q(INT64_C(18))))(_l); })) {
      (digits = RubyString("0", 1));
    } else {
      if (digits.empty_q()) {
      diagnostic(ruby_sym("error"), ruby_sym("empty_numeric"));
    } else {
      if (({ auto _l = ((iv_num_base == INT64_C(8))); (_l) ? decltype(((invalid_idx = digits.index(/* UNSUPPORTED: RegexpLiteral */))))((invalid_idx = digits.index(/* UNSUPPORTED: RegexpLiteral */))) : decltype(((invalid_idx = digits.index(/* UNSUPPORTED: RegexpLiteral */))))(_l); })) {
      (invalid_s = (iv_num_digits_s + invalid_idx));
      diagnostic(ruby_sym("error"), ruby_sym("invalid_octal"), RUBY_NIL, range(invalid_s, (invalid_s + INT64_C(1))));
    };
    };
    };
    }
    return digits;
  }

  RubyObject* on_newline(auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_newline\n"); std::abort();
    return nullptr;
  }

  RubyNil check_ambiguous_slash(auto tm) {
    if ((tok(tm, (tm + INT64_C(1))) == RubyString("/", 1))) {
      if ((iv_version < INT64_C(30))) {
        return diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_literal"), RUBY_NIL, range(tm, (tm + INT64_C(1))));
      } else {
        return diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_regexp"), RUBY_NIL, range(tm, (tm + INT64_C(1))));
      }
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* emit_global_var(auto ts, auto te) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_global_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_class_var(auto ts, auto te) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_class_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_instance_var(auto ts, auto te) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_instance_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_rbrace_rparen_rbrack() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_rbrace_rparen_rbrack\n"); std::abort();
    return nullptr;
  }

  std::optional<int64_t> emit_colon_with_digits(auto p, auto tm, auto diag_msg) {
    if ((iv_version >= INT64_C(27))) {
      diagnostic(ruby_sym("error"), diag_msg, ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), tok(tm, iv_te)); _h; }), range(tm, iv_te));
    } else {
      emit(ruby_sym("tCOLON"), tok(iv_ts, (iv_ts + INT64_C(1))), iv_ts, (iv_ts + INT64_C(1)));
      (p = iv_ts);
    }
    return p;
  }

  RubyObject* emit_singleton_class() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_singleton_class\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Lexer>() { return "Lexer"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Lexer> : dustman::FieldList<Ruby_Lexer, &Ruby_Lexer::iv_static_env, &Ruby_Lexer::iv_cond, &Ruby_Lexer::iv_cmdarg, &Ruby_Lexer::iv_context, &Ruby_Lexer::iv_command_start> {};
#endif

struct Ruby_LexerStrings : public RubyObject {
  RubyNil iv_herebody_s;
  gc_ref<RubyObject> iv_source_buffer = nullptr;
  gc_ref<RubyObject> iv_source_pts = nullptr;
  gc_ref<RubyObject> iv_lexer = nullptr;
  int64_t iv_version = 0;
  RubyArray<int64_t> iv__lex_actions;
  gc_ref<RubyObject> iv_cs = nullptr;
  RubyArray<int64_t> iv_literal_stack;
  RubyNil iv_escape_s;
  RubyString iv_escape;
  RubyNil iv_dedent_level;
  gc_ref<RubyObject> iv_ts = nullptr;
  gc_ref<RubyObject> iv_newline_s = nullptr;
  gc_ref<RubyObject> iv_te = nullptr;
  gc_ref<RubyObject> iv_root_lexer_state = nullptr;

  Ruby_LexerStrings() = default;
  Ruby_LexerStrings(auto lexer, auto version) {
    iv_lexer = lexer;
    iv_version = version;
    iv__lex_actions = (rb_class().respond_to_q(ruby_sym("_lex_actions"), true) ? (rb_class().send(ruby_sym("_lex_actions"))) : (RubyArray_I64(0)));
    reset();
  }
  const char* rb_class_name() const override { return "LexerStrings"; }

  RubyNil herebody_s() {
    return iv_herebody_s;
  }

  RubyNil set_herebody_s(auto __anon_req__) {
    iv_herebody_s = __anon_req__;
    return iv_herebody_s;
  }

  RubyObject* source_buffer() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_buffer\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_source_buffer(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_source_buffer\n"); std::abort();
    return nullptr;
  }

  RubyObject* source_pts() {
    std::fprintf(stderr, "frozone: called TI-gap stub source_pts\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_source_pts(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_source_pts\n"); std::abort();
    return nullptr;
  }

  RubyNil reset() {
    iv_cs = rb_class().lex_en_unknown();
    iv_literal_stack = RubyArray_I64(0);
    iv_escape_s = RUBY_NIL;
    iv_escape = RUBY_NIL;
    iv_herebody_s = RUBY_NIL;
    return iv_dedent_level = RUBY_NIL;
  }

  RubyArray<int64_t> advance(auto p) {
    std::decay_t<decltype(rb_class())> klass{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_keys")))> _lex_trans_keys{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_key_spans")))> _lex_key_spans{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_index_offsets")))> _lex_index_offsets{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_indicies")))> _lex_indicies{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_targs")))> _lex_trans_targs{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_trans_actions")))> _lex_trans_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_to_state_actions")))> _lex_to_state_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_from_state_actions")))> _lex_from_state_actions{};
    std::decay_t<decltype(klass.send(ruby_sym("_lex_eof_trans")))> _lex_eof_trans{};
    RubyArray<int64_t> _lex_actions;
    std::decay_t<decltype((source_pts().len() + INT64_C(2)))> pe{};
    std::decay_t<decltype(pe)> eof{};
    bool testEof = false;
    int64_t _goto_level = 0;
    int64_t _resume = 0;
    int64_t _eof_trans = 0;
    int64_t _again = 0;
    int64_t _test_eof = 0;
    int64_t _out = 0;
    gc_local<RubyObject> _trigger_goto = nullptr;
    int64_t _wide = 0;
    RubySymbol interp_var_kind;
    std::decay_t<decltype(literal())> current_literal{};
    std::decay_t<decltype(extend_string_eol_heredoc_line())> line{};
    std::decay_t<decltype(tok())> string{};
    RubyNil state;
    std::decay_t<decltype(tok().scan(/* UNSUPPORTED: RegexpLiteral */))> unknown_options{};
    RubyNil escape;
    (klass = rb_class());
    (_lex_trans_keys = klass.send(ruby_sym("_lex_trans_keys")));
    (_lex_key_spans = klass.send(ruby_sym("_lex_key_spans")));
    (_lex_index_offsets = klass.send(ruby_sym("_lex_index_offsets")));
    (_lex_indicies = klass.send(ruby_sym("_lex_indicies")));
    (_lex_trans_targs = klass.send(ruby_sym("_lex_trans_targs")));
    (_lex_trans_actions = klass.send(ruby_sym("_lex_trans_actions")));
    (_lex_to_state_actions = klass.send(ruby_sym("_lex_to_state_actions")));
    (_lex_from_state_actions = klass.send(ruby_sym("_lex_from_state_actions")));
    (_lex_eof_trans = klass.send(ruby_sym("_lex_eof_trans")));
    (_lex_actions = iv__lex_actions);
    (pe = (source_pts().len() + INT64_C(2)));
    (eof = pe);
          (testEof = false);
      auto _masgn31 = RUBY_NIL;
      auto _slen = _masgn31[INT64_C(0)];
      auto _trans = _masgn31[INT64_C(1)];
      auto _keys = _masgn31[INT64_C(2)];
      auto _inds = _masgn31[INT64_C(3)];
      auto _acts = _masgn31[INT64_C(4)];
      auto _nacts = _masgn31[INT64_C(5)];
      (_goto_level = INT64_C(0));
      (_resume = INT64_C(10));
      (_eof_trans = INT64_C(15));
      (_again = INT64_C(20));
      (_test_eof = INT64_C(30));
      (_out = INT64_C(40));
      while (true) {
      (_trigger_goto = false);
      if ((_goto_level <= INT64_C(0))) {
      if ((p == pe)) {
      (_goto_level = _test_eof);
      continue;
    };
      if ((iv_cs == INT64_C(0))) {
      (_goto_level = _out);
      continue;
    };
    };
      if ((_goto_level <= _resume)) {
      (_acts = _lex_from_state_actions[iv_cs]);
      (_nacts = _lex_actions[_acts]);
      (_acts = (_acts + INT64_C(1)));
      while ((_nacts > INT64_C(0))) {
      (_nacts = (_nacts - INT64_C(1)));
      (_acts = (_acts + INT64_C(1)));
      ({ auto _cs = _lex_actions[(_acts - INT64_C(1))]; ((_cs == INT64_C(24))) ? (      iv_ts = p;) : (RUBY_NIL); });
    };
      if (_trigger_goto) {
      continue;
    };
      (_keys = (iv_cs << INT64_C(1)));
      (_inds = _lex_index_offsets[iv_cs]);
      (_slen = _lex_key_spans[iv_cs]);
      (_wide = ({ auto _l = (source_pts()[p]); (_l) ? decltype((INT64_C(0)))(_l) : (INT64_C(0)); }));
      (_trans = (({ auto _l = (({ auto _l = ((_slen > INT64_C(0))); (_l) ? decltype(((_lex_trans_keys[_keys] <= _wide)))((_lex_trans_keys[_keys] <= _wide)) : decltype(((_lex_trans_keys[_keys] <= _wide)))(_l); })); (_l) ? decltype(((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])))((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])) : decltype(((_wide <= _lex_trans_keys[(_keys + INT64_C(1))])))(_l); }) ? (_lex_indicies[((_inds + _wide) - _lex_trans_keys[_keys])]) : (_lex_indicies[(_inds + _slen)])));
    };
      if ((_goto_level <= _eof_trans)) {
      iv_cs = _lex_trans_targs[_trans];
      if ((_lex_trans_actions[_trans] != INT64_C(0))) {
      (_acts = _lex_trans_actions[_trans]);
      (_nacts = _lex_actions[_acts]);
      (_acts = (_acts + INT64_C(1)));
      while ((_nacts > INT64_C(0))) {
      (_nacts = (_nacts - INT64_C(1)));
      (_acts = (_acts + INT64_C(1)));
      ({ auto _cs = _lex_actions[(_acts - INT64_C(1))]; ((_cs == INT64_C(0))) ? (      iv_newline_s = p;) : (((_cs == INT64_C(1))) ? (      unicode_points(p);) : (((_cs == INT64_C(2))) ? (      unescape_char(p);) : (((_cs == INT64_C(3))) ? (      diagnostic(ruby_sym("fatal"), ruby_sym("invalid_escape"));) : (((_cs == INT64_C(4))) ? (      read_post_meta_or_ctrl_char(p);) : (((_cs == INT64_C(5))) ? (      slash_c_char();) : (((_cs == INT64_C(6))) ? (      slash_m_char();) : (((_cs == INT64_C(7))) ? (      encode_escaped_char(p);) : (((_cs == INT64_C(8))) ? (      iv_escape = RubyString("\u007F", 1);) : (((_cs == INT64_C(9))) ? (      encode_escaped_char(p);) : (((_cs == INT64_C(10))) ? (      iv_escape = encode_escape(ruby_mod(tok(iv_escape_s, p).to_i(INT64_C(8)), INT64_C(256)));) : (((_cs == INT64_C(11))) ? (      iv_escape = encode_escape(tok((iv_escape_s + INT64_C(1)), p).to_i(INT64_C(16)));) : (((_cs == INT64_C(12))) ? (      diagnostic(ruby_sym("fatal"), ruby_sym("invalid_hex_escape"), RUBY_NIL, range((iv_escape_s - INT64_C(1)), (p + INT64_C(2))));) : (((_cs == INT64_C(13))) ? (      iv_escape = tok((iv_escape_s + INT64_C(1)), p).to_i(INT64_C(16)).chr(INT64_C(0) /* ::UTF_8 */);) : (((_cs == INT64_C(14))) ? (      check_invalid_escapes(p);) : (((_cs == INT64_C(15))) ? (      check_invalid_escapes(p);) : (((_cs == INT64_C(16))) ? (      diagnostic(ruby_sym("fatal"), ruby_sym("unterminated_unicode"), RUBY_NIL, range((p - INT64_C(1)), p));) : (((_cs == INT64_C(17))) ? (      diagnostic(ruby_sym("fatal"), ruby_sym("escape_eof"), RUBY_NIL, range((p - INT64_C(1)), p));) : (((_cs == INT64_C(18))) ? (      iv_escape_s = p;
      iv_escape = RUBY_NIL;) : (((_cs == INT64_C(19))) ? (      (interp_var_kind = ruby_sym("gvar"));) : (((_cs == INT64_C(20))) ? (      (interp_var_kind = ruby_sym("cvar"));) : (((_cs == INT64_C(21))) ? (      (interp_var_kind = ruby_sym("ivar"));) : (((_cs == INT64_C(22))) ? (      iv_escape = RUBY_NIL;) : (((_cs == INT64_C(25))) ? (      iv_te = (p + INT64_C(1));) : (((_cs == INT64_C(26))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_interp_code(current_literal);
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_value();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(27))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(28))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      auto lookahead = extend_string_slice_end(lookahead);
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype((auto token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead)))(auto token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead)) : decltype((auto token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead)))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(29))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_interp_digit_var();;) : (((_cs == INT64_C(30))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (current_literal = literal());
      extend_interp_var(current_literal);
      emit_interp_var(interp_var_kind);;) : (((_cs == INT64_C(31))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_string_escaped();;) : (((_cs == INT64_C(32))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            literal().extend_space(iv_ts, iv_te);;) : (((_cs == INT64_C(33))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(34))) ? (            (p = (iv_te - INT64_C(1)));;
            extend_string_escaped();;) : (((_cs == INT64_C(35))) ? (            (p = (iv_te - INT64_C(1)));;
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(36))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_interp_code(current_literal);
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_value();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(37))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(38))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(39))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_interp_digit_var();;) : (((_cs == INT64_C(40))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (current_literal = literal());
      extend_interp_var(current_literal);
      emit_interp_var(interp_var_kind);;) : (((_cs == INT64_C(41))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_string_escaped();;) : (((_cs == INT64_C(42))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(43))) ? (            (p = (iv_te - INT64_C(1)));;
            extend_string_escaped();;) : (((_cs == INT64_C(44))) ? (            (p = (iv_te - INT64_C(1)));;
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(45))) ? (      iv_te = (p + INT64_C(1));
            extend_string_escaped();;) : (((_cs == INT64_C(46))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(47))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(48))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            literal().extend_space(iv_ts, iv_te);;) : (((_cs == INT64_C(49))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(50))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(51))) ? (      iv_te = (p + INT64_C(1));
            extend_string_escaped();;) : (((_cs == INT64_C(52))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(53))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(54))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(55))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_interp_code(current_literal);
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_value();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(56))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(57))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(58))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_interp_digit_var();;) : (((_cs == INT64_C(59))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (current_literal = literal());
      extend_interp_var(current_literal);
      emit_interp_var(interp_var_kind);;) : (((_cs == INT64_C(60))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(61))) ? (            (p = (iv_te - INT64_C(1)));;
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(62))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(63))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(64))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_interp_code(current_literal);
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_value();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(65))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(66))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(67))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            extend_interp_digit_var();;) : (((_cs == INT64_C(68))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (current_literal = literal());
      extend_interp_var(current_literal);
      emit_interp_var(interp_var_kind);;) : (((_cs == INT64_C(69))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            literal().extend_space(iv_ts, iv_te);;) : (((_cs == INT64_C(70))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(71))) ? (            (p = (iv_te - INT64_C(1)));;
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(72))) ? (      iv_te = (p + INT64_C(1));
            (current_literal = literal());
      extend_string_eol_check_eof(current_literal, pe);
      if (current_literal.heredoc_q()) {
      (line = extend_string_eol_heredoc_line());
      if (current_literal.nest_and_try_closing(line, iv_herebody_s, iv_ts)) {
      iv_herebody_s = iv_te;
      (p = (current_literal.heredoc_e() - INT64_C(1)));
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      current_literal.infer_indent_level(line);
      iv_herebody_s = iv_te;
    };
    } else {
      if (current_literal.nest_and_try_closing(tok(), iv_ts, iv_te)) {
      iv_cs = pop_literal();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    };
      (p = extend_string_eol_heredoc_intertwined(p));
    };
      extend_string_eol_words(current_literal, p);;) : (((_cs == INT64_C(73))) ? (      iv_te = (p + INT64_C(1));
            (string = tok());
      (lookahead = extend_string_slice_end(lookahead));
      (current_literal = literal());
      if (({ auto _l = ((!(current_literal.heredoc_q()))); (_l) ? decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))) : decltype(((token = current_literal.nest_and_try_closing(string, iv_ts, iv_te, lookahead))))(_l); })) {
      if ((token[INT64_C(0)] == ruby_sym("tLABEL_END"))) {
      (p = (p + INT64_C(1)));
      pop_literal();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_labelarg();
    } else {
      if ((state = pop_literal())) {
      iv_cs = state;
    };
    };
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;
    } else {
      extend_string_for_token_range(current_literal, string);
    };;) : (((_cs == INT64_C(74))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            literal().extend_space(iv_ts, iv_te);;) : (((_cs == INT64_C(75))) ? (      iv_te = (p + INT64_C(1));
            emit(ruby_sym("tREGEXP_OPT"), tok(iv_ts, (iv_te - INT64_C(1))), iv_ts, (iv_te - INT64_C(1)));
      (p = (p - INT64_C(1)));
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(76))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (unknown_options = tok().scan(/* UNSUPPORTED: RegexpLiteral */));
      if (unknown_options.any_q()) {
      diagnostic(ruby_sym("error"), ruby_sym("regexp_options"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("options"), unknown_options.join()); _h; }));
    };
      emit(ruby_sym("tREGEXP_OPT"));
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(77))) ? (      iv_te = (p + INT64_C(1));
            (escape = ESCAPE_WHITESPACE[source_buffer().slice((iv_ts + INT64_C(1)), INT64_C(1))]);
      diagnostic(ruby_sym("warning"), ruby_sym("invalid_escape_use"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("escape"), escape); _h; }), range());
      (p = (iv_ts - INT64_C(1)));
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(78))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            emit_character_constant();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(79))) ? (      iv_te = p;
      (p = (p - INT64_C(1)));
            (p = (iv_ts - INT64_C(1)));
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(80))) ? (            (p = (iv_te - INT64_C(1)));;
            emit_character_constant();
      iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end();
            (p = (p + INT64_C(1)));
      (_trigger_goto = true);
      (_goto_level = _out);
      break;;;) : (((_cs == INT64_C(81))) ? (      iv_te = (p + INT64_C(1));
            throw Ruby_RuntimeError("bug");;) : (RUBY_NIL)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))); });
    };
    };
      if (_trigger_goto) {
      continue;
    };
    };
      if ((_goto_level <= _again)) {
      (_acts = _lex_to_state_actions[iv_cs]);
      (_nacts = _lex_actions[_acts]);
      (_acts = (_acts + INT64_C(1)));
      while ((_nacts > INT64_C(0))) {
      (_nacts = (_nacts - INT64_C(1)));
      (_acts = (_acts + INT64_C(1)));
      ({ auto _cs = _lex_actions[(_acts - INT64_C(1))]; ((_cs == INT64_C(23))) ? (      iv_ts = RUBY_NIL;) : (RUBY_NIL); });
    };
      if (_trigger_goto) {
      continue;
    };
      if ((iv_cs == INT64_C(0))) {
      (_goto_level = _out);
      continue;
    };
      (p = (p + INT64_C(1)));
      if ((p != pe)) {
      (_goto_level = _resume);
      continue;
    };
    };
      if ((_goto_level <= _test_eof)) {
      if ((p == eof)) {
      if ((_lex_eof_trans[iv_cs] > INT64_C(0))) {
      (_trans = (_lex_eof_trans[iv_cs] - INT64_C(1)));
      (_goto_level = _eof_trans);
      continue;
    };
    };
    };
      if ((_goto_level <= _out)) {
      break;
    };
    };
    if (false) {
      testEof;
    }
    return ({ auto _e0 = p; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_root_lexer_state; _a; });
  }

  RubyArray<gc_ref<RubyObject>> read_character_constant(auto p) {
    iv_cs = rb_class().lex_en_character();
    return advance(p);
  }

  RubyObject* push_literal() {
    std::fprintf(stderr, "frozone: called TI-gap stub push_literal\n"); std::abort();
    return nullptr;
  }

  RubyObject* next_state_for_literal(auto literal) {
    std::fprintf(stderr, "frozone: called TI-gap stub next_state_for_literal\n"); std::abort();
    return nullptr;
  }

  RubyObject* continue_lexing(auto current_literal) {
    std::fprintf(stderr, "frozone: called TI-gap stub continue_lexing\n"); std::abort();
    return nullptr;
  }

  RubyObject* literal() {
    std::fprintf(stderr, "frozone: called TI-gap stub literal\n"); std::abort();
    return nullptr;
  }

  RubyNil pop_literal() {
    std::decay_t<decltype(iv_literal_stack.pop())> old_literal{};
    (old_literal = iv_literal_stack.pop());
    iv_dedent_level = old_literal.dedent_level();
    if ((old_literal.type() == ruby_sym("tREGEXP_BEG"))) {
      return iv_root_lexer_state = ruby_class(iv_lexer).lex_en_inside_string(); rb_class().lex_en_regexp_modifiers();
    } else {
      return iv_root_lexer_state = ruby_class(iv_lexer).lex_en_expr_end(); RUBY_NIL;
    }
  }

  bool close_interp_on_current_literal(auto p) {
    std::decay_t<decltype(literal())> current_literal{};
    (current_literal = literal());
    if (current_literal) {
      if (current_literal.end_interp_brace_and_try_closing()) {
        return if (version_q(INT64_C(18), INT64_C(19))) {
          emit(ruby_sym("tRCURLY"), RubyString("}", 1), (p - INT64_C(1)), p);
          iv_lexer->cond().lexpop();
          iv_lexer->cmdarg().lexpop();
        } else {
          emit(ruby_sym("tSTRING_DEND"), RubyString("}", 1), (p - INT64_C(1)), p);
        }; if (current_literal.saved_herebody_s()) {
          iv_herebody_s = current_literal.saved_herebody_s();
        }; continue_lexing(current_literal); return true;
      }
      return bool(RUBY_NIL);
    }
    return bool(RUBY_NIL);
  }

  RubyNil dedent_level() {
    RubyNil dedent_level;
    auto _t32_0 = iv_dedent_level;
    auto _t32_1 = RUBY_NIL;
    dedent_level = _t32_0;
    iv_dedent_level = _t32_1;
    return dedent_level;
  }

  RubyNil on_newline(auto p) {
    if (iv_herebody_s) {
      (p = iv_herebody_s);
      iv_herebody_s = RUBY_NIL;
    }
    return p;
  }

  RubyObject* eof_codepoint_q(auto point) {
    std::fprintf(stderr, "frozone: called TI-gap stub eof_codepoint_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* version_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub version_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* tok(auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub tok\n"); std::abort();
    return nullptr;
  }

  RubyObject* range(auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub range\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit(auto type, auto value, auto s, auto e) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit\n"); std::abort();
    return nullptr;
  }

  RubyObject* diagnostic(auto type, auto reason, auto arguments, auto location, auto highlights) {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostic\n"); std::abort();
    return nullptr;
  }

  RubyObject* cond() {
    std::fprintf(stderr, "frozone: called TI-gap stub cond\n"); std::abort();
    return nullptr;
  }

  bool emit_invalid_escapes_q() {
    if ((iv_version < INT64_C(32))) {
      return true;
    }
    if (ruby_nil_q(literal())) {
      return true;
    }
    return (!(literal().regexp_q()));
  }

  RubyObject* extend_string_escaped() {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_escaped\n"); std::abort();
    return nullptr;
  }

  bool extend_interp_code(auto current_literal) {
    current_literal.flush_string();
    current_literal.extend_content();
    emit(ruby_sym("tSTRING_DBEG"), RubyString("\#{", 2));
    if (current_literal.heredoc_q()) {
      current_literal.set_saved_herebody_s(iv_herebody_s);
      iv_herebody_s = RUBY_NIL;
    }
    current_literal.start_interp_brace();
    return iv_lexer->set_command_start(true);
  }

  RubyObject* extend_interp_digit_var() {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_interp_digit_var\n"); std::abort();
    return nullptr;
  }

  RubyNil extend_string_eol_check_eof(auto current_literal, auto pe) {
    if ((iv_te == pe)) {
      return diagnostic(ruby_sym("fatal"), ruby_sym("string_eof"), RUBY_NIL, range(current_literal.str_s(), (current_literal.str_s() + INT64_C(1))));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* extend_string_eol_heredoc_line() {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_eol_heredoc_line\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_string_eol_heredoc_intertwined(auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_eol_heredoc_intertwined\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_string_eol_words(auto current_literal, auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_eol_words\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_string_slice_end(auto lookahead) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_slice_end\n"); std::abort();
    return nullptr;
  }

  RubyObject* extend_string_for_token_range(auto current_literal, auto string) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_string_for_token_range\n"); std::abort();
    return nullptr;
  }

  RubyObject* encode_escape(auto ord) {
    std::fprintf(stderr, "frozone: called TI-gap stub encode_escape\n"); std::abort();
    return nullptr;
  }

  RubyNil unescape_char(auto p) {
    std::decay_t<decltype(source_pts()[(p - INT64_C(1))])> codepoint{};
    (codepoint = source_pts()[(p - INT64_C(1))]);
    if (({ auto _l = ((iv_version >= INT64_C(30))); (_l) ? decltype((({ auto _l = ((codepoint == INT64_C(117))); (_l) ? decltype(((codepoint == INT64_C(85))))(_l) : ((codepoint == INT64_C(85))); })))(({ auto _l = ((codepoint == INT64_C(117))); (_l) ? decltype(((codepoint == INT64_C(85))))(_l) : ((codepoint == INT64_C(85))); })) : decltype((({ auto _l = ((codepoint == INT64_C(117))); (_l) ? decltype(((codepoint == INT64_C(85))))(_l) : ((codepoint == INT64_C(85))); })))(_l); })) {
      diagnostic(ruby_sym("fatal"), ruby_sym("invalid_escape"));
    }
    if (ruby_nil_q(iv_escape = ESCAPES[codepoint])) {
      return iv_escape = encode_escape(source_buffer().slice((p - INT64_C(1)), INT64_C(1)));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* unicode_points(auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub unicode_points\n"); std::abort();
    return nullptr;
  }

  RubyNil read_post_meta_or_ctrl_char(auto p) {
    iv_escape = source_buffer().slice((p - INT64_C(1)), INT64_C(1)).chr();
    if (({ auto _l = ((iv_version >= INT64_C(27))); (_l) ? decltype((({ auto _l = ((INT64_C(8) + 1LL).include_q(iv_escape.ord())); (_l) ? decltype(((INT64_C(31) + 1LL).include_q(iv_escape.ord())))(_l) : ((INT64_C(31) + 1LL).include_q(iv_escape.ord())); })))(({ auto _l = ((INT64_C(8) + 1LL).include_q(iv_escape.ord())); (_l) ? decltype(((INT64_C(31) + 1LL).include_q(iv_escape.ord())))(_l) : ((INT64_C(31) + 1LL).include_q(iv_escape.ord())); })) : decltype((({ auto _l = ((INT64_C(8) + 1LL).include_q(iv_escape.ord())); (_l) ? decltype(((INT64_C(31) + 1LL).include_q(iv_escape.ord())))(_l) : ((INT64_C(31) + 1LL).include_q(iv_escape.ord())); })))(_l); })) {
      return diagnostic(ruby_sym("fatal"), ruby_sym("invalid_escape"));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* extend_interp_var(auto current_literal) {
    std::fprintf(stderr, "frozone: called TI-gap stub extend_interp_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_interp_var(auto interp_var_kind) {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_interp_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* encode_escaped_char(auto p) {
    std::fprintf(stderr, "frozone: called TI-gap stub encode_escaped_char\n"); std::abort();
    return nullptr;
  }

  RubyObject* slash_c_char() {
    std::fprintf(stderr, "frozone: called TI-gap stub slash_c_char\n"); std::abort();
    return nullptr;
  }

  RubyObject* slash_m_char() {
    std::fprintf(stderr, "frozone: called TI-gap stub slash_m_char\n"); std::abort();
    return nullptr;
  }

  RubyObject* emit_character_constant() {
    std::fprintf(stderr, "frozone: called TI-gap stub emit_character_constant\n"); std::abort();
    return nullptr;
  }

  RubyNil check_ambiguous_slash(auto tm) {
    if ((tok(tm, (tm + INT64_C(1))) == RubyString("/", 1))) {
      if ((iv_version < INT64_C(30))) {
        return diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_literal"), RUBY_NIL, range(tm, (tm + INT64_C(1))));
      } else {
        return diagnostic(ruby_sym("warning"), ruby_sym("ambiguous_regexp"), RUBY_NIL, range(tm, (tm + INT64_C(1))));
      }
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil check_invalid_escapes(auto p) {
    if (emit_invalid_escapes_q()) {
      return diagnostic(ruby_sym("fatal"), ruby_sym("invalid_unicode_escape"), RUBY_NIL, range((iv_escape_s - INT64_C(1)), p));
    }
    return RubyNil(RUBY_NIL);
  }

};
template<> inline const char* ruby_class_name<Ruby_LexerStrings>() { return "LexerStrings"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_LexerStrings> : dustman::FieldList<Ruby_LexerStrings> {};
#endif

struct Ruby_Default : public RubyObject {
  gc_ref<RubyObject> iv_parser = nullptr;
  bool iv_emit_file_line_as_literals = false;

  Ruby_Default() {
    iv_emit_file_line_as_literals = true;
  }
  const char* rb_class_name() const override { return "Default"; }

  RubyObject* parser() {
    std::fprintf(stderr, "frozone: called TI-gap stub parser\n"); std::abort();
    return nullptr;
  }

  RubyObject* set_parser(auto __anon_req__) {
    std::fprintf(stderr, "frozone: called TI-gap stub set_parser\n"); std::abort();
    return nullptr;
  }

  bool emit_file_line_as_literals() {
    return iv_emit_file_line_as_literals;
  }

  bool set_emit_file_line_as_literals(auto __anon_req__) {
    iv_emit_file_line_as_literals = __anon_req__;
    return iv_emit_file_line_as_literals;
  }

  RubyObject* nil(auto nil_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub nil\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_true(auto true_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_true\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_false(auto false_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_false\n"); std::abort();
    return nullptr;
  }

  RubyObject* integer(auto integer_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub integer\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_float(auto float_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_float\n"); std::abort();
    return nullptr;
  }

  RubyObject* rational(auto rational_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rational\n"); std::abort();
    return nullptr;
  }

  RubyObject* complex(auto complex_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub complex\n"); std::abort();
    return nullptr;
  }

  RubyObject* numeric(auto kind, auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub numeric\n"); std::abort();
    return nullptr;
  }

  RubyObject* unary_num(auto unary_t, auto numeric) {
    std::fprintf(stderr, "frozone: called TI-gap stub unary_num\n"); std::abort();
    return nullptr;
  }

  RubyObject* __LINE__(auto __LINE__t) {
    std::fprintf(stderr, "frozone: called TI-gap stub __LINE__\n"); std::abort();
    return nullptr;
  }

  RubyObject* string(auto string_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub string\n"); std::abort();
    return nullptr;
  }

  RubyObject* string_internal(auto string_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub string_internal\n"); std::abort();
    return nullptr;
  }

  RubyObject* string_compose(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub string_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* character(auto char_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub character\n"); std::abort();
    return nullptr;
  }

  RubyObject* __FILE__(auto __FILE__t) {
    std::fprintf(stderr, "frozone: called TI-gap stub __FILE__\n"); std::abort();
    return nullptr;
  }

  RubyObject* symbol(auto symbol_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub symbol\n"); std::abort();
    return nullptr;
  }

  RubyObject* symbol_internal(auto symbol_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub symbol_internal\n"); std::abort();
    return nullptr;
  }

  RubyObject* symbol_compose(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub symbol_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* xstring_compose(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub xstring_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* dedent_string(auto node, auto dedent_level) {
    std::fprintf(stderr, "frozone: called TI-gap stub dedent_string\n"); std::abort();
    return nullptr;
  }

  RubyObject* regexp_options(auto regopt_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub regexp_options\n"); std::abort();
    return nullptr;
  }

  RubyObject* regexp_compose(auto begin_t, auto parts, auto end_t, auto options) {
    std::fprintf(stderr, "frozone: called TI-gap stub regexp_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* array(auto begin_t, auto elements, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub array\n"); std::abort();
    return nullptr;
  }

  RubyObject* splat(auto star_t, auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub splat\n"); std::abort();
    return nullptr;
  }

  RubyObject* word(auto parts) {
    std::fprintf(stderr, "frozone: called TI-gap stub word\n"); std::abort();
    return nullptr;
  }

  RubyObject* words_compose(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub words_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* symbols_compose(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub symbols_compose\n"); std::abort();
    return nullptr;
  }

  RubyObject* pair(auto key, auto assoc_t, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub pair\n"); std::abort();
    return nullptr;
  }

  RubyObject* pair_list_18(auto list) {
    std::fprintf(stderr, "frozone: called TI-gap stub pair_list_18\n"); std::abort();
    return nullptr;
  }

  RubyObject* pair_keyword(auto key_t, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub pair_keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* pair_quoted(auto begin_t, auto parts, auto end_t, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub pair_quoted\n"); std::abort();
    return nullptr;
  }

  RubyObject* pair_label(auto key_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub pair_label\n"); std::abort();
    return nullptr;
  }

  RubyObject* kwsplat(auto dstar_t, auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwsplat\n"); std::abort();
    return nullptr;
  }

  RubyObject* associate(auto begin_t, auto pairs, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub associate\n"); std::abort();
    return nullptr;
  }

  RubyObject* range_inclusive(auto lhs, auto dot2_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub range_inclusive\n"); std::abort();
    return nullptr;
  }

  RubyObject* range_exclusive(auto lhs, auto dot3_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub range_exclusive\n"); std::abort();
    return nullptr;
  }

  RubyObject* self(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub self\n"); std::abort();
    return nullptr;
  }

  RubyObject* ident(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub ident\n"); std::abort();
    return nullptr;
  }

  RubyObject* ivar(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub ivar\n"); std::abort();
    return nullptr;
  }

  RubyObject* gvar(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub gvar\n"); std::abort();
    return nullptr;
  }

  RubyObject* cvar(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub cvar\n"); std::abort();
    return nullptr;
  }

  RubyObject* back_ref(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub back_ref\n"); std::abort();
    return nullptr;
  }

  RubyObject* nth_ref(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub nth_ref\n"); std::abort();
    return nullptr;
  }

  RubyObject* accessible(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub accessible\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_const(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_const\n"); std::abort();
    return nullptr;
  }

  RubyObject* const_global(auto t_colon3, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub const_global\n"); std::abort();
    return nullptr;
  }

  RubyObject* const_fetch(auto scope, auto t_colon2, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub const_fetch\n"); std::abort();
    return nullptr;
  }

  RubyObject* __ENCODING__(auto __ENCODING__t) {
    std::fprintf(stderr, "frozone: called TI-gap stub __ENCODING__\n"); std::abort();
    return nullptr;
  }

  RubyObject* assignable(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub assignable\n"); std::abort();
    return nullptr;
  }

  RubyObject* const_op_assignable(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub const_op_assignable\n"); std::abort();
    return nullptr;
  }

  RubyObject* assign(auto lhs, auto eql_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub assign\n"); std::abort();
    return nullptr;
  }

  RubyObject* op_assign(auto lhs, auto op_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub op_assign\n"); std::abort();
    return nullptr;
  }

  RubyObject* multi_lhs(auto begin_t, auto items, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub multi_lhs\n"); std::abort();
    return nullptr;
  }

  RubyObject* multi_assign(auto lhs, auto eql_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub multi_assign\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_class(auto class_t, auto name, auto lt_t, auto superclass, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_class\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_sclass(auto class_t, auto lshft_t, auto expr, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_sclass\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_module(auto module_t, auto name, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_module\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_method(auto def_t, auto name_t, auto args, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_endless_method(auto def_t, auto name_t, auto args, auto assignment_t, auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_endless_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_singleton(auto def_t, auto definee, auto dot_t, auto name_t, auto args, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_singleton\n"); std::abort();
    return nullptr;
  }

  RubyObject* def_endless_singleton(auto def_t, auto definee, auto dot_t, auto name_t, auto args, auto assignment_t, auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub def_endless_singleton\n"); std::abort();
    return nullptr;
  }

  RubyObject* undef_method(auto undef_t, auto names) {
    std::fprintf(stderr, "frozone: called TI-gap stub undef_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* alias(auto alias_t, auto to, auto from) {
    std::fprintf(stderr, "frozone: called TI-gap stub alias\n"); std::abort();
    return nullptr;
  }

  RubyObject* args(auto begin_t, auto args, auto end_t, auto check_args) {
    std::fprintf(stderr, "frozone: called TI-gap stub args\n"); std::abort();
    return nullptr;
  }

  RubyObject* numargs(auto max_numparam) {
    std::fprintf(stderr, "frozone: called TI-gap stub numargs\n"); std::abort();
    return nullptr;
  }

  RubyObject* forward_only_args(auto begin_t, auto dots_t, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub forward_only_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* forward_arg(auto dots_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub forward_arg\n"); std::abort();
    return nullptr;
  }

  RubyObject* arg(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub arg\n"); std::abort();
    return nullptr;
  }

  RubyObject* optarg(auto name_t, auto eql_t, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub optarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* restarg(auto star_t, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub restarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* kwarg(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* kwoptarg(auto name_t, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwoptarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* kwrestarg(auto dstar_t, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwrestarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* kwnilarg(auto dstar_t, auto nil_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwnilarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* shadowarg(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub shadowarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* blockarg(auto amper_t, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub blockarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* procarg0(auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub procarg0\n"); std::abort();
    return nullptr;
  }

  RubyObject* arg_expr(auto expr) {
    std::fprintf(stderr, "frozone: called TI-gap stub arg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* restarg_expr(auto star_t, auto expr) {
    std::fprintf(stderr, "frozone: called TI-gap stub restarg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* blockarg_expr(auto amper_t, auto expr) {
    std::fprintf(stderr, "frozone: called TI-gap stub blockarg_expr\n"); std::abort();
    return nullptr;
  }

  RubyObject* objc_kwarg(auto kwname_t, auto assoc_t, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub objc_kwarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* objc_restarg(auto star_t, auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub objc_restarg\n"); std::abort();
    return nullptr;
  }

  RubySymbol call_type_for_dot(auto dot_t) {
    if (({ auto _l = ((!(ruby_nil_q(dot_t)))); (_l) ? decltype(((value(dot_t) == ruby_sym("anddot"))))((value(dot_t) == ruby_sym("anddot"))) : decltype(((value(dot_t) == ruby_sym("anddot"))))(_l); })) {
      return ruby_sym("csend");
    } else {
      return ruby_sym("send");
    }
  }

  RubyObject* forwarded_args(auto dots_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub forwarded_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* forwarded_restarg(auto star_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub forwarded_restarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* forwarded_kwrestarg(auto dstar_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub forwarded_kwrestarg\n"); std::abort();
    return nullptr;
  }

  RubyObject* call_method(auto receiver, auto dot_t, auto selector_t, auto lparen_t, auto args, auto rparen_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub call_method\n"); std::abort();
    return nullptr;
  }

  RubyObject* call_lambda(auto lambda_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub call_lambda\n"); std::abort();
    return nullptr;
  }

  RubyObject* block(auto method_call, auto begin_t, auto args, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub block\n"); std::abort();
    return nullptr;
  }

  RubyObject* block_pass(auto amper_t, auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub block_pass\n"); std::abort();
    return nullptr;
  }

  RubyObject* objc_varargs(auto pair, auto rest_of_varargs) {
    std::fprintf(stderr, "frozone: called TI-gap stub objc_varargs\n"); std::abort();
    return nullptr;
  }

  RubyObject* attr_asgn(auto receiver, auto dot_t, auto selector_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub attr_asgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* index(auto receiver, auto lbrack_t, auto indexes, auto rbrack_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub index\n"); std::abort();
    return nullptr;
  }

  RubyObject* index_asgn(auto receiver, auto lbrack_t, auto indexes, auto rbrack_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub index_asgn\n"); std::abort();
    return nullptr;
  }

  RubyObject* binary_op(auto receiver, auto operator_t, auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub binary_op\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_op(auto receiver, auto match_t, auto arg) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_op\n"); std::abort();
    return nullptr;
  }

  RubyObject* unary_op(auto op_t, auto receiver) {
    std::fprintf(stderr, "frozone: called TI-gap stub unary_op\n"); std::abort();
    return nullptr;
  }

  RubyObject* not_op(auto not_t, auto begin_t, auto receiver, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub not_op\n"); std::abort();
    return nullptr;
  }

  RubyObject* logical_op(auto type, auto lhs, auto op_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub logical_op\n"); std::abort();
    return nullptr;
  }

  RubyObject* condition(auto cond_t, auto cond, auto then_t, auto if_true, auto else_t, auto if_false, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub condition\n"); std::abort();
    return nullptr;
  }

  RubyObject* condition_mod(auto if_true, auto if_false, auto cond_t, auto cond) {
    std::fprintf(stderr, "frozone: called TI-gap stub condition_mod\n"); std::abort();
    return nullptr;
  }

  RubyObject* ternary(auto cond, auto question_t, auto if_true, auto colon_t, auto if_false) {
    std::fprintf(stderr, "frozone: called TI-gap stub ternary\n"); std::abort();
    return nullptr;
  }

  RubyObject* when(auto when_t, auto patterns, auto then_t, auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub when\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_case(auto case_t, auto expr, auto when_bodies, auto else_t, auto else_body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_case\n"); std::abort();
    return nullptr;
  }

  RubyObject* loop(auto type, auto keyword_t, auto cond, auto do_t, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub loop\n"); std::abort();
    return nullptr;
  }

  RubyObject* loop_mod(auto type, auto body, auto keyword_t, auto cond) {
    std::fprintf(stderr, "frozone: called TI-gap stub loop_mod\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_for(auto for_t, auto iterator, auto in_t, auto iteratee, auto do_t, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_for\n"); std::abort();
    return nullptr;
  }

  RubyObject* keyword_cmd(auto type, auto keyword_t, auto lparen_t, auto args, auto rparen_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub keyword_cmd\n"); std::abort();
    return nullptr;
  }

  RubyObject* preexe(auto preexe_t, auto lbrace_t, auto compstmt, auto rbrace_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub preexe\n"); std::abort();
    return nullptr;
  }

  RubyObject* postexe(auto postexe_t, auto lbrace_t, auto compstmt, auto rbrace_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub postexe\n"); std::abort();
    return nullptr;
  }

  RubyObject* rescue_body(auto rescue_t, auto exc_list, auto assoc_t, auto exc_var, auto then_t, auto compound_stmt) {
    std::fprintf(stderr, "frozone: called TI-gap stub rescue_body\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin_body(auto compound_stmt, auto rescue_bodies, auto else_t, auto else_, auto ensure_t, auto ensure_) {
    std::fprintf(stderr, "frozone: called TI-gap stub begin_body\n"); std::abort();
    return nullptr;
  }

  RubyObject* compstmt(auto statements) {
    std::fprintf(stderr, "frozone: called TI-gap stub compstmt\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin(auto begin_t, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub begin\n"); std::abort();
    return nullptr;
  }

  RubyObject* begin_keyword(auto begin_t, auto body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub begin_keyword\n"); std::abort();
    return nullptr;
  }

  RubyObject* case_match(auto case_t, auto expr, auto in_bodies, auto else_t, auto else_body, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub case_match\n"); std::abort();
    return nullptr;
  }

  RubyObject* in_match(auto lhs, auto in_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub in_match\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_pattern(auto lhs, auto match_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_pattern_p(auto lhs, auto match_t, auto rhs) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_pattern_p\n"); std::abort();
    return nullptr;
  }

  RubyObject* in_pattern(auto in_t, auto pattern, auto guard, auto then_t, auto body) {
    std::fprintf(stderr, "frozone: called TI-gap stub in_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* if_guard(auto if_t, auto if_body) {
    std::fprintf(stderr, "frozone: called TI-gap stub if_guard\n"); std::abort();
    return nullptr;
  }

  RubyObject* unless_guard(auto unless_t, auto unless_body) {
    std::fprintf(stderr, "frozone: called TI-gap stub unless_guard\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_var(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_hash_var(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_hash_var\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_hash_var_from_str(auto begin_t, auto strings, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_hash_var_from_str\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_rest(auto star_t, auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_rest\n"); std::abort();
    return nullptr;
  }

  RubyObject* hash_pattern(auto lbrace_t, auto kwargs, auto rbrace_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub hash_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* array_pattern(auto lbrack_t, auto elements, auto rbrack_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub array_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* find_pattern(auto lbrack_t, auto elements, auto rbrack_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub find_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_with_trailing_comma(auto match, auto comma_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_with_trailing_comma\n"); std::abort();
    return nullptr;
  }

  RubyObject* const_pattern(auto const, auto ldelim_t, auto pattern, auto rdelim_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub const_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* pin(auto pin_t, auto var) {
    std::fprintf(stderr, "frozone: called TI-gap stub pin\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_alt(auto left, auto pipe_t, auto right) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_alt\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_as(auto value, auto assoc_t, auto as) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_as\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_nil_pattern(auto dstar_t, auto nil_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_nil_pattern\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_pair(auto label_type, auto label, auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_pair\n"); std::abort();
    return nullptr;
  }

  RubyObject* match_label(auto label_type, auto label) {
    std::fprintf(stderr, "frozone: called TI-gap stub match_label\n"); std::abort();
    return nullptr;
  }

  RubyObject* check_condition(auto cond) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_condition\n"); std::abort();
    return nullptr;
  }

  RubyObject* check_duplicate_args(auto args, auto map) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_duplicate_args\n"); std::abort();
    return nullptr;
  }

  RubyNil check_duplicate_arg(auto this_arg, RubyHash<RubySymbol, int64_t> map = RubyHash<RubySymbol, int64_t>{}) {
    int64_t this_name = 0;
    std::decay_t<decltype(map[this_name])> that_arg{};
    int64_t that_name = 0;
    auto _t33_0 = /* UNSUPPORTED: SplatArg */;
    this_name = _t33_0;
    /* UNSUPPORTED masgn target: splat_nil */;
    (that_arg = map[this_name]);
    auto _t34_0 = /* UNSUPPORTED: SplatArg */;
    that_name = _t34_0;
    /* UNSUPPORTED masgn target: splat_nil */;
    if (ruby_nil_q(that_arg)) {
      return map[this_name] = this_arg;
    } else {
      if (arg_name_collides_q(this_name, that_name)) {
        return diagnostic(ruby_sym("error"), ruby_sym("duplicate_argument"), RUBY_NIL, this_arg.loc().name(), ({ auto _e0 = that_arg.loc().name(); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyNil validate_no_forward_arg_after_restarg(auto args) {
    RubyNil restarg;
    RubyNil forward_arg;
    (restarg = RUBY_NIL);
    (forward_arg = RUBY_NIL);
    { auto _coll = args; for (auto& arg : *_coll.data) {
      ({ auto _cs = arg.type(); ((_cs == ruby_sym("restarg"))) ? ((restarg = arg)) : (((_cs == ruby_sym("forward_arg"))) ? ((forward_arg = arg)) : (RUBY_NIL)); });
    } }
    if (({ auto _l = ((!(ruby_nil_q(forward_arg)))); (_l) ? decltype(((!(ruby_nil_q(restarg)))))((!(ruby_nil_q(restarg)))) : decltype(((!(ruby_nil_q(restarg)))))(_l); })) {
      return diagnostic(ruby_sym("error"), ruby_sym("forward_arg_after_restarg"), RUBY_NIL, forward_arg.loc().expression(), ({ auto _e0 = restarg.loc().expression(); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil check_assignment_to_numparam(auto name, auto loc) {
    if ((iv_parser->version() < INT64_C(27))) {
      return RubyNil(RUBY_NIL);
    }
    auto assigning_to_numparam = ({ auto _l = (({ auto _l = (iv_parser->context().in_dynamic_block_q()); (_l) ? decltype((name.=~(/* UNSUPPORTED: RegexpLiteral */)))(name.=~(/* UNSUPPORTED: RegexpLiteral */)) : decltype((name.=~(/* UNSUPPORTED: RegexpLiteral */)))(_l); })); (_l) ? decltype((iv_parser->max_numparam_stack().has_numparams_q()))(iv_parser->max_numparam_stack().has_numparams_q()) : decltype((iv_parser->max_numparam_stack().has_numparams_q()))(_l); });
    if (assigning_to_numparam) {
      return diagnostic(ruby_sym("error"), ruby_sym("cant_assign_to_numparam"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), name); _h; }), loc);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil check_reserved_for_numparam(auto name, auto loc) {
    if ((iv_parser->version() < INT64_C(30))) {
      return RubyNil(RUBY_NIL);
    }
    if (name.=~(/* UNSUPPORTED: RegexpLiteral */)) {
      return diagnostic(ruby_sym("error"), ruby_sym("reserved_for_numparam"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), name); _h; }), loc);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* arg_name_collides_q(auto this_name, auto that_name) {
    std::fprintf(stderr, "frozone: called TI-gap stub arg_name_collides_q\n"); std::abort();
    return nullptr;
  }

  RubyNil check_lvar_name(auto name, auto loc) {
    if (name.=~(/* UNSUPPORTED: RegexpLiteral */)) {
      return RubyNil(RUBY_NIL);
    } else {
      return diagnostic(ruby_sym("error"), ruby_sym("lvar_name"), ({ RubyHash<RubySymbol, auto> _h; _h.store(ruby_sym("name"), name); _h; }), loc);
    }
  }

  RubyObject* check_duplicate_pattern_variable(auto name, auto loc) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_duplicate_pattern_variable\n"); std::abort();
    return nullptr;
  }

  RubyObject* check_duplicate_pattern_key(auto name, auto loc) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_duplicate_pattern_key\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Node> n(auto type, auto children, auto source_map) {
    return gc_new<Ruby_Node>(type, children);
  }

  RubyObject* n0(auto type, auto source_map) {
    std::fprintf(stderr, "frozone: called TI-gap stub n0\n"); std::abort();
    return nullptr;
  }

  RubyObject* join_exprs(auto left_expr, auto right_expr) {
    std::fprintf(stderr, "frozone: called TI-gap stub join_exprs\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Map> token_map(auto token) {
    return gc_new<Ruby_Map>(loc(token));
  }

  gc_ref<Ruby_Collection> delimited_string_map(auto string_t) {
    RubyNil str_range;
    std::decay_t<decltype(str_range.with())> begin_l{};
    std::decay_t<decltype(str_range.with())> end_l{};
    (str_range = loc(string_t));
    (begin_l = str_range.with());
    (end_l = str_range.with());
    return gc_new<Ruby_Collection>(begin_l, end_l, loc(string_t));
  }

  gc_ref<Ruby_Collection> prefix_string_map(auto symbol) {
    RubyNil str_range;
    std::decay_t<decltype(str_range.with())> begin_l{};
    (str_range = loc(symbol));
    (begin_l = str_range.with());
    return gc_new<Ruby_Collection>(begin_l, RUBY_NIL, loc(symbol));
  }

  gc_ref<Ruby_Collection> unquoted_map(auto token) {
    return gc_new<Ruby_Collection>(RUBY_NIL, RUBY_NIL, loc(token));
  }

  RubyArray<int64_t> pair_keyword_map(auto key_t, auto value_e) {
    RubyNil key_range;
    std::decay_t<decltype(key_range.adjust())> key_l{};
    std::decay_t<decltype(key_range.with())> colon_l{};
    (key_range = loc(key_t));
    (key_l = key_range.adjust());
    (colon_l = key_range.with());
    return ({ auto _e0 = gc_new<Ruby_Collection>(RUBY_NIL, RUBY_NIL, key_l); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = gc_new<Ruby_Operator>(colon_l, key_range.join(value_e.loc().expression())); _a; });
  }

  RubyArray<RubyArray<int64_t>> pair_quoted_map(auto begin_t, auto end_t, auto value_e) {
    RubyNil end_l;
    std::decay_t<decltype(end_l.with())> quote_l{};
    std::decay_t<decltype(end_l.with())> colon_l{};
    (end_l = loc(end_t));
    (quote_l = end_l.with());
    (colon_l = end_l.with());
    return ({ auto _e0 = ({ auto _e0 = value(end_t); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = quote_l; _a; }); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = gc_new<Ruby_Operator>(colon_l, loc(begin_t).join(value_e.loc().expression())); _a; });
  }

  gc_ref<Ruby_Map> expr_map(auto loc) {
    return gc_new<Ruby_Map>(loc);
  }

  gc_ref<Ruby_Collection> collection_map(auto begin_t, auto parts, auto end_t) {
    RubyNil expr_l;
    if (({ auto _l = (ruby_nil_q(begin_t)); (_l) ? decltype((ruby_nil_q(end_t)))(_l) : (ruby_nil_q(end_t)); })) {
      if (parts.any_q()) {
      (expr_l = join_exprs(parts.first(), parts.last()));
    } else {
      if ((!(ruby_nil_q(begin_t)))) {
      (expr_l = loc(begin_t));
    } else {
      if ((!(ruby_nil_q(end_t)))) {
      (expr_l = loc(end_t));
    };
    };
    };
    } else {
      (expr_l = loc(begin_t).join(loc(end_t)));
    }
    return gc_new<Ruby_Collection>(loc(begin_t), loc(end_t), expr_l);
  }

  RubyObject* string_map(auto begin_t, auto parts, auto end_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub string_map\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Collection> regexp_map(auto begin_t, auto end_t, auto options_e) {
    return gc_new<Ruby_Collection>(loc(begin_t), loc(end_t), loc(begin_t).join(options_e.loc().expression()));
  }

  gc_ref<Ruby_Constant> constant_map(auto scope, auto colon2_t, auto name_t) {
    RubyNil expr_l;
    (ruby_nil_q(scope) ? ((expr_l = loc(name_t))) : ((expr_l = scope.loc().expression().join(loc(name_t)))));
    return gc_new<Ruby_Constant>(loc(colon2_t), loc(name_t), expr_l);
  }

  gc_ref<Ruby_Variable> variable_map(auto name_t) {
    return gc_new<Ruby_Variable>(loc(name_t));
  }

  gc_ref<Ruby_Operator> binary_op_map(auto left_e, auto op_t, auto right_e) {
    return gc_new<Ruby_Operator>(loc(op_t), join_exprs(left_e, right_e));
  }

  gc_ref<Ruby_Operator> unary_op_map(auto op_t, auto arg_e = RUBY_NIL) {
    RubyNil expr_l;
    (ruby_nil_q(arg_e) ? ((expr_l = loc(op_t))) : ((expr_l = loc(op_t).join(arg_e.loc().expression()))));
    return gc_new<Ruby_Operator>(loc(op_t), expr_l);
  }

  gc_ref<Ruby_Operator> range_map(auto start_e, auto op_t, auto end_e) {
    std::decay_t<decltype(join_exprs(start_e, end_e))> expr_l{};
    if (({ auto _l = (start_e); (_l) ? decltype((end_e))(end_e) : decltype((end_e))(_l); })) {
      (expr_l = join_exprs(start_e, end_e));
    } else {
      if (start_e) {
      (expr_l = start_e.loc().expression().join(loc(op_t)));
    } else {
      if (end_e) {
      (expr_l = loc(op_t).join(end_e.loc().expression()));
    };
    };
    }
    return gc_new<Ruby_Operator>(loc(op_t), expr_l);
  }

  gc_ref<Ruby_Variable> arg_prefix_map(auto op_t, auto name_t = RUBY_NIL) {
    RubyNil expr_l;
    (ruby_nil_q(name_t) ? ((expr_l = loc(op_t))) : ((expr_l = loc(op_t).join(loc(name_t)))));
    return gc_new<Ruby_Variable>(loc(name_t), expr_l);
  }

  gc_ref<Ruby_Variable> kwarg_map(auto name_t, auto value_e = RUBY_NIL) {
    RubyNil label_range;
    std::decay_t<decltype(label_range.adjust())> name_range{};
    RubyNil expr_l;
    (label_range = loc(name_t));
    (name_range = label_range.adjust());
    (value_e ? ((expr_l = loc(name_t).join(value_e.loc().expression()))) : ((expr_l = loc(name_t))));
    return gc_new<Ruby_Variable>(name_range, expr_l);
  }

  gc_ref<Ruby_Definition> module_definition_map(auto keyword_t, auto name_e, auto operator_t, auto end_t) {
    std::decay_t<decltype(name_e.loc().expression())> name_l{};
    if (name_e) {
      (name_l = name_e.loc().expression());
    }
    return gc_new<Ruby_Definition>(loc(keyword_t), loc(operator_t), name_l, loc(end_t));
  }

  gc_ref<Ruby_MethodDefinition> definition_map(auto keyword_t, auto operator_t, auto name_t, auto end_t) {
    return gc_new<Ruby_MethodDefinition>(loc(keyword_t), loc(operator_t), loc(name_t), loc(end_t), RUBY_NIL, RUBY_NIL);
  }

  gc_ref<Ruby_MethodDefinition> endless_definition_map(auto keyword_t, auto operator_t, auto name_t, auto assignment_t, auto body_e) {
    std::decay_t<decltype(body_e.loc().expression())> body_l{};
    (body_l = body_e.loc().expression());
    return gc_new<Ruby_MethodDefinition>(loc(keyword_t), loc(operator_t), loc(name_t), RUBY_NIL, loc(assignment_t), body_l);
  }

  gc_ref<Ruby_Send> send_map(auto receiver_e, auto dot_t, auto selector_t, auto begin_t = RUBY_NIL, RubyArray_I64 args = RubyArray_I64(0), auto end_t = RUBY_NIL) {
    RubyNil begin_l;
    RubyNil end_l;
    if (receiver_e) {
      (begin_l = receiver_e.loc().expression());
    } else {
      if (selector_t) {
      (begin_l = loc(selector_t));
    };
    }
    if (end_t) {
      (end_l = loc(end_t));
    } else {
      if (args.any_q()) {
      (end_l = args.last().loc().expression());
    } else {
      if (selector_t) {
      (end_l = loc(selector_t));
    };
    };
    }
    return gc_new<Ruby_Send>(loc(dot_t), loc(selector_t), loc(begin_t), loc(end_t), begin_l.join(end_l));
  }

  gc_ref<Ruby_Send> var_send_map(auto variable_e) {
    return gc_new<Ruby_Send>(RUBY_NIL, variable_e.loc().expression(), RUBY_NIL, RUBY_NIL, variable_e.loc().expression());
  }

  gc_ref<Ruby_Send> send_binary_op_map(auto lhs_e, auto selector_t, auto rhs_e) {
    return gc_new<Ruby_Send>(RUBY_NIL, loc(selector_t), RUBY_NIL, RUBY_NIL, join_exprs(lhs_e, rhs_e));
  }

  gc_ref<Ruby_Send> send_unary_op_map(auto selector_t, auto arg_e) {
    RubyNil expr_l;
    (ruby_nil_q(arg_e) ? ((expr_l = loc(selector_t))) : ((expr_l = loc(selector_t).join(arg_e.loc().expression()))));
    return gc_new<Ruby_Send>(RUBY_NIL, loc(selector_t), RUBY_NIL, RUBY_NIL, expr_l);
  }

  gc_ref<Ruby_Index> index_map(auto receiver_e, auto lbrack_t, auto rbrack_t) {
    return gc_new<Ruby_Index>(loc(lbrack_t), loc(rbrack_t), receiver_e.loc().expression().join(loc(rbrack_t)));
  }

  gc_ref<Ruby_Send> send_index_map(auto receiver_e, auto lbrack_t, auto rbrack_t) {
    return gc_new<Ruby_Send>(RUBY_NIL, loc(lbrack_t).join(loc(rbrack_t)), RUBY_NIL, RUBY_NIL, receiver_e.loc().expression().join(loc(rbrack_t)));
  }

  gc_ref<Ruby_Collection> block_map(auto receiver_l, auto begin_t, auto end_t) {
    return gc_new<Ruby_Collection>(loc(begin_t), loc(end_t), receiver_l.join(loc(end_t)));
  }

  gc_ref<Ruby_Keyword> keyword_map(auto keyword_t, auto begin_t, auto args, auto end_t) {
    RubyNil end_l;
    ({ auto _l = (args); (_l) ? decltype(((args = RubyArray_I64(0))))(_l) : ((args = RubyArray_I64(0))); });
    if (end_t) {
      (end_l = loc(end_t));
    } else {
      if (({ auto _l = (args.any_q()); (_l) ? decltype(((!(ruby_nil_q(args.last())))))((!(ruby_nil_q(args.last())))) : decltype(((!(ruby_nil_q(args.last())))))(_l); })) {
      (end_l = args.last().loc().expression());
    } else {
      (({ auto _l = (args.any_q()); (_l) ? decltype(((args.count() > INT64_C(1))))((args.count() > INT64_C(1))) : decltype(((args.count() > INT64_C(1))))(_l); }) ? ((end_l = args[INT64_C(-2)].loc().expression())) : ((end_l = loc(keyword_t))));
    };
    }
    return gc_new<Ruby_Keyword>(loc(keyword_t), loc(begin_t), loc(end_t), loc(keyword_t).join(end_l));
  }

  gc_ref<Ruby_Keyword> keyword_mod_map(auto pre_e, auto keyword_t, auto post_e) {
    return gc_new<Ruby_Keyword>(loc(keyword_t), RUBY_NIL, RUBY_NIL, join_exprs(pre_e, post_e));
  }

  gc_ref<Ruby_Condition> condition_map(auto keyword_t, auto cond_e, auto begin_t, auto body_e, auto else_t, auto else_e, auto end_t) {
    RubyNil end_l;
    if (end_t) {
      (end_l = loc(end_t));
    } else {
      if (({ auto _l = (else_e); (_l) ? decltype((else_e.loc().expression()))(else_e.loc().expression()) : decltype((else_e.loc().expression()))(_l); })) {
      (end_l = else_e.loc().expression());
    } else {
      if (loc(else_t)) {
      (end_l = loc(else_t));
    } else {
      if (({ auto _l = (body_e); (_l) ? decltype((body_e.loc().expression()))(body_e.loc().expression()) : decltype((body_e.loc().expression()))(_l); })) {
      (end_l = body_e.loc().expression());
    } else {
      (loc(begin_t) ? ((end_l = loc(begin_t))) : ((end_l = cond_e.loc().expression())));
    };
    };
    };
    }
    return gc_new<Ruby_Condition>(loc(keyword_t), loc(begin_t), loc(else_t), loc(end_t), loc(keyword_t).join(end_l));
  }

  gc_ref<Ruby_Ternary> ternary_map(auto begin_e, auto question_t, auto mid_e, auto colon_t, auto end_e) {
    return gc_new<Ruby_Ternary>(loc(question_t), loc(colon_t), join_exprs(begin_e, end_e));
  }

  gc_ref<Ruby_For> for_map(auto keyword_t, auto in_t, auto begin_t, auto end_t) {
    return gc_new<Ruby_For>(loc(keyword_t), loc(in_t), loc(begin_t), loc(end_t), loc(keyword_t).join(loc(end_t)));
  }

  gc_ref<Ruby_RescueBody> rescue_body_map(auto keyword_t, auto exc_list_e, auto assoc_t, auto exc_var_e, auto then_t, auto compstmt_e) {
    RubyNil end_l;
    if (compstmt_e) {
      (end_l = compstmt_e.loc().expression());
    }
    if (({ auto _l = (ruby_nil_q(end_l)); (_l) ? decltype((then_t))(then_t) : decltype((then_t))(_l); })) {
      (end_l = loc(then_t));
    }
    if (({ auto _l = (ruby_nil_q(end_l)); (_l) ? decltype((exc_var_e))(exc_var_e) : decltype((exc_var_e))(_l); })) {
      (end_l = exc_var_e.loc().expression());
    }
    if (({ auto _l = (ruby_nil_q(end_l)); (_l) ? decltype((exc_list_e))(exc_list_e) : decltype((exc_list_e))(_l); })) {
      (end_l = exc_list_e.loc().expression());
    }
    if (ruby_nil_q(end_l)) {
      (end_l = loc(keyword_t));
    }
    return gc_new<Ruby_RescueBody>(loc(keyword_t), loc(assoc_t), loc(then_t), loc(keyword_t).join(end_l));
  }

  gc_ref<Ruby_Condition> eh_keyword_map(auto compstmt_e, auto keyword_t, auto body_es, auto else_t, auto else_e) {
    RubyNil begin_l;
    RubyNil end_l;
    if (ruby_nil_q(compstmt_e)) {
      (ruby_nil_q(keyword_t) ? ((begin_l = body_es.first().loc().expression())) : ((begin_l = loc(keyword_t))));
    } else {
      (begin_l = compstmt_e.loc().expression());
    }
    if (else_t) {
      (ruby_nil_q(else_e) ? ((end_l = loc(else_t))) : ((end_l = else_e.loc().expression())));
    } else {
      ((!(ruby_nil_q(body_es.last()))) ? ((end_l = body_es.last().loc().expression())) : ((end_l = loc(keyword_t))));
    }
    return gc_new<Ruby_Condition>(loc(keyword_t), RUBY_NIL, loc(else_t), RUBY_NIL, begin_l.join(end_l));
  }

  gc_ref<Ruby_Keyword> guard_map(auto keyword_t, auto guard_body_e) {
    RubyNil keyword_l;
    std::decay_t<decltype(guard_body_e.loc().expression())> guard_body_l{};
    (keyword_l = loc(keyword_t));
    (guard_body_l = guard_body_e.loc().expression());
    return gc_new<Ruby_Keyword>(keyword_l, RUBY_NIL, RUBY_NIL, keyword_l.join(guard_body_l));
  }

  RubyObject* static_string(auto nodes) {
    std::fprintf(stderr, "frozone: called TI-gap stub static_string\n"); std::abort();
    return nullptr;
  }

  RubyNil static_regexp(auto parts, auto options) {
    std::decay_t<decltype(static_string(parts))> source{};
    int64_t old_verbose = 0;
    (source = static_string(parts));
    if (ruby_nil_q(source)) {
      return RubyNil(RUBY_NIL);
    }
    (source = (options.children().include_q(ruby_sym("u"))) ? (source.encode(INT64_C(0) /* ::UTF_8 */)) : ((options.children().include_q(ruby_sym("e"))) ? (source.encode(INT64_C(0) /* ::EUC_JP */)) : ((options.children().include_q(ruby_sym("s"))) ? (source.encode(INT64_C(0) /* ::WINDOWS_31J */)) : ((options.children().include_q(ruby_sym("n"))) ? (source.encode(INT64_C(0) /* ::BINARY */)) : (source)))));
    {
      auto _t35_0 = /* UNSUPPORTED: GlobalVariableRead */;
      auto _t35_1 = RUBY_NIL;
      old_verbose = _t35_0;
      /* UNSUPPORTED masgn target: gvar */;
      gc_new<Ruby_Regexp>(source, if (options.children().include_q(ruby_sym("x"))) {
      INT64_C(0) /* ::EXTENDED */;
    });
    }
          /* UNSUPPORTED: GlobalVariableWrite */;;
  }

  RubyNil static_regexp_node(auto node) {
    std::decay_t<decltype(node.children()[(INT64_C(-2) + 1LL)])> parts{};
    std::decay_t<decltype(node.children()[INT64_C(-1)])> options{};
    if ((node.type() == ruby_sym("regexp"))) {
      return if (({ auto _l = ((iv_parser->version() >= INT64_C(33))); (_l) ? decltype((node.children()[(INT64_C(-2) + 1LL)].any_q()))(node.children()[(INT64_C(-2) + 1LL)].any_q()) : decltype((node.children()[(INT64_C(-2) + 1LL)].any_q()))(_l); })) {
        return RubyNil(RUBY_NIL);
      }; ({ auto _t36_0 = node.children()[(INT64_C(-2) + 1LL)]; auto _t36_1 = node.children()[INT64_C(-1)]; parts = _t36_0; options = _t36_1; }); static_regexp(parts, options);
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* collapse_string_parts_q(auto parts) {
    std::fprintf(stderr, "frozone: called TI-gap stub collapse_string_parts_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* value(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub value\n"); std::abort();
    return nullptr;
  }

  RubyObject* string_value(auto token) {
    std::fprintf(stderr, "frozone: called TI-gap stub string_value\n"); std::abort();
    return nullptr;
  }

  RubyNil loc(auto token) {
    if (({ auto _l = (token); (_l) ? decltype((token[INT64_C(0)]))(token[INT64_C(0)]) : decltype((token[INT64_C(0)]))(_l); })) {
      return token[INT64_C(1)];
    }
    return RubyNil(RUBY_NIL);
  }

  RubyNil diagnostic(auto type, auto reason, auto arguments, auto location, RubyArray_I64 highlights = RubyArray_I64(0)) {
    iv_parser->diagnostics().process(gc_new<Ruby_Diagnostic>(type, reason, arguments, location, highlights));
    if ((type == ruby_sym("error"))) {
      return iv_parser->send(ruby_sym("yyerror"));
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* validate_definee(auto definee) {
    std::fprintf(stderr, "frozone: called TI-gap stub validate_definee\n"); std::abort();
    return nullptr;
  }

  RubyNil rewrite_hash_args_to_kwargs(auto args) {
    if (({ auto _l = (args.any_q()); (_l) ? decltype((kwargs_q(args.last())))(kwargs_q(args.last())) : decltype((kwargs_q(args.last())))(_l); })) {
      return args[(args.len() - INT64_C(1))] = args[(args.len() - INT64_C(1))].updated(ruby_sym("kwargs"));
    } else {
      if (({ auto _l = (({ auto _l = ((args.len() > INT64_C(1))); (_l) ? decltype(((args.last().type() == ruby_sym("block_pass"))))((args.last().type() == ruby_sym("block_pass"))) : decltype(((args.last().type() == ruby_sym("block_pass"))))(_l); })); (_l) ? decltype((kwargs_q(args[(args.len() - INT64_C(2))])))(kwargs_q(args[(args.len() - INT64_C(2))])) : decltype((kwargs_q(args[(args.len() - INT64_C(2))])))(_l); })) {
        return args[(args.len() - INT64_C(2))] = args[(args.len() - INT64_C(2))].updated(ruby_sym("kwargs"));
      }
      return RubyNil(RUBY_NIL);
    }
  }

  RubyObject* kwargs_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub kwargs_q\n"); std::abort();
    return nullptr;
  }

  static RubyObject* modernize() {
    std::fprintf(stderr, "frozone: called TI-gap stub modernize\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Default>() { return "Default"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Default> : dustman::FieldList<Ruby_Default> {};
#endif

struct Ruby_Context : public RubyObject {
  bool iv_in_defined = false;
  gc_ref<RubyObject> iv_in_kwarg;
  gc_ref<RubyObject> iv_in_argdef;
  gc_ref<RubyObject> iv_in_def;
  gc_ref<RubyObject> iv_in_class;
  gc_ref<RubyObject> iv_in_block;
  gc_ref<RubyObject> iv_in_lambda;
  gc_ref<RubyObject> iv_cant_return;
  gc_ref<RubyObject> iv_cant_yield;

  Ruby_Context() {
    reset();
  }
  const char* rb_class_name() const override { return "Context"; }

  bool reset() {
    iv_in_defined = false;
    iv_in_kwarg = coerce_to_ref<RubyObject>(false);
    iv_in_argdef = coerce_to_ref<RubyObject>(false);
    iv_in_def = coerce_to_ref<RubyObject>(false);
    iv_in_class = coerce_to_ref<RubyObject>(false);
    iv_in_block = coerce_to_ref<RubyObject>(false);
    iv_in_lambda = coerce_to_ref<RubyObject>(false);
    iv_cant_return = coerce_to_ref<RubyObject>(false);
    return iv_cant_yield = coerce_to_ref<RubyObject>(false);
  }

  bool in_defined() {
    return iv_in_defined;
  }

  bool set_in_defined(auto __anon_req__) {
    iv_in_defined = __anon_req__;
    return iv_in_defined;
  }

  gc_ref<RubyObject> in_kwarg() {
    return iv_in_kwarg;
  }

  gc_ref<RubyObject> set_in_kwarg(gc_ref<RubyObject> __anon_req__) {
    iv_in_kwarg = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_kwarg;
  }

  gc_ref<RubyObject> in_argdef() {
    return iv_in_argdef;
  }

  gc_ref<RubyObject> set_in_argdef(gc_ref<RubyObject> __anon_req__) {
    iv_in_argdef = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_argdef;
  }

  gc_ref<RubyObject> in_def() {
    return iv_in_def;
  }

  gc_ref<RubyObject> set_in_def(gc_ref<RubyObject> __anon_req__) {
    iv_in_def = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_def;
  }

  gc_ref<RubyObject> in_class() {
    return iv_in_class;
  }

  gc_ref<RubyObject> set_in_class(gc_ref<RubyObject> __anon_req__) {
    iv_in_class = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_class;
  }

  gc_ref<RubyObject> in_block() {
    return iv_in_block;
  }

  gc_ref<RubyObject> set_in_block(gc_ref<RubyObject> __anon_req__) {
    iv_in_block = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_block;
  }

  gc_ref<RubyObject> in_lambda() {
    return iv_in_lambda;
  }

  gc_ref<RubyObject> set_in_lambda(gc_ref<RubyObject> __anon_req__) {
    iv_in_lambda = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_in_lambda;
  }

  gc_ref<RubyObject> cant_return() {
    return iv_cant_return;
  }

  gc_ref<RubyObject> set_cant_return(gc_ref<RubyObject> __anon_req__) {
    iv_cant_return = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_cant_return;
  }

  gc_ref<RubyObject> cant_yield() {
    return iv_cant_yield;
  }

  gc_ref<RubyObject> set_cant_yield(gc_ref<RubyObject> __anon_req__) {
    iv_cant_yield = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_cant_yield;
  }

  RubyObject* in_dynamic_block_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub in_dynamic_block_q\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Context>() { return "Context"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Context> : dustman::FieldList<Ruby_Context, &Ruby_Context::iv_in_kwarg, &Ruby_Context::iv_in_argdef, &Ruby_Context::iv_in_def, &Ruby_Context::iv_in_class, &Ruby_Context::iv_in_block, &Ruby_Context::iv_in_lambda, &Ruby_Context::iv_cant_return, &Ruby_Context::iv_cant_yield> {};
#endif

struct Ruby_MaxNumparamStack : public RubyObject {
  inline static const int64_t ORDINARY_PARAMS = -1LL;
  RubyArray<int64_t> iv_stack;

  Ruby_MaxNumparamStack() {
    iv_stack = RubyArray_I64(0);
  }
  const char* rb_class_name() const override { return "MaxNumparamStack"; }

  RubyArray<int64_t> stack() {
    return iv_stack;
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* has_ordinary_params_b() {
    std::fprintf(stderr, "frozone: called TI-gap stub has_ordinary_params_b\n"); std::abort();
    return nullptr;
  }

  RubyObject* has_ordinary_params_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub has_ordinary_params_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* has_numparams_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub has_numparams_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* rb_register(auto numparam) {
    std::fprintf(stderr, "frozone: called TI-gap stub rb_register\n"); std::abort();
    return nullptr;
  }

  RubyObject* top() {
    std::fprintf(stderr, "frozone: called TI-gap stub top\n"); std::abort();
    return nullptr;
  }

  RubyObject* push(auto static) {
    std::fprintf(stderr, "frozone: called TI-gap stub push\n"); std::abort();
    return nullptr;
  }

  RubyObject* pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* set(auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub set\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_MaxNumparamStack>() { return "MaxNumparamStack"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_MaxNumparamStack> : dustman::FieldList<Ruby_MaxNumparamStack> {};
#endif

struct Ruby_CurrentArgStack : public RubyObject {
  RubyArray<int64_t> iv_stack;

  Ruby_CurrentArgStack() {
    iv_stack = RubyArray_I64(0);
    0LL;
  }
  const char* rb_class_name() const override { return "CurrentArgStack"; }

  RubyArray<int64_t> stack() {
    return iv_stack;
  }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* push(auto value) {
    std::fprintf(stderr, "frozone: called TI-gap stub push\n"); std::abort();
    return nullptr;
  }

  std::optional<int64_t> set(auto value) {
    return iv_stack[(iv_stack.len() - INT64_C(1))] = value;
  }

  RubyObject* pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* reset() {
    std::fprintf(stderr, "frozone: called TI-gap stub reset\n"); std::abort();
    return nullptr;
  }

  RubyObject* top() {
    std::fprintf(stderr, "frozone: called TI-gap stub top\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_CurrentArgStack>() { return "CurrentArgStack"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_CurrentArgStack> : dustman::FieldList<Ruby_CurrentArgStack> {};
#endif

struct Ruby_VariablesStack : public RubyObject {
  RubyArray<int64_t> iv_stack;

  Ruby_VariablesStack() {
    iv_stack = RubyArray_I64(0);
    push();
  }
  const char* rb_class_name() const override { return "VariablesStack"; }

  RubyObject* empty_q() {
    std::fprintf(stderr, "frozone: called TI-gap stub empty_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* push() {
    std::fprintf(stderr, "frozone: called TI-gap stub push\n"); std::abort();
    return nullptr;
  }

  RubyObject* pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub pop\n"); std::abort();
    return nullptr;
  }

  RubyObject* reset() {
    std::fprintf(stderr, "frozone: called TI-gap stub reset\n"); std::abort();
    return nullptr;
  }

  RubyObject* declare(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub declare\n"); std::abort();
    return nullptr;
  }

  RubyObject* declared_q(auto name) {
    std::fprintf(stderr, "frozone: called TI-gap stub declared_q\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_VariablesStack>() { return "VariablesStack"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_VariablesStack> : dustman::FieldList<Ruby_VariablesStack> {};
#endif

struct Ruby_Base : public Ruby_Parser {
  inline static const RubyString Racc_Runtime_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version_R = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Type = RubyString("ruby", 4);
  gc_ref<Ruby_Lexer> iv_lexer;
  gc_ref<RubyObject> iv_diagnostics = nullptr;
  gc_ref<RubyObject> iv_builder = nullptr;
  gc_ref<Ruby_StaticEnvironment> iv_static_env;
  RubyNil iv_source_buffer;
  gc_ref<Ruby_Context> iv_context;
  gc_ref<Ruby_MaxNumparamStack> iv_max_numparam_stack;
  gc_ref<Ruby_CurrentArgStack> iv_current_arg_stack;
  gc_ref<Ruby_VariablesStack> iv_pattern_variables;
  gc_ref<Ruby_VariablesStack> iv_pattern_hash_keys;
  RubyArray<gc_ref<RubyObject>> iv_last_token;
  gc_ref<RubyObject> iv_yydebug = nullptr;
  gc_ref<RubyObject> iv_racc_debug_out = nullptr;
  RubyArray<int64_t> iv_racc_state;
  RubyArray<int64_t> iv_racc_tstack;
  RubyArray<int64_t> iv_racc_vstack;
  RubyNil iv_racc_t;
  RubyNil iv_racc_val;
  bool iv_racc_read_next = false;
  int64_t iv_racc_error_status = 0;

  Ruby_Base() = default;
  Ruby_Base(int64_t builder = gc_new<Ruby_Default>()) {
    iv_diagnostics = gc_new<Ruby_Engine>();
    iv_static_env = gc_new<Ruby_StaticEnvironment>();
    iv_context = gc_new<Ruby_Context>();
    iv_max_numparam_stack = gc_new<Ruby_MaxNumparamStack>();
    iv_current_arg_stack = gc_new<Ruby_CurrentArgStack>();
    iv_pattern_variables = gc_new<Ruby_VariablesStack>();
    iv_pattern_hash_keys = gc_new<Ruby_VariablesStack>();
    iv_lexer = gc_new<Ruby_Lexer>(version());
    iv_lexer->set_diagnostics(iv_diagnostics);
    iv_lexer->set_static_env(iv_static_env);
    iv_lexer->set_context(iv_context);
    iv_builder = builder;
    iv_builder->set_parser((*this));
    iv_last_token = RUBY_NIL;
    if (({ auto _l = (INT64_C(0) /* ::Racc_debug_parser */); (_l) ? decltype((ENV[RubyString("RACC_DEBUG", 10)]))(ENV[RubyString("RACC_DEBUG", 10)]) : decltype((ENV[RubyString("RACC_DEBUG", 10)]))(_l); })) {
      iv_yydebug = true;
    }
    reset();
  }
  const char* rb_class_name() const override { return "Base"; }

  gc_ref<Ruby_Lexer> lexer() {
    return iv_lexer;
  }

  RubyObject* diagnostics() {
    std::fprintf(stderr, "frozone: called TI-gap stub diagnostics\n"); std::abort();
    return nullptr;
  }

  RubyObject* builder() {
    std::fprintf(stderr, "frozone: called TI-gap stub builder\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_StaticEnvironment> static_env() {
    return iv_static_env;
  }

  RubyNil source_buffer() {
    return iv_source_buffer;
  }

  gc_ref<Ruby_Context> context() {
    return iv_context;
  }

  gc_ref<Ruby_MaxNumparamStack> max_numparam_stack() {
    return iv_max_numparam_stack;
  }

  gc_ref<Ruby_CurrentArgStack> current_arg_stack() {
    return iv_current_arg_stack;
  }

  gc_ref<Ruby_VariablesStack> pattern_variables() {
    return iv_pattern_variables;
  }

  gc_ref<Ruby_VariablesStack> pattern_hash_keys() {
    return iv_pattern_hash_keys;
  }

  RubyObject* reset() {
    std::fprintf(stderr, "frozone: called TI-gap stub reset\n"); std::abort();
    return nullptr;
  }

  RubyObject* parse(auto source_buffer) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse\n"); std::abort();
    return nullptr;
  }

  RubyObject* parse_with_comments(auto source_buffer) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse_with_comments\n"); std::abort();
    return nullptr;
  }

  RubyObject* tokenize(auto source_buffer, auto recover) {
    std::fprintf(stderr, "frozone: called TI-gap stub tokenize\n"); std::abort();
    return nullptr;
  }

  RubyArray<gc_ref<RubyObject>> next_token() {
    RubyArray<gc_ref<RubyObject>> token;
    (token = iv_lexer->advance());
    iv_last_token = token;
    return token;
  }

  RubyObject* check_kwarg_name(auto name_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_kwarg_name\n"); std::abort();
    return nullptr;
  }

  RubyNil diagnostic(auto level, auto reason, auto arguments, auto location_t, RubyArray_I64 highlights_ts = RubyArray_I64(0)) {
    auto _masgn37 = location_t;
    auto _ = _masgn37[INT64_C(0)];
    auto location = _masgn37[INT64_C(1)];
    auto highlights = highlights_ts.map();
    iv_diagnostics->process(gc_new<Ruby_Diagnostic>(level, reason, arguments, location, highlights));
    if ((level == ruby_sym("error"))) {
      return yyerror();
    }
    return RubyNil(RUBY_NIL);
  }

  RubyObject* on_error(auto error_token_id, auto error_value, auto value_stack) {
    std::fprintf(stderr, "frozone: called TI-gap stub on_error\n"); std::abort();
    return nullptr;
  }

  static RubyObject* parse(auto string, auto file, auto line) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse\n"); std::abort();
    return nullptr;
  }

  static RubyObject* parse_with_comments(auto string, auto file, auto line) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse_with_comments\n"); std::abort();
    return nullptr;
  }

  static RubyObject* parse_file(auto filename) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse_file\n"); std::abort();
    return nullptr;
  }

  static RubyObject* parse_file_with_comments(auto filename) {
    std::fprintf(stderr, "frozone: called TI-gap stub parse_file_with_comments\n"); std::abort();
    return nullptr;
  }

  static RubyObject* default_parser() {
    std::fprintf(stderr, "frozone: called TI-gap stub default_parser\n"); std::abort();
    return nullptr;
  }

  static RubyObject* setup_source_buffer(auto file, auto line, auto string, auto encoding) {
    std::fprintf(stderr, "frozone: called TI-gap stub setup_source_buffer\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Base>() { return "Base"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Base> : dustman::FieldList<Ruby_Base, &Ruby_Base::iv_lexer, &Ruby_Base::iv_static_env, &Ruby_Base::iv_context, &Ruby_Base::iv_max_numparam_stack, &Ruby_Base::iv_current_arg_stack, &Ruby_Base::iv_pattern_variables, &Ruby_Base::iv_pattern_hash_keys> {};
#endif

struct Ruby_Rewriter : public Ruby_Processor {
  inline static const RubyString DEPRECATION_WARNING = RubyString("Parser::Rewriter is deprecated.\nPlease update your code to use Parser::TreeRewriter instead", 91);
  gc_ref<RubyObject> iv_source_rewriter = nullptr;

  Ruby_Rewriter() {
    rb_class().warn_of_deprecation();
    INT64_C(0) /* ::Rewriter */.set_warned_of_deprecation(true);
    /* UNSUPPORTED: Super */;
  }
  const char* rb_class_name() const override { return "Rewriter"; }

  RubyObject* rewrite(auto source_buffer, auto ast) {
    std::fprintf(stderr, "frozone: called TI-gap stub rewrite\n"); std::abort();
    return nullptr;
  }

  RubyObject* assignment_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub assignment_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* remove(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub remove\n"); std::abort();
    return nullptr;
  }

  RubyObject* wrap(auto range, auto before, auto after) {
    std::fprintf(stderr, "frozone: called TI-gap stub wrap\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Rewriter>() { return "Rewriter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Rewriter> : dustman::FieldList<Ruby_Rewriter> {};
#endif

struct Ruby_TreeRewriter : public Ruby_Processor {
  gc_ref<RubyObject> iv_source_rewriter = nullptr;

  Ruby_TreeRewriter() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "TreeRewriter"; }

  RubyObject* rewrite(auto source_buffer, auto ast) {
    std::fprintf(stderr, "frozone: called TI-gap stub rewrite\n"); std::abort();
    return nullptr;
  }

  RubyObject* assignment_q(auto node) {
    std::fprintf(stderr, "frozone: called TI-gap stub assignment_q\n"); std::abort();
    return nullptr;
  }

  RubyObject* remove(auto range) {
    std::fprintf(stderr, "frozone: called TI-gap stub remove\n"); std::abort();
    return nullptr;
  }

  RubyObject* wrap(auto range, auto before, auto after) {
    std::fprintf(stderr, "frozone: called TI-gap stub wrap\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_before(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_before\n"); std::abort();
    return nullptr;
  }

  RubyObject* insert_after(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub insert_after\n"); std::abort();
    return nullptr;
  }

  RubyObject* replace(auto range, auto content) {
    std::fprintf(stderr, "frozone: called TI-gap stub replace\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_TreeRewriter>() { return "TreeRewriter"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TreeRewriter> : dustman::FieldList<Ruby_TreeRewriter> {};
#endif

struct Ruby_Ruby40 : public Ruby_Base {
  inline static const bool Racc_debug_parser = false;
  inline static const RubyString Racc_Runtime_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version_R = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Core_Version = RubyString("1.8.1", 5);
  inline static const RubyString Racc_Runtime_Type = RubyString("ruby", 4);
  gc_ref<Ruby_StaticEnvironment> iv_static_env;
  gc_ref<Ruby_Lexer> iv_lexer;
  gc_ref<Ruby_MaxNumparamStack> iv_max_numparam_stack;
  gc_ref<Ruby_Context> iv_context;
  gc_ref<Ruby_CurrentArgStack> iv_current_arg_stack;
  gc_ref<RubyObject> iv_builder = nullptr;
  gc_ref<Ruby_VariablesStack> iv_pattern_variables;
  gc_ref<Ruby_VariablesStack> iv_pattern_hash_keys;
  RubyArray<gc_ref<RubyObject>> iv_last_token;
  gc_ref<RubyObject> iv_diagnostics = nullptr;
  RubyNil iv_source_buffer;
  gc_ref<RubyObject> iv_yydebug = nullptr;
  gc_ref<RubyObject> iv_racc_debug_out = nullptr;
  RubyArray<int64_t> iv_racc_state;
  RubyArray<int64_t> iv_racc_tstack;
  RubyArray<int64_t> iv_racc_vstack;
  RubyNil iv_racc_t;
  RubyNil iv_racc_val;
  bool iv_racc_read_next = false;
  int64_t iv_racc_error_status = 0;

  Ruby_Ruby40() = default;
  Ruby_Ruby40(int64_t builder = gc_new<Ruby_Default>()) {
    iv_diagnostics = gc_new<Ruby_Engine>();
    iv_static_env = gc_new<Ruby_StaticEnvironment>();
    iv_context = gc_new<Ruby_Context>();
    iv_max_numparam_stack = gc_new<Ruby_MaxNumparamStack>();
    iv_current_arg_stack = gc_new<Ruby_CurrentArgStack>();
    iv_pattern_variables = gc_new<Ruby_VariablesStack>();
    iv_pattern_hash_keys = gc_new<Ruby_VariablesStack>();
    iv_lexer = gc_new<Ruby_Lexer>(version());
    iv_lexer->set_diagnostics(iv_diagnostics);
    iv_lexer->set_static_env(iv_static_env);
    iv_lexer->set_context(iv_context);
    iv_builder = builder;
    iv_builder->set_parser((*this));
    iv_last_token = RUBY_NIL;
    if (({ auto _l = (INT64_C(0) /* ::Racc_debug_parser */); (_l) ? decltype((ENV[RubyString("RACC_DEBUG", 10)]))(ENV[RubyString("RACC_DEBUG", 10)]) : decltype((ENV[RubyString("RACC_DEBUG", 10)]))(_l); })) {
      iv_yydebug = true;
    }
    reset();
  }
  const char* rb_class_name() const override { return "Ruby40"; }

  int64_t version() {
    return INT64_C(40);
  }

  RubyObject* default_encoding() {
    std::fprintf(stderr, "frozone: called TI-gap stub default_encoding\n"); std::abort();
    return nullptr;
  }

  RubyNil endless_method_name(auto name_t) {
    return RubyNil(RUBY_NIL);
  }

  RubyObject* check_index_assignment_args(auto args, auto lbrack_t) {
    std::fprintf(stderr, "frozone: called TI-gap stub check_index_assignment_args\n"); std::abort();
    return nullptr;
  }

  RubyObject* local_push() {
    std::fprintf(stderr, "frozone: called TI-gap stub local_push\n"); std::abort();
    return nullptr;
  }

  RubyObject* local_pop() {
    std::fprintf(stderr, "frozone: called TI-gap stub local_pop\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> try_declare_numparam(auto node) {
    std::decay_t<decltype(node.children()[INT64_C(0)])> name{};
    std::decay_t<decltype(node.loc().expression())> location{};
    std::decay_t<decltype(max_numparam_stack().stack().dup_())> raw_max_numparam_stack{};
    (name = node.children()[INT64_C(0)]);
    if (({ auto _l = (({ auto _l = (name.=~(/* UNSUPPORTED: RegexpLiteral */)); (_l) ? decltype(((!(static_env().declared_q(name)))))((!(static_env().declared_q(name)))) : decltype(((!(static_env().declared_q(name)))))(_l); })); (_l) ? decltype((iv_context->in_dynamic_block_q()))(iv_context->in_dynamic_block_q()) : decltype((iv_context->in_dynamic_block_q()))(_l); })) {
      return coerce_to_ref<RubyObject>((location = node.loc().expression()); if (max_numparam_stack().has_ordinary_params_q()) {
        diagnostic(ruby_sym("error"), ruby_sym("ordinary_param_defined"), RUBY_NIL, ({ auto _e0 = RUBY_NIL; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = location; _a; }));
      }; (raw_max_numparam_stack = max_numparam_stack().stack().dup_()); raw_max_numparam_stack.pop(); raw_max_numparam_stack.reverse_each(); static_env().declare(name); max_numparam_stack().rb_register((int64_t)(name[INT64_C(1)])); true);
    } else {
      return coerce_to_ref<RubyObject>(false);
    }
  }

  RubyObject* _reduce_1(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_1\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_2(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_2\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_3(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_3\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_4(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyArray<int64_t> _reduce_5(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_6(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_6\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_7(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(1)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_9(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_9\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_10(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_10\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_11(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_11\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_12(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_12\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_13(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyArray<int64_t> _reduce_14(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_15(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_15\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_16(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(1)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_18(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_18\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_19(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_19\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_20(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_20\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_21(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_21\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_22(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_22\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_23(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_23\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_24(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_24\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_25(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_25\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_26(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_26\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_27(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_27\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_28(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_28\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_29(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_29\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_30(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_30\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_32(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_32\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_33(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_33\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_34(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_34\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_35(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_35\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_37(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_37\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_38(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_38\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_39(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_39\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_40(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_40\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_41(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_41\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_42(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_42\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_43(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_43\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_44(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_44\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_45(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_45\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_46(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_46\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_48(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_48\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_49(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_49\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_51(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_51\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_54(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_54\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_55(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_55\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_56(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_56\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_57(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_57\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_58(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_58\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_59(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_59\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_62(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_62\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_63(auto val, auto _values, auto result) {
    iv_lexer->cond().pop();
    (result = ({ auto _e0 = val[INT64_C(1)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a; }));
    return result;
  }

  RubyArray<gc_ref<Ruby_Context>> _reduce_64(auto val, auto _values, auto result) {
    local_push();
    iv_current_arg_stack->push(RUBY_NIL);
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_context.dup_(); _a; }));
    iv_context->set_in_def(true);
    iv_context->set_cant_return(false);
    iv_context->set_cant_yield(false);
    return result;
  }

  RubyArray<int64_t> _reduce_65(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a; }));
    return result;
  }

  RubyObject* _reduce_66(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_66\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_67(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(4); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a[2] = val[INT64_C(2)]; _a[3] = val[INT64_C(4)]; _a; }));
    return result;
  }

  RubyObject* _reduce_71(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_71\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_72(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_block(true);
    return result;
  }

  RubyArray<int64_t> _reduce_73(auto val, auto _values, auto result) {
    iv_context->set_in_block(val[INT64_C(1)].in_block());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  RubyObject* _reduce_75(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_75\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_76(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_76\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_77(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_77\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_78(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_78\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_79(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_79\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_80(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_80\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_81(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_81\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_82(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_82\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_83(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_83\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_84(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_84\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_85(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_85\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_86(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_86\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_87(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_87\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_88(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_88\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_89(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_89\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_90(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_90\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_92(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_92\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_93(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_93\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_94(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_94\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_95(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_95\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_96(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_96\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_97(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_98(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_99(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_100(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyObject* _reduce_102(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_102\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_103(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_104(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_104\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_105(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_106(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_106\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_107(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_107\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_108(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_108\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_109(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_109\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_110(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_110\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_111(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_111\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_112(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_112\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_113(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_113\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_114(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_114\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_115(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_115\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_116(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_116\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_117(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_117\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_118(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_118\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_119(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_119\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_120(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_120\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_121(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_121\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_122(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_122\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_123(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_123\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_124(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_124\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_125(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_125\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_127(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_127\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_128(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_128\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_129(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_129\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_135(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_135\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_137(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_138(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_138\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_139(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_139\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_211(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_211\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_212(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_212\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_213(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_213\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_214(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_214\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_215(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_215\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_216(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_216\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_217(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_217\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_218(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_218\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_219(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_219\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_220(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_220\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_221(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_221\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_222(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_222\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_223(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_223\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_224(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_224\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_225(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_225\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_226(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_226\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_227(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_227\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_228(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_228\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_229(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_229\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_230(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_230\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_231(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_231\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_232(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_232\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_233(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_233\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_234(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_234\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_235(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_235\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_236(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_236\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_237(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_237\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_238(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_238\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_240(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_240\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_241(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_241\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_242(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_242\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_243(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_243\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_244(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_244\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_245(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_245\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_246(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_246\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_247(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_247\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_248(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_248\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_249(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_249\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_250(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_250\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_251(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_251\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_252(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_252\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_253(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_253\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_254(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_254\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_257(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_257\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_258(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_258\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_263(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_263\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_264(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_264\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_265(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    return result;
  }

  RubyObject* _reduce_269(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_269\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_270(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->associate(RUBY_NIL, val[INT64_C(0)], RUBY_NIL); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_272(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_272\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_273(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_273\n"); std::abort();
    return nullptr;
  }

  RubyArray<RubyArray<int64_t>> _reduce_274(auto val, auto _values, auto result) {
    (iv_static_env->declared_forward_args_q() ? (RUBY_NIL) : (diagnostic(ruby_sym("error"), ruby_sym("unexpected_token"), ({ RubyHash<RubySymbol, RubyString> _h; _h.store(ruby_sym("token"), RubyString("tBDOT3", 6)); _h; }), val[INT64_C(3)])));
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_builder->forwarded_args(val[INT64_C(3)]); _a; }); _a[2] = val[INT64_C(4)]; _a; }));
    return result;
  }

  RubyArray<RubyArray<int64_t>> _reduce_275(auto val, auto _values, auto result) {
    (iv_static_env->declared_forward_args_q() ? (RUBY_NIL) : (diagnostic(ruby_sym("error"), ruby_sym("unexpected_token"), ({ RubyHash<RubySymbol, RubyString> _h; _h.store(ruby_sym("token"), RubyString("tBDOT3", 6)); _h; }), val[INT64_C(1)])));
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = ({ auto _e0 = iv_builder->forwarded_args(val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }); _a[2] = val[INT64_C(2)]; _a; }));
    return result;
  }

  RubyArray<RubyArray<int64_t>> _reduce_276(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = RUBY_NIL; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = RubyArray_I64(0); _a[2] = RUBY_NIL; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_278(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_281(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_281\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_282(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->associate(RUBY_NIL, val[INT64_C(0)], RUBY_NIL); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_283(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_284(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_284\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_285(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->associate(RUBY_NIL, val[INT64_C(0)], RUBY_NIL); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    result.concat(val[INT64_C(1)]);
    return result;
  }

  RubyObject* _reduce_286(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_286\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_287(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_288(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_288\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_289(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_289\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_290(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_290\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_291(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_291\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_292(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(1)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_293(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyArray<int64_t> _reduce_294(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_296(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_296\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_297(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_297\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_298(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_299(auto val, auto _values, auto result) {
    if ((!(iv_static_env->declared_anonymous_restarg_q()))) {
      diagnostic(ruby_sym("error"), ruby_sym("no_anonymous_restarg"), RUBY_NIL, val[INT64_C(0)]);
    }
    if (({ auto _l = (({ auto _l = (({ auto _l = (iv_context->in_dynamic_block_q()); (_l) ? decltype((context().in_def()))(context().in_def()) : decltype((context().in_def()))(_l); })); (_l) ? decltype((iv_static_env->declared_anonymous_restarg_in_current_scope_q()))(iv_static_env->declared_anonymous_restarg_in_current_scope_q()) : decltype((iv_static_env->declared_anonymous_restarg_in_current_scope_q()))(_l); })); (_l) ? decltype((iv_static_env->parent_has_anonymous_restarg_q()))(iv_static_env->parent_has_anonymous_restarg_q()) : decltype((iv_static_env->parent_has_anonymous_restarg_q()))(_l); })) {
      diagnostic(ruby_sym("error"), ruby_sym("ambiguous_anonymous_restarg"), RUBY_NIL, val[INT64_C(0)]);
    }
    (result = ({ auto _e0 = iv_builder->forwarded_restarg(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_300(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_300\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_302(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_302\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_303(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_303\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_304(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->splat(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_315(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_315\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_316(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_316\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_317(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_317\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_318(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_318\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_319(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_319\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_320(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_320\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_321(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_321\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_322(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_322\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_323(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_323\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_324(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_324\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_325(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_325\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_326(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_326\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_327(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_327\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_328(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_328\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_329(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_329\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_330(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_330\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_331(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_331\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_332(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_332\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_334(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_334\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_336(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_336\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_337(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_337\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_338(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_338\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_339(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_339\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_340(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_340\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_341(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_341\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_342(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_342\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_343(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_343\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_344(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_344\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_345(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_345\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_346(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_346\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_347(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_347\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_348(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_348\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_349(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_349\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_350(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_350\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_351(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_351\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_352(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_352\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_353(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_353\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_354(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_354\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_355(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_355\n"); std::abort();
    return nullptr;
  }

  RubyArray<gc_ref<Ruby_Context>> _reduce_357(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_context.dup_(); _a; }));
    return result;
  }

  RubyArray<gc_ref<Ruby_Context>> _reduce_358(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_context.dup_(); _a; }));
    return result;
  }

  RubyObject* _reduce_359(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_359\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_360(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_360\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_361(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_361\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_364(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_364\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_368(auto val, auto _values, auto result) {
    auto _masgn38 = val[INT64_C(4)];
    auto else_t = _masgn38[INT64_C(0)];
    auto else_ = _masgn38[INT64_C(1)];
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_builder->condition(val[INT64_C(0)], val[INT64_C(1)], val[INT64_C(2)], val[INT64_C(3)], else_t, else_, RUBY_NIL); _a; }));
    return result;
  }

  RubyObject* _reduce_370(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_370\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_373(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_373\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_374(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_374\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_375(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_376(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_376\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_378(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_378\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_379(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_379\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_380(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_381(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyObject* _reduce_382(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_382\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_383(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_383\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_386(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_386\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_387(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_387\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_388(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_388\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_389(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_389\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_390(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_390\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_391(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_392(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_392\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_393(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_395(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_395\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_396(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_396\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_397(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_397\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_398(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_398\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_399(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_399\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_400(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_400\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_401(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_401\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_402(auto val, auto _values, auto result) {
    (({ auto _l = (val[INT64_C(1)].empty_q()); (_l) ? decltype(((val[INT64_C(0)].len() == INT64_C(1))))((val[INT64_C(0)].len() == INT64_C(1))) : decltype(((val[INT64_C(0)].len() == INT64_C(1))))(_l); }) ? ((result = ({ auto _e0 = iv_builder->procarg0(val[INT64_C(0)][INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }))) : ((result = val[INT64_C(0)].concat(val[INT64_C(1)]))));
    return result;
  }

  RubyObject* _reduce_403(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_403\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_404(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_404\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_405(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_405\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_406(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_406\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_407(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_407\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_408(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_408\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_410(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_410\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_411(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_411\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_412(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_412\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_413(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_413\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_414(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_415(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_415\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_416(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_417(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_417\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_418(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_418\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_420(auto val, auto _values, gc_ref<Ruby_Context> result) {
    iv_static_env->extend_dynamic();
    iv_max_numparam_stack->push();
    (result = iv_context.dup_());
    iv_context->set_in_lambda(true);
    return result;
  }

  RubyObject* _reduce_421(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_421\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_422(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_422\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_423(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_423\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_424(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_424\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_425(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_lambda(true);
    return result;
  }

  RubyArray<int64_t> _reduce_426(auto val, auto _values, auto result) {
    iv_context->set_in_lambda(val[INT64_C(1)].in_lambda());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  gc_ref<Ruby_Context> _reduce_427(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_lambda(true);
    return result;
  }

  RubyArray<int64_t> _reduce_428(auto val, auto _values, auto result) {
    iv_context->set_in_lambda(val[INT64_C(1)].in_lambda());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  gc_ref<Ruby_Context> _reduce_429(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_block(true);
    return result;
  }

  RubyArray<int64_t> _reduce_430(auto val, auto _values, auto result) {
    iv_context->set_in_block(val[INT64_C(1)].in_block());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  RubyObject* _reduce_431(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_431\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_432(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_432\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_433(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_433\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_434(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_434\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_435(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_435\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_436(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_436\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_437(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_437\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_438(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_438\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_439(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_439\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_440(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_440\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_441(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_441\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_442(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_442\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_443(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_443\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_444(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_block(true);
    return result;
  }

  RubyArray<int64_t> _reduce_445(auto val, auto _values, auto result) {
    iv_context->set_in_block(val[INT64_C(1)].in_block());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  gc_ref<Ruby_Context> _reduce_446(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_block(true);
    return result;
  }

  RubyArray<int64_t> _reduce_447(auto val, auto _values, auto result) {
    iv_context->set_in_block(val[INT64_C(1)].in_block());
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = val[INT64_C(3)]; _a; }));
    return result;
  }

  RubyObject* _reduce_448(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_448\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_449(auto val, auto _values, auto result) {
    auto args = (iv_max_numparam_stack->has_numparams_q() ? (iv_builder->numargs(iv_max_numparam_stack->top())) : (val[INT64_C(1)]));
    (result = ({ auto _e0 = args; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a; }));
    iv_max_numparam_stack->pop();
    iv_static_env->unextend();
    return result;
  }

  RubyObject* _reduce_450(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_450\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_451(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_451\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_452(auto val, auto _values, auto result) {
    auto args = (iv_max_numparam_stack->has_numparams_q() ? (iv_builder->numargs(iv_max_numparam_stack->top())) : (val[INT64_C(2)]));
    (result = ({ auto _e0 = args; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(3)]; _a; }));
    iv_max_numparam_stack->pop();
    iv_static_env->unextend();
    iv_lexer->cmdarg().pop();
    return result;
  }

  RubyArray<int64_t> _reduce_453(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->when(val[INT64_C(0)], val[INT64_C(1)], val[INT64_C(2)], val[INT64_C(3)]); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_454(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_456(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_456\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_457(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_457\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> _reduce_458(auto val, auto _values, gc_ref<RubyObject> result) {
    (result = iv_context->in_kwarg());
    iv_lexer->set_state(ruby_sym("expr_beg"));
    iv_lexer->set_command_start(false);
    iv_context->set_in_kwarg(true);
    return coerce_to_ref<RubyObject>(result);
  }

  RubyObject* _reduce_459(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_459\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_460(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->in_pattern(val[INT64_C(0)], /* UNSUPPORTED: SplatArg */, val[INT64_C(5)], val[INT64_C(7)]); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_461(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<RubyNil> _reduce_463(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RUBY_NIL; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_464(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_builder->if_guard(val[INT64_C(1)], val[INT64_C(2)]); _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_465(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = iv_builder->unless_guard(val[INT64_C(1)], val[INT64_C(2)]); _a; }));
    return result;
  }

  RubyObject* _reduce_467(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_467\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_468(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_468\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_469(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_469\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_470(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_470\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_471(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_471\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_473(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_473\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_475(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_475\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_477(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_477\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_478(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_478\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_481(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_481\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_482(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_482\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_483(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_483\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_484(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_484\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_485(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_485\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_486(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_486\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_487(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_487\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_488(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_488\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_489(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_489\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_490(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_490\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_491(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_491\n"); std::abort();
    return nullptr;
  }

  gc_ref<RubyObject> _reduce_492(auto val, auto _values, gc_ref<RubyObject> result) {
    iv_pattern_hash_keys->push();
    (result = iv_context->in_kwarg());
    iv_context->set_in_kwarg(false);
    return coerce_to_ref<RubyObject>(result);
  }

  RubyObject* _reduce_493(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_493\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_494(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_494\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_495(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_495\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_496(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_496\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_497(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_498(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_498\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_499(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_500(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_501(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a[2] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_503(auto val, auto _values, auto result) {
    std::decay_t<decltype(iv_builder->match_with_trailing_comma(val[INT64_C(0)], val[INT64_C(1)]))> item{};
    (item = iv_builder->match_with_trailing_comma(val[INT64_C(0)], val[INT64_C(1)]));
    (result = ({ auto _e0 = item; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_504(auto val, auto _values, auto result) {
    std::decay_t<decltype(iv_builder->match_with_trailing_comma(val[INT64_C(1)], val[INT64_C(2)]))> last_item{};
    (last_item = iv_builder->match_with_trailing_comma(val[INT64_C(1)], val[INT64_C(2)]));
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = last_item; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_505(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_506(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_507(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a[2] = val[INT64_C(4)]; _a; }));
    return result;
  }

  RubyObject* _reduce_508(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_508\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_509(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_509\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_510(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_511(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_513(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyObject* _reduce_514(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_514\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_515(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_515\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_516(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_516\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_517(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_518(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = /* UNSUPPORTED: SplatArg */; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a; }));
    return result;
  }

  RubyObject* _reduce_519(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_519\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_520(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_520\n"); std::abort();
    return nullptr;
  }

  RubyArray<RubySymbol> _reduce_521(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = ruby_sym("label"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(0)]; _a; }));
    return result;
  }

  RubyArray<gc_ref<RubyObject>> _reduce_522(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = ruby_sym("quoted"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a[2] = val[INT64_C(2)]; _a; }); _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_523(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->match_rest(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_524(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->match_rest(val[INT64_C(0)], RUBY_NIL); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_525(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_525\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_527(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->match_nil_pattern(val[INT64_C(0)][INT64_C(0)], val[INT64_C(0)][INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_529(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_529\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_530(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_530\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_531(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_531\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_532(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_532\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_536(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_536\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_537(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_537\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_546(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_546\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_548(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_548\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_549(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_549\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_550(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_550\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_551(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_551\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_552(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_552\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_553(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_553\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_554(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_554\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_555(auto val, auto _values, auto result) {
    std::decay_t<decltype(iv_builder->array(RUBY_NIL, val[INT64_C(1)], RUBY_NIL))> exc_list{};
    auto _masgn39 = val[INT64_C(2)];
    auto assoc_t = _masgn39[INT64_C(0)];
    auto exc_var = _masgn39[INT64_C(1)];
    if (val[INT64_C(1)]) {
      (exc_list = iv_builder->array(RUBY_NIL, val[INT64_C(1)], RUBY_NIL));
    }
    (result = ({ auto _e0 = iv_builder->rescue_body(val[INT64_C(0)], exc_list, assoc_t, exc_var, val[INT64_C(3)], val[INT64_C(4)]); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = /* UNSUPPORTED: SplatArg */; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_556(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyArray<int64_t> _reduce_557(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_560(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_562(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(1)]; _a; }));
    return result;
  }

  RubyObject* _reduce_566(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_566\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_567(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_568(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_568\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_569(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_569\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_570(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_570\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_571(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_571\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_572(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_572\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_573(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_573\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_576(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_576\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_577(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_578(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_578\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_579(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_580(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_580\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_581(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_581\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_582(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_583(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_583\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_584(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_584\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_585(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_585\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_586(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_587(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_587\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_588(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_589(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_589\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_590(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_591(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_591\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_592(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_593(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_593\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_594(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_595(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_595\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_596(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_596\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_597(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_597\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_598(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_598\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_599(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_599\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_601(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_601\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_605(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_605\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_606(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_606\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_607(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_607\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_608(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_608\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_609(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_609\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_610(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_610\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_611(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_611\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_612(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_612\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_613(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_613\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_614(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_614\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_615(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_615\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_616(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_616\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_617(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_617\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_619(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_619\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_620(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_620\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_621(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_621\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_622(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_622\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_623(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_623\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_624(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_624\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_625(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_625\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_626(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_626\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_627(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_627\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_628(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_628\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_629(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_629\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_630(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_630\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_631(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_631\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_632(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_632\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_633(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(2)]; _a; }));
    return result;
  }

  RubyNil _reduce_634(auto val, auto _values, auto result) {
    (result = RUBY_NIL);
    return result;
  }

  RubyObject* _reduce_636(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_636\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_637(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_637\n"); std::abort();
    return nullptr;
  }

  gc_ref<Ruby_Context> _reduce_639(auto val, auto _values, gc_ref<Ruby_Context> result) {
    (result = iv_context.dup_());
    iv_context->set_in_kwarg(true);
    iv_context->set_in_argdef(true);
    return result;
  }

  RubyObject* _reduce_640(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_640\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_641(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_641\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_642(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_642\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_643(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_643\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_644(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_645(auto val, auto _values, auto result) {
    iv_static_env->declare_forward_args();
    (result = ({ auto _e0 = iv_builder->forward_arg(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_646(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_646\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_647(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_648(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_648\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_649(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_649\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_650(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_650\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_651(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_651\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_652(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_652\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_653(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_653\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_654(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_654\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_655(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_655\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_656(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_656\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_657(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_657\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_658(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_658\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_659(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_659\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_660(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_660\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_661(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_661\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_662(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_663(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_663\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_664(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_664\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_665(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_665\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_666(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_666\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_667(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_667\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_669(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_669\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_670(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_670\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_671(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_671\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_672(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_672\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_673(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_674(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_674\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_675(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_675\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_676(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_676\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_677(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_677\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_678(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_678\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_679(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_679\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_680(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_681(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_681\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_682(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_683(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_683\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_686(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = iv_builder->kwnilarg(val[INT64_C(0)][INT64_C(0)], val[INT64_C(0)][INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_687(auto val, auto _values, auto result) {
    iv_static_env->declare(val[INT64_C(1)][INT64_C(0)]);
    (result = ({ auto _e0 = iv_builder->kwrestarg(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_688(auto val, auto _values, auto result) {
    iv_static_env->declare_anonymous_kwrestarg();
    (result = ({ auto _e0 = iv_builder->kwrestarg(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_689(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_689\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_690(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_690\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_691(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_692(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_692\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_693(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_694(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_694\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_697(auto val, auto _values, auto result) {
    iv_static_env->declare(val[INT64_C(1)][INT64_C(0)]);
    (result = ({ auto _e0 = iv_builder->restarg(val[INT64_C(0)], val[INT64_C(1)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_698(auto val, auto _values, auto result) {
    iv_static_env->declare_anonymous_restarg();
    (result = ({ auto _e0 = iv_builder->restarg(val[INT64_C(0)]); auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_701(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_701\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_702(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_702\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_703(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(1)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyArray<int64_t> _reduce_704(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyObject* _reduce_706(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_706\n"); std::abort();
    return nullptr;
  }

  RubyArray<int64_t> _reduce_707(auto val, auto _values, auto result) {
    (result = RubyArray_I64(0));
    return result;
  }

  RubyArray<int64_t> _reduce_709(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = val[INT64_C(0)]; auto _a = RubyArray<decltype(_e0)>(1); _a[0] = _e0;  _a; }));
    return result;
  }

  RubyObject* _reduce_710(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_710\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_711(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_711\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_712(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_712\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_713(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_713\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_714(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_714\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_715(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_715\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_716(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_716\n"); std::abort();
    return nullptr;
  }

  RubyArray<RubySymbol> _reduce_727(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = ruby_sym("dot"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(0)][INT64_C(1)]; _a; }));
    return result;
  }

  RubyArray<RubySymbol> _reduce_728(auto val, auto _values, auto result) {
    (result = ({ auto _e0 = ruby_sym("anddot"); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = val[INT64_C(0)][INT64_C(1)]; _a; }));
    return result;
  }

  RubyObject* _reduce_733(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_733\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_734(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_734\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_735(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_735\n"); std::abort();
    return nullptr;
  }

  RubyObject* _reduce_738(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_738\n"); std::abort();
    return nullptr;
  }

  RubyNil _reduce_742(auto val, auto _values, auto result) {
    (result = RUBY_NIL);
    return result;
  }

  RubyObject* _reduce_none(auto val, auto _values, auto result) {
    std::fprintf(stderr, "frozone: called TI-gap stub _reduce_none\n"); std::abort();
    return nullptr;
  }

};
template<> inline const char* ruby_class_name<Ruby_Ruby40>() { return "Ruby40"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Ruby40> : dustman::FieldList<Ruby_Ruby40, &Ruby_Ruby40::iv_static_env, &Ruby_Ruby40::iv_lexer, &Ruby_Ruby40::iv_max_numparam_stack, &Ruby_Ruby40::iv_context, &Ruby_Ruby40::iv_current_arg_stack, &Ruby_Ruby40::iv_pattern_variables, &Ruby_Ruby40::iv_pattern_hash_keys> {};
#endif



struct Ruby_Messages {
  RubyNil compile(auto reason, auto arguments) {
    RubyNil rb_template;
    (rb_template = MESSAGES[reason]);
    if (({ auto _l = (Hash.===(arguments)); (_l) ? decltype((arguments.empty_q()))(arguments.empty_q()) : decltype((arguments.empty_q()))(_l); })) {
      return rb_template;
    }
    return format(rb_template, arguments);
  }

};
static Ruby_Messages Messages;



int main() {
  FROZONE_GC_INIT();
  gc_local<Ruby_Type> t = nullptr;
  gc_local<Ruby_Type> t2 = nullptr;
  (t = gc_new<Ruby_Type>(ruby_sym("i64")));
  ruby_puts(ruby_to_s(t->kind()));
  ruby_puts(ruby_to_s(t->i64_q()));
  ruby_puts(ruby_to_s(t->numeric_q()));
  (t2 = gc_new<Ruby_Type>(ruby_sym("f64")));
  ruby_puts(ruby_to_s(t2->f64_q()));
  ruby_puts(t2->to_crystal());
  FROZONE_GC_SHUTDOWN();
  return 0;
}

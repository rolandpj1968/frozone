# C++ backend emitter for Frozone AOT compiler.
#
# Emits C++ source from the settled VM state + execute block AST,
# using the same TI results as the Crystal emitter. No type system
# translation layer — emit exactly what TI infers.
#
# Initial scope: unboxed Int64/Float64 arithmetic, user classes with
# typed ivars, method dispatch via virtual functions.

module Frozone
  module Compiler
    class CppEmitter
      def initialize
        @out = +""
        @indent = 0
      end

      def write(*strs) = strs.each { |s| @out << s }
      def line(str) = @out << ("  " * @indent) << str << "\n"
      def emit_indent = @out << ("  " * @indent)
      def emit_newline = @out << "\n"

      def indented
        @indent += 1
        yield
        @indent -= 1
      end

      def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
        @stub_file = stub_file
        @top_level_scope = top_level_scope
        # Ivar-type fixpoint: repeat ctor-arg + ivar inference until stable
        # or budget exhausted. Lets patterns like
        #   @root = Node.new(...)              # SplayTree infers @root: Ruby_Node
        #   node.set_left(@root)               # next pass: set_left arg is Ruby_Node
        #   def set_left(x); @left = x; end    # Node infers @left: Ruby_Node
        # converge in two iterations.
        @_class_ivar_types = {}
        @_class_method_return_types = {}
        @_top_level_method_return_types = {}
        3.times do
          @_ctor_param_types = collect_ctor_param_types(execute_block, top_level_scope)
          changed = false
          collect_user_classes(top_level_scope).each do |_n, cls|
            new_types = infer_ivar_types(cls)
            changed = true if @_class_ivar_types[cls.name] != new_types
            @_class_ivar_types[cls.name] = new_types
            @_current_wrapper_name = "Ruby_#{cls.name}"
            ret_types = {}
            (cls.methods_table || {}).each do |mname, m|
              next unless m.is_a?(Vm::Method) && method_defined_here?(m, cls)
              rt = infer_method_return_type(m)
              ret_types[mname] = rt if rt
            end
            @_class_method_return_types[cls.name] = ret_types
          end
          @_current_wrapper_name = nil
          # Top-level method return types (free functions).
          (top_level_scope.methods_table || {}).each do |mname, m|
            next unless m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            rt = infer_method_return_type(m)
            @_top_level_method_return_types[mname] = rt if rt
          end
          $stderr.puts "DBG top_level_rt=#{@_top_level_method_return_types.inspect}" if ENV['CPP_DEBUG']
          break unless changed
        end
        emit_header
        emit_newline

        # Emit settled value constants (Int64, Float64, etc.)
        emit_constants(top_level_scope, skip_objects: true)
        emit_newline

        # Emit user-defined classes
        emit_user_classes(top_level_scope)
        emit_newline

        # Emit settled object constants (after class definitions)
        emit_constants(top_level_scope, objects_only: true)
        emit_newline

        # Emit user-defined top-level methods
        emit_user_methods(top_level_scope)
        emit_newline

        emit_main(execute_block)
        @out
      end

      private

      # Ivar access:
      #   - Inside a wrapped class method/ctor body: `p->iv_<name>`
      #     (goes through the shared_ptr for reference semantics).
      #   - Outside (shouldn't happen for user code): bare `iv_<name>`.
      def cpp_ivar(name)
        stripped = name.to_s.delete_prefix('@')
        @_inside_wrapped_class ? "p->iv_#{stripped}" : "iv_#{stripped}"
      end

      # Ruby → C++ method name overrides (where Ruby name would be invalid or
      # shadow a keyword in C++).
      RUBY_TO_CPP_METHOD = {
        getbyte: :get_byte,
        setbyte: :set_byte,
        dup: :dup_,  # 'dup' is a POSIX function — avoid collision
      }.freeze

      # Translate Ruby method names with non-identifier suffixes to valid C++ identifiers.
      def cpp_method_name(name)
        if (override = RUBY_TO_CPP_METHOD[name])
          return override.to_s
        end
        s = name.to_s
        return "set_#{s.chomp('=')}" if s.end_with?('=')
        return "#{s.chomp('?')}_q" if s.end_with?('?')
        return "#{s.chomp('!')}_b" if s.end_with?('!')
        s
      end

      def trivial_body?(body)
        return true if body.nil?
        return true if body.is_a?(Ast::NilLiteral)
        return true if body.is_a?(Ast::Sequence) && body.nodes.size <= 1 &&
          (body.nodes.empty? || body.nodes[0].is_a?(Ast::NilLiteral))
        false
      end

      # Runtime is a real C++ header at cpp/runtime/frozone.hpp. Include
      # it at the top of every generated file. Edit the header directly
      # for runtime changes — no more ruby-string-quoted C++.
      def emit_header
        line "#include \"../runtime/frozone.hpp\""
      end

      CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

      # Ruby constant names that collide with C/C++ stdlib identifiers.
      # Emission renames them to avoid the clash.
      CPP_RESERVED_NAMES = %w[FILE stdin stdout stderr EOF NULL errno signal
                              strcpy strlen memcpy memset free exit abort].to_set.freeze

      # C++ keywords that Ruby allows as local variable names.
      CPP_KEYWORDS = %w[char class const enum extern export friend goto inline
                         mutable namespace operator private protected public
                         register short signed sizeof static struct switch
                         template this throw try typedef typename union unsigned
                         using virtual void volatile int float auto new delete
                         default case do if else while for break continue return
                         true false bool default do typeid wchar_t alignas
                         alignof asm decltype thread_local].to_set.freeze

      # Rename Ruby constant/module names that would collide with C/C++
      # stdlib identifiers. `FILE` -> `RUBY_FILE`, etc.
      def cpp_const_name(name)
        s = name.to_s
        CPP_RESERVED_NAMES.include?(s) ? "RUBY_#{s}" : s
      end

      # Rename Ruby local variable names that collide with C++ keywords.
      def cpp_local_name(name)
        s = name.to_s
        CPP_KEYWORDS.include?(s) ? "rb_#{s}" : s
      end

      def user_source_location?(loc)
        return false if loc.nil?
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @stub_file && file == @stub_file
        CORE_PATH_MARKERS.none? { |m| file.include?(m) }
      end

      # Emit an ArrayObject constant as a global RubyArray<T>, initialised
      # inside a `static auto` factory call to work around the lack of
      # static-init syntax for our runtime types.
      def emit_array_const(cname, arr_obj)
        elems = arr_obj.raw
        if elems.empty?
          line "static auto #{cname} = RubyArray_I64();"
          return
        end
        # Infer element C++ type from the first element.
        elem_type = case elems.first
                    when Vm::IntegerObject then "int64_t"
                    when Vm::FloatObject then "double"
                    when Vm::StringObject then "RubyString"
                    when Vm::TrueObject, Vm::FalseObject then "bool"
                    else return  # nested arrays, objects — skip
                    end
        # Encode each element as a C++ initializer expression.
        init_exprs = elems.map do |e|
          case e
          when Vm::IntegerObject then "INT64_C(#{e.raw})"
          when Vm::FloatObject then e.raw.to_s
          when Vm::StringObject then "RubyString(#{e.raw.inspect}, #{e.raw.bytesize})"
          when Vm::TrueObject then "true"
          when Vm::FalseObject then "false"
          else return  # mixed types — skip
          end
        end
        # Emit as an inline-init function so the vector gets populated once.
        line "static auto #{cname} = []() { RubyArray<#{elem_type}> _a(#{elems.size});"
        init_exprs.each_with_index do |expr, i|
          line "  (*_a.data)[#{i}] = #{expr};"
        end
        line "  return _a; }();"
      end

      # All VM "primitive" value types that lower to C++ scalars/RubyString
      # (not user-defined ObjectObject instances).
      PRIMITIVE_VALUE_TYPES = [
        Vm::IntegerObject, Vm::FloatObject, Vm::StringObject,
        Vm::TrueObject, Vm::FalseObject
      ].freeze

      def primitive_value?(v)
        PRIMITIVE_VALUE_TYPES.any? { |c| v.is_a?(c) }
      end

      def emit_constants(scope, skip_objects: false, objects_only: false)
        const_table = scope.constants_table || {}
        const_locs = scope.constants_locations || {}
        const_table.each do |name, value|
          next if value.is_a?(Vm::ModuleObject)
          loc = const_locs[name]
          next unless user_source_location?(loc)
          # "Object" here means an instance of a user-defined class,
          # not a primitive value (Int/Float/Str/Bool).
          is_user_obj = value.is_a?(Vm::ObjectObject) && !primitive_value?(value)
          next if skip_objects && is_user_obj
          next if objects_only && !is_user_obj
          cname = cpp_const_name(name)
          case value
          when Vm::IntegerObject then line "static const int64_t #{cname} = #{value.raw}LL;"
          when Vm::FloatObject then line "static const double #{cname} = #{value.raw};"
          when Vm::StringObject
            raw = value.raw
            line "static const RubyString #{cname} = RubyString(#{raw.inspect}, #{raw.bytesize});"
          when Vm::TrueObject then line "static const bool #{cname} = true;"
          when Vm::FalseObject then line "static const bool #{cname} = false;"
          when Vm::ArrayObject
            # Emit as RubyArray<T> with inferred element type. For mixed-
            # type arrays (not expected in user constants), bail out.
            emit_array_const(cname, value)
          when Vm::ObjectObject
            klass = value.class_object
            next unless klass.is_a?(Vm::ClassObject) && klass.name
            next if %i[Hash Array Range Regexp Proc].include?(klass.name)
            line "static Ruby_#{klass.name} #{cname};"
          end
        end
      end

      def emit_user_classes(scope)
        # Collect user classes recursively (including classes nested inside
        # other classes, e.g. SplayTree::Node). Nested classes are promoted
        # to top-level; inside each subtree, nested children are emitted
        # before their parent (parent's methods may reference the child's
        # type by bare name); across siblings, definition order is preserved.
        collect_user_classes(scope).each do |name, cls|
          emit_class(name, cls)
          emit_newline
        end
      end

      # Returns [name, class_object] pairs in emission order: for each
      # top-level class, all its nested classes come first, then the class
      # itself; siblings follow definition order.
      def collect_user_classes(scope, seen = {})
        result = []
        const_locs = scope.constants_locations || {}
        (scope.constants_table || {}).each do |name, value|
          next unless value.is_a?(Vm::ClassObject)
          next if value.name.nil? || %i[Object BasicObject Module Class Kernel].include?(value.name)
          next if seen[value]
          seen[value] = true
          methods = value.methods_table || {}
          has_user_method = methods.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }
          next unless has_user_method || user_source_location?(const_locs[name])
          # Emit nested children first, then the parent itself.
          result.concat(collect_user_classes(value, seen))
          result << [name, value]
        end
        result
      end

      # Emit a user class as a shared_ptr-wrapping value type:
      #   struct Ruby_X {
      #     struct Impl { <ivars>; };
      #     std::shared_ptr<Impl> p;
      #     Ruby_X(...) : p(std::make_shared<Impl>()) { <init body using p->iv_*> }
      #     <methods delegating through p->iv_*>
      #   };
      # This gives Ruby reference semantics: copying the wrapper aliases the
      # Impl via shared_ptr, so `b = arr[i]; b.set_x(v)` mutates the original.
      def emit_class(name, cls)
        if struct_subclass?(cls)
          emit_struct_class(name, cls)
          return
        end
        line "struct Ruby_#{name} {"
        init = cls.methods_table&.fetch(:initialize, nil)
        ivars = []
        if init.is_a?(Vm::Method) && init.body
          collect_ivars_from_body(init.body, ivars)
        end
        ivar_types = infer_ivar_types(cls)
        init_has_params = init.is_a?(Vm::Method) && !all_param_names(init).empty?
        self_wrapper = "Ruby_#{name}"

        # Self-referential ivars: fields whose type equals the enclosing
        # class's wrapper. Can't store by value (incomplete type) — store
        # as std::shared_ptr<Impl> and wrap/unwrap at access sites.
        self_ref_ivars = ivar_types.select { |_, t| t == self_wrapper }.keys.to_set
        @_self_ref_ivars = self_ref_ivars
        @_current_wrapper_name = self_wrapper

        indented do
          # Nested Impl struct holds all the data — ivars only, no methods.
          line "struct Impl {"
          indented do
            ivars.uniq.each do |iv|
              key = iv.to_s.delete_prefix('@')
              t = ivar_types[key] || "int64_t"
              if self_ref_ivars.include?(key)
                # Recursive field: store as shared_ptr<Impl> (same type).
                line "std::shared_ptr<Impl> iv_#{key};"
              else
                default = (t == "int64_t") ? " = 0" : (t == "double" ? " = 0.0" : "")
                line "#{t} iv_#{key}#{default};"
              end
            end
          end
          line "};"
          line "std::shared_ptr<Impl> p;"
          emit_newline

          # Self-ref ctor and conversion — lets `p->iv_left = other` assign
          # the shared_ptr directly (via operator) and `Ruby_X(p->iv_left)`
          # wrap a shared_ptr back into a wrapper.
          unless self_ref_ivars.empty?
            line "Ruby_#{name}(std::shared_ptr<Impl> p_) : p(p_) {}"
            line "operator std::shared_ptr<Impl>() const { return p; }"
          end

          @_inside_wrapped_class = true

          # Default ctor: nil unless the user's init is 0-arg (then we
          # must allocate and run it so `static Ruby_X OBJ;` works).
          if init.is_a?(Vm::Method) && !init_has_params
            # 0-arg init: default ctor allocates + runs the init body.
            line "Ruby_#{name}() : p(std::make_shared<Impl>()) {"
            @_declared_locals = Set.new; @_optional_locals = {}
            indented { emit(init.body) }
            line "}"
          else
            line "Ruby_#{name}() = default;"
          end

          # Nil conversion — assigning RUBY_NIL leaves p as nullptr.
          line "Ruby_#{name}(const RubyNil&) {}"

          # Parameterised ctor — only if init has params; allocates + runs body.
          if init_has_params
            params = emit_param_list(init)
            line "Ruby_#{name}(#{params}) : p(std::make_shared<Impl>()) {"
            @_declared_locals = Set.new; @_optional_locals = {}
            all_param_names(init).each { |p| @_declared_locals << p.to_s }
            indented { emit(init.body) }
            line "}"
          end

          emit_newline
          # Methods DEFINED on this class (skip inherited via module erasure).
          cls.methods_table&.each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            next if mname == :initialize
            next unless user_source_location?(method.source_location) || accessor_method?(method)
            next unless method_defined_here?(method, cls)
            emit_class_method(mname, method)
            emit_newline
          end

          @_inside_wrapped_class = false

          line "bool nil_q() const { return !p; }"
          # Contextual bool: non-nil wrapper is truthy. Used for `||`, `&&`,
          # `if (x)`, and ternaries in Ruby-translated code.
          line "explicit operator bool() const { return (bool)p; }"
        end
        line "};"
        # Register class name for `.class` dispatch.
        line "template<> inline const char* ruby_class_name<Ruby_#{name}>() { return \"#{name}\"; }"
        @_self_ref_ivars = nil
        @_current_wrapper_name = nil
      end

      def emit_struct_class(name, cls)
        members = struct_members_for(cls)
        ctor_types = @_ctor_param_types[name] || []
        line "struct Ruby_#{name} {"
        @_current_wrapper_name = "Ruby_#{name}"
        @_self_ref_ivars = Set.new
        indented do
          line "struct Impl {"
          indented do
            members.each_with_index do |m, i|
              t = ctor_types[i] || "int64_t"
              default = (t == "int64_t") ? " = 0" : (t == "double" ? " = 0.0" : "")
              line "#{t} iv_#{m}#{default};"
            end
          end
          line "};"
          line "std::shared_ptr<Impl> p;"
          emit_newline

          line "Ruby_#{name}() = default;"
          line "Ruby_#{name}(const RubyNil&) {}"

          params = members.each_with_index.map { |m, i|
            t = ctor_types[i] || "auto"
            "#{t} _#{m}"
          }.join(", ")
          line "Ruby_#{name}(#{params}) : p(std::make_shared<Impl>()) {"
          indented { members.each { |m| line "p->iv_#{m} = _#{m};" } }
          line "}"
          emit_newline

          members.each do |m|
            t = ctor_types[members.index(m)] || "auto"
            line "#{t} #{m}() const { return p->iv_#{m}; }"
            line "void set_#{m}(#{t} v) { p->iv_#{m} = v; }"
          end
          emit_newline

          line "bool nil_q() const { return !p; }"
          line "explicit operator bool() const { return (bool)p; }"
        end
        line "};"
        line "template<> inline const char* ruby_class_name<Ruby_#{name}>() { return \"#{name}\"; }"
        @_self_ref_ivars = nil
        @_current_wrapper_name = nil
      end

      # Walks every AST node rooted at `root` (the execute block + every
      # user method body) and records, for each `ClassName.new(args...)`
      # call, the type of each positional arg. Types are widened across
      # call sites: if Planet.new is ever called with a double at arg 0,
      # arg 0 is considered double.
      def collect_ctor_param_types(execute_block, scope)
        seen = {}   # class_name => [types by positional index]
        @_method_call_arg_types = {}   # [method_name] => [types by arg index]
        # `cls_ctx` is the class currently being walked (nil at top level /
        # in free functions). Passed through so InstanceVariableRead can
        # resolve via @_class_ivar_types.
        walker = nil
        walker = lambda do |node, cls_ctx|
          return unless node
          if node.is_a?(Ast::MethodCall) && node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
            cls_name = node.receiver_node.name
            (node.arg_nodes || []).each_with_index do |arg, i|
              t = infer_expr_type_ctx(arg, cls_ctx)
              existing = (seen[cls_name] ||= [])
              existing[i] = widen_type(existing[i], t)
            end
          end
          if node.is_a?(Ast::MethodCall) && node.receiver_node && node.name != :new
            (node.arg_nodes || []).each_with_index do |arg, i|
              t = infer_expr_type_ctx(arg, cls_ctx)
              key = node.name
              existing = (@_method_call_arg_types[key] ||= [])
              existing[i] = widen_type(existing[i], t)
            end
          end
          # AttributeWrite (`obj.foo = val`) — Ruby method name is `:foo=`,
          # which our emitter maps to `set_foo`. Record arg type under the
          # ORIGINAL Ruby name so infer_ivar_types can find it later.
          if node.is_a?(Ast::AttributeWrite) && node.receiver_node
            (node.arg_nodes || []).each_with_index do |arg, i|
              t = infer_expr_type_ctx(arg, cls_ctx)
              key = node.name
              existing = (@_method_call_arg_types[key] ||= [])
              existing[i] = widen_type(existing[i], t)
            end
          end
          node.children.each { |c| walker.call(c, cls_ctx) if c.is_a?(Ast::Node) }
        end
        walker.call(execute_block, nil)
        (scope.methods_table || {}).each_value { |m| walker.call(m.body, nil) if m.is_a?(Vm::Method) }
        (scope.constants_table || {}).each_value do |v|
          next unless v.is_a?(Vm::ClassObject)
          (v.methods_table || {}).each_value { |m| walker.call(m.body, v) if m.is_a?(Vm::Method) }
          # Also descend into nested classes with their own cls_ctx.
          (v.constants_table || {}).each_value do |nv|
            next unless nv.is_a?(Vm::ClassObject)
            (nv.methods_table || {}).each_value { |m| walker.call(m.body, nv) if m.is_a?(Vm::Method) }
          end
        end
        seen
      end

      # infer_expr_type with an optional current-class context, so
      # InstanceVariableRead/Write can be resolved via @_class_ivar_types
      # from the previous fixpoint iteration.
      def infer_expr_type_ctx(node, cls_ctx)
        if node.is_a?(Ast::InstanceVariableRead) && cls_ctx
          t = (@_class_ivar_types[cls_ctx.name] || {})[node.name.to_s.delete_prefix('@')]
          return t if t
        end
        if node.is_a?(Ast::MethodCall) && %i[+ - * / %].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
          l = infer_expr_type_ctx(node.receiver_node, cls_ctx)
          r = infer_expr_type_ctx(node.arg_nodes[0], cls_ctx)
          return "double" if l == "double" || r == "double"
        end
        infer_expr_type(node)
      end

      # Picks a type that accommodates both existing and new observations.
      # Prefer more-specific types: any class type > double > int64_t.
      # Int64 is the default / fallback when we couldn't infer better,
      # so a later call site observing a class/double type takes priority.
      def widen_type(existing, new_t)
        return new_t if existing.nil?
        return existing if existing == new_t
        # "auto" = unknown; treat as least specific, never let it clobber
        # a concrete type.
        return existing if new_t == "auto"
        return new_t if existing == "auto"
        return new_t if existing == "int64_t"
        return existing if new_t == "int64_t"
        return "double" if [existing, new_t].include?("double")
        existing
      end

      # Scans every method body on `cls` for ivar writes and tries to infer
      # the C++ type from the RHS (class instance, float literal, or a RHS
      # that touches a known-double constant). Ivars with conflicting or
      # unrecognised RHS types default to int64_t at emission time.
      def infer_ivar_types(cls)
        candidates = {}   # ivar_name => Set[cpp_type]
        (cls.methods_table || {}).each do |mname, method|
          next unless method.is_a?(Vm::Method) && method.body
          # Only consider methods defined on THIS class (post-flatten).
          next unless method_defined_here?(method, cls)
          # Param type map for THIS method. For initialize, use ctor
          # call-site types. For other methods, use per-method call-site
          # arg types collected across the whole program.
          param_types = if mname == :initialize
            @_ctor_param_types[cls.name] || []
          else
            @_method_call_arg_types[mname] || []
          end
          param_names = method.required_params || []
          walk_ivar_assigns_with_params(method.body, param_names, param_types) do |ivar_name, cpp_type|
            (candidates[ivar_name] ||= Set.new) << cpp_type
          end
        end
        # Unify: if all observed types agree (including after ignoring a
        # non-nil default like int64_t == 0), pick the single type. If we
        # see "double" OR "Ruby_X" mixed with "int64_t", prefer the
        # non-int one (the int64_t came from an `@x = 0` default init).
        candidates.each_with_object({}) do |(iv, types), out|
          types.delete("int64_t") if types.size > 1
          out[iv] = types.first if types.size == 1
        end
      end

      def walk_ivar_assigns_with_params(node, param_names, param_types, &block)
        return unless node
        if node.is_a?(Ast::InstanceVariableWrite)
          yield node.name.to_s.delete_prefix('@'), infer_expr_type_with_params(node.value_node, param_names, param_types)
        elsif node.is_a?(Ast::MultipleAssignment)
          targets = node.targets || []
          vals = node.value_node
          elems = vals.is_a?(Ast::ArrayLiteral) ? (vals.element_nodes || []) : []
          targets.each_with_index do |(kind, name), i|
            next unless kind == :ivar && elems[i]
            yield name.to_s.delete_prefix('@'), infer_expr_type_with_params(elems[i], param_names, param_types)
          end
        end
        node.children.each { |c| walk_ivar_assigns_with_params(c, param_names, param_types, &block) if c.is_a?(Ast::Node) }
      end

      # Like infer_expr_type, but also resolves LocalVariableRead of a
      # known parameter back to its call-site-inferred type.
      def infer_expr_type_with_params(node, param_names, param_types)
        if node.is_a?(Ast::LocalVariableRead) && param_types
          idx = param_names.index(node.name)
          return param_types[idx] if idx && param_types[idx]
        end
        if node.is_a?(Ast::MethodCall) && %i[+ - * / %].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
          l = infer_expr_type_with_params(node.receiver_node, param_names, param_types)
          r = infer_expr_type_with_params(node.arg_nodes[0], param_names, param_types)
          return "double" if l == "double" || r == "double"
        end
        infer_expr_type(node)
      end

      # Best-effort expression-type inference for ivar type candidates.
      # Returns "Ruby_Klass", "RubyString", "double", or "int64_t".
      def infer_expr_type(node)
        case node
        when Ast::FloatLiteral then "double"
        when Ast::StringLiteral then "RubyString"
        when Ast::MethodCall
          if node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
            cn = node.receiver_node.name
            return "RubyString" if cn == :String
            return "Ruby_#{cn}"
          end
          # Arithmetic: if either operand is a double, propagate.
          if %i[+ - * / %].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
            l = infer_expr_type(node.receiver_node)
            r = infer_expr_type(node.arg_nodes[0])
            return "double" if l == "double" || r == "double"
          end
          "int64_t"
        when Ast::ConstantRead
          if @top_level_scope
            c = @top_level_scope.constants_table&.fetch(node.name, nil)
            return "double" if c.is_a?(Vm::FloatObject)
            return "RubyString" if c.is_a?(Vm::StringObject)
          end
          "int64_t"
        else "int64_t"
        end
      end

      def collect_ivars_from_body(node, result)
        return unless node
        if node.is_a?(Ast::InstanceVariableWrite)
          result << node.name.to_s
        elsif node.is_a?(Ast::InstanceVariableRead)
          result << node.name.to_s
        elsif node.is_a?(Ast::MultipleAssignment)
          # Targets are [kind, name] tuples; harvest ivar targets directly.
          (node.targets || []).each do |kind, name|
            result << name.to_s if kind == :ivar
          end
        end
        node.children.each { |c| collect_ivars_from_body(c, result) if c.is_a?(Ast::Node) }
      end

      # Checks whether the method was originally defined on `cls` (vs
      # inherited and flattened in via module erasure). Uses `method.scopes`,
      # which records the class the `def` appeared in.
      def method_defined_here?(method, cls)
        scopes = method.scopes
        return true if scopes.nil? || scopes.empty?
        scopes.last.equal?(cls)
      end

      def struct_subclass?(cls)
        c = cls
        while c
          return true if c.name == :Struct
          c = c.respond_to?(:superclass) ? c.superclass : nil
        end
        false
      end

      def struct_members_for(cls)
        members_obj = cls.get_ivar(:@members)
        return [] unless members_obj.is_a?(Vm::ArrayObject)
        members_obj.raw.map { |m| m.respond_to?(:raw) ? m.raw.to_s : m.to_s }
      end

      def accessor_method?(method)
        method.body.is_a?(Ast::InstanceVariableRead) || method.body.is_a?(Ast::InstanceVariableWrite)
      end

      # Decide a local variable's declared C++ type from its initializer.
      # `int64_t` for plain integer-typed exprs; `auto` for class instances,
      # arrays, method calls (which may return auto-deduced types), and
      # anything ambiguous.
      # Heuristic: a 2-element ArrayLiteral whose elements are all nil literals
      # or self-free method calls (e.g. recursive `bottom_up_tree(d)`) is
      # treated as a binary-tree node. This maps `[nil, nil]` and
      # `[bottom_up_tree(d), bottom_up_tree(d)]` onto a uniform RubyTree type,
      # sidestepping heterogeneous-recursion return-type mismatches.
      def tree_node_literal?(node)
        return false unless node.is_a?(Ast::ArrayLiteral)
        elems = node.element_nodes || []
        return false unless elems.size == 2
        elems.all? do |e|
          e.is_a?(Ast::NilLiteral) ||
            (e.is_a?(Ast::MethodCall) && e.receiver_node.nil?)
        end
      end

      # Scans `body` for the first non-nil LocalVariableWrite to `name` and
      # returns its inferred type. Returns nil if none found.
      def look_ahead_local_type(name, body)
        best = nil
        has_nil_write = false  # any write of NilLiteral OR a RubyNil-returning method
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::LocalVariableWrite) && node.name.to_s == name
            if node.value_node.is_a?(Ast::NilLiteral)
              has_nil_write = true
            else
              t = deep_decl_type(node.value_node)
              if t == "RubyNil"
                has_nil_write = true
              elsif t
                best = widen_type(best, t)
              end
            end
          end
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        walker.call(body)
        # If we saw both a concrete primitive type AND a nil write,
        # promote to std::optional<T>. Class-typed locals are already
        # naturally nullable via shared_ptr so leave them as-is.
        if has_nil_write && best && %w[int64_t double bool].include?(best)
          return "std::optional<#{best}>"
        end
        best == "int64_t" ? nil : best
      end

      # Like local_decl_type but follows top-level method calls to their
      # return type by inspecting the body's last expression.
      def deep_decl_type(val)
        t = local_decl_type(val)
        return t unless t == "auto"
        if val.is_a?(Ast::MethodCall) && val.receiver_node.nil?
          # Prefer the cached return type (populated from infer_method_return_type
          # which looks at all explicit returns).
          rt = (@_top_level_method_return_types || {})[val.name]
          return rt if rt
          m = lookup_top_level_method(val.name)
          if m && m.body
            last = m.body.is_a?(Ast::Sequence) ? m.body.nodes.last : m.body
            return deep_decl_type(last) if last
          end
        end
        "auto"
      end

      def local_decl_type(val)
        @_decl_depth ||= 0
        return "auto" if @_decl_depth > 5
        @_decl_depth += 1
        begin
          _local_decl_type_impl(val)
        ensure
          @_decl_depth -= 1
        end
      end

      def _local_decl_type_impl(val)
        case val
        when Ast::Or, Ast::And
          # Type of `a || b` is the right operand's type (typical
          # `x || @default` pattern where right is the real fallback).
          local_decl_type(val.right_node)
        when Ast::LocalVariableRead
          # Try to resolve by finding the variable's first assignment in
          # the current body.
          if @_current_body
            later = look_ahead_local_type(val.name.to_s, @_current_body)
            return later if later
          end
          "auto"
        when Ast::InstanceVariableRead
          # Look up the ivar's inferred type in the enclosing class.
          if @_current_wrapper_name
            cls_name = @_current_wrapper_name.sub(/^Ruby_/, '').to_sym
            t = (@_class_ivar_types[cls_name] || {})[val.name.to_s.delete_prefix('@')]
            return t if t
          end
          "auto"
        when Ast::InstanceVariableWrite
          # `@foo = x` evaluates to x; type is the value's type.
          local_decl_type(val.value_node)
        when Ast::LocalVariableWrite
          # `x = y = expr` — chained; type flows through the RHS.
          local_decl_type(val.value_node)
        when Ast::MethodCall
          if val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
            cn = val.receiver_node.name
            return "RubyString" if cn == :String
            return cn == :Array ? "auto" : "Ruby_#{cn}"
          end
          # Indexed read like `arr[i]` — use `auto` (value). Since user
          # class wrappers are shared_ptr-based, a value copy aliases the
          # underlying Impl, so mutations via setters still propagate.
          # RubyString[i] returns a 1-char rvalue — `auto` is the only
          # safe option (can't bind a reference to a temporary).
          return "auto" if val.name == :[] && val.receiver_node && (val.arg_nodes || []).size == 1
          # If the receiver's type resolves to a known user class, look up
          # the called method's return type (helps `tmp = node.left` etc).
          if val.receiver_node
            recv_t = local_decl_type(val.receiver_node)
            if recv_t&.start_with?("Ruby_")
              cls_name = recv_t.sub("Ruby_", "").to_sym
              rt = (@_class_method_return_types || {})[cls_name]&.[](val.name)
              return rt if rt
            end
          end
          "auto"
        when Ast::ArrayLiteral
          # 2-element [nil, call()] → RubyTree; otherwise infer element
          # type from the first element, default to RubyArray<int64_t>.
          if tree_node_literal?(val)
            "RubyTree"
          elsif (elems = val.element_nodes).any?
            et = local_decl_type(elems.first)
            et = "int64_t" if et == "auto"
            "RubyArray<#{et}>"
          else
            "RubyArray_I64"
          end
        when Ast::HashLiteral
          pairs = (val.kv_nodes || []).reject { |k, _| k.nil? }
          if pairs.empty?
            "RubyHash<RubySymbol, int64_t>"
          else
            k_type = key_type_for(pairs[0][0])
            val_types = pairs.map { |_, v| local_decl_type(v) }.uniq
            v_type = val_types.size == 1 ? val_types[0] : "int64_t"
            v_type = "int64_t" if v_type == "auto"
            "RubyHash<#{k_type}, #{v_type}>"
          end
        when Ast::SymbolLiteral then "RubySymbol"
        when Ast::FloatLiteral then "double"
        when Ast::StringLiteral then "RubyString"
        when Ast::TrueLiteral, Ast::FalseLiteral then "bool"
        when Ast::ConstantRead
          # Constant lookup — could be any type. Resolve at compile time if we
          # have access to the top-level scope's constants table.
          if @top_level_scope
            c = @top_level_scope.constants_table&.fetch(val.name, nil)
            return "RubyString" if c.is_a?(Vm::StringObject)
            return "double" if c.is_a?(Vm::FloatObject)
          end
          "auto"
        else "int64_t"
        end
      end

      # Detect if a method body's last expression returns a non-int64_t value
      # (class instance, array literal, Array.new). If so, use 'auto' return
      # type so C++ deducer picks up the struct type.
      def returns_non_int?(body)
        last = body.is_a?(Ast::Sequence) ? body.nodes.last : body
        return true if last.is_a?(Ast::ArrayLiteral)
        return false unless last.is_a?(Ast::MethodCall)
        return true if last.name == :new && last.receiver_node.is_a?(Ast::ConstantRead)
        false
      end

      # Collect every LocalVariableWrite's name in `body`, in source order,
      # paired with the type inferred from its first-seen write. Used to
      # hoist declarations to method top so inner-scope locals are visible
      # outside their nested block (matches Ruby's method-wide local scope).
      def collect_hoistable_locals(body, param_names)
        prev_body = @_current_body
        @_current_body = body
        seen = {}  # name => {type:, first_rhs:}
        order = []
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::LocalVariableWrite)
            name = node.name.to_s
            unless seen.key?(name) || param_names.include?(name.to_sym) || param_names.include?(name)
              # Use the WIDEST type across all writes in this body so
              # `last = 0; ...; last = fannkuch(N)` picks up RubyArray
              # rather than locking in int64_t from the first write.
              widened = look_ahead_local_type(name, body)
              widened ||= local_decl_type(node.value_node)
              seen[name] = { type: widened, first_rhs: node.value_node }
              order << name
            end
          elsif node.is_a?(Ast::MultipleAssignment)
            vals = node.value_node
            elems = vals.is_a?(Ast::ArrayLiteral) ? (vals.element_nodes || []) : []
            (node.targets || []).each_with_index do |t, i|
              kind, nm = t[0], t[1]
              next unless kind == :local
              s = nm.to_s
              next if seen.key?(s) || param_names.include?(nm) || param_names.include?(s)
              # Per-target type inference: ArrayLiteral → elem[i]'s type;
              # else unknown ("auto").
              per_elem = elems[i]
              if per_elem
                seen[s] = { type: local_decl_type(per_elem), first_rhs: per_elem }
              else
                seen[s] = { type: "auto", first_rhs: nil }
              end
              order << s
            end
          end
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        walker.call(body)
        @_current_body = prev_body
        order.map { |n| [n, seen[n]] }
      end

      # True if the body contains any explicit `return` statement.
      def has_explicit_return?(node)
        return false unless node
        return true if node.is_a?(Ast::Return)
        node.children.any? { |c| c.is_a?(Ast::Node) && has_explicit_return?(c) }
      end

      # Scan method body for the richest non-nil return type. Used to
      # wrap `return nil` as `return T(RUBY_NIL)` so C++ auto-deduction
      # doesn't choke on RubyNil-vs-T mixed returns.
      def infer_method_return_type(method)
        body = method.body
        return nil unless body
        prev_body = @_current_body
        @_current_body = body
        @_current_body_has_explicit_return = has_explicit_return?(body)
        best = nil
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::Return) && node.value_node && !node.value_node.is_a?(Ast::NilLiteral)
            t = local_decl_type(node.value_node)
            best = widen_type(best, t) if t && t != "int64_t" && t != "auto"
          end
          # Last expression in a Sequence is an implicit return.
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        walker.call(body)
        # Also pick up the final expression if there's no explicit return.
        last = body.is_a?(Ast::Sequence) ? body.nodes.last : body
        if last && !last.is_a?(Ast::NilLiteral) && !last.is_a?(Ast::Return)
          t = local_decl_type(last)
          best = widen_type(best, t) if t && t != "int64_t" && t != "auto"
        end
        # Method body with no explicit returns AND last statement is a
        # loop/while/for → Ruby returns nil. Record "RubyNil" so callers
        # can widen their local types to std::optional<T>.
        if best.nil? && !@_current_body_has_explicit_return && last &&
           (last.is_a?(Ast::While) || last.is_a?(Ast::Until) || last.is_a?(Ast::ForLoop))
          best = "RubyNil"
        end
        @_current_body = prev_body
        best
      end

      def emit_class_method(mname, method)
        # Use 'auto' for params so C++20 can deduce per call site
        # (covers both int64_t and class-typed args without explicit TI)
        params = emit_param_list(method)
        # Always 'auto' return — C++20 deduces. Works for recursion when
        # at least one base-case return is non-recursive.
        line "auto #{cpp_method_name(mname)}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}
        @_method_return_type = infer_method_return_type(method)
        all_param_names(method).each { |p| @_declared_locals << p.to_s }
        indented do
          body = method.body
          emit_hoisted_locals(body, all_param_names(method))
          if trivial_body?(body)
            line "return 0LL;"
          elsif body.is_a?(Ast::InstanceVariableRead)
            # Route through cr() so self-ref ivars get wrapped as Ruby_<Name>.
            line "return #{cr(body)};"
          elsif body.is_a?(Ast::InstanceVariableWrite)
            # attr_writer body: @foo = val (returns val)
            line "#{cr(body)};"
            line "return #{cr(Ast::InstanceVariableRead.new(body.name))};"
          elsif body.is_a?(Ast::Sequence)
            nodes = body.nodes
            nodes[0...-1].each { |n| emit_stmt(n) }
            emit_stmt_return(nodes.last) if nodes.last
          else
            emit_stmt_return(body)
          end
        end
        @_method_return_type = nil
        line "}"
      end

      # Hoist locals with a determinable type to the method top. Locals
      # first-defined in an inner scope stay visible for subsequent outer
      # uses (matches Ruby's method-wide local scope vs C++ block scope).
      # Locals whose type we can't resolve are left to per-site decl.
      def emit_hoisted_locals(body, param_names)
        @_current_body = body
        param_names_set = param_names.map(&:to_s).to_set
        collect_hoistable_locals(body, param_names).each do |name, info|
          t = info[:type]
          next if t.nil?
          next if @_declared_locals&.include?(name)
          decl_name = cpp_local_name(name)
          if t == "auto" || t == "auto&"
            rhs = info[:first_rhs]
            next unless rhs && rhs_safe_for_decltype?(rhs, param_names_set)
            rhs_str = cr(rhs)
            line "std::decay_t<decltype(#{rhs_str})> #{decl_name}{};"
          else
            init = case t
                   when "int64_t" then " = 0"
                   when "double" then " = 0.0"
                   when "bool" then " = false"
                   else ""
                   end
            line "#{t} #{decl_name}#{init};"
            if (m = t.match(/\Astd::optional<(.+)>\z/))
              (@_optional_locals ||= {})[name] = m[1]
            end
          end
          @_declared_locals << name
        end
      end

      # True when the expression can be placed inside `decltype(...)`.
      # Conditions:
      #   1. Every LocalVariableRead references a name already visible at
      #      the hoisting point (a method parameter, or a local that was
      #      already hoisted earlier in this pass).
      #   2. The emitted C++ is a plain expression — no statement-expression
      #      wrappers (`({...})`) which GCC disallows inside decltype.
      def rhs_safe_for_decltype?(node, param_names_set)
        return true unless node
        # Statement-expression-generating nodes: Array.new with a block,
        # multi-element ArrayLiterals, And/Or (our ternary form), If,
        # MultipleAssignment — all emit as `({...})`.
        case node
        when Ast::And, Ast::Or, Ast::If, Ast::MultipleAssignment
          return false
        when Ast::ArrayLiteral
          return false if (node.element_nodes || []).size > 0 && !tree_node_literal?(node)
        when Ast::MethodCall
          if node.name == :new && node.block_node &&
             node.receiver_node.is_a?(Ast::ConstantRead) && node.receiver_node.name == :Array
            return false
          end
          # `.times { }`, `.each { }` with a block expand to statement-exprs too.
          return false if node.block_node
        end
        if node.is_a?(Ast::LocalVariableRead)
          name = node.name.to_s
          return true if param_names_set.include?(name)
          return true if @_declared_locals&.include?(name)
          return false
        end
        node.children.all? { |c| !c.is_a?(Ast::Node) || rhs_safe_for_decltype?(c, param_names_set) }
      end

      def emit_constructor(name, init)
        # Use `auto` for params so int/float/class args all bind correctly
        # per call site (C++20 abbreviated function template).
        params = emit_param_list(init)
        line "Ruby_#{name}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}
        (init.required_params || []).each { |p| @_declared_locals << p.to_s }
        indented { emit(init.body) }
        line "}"
      end

      def emit_user_methods(scope)
        scope.methods_table&.each do |name, method|
          next unless method.is_a?(Vm::Method) && user_source_location?(method.source_location)
          # Skip stub methods and methods with trivial/nil bodies
          next if trivial_body?(method.body)
          emit_method(name, method)
          emit_newline
        end
      end

      def all_param_names(method)
        ((method.required_params || []) + (method.optional_params || []).map { |name, _| name } + (method.required_kw_params || []))
      end

      # Renders `auto <name>` for required params and
      # `auto <name> = <default>` for optional params (C++20 abbreviated
      # function templates support default args).
      def emit_param_list(method)
        parts = []
        (method.required_params || []).each { |p| parts << "auto #{p}" }
        (method.optional_params || []).each do |pname, default_node|
          parts << "auto #{pname} = #{cr(default_node)}"
        end
        (method.required_kw_params || []).each { |p| parts << "auto #{p}" }
        parts.join(", ")
      end

      def emit_method(name, method)
        params = emit_param_list(method)
        line "static auto #{cpp_method_name(name)}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}
        @_method_return_type = infer_method_return_type(method)
        all_param_names(method).each { |p| @_declared_locals << p.to_s }
        indented do
          body = method.body
          emit_hoisted_locals(body, all_param_names(method))
          if body.is_a?(Ast::Sequence)
            nodes = body.nodes
            nodes[0...-1].each { |n| emit_stmt(n) }
            emit_stmt_return(nodes.last) if nodes.last
          else
            emit_stmt_return(body)
          end
        end
        @_method_return_type = nil
        line "}"
      end

      def emit_stmt_return(node)
        s = cr(node)
        if s.include?("{\n") || s.start_with?("if ") || s.start_with?("while ") || s.start_with?("for ") || s.start_with?("return ")
          if s.include?("{\n")
            emit_indent; write s; emit_newline
          else
            line "#{s};"
          end
          if s.start_with?("while ") || s.start_with?("for ")
            # Loops don't yield a value. Behaviour:
            #   - Known return type → emit typed default return.
            #   - No explicit return in body → emit `return RUBY_NIL` so
            #     callers get a nil-convertible value.
            #   - Has explicit returns → trailing is unreachable; avoid
            #     return here so `auto` doesn't deduce to void (vs the
            #     real return type inside the loop).
            if @_method_return_type
              line "return #{@_method_return_type}();"
            elsif @_current_body_has_explicit_return
              line "__builtin_unreachable();"
            else
              line "return RUBY_NIL;"
            end
          end
        else
          line "return #{s};"
        end
      end

      def emit_main(execute_block)
        line "int main() {"
        @_declared_locals = Set.new; @_optional_locals = {}
        @_current_body = execute_block&.body
        indented do
          # Hoist locals for main too — same rationale as method bodies.
          emit_hoisted_locals(execute_block.body, []) if execute_block&.body
          emit(execute_block.body) if execute_block&.body
          line "return 0;"
        end
        @_current_body = nil
        line "}"
      end

      def emit(node)
        case node
        when Ast::Sequence
          node.nodes.each { |n| emit_stmt(n) }
        else
          emit_stmt(node)
        end
      end

      def emit_stmt(node)
        # MultipleAssignment at statement level: emit each decl/assign on
        # its own line so declarations land in the enclosing scope (not
        # inside a `({...})` statement-expression).
        if node.is_a?(Ast::MultipleAssignment)
          return emit_masgn_stmt(node)
        end
        s = cr(node)
        if s.include?("{\n")
          emit_indent; write s; emit_newline
        else
          line "#{s};"
        end
      end

      # Statement-level emission — declares each target in the enclosing
      # scope. Two RHS shapes supported:
      #   `a, b = call()`    — destructure: val = rhs[0], rhs[1], ...
      #   `a, b = x, y`      — parallel: evaluate all RHS into temps first
      def emit_masgn_stmt(node)
        targets = node.targets || []
        vals = node.value_node
        @_masgn_counter ||= 0
        tag = (@_masgn_counter += 1)
        if vals.is_a?(Ast::ArrayLiteral)
          elems = vals.element_nodes || []
          elems.each_with_index { |e, i| line "auto _t#{tag}_#{i} = #{e ? cr(e) : 'INT64_C(0)'};" }
          targets.each_with_index do |t, i|
            emit_masgn_target(t, "_t#{tag}_#{i}")
          end
        else
          line "auto _masgn#{tag} = #{cr(vals)};"
          targets.each_with_index do |t, i|
            emit_masgn_target(t, "_masgn#{tag}[INT64_C(#{i})]")
          end
        end
      end

      def emit_masgn_target(t, val_expr)
        kind, name = t[0], t[1]
        case kind
        when :local
          nm = cpp_local_name(name)
          if @_declared_locals&.include?(name.to_s)
            line "#{nm} = #{val_expr};"
          else
            @_declared_locals << name.to_s
            line "auto #{nm} = #{val_expr};"
          end
        when :ivar
          line "#{cpp_ivar(name)} = #{val_expr};"
        when :index
          recv = cr(t[1])
          idx = cr(t[2][0])
          line "#{recv}[#{idx}] = #{val_expr};"
        else
          line "/* UNSUPPORTED masgn target: #{kind} */;"
        end
      end

      # Emit a hash literal as `RubyHash<K, V>{...}`.
      # Key type: inferred from the first non-splat key. Typically RubySymbol
      # for `{a: 1}` style or RubyString for `{"a" => 1}`.
      # Value type: inferred from the first value. Heterogeneous values
      # require wrapping (std::variant) — flagged with a TODO comment on
      # the emitted line when we detect type mismatch across elems.
      def cr_hash_literal(node)
        pairs = (node.kv_nodes || []).reject { |k, _| k.nil? }  # skip **splat for now
        if pairs.empty?
          return "RubyHash<RubySymbol, int64_t>{}"  # empty: innocuous default
        end
        k_type = key_type_for(pairs[0][0])
        val_types = pairs.map { |_, v| local_decl_type(v) }.uniq
        v_type = val_types.size == 1 ? val_types[0] : "/* TODO heterogeneous hash */ auto"
        v_type = "int64_t" if v_type == "auto"
        entries = pairs.map { |k, v| "{#{cr(k)}, #{cr(v)}}" }.join(", ")
        # Build via default ctor + .store for each entry — since
        # initializer-list construction of RubyHash isn't supported yet.
        init_pairs = pairs.map { |k, v| "_h.store(#{cr(k)}, #{cr(v)});" }.join(" ")
        "({ RubyHash<#{k_type}, #{v_type}> _h; #{init_pairs} _h; })"
      end

      def key_type_for(node)
        case node
        when Ast::SymbolLiteral then "RubySymbol"
        when Ast::StringLiteral then "RubyString"
        when Ast::IntegerLiteral then "int64_t"
        else "RubySymbol"  # default guess
        end
      end

      def cr(node)
        case node
        when Ast::NilLiteral then "RUBY_NIL"
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral then "false"
        when Ast::IntegerLiteral then "INT64_C(#{node.value.raw})"
        when Ast::FloatLiteral
          val = node.value.respond_to?(:raw) ? node.value.raw : node.value
          s = val.to_s
          s += ".0" unless s.include?('.') || s.include?('e')
          s
        when Ast::StringLiteral
          raw = node.value.respond_to?(:raw) ? node.value.raw : node.value
          "RubyString(#{raw.inspect}, #{raw.bytesize})"
        when Ast::SymbolLiteral
          # :foo → ruby_sym("foo") — interns at runtime; equality is
          # pointer-equality. Usable as a hash key (has std::hash spec).
          "ruby_sym(#{node.value.to_s.inspect})"
        when Ast::HashLiteral
          cr_hash_literal(node)
        when Ast::LocalVariableRead then cpp_local_name(node.name)
        when Ast::InstanceVariableRead
          key = node.name.to_s.delete_prefix('@')
          if @_self_ref_ivars&.include?(key) && @_inside_wrapped_class
            # Self-ref ivar stored as shared_ptr<Impl>; wrap to the outer
            # wrapper type so method calls / arg passing work normally.
            "#{@_current_wrapper_name}(#{cpp_ivar(node.name)})"
          else
            cpp_ivar(node.name)
          end
        when Ast::InstanceVariableWrite
          # Write of self-ref ivars works via implicit conversion
          # (Ruby_X has `operator std::shared_ptr<Impl>()`).
          "#{cpp_ivar(node.name)} = #{cr(node.value_node)}"
        when Ast::MultipleAssignment
          # Two forms:
          #   `a, b = x, y`  (ArrayLiteral RHS)  →  parallel assignment
          #   `a, b = call()` (single-value RHS) →  destructure result[i]
          targets = node.targets
          vals = node.value_node
          if vals.is_a?(Ast::ArrayLiteral)
            elems = vals.element_nodes || []
            @_masgn_counter ||= 0
            tag = (@_masgn_counter += 1)
            tmp_decls = elems.each_with_index.map { |e, i| "auto _t#{tag}_#{i} = #{e ? cr(e) : 'INT64_C(0)'}" }
            assigns = targets.each_with_index.map do |t, i|
              kind, name = t[0], t[1]
              val = "_t#{tag}_#{i}"
              case kind
              when :ivar then "#{cpp_ivar(name)} = #{val}"
              when :index
                recv = cr(t[1])
                idx = cr(t[2][0])
                "#{recv}[#{idx}] = #{val}"
              else
                nm = cpp_local_name(name)
                if @_declared_locals&.include?(name.to_s)
                  "#{nm} = #{val}"
                else
                  @_declared_locals << name.to_s
                  "auto #{nm} = #{val}"
                end
              end
            end
            "({ #{(tmp_decls + assigns).join('; ')}; })"
          else
            # Single RHS — destructure by positional index. When used as
            # a statement, emit_masgn_stmt handles it; here we're in an
            # expression context (rare for destructure) so use a stmt-expr.
            rhs = cr(vals)
            parts = ["auto _masgn = #{rhs}"]
            targets.each_with_index do |t, i|
              kind, name = t
              val = "_masgn[INT64_C(#{i})]"
              case kind
              when :local
                nm = cpp_local_name(name)
                if @_declared_locals&.include?(name.to_s)
                  parts << "#{nm} = #{val}"
                else
                  @_declared_locals << name.to_s
                  parts << "auto #{nm} = #{val}"
                end
              when :ivar
                parts << "#{cpp_ivar(name)} = #{val}"
              when :index
                recv = cr(t[1])
                idx = cr(t[2][0])
                parts << "#{recv}[#{idx}] = #{val}"
              else
                parts << "/* masgn target: #{kind} */"
              end
            end
            "({ #{parts.join('; ')}; })"
          end
        when Ast::LocalVariableWrite
          name = cpp_local_name(node.name)
          val = node.value_node
          if @_declared_locals&.include?(name)
            rhs = cr(val)
            if (inner = (@_optional_locals || {})[name])
              rhs = "ruby_to_opt<#{inner}>(#{rhs})"
            end
            # Wrap in parens for expression contexts like
            # `if ((q1 = p[1]) != 1)` — `!=` binds tighter than `=` in C++.
            "(#{name} = #{rhs})"
          else
            @_declared_locals << name
            type = local_decl_type(val)
            if val.is_a?(Ast::NilLiteral) && @_current_body
              later = look_ahead_local_type(name, @_current_body)
              type = later if later
            end
            if (m = type.to_s.match(/\Astd::optional<(.+)>\z/))
              (@_optional_locals ||= {})[name] = m[1]
            end
            "#{type} #{name} = #{cr(val)}"
          end
        when Ast::If then cr_if(node)
        when Ast::Return
          if node.value_node
            if node.value_node.is_a?(Ast::NilLiteral) && @_method_return_type
              "return #{@_method_return_type}(RUBY_NIL)"
            else
              "return #{cr(node.value_node)}"
            end
          else
            # Bare `return` — Ruby returns nil. Match return type when known.
            @_method_return_type ? "return #{@_method_return_type}()" : "return"
          end
        when Ast::And
          # Ruby `a && b`: short-circuit — evaluate `b` only if `a` is truthy.
          # Result is `b` if `a` truthy, else `a` widened to `b`'s type.
          # Use decltype (compile-time only) to pick the common type without
          # runtime-evaluating the right operand eagerly.
          l = cr(node.left_node)
          r = cr(node.right_node)
          "({ auto _l = (#{l}); (_l) ? decltype((#{r}))(#{r}) : decltype((#{r}))(_l); })"
        when Ast::Or
          # Ruby `a || b`: short-circuit — evaluate `b` only if `a` is falsy.
          # Typical pattern: `x || @default`.
          l = cr(node.left_node)
          r = cr(node.right_node)
          "({ auto _l = (#{l}); (_l) ? decltype((#{r}))(_l) : (#{r}); })"
        when Ast::MethodCall then cr_method_call(node)
        when Ast::ConstantRead then cpp_const_name(node.name)
        when Ast::ConstantPath
          # Encoding::UTF_8 etc. — treat as 0 (encoding ignored for now)
          "INT64_C(0) /* ::#{node.name} */"
        when Ast::IndexOperatorWrite
          # a[i] += expr
          recv = cr(node.receiver_node)
          idx = cr(node.index_arg_nodes[0])
          val = cr(node.value_node)
          "#{recv}[#{idx}] #{node.operator}= #{val}"
        when Ast::AttributeWrite
          if node.name == :[]=
            recv = cr(node.receiver_node)
            args = node.arg_nodes || []
            # Slice assignment: `arr[lo..hi] = other_arr` — replaces a
            # contiguous range of elements with another array's elements.
            idx_node = args[0]
            if idx_node.is_a?(Ast::RangeLiteral)
              lo = cr(idx_node.begin_node)
              hi = cr(idx_node.end_node)
              hi_incl = idx_node.exclusive ? "(#{hi} - 1)" : hi
              "#{recv}.slice_assign(#{lo}, #{hi_incl}, #{cr(args[1])})"
            else
              "#{recv}[#{cr(idx_node)}] = #{cr(args[1])}"
            end
          else
            "#{cr(node.receiver_node)}.#{cpp_method_name(node.name)}(#{(node.arg_nodes || []).map { |a| cr(a) }.join(', ')})"
          end
        when Ast::Sequence then node.nodes.map { |n| cr(n) }.join("; ")
        when Ast::While
          cr_while("while", node)
        when Ast::Until
          cr_while("while", node, negate: true)
        when Ast::ForLoop
          target = node.target
          var = target[0] == :local ? target[1].to_s : "_for_var"
          # Track the var as declared for the duration of the body only.
          @_declared_locals&.add(var)
          coll_node = node.collection_node
          old_indent = "  " * @indent
          if coll_node.is_a?(Ast::RangeLiteral)
            # Numeric range: iterate integer counter directly.
            start_expr = cr(coll_node.begin_node)
            end_expr = cr(coll_node.end_node)
            cmp = coll_node.exclusive ? "<" : "<="
            body_str = cr_block_body(node.body_node)
            "for (int64_t #{var} = #{start_expr}; #{var} #{cmp} #{end_expr}; #{var}++) {\n#{body_str}\n#{old_indent}}"
          else
            # `for x in array` — iterate by index and bind `x` to each element.
            # Ruby for-loop variables leak to outer scope; declare `x` before
            # the loop so post-loop references still see it. Skip decl if
            # already hoisted at method top.
            coll_expr = cr(coll_node)
            body_str = cr_block_body(node.body_node)
            decl = @_declared_locals&.include?(var) ? "" : "std::remove_reference_t<decltype((#{coll_expr})[0])> #{var}; "
            "#{decl}for (int64_t _fi = 0; _fi < (#{coll_expr}).len(); _fi++) {\n#{old_indent}  #{var} = (#{coll_expr})[_fi];\n#{body_str}\n#{old_indent}}"
          end
        when Ast::Next
          "continue"
        when Ast::Break
          "break"
        when Ast::RangeLiteral
          # For ranges used in for loops, emit the end value
          # (the for loop handles the iteration)
          node.exclusive ? cr(node.end_node) : "(#{cr(node.end_node)} + 1LL)"
        when Ast::ArrayLiteral
          # [a, b, c] — emit a fresh RubyArray<T> deduced from first element
          elems = node.element_nodes || []
          if elems.empty?
            "RubyArray_I64(0)"
          elsif tree_node_literal?(node)
            # 2-element literal with nil or recursive-looking calls
            # → emit as RubyTree pair node (shared-ownership binary tree)
            "RubyTree(#{cr(elems[0])}, #{cr(elems[1])})"
          else
            first = cr(elems[0])
            rest_inits = elems[1..].each_with_index.map { |e, i| "_a[#{i+1}] = #{cr(e)};" }.join(' ')
            "({ auto _e0 = #{first}; auto _a = RubyArray<decltype(_e0)>(#{elems.size}); _a[0] = _e0; #{rest_inits} _a; })"
          end
        when Ast::Rescue
          # begin/rescue/end — emit body, ignore rescue for now
          cr(node.body)
        else "/* UNSUPPORTED: #{node.class.name.split('::').last} */"
        end
      end

      def cr_if(node)
        pred = cr_truthy(node.pred_node)
        indent_str = "  " * @indent
        # Ternary form when both branches are simple expressions —
        # lets `a = if cond then X else Y end` emit as an rvalue.
        if node.then_node && node.else_node &&
           simple_expr?(node.then_node) && simple_expr?(node.else_node)
          return "(#{pred} ? (#{cr(node.then_node)}) : (#{cr(node.else_node)}))"
        end
        # `unless` — if cond; nil; else; body; end
        if node.then_node.is_a?(Ast::NilLiteral) && node.else_node
          body_str = cr_block_body(node.else_node)
          return "if (!(#{pred})) {\n#{body_str}\n#{indent_str}}"
        end
        # Statement form: bodies rendered via cr_block_body so
        # MultipleAssignment lowers into multi-line declarations.
        then_str = cr_block_body(node.then_node)
        if node.else_node
          else_str = cr_block_body(node.else_node)
          "if (#{pred}) {\n#{then_str}\n#{indent_str}} else {\n#{else_str}\n#{indent_str}}"
        else
          "if (#{pred}) {\n#{then_str}\n#{indent_str}}"
        end
      end

      # A "simple expression" can appear as an rvalue — no statement-only
      # constructs (nested If, Sequence of multiple stmts, While/For, raise, etc).
      def simple_expr?(node)
        case node
        when Ast::If, Ast::While, Ast::Until, Ast::ForLoop, Ast::Return, Ast::Break, Ast::Next
          false
        when Ast::Sequence
          node.nodes.size == 1 && simple_expr?(node.nodes[0])
        when Ast::MethodCall
          # `raise` emits as a void statement-expression with exit(1).
          return false if node.name == :raise && node.receiver_node.nil?
          true
        else
          true
        end
      end

      def cr_while(keyword, node, negate: false)
        pred = cr_truthy(node.condition_node)
        pred = "!(#{pred})" if negate
        old_indent = "  " * @indent
        body_str = cr_block_body(node.body_node)
        "#{keyword} (#{pred}) {\n#{body_str}\n#{old_indent}}"
      end

      def cr_block_body(node)
        lines = []
        ind = "  " * (@indent + 1)
        each_stmt = ->(n) do
          # MultipleAssignment emits multiple lines so declarations land
          # in the enclosing block scope (not inside a statement-expr).
          if n.is_a?(Ast::MultipleAssignment)
            lines.concat(masgn_stmt_lines(n, ind))
          else
            lines << (ind + cr(n) + ";")
          end
        end
        if node.is_a?(Ast::Sequence)
          node.nodes.each(&each_stmt)
        else
          each_stmt.call(node)
        end
        lines.join("\n")
      end

      # Same as emit_masgn_stmt but returns lines instead of writing to @out.
      # Used from cr_block_body where we're building a string.
      def masgn_stmt_lines(node, ind)
        targets = node.targets || []
        vals = node.value_node
        @_masgn_counter ||= 0
        tag = (@_masgn_counter += 1)
        lines = []
        if vals.is_a?(Ast::ArrayLiteral)
          elems = vals.element_nodes || []
          elems.each_with_index { |e, i| lines << "#{ind}auto _t#{tag}_#{i} = #{e ? cr(e) : 'INT64_C(0)'};" }
          targets.each_with_index do |t, i|
            lines << ind + masgn_target_line(t, "_t#{tag}_#{i}")
          end
        else
          lines << "#{ind}auto _masgn#{tag} = #{cr(vals)};"
          targets.each_with_index do |t, i|
            lines << ind + masgn_target_line(t, "_masgn#{tag}[INT64_C(#{i})]")
          end
        end
        lines
      end

      def masgn_target_line(t, val_expr)
        kind, name = t[0], t[1]
        case kind
        when :local
          nm = cpp_local_name(name)
          if @_declared_locals&.include?(name.to_s)
            "#{nm} = #{val_expr};"
          else
            @_declared_locals << name.to_s
            "auto #{nm} = #{val_expr};"
          end
        when :ivar then "#{cpp_ivar(name)} = #{val_expr};"
        when :index
          "#{cr(t[1])}[#{cr(t[2][0])}] = #{val_expr};"
        else "/* UNSUPPORTED masgn target: #{kind} */;"
        end
      end

      def cr_truthy(node)
        case node
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral, Ast::NilLiteral then "false"
        when Ast::MethodCall
          if %i[< <= > >= == !=].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
            "(#{cr(node.receiver_node)} #{node.name} #{cr(node.arg_nodes[0])})"
          else
            cr(node)
          end
        else cr(node)
        end
      end

      # Convert kw_arg_nodes ([[SymbolLiteral(name), value_node], ...]) into
      # positional values in the order required_kw_params expects.
      def kw_args_in_order(node, kw_param_names)
        kw_map = (node.kw_arg_nodes || []).to_h { |k, v| [k.value.respond_to?(:raw) ? k.value.raw.to_sym : k.value.to_sym, v] }
        kw_param_names.map { |p| kw_map[p.to_sym] }.compact
      end

      # Recursively search the constant graph for a ClassObject with the
      # given bare name (handles classes nested inside other classes).
      def find_nested_class(scope, name, seen = {})
        return nil unless scope
        (scope.constants_table || {}).each do |_k, v|
          next unless v.is_a?(Vm::ClassObject)
          next if seen[v]
          seen[v] = true
          return v if v.name == name
          found = find_nested_class(v, name, seen)
          return found if found
        end
        nil
      end

      def lookup_top_level_method(name)
        return nil unless @top_level_scope
        m = @top_level_scope.methods_table&.fetch(name, nil)
        m if m.is_a?(Vm::Method)
      end

      def cr_method_call(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        kw_arg_nodes = node.kw_arg_nodes || []

        # puts → ruby_puts (template dispatches on arg type at compile time)
        if recv.nil? && name == :puts
          return "printf(\"\\n\")" if args.empty?
          return "ruby_puts(#{cr(args[0])})"
        end

        # Math.sqrt, Math::PI etc.
        if recv.is_a?(Ast::ConstantRead) && recv.name == :Math
          case name
          when :sqrt then return "sqrt(#{cr(args[0])})"
          when :PI then return "M_PI"
          end
        end

        # raise → fprintf + exit
        if recv.nil? && name == :raise
          msg = if args.empty?
            "\"RuntimeError\""
          elsif args[0].is_a?(Ast::StringLiteral)
            "\"#{args[0].value.respond_to?(:raw) ? args[0].value.raw : args[0].value}\""
          else
            "\"error\""
          end
          return "{ fprintf(stderr, \"Error: %s\\n\", #{msg}); exit(1); }"
        end

        # String.new or String.new(encoding: X) — ignore encoding for now
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name == :String
          return "RubyString()"
        end

        # ClassName.new(args) → Ruby_ClassName(args) constructor call
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name != :Array
          arg_strs = args.map { |a| cr(a) }.join(", ")
          return "Ruby_#{recv.name}(#{arg_strs})"
        end

        # Array.new(size, fill)
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name == :Array
          if args.size == 2 && !node.block_node
            return "make_ra(#{cr(args[0])}, #{cr(args[1])})"
          elsif args.size == 1 && node.block_node
            # Array.new(n) { |i| expr } — unfold into loop, deduce elem type from block body
            blk = node.block_node
            var = (blk.required_params || [])[0] || :_ai
            @_declared_locals&.add(var.to_s)
            size_expr = cr(args[0])
            # Generate body once with var=0 to deduce type, then a real loop
            body_expr = cr(blk.body)
            return "({ auto _n = #{size_expr}; #{var.to_s == '_ai' ? 'int64_t _ai = 0;' : "int64_t #{var} = 0;"} auto _e0 = #{body_expr}; auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (#{var} = 1; #{var} < _n; #{var}++) { _arr[#{var}] = #{body_expr}; } _arr; })"
          end
        end

        # .each { |x| body } on an array — range-for over *data.
        if name == :each && recv && node.block_node
          blk = node.block_node
          var = (blk.required_params || [])[0] || :_e
          @_declared_locals&.add(var.to_s)
          coll = cr(recv)
          body_str = nil
          old_indent = "  " * @indent
          indented do
            lines = []
            if blk.body.is_a?(Ast::Sequence)
              blk.body.nodes.each { |n| lines << ("  " * @indent + cr(n) + ";") }
            else
              lines << ("  " * @indent + cr(blk.body) + ";")
            end
            body_str = lines.join("\n")
          end
          return "for (auto& #{var} : *#{coll}.data) {\n#{body_str}\n#{old_indent}}"
        end

        # (lo..hi).to_a / (lo...hi).to_a — emit as ruby_range_to_a helper.
        # Unwrap single-element Sequence (parser wraps `(...)` in Sequence).
        unwrapped_recv = recv
        while unwrapped_recv.is_a?(Ast::Sequence) && unwrapped_recv.nodes.size == 1
          unwrapped_recv = unwrapped_recv.nodes[0]
        end
        if name == :to_a && unwrapped_recv.is_a?(Ast::RangeLiteral) && args.empty?
          lo = cr(unwrapped_recv.begin_node)
          hi = cr(unwrapped_recv.end_node)
          return unwrapped_recv.exclusive ?
            "ruby_range_to_a(#{lo}, #{hi}, true)" :
            "ruby_range_to_a(#{lo}, #{hi}, false)"
        end

        # loop { body } — Ruby's Kernel#loop; infinite loop, exits via break.
        if recv.nil? && name == :loop && node.block_node
          blk = node.block_node
          old_indent = "  " * @indent
          body_str = nil
          indented do
            lines = []
            if blk.body.is_a?(Ast::Sequence)
              blk.body.nodes.each { |n| lines << ("  " * @indent + cr(n) + ";") }
            else
              lines << ("  " * @indent + cr(blk.body) + ";")
            end
            body_str = lines.join("\n")
          end
          return "while (true) {\n#{body_str}\n#{old_indent}}"
        end

        # .times { |i| block }
        if name == :times && recv && node.block_node
          blk = node.block_node
          var = (blk.required_params || [])[0] || :_i
          @_declared_locals&.add(var.to_s)
          body_str = nil
          old_indent = "  " * @indent
          indented do
            lines = []
            if blk.body.is_a?(Ast::Sequence)
              blk.body.nodes.each { |n| lines << ("  " * @indent + cr(n) + ";") }
            else
              lines << ("  " * @indent + cr(blk.body) + ";")
            end
            body_str = lines.join("\n")
          end
          return "for (int64_t #{var} = 0; #{var} < #{cr(recv)}; #{var}++) {\n#{body_str}\n#{old_indent}}"
        end

        # a[i] (subscript read)
        if name == :[] && recv && args.size == 1
          return "#{cr(recv)}[#{cr(args[0])}]"
        end

        # .nil? — RubyTree has nil_q(); for other types, fall through to name mangling (→ nil_q).
        # Plain int64_t or RubyString don't have nil_q so we emit a uniform
        # nil check via a templated helper.
        if recv && name == :nil? && args.empty?
          return "ruby_nil_q(#{cr(recv)})"
        end

        # .class — return class name as const char*
        if recv && name == :class && args.empty?
          return "ruby_class(#{cr(recv)})"
        end

        # .to_s — Ruby String conversion. For user classes, their own
        # to_s would take precedence (emitted as a method) so we only
        # intercept when there's no class context to forward to.
        if recv && name == :to_s && args.empty?
          return "ruby_to_s(#{cr(recv)})"
        end

        # Unary ! and -@ as Ruby method calls with no args
        if recv && name == :! && args.empty?
          return "(!(#{cr_truthy(recv)}))"
        end
        if recv && name == :-@ && args.empty?
          return "(-(#{cr(recv)}))"
        end
        if recv && name == :+@ && args.empty?
          return "(#{cr(recv)})"
        end

        # Integer#succ, Integer#pred — compile-time arithmetic
        if recv && name == :succ && args.empty?
          return "(#{cr(recv)} + INT64_C(1))"
        end
        if recv && name == :pred && args.empty?
          return "(#{cr(recv)} - INT64_C(1))"
        end

        # is_a?/kind_of? with a class literal — compile-time true when type is known.
        # Conservative stub: emit true. Full impl needs receiver type inference.
        if recv && (name == :is_a? || name == :kind_of?) && args.size == 1
          return "true"
        end

        # Power: 2**n → (INT64_C(1) << n) for integer base of 2
        if recv && name == :** && args.size == 1
          if recv.is_a?(Ast::IntegerLiteral) && recv.value.raw == 2
            return "(INT64_C(1) << #{cr(args[0])})"
          end
          return "((int64_t)pow(#{cr(recv)}, #{cr(args[0])}))"
        end

        # Arithmetic operators
        if recv && %i[+ - * / % < <= > >= == != << >> & | ^].include?(name) && args.size == 1
          return "(#{cr(recv)} #{name} #{cr(args[0])})"
        end

        # .length / .size / .bytesize — uniform via `.len()` method
        # (RubyArray<T>, RubyString, RubyTree all expose len())
        if recv && %i[length size bytesize].include?(name) && args.empty?
          return "#{cr(recv)}.len()"
        end

        # .dup — deep copy. RubyArray/RubyString have dup_() methods
        # (avoiding the POSIX `dup` name clash).
        return "#{cr(recv)}.dup_()" if name == :dup && recv

        # Free function call
        if recv.nil?
          # itself at top-level: no-op identity (returns self placeholder)
          return "0LL" if name == :itself && args.empty?
          # Append kw args in declaration order if method is known
          method = lookup_top_level_method(name)
          kw_vals = method && !kw_arg_nodes.empty? ? kw_args_in_order(node, method.required_kw_params || []) : []
          arg_strs = (args + kw_vals).map { |a| cr(a) }.join(", ")
          return "#{cpp_method_name(name)}(#{arg_strs})"
        end

        # respond_to?(:sym) — if we can resolve receiver's class and the
        # symbol is a literal, the answer is statically known.
        if name == :respond_to? && args.size == 1 && args[0].is_a?(Ast::SymbolLiteral) && recv
          sym = args[0].value.respond_to?(:raw) ? args[0].value.raw.to_sym : args[0].value.to_sym
          recv_t = local_decl_type(recv)
          if recv_t&.start_with?("Ruby_")
            cls_name = recv_t.sub("Ruby_", "").to_sym
            cls = @top_level_scope&.constants_table&.fetch(cls_name, nil)
            cls ||= find_nested_class(@top_level_scope, cls_name)
            if cls.is_a?(Vm::ClassObject)
              has = cls.methods_table&.key?(sym) || false
              return has ? "true" : "false"
            end
          end
          # Fallback when we can't resolve — assume present.
          return "true"
        end

        # itself on receiver: identity
        return cr(recv) if name == :itself && args.empty?

        # General: recv.method(args)
        arg_strs = args.map { |a| cr(a) }.join(", ")
        "#{cr(recv)}.#{cpp_method_name(name)}(#{arg_strs})"
      end
    end
  end
end

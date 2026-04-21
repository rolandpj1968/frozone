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
      # Built-in runtime types that aren't safe to allocate under Dustman's
      # moving collector — they hold shared_ptrs or other non-trivially-
      # relocatable state. Emit plain `new` for these; they escape Dustman's
      # tracking entirely (fine for singletons / long-lived objects).
      NON_GC_BUILTIN_CLASSES = Set.new(%i[Random]).freeze

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

        # ── Shared TI (same engine as Crystal backend) ──────────────
        require_relative 'type_inference'
        user_methods = {}
        (top_level_scope.methods_table || {}).each do |name, m|
          user_methods[name] = m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end
        user_classes = {}
        collect_user_classes(top_level_scope).each { |name, cls| user_classes[name] = cls }
        # Also include module methods in user_methods for TI
        collect_module_methods_for_ti(top_level_scope, user_methods)
        ti = TypeInference.new(
          user_methods: user_methods,
          user_classes: user_classes,
          execute_block: execute_block,
          constants: (top_level_scope.constants_table || {}).dup
        )
        @ti_env = ti.run
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

        # Emit user-defined modules as static method containers (after classes)
        emit_user_modules(top_level_scope)
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
      # Query the shared TI for a type, returning a C++ type string.
      # Falls back to nil if the slot isn't typed.
      # TI query — returns the Type at `slot`, or nil if unknown / bottom /
      # too-complex-for-our-codegen. Primary query; cpp-string variants below
      # derive from this.
      def ti_type(slot)
        return nil unless @ti_env
        ty = @ti_env.type_at(slot)
        return nil unless ty && !ty.bottom?
        # Filter the same too-deep-generics case ti_type_cpp used to; keeping
        # the guard here (rather than on to_cpp) means callers that want the
        # raw Type for Type-level reasoning still get it.
        return nil if ty.to_cpp&.count('<') > 2
        return nil if ty.to_cpp == "auto"
        ty
      end

      # Legacy cpp-string accessor. New code should prefer `ti_type` and call
      # `.to_cpp` at the emission boundary.
      def ti_type_cpp(slot)
        ti_type(slot)&.to_cpp
      end

      def ti_ivar_type_t(class_name, ivar_name)
        ti_type([:ivar, class_name, :"@#{ivar_name}"])
      end

      def ti_local_type_t(method_key, local_name)
        ti_type([:local, method_key, local_name.to_sym])
      end

      def ti_return_type_t(method_key)
        ti_type([:return, method_key])
      end

      def ti_ivar_type(class_name, ivar_name)
        ti_ivar_type_t(class_name, ivar_name)&.to_cpp
      end

      def ti_local_type(method_key, local_name)
        ti_local_type_t(method_key, local_name)&.to_cpp
      end

      def ti_return_type(method_key)
        ti_return_type_t(method_key)&.to_cpp
      end

      def collect_module_methods_for_ti(scope, methods, seen = Set.new)
        (scope.constants_table || {}).each_value do |v|
          next if seen.include?(v.object_id)
          seen << v.object_id
          if v.is_a?(Vm::ModuleObject)
            eigen = v.eigenclass rescue nil
            (eigen&.methods_table || {}).each do |name, m|
              methods[name] ||= m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            end
            (v.methods_table || {}).each do |name, m|
              methods[name] ||= m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            end
            collect_module_methods_for_ti(v, methods, seen)
          end
        end
      end

      # Is this C++ type a pointer to a user class (not a builtin value type)?
      def user_class_ptr_type?(t)
        t&.match?(/\ARuby_[A-Z]\w*\*\z/)
      end

      # True if `type_str` is like `Ruby_Foo*` where Foo is in
      # NON_GC_BUILTIN_CLASSES. Those types must be emitted as raw `T*` —
      # they aren't Dustman-managed.
      def non_gc_builtin_ptr?(type_str)
        m = type_str.to_s.match(/\ARuby_([A-Z]\w*)\*\z/)
        !!(m && NON_GC_BUILTIN_CLASSES.include?(m[1].to_sym))
      end

      # Translate a C++ type string for emission. User-class pointer forms
      # (Ruby_X*, RubyObject*) are wrapped in gc_ref<...>. The wrapper is a
      # typedef in frozone.hpp: T* under Boehm/none, dustman::gc_ptr<T> under
      # Dustman. Works inside nested generics (RubyArray<Ruby_X*> → RubyArray<gc_ref<Ruby_X>>).
      # Non-GC built-in classes (NON_GC_BUILTIN_CLASSES) pass through as raw T*.
      def emit_type(t)
        return t unless t
        t.gsub(/Ruby_[A-Z]\w*\*/) do |m|
          non_gc_builtin_ptr?(m) ? m : "gc_ref<#{m[0..-2]}>"
        end.gsub(/\bRubyObject\*/, 'gc_ref<RubyObject>')
      end

      # Like emit_type but for a stack-local variable declaration — wraps
      # user-class pointers in gc_local<T> (= Root<T> under Dustman) so a
      # collection triggered by another allocation doesn't reclaim the referent.
      # Under Boehm/none gc_local<T> = T*, same as gc_ref.
      def emit_local_type(t)
        return t unless t
        t.gsub(/Ruby_[A-Z]\w*\*/) do |m|
          non_gc_builtin_ptr?(m) ? m : "gc_local<#{m[0..-2]}>"
        end.gsub(/\bRubyObject\*/, 'gc_local<RubyObject>')
      end

      def mark_param_pointer_types(method)
        return unless method.is_a?(Vm::Method)
        mkey = @_current_method_key
        (method.required_params || []).each_with_index do |p, i|
          pt = ti_local_type(mkey, p.to_s)
          pt ||= ti_type_cpp([:param, mkey, i])  # TI stores params under :param slots
          @_pointer_locals << p.to_s if user_class_ptr_type?(pt)
        end
      end

      def recv_t_is_ptr?(recv)
        # Check @_pointer_locals (populated from TI during method setup)
        return true if recv.is_a?(Ast::LocalVariableRead) && @_pointer_locals&.include?(recv.name.to_s)
        # Constructor call always returns a pointer
        if recv.is_a?(Ast::MethodCall) && recv.name == :new && recv.receiver_node.is_a?(Ast::ConstantRead)
          return !%i[Array String Hash Set].include?(recv.receiver_node.name)
        end
        # Check TI for the local's type
        if recv.is_a?(Ast::LocalVariableRead)
          t = ti_local_type(@_current_method_key, recv.name.to_s)
          return user_class_ptr_type?(t)
        end
        # Ivar read: TI-typed pointer to user class, or self-ref ivar.
        if recv.is_a?(Ast::InstanceVariableRead) && @_current_wrapper_name
          key = recv.name.to_s.delete_prefix('@')
          return true if @_self_ref_ivars&.include?(key)
          cls_name = @_current_wrapper_name.delete_prefix('Ruby_').to_sym
          return user_class_ptr_type?(ti_ivar_type(cls_name, key))
        end
        # Array index on pointer-element array: arr[i] → Ruby_X*
        if recv.is_a?(Ast::MethodCall) && recv.name == :[] && recv.receiver_node.is_a?(Ast::LocalVariableRead)
          arr_t = ti_local_type(@_current_method_key, recv.receiver_node.name.to_s)
          return true if arr_t&.match?(/RubyArray<Ruby_/)
        end
        # Chained method call on pointer → check if method returns pointer
        if recv.is_a?(Ast::MethodCall) && recv.receiver_node && recv_t_is_ptr?(recv.receiver_node)
          recv_cls = infer_receiver_class(recv.receiver_node)
          if recv_cls
            rt = ti_return_type([recv_cls, recv.name])
            return user_class_ptr_type?(rt)
          end
        end
        false
      end

      def infer_receiver_class(recv)
        if recv.is_a?(Ast::LocalVariableRead) && @_current_method_key
          t = ti_local_type(@_current_method_key, recv.name.to_s)
          return t&.delete_suffix("*")&.delete_prefix("Ruby_")&.to_sym if user_class_ptr_type?(t)
        end
        if recv.is_a?(Ast::InstanceVariableRead) && @_current_wrapper_name
          return @_current_wrapper_name.delete_prefix("Ruby_").to_sym
        end
        nil
      end

      def cpp_ivar(name)
        stripped = name.to_s.delete_prefix('@')
        "iv_#{stripped}"
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
        return @_bracket_method_name || "operator[]" if name == :[]
        if (override = RUBY_TO_CPP_METHOD[name])
          return override.to_s
        end
        s = name.to_s
        return "operator==" if name == :==
        return "operator!=" if name == :!=
        return "operator<=>" if name == :<=>
        return "set_#{s.chomp('=')}" if s.end_with?('=') && !s.end_with?('==')
        return "#{s.chomp('?')}_q" if s.end_with?('?')
        return "#{s.chomp('!')}_b" if s.end_with?('!')
        CPP_KEYWORDS.include?(s) ? "rb_#{s}" : s
      end

      def body_has_yield?(node)
        return false unless node
        return true if node.is_a?(Ast::Yield)
        node.respond_to?(:children) && node.children.any? { |c| c.is_a?(Ast::Node) && body_has_yield?(c) }
      end

      def cr_block_lambda(block_node)
        if block_node.respond_to?(:required_params)
          params = (block_node.required_params || []).map { |p| "auto #{p}" }.join(", ")
          body_s = cr(block_node.body)
          "[&](#{params}) { return #{body_s}; }"
        else
          "/* UNSUPPORTED: BlockArg lambda */"
        end
      end

      def nil_return_expr
        if @_method_return_type&.start_with?("std::optional")
          "std::nullopt"
        elsif @_method_return_type&.end_with?("*")
          # Under Dustman this becomes gc_ref<Ruby_X>(nullptr); under Boehm/none
          # it's the familiar (Ruby_X*)nullptr. Functional-cast syntax works for
          # both because gc_ref<T> is callable on nullptr.
          "#{emit_type(@_method_return_type)}(nullptr)"
        elsif @_method_return_type
          "#{@_method_return_type}(RUBY_NIL)"
        else
          "RUBY_NIL"
        end
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
                         using virtual void volatile int float double auto new delete
                         default case do if else while for break continue return
                         true false bool default do typeid wchar_t alignas
                         alignof asm decltype thread_local
                         pow sqrt cos sin abs].to_set.freeze

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

      def emit_user_modules(scope, seen = {})
        (scope.constants_table || {}).each do |name, value|
          next unless value.is_a?(Vm::ModuleObject) && !value.is_a?(Vm::ClassObject)
          next if seen[value]
          seen[value] = true
          # Recurse into nested modules first
          emit_user_modules(value, seen)
          # Collect singleton (def self.) methods from the eigenclass
          eigen = value.eigenclass rescue nil
          next unless eigen
          user_methods = (eigen.methods_table || {}).select do |_, m|
            m.is_a?(Vm::Method) && user_source_location?(m.source_location)
          end
          # Also collect module_function methods (instance methods exposed as singleton)
          (value.methods_table || {}).each do |mname, m|
            next unless m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            user_methods[mname] ||= m
          end
          next if user_methods.empty?
          # Emit module constants (before the struct, so methods can reference them)
          emit_constants(value, skip_objects: true)
          emit_constants(value, objects_only: true)
          cpp_name = "Ruby_#{name}"
          line "struct #{cpp_name} {"
          indented do
            @_inside_wrapped_class = false
            user_methods.each do |mname, method|
              next if trivial_body?(method.body)
              emit_module_method(mname, method)
              emit_newline
            end
          end
          line "};"
          line "static #{cpp_name} #{name};"
          emit_newline
        end
      end

      def emit_module_method(name, method)
        params = emit_param_list(method)
        @_method_return_type = ti_return_type(@_current_method_key)
        ret_type = %w[std::any].include?(@_method_return_type) || @_method_return_type&.start_with?("std::optional") ? @_method_return_type : "auto"
        line "#{ret_type} #{cpp_method_name(name)}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
        all_param_names(method).each { |p| @_declared_locals << p.to_s }; mark_param_pointer_types(method)
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
        @_method_return_type = nil; @_current_method_key = nil
        line "}"
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
          # Descend into modules to find nested classes
          if value.is_a?(Vm::ModuleObject) && !value.is_a?(Vm::ClassObject) && !seen[value]
            seen[value] = true
            result.concat(collect_user_classes(value, seen))
            next
          end
          next unless value.is_a?(Vm::ClassObject)
          next if value.name.nil? || %i[Object BasicObject Module Class Kernel].include?(value.name)
          next if seen[value]
          seen[value] = true
          methods = value.methods_table || {}
          has_user_method = methods.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }
          next unless has_user_method || user_source_location?(const_locs[name])
          result.concat(collect_user_classes(value, seen))
          result << [name, value]
        end
        result
      end

      # Emit a user class as a heap-allocated object with direct ivars.
      # Objects are raw pointers (Ruby reference semantics). Nil = nullptr.
      # Inherits from RubyObject (or RubyBasicObject for `< BasicObject`).
      def emit_class(name, cls)
        if struct_subclass?(cls)
          emit_struct_class(name, cls)
          return
        end
        init = cls.methods_table&.fetch(:initialize, nil)
        # Ivar types from shared TI, via ti_ivar_type (applies emitter
        # canonicalization: RubyObject* → std::any, filters deep generics).
        # This matches how param/local types are rendered, so ivar-to-param
        # writes agree on their C++ types.
        ivar_types = {}
        @ti_env&.each_typed do |slot, _|
          next unless slot.is_a?(Array) && slot[0] == :ivar && slot[1] == name
          key = slot[2].to_s.delete_prefix('@')
          t = ti_ivar_type(name, key)
          ivar_types[key] = t if t
        end
        all_ivars = Set.new
        (cls.methods_table || {}).each_value do |m|
          next unless m.is_a?(Vm::Method) && m.body
          collect_ivars_from_body(m.body, all_ivars)
        end
        ivars = all_ivars.to_a
        read_ivars = collect_read_ivars(cls)
        @_dropped_ivars = Set.new
        # Drop write-only ivars only when we're sure they can't hold a user
        # object reference. std::any / RubyObject* can hold anything — a live
        # user-class pointer in there is load-bearing for Dustman's reachability
        # even if the Ruby code never reads it back. Keeping the field costs
        # one pointer/std::any slot per instance.
        ivars.reject! do |iv|
          key = iv.to_s.delete_prefix('@')
          t = ivar_types[key]
          next false unless t
          next false if read_ivars.include?(key)
          # Safe-to-drop only if the type is a non-pointer value type.
          if t == "int64_t" || t == "double" || t == "bool" || t == "RubyString"
            @_dropped_ivars << key
            true
          else
            false
          end
        end
        init_has_params = init.is_a?(Vm::Method) && !all_param_names(init).empty?
        self_wrapper = "Ruby_#{name}"
        self_ref_ivars = ivar_types.select { |_, t| t == self_wrapper || t == "#{self_wrapper}*" }.keys.to_set
        @_self_ref_ivars = self_ref_ivars
        @_current_wrapper_name = self_wrapper

        # Determine parent class
        parent = cls.superclass
        parent_cpp = if parent && parent.name && !%i[Object BasicObject].include?(parent.name)
          "Ruby_#{parent.name}"
        else
          "RubyObject"
        end

        line "struct #{self_wrapper} : public #{parent_cpp} {"
        indented do
          # Ivars as direct fields
          ivars.uniq.each do |iv|
            key = iv.to_s.delete_prefix('@')
            t = ivar_types[key] || "int64_t"
            if self_ref_ivars.include?(key)
              line "#{emit_type("#{self_wrapper}*")} iv_#{key} = nullptr;"
            else
              default = case t
                when "int64_t" then " = 0"
                when "double" then " = 0.0"
                when "bool" then " = false"
                else ""
                end
              line "#{emit_type(t)} iv_#{key}#{default};"
            end
          end
          emit_newline

          @_inside_wrapped_class = true

          # Constructors
          if init.is_a?(Vm::Method) && !init_has_params
            line "#{self_wrapper}() {"
            @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
            indented { emit(init.body) }
            line "}"
          else
            line "#{self_wrapper}() = default;"
          end

          if init_has_params
            params = emit_param_list(init)
            line "#{self_wrapper}(#{params}) {"
            @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
            all_param_names(init).each { |p| @_declared_locals << p.to_s }
            indented { emit(init.body) }
            line "}"
          end

          line "const char* rb_class_name() const override { return \"#{name}\"; }"
          emit_newline

          # Instance methods
          cls.methods_table&.each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            next if mname == :initialize
            next unless user_source_location?(method.source_location) || accessor_method?(method)
            next unless method_defined_here?(method, cls)
            if accessor_method?(method) && @_dropped_ivars&.any?
              body = method.body
              ivar_key = if body.is_a?(Ast::InstanceVariableRead)
                body.name.to_s.delete_prefix('@')
              elsif body.is_a?(Ast::InstanceVariableWrite)
                body.name.to_s.delete_prefix('@')
              end
              next if ivar_key && @_dropped_ivars.include?(ivar_key)
            end
            emit_class_method(mname, method)
            emit_newline
          end

          @_inside_wrapped_class = false

          # Class variables
          cvars = collect_class_variables(cls)
          cvars.each { |cv| line "static inline int64_t cv_#{cv} = 0;" }

          # Eigenclass methods (def self.foo)
          eigen = cls.eigenclass rescue nil
          (eigen&.methods_table || {}).each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            next unless user_source_location?(method.source_location)
            emit_static_class_method(mname, method)
            emit_newline
          end
        end
        line "};"
        line "template<> inline const char* ruby_class_name<Ruby_#{name}>() { return \"#{name}\"; }"
        emit_tracer_spec(self_wrapper, ivars, ivar_types, self_ref_ivars)
        @_self_ref_ivars = nil
        @_current_wrapper_name = nil
        @_dropped_ivars = nil
      end

      # Emit a Dustman Tracer specialization for `wrapper` (Ruby_X). Lists only
      # ivars that hold GC references — user-class pointers or RubyObject*.
      # Value-typed ivars (int/double/bool/RubyString/etc.) are not traced.
      def emit_tracer_spec(wrapper, ivars, ivar_types, self_ref_ivars)
        trace = ivars.uniq.select do |iv|
          key = iv.to_s.delete_prefix('@')
          self_ref_ivars.include?(key) || begin
            t = ivar_types[key]
            user_class_ptr_type?(t) || t == "RubyObject*"
          end
        end
        members = trace.map { |iv| "&#{wrapper}::iv_#{iv.to_s.delete_prefix('@')}" }
        line "#ifdef FROZONE_USE_DUSTMAN_GC"
        if members.empty?
          line "template<> struct dustman::Tracer<#{wrapper}> : dustman::FieldList<#{wrapper}> {};"
        else
          line "template<> struct dustman::Tracer<#{wrapper}> : dustman::FieldList<#{wrapper}, #{members.join(', ')}> {};"
        end
        line "#endif"
      end

      def emit_struct_class(name, cls)
        members = struct_members_for(cls)
        ctor_types = []
        line "struct Ruby_#{name} : public RubyObject {"
        @_current_wrapper_name = "Ruby_#{name}"
        @_self_ref_ivars = Set.new
        indented do
          members.each_with_index do |m, i|
            t = ctor_types[i] || "int64_t"
            default = (t == "int64_t") ? " = 0" : (t == "double" ? " = 0.0" : "")
            line "#{emit_type(t)} iv_#{m}#{default};"
          end
          emit_newline

          line "Ruby_#{name}() = default;"

          params = members.each_with_index.map { |m, i|
            t = ctor_types[i] || "auto"
            "#{t} _#{m}"
          }.join(", ")
          line "Ruby_#{name}(#{params}) {"
          indented { members.each { |m| line "iv_#{m} = _#{m};" } }
          line "}"
          line "const char* rb_class_name() const override { return \"#{name}\"; }"
          emit_newline

          members.each do |m|
            t = ctor_types[members.index(m)] || "auto"
            line "#{emit_type(t)} #{m}() const { return iv_#{m}; }"
            line "void set_#{m}(#{emit_type(t)} v) { iv_#{m} = v; }"
          end
          emit_newline

        end
        line "};"
        line "template<> inline const char* ruby_class_name<Ruby_#{name}>() { return \"#{name}\"; }"
        # Struct members are value-typed (int/double) — empty FieldList.
        line "#ifdef FROZONE_USE_DUSTMAN_GC"
        line "template<> struct dustman::Tracer<Ruby_#{name}> : dustman::FieldList<Ruby_#{name}> {};"
        line "#endif"
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
          if node.is_a?(Ast::LocalVariableWrite)
            t = infer_expr_type_ctx(node.value_node, cls_ctx)
            (@_walker_local_types ||= {})[node.name] = t if t != "int64_t"
          end
          if node.is_a?(Ast::MethodCall) && node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
            cls_name = node.receiver_node.name
            (node.arg_nodes || []).each_with_index do |arg, i|
              t = infer_expr_type_ctx(arg, cls_ctx)
              existing = (seen[cls_name] ||= [])
              existing[i] = widen_type(existing[i], t)
            end
          end
          if node.is_a?(Ast::MethodCall) && node.name != :new
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
        walk_method = lambda do |m, cls_ctx|
          return unless m.is_a?(Vm::Method) && m.body
          param_names = m.required_params || []
          param_types = @_method_call_arg_types[m.name] || []
          @_walker_param_names = param_names
          @_walker_param_types = param_types
          @_walker_local_types = {}
          walker.call(m.body, cls_ctx)
          @_walker_param_names = nil
          @_walker_param_types = nil
          @_walker_local_types = nil
        end
        walker.call(execute_block, nil)
        (scope.methods_table || {}).each_value { |m| walk_method.call(m, nil) }
        walked_scopes = Set.new
        walk_scope_methods = lambda do |s|
          return if walked_scopes.include?(s.object_id)
          walked_scopes << s.object_id
          (s.constants_table || {}).each_value do |v|
            if v.is_a?(Vm::ClassObject)
              (v.methods_table || {}).each_value { |m| walk_method.call(m, v) }
              walk_scope_methods.call(v)
            elsif v.is_a?(Vm::ModuleObject)
              eigen = v.eigenclass rescue nil
              (eigen&.methods_table || {}).each_value { |m| walk_method.call(m, nil) }
              (v.methods_table || {}).each_value { |m| walk_method.call(m, nil) }
              walk_scope_methods.call(v)
            end
          end
        end
        walk_scope_methods.call(scope)
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
        if node.is_a?(Ast::LocalVariableRead)
          if @_walker_param_names
            idx = @_walker_param_names.index(node.name)
            return @_walker_param_types[idx] if idx && @_walker_param_types&.[](idx)
          end
          if @_walker_local_types
            t = @_walker_local_types[node.name]
            return t if t
          end
        end
        if node.is_a?(Ast::MethodCall) && %i[+ - * / %].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
          l = infer_expr_type_ctx(node.receiver_node, cls_ctx)
          r = infer_expr_type_ctx(node.arg_nodes[0], cls_ctx)
          return "double" if l == "double" || r == "double"
        end
        if node.is_a?(Ast::MethodCall) && node.receiver_node
          recv_t = infer_expr_type_ctx(node.receiver_node, cls_ctx)
          if recv_t&.start_with?("Ruby_")
            cls_name = recv_t.delete_prefix("Ruby_").delete_suffix("*").to_sym
            rt = ti_return_type([cls_name, node.name])
            return rt if rt
          end
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
        # Array type widening: int → double element type
        e = existing == "Ruby_Array" ? "RubyArray<int64_t>" : existing
        n = new_t == "Ruby_Array" ? "RubyArray<int64_t>" : new_t
        if e.start_with?("RubyArray<") && n.start_with?("RubyArray<")
          return n if n.include?("double")
          return e if e.include?("double")
          return e
        end
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
        candidates.each_with_object({}) do |(iv, types), out|
          types.delete("int64_t") if types.size > 1
          # Normalize Ruby_Array → RubyArray<int64_t>
          if types.delete?("Ruby_Array")
            types << "RubyArray<int64_t>"
          end
          # Array element type widening: int → double
          arr_types = types.select { |t| t.start_with?("RubyArray<") }
          if arr_types.size > 1
            best_arr = arr_types.any? { |t| t.include?("double") } ? "RubyArray<double>" : arr_types.first
            arr_types.each { |t| types.delete(t) }
            types << best_arr
          end
          if types.size == 1
            out[iv] = types.first
          elsif types.size > 1
            out[iv] = "std::any"
          end
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
        elsif node.is_a?(Ast::AttributeWrite) && node.name == :[]= && node.receiver_node.is_a?(Ast::InstanceVariableRead)
          val_node = (node.arg_nodes || []).last
          val_t = val_node ? infer_expr_type_with_params(val_node, param_names, param_types) : "int64_t"
          if val_t == "double"
            yield node.receiver_node.name.to_s.delete_prefix('@'), "RubyArray<double>"
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
        node = node.nodes.last if node.is_a?(Ast::Sequence) && node.nodes.size == 1
        case node
        when Ast::FloatLiteral then "double"
        when Ast::StringLiteral, Ast::InterpolatedString then "RubyString"
        when Ast::SymbolLiteral then "RubySymbol"
        when Ast::MethodCall
          if node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
            cn = node.receiver_node.name
            return "RubyString" if cn == :String
            return "Ruby_#{cn}*"
          end
          # Arithmetic: if either operand is a double, propagate.
          # String * n → RubyString; String + String → RubyString.
          if %i[+ - * / %].include?(node.name) && node.receiver_node && node.arg_nodes&.size == 1
            l = infer_expr_type(node.receiver_node)
            r = infer_expr_type(node.arg_nodes[0])
            return "RubyString" if l == "RubyString"
            return "double" if l == "double" || r == "double"
          end
          # Methods that preserve receiver type
          if node.name == :abs && node.receiver_node
            return infer_expr_type(node.receiver_node)
          end
          # String methods that return RubyString
          return "RubyString" if %i[b dup_ upcase downcase slice].include?(node.name) && node.receiver_node
          # Top-level function call: use cached return type if available.
          if node.receiver_node.nil?
            rt = ti_return_type(node.name)
            return rt if rt && rt != "RubyNil"
          end
          # Built-in methods with known return types.
          return "double" if node.name == :rand
          return "RubyString" if node.name == :to_s
          "int64_t"
        when Ast::InstanceVariableRead
          if @_current_wrapper_name
            cls_name = @_current_wrapper_name.sub(/^Ruby_/, '').to_sym
            t = ti_ivar_type(cls_name, node.name.to_s.delete_prefix("@"))
            return t if t
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

      def collect_class_variables(cls)
        cvars = Set.new
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::ClassVariableRead) || node.is_a?(Ast::ClassVariableWrite)
            cvars << node.name.to_s.delete_prefix('@@')
          end
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        (cls.methods_table || {}).each_value do |m|
          next unless m.is_a?(Vm::Method) && m.body
          walker.call(m.body)
        end
        eigen = cls.eigenclass rescue nil
        (eigen&.methods_table || {}).each_value do |m|
          next unless m.is_a?(Vm::Method) && m.body
          walker.call(m.body)
        end
        cvars
      end

      def emit_static_class_method(name, method)
        params = emit_param_list(method)
        line "static auto #{cpp_method_name(name)}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
        @_method_return_type = ti_return_type(@_current_method_key)
        all_param_names(method).each { |p| @_declared_locals << p.to_s }; mark_param_pointer_types(method)
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
        @_method_return_type = nil; @_current_method_key = nil
        line "}"
      end

      def collect_read_ivars(cls)
        reads = Set.new
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::InstanceVariableRead)
            reads << node.name.to_s.delete_prefix('@')
          end
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        (cls.methods_table || {}).each do |mname, m|
          next if mname == :initialize
          next unless m.is_a?(Vm::Method) && m.body
          # Count accessor bodies too — we don't know whether external code
          # invokes the reader, so conservatively assume it does.
          walker.call(m.body)
        end
        reads
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
          rt = ti_return_type(val.name)
          return rt if rt
          m = lookup_top_level_method(val.name)
          if m && m.body
            last = m.body.is_a?(Ast::Sequence) ? m.body.nodes.last : m.body
            return deep_decl_type(last) if last
          end
        end
        # Instance method call: check class method return types
        if val.is_a?(Ast::MethodCall) && val.receiver_node
          recv_t = local_decl_type(val.receiver_node)
          if recv_t&.start_with?("Ruby_")
            cls_name = recv_t.delete_prefix("Ruby_").delete_suffix("*").to_sym
            rt = ti_return_type([cls_name, val.name])
            return rt if rt
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

      # Type-returning counterpart to `local_decl_type`. Returns a Frozone
      # Type for nodes we can structurally infer, or nil when the shape is
      # beyond what we can cleanly lift to a Type (constant folding of
      # cpp-string outputs, unmapped AST shapes, etc.) — callers then fall
      # back to string handling.
      #
      # Coverage goal: the AST shapes that actually participate in
      # union-decision sites (hash literal values, ternary branches, ||/&&
      # operands, case/when branches). Non-covered shapes return nil and
      # defer to the string predicates.
      def local_decl_type_t(val)
        @_decl_depth_t ||= 0
        return nil if @_decl_depth_t > 5
        @_decl_depth_t += 1
        begin
          _local_decl_type_t_impl(val)
        ensure
          @_decl_depth_t -= 1
        end
      end

      def _local_decl_type_t_impl(val)
        case val
        when Ast::NilLiteral     then Frozone::Compiler::Type::NIL_CLASS
        when Ast::TrueLiteral    then Frozone::Compiler::Type::TRUE_CLASS
        when Ast::FalseLiteral   then Frozone::Compiler::Type::FALSE_CLASS
        when Ast::IntegerLiteral then Frozone::Compiler::Type::I64
        when Ast::FloatLiteral   then Frozone::Compiler::Type::F64
        when Ast::SymbolLiteral  then Frozone::Compiler::Type::SYMBOL
        when Ast::StringLiteral, Ast::InterpolatedString then Frozone::Compiler::Type::STRING
        when Ast::InstanceVariableRead
          return nil unless @_current_wrapper_name
          cls_name = @_current_wrapper_name.sub(/^Ruby_/, '').to_sym
          ti_ivar_type_t(cls_name, val.name.to_s.delete_prefix("@"))
        when Ast::InstanceVariableWrite, Ast::LocalVariableWrite
          local_decl_type_t(val.value_node)
        when Ast::Or, Ast::And
          a = local_decl_type_t(val.left_node)
          b = local_decl_type_t(val.right_node)
          return a if a == b
          return b if a.nil?
          return a if b.nil?
          # Different concrete types — defer to string meet_types via the
          # caller's fallback for now. A future commit can extend this.
          nil
        when Ast::MethodCall
          if val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
            cn = val.receiver_node.name
            return Frozone::Compiler::Type::STRING if cn == :String
            return nil if cn == :Array   # element type unknown here
            return Frozone::Compiler::Type.of(cn)
          end
          # obj.foo where obj resolves to a known user class — look up the
          # method's TI-typed return.
          if val.receiver_node
            recv_t = local_decl_type_t(val.receiver_node)
            if recv_t && recv_t.class_type? && recv_t.class_name && !recv_t.class_name.to_s.start_with?("Ruby")
              rt = ti_return_type_t([recv_t.class_name, val.name])
              return rt if rt
            end
          end
          nil
        when Ast::HashLiteral
          pairs = (val.kv_nodes || []).reject { |k, _| k.nil? }
          if pairs.empty?
            return Frozone::Compiler::Type.new(:class_type, class_name: :Hash,
                                               key: Frozone::Compiler::Type::SYMBOL,
                                               val: Frozone::Compiler::Type::I64)
          end
          return nil unless pairs[0][0].is_a?(Ast::SymbolLiteral)  # non-symbol keys: punt
          k_t = Frozone::Compiler::Type::SYMBOL
          val_ts = pairs.map { |_, v| local_decl_type_t(v) }
          return nil if val_ts.any?(&:nil?)
          uniq_vs = val_ts.uniq
          v_t = if uniq_vs.size == 1
                  uniq_vs[0]
                elsif uniq_vs.all?(&:ruby_object_convertible?)
                  Frozone::Compiler::Type::OBJECT
                end
          return nil unless v_t
          Frozone::Compiler::Type.new(:class_type, class_name: :Hash, key: k_t, val: v_t)
        when Ast::ArrayLiteral
          return nil if tree_node_literal?(val)
          elems = val.element_nodes
          return Frozone::Compiler::Type::ARRAY_I64 if elems.empty?
          et = local_decl_type_t(elems.first)
          return Frozone::Compiler::Type.new(:class_type, class_name: :Array,
                                             elem: Frozone::Compiler::Type::I64) if et.nil?
          Frozone::Compiler::Type.new(:class_type, class_name: :Array, elem: et)
        when Ast::If
          return nil unless val.then_node && val.else_node
          t_then = local_decl_type_t(unwrap_single_sequence(val.then_node))
          t_else = local_decl_type_t(unwrap_single_sequence(val.else_node))
          return t_then if t_then == t_else && t_then
          return nil unless t_then && t_else
          # Different concrete types — compute union representation via
          # Type. Return Type::OBJECT (renders as RubyObject*) when that's
          # the representation; nil otherwise so the caller can decide.
          rep = Frozone::Compiler::Type.union_representation([t_then, t_else])
          rep == "RubyObject*" ? Frozone::Compiler::Type::OBJECT : nil
        when Ast::Case
          return nil unless val.whens&.any?
          types = val.whens.map { |w|
            local_decl_type_t(unwrap_single_sequence(w.body_node))
          }
          return nil if types.any?(&:nil?)
          uniq = types.uniq
          return uniq[0] if uniq.size == 1
          rep = Frozone::Compiler::Type.union_representation(uniq)
          rep == "RubyObject*" ? Frozone::Compiler::Type::OBJECT : nil
        when Ast::ConstantRead
          if @top_level_scope
            c = @top_level_scope.constants_table&.fetch(val.name, nil)
            return Frozone::Compiler::Type::STRING if c.is_a?(Vm::StringObject)
            return Frozone::Compiler::Type::F64 if c.is_a?(Vm::FloatObject)
          end
          nil
        else
          nil
        end
      end

      def _local_decl_type_impl(val)
        case val
        when Ast::Or, Ast::And
          # `a || b` evaluates to `a` if truthy else `b` — the result type
          # is the lattice join of left and right. Try Type-level first;
          # fall back to string meet_types for shapes not modelled by
          # local_decl_type_t.
          ta = local_decl_type_t(val.left_node)
          tb = local_decl_type_t(val.right_node)
          if ta && tb
            return ta.to_cpp if ta == tb
            return Frozone::Compiler::Type.union_representation([ta, tb])
          end
          meet_types(local_decl_type(val.left_node), local_decl_type(val.right_node))
        when Ast::LocalVariableRead
          "auto"
        when Ast::InstanceVariableRead
          # Look up the ivar's inferred type in the enclosing class.
          if @_current_wrapper_name
            cls_name = @_current_wrapper_name.sub(/^Ruby_/, '').to_sym
            t = ti_ivar_type(cls_name, val.name.to_s.delete_prefix("@"))
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
            return cn == :Array ? "auto" : "Ruby_#{cn}*"
          end
          # Indexed read like `arr[i]` — use `auto` (value). Since user
          # class wrappers are shared_ptr-based, a value copy aliases the
          # underlying Impl, so mutations via setters still propagate.
          # RubyString[i] returns a 1-char rvalue — `auto` is the only
          # safe option (can't bind a reference to a temporary).
          return "auto" if val.name == :[] && val.receiver_node && (val.arg_nodes || []).size == 1
          return "RubyString" if val.name == :[] && val.receiver_node && (val.arg_nodes || []).size == 2
          return "RubyString" if %i[b slice dup_ upcase downcase].include?(val.name) && val.receiver_node
          # If the receiver's type resolves to a known user class, look up
          # the called method's return type (helps `tmp = node.left` etc).
          if val.receiver_node
            recv_t = local_decl_type(val.receiver_node)
            if recv_t&.start_with?("Ruby_")
              cls_name = recv_t.sub("Ruby_", "").to_sym
              rt = ti_return_type([cls_name, val.name])
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
            v_type = hash_literal_value_type(pairs)
            "RubyHash<#{k_type}, #{v_type}>"
          end
        when Ast::SymbolLiteral then "RubySymbol"
        when Ast::FloatLiteral then "double"
        when Ast::StringLiteral, Ast::InterpolatedString then "RubyString"
        when Ast::TrueLiteral, Ast::FalseLiteral then "bool"
        when Ast::Case
          types = val.whens.map { |w| local_decl_type(unwrap_single_sequence(w.body_node)) }.uniq
          types.delete("int64_t") if types.size > 1
          types.delete("auto") if types.size > 1
          types.size == 1 ? types.first : "auto"
        when Ast::If
          if val.then_node && val.else_node
            t1 = local_decl_type(unwrap_single_sequence(val.then_node))
            t2 = local_decl_type(unwrap_single_sequence(val.else_node))
            return t1 if t1 == t2
            # Absorb int64_t/auto into the concrete type
            %w[int64_t auto].each do |weak|
              t1 = t2 if t1 == weak
              t2 = t1 if t2 == weak
            end
            return t1 if t1 == t2
            "std::any"
          else
            "auto"
          end
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
              # Prefer shared TI (no body re-walking), fall back to
              # look-ahead scan (skipped for large methods).
              widened = ti_local_type(@_current_method_key, name)
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
        has_nil_return = false
        has_value_return = false
        walker = lambda do |node|
          return unless node
          if node.is_a?(Ast::Return)
            if node.value_node.nil? || node.value_node.is_a?(Ast::NilLiteral)
              has_nil_return = true
            else
              has_value_return = true
              t = local_decl_type(node.value_node)
              best = widen_type(best, t) if t && t != "int64_t" && t != "auto"
            end
          end
          node.children.each { |c| walker.call(c) if c.is_a?(Ast::Node) }
        end
        walker.call(body)
        last = body.is_a?(Ast::Sequence) ? body.nodes.last : body
        if last.is_a?(Ast::NilLiteral)
          has_nil_return = true
        elsif last && !last.is_a?(Ast::Return)
          t = local_decl_type(last)
          best = widen_type(best, t) if t && t != "int64_t" && t != "auto"
        end
        if best.nil? && !@_current_body_has_explicit_return && last &&
           (last.is_a?(Ast::While) || last.is_a?(Ast::Until) || last.is_a?(Ast::ForLoop))
          best = "RubyNil"
        end
        # Primitive + nil → std::optional<T>
        if best.nil? && has_nil_return && has_value_return
          best = "std::optional<int64_t>"
        end
        @_current_body = prev_body
        best
      end

      def scan_body_for_return_type(body)
        found = nil
        infer = lambda do |n|
          return nil unless n.is_a?(Ast::Node)
          # Peel simple wrappers that evaluate to their RHS.
          return infer.call(n.value_node) if n.is_a?(Ast::InstanceVariableWrite) || n.is_a?(Ast::LocalVariableWrite)
          # LocalVariableRead: look up via TI (local_decl_type returns "auto").
          if n.is_a?(Ast::LocalVariableRead)
            return ti_local_type(@_current_method_key, n.name.to_s)
          end
          # InstanceVariableRead: TI ivar type.
          if n.is_a?(Ast::InstanceVariableRead) && @_current_wrapper_name
            cls_name = @_current_wrapper_name.delete_prefix('Ruby_').to_sym
            return ti_ivar_type(cls_name, n.name.to_s.delete_prefix('@'))
          end
          local_decl_type(n)
        end
        take = lambda do |n|
          t = infer.call(n)
          found = t if !found && t && (user_class_ptr_type?(t) || t.end_with?('*'))
        end
        walk = lambda do |node|
          return unless node.is_a?(Ast::Node)
          if node.is_a?(Ast::Return) && node.value_node && !node.value_node.is_a?(Ast::NilLiteral)
            take.call(node.value_node)
          end
          node.children.each { |c| walk.call(c) if c }
        end
        walk.call(body)
        # Also look at the implicit final expression of the body.
        last = body.is_a?(Ast::Sequence) ? body.nodes.last : body
        take.call(last) if last && !last.is_a?(Ast::NilLiteral)
        found
      end

      def emit_class_method(mname, method)
        @_current_method_key = @_current_wrapper_name ? [@_current_wrapper_name.sub("Ruby_", "").to_sym, mname] : mname
        params = emit_param_list(method)
        nparams = all_param_names(method).size
        @_bracket_method_name = (mname == :[] && nparams > 1) ? "slice" : nil
        @_method_return_type = ti_return_type(@_current_method_key)
        # TI punts (returns nil) on methods with mixed bare/value returns.
        # Fallback: scan the body for a value Return / final expression whose
        # type is a user-class pointer; use that as the method's return type so
        # bare `return` emits `return nullptr;` instead of colliding.
        @_method_return_type ||= scan_body_for_return_type(method.body)
        # For user-class pointer return types, make the signature explicit
        # (gc_ref<Ruby_X>) so a `return root_local` unifies via implicit
        # conversion Root<T> → gc_ptr<T>. `auto` deduction would see two
        # distinct types and fail.
        ret_sig = explicit_return_type(@_method_return_type)
        line "#{ret_sig} #{cpp_method_name(mname)}(#{params}) {"
        @_bracket_method_name = nil
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
        all_param_names(method).each { |p| @_declared_locals << p.to_s }; mark_param_pointer_types(method)
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
        @_method_return_type = nil; @_current_method_key = nil
        line "}"
      end

      # Hoist locals with a determinable type to the method top. Locals
      # first-defined in an inner scope stay visible for subsequent outer
      # uses (matches Ruby's method-wide local scope vs C++ block scope).
      # Locals whose type we can't resolve are left to per-site decl.
      def ast_node_count(node)
        return 0 unless node.is_a?(Ast::Node)
        1 + node.children.sum { |c| ast_node_count(c) }
      end

      def emit_hoisted_locals(body, param_names)
        @_current_body = body
        param_names_set = param_names.map(&:to_s).to_set
        collect_hoistable_locals(body, param_names).each do |name, info|
          t = info[:type]
          next if t.nil?
          next if @_declared_locals&.include?(name)
          decl_name = cpp_local_name(name)
          if t == "auto" || t == "auto&"
            ti_t = ti_local_type(@_current_method_key, name)
            if ti_t && ti_t != "auto"
              t = ti_t
            else
              rhs = info[:first_rhs]
              next unless rhs && rhs_safe_for_decltype?(rhs, param_names_set)
              rhs_str = cr(rhs)
              line "std::decay_t<decltype(#{rhs_str})> #{decl_name}{};"
              @_declared_locals << name
              @_declared_locals << decl_name if decl_name != name
              next
            end
          end
          if t.start_with?("Ruby_") && !t.end_with?("*")
            line "#{emit_local_type("#{t}*")} #{decl_name} = nullptr;"
            @_pointer_locals << name
          elsif t.end_with?("*")
            line "#{emit_local_type(t)} #{decl_name} = nullptr;"
            @_pointer_locals << name
          else
              init = case t
                     when "int64_t" then " = 0"
                     when "double" then " = 0.0"
                     when "bool" then " = false"
                     else ""
                     end
              line "#{emit_type(t)} #{decl_name}#{init};"
            end
            if (m = t.match(/\Astd::optional<(.+)>\z/))
              (@_optional_locals ||= {})[name] = m[1]
            end
          @_declared_locals << name
          @_declared_locals << decl_name if decl_name != name
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
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
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
        ((method.required_params || []) + (method.optional_params || []).map { |name, _| name } +
         (method.required_kw_params || []) + (method.optional_kw_params || []).map { |name, _| name })
      end

      # Renders `auto <name>` for required params and
      # `auto <name> = <default>` for optional params (C++20 abbreviated
      # function templates support default args).
      def emit_param_list(method)
        parts = []
        # attr_writer setters have a synthetic single param assigned to an ivar.
        # Use the ivar's TI type so a Root<T> caller converts to gc_ref<T>.
        setter_ivar_t = nil
        if method.body.is_a?(Ast::InstanceVariableWrite) && @_current_wrapper_name
          cls_name = @_current_wrapper_name.delete_prefix('Ruby_').to_sym
          ivk = method.body.name.to_s.delete_prefix('@')
          setter_ivar_t = ti_ivar_type(cls_name, ivk)
        end
        (method.required_params || []).each_with_index do |p, i|
          # If TI typed this param as a user-class pointer, emit gc_ref<T>
          # explicitly. Under Dustman, callers often pass a Root<T> (non-copyable
          # stack root) — auto-deduction would fail, but Root→gc_ptr converts.
          mkey = @_current_method_key
          t = mkey ? (ti_local_type(mkey, p.to_s) || ti_type_cpp([:param, mkey, i])) : nil
          t ||= setter_ivar_t if i == 0
          if user_class_ptr_type?(t)
            parts << "#{emit_type(t)} #{p}"
          else
            parts << "auto #{p}"
          end
        end
        req_count = (method.required_params || []).size
        (method.optional_params || []).each_with_index do |(pname, default_node), oi|
          if default_node.is_a?(Ast::NilLiteral)
            arg_types = (@_method_call_arg_types || {})[method.name] || []
            t = arg_types[req_count + oi]
            # Fallback to TI's :param slot if the caller-scan didn't populate it.
            t ||= ti_type_cpp([:param, @_current_method_key, req_count + oi]) if @_current_method_key
            # Also try :local (sometimes TI stores param types there).
            t ||= ti_local_type(@_current_method_key, pname.to_s) if @_current_method_key
            if t && t.start_with?("Ruby_")
              ptr_t = t.end_with?("*") ? t : "#{t}*"
              parts << "#{emit_type(ptr_t)} #{pname} = nullptr"
            else
              parts << "auto #{pname} = #{cr(default_node)}"
            end
          else
            t = local_decl_type(default_node)
            t = "int64_t" if t == "auto"
            parts << "#{t} #{pname} = #{cr(default_node)}"
          end
        end
        (method.required_kw_params || []).each { |p| parts << "auto #{p}" }
        (method.optional_kw_params || []).each do |pname, default_node|
          t = local_decl_type(default_node)
          t = "int64_t" if t == "auto"
          parts << "#{t} #{pname} = #{cr(default_node)}"
        end
        parts.join(", ")
      end

      def emit_method(name, method)
        @_current_method_key = name
        params = emit_param_list(method)
        @_method_yields = method.uses_block || body_has_yield?(method.body)
        params = params.empty? ? "auto _block" : "#{params}, auto _block" if @_method_yields
        @_method_return_type = ti_return_type(@_current_method_key)
        ret_type = explicit_return_type(@_method_return_type)
        line "static #{ret_type} #{cpp_method_name(name)}(#{params}) {"
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
        all_param_names(method).each { |p| @_declared_locals << p.to_s }; mark_param_pointer_types(method)
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
        @_method_return_type = nil; @_current_method_key = nil
        @_method_yields = false
        line "}"
      end

      def emit_stmt_return(node)
        if node.is_a?(Ast::If)
          emit_if_return(node)
          return
        end
        if node.is_a?(Ast::Case)
          emit_case_return(node)
          return
        end
        # Coerce the returned expression into the method's declared return
        # type. Only non-control expressions — control-flow forms (if/while/for)
        # aren't return-producing here; they go through other paths.
        s = if node.is_a?(Ast::Node) && !node.is_a?(Ast::If) && !node.is_a?(Ast::While) && !node.is_a?(Ast::ForLoop)
              cr_coerce(node, @_method_return_type)
            else
              cr(node)
            end
        if s.include?("{\n") || s.start_with?("if ") || s.start_with?("while ") || s.start_with?("for ") || s.start_with?("return ")
          if s.include?("{\n")
            emit_indent; write s; emit_newline
          else
            line "#{s};"
          end
          if s.start_with?("while ") || s.start_with?("for ")
            if @_method_return_type
              line "return #{@_method_return_type}();"
            elsif @_current_body_has_explicit_return
              line "__builtin_unreachable();"
            else
              line "return RUBY_NIL;"
            end
          elsif s.start_with?("if ") && @_method_return_type
            line "return #{nil_return_expr};"
          end
        else
          if s == "RUBY_NIL" && @_method_return_type
            line "return #{nil_return_expr};"
          else
            line "return #{s};"
          end
        end
      end

      def emit_if_return(node)
        pred = cr_truthy(node.pred_node)
        line "if (#{pred}) {"
        indented { emit_return_branch(node.then_node || Ast::NilLiteral::NIL) }
        if node.else_node
          line "} else {"
          indented { emit_return_branch(node.else_node) }
        end
        line "}"
        if @_method_return_type && !node.else_node
          line "return #{nil_return_expr};"
        end
      end

      def emit_return_branch(node)
        inner = unwrap_single_sequence(node)
        if inner.is_a?(Ast::If)
          emit_if_return(inner)
        elsif inner.is_a?(Ast::NilLiteral) && @_method_return_type
          line "return #{nil_return_expr};"
        else
          line "return #{cr_coerce(inner, @_method_return_type)};"
        end
      end

      def emit_case_return(node)
        subj = node.subject_node ? cr(node.subject_node) : nil
        node.whens.each_with_index do |w, wi|
          conds = w.condition_nodes.map { |c| subj ? "(#{subj} == #{cr(c)})" : cr_truthy(c) }.join(" || ")
          keyword = wi == 0 ? "if" : "} else if"
          line "#{keyword} (#{conds}) {"
          indented { emit_return_branch(w.body_node) }
        end
        if node.else_node
          line "} else {"
          indented { emit_return_branch(node.else_node) }
        end
        line "}"
        line "return RUBY_NIL;" unless node.else_node
      end

      def emit_main(execute_block)
        line "int main() {"
        @_declared_locals = Set.new; @_optional_locals = {}; @_pointer_locals = Set.new
        @_current_body = execute_block&.body
        indented do
          line "FROZONE_GC_INIT();"
          # Hoist locals for main too — same rationale as method bodies.
          emit_hoisted_locals(execute_block.body, []) if execute_block&.body
          emit(execute_block.body) if execute_block&.body
          line "FROZONE_GC_SHUTDOWN();"
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
        v_type = hash_literal_value_type(pairs)
        init_pairs = pairs.map { |k, v|
          rhs = case v_type
                when "std::any"   then "std::any(#{cr(v)})"
                when "RubyObject*" then cr_coerce(v, "RubyObject*")
                else cr(v)
                end
          "_h.store(#{cr(k)}, #{rhs});"
        }.join(" ")
        "({ RubyHash<#{k_type}, #{emit_type(v_type)}> _h; #{init_pairs} _h; })"
      end

      # Decide the V type for a RubyHash<K, V> built from `pairs`.
      # Tries Type-level inference first — consistent with the Type lattice's
      # structural view of gc_ref containment and convertibility. Falls back
      # to string-level union_representation when Type inference returns nil
      # for a pair (e.g. chained MethodCalls we don't structurally model yet).
      def hash_literal_value_type(pairs)
        val_ts = pairs.map { |_, v| local_decl_type_t(v) }
        if val_ts.none?(&:nil?)
          uniq_ts = val_ts.uniq
          return uniq_ts[0].to_cpp if uniq_ts.size == 1
          return Frozone::Compiler::Type.union_representation(uniq_ts)
        end
        # Fallback: some participant didn't lift to a Type (unmapped AST
        # shape). Go through the legacy string path.
        val_types = pairs.map { |_, v| local_decl_type(v) }.uniq
        return val_types[0] if val_types.size == 1 && val_types[0] != "auto"
        union_representation(val_types)
      end

      # Can values of `cpp_type` be represented as RubyObject* via
      # coerce_to_ref? True for pointers, value-typed subclasses, primitives
      # (boxed into Ruby_Integer / Ruby_Float / Ruby_Boolean), RubySymbol
      # (boxed into Ruby_Symbol), and "auto" (trust runtime dispatch —
      # coerce_to_ref's if-constexpr chain handles all supported types at
      # the template instantiation site, and static_asserts on anything
      # unsupported, surfacing a compile error rather than silently
      # hiding a gc_ref inside std::any).
      #
      # The only "can't convert" cases left are `std::any` (already
      # type-erased — unbox would need runtime type knowledge we don't
      # have) and nil (handled separately via coerce_to_ref's null path).
      def ruby_object_convertible_type?(cpp_type)
        return true if cpp_type.nil? || cpp_type == "auto"
        return false if cpp_type == "std::any"
        cpp_type.end_with?("*") ||
          ruby_object_subclass_value_type?(cpp_type) ||
          cpp_type == "RubySymbol" ||
          %w[int64_t double bool].include?(cpp_type)
      end

      # Would storing a value of `cpp_type` inside std::any hide gc_refs from
      # Dustman's precise tracing? True for anything that (directly or
      # transitively via container element types) contains a gc_ref.
      # Used at union sites: if any participant contains gc_refs, we MUST
      # lift the union to gc_ref<RubyObject> (so the collector can see
      # through it). Otherwise std::any is safe and SBO-efficient.
      def contains_gc_refs?(cpp_type)
        return false unless cpp_type
        return true if cpp_type.end_with?("*") && (cpp_type.start_with?("Ruby_") || cpp_type == "RubyObject*")
        if (m = cpp_type.match(/\ARubyArray<(.+)>\z/))
          return contains_gc_refs?(m[1])
        end
        if (m = cpp_type.match(/\ARubyHash<([^,]+),\s*(.+)>\z/))
          return contains_gc_refs?(m[1]) || contains_gc_refs?(m[2])
        end
        false
      end

      # Meet two cpp types at the lattice level. Used for expressions whose
      # value type is the join of two sub-expressions (ternary, ||, &&, case).
      # - Same type on both sides → that type
      # - One side is bottom-ish ("auto" / nil) → the other
      # - Otherwise → union_representation([a, b]) (RubyObject*, or std::any)
      def meet_types(a, b)
        return a if a == b
        return b if a.nil? || a == "auto"
        return a if b.nil? || b == "auto"
        union_representation([a, b])
      end

      # Pick the representation for a union of participant cpp types.
      # Goal: match TI's join (LCA) decision at the emitter level and stay
      # Dustman-safe.
      #   - any participant has gc_refs, OR
      #     all participants are RubyObject-convertible (includes primitives
      #     via boxing) → "RubyObject*"
      #   - else (RubySymbol / unknown mixed in) → "std::any" last resort.
      #     Flag this as a TODO — if std::any ends up holding a gc_ref via an
      #     untracked participant, tracing breaks. Currently only hit by
      #     RubySymbol-inclusive unions, which don't contain gc_refs, so
      #     it's safe today.
      def union_representation(types)
        return "RubyObject*" if types.any? { |t| contains_gc_refs?(t) }
        return "RubyObject*" if types.all? { |t| ruby_object_convertible_type?(t) }
        "std::any"
      end

      def key_type_for(node)
        case node
        when Ast::SymbolLiteral then "RubySymbol"
        when Ast::StringLiteral then "RubyString"
        when Ast::IntegerLiteral then "int64_t"
        else "RubySymbol"  # default guess
        end
      end

      # Emit `node` as an expression producing `target_type`, inserting any
      # coercion needed so the value fits the target slot.
      #
      # target_type is an internal cpp type string (pre-emit_type); typical
      # callers are emission sites that assign into a union slot (ivar, return,
      # param, hash/array element whose V/T has been widened to RubyObject*).
      #
      # Coercion rules:
      #   - target matches node's static type      → identity
      #   - target is RubyObject*, node is pointer → identity (C++ upcasts)
      #   - target is RubyObject*, node is a value type RubyObject-subclass
      #     (RubyString, RubyArray<T>, RubyHash<K,V>, RubyTree)
      #                                            → box: gc_new<Type>(expr)
      #   - target is RubyObject*, node is primitive (int64, double, bool)
      #                                            → fallback: std::any(expr)
      #     (proper fix is boxed primitive wrappers in a future step)
      #   - everything else                        → identity (trust callers)
      # Coerce `node` at emission time so its value fits the `target` slot.
      # Accepts either a Frozone::Compiler::Type (preferred) or a cpp-string
      # target (legacy, still used by a few call sites we'll migrate).
      #
      # Only the "RubyObject*" target is non-trivial: we emit
      # coerce_to_ref<RubyObject>(...) which compile-time-dispatches at the
      # template instantiation site on the actual input type:
      #   nil / nullptr          → gc_ref<Base>(nullptr)
      #   gc_ptr<T> / T*         → as_ref<Base>(x)
      #   value-typed subclass   → as_ref<Base>(gc_new<T>(x))
      #   int64_t / double / bool→ as_ref<Base>(gc_new<Ruby_{Integer,Float,
      #                              Boolean}>(x))
      #   RubySymbol             → as_ref<Base>(gc_new<Ruby_Symbol>(x))
      # For any other target type cr_coerce is identity.
      def cr_coerce(node, target)
        s = cr(node)
        target_cpp = if target.is_a?(Frozone::Compiler::Type)
                       target.to_cpp
                     else
                       target
                     end
        return s unless target_cpp == "RubyObject*"
        "coerce_to_ref<RubyObject>(#{s})"
      end

      # Is `cpp_type` a C++ type that's a value-semantic RubyObject subclass?
      # These can be boxed via gc_new<Type>(value) to produce a RubyObject*.
      def ruby_object_subclass_value_type?(cpp_type)
        return false unless cpp_type
        cpp_type == "RubyString" ||
          cpp_type == "RubyTree" ||
          cpp_type.start_with?("RubyArray<") ||
          cpp_type.start_with?("RubyHash<")
      end

      # Decide the method's emitted return type. `auto` for the common case;
      # explicit when TI gives us a type that the `auto` deducer can't unify
      # across branches (user-class pointers, RubyObject*, std::any,
      # std::optional) — callers returning mixed-but-convertible-to-target
      # types will then implicitly coerce at return sites.
      def explicit_return_type(t)
        return "auto" unless t
        return t if t == "std::any" || t.start_with?("std::optional")
        return emit_type(t) if user_class_ptr_type?(t) || t == "RubyObject*"
        "auto"
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
        when Ast::ClassVariableRead
          "cv_#{node.name.to_s.delete_prefix('@@')}"
        when Ast::ClassVariableWrite
          "(cv_#{node.name.to_s.delete_prefix('@@')} = #{cr(node.value_node)})"
        when Ast::InstanceVariableRead
          cpp_ivar(node.name)
        when Ast::InstanceVariableWrite
          ivar_t = nil
          ivar_type = nil
          if @_inside_wrapped_class && @_current_wrapper_name
            cls_name = @_current_wrapper_name.sub(/^Ruby_/, '').to_sym
            ivar_type = ti_ivar_type_t(cls_name, node.name.to_s.delete_prefix("@"))
            ivar_t = ivar_type&.to_cpp
            if @_dropped_ivars&.include?(node.name.to_s.delete_prefix('@'))
              return "#{cr(node.value_node)}"
            end
            if ivar_t&.match?(/RubyArray<double>/)
              @_array_new_elem_type = "double"
            end
          end
          # Coerce RHS to the ivar's declared type. Pass the Type directly;
          # cr_coerce routes to coerce_to_ref when target is RubyObject*.
          rhs = cr_coerce(node.value_node, ivar_type || ivar_t)
          # Bare nullptr when assigning nil into a user-class pointer ivar
          # (avoids RubyNil/gc_ptr assignment ambiguity under Dustman).
          if rhs == "RUBY_NIL" && (user_class_ptr_type?(ivar_t) || @_self_ref_ivars&.include?(node.name.to_s.delete_prefix('@')))
            rhs = "nullptr"
          end
          result = "#{cpp_ivar(node.name)} = #{rhs}"
          @_array_new_elem_type = nil
          result
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
            # `= RUBY_NIL` is ambiguous when LHS is gc_ref<T> under Dustman
            # (templated RubyNil → T clashes with RubyNil → nullptr_t). Emit
            # bare nullptr for pointer-typed locals; works for all GC modes.
            if rhs == "RUBY_NIL" && @_pointer_locals&.include?(name)
              rhs = "nullptr"
            end
            # LHS is a gc_local<T> = Root<T> under Dustman, RHS may also be a
            # Root<T> (another pointer local). Root has no copy-assign; coerce
            # RHS through its gc_ptr<T> conversion by wrapping in gc_ref<T>().
            # Under Boehm/none this is a no-op cast.
            if @_pointer_locals&.include?(name) && val.is_a?(Ast::LocalVariableRead) && @_pointer_locals.include?(val.name.to_s)
              t = ti_local_type(@_current_method_key, name) || ti_local_type(@_current_method_key, val.name.to_s)
              if user_class_ptr_type?(t)
                rhs = "#{emit_type(t)}(#{rhs})"
              end
            end
            # Wrap in parens for expression contexts like
            # `if ((q1 = p[1]) != 1)` — `!=` binds tighter than `=` in C++.
            "(#{name} = #{rhs})"
          else
            @_declared_locals << name
            # Shared TI for local type, fall back to expression-level inference
            type = ti_local_type(@_current_method_key, name)
            type ||= local_decl_type(val)
            if (m = type.to_s.match(/\Astd::optional<(.+)>\z/))
              (@_optional_locals ||= {})[name] = m[1]
            end
            if type.start_with?("Ruby_") && !type.end_with?("*")
              type = "#{type}*"
            end
            if type.end_with?("*")
              (@_pointer_locals ||= Set.new) << name
            end
            "#{type} #{name} = #{cr(val)}"
          end
        when Ast::If then cr_if(node)
        when Ast::Return
          if node.value_node
            if node.value_node.is_a?(Ast::NilLiteral) && @_method_return_type
              "return #{nil_return_expr}"
            else
              "return #{cr(node.value_node)}"
            end
          else
            @_method_return_type ? "return #{nil_return_expr}" : "return"
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
          if node.parent_node.is_a?(Ast::ConstantRead) && node.parent_node.name == :Math && node.name == :PI
            "M_PI"
          else
            "INT64_C(0) /* ::#{node.name} */"
          end
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
            recv_s = cr(node.receiver_node)
            op = recv_t_is_ptr?(node.receiver_node) ? "->" : "."
            "#{recv_s}#{op}#{cpp_method_name(node.name)}(#{(node.arg_nodes || []).map { |a| cr(a) }.join(', ')})"
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
        when Ast::InterpolatedString
          parts = node.parts.map do |part|
            if part.is_a?(Ast::StringLiteral)
              cr(part)
            else
              "ruby_to_s(#{cr(part)})"
            end
          end
          parts.size == 1 ? parts[0] : "(#{parts.join(' + ')})"
        when Ast::Case
          cr_case(node)
        when Ast::Yield
          yield_args = (node.respond_to?(:arg_nodes) ? node.arg_nodes : []) || []
          if yield_args.empty?
            "_block()"
          else
            "_block(#{yield_args.map { |a| cr(a) }.join(', ')})"
          end
        when Ast::SelfLiteral
          @_inside_wrapped_class ? "(*this)" : "0LL"
        when Ast::Rescue
          cr_rescue(node)
        else "/* UNSUPPORTED: #{node.class.name.split('::').last} */"
        end
      end

      def cr_rescue(node)
        indent_str = "  " * @indent
        clauses = node.rescue_clauses || []
        body = cr_block_body(node.body)
        if clauses.empty? && !node.ensure_node
          return body
        end
        parts = []
        if clauses.any?
          parts << "try {\n#{body}\n#{indent_str}}"
          clauses.each do |clause|
            exc_types = (clause.exception_nodes || []).map do |en|
              en.is_a?(Ast::ConstantRead) ? "Ruby_#{en.name}" : "RubyException"
            end
            exc_types = ["Ruby_StandardError"] if exc_types.empty?
            exc_types.each do |et|
              var = clause.var_name ? " #{clause.var_name}" : ""
              rescue_body = cr_block_body(clause.body)
              parts << " catch (#{et}&#{var}) {\n#{rescue_body}\n#{indent_str}}"
            end
          end
        else
          parts << "{\n#{body}\n#{indent_str}}"
        end
        if node.ensure_node
          ensure_body = cr_block_body(node.ensure_node)
          parts << "\n#{indent_str}#{ensure_body};"
        end
        parts.join
      end

      def cr_case(node)
        subj_expr = node.subject_node ? cr(node.subject_node) : nil
        # Emit as chained ternary: (s==1 ? body1 : s==2 ? body2 : else_body)
        parts = []
        subj_var = subj_expr ? "_cs" : nil
        node.whens.each do |w|
          cond = w.condition_nodes.map { |c|
            subj_var ? "(#{subj_var} == #{cr(c)})" : cr_truthy(c)
          }.join(" || ")
          parts << [cond, cr(w.body_node)]
        end
        else_body = node.else_node ? cr(node.else_node) : "RUBY_NIL"
        chain = parts.reverse.inject(else_body) { |rest, (cond, body)| "(#{cond}) ? (#{body}) : (#{rest})" }
        subj_var ? "({ auto #{subj_var} = #{subj_expr}; #{chain}; })" : chain
      end

      def cr_if(node)
        pred = cr_truthy(node.pred_node)
        indent_str = "  " * @indent
        # Ternary form when both branches are simple expressions —
        # lets `a = if cond then X else Y end` emit as an rvalue.
        if node.then_node && node.else_node &&
           simple_expr?(node.then_node) && simple_expr?(node.else_node)
          then_s = cr(node.then_node)
          else_s = cr(node.else_node)
          then_inner = unwrap_single_sequence(node.then_node)
          else_inner = unwrap_single_sequence(node.else_node)
          if else_inner.is_a?(Ast::NilLiteral)
            t = infer_expr_type(then_inner)
            if t&.start_with?("Ruby_")
              else_s = "(#{t})nullptr"
            end
          elsif then_inner.is_a?(Ast::NilLiteral)
            t = infer_expr_type(else_inner)
            if t&.start_with?("Ruby_")
              then_s = "(#{t})nullptr"
            end
          else
            # Prefer Type-level inference; fall back to string-path when
            # either branch's shape isn't structurally modelled by
            # local_decl_type_t (returns nil in that case).
            t1_t = local_decl_type_t(then_inner)
            t2_t = local_decl_type_t(else_inner)
            rep = if t1_t && t2_t && t1_t != t2_t
                    Frozone::Compiler::Type.union_representation([t1_t, t2_t])
                  elsif t1_t.nil? || t2_t.nil?
                    # Fallback: mirror legacy string path.
                    t1 = local_decl_type(then_inner)
                    t2 = local_decl_type(else_inner)
                    if t1 != t2 && t1 != "auto" && t2 != "auto"
                      union_representation([t1, t2])
                    end
                  end
            if rep == "RubyObject*"
              then_s = cr_coerce(then_inner, "RubyObject*")
              else_s = cr_coerce(else_inner, "RubyObject*")
            elsif rep == "std::any"
              then_s = "std::any(#{then_s})"
              else_s = "std::any(#{else_s})"
            end
          end
          return "(#{pred} ? (#{then_s}) : (#{else_s}))"
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
      def unwrap_single_sequence(node)
        node.is_a?(Ast::Sequence) && node.nodes.size == 1 ? node.nodes[0] : node
      end

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

        # lambda { |x| body } → C++ lambda
        if recv.nil? && name == :lambda && node.block_node
          return cr_block_lambda(node.block_node)
        end
        # proc.call(args) → proc(args)
        if name == :call && recv
          arg_strs = args.map { |a| cr(a) }.join(", ")
          return "#{cr(recv)}(#{arg_strs})"
        end

        # $stdout.puts → ruby_puts
        if recv.is_a?(Ast::GlobalVariableRead) && recv.name == :$stdout && name == :puts
          return "printf(\"\\n\")" if args.empty?
          return "ruby_puts(#{cr(args[0])})"
        end

        # puts → ruby_puts (template dispatches on arg type at compile time)
        if recv.nil? && name == :puts
          return "printf(\"\\n\")" if args.empty?
          return "ruby_puts(#{cr(args[0])})"
        end

        # Class.method() → static method call
        if recv.is_a?(Ast::ConstantRead) && name != :new && name != :Math
          cls_obj = @top_level_scope&.constants_table&.fetch(recv.name, nil)
          if cls_obj.is_a?(Vm::ClassObject)
            eigen = cls_obj.eigenclass rescue nil
            if eigen&.methods_table&.key?(name)
              arg_strs = args.map { |a| cr(a) }.join(", ")
              return "Ruby_#{recv.name}::#{cpp_method_name(name)}(#{arg_strs})"
            end
          end
        end

        # Math.sqrt, Math::PI etc.
        if recv.is_a?(Ast::ConstantRead) && recv.name == :Math
          case name
          when :sqrt then return "sqrt(#{cr(args[0])})"
          when :cos then return "cos(#{cr(args[0])})"
          when :sin then return "sin(#{cr(args[0])})"
          when :PI then return "M_PI"
          end
        end

        # raise → fprintf + exit
        if recv.nil? && name == :raise
          if args.empty?
            return "throw Ruby_RuntimeError()"
          elsif args[0].is_a?(Ast::ConstantRead) && args.size >= 1
            exc_cls = "Ruby_#{args[0].name}"
            msg = args.size >= 2 ? cr(args[1]) : "\"#{args[0].name}\""
            return "throw #{exc_cls}(#{msg})"
          elsif args[0].is_a?(Ast::StringLiteral)
            raw = args[0].value.respond_to?(:raw) ? args[0].value.raw : args[0].value.to_s
            return "throw Ruby_RuntimeError(\"#{raw.gsub('"', '\\"')}\")"
          else
            return "throw Ruby_RuntimeError()"
          end
        end

        # String.new or String.new(encoding: X) — ignore encoding for now
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name == :String
          return "RubyString()"
        end

        # ClassName.new(args) → gc_new<Ruby_ClassName>(args).
        # Except for built-in runtime types that can't live on a moving GC
        # (shared_ptr internals break under evacuation). Those use plain `new`
        # and leak out of Dustman's control — fine because they're rare and
        # typically long-lived (Random, etc.).
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name != :Array
          arg_strs = args.map { |a| cr(a) }.join(", ")
          alloc_op = NON_GC_BUILTIN_CLASSES.include?(recv.name) ? "new" : "gc_new<Ruby_#{recv.name}>"
          if alloc_op == "new"
            return "new Ruby_#{recv.name}(#{arg_strs})"
          else
            return "#{alloc_op}(#{arg_strs})"
          end
        end

        # Array.new(size, fill) / Array.new(size)
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name == :Array
          if args.size == 1 && !node.block_node
            return "RubyArray<double>(#{cr(args[0])})" if @_array_new_elem_type == "double"
            return "RubyArray<int64_t>(#{cr(args[0])})"
          elsif args.size == 2 && !node.block_node
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
        if name == :each && recv && node.block_node && node.block_node.respond_to?(:required_params)
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
          return "{ auto _coll = #{coll}; for (auto& #{var} : *_coll.data) {\n#{body_str}\n#{old_indent}} }"
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
        if name == :[] && recv && args.size == 2
          return "#{cr(recv)}.slice(#{cr(args[0])}, #{cr(args[1])})"
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

        # [a, b].max / [a, b].min
        if recv.is_a?(Ast::ArrayLiteral) && (name == :max || name == :min) && args.empty?
          elems = recv.element_nodes || []
          if elems.size == 2
            a, b = cr(elems[0]), cr(elems[1])
            return "(((#{a}) > (#{b})) ? (#{a}) : (#{b}))" if name == :max
            return "(((#{a}) < (#{b})) ? (#{a}) : (#{b}))"
          end
        end

        # No-op methods
        if name == :freeze && args.empty?
          return recv ? cr(recv) : "0LL"
        end
        if name == :frozen? && args.empty?
          return "false"
        end

        # Type conversion methods
        if recv && name == :to_f && args.empty?
          return "(double)(#{cr(recv)})"
        end
        if recv && name == :to_i && args.empty?
          return "(int64_t)(#{cr(recv)})"
        end
        if recv && name == :floor && args.empty?
          return "(int64_t)floor((double)(#{cr(recv)}))"
        end
        if recv && name == :abs && args.empty?
          return "std::abs(#{cr(recv)})"
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
          if recv.is_a?(Ast::IntegerLiteral)
            if recv.value.raw == 2
              return "(INT64_C(1) << #{cr(args[0])})"
            end
            return "((int64_t)pow((double)(#{cr(recv)}), (double)(#{cr(args[0])})))"
          end
          return "pow((double)(#{cr(recv)}), (double)(#{cr(args[0])}))"
        end

        # Arithmetic operators — safe division for integers
        if recv && %i[+ - * / % < <= > >= == != << >> & | ^].include?(name) && args.size == 1
          if name == :/ then return "ruby_div(#{cr(recv)}, #{cr(args[0])})" end
          if name == :% then return "ruby_mod(#{cr(recv)}, #{cr(args[0])})" end
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
          all_kw_names = (method&.required_kw_params || []) + (method&.optional_kw_params || []).map { |n, _| n }
          kw_vals = method && !kw_arg_nodes.empty? ? kw_args_in_order(node, all_kw_names) : []
          all_args = (args + kw_vals).map { |a| cr(a) }
          if node.block_node && (method.nil? || method.uses_block || body_has_yield?(method&.body))
            all_args << cr_block_lambda(node.block_node)
          end
          return "#{cpp_method_name(name)}(#{all_args.join(', ')})"
        end

        # respond_to?(:sym) — if we can resolve receiver's class and the
        # symbol is a literal, the answer is statically known.
        if name == :respond_to? && args.size == 1 && args[0].is_a?(Ast::SymbolLiteral) && recv
          sym = args[0].value.respond_to?(:raw) ? args[0].value.raw.to_sym : args[0].value.to_sym
          recv_t = local_decl_type(recv)
          if recv_t&.start_with?("Ruby_")
            cls_name = recv_t.delete_prefix("Ruby_").delete_suffix("*").to_sym
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

        # General: recv.method(args) or recv->method(args) for pointer types
        arg_strs = args.map { |a| cr(a) }.join(", ")
        recv_s = cr(recv)
        is_ptr = recv_t_is_ptr?(recv)
        op = is_ptr ? "->" : "."
        "#{recv_s}#{op}#{cpp_method_name(name)}(#{arg_strs})"
      end
    end
  end
end

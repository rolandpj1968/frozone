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

      # Strip @ from Ruby ivar names and prefix with iv_ to avoid clashes with method names
      def cpp_ivar(name) = "iv_#{name.to_s.delete_prefix('@')}"

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

      def emit_header
        line "#include <cstdio>"
        line "#include <cstdint>"
        line "#include <cstdlib>"
        line "#include <cstring>"
        line "#include <cmath>"
        emit_newline
        line "// --- Frozone C++ runtime (minimal) ---"
        emit_newline
        line "class RubyObject {"
        line "public:"
        indented do
          line "virtual ~RubyObject() = default;"
          line "virtual int64_t to_i64() { return 0; }"
          line "virtual double to_f64() { return 0.0; }"
          line "virtual const char* to_s() { return \"#<Object>\"; }"
          line "virtual bool truthy() { return true; }"
        end
        line "};"
        emit_newline
        line "class RubyNil : public RubyObject {"
        line "public:"
        indented do
          line "bool truthy() override { return false; }"
          line "const char* to_s() override { return \"\"; }"
        end
        line "};"
        emit_newline
        line "class RubyInteger : public RubyObject {"
        line "public:"
        indented do
          line "int64_t value;"
          line "RubyInteger(int64_t v) : value(v) {}"
          line "int64_t to_i64() override { return value; }"
          line "const char* to_s() override {"
          indented do
            line "static thread_local char buf[32];"
            line "snprintf(buf, sizeof(buf), \"%lld\", (long long)value);"
            line "return buf;"
          end
          line "}"
        end
        line "};"
        emit_newline
        line "class RubyFloat : public RubyObject {"
        line "public:"
        indented do
          line "double value;"
          line "RubyFloat(double v) : value(v) {}"
          line "double to_f64() override { return value; }"
          line "int64_t to_i64() override { return (int64_t)value; }"
        end
        line "};"
        emit_newline
        line "// Mutable byte-oriented string. Encoding is tracked nominally"
        line "// but all methods operate on bytes (matches Ruby binary semantics)."
        line "#include <vector>"
        line "#include <cstring>"
        line "class RubyString {"
        line "public:"
        indented do
          line "std::vector<uint8_t> bytes;"
          line "int64_t len = 0;"
          line "RubyString() = default;"
          line "RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); len = n; } }"
          line "RubyString(const char* s, size_t n) { bytes.assign(s, s + n); len = n; }"
          line "int64_t bytesize() const { return len; }"
          line "int64_t size() const { return len; }"
          line "int64_t length() const { return len; }"
          line "int64_t get_byte(int64_t i) const { return (i >= 0 && i < len) ? (int64_t)bytes[i] : 0; }"
          line "void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < len) bytes[i] = (uint8_t)(v & 0xff); }"
          line "RubyString dup_() const { return *this; }"
          line "RubyString& operator<<(const RubyString& o) {"
          indented { line "bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); len = (int64_t)bytes.size(); return *this;" }
          line "}"
          line "RubyString& operator<<(const char* s) {"
          indented { line "if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); len = (int64_t)bytes.size(); } return *this;" }
          line "}"
          line "bool operator==(const RubyString& o) const { return bytes == o.bytes; }"
          line "bool operator!=(const RubyString& o) const { return bytes != o.bytes; }"
        end
        line "};"
        line "using Ruby_String = RubyString;"
        emit_newline
        line "// Generic native array — TI-specialised per element type"
        line "// Uses shared_ptr so nested arrays / temporaries copy cheaply"
        line "#include <memory>"
        line "template<typename T> class RubyArray {"
        line "public:"
        indented do
          line "std::shared_ptr<T[]> data;"
          line "int64_t len;"
          line "RubyArray() : data(nullptr), len(0) {}"
          line "RubyArray(int64_t size) : data(new T[size > 0 ? size : 1]()), len(size) {}"
          line "RubyArray(int64_t size, T fill) : data(new T[size > 0 ? size : 1]), len(size) {"
          indented { line "for (int64_t i = 0; i < size; i++) data[i] = fill;" }
          line "}"
          line "T& operator[](int64_t i) { return data[i]; }"
          line "const T& operator[](int64_t i) const { return data[i]; }"
        end
        line "};"
        emit_newline
        line "using RubyArray_I64 = RubyArray<int64_t>;"
        line "using RubyArray_F64 = RubyArray<double>;"
        line "// Helper: deduce array element type from fill value"
        line "template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }"
        emit_newline
        # RUBY_NIL as int64_t sentinel (0) — loses identity but works in
        # int64_t-typed slots (RubyArray_I64 elements, locals, return values).
        line "static constexpr int64_t RUBY_NIL = 0;"
        emit_newline
        line "// Ruby-flavored puts: chooses format based on type"
        line "#include <type_traits>"
        line "#include <charconv>"
        line "template<typename T> static inline void ruby_puts(T v) {"
        indented do
          line "if constexpr (std::is_same_v<T, bool>) {"
          indented { line 'printf(v ? "true\\n" : "false\\n");' }
          line "} else if constexpr (std::is_floating_point_v<T>) {"
          indented do
            line "// Shortest round-trippable representation (matches Ruby's Float#to_s closely)"
            line "char buf[64]; auto r = std::to_chars(buf, buf + sizeof(buf) - 4, (double)v);"
            line "*r.ptr = 0;"
            line "// Ensure trailing .0 for integer-valued doubles (Ruby convention)"
            line "bool has_dot = false; for (char* p = buf; p < r.ptr; ++p) if (*p == '.' || *p == 'e' || *p == 'n' || *p == 'i') { has_dot = true; break; }"
            line "if (!has_dot) { *r.ptr++ = '.'; *r.ptr++ = '0'; *r.ptr = 0; }"
            line 'printf("%s\\n", buf);'
          end
          line "} else if constexpr (std::is_integral_v<T>) {"
          indented { line 'printf("%lld\\n", (long long)v);' }
          line "} else {"
          indented { line 'printf("#<Object>\\n");' }
          line "}"
        end
        line "}"
        line "static inline void ruby_puts(const char* s) { printf(\"%s\\n\", s); }"
      end

      CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

      def user_source_location?(loc)
        return false if loc.nil?
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @stub_file && file == @stub_file
        CORE_PATH_MARKERS.none? { |m| file.include?(m) }
      end

      def emit_constants(scope, skip_objects: false, objects_only: false)
        const_table = scope.constants_table || {}
        const_locs = scope.constants_locations || {}
        const_table.each do |name, value|
          next if value.is_a?(Vm::ModuleObject)
          loc = const_locs[name]
          next unless user_source_location?(loc)
          is_obj = value.is_a?(Vm::ObjectObject)
          next if skip_objects && is_obj
          next if objects_only && !is_obj
          case value
          when Vm::IntegerObject then line "static const int64_t #{name} = #{value.raw}LL;"
          when Vm::FloatObject then line "static const double #{name} = #{value.raw};"
          when Vm::StringObject
            # Emit as RubyString so .dup/.bytesize/.length etc. work.
            # Use the (ptr, len) constructor so embedded NULs are preserved.
            raw = value.raw
            line "static const RubyString #{name} = RubyString(#{raw.inspect}, #{raw.bytesize});"
          when Vm::TrueObject then line "static const bool #{name} = true;"
          when Vm::FalseObject then line "static const bool #{name} = false;"
          when Vm::ObjectObject
            klass = value.class_object
            next unless klass.is_a?(Vm::ClassObject) && klass.name
            # Skip built-in container types without C++ runtime equivalents yet.
            next if %i[Hash Array Range Regexp Proc].include?(klass.name)
            line "static Ruby_#{klass.name} #{name};"
          end
        end
      end

      def emit_user_classes(scope)
        const_locs = scope.constants_locations || {}
        scope.constants_table&.each do |name, value|
          next unless value.is_a?(Vm::ClassObject)
          next if value.name.nil? || %i[Object BasicObject Module Class Kernel].include?(value.name)
          methods = value.methods_table || {}
          has_user_method = methods.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }
          # Also emit if class itself was defined in user source (subclass with no own methods)
          next unless has_user_method || user_source_location?(const_locs[name])
          emit_class(name, value)
          emit_newline
        end
      end

      def emit_class(name, cls)
        line "struct Ruby_#{name} {"
        # Collect ivars from initialize
        init = cls.methods_table&.fetch(:initialize, nil)
        ivars = []
        if init.is_a?(Vm::Method) && init.body
          collect_ivars_from_body(init.body, ivars)
        end
        indented do
          # Emit ivar fields (all int64_t for now — TI would tell us)
          ivars.uniq.each { |iv| line "int64_t #{cpp_ivar(iv)} = 0;" }
          emit_newline if ivars.any?
          # Emit methods (including trivial-body ones — e.g. empty methods called from execute block)
          cls.methods_table&.each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            next if mname == :initialize # handle separately
            next unless user_source_location?(method.source_location) || accessor_method?(method)
            emit_class_method(mname, method)
            emit_newline
          end
          # Emit initialize as constructor
          if init.is_a?(Vm::Method) && init.body
            emit_constructor(name, init)
          end
        end
        line "};"
      end

      def collect_ivars_from_body(node, result)
        return unless node
        if node.is_a?(Ast::InstanceVariableWrite)
          result << node.name.to_s
        elsif node.is_a?(Ast::InstanceVariableRead)
          result << node.name.to_s
        end
        node.children.each { |c| collect_ivars_from_body(c, result) if c.is_a?(Ast::Node) }
      end

      def accessor_method?(method)
        method.body.is_a?(Ast::InstanceVariableRead) || method.body.is_a?(Ast::InstanceVariableWrite)
      end

      # Decide a local variable's declared C++ type from its initializer.
      # `int64_t` for plain integer-typed exprs; `auto` for class instances,
      # arrays, method calls (which may return auto-deduced types), and
      # anything ambiguous.
      def local_decl_type(val)
        case val
        when Ast::MethodCall
          if val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
            cn = val.receiver_node.name
            return "RubyString" if cn == :String
            return cn == :Array ? "auto" : "Ruby_#{cn}"
          end
          # Free function or method call → return type unknown, use auto
          "auto"
        when Ast::ArrayLiteral then "auto"
        when Ast::FloatLiteral then "double"
        when Ast::StringLiteral then "RubyString"
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

      def emit_class_method(mname, method)
        # Use 'auto' for params so C++20 can deduce per call site
        # (covers both int64_t and class-typed args without explicit TI)
        params = all_param_names(method).map { |p| "auto #{p}" }.join(", ")
        # Always 'auto' return — C++20 deduces. Works for recursion when
        # at least one base-case return is non-recursive.
        line "auto #{cpp_method_name(mname)}(#{params}) {"
        @_declared_locals = Set.new
        all_param_names(method).each { |p| @_declared_locals << p.to_s }
        indented do
          body = method.body
          if trivial_body?(body)
            line "return 0LL;"
          elsif body.is_a?(Ast::InstanceVariableRead)
            line "return #{cpp_ivar(body.name)};"
          elsif body.is_a?(Ast::InstanceVariableWrite)
            # attr_writer body: @foo = val (returns val)
            line "#{cpp_ivar(body.name)} = #{cr(body.value_node)};"
            line "return #{cpp_ivar(body.name)};"
          elsif body.is_a?(Ast::Sequence)
            nodes = body.nodes
            nodes[0...-1].each { |n| emit_stmt(n) }
            emit_stmt_return(nodes.last) if nodes.last
          else
            emit_stmt_return(body)
          end
        end
        line "}"
      end

      def emit_constructor(name, init)
        params = (init.required_params || []).map { |p| "int64_t #{p}" }.join(", ")
        line "Ruby_#{name}(#{params}) {"
        @_declared_locals = Set.new
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
        ((method.required_params || []) + (method.required_kw_params || []))
      end

      def emit_method(name, method)
        params = all_param_names(method).map { |p| "auto #{p}" }.join(", ")
        line "static auto #{cpp_method_name(name)}(#{params}) {"
        @_declared_locals = Set.new
        all_param_names(method).each { |p| @_declared_locals << p.to_s }
        indented do
          body = method.body
          if body.is_a?(Ast::Sequence)
            nodes = body.nodes
            nodes[0...-1].each { |n| emit_stmt(n) }
            # Last expression → return
            emit_stmt_return(nodes.last) if nodes.last
          else
            emit_stmt_return(body)
          end
        end
        line "}"
      end

      def emit_stmt_return(node)
        s = cr(node)
        if s.include?("{\n") || s.start_with?("if ") || s.start_with?("while ") || s.start_with?("for ") || s.start_with?("return ")
          emit_stmt(node)
          # Loops/non-expression statements don't yield a value.
          # Emit a trailing `return INT64_C(0)` so `auto`-return methods
          # have a deducible return type (avoids deducing as `void`).
          if s.start_with?("while ") || s.start_with?("for ")
            line "return INT64_C(0);"
          end
        else
          line "return #{s};"
        end
      end

      def emit_main(execute_block)
        line "int main() {"
        @_declared_locals = Set.new
        indented do
          emit(execute_block.body) if execute_block&.body
          line "return 0;"
        end
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
        s = cr(node)
        # Blocks (if/for) don't need semicolons
        if s.include?("{\n")
          emit_indent; write s; emit_newline
        else
          line "#{s};"
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
        when Ast::LocalVariableRead then node.name.to_s
        when Ast::InstanceVariableRead then cpp_ivar(node.name)
        when Ast::InstanceVariableWrite then "#{cpp_ivar(node.name)} = #{cr(node.value_node)}"
        when Ast::MultipleAssignment
          # Simple case: @a, @b, @c = x, y, z (from array literal RHS)
          targets = node.targets
          vals = node.value_node
          if vals.is_a?(Ast::ArrayLiteral)
            elems = vals.element_nodes || []
            parts = targets.each_with_index.map { |t, i|
              tgt = t[0] == :ivar ? t[1].to_s : t[1].to_s
              "#{tgt} = #{elems[i] ? cr(elems[i]) : "0LL"}"
            }
            parts.join("; ")
          else
            "/* UNSUPPORTED masgn */"
          end
        when Ast::LocalVariableWrite
          name = node.name.to_s
          val = node.value_node
          if @_declared_locals&.include?(name)
            "#{name} = #{cr(val)}"
          else
            @_declared_locals << name
            type = local_decl_type(val)
            "#{type} #{name} = #{cr(val)}"
          end
        when Ast::If then cr_if(node)
        when Ast::Return then node.value_node ? "return #{cr(node.value_node)}" : "return"
        when Ast::And then "(#{cr(node.left_node)} && #{cr(node.right_node)})"
        when Ast::Or then "(#{cr(node.left_node)} || #{cr(node.right_node)})"
        when Ast::MethodCall then cr_method_call(node)
        when Ast::ConstantRead then node.name.to_s
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
          # a[i] = val (setter)
          if node.name == :[]=
            recv = cr(node.receiver_node)
            args = node.arg_nodes || []
            "#{recv}[#{cr(args[0])}] = #{cr(args[1])}"
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
          @_declared_locals&.add(var)
          coll = cr(node.collection_node)
          body_str = cr_block_body(node.body_node)
          old_indent = "  " * @indent
          "for (int64_t #{var} = 0; #{var} < #{coll}; #{var}++) {\n#{body_str}\n#{old_indent}}"
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
        # Detect unless: if cond; nil; else; body; end
        if node.then_node.is_a?(Ast::NilLiteral) && node.else_node
          body = nil
          indented { body = cr(node.else_node) }
          return "if (!(#{pred})) {\n#{indent_str}  #{body};\n#{indent_str}}"
        end
        then_body = nil
        indented { then_body = cr(node.then_node) }
        if node.else_node
          else_body = nil
          indented { else_body = cr(node.else_node) }
          "if (#{pred}) {\n#{indent_str}  #{then_body};\n#{indent_str}} else {\n#{indent_str}  #{else_body};\n#{indent_str}}"
        else
          "if (#{pred}) {\n#{indent_str}  #{then_body};\n#{indent_str}}"
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
        if node.is_a?(Ast::Sequence)
          node.nodes.each { |n| lines << (ind + cr(n) + ";") }
        else
          lines << (ind + cr(node) + ";")
        end
        lines.join("\n")
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

        # Arithmetic operators
        if recv && %i[+ - * / % < <= > >= == != << >> & | ^].include?(name) && args.size == 1
          return "(#{cr(recv)} #{name} #{cr(args[0])})"
        end

        # .length / .size / .bytesize — uniform via `.len` field
        # (both RubyArray<T> and RubyString expose `len`)
        if recv && %i[length size bytesize].include?(name) && args.empty?
          return "#{cr(recv)}.len"
        end

        # .dup
        return "#{cr(recv)}" if name == :dup && recv  # TODO: proper dup

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

        # respond_to?(:literal) — TODO: needs receiver class info; emit true placeholder
        return "true" if name == :respond_to? && args.size == 1 && args[0].is_a?(Ast::SymbolLiteral)

        # itself on receiver: identity
        return cr(recv) if name == :itself && args.empty?

        # General: recv.method(args)
        arg_strs = args.map { |a| cr(a) }.join(", ")
        "#{cr(recv)}.#{cpp_method_name(name)}(#{arg_strs})"
      end
    end
  end
end

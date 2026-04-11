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
        emit_header
        emit_newline

        # Emit settled constants
        emit_constants(top_level_scope)
        emit_newline

        # Emit user-defined top-level methods
        emit_user_methods(top_level_scope)
        emit_newline

        emit_main(execute_block)
        @out
      end

      private

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
        line "// Native Int64 array — TI-specialised, no boxing"
        line "class RubyArray_I64 {"
        line "public:"
        indented do
          line "int64_t* data;"
          line "int64_t len;"
          line "RubyArray_I64(int64_t size, int64_t fill = 0) : len(size) {"
          indented do
            line "data = (int64_t*)calloc(size, sizeof(int64_t));"
            line "if (fill) for (int64_t i = 0; i < size; i++) data[i] = fill;"
          end
          line "}"
          line "int64_t& operator[](int64_t i) { return data[i]; }"
          line "~RubyArray_I64() { free(data); }"
        end
        line "};"
        emit_newline
        line "// Native Float64 array"
        line "class RubyArray_F64 {"
        line "public:"
        indented do
          line "double* data;"
          line "int64_t len;"
          line "RubyArray_F64(int64_t size = 0, double fill = 0.0) : len(size) {"
          indented do
            line "data = (double*)calloc(size > 0 ? size : 1, sizeof(double));"
            line "if (fill != 0.0) for (int64_t i = 0; i < size; i++) data[i] = fill;"
          end
          line "}"
          line "double& operator[](int64_t i) { return data[i]; }"
          line "~RubyArray_F64() { free(data); }"
        end
        line "};"
        emit_newline
        line "static RubyNil RUBY_NIL_INSTANCE;"
        line "static RubyObject* RUBY_NIL = &RUBY_NIL_INSTANCE;"
      end

      CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

      def user_source_location?(loc)
        return false if loc.nil?
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @stub_file && file == @stub_file
        CORE_PATH_MARKERS.none? { |m| file.include?(m) }
      end

      def emit_constants(scope)
        const_table = scope.constants_table || {}
        const_locs = scope.constants_locations || {}
        const_table.each do |name, value|
          next if value.is_a?(Vm::ModuleObject)
          loc = const_locs[name]
          next unless user_source_location?(loc)
          case value
          when Vm::IntegerObject then line "static const int64_t #{name} = #{value.raw}LL;"
          when Vm::FloatObject then line "static const double #{name} = #{value.raw};"
          when Vm::StringObject then line "static const char* #{name} = #{value.raw.inspect};"
          when Vm::TrueObject then line "static const bool #{name} = true;"
          when Vm::FalseObject then line "static const bool #{name} = false;"
          end
        end
      end

      def emit_user_methods(scope)
        scope.methods_table&.each do |name, method|
          next unless method.is_a?(Vm::Method) && user_source_location?(method.source_location)
          # Skip stub methods (body is just nil)
          next if method.body.is_a?(Ast::NilLiteral)
          next if method.body.is_a?(Ast::Sequence) && method.body.nodes.size == 1 && method.body.nodes[0].is_a?(Ast::NilLiteral)
          emit_method(name, method)
          emit_newline
        end
      end

      def emit_method(name, method)
        params = (method.required_params || []).map { |p| "int64_t #{p}" }.join(", ")
        line "static int64_t #{name}(#{params}) {"
        @_declared_locals = Set.new
        (method.required_params || []).each { |p| @_declared_locals << p.to_s }
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
        when Ast::IntegerLiteral then "#{node.value.raw}LL"
        when Ast::FloatLiteral
          val = node.value.respond_to?(:raw) ? node.value.raw : node.value
          s = val.to_s
          s += ".0" unless s.include?('.') || s.include?('e')
          s
        when Ast::StringLiteral then "\"#{node.value.respond_to?(:raw) ? node.value.raw : node.value}\""
        when Ast::LocalVariableRead then node.name.to_s
        when Ast::LocalVariableWrite
          name = node.name.to_s
          val = node.value_node
          if @_declared_locals&.include?(name)
            "#{name} = #{cr(val)}"
          else
            @_declared_locals << name
            # Detect Array.new → RubyArray_I64 type
            type = if val.is_a?(Ast::MethodCall) && val.name == :new &&
                      val.receiver_node.is_a?(Ast::ConstantRead) && val.receiver_node.name == :Array
              "RubyArray_I64"
            else
              "int64_t"
            end
            "#{type} #{name} = #{cr(val)}"
          end
        when Ast::If then cr_if(node)
        when Ast::Return then node.value_node ? "return #{cr(node.value_node)}" : "return"
        when Ast::And then "(#{cr(node.left_node)} && #{cr(node.right_node)})"
        when Ast::Or then "(#{cr(node.left_node)} || #{cr(node.right_node)})"
        when Ast::MethodCall then cr_method_call(node)
        when Ast::ConstantRead then node.name.to_s
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
            "#{cr(node.receiver_node)}.#{node.name}(#{(node.arg_nodes || []).map { |a| cr(a) }.join(', ')})"
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

      def cr_method_call(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []

        # puts → printf (auto-detect int vs float from literal type)
        if recv.nil? && name == :puts
          if args.empty?
            return "printf(\"\\n\")"
          else
            arg = cr(args[0])
            # Heuristic: if arg contains . or is a known float var, use %f
            return "printf(\"%.9f\\n\", (double)(#{arg}))" if arg.include?('.') || @_float_vars&.include?(args[0].respond_to?(:name) ? args[0].name.to_s : nil)
            return "printf(\"%lld\\n\", (long long)(#{arg}))"
          end
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

        # Array.new(size, fill)
        if name == :new && recv.is_a?(Ast::ConstantRead) && recv.name == :Array
          if args.size == 2 && !node.block_node
            return "RubyArray_I64(#{cr(args[0])}, #{cr(args[1])})"
          elsif args.size == 1 && node.block_node
            # Array.new(n) { |i| expr } — unfold into loop
            blk = node.block_node
            var = (blk.required_params || [])[0] || :_ai
            @_declared_locals&.add(var.to_s)
            size_expr = cr(args[0])
            body_expr = cr(blk.body)
            # Return a C++ compound expression that builds the array
            return "({ auto _arr = RubyArray_F64(#{size_expr}); for (int64_t #{var} = 0; #{var} < #{size_expr}; #{var}++) { _arr[#{var}] = #{body_expr}; } _arr; })"
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

        # Arithmetic operators
        if recv && %i[+ - * / % < <= > >= == != << >> & | ^].include?(name) && args.size == 1
          return "(#{cr(recv)} #{name} #{cr(args[0])})"
        end

        # .length / .size
        if recv && (name == :length || name == :size) && args.empty?
          return "#{cr(recv)}.len"
        end

        # .dup
        return "#{cr(recv)}" if name == :dup && recv  # TODO: proper dup

        # Free function call
        if recv.nil?
          arg_strs = args.map { |a| cr(a) }.join(", ")
          return "#{name}(#{arg_strs})"
        end

        # General: recv.method(args)
        arg_strs = args.map { |a| cr(a) }.join(", ")
        "#{cr(recv)}.#{name}(#{arg_strs})"
      end
    end
  end
end

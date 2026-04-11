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

      def emit_user_methods(scope)
        scope.methods_table&.each do |name, method|
          next unless method.is_a?(Vm::Method) && user_source_location?(method.source_location)
          emit_method(name, method)
          emit_newline
        end
      end

      def emit_method(name, method)
        # For now: emit all methods as returning int64_t (TI would tell us)
        params = (method.required_params || []).map { |p| "int64_t #{p}" }.join(", ")
        line "static int64_t #{name}(#{params}) {"
        @_declared_locals = Set.new
        (method.required_params || []).each { |p| @_declared_locals << p.to_s }
        indented { emit(method.body) }
        line "}"
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
        when Ast::FloatLiteral then "#{node.value.respond_to?(:raw) ? node.value.raw : node.value}"
        when Ast::StringLiteral then "\"#{node.value.respond_to?(:raw) ? node.value.raw : node.value}\""
        when Ast::LocalVariableRead then node.name.to_s
        when Ast::LocalVariableWrite
          name = node.name.to_s
          if @_declared_locals&.include?(name)
            "#{name} = #{cr(node.value_node)}"
          else
            @_declared_locals << name
            "int64_t #{name} = #{cr(node.value_node)}"
          end
        when Ast::If then cr_if(node)
        when Ast::Return then node.value_node ? "return #{cr(node.value_node)}" : "return"
        when Ast::MethodCall then cr_method_call(node)
        when Ast::Sequence then node.nodes.map { |n| cr(n) }.join("; ")
        else "/* UNSUPPORTED: #{node.class.name.split('::').last} */"
        end
      end

      def cr_if(node)
        pred = cr_truthy(node.pred_node)
        indent_str = "  " * @indent
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

        # puts → printf
        if recv.nil? && name == :puts
          return args.empty? ? "puts(\"\")" :
            "printf(\"%lld\\n\", (long long)(#{cr(args[0])}))"
        end

        # .times { block }
        if name == :times && recv && node.block_node
          blk = node.block_node
          var = (blk.required_params || [])[0] || :_i
          body = nil
          indented { body = cr(blk.body) }
          indent_str = "  " * @indent
          return "for (int64_t #{var} = 0; #{var} < #{cr(recv)}; #{var}++) {\n#{indent_str}  #{body};\n#{indent_str}}"
        end

        # Arithmetic operators
        if recv && %i[+ - * / % < <= > >= == != << >>].include?(name) && args.size == 1
          return "(#{cr(recv)} #{name} #{cr(args[0])})"
        end

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

require_relative '../ast/node'

module Frozone
  module Compiler
    # Visitor that walks a Frozone AST and emits Crystal source code.
    #
    # Usage:
    #   ast  = Frozone::Vm::Parser.new(source, file).parse
    #   code = CrystalCodegen.new.generate(ast)
    #   File.write("out.cr", code)
    #
    # Design: single case dispatch in #emit — no modifications to AST nodes.
    # The runtime library lives in crystal/src/ and is required at the top of
    # every emitted file via RUNTIME_REQUIRE.
    class CrystalCodegen
      CRYSTAL_DIR = File.expand_path('../../../crystal', __dir__)

      def initialize(output_dir: CRYSTAL_DIR)
        @out          = +""        # output buffer
        @indent       = 0          # current indentation level
        @errors       = []         # collect unsupported-node warnings
        @output_dir   = output_dir # used to compute relative runtime require path
        @user_methods = Set.new    # names of user-defined methods (for RubyObject stubs)
      end

      # Generate a complete Crystal source file from the top-level AST node.
      # Returns the Crystal source as a String.
      def generate(node)
        # Two-pass: collect user-defined method names, then emit.
        collect_user_methods(node)
        emit_header
        emit_user_method_stubs unless @user_methods.empty?
        emit(node)
        emit_newline
        @out
      end

      # Collect all method names defined in user classes/modules.
      def collect_user_methods(node)
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_user_methods(n) }
        when Ast::ClassDef, Ast::ModuleDef
          body = ivar(node, :body)
          collect_user_methods(body) if body
        when Ast::MethodDef
          @user_methods << ivar(node, :name)
        end
      end

      # Methods already defined on RubyObject — skip stub generation for these.
      RUBY_OBJECT_METHODS = %i[initialize to_s inspect hash == != truthy?
                               ruby_nil? ruby_bool? not [] []= ruby_to_s ruby_inspect].to_set

      # Emit RubyObject stub methods for all user-defined methods.
      # This allows polymorphic dispatch: `obj.some_method` where `obj : RubyObject`
      # compiles because Crystal sees the stub and dispatches to the real implementation.
      def emit_user_method_stubs
        stubs = @user_methods.reject { |n|
          RUBY_OBJECT_METHODS.include?(n) || operator?(n)
        }
        return if stubs.empty?

        write "# User-defined method stubs on RubyObject for polymorphic dispatch"
        emit_newline
        write "class RubyObject"
        emit_newline
        stubs.each do |name|
          crystal_name = crystal_method_name(name)
          write "  def #{crystal_name}(*args) : RubyObject"
          emit_newline
          write "    raise Exception.new(\"undefined method '#{name}' for \#{self.class}\")"
          emit_newline
          write "  end"
          emit_newline
        end
        write "end"
        emit_newline
        emit_newline
      end

      # The directory that generated .cr files should be placed in (so that
      # relative require paths to the runtime resolve correctly).
      def output_dir = @output_dir

      attr_reader :errors

      private

      # -----------------------------------------------------------------------
      # Top-level dispatch
      # -----------------------------------------------------------------------

      def emit(node)
        case node
        when Ast::Sequence              then emit_sequence(node)
        when Ast::NilLiteral            then emit_nil_literal
        when Ast::TrueLiteral           then emit_true_literal
        when Ast::FalseLiteral          then emit_false_literal
        when Ast::IntegerLiteral        then emit_integer_literal(node)
        when Ast::FloatLiteral          then emit_float_literal(node)
        when Ast::StringLiteral         then emit_string_literal(node)
        when Ast::SymbolLiteral         then emit_symbol_literal(node)
        when Ast::SelfLiteral           then emit_self_literal
        when Ast::LocalVariableRead     then emit_local_var_read(node)
        when Ast::LocalVariableWrite    then emit_local_var_write(node)
        when Ast::InstanceVariableRead  then emit_ivar_read(node)
        when Ast::InstanceVariableWrite then emit_ivar_write(node)
        when Ast::ConstantRead          then emit_constant_read(node)
        when Ast::MethodCall            then emit_method_call(node)
        when Ast::AttributeWrite        then emit_attribute_write(node)
        when Ast::MethodDef             then emit_method_def(node)
        when Ast::ClassDef              then emit_class_def(node)
        when Ast::ModuleDef             then emit_module_def(node)
        when Ast::If                    then emit_if(node)
        when Ast::While                 then emit_while(node)
        when Ast::Until                 then emit_until(node)
        when Ast::Return                then emit_return(node)
        when Ast::And                   then emit_and(node)
        when Ast::Or                    then emit_or(node)
        when Ast::ArrayLiteral          then emit_array_literal(node)
        when Ast::HashLiteral           then emit_hash_literal(node)
        when Ast::InterpolatedString    then emit_interpolated_string(node)
        when Ast::Block                 then unsupported!(node, "bare Block outside method call")
        else
          unsupported!(node)
        end
      end

      # -----------------------------------------------------------------------
      # Header
      # -----------------------------------------------------------------------

      def emit_header
        runtime = File.join(@output_dir, 'src', 'frozone_crystal')
        # Emit a relative require so Crystal can find the runtime
        # (Crystal absolute path resolution is quirky; relative is reliable).
        line %(require "./src/frozone_crystal")
        emit_newline
        line "RUBY_NIL   = RubyNil::INSTANCE"
        line "RUBY_TRUE  = RubyBool::TRUE"
        line "RUBY_FALSE = RubyBool::FALSE"
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Literals
      # -----------------------------------------------------------------------

      def emit_nil_literal
        write "RUBY_NIL"
      end

      def emit_true_literal
        write "RUBY_TRUE"
      end

      def emit_false_literal
        write "RUBY_FALSE"
      end

      def emit_integer_literal(node)
        val = ivar(node, :value).raw
        write "RubyInteger.new(#{val}_i64)"
      end

      def emit_float_literal(node)
        val = ivar(node, :value).raw
        write "RubyFloat.new(#{val}_f64)"
      end

      def emit_string_literal(node)
        raw = ivar(node, :value).raw
        write %(RubyString.new(#{crystal_string_literal(raw)}))
      end

      def emit_symbol_literal(node)
        name = ivar(node, :name)
        write %(RubySymbol.from(#{name.to_s.inspect}))
      end

      def emit_self_literal
        write "self"
      end

      # -----------------------------------------------------------------------
      # Variables
      # -----------------------------------------------------------------------

      def emit_local_var_read(node)
        write crystal_local(ivar(node, :name))
      end

      def emit_local_var_write(node)
        write "#{crystal_local(ivar(node, :name))} = "
        emit(ivar(node, :value_node))
      end

      def emit_ivar_read(node)
        write ivar(node, :name).to_s  # already includes leading @
      end

      def emit_ivar_write(node)
        write "#{ivar(node, :name)} = "
        emit(ivar(node, :value_node))
      end

      def emit_constant_read(node)
        write "Ruby_#{crystal_constant(ivar(node, :name))}"
      end

      # -----------------------------------------------------------------------
      # Sequence
      # -----------------------------------------------------------------------

      def emit_sequence(node)
        node.nodes.each_with_index do |child, i|
          emit_newline if i > 0
          emit_indent
          emit(child)
        end
      end

      # -----------------------------------------------------------------------
      # Method call
      # -----------------------------------------------------------------------

      def emit_method_call(node)
        name = node.name

        # Kernel-level methods with no receiver map to top-level helpers
        if node.receiver_node.nil?
          case name
          when :puts   then return emit_puts(node)
          when :print  then return emit_print(node)
          when :p      then return emit_p(node)
          when :raise  then return emit_raise(node)
          when :require then return emit_require_call(node)
          end
        end

        # Operator and unary methods — emit as Crystal operator syntax
        if node.receiver_node
          return emit_operator(node, name) if operator?(name)
        end

        # General method call: receiver.method(args)
        if node.receiver_node
          emit(node.receiver_node)
          write "."
        end
        write crystal_method_name(name)
        emit_call_args(node)
      end

      BINARY_OPS = %i[+ - * / % ** == != < <= > >= <=> << >> & | ^ === =~].to_set
      UNARY_OPS  = %i[-@ +@ ~ !].to_set
      # Comparison operators that return Crystal Bool — wrap in RubyBool for consistency
      COMPARE_OPS = %i[== != < <= > >= === =~].to_set

      # AttributeWrite: obj[key] = val (e.g. @hash[k] = v)
      def emit_attribute_write(node)
        emit(ivar(node, :receiver_node))
        write "["
        emit(ivar(node, :arg_nodes)[0])
        write "] = "
        emit(ivar(node, :arg_nodes)[1])
      end

      def operator?(name)
        BINARY_OPS.include?(name) || UNARY_OPS.include?(name)
      end

      def emit_operator(node, name)
        if UNARY_OPS.include?(name)
          # Crystal unary minus is a zero-arg def -, called as recv.-
          # Emit as method call for -@ and ~; inline for +@ (no-op)
          case name
          when :"-@"
            write "("
            emit(node.receiver_node)
            write ".-)"
          when :"+@"
            emit(node.receiver_node)
          when :"~"
            write "~("
            emit(node.receiver_node)
            write ")"
          when :"!"
            write "!("
            emit_truthy(node.receiver_node)
            write ")"
          end
        elsif COMPARE_OPS.include?(name)
          # Comparison: wrap in RubyBool so return type is RubyObject-compatible
          # (a >= b) ? RUBY_TRUE : RUBY_FALSE
          write "(("
          emit(node.receiver_node)
          write " #{name} "
          emit(node.arg_nodes[0])
          write ") ? RUBY_TRUE : RUBY_FALSE)"
        else
          # Arithmetic binary: (lhs op rhs) — returns RubyObject via Crystal dispatch
          write "("
          emit(node.receiver_node)
          write " #{name} "
          emit(node.arg_nodes[0])
          write ")"
        end
      end

      def emit_puts(node)
        if node.arg_nodes.empty?
          write "STDOUT.puts; RUBY_NIL"
        elsif node.arg_nodes.length == 1
          write "STDOUT.puts("
          emit(node.arg_nodes[0])
          write ".to_s); RUBY_NIL"
        else
          node.arg_nodes.each do |arg|
            write "STDOUT.puts("
            emit(arg)
            write ".to_s); "
          end
          write "RUBY_NIL"
        end
      end

      def emit_print(node)
        write "STDOUT.print("
        node.arg_nodes.each_with_index do |arg, i|
          write ", " if i > 0
          emit(arg)
          write ".to_s"
        end
        write ")"
      end

      def emit_p(node)
        node.arg_nodes.each_with_index do |arg, i|
          write "; " if i > 0
          write "STDOUT.puts("
          emit(arg)
          write ".inspect)"
        end
      end

      def emit_raise(node)
        write "raise "
        if node.arg_nodes.empty?
          write "RuntimeError.new"
        else
          emit(node.arg_nodes[0])
          write ".to_s"
        end
      end

      def emit_require_call(node)
        # Silently drop require calls — closed world, all files already compiled.
        write "# require #{node.arg_nodes[0].inspect} (dropped — closed world)"
      end

      def emit_call_args(node)
        return if node.arg_nodes.empty? && node.kw_arg_nodes.empty? && node.block_node.nil?

        write "("
        first = true
        node.arg_nodes.each do |arg|
          write ", " unless first
          first = false
          emit(arg)
        end
        node.kw_arg_nodes.each do |kw_name, val_node|
          write ", " unless first
          first = false
          write "#{kw_name}: "
          emit(val_node)
        end
        write ")"

        if node.block_node
          write " "
          emit_block(node.block_node)
        end
      end

      # -----------------------------------------------------------------------
      # Block
      # -----------------------------------------------------------------------

      def emit_block(node)
        params = ivar(node, :required_params) + ivar(node, :optional_params).map(&:first)
        params += [ivar(node, :rest_param)].compact
        write "{ "
        unless params.empty?
          write "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        end
        emit(ivar(node, :body))
        write " }"
      end

      # -----------------------------------------------------------------------
      # Control flow
      # -----------------------------------------------------------------------

      def emit_if(node)
        write "if "
        emit_truthy(node.pred_node)
        emit_newline
        indented { emit(node.then_node) }
        if node.else_node
          emit_newline
          emit_indent
          write "else"
          emit_newline
          indented { emit(node.else_node) }
        end
        emit_newline
        emit_indent
        write "end"
      end

      def emit_while(node)
        write "while "
        emit_truthy(ivar(node, :condition_node))
        emit_newline
        indented { emit(ivar(node, :body_node)) }
        emit_newline
        emit_indent
        write "end"
      end

      def emit_until(node)
        write "until "
        emit_truthy(ivar(node, :condition_node))
        emit_newline
        indented { emit(ivar(node, :body_node)) }
        emit_newline
        emit_indent
        write "end"
      end

      def emit_return(node)
        write "return"
        val = ivar(node, :value_node)
        if val
          write " "
          emit(val)
        end
      end

      # -----------------------------------------------------------------------
      # Boolean operators
      # -----------------------------------------------------------------------

      def emit_and(node)
        emit_truthy(ivar(node, :left_node))
        write " && "
        emit_truthy(ivar(node, :right_node))
      end

      def emit_or(node)
        emit_truthy(ivar(node, :left_node))
        write " || "
        emit_truthy(ivar(node, :right_node))
      end

      # Wrap a value in a Crystal truthy check when used as a condition.
      # If the node is already a comparison/predicate that returns Bool, emit
      # it directly; otherwise wrap in .truthy?
      def emit_truthy(node)
        if boolean_valued?(node)
          emit(node)
        else
          emit(node)
          write ".truthy?"
        end
      end

      # Methods that return Crystal Bool directly (not RubyObject).
      # Use the Crystal name (after RUBY_TO_CRYSTAL_METHOD mapping).
      BOOL_METHODS = %i[ruby_nil? empty? frozen? zero? positive? negative?
                        truthy? ruby_bool?
                        is_a? kind_of? instance_of? equal?].to_set

      # Heuristic: is this node likely to return a Crystal Bool directly?
      def boolean_valued?(node)
        case node
        when Ast::TrueLiteral, Ast::FalseLiteral then true
        when Ast::And, Ast::Or                   then true
        when Ast::MethodCall
          # Comparison operators now emit as (a op b) ? RUBY_TRUE : RUBY_FALSE → RubyBool
          # (no longer Crystal Bool, so .truthy? is needed — return false here)
          # Known predicate methods that return Crystal Bool directly
          crystal_name = RUBY_TO_CRYSTAL_METHOD.fetch(node.name, node.name)
          BOOL_METHODS.include?(crystal_name)
        else false
        end
      end

      # -----------------------------------------------------------------------
      # Collections
      # -----------------------------------------------------------------------

      def emit_array_literal(node)
        write "RubyArray.new(["
        ivar(node, :element_nodes).each_with_index do |el, i|
          write ", " if i > 0
          emit(el)
        end
        write "] of RubyObject)"
      end

      def emit_hash_literal(node)
        write "RubyHash.new"
        pairs = ivar(node, :kv_nodes)
        unless pairs.empty?
          write ".tap { |_h| "
          pairs.each do |k, v|
            write "_h.store("
            emit(k)
            write ", "
            emit(v)
            write "); "
          end
          write "}"
        end
      end

      def emit_interpolated_string(node)
        write "RubyString.new(String.build { |_s| "
        ivar(node, :parts).each do |part|
          case part
          when Ast::StringLiteral
            raw = ivar(part, :value).raw
            write "_s << #{crystal_string_literal(raw)}; "
          else
            write "_s << ("
            emit(part)
            write ").to_s; "
          end
        end
        write "})"
      end

      # -----------------------------------------------------------------------
      # Method definition
      # -----------------------------------------------------------------------

      # Methods that must return Crystal String (override RubyObject abstract defs)
      STRING_RETURN_METHODS = %i[to_s inspect].to_set

      def emit_method_def(node)
        recv = ivar(node, :receiver_node)
        name = ivar(node, :name)
        string_return = STRING_RETURN_METHODS.include?(name)
        # Method definition: don't translate to_s → ruby_to_s; emit as-is (Crystal protocol)
        crystal_name = string_return ? name.to_s : crystal_method_name(name)

        if recv
          write "def "
          emit(recv)
          write ".#{crystal_name}"
        else
          write "def #{crystal_name}"
        end
        write " : String" if string_return
        emit_param_list(node)
        emit_newline
        if string_return
          # Body may return RubyString; wrap in .to_s to produce Crystal String
          indented do
            write "(begin"
            emit_newline
            indented { emit(ivar(node, :body)) }
            emit_newline
            emit_indent
            write "end).to_s"
          end
        else
          indented { emit(ivar(node, :body)) }
        end
        emit_newline
        emit_indent
        write "end"
      end

      def emit_param_list(node)
        parts = []
        ivar(node, :required_params).each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        ivar(node, :optional_params).each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        rp = ivar(node, :rest_param)
        parts << "*#{crystal_local(rp)} : RubyObject" if rp
        ivar(node, :post_params).each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        ivar(node, :required_kw_params).each { |p| parts << "#{p}: #{crystal_local(p)} : RubyObject" }
        ivar(node, :optional_kw_params).each { |p, default| parts << "#{p}: #{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        kr = ivar(node, :kw_rest_param)
        parts << "**#{crystal_local(kr)} : RubyObject" if kr
        bp = ivar(node, :block_param)
        parts << "&#{crystal_local(bp)}" if bp
        write "(#{parts.join(', ')})" unless parts.empty?
      end

      # -----------------------------------------------------------------------
      # Class / module definitions
      # -----------------------------------------------------------------------

      def emit_class_def(node)
        name = crystal_constant(ivar(node, :name))
        write "class Ruby_#{name}"
        sc = ivar(node, :superclass_node)
        if sc
          write " < Ruby_#{crystal_constant(ivar(sc, :name))}"
        else
          write " < RubyObject"
        end
        emit_newline
        indented do
          # Declare all ivars as RubyObject = RUBY_NIL so Crystal knows the type
          ivars = collect_ivars(ivar(node, :body))
          ivars.each { |iv| line "#{iv} : RubyObject = RUBY_NIL" }
          emit_newline unless ivars.empty?
          # Default RubyObject abstract method implementations
          line "def to_s : String; \"#<#{name}>\"; end"
          line "def inspect : String; \"#<#{name}>\"; end"
          line "def ==(other : RubyObject) : Bool; same?(other); end"
          emit_newline
          emit_indent
          emit(ivar(node, :body))
        end
        emit_newline
        emit_indent
        write "end"
      end

      def emit_module_def(node)
        write "module Ruby_#{crystal_constant(ivar(node, :name))}"
        emit_newline
        indented { emit(ivar(node, :body)) }
        emit_newline
        emit_indent
        write "end"
      end

      # -----------------------------------------------------------------------
      # Output helpers
      # -----------------------------------------------------------------------

      def write(str)
        @out << str
      end

      def line(str)
        @out << ("  " * @indent) << str << "\n"
      end

      def emit_indent
        @out << ("  " * @indent)
      end

      def emit_newline
        @out << "\n"
      end

      def indented
        @indent += 1
        yield
        @indent -= 1
      end

      # -----------------------------------------------------------------------
      # Name helpers
      # -----------------------------------------------------------------------

      # Map a Ruby method name symbol to a Crystal method name string.
      # Crystal keywords and operators need mangling.
      CRYSTAL_KEYWORDS = %w[
        abstract alias annotation asm begin break case class def do else elsif
        end ensure enum extend false for fun if in include instance_sizeof
        is_a? lib macro module next nil of out pointerof private protected
        require rescue responds_to? return select self sizeof struct super
        then true type typeof union unless until verbatim when while with yield
      ].to_set

      # Ruby method names that map to different Crystal method names at CALL sites.
      # (Crystal's to_s/inspect return String; Ruby's return RubyString)
      RUBY_TO_CRYSTAL_METHOD = {
        nil?:    :ruby_nil?,
        to_s:    :ruby_to_s,
        inspect: :ruby_inspect,
      }.freeze

      def crystal_method_name(sym)
        return RUBY_TO_CRYSTAL_METHOD[sym].to_s if RUBY_TO_CRYSTAL_METHOD.key?(sym)
        s = sym.to_s
        CRYSTAL_KEYWORDS.include?(s) ? "ruby_#{s}" : s
      end

      def crystal_local(sym)
        s = sym.to_s
        CRYSTAL_KEYWORDS.include?(s) ? "loc_#{s}" : s
      end

      def crystal_constant(sym_or_str)
        sym_or_str.to_s
      end

      # Escape a Ruby string value (a native Ruby String) for use as a Crystal
      # string literal.
      def crystal_string_literal(str)
        # Crystal string literals use the same escapes as Ruby for ASCII,
        # but we emit raw bytes for non-ASCII to let Crystal handle encoding.
        str.inspect   # Ruby's inspect gives us a valid double-quoted literal
                      # that Crystal also accepts for ASCII-safe strings.
                      # TODO: handle non-UTF-8 encoded strings properly.
      end

      # -----------------------------------------------------------------------
      # Inline codegen for default parameter values
      # -----------------------------------------------------------------------

      def codegen_inline(node)
        sub = CrystalCodegen.new
        sub.instance_variable_set(:@indent, 0)
        sub.send(:emit, node)
        sub.instance_variable_get(:@out)
      end

      # -----------------------------------------------------------------------
      # Ivar collection — scan a class body AST for all @ivar assignments
      # -----------------------------------------------------------------------

      def collect_ivars(node, seen = Set.new)
        case node
        when Ast::InstanceVariableWrite
          seen << ivar(node, :name).to_s
          collect_ivars(ivar(node, :value_node), seen)
        when Ast::Sequence
          node.nodes.each { |n| collect_ivars(n, seen) }
        when Ast::MethodDef
          collect_ivars(ivar(node, :body), seen) if ivar(node, :body)
        when Ast::If
          collect_ivars(node.then_node, seen)
          collect_ivars(node.else_node, seen) if node.else_node
        when nil
          # nothing
        else
          # For other nodes, recurse into known child slots
          %i[body value_node then_node else_node body_node].each do |slot|
            child = node.instance_variable_defined?(:"@#{slot}") && node.instance_variable_get(:"@#{slot}")
            collect_ivars(child, seen) if child && child.is_a?(Ast::Node)
          end
        end
        seen.to_a.sort
      end

      # -----------------------------------------------------------------------
      # AST accessor helper — most AST nodes lack attr_reader
      # -----------------------------------------------------------------------

      def ivar(node, name)
        node.instance_variable_get(:"@#{name}")
      end

      # -----------------------------------------------------------------------
      # Error handling
      # -----------------------------------------------------------------------

      def unsupported!(node, msg = nil)
        name = node.class.name.split('::').last
        message = msg ? "#{name}: #{msg}" : name
        @errors << message
        write "# UNSUPPORTED: #{message}"
      end
    end
  end
end

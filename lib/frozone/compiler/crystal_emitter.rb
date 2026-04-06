require_relative '../ast/node'

module Frozone
  module Compiler
    # Visitor that walks a Frozone AST and emits Crystal source code.
    #
    # Usage:
    #   ast  = Frozone::Vm::Parser.new(source, file).parse
    #   code = CrystalEmitter.new.generate(ast)
    #   File.write("out.cr", code)
    #
    # Design: single case dispatch in #emit — no modifications to AST nodes.
    # The runtime library lives in crystal/src/ and is required at the top of
    # every emitted file via RUNTIME_REQUIRE.
    class CrystalEmitter
      CRYSTAL_DIR = File.expand_path('../../../crystal', __dir__)

      # The directory that generated .cr files should be placed in (so that
      # relative require paths to the runtime resolve correctly).
      def output_dir = @output_dir
      attr_reader :errors

      def initialize(output_dir: CRYSTAL_DIR)
        @out = +""                  # output buffer
        @indent = 0                 # current indentation level
        @errors = []                # collect unsupported-node warnings
        @output_dir = output_dir    # used to compute relative runtime require path
        @user_methods = Set.new     # names of user-defined methods (for RubyObject stubs)
        @exception_classes = Set.new # Ruby class names that inherit from exception bases
        @in_exception_class = false # true while emitting inside an exception class body
        @temp_counter = 0           # unique suffix for generated temp variable names
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

      # Ruby base exception class names — subclasses of these become RubyException in Crystal.
      EXCEPTION_BASE_NAMES = %w[
        Exception StandardError RuntimeError ArgumentError TypeError NameError
        NoMethodError ZeroDivisionError IOError IndexError KeyError StopIteration
        NotImplementedError RangeError RegexpError SystemExit Interrupt
        SystemCallError EncodingError EnvError LoadError SyntaxError
      ].to_set

      # Ruby class names that don't need explicit default stubs when inherited from.
      # If a class inherits from one of these, we still emit the default stubs.
      BUILTIN_SUPERCLASSES = (%w[
        Object BasicObject Numeric Integer Float String Array Hash Symbol
        IO File Dir Proc Struct Data Comparable Enumerable
      ] + EXCEPTION_BASE_NAMES.to_a).to_set

      # Collect all method names defined in user classes/modules, and
      # track which classes are exception classes.
      def collect_user_methods(node)
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_user_methods(n) }
        when Ast::ClassDef
          sc = node.superclass_node
          if sc.is_a?(Ast::ConstantRead)
            sc_name = sc.name.to_s
            if EXCEPTION_BASE_NAMES.include?(sc_name) || @exception_classes.include?(sc_name.to_sym)
              @exception_classes << node.name
            end
          end
          body = node.body
          collect_user_methods(body) if body
        when Ast::ModuleDef
          body = node.body
          collect_user_methods(body) if body
        when Ast::MethodDef
          @user_methods << node.name
        when Ast::MethodCall
          # attr_accessor/reader/writer implicitly define methods
          mname = node.name
          if ATTR_METHODS.include?(mname)
            node.arg_nodes.each do |a|
              next unless a.is_a?(Ast::SymbolLiteral)
              sym_name = a.value
              @user_methods << sym_name           unless mname == :attr_writer
              @user_methods << :"#{sym_name}="    unless mname == :attr_reader
            end
          end
        end
      end

      # Methods already defined on RubyObject — skip stub generation for these.
      RUBY_OBJECT_METHODS = %i[initialize to_s inspect hash == != truthy?
                               ruby_nil? ruby_bool? not [] []= ruby_to_s ruby_inspect
                               itself dup succ ord bytesize b floor abs
                               getbyte setbyte fetch set get putc pos max min
                               length size each respond_to?
                               matches? failure_message].to_set

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
          # Crystal setters must have exactly one parameter (no *args)
          params = crystal_name.end_with?('=') ? "(val : RubyObject)" : "(*args)"
          write "  def #{crystal_name}#{params} : RubyObject"
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

      private

      # -----------------------------------------------------------------------
      # Top-level dispatch
      # -----------------------------------------------------------------------

      # Return Crystal source string for an AST node.
      # Inline nodes return a single string. Structural nodes (if, while, etc.)
      # return a string with embedded \n — callers split if they need lines.
      # This is the functional core; emit(node) is the write wrapper.
      def cr(node)
        case node
        when Ast::NilLiteral         then cr_nil
        when Ast::TrueLiteral        then cr_true
        when Ast::FalseLiteral       then cr_false
        when Ast::IntegerLiteral     then cr_integer(node)
        when Ast::FloatLiteral       then cr_float(node)
        when Ast::StringLiteral      then cr_string(node)
        when Ast::SymbolLiteral      then cr_symbol(node)
        when Ast::SelfLiteral        then cr_self
        when Ast::LocalVariableRead  then cr_local_read(node)
        when Ast::InstanceVariableRead then cr_ivar_read(node)
        when Ast::ConstantRead       then cr_constant_read(node)
        when Ast::ClassVariableRead  then cr_class_var_read(node)
        when Ast::And                then cr_and(node)
        when Ast::Or                 then cr_or(node)
        when Ast::ArrayLiteral       then cr_array_literal(node)
        when Ast::HashLiteral        then cr_hash_literal(node)
        when Ast::RangeLiteral       then cr_range_literal(node)
        when Ast::InterpolatedString then cr_interpolated_string(node)
        when Ast::Return             then cr_return(node)
        when Ast::Next               then cr_next(node)
        when Ast::Break              then cr_break(node)
        when Ast::GlobalVariableRead then cr_global_var_read(node)
        when Ast::ConstantPath       then cr_constant_path(node)
        when Ast::LocalVariableWrite then cr_local_var_write(node)
        when Ast::InstanceVariableWrite then cr_ivar_write(node)
        when Ast::ConstantWrite      then cr_constant_write(node)
        when Ast::ClassVariableWrite then cr_class_var_write(node)
        when Ast::GlobalVariableWrite then cr_global_var_write(node)
        when Ast::IndexOrWrite       then cr_index_or_write(node)
        when Ast::IndexOperatorWrite then cr_index_op_write(node)
        when Ast::IndexAndWrite      then cr_index_and_write(node)
        when Ast::Yield              then cr_yield(node)
        when Ast::Super              then cr_super(node)
        when Ast::Lambda             then cr_lambda(node)
        when Ast::AttributeWrite     then cr_attribute_write(node)
        when Ast::MethodCall         then cr_method_call(node)
        when Ast::Retry              then "retry"
        # Structural nodes — join lines with current indent
        when Ast::Sequence, Ast::If, Ast::While, Ast::Until, Ast::Rescue,
             Ast::ForLoop, Ast::MultipleAssignment, Ast::Case,
             Ast::MethodDef, Ast::ClassDef, Ast::ModuleDef
          cr_lines(node).join("\n#{'  ' * @indent}")
        else
          # Nodes without cr_* yet — capture at indent 0 for clean composition
          saved = @indent; @indent = 0
          s = capture { emit_node(node) }
          @indent = saved
          s
        end
      end

      # Return unindented Array<String> for an AST node.
      # Structural nodes (if, while, sequence) compose via indent(cr_lines(body)).
      # Inline nodes return a single-element array.
      def cr_lines(node)
        case node
        when Ast::Sequence then cr_sequence_lines(node)
        when Ast::If       then cr_if_lines(node)
        when Ast::While    then cr_while_lines(node)
        when Ast::Until    then cr_until_lines(node)
        when Ast::Rescue              then cr_rescue_lines(node)
        when Ast::ForLoop             then cr_for_loop_lines(node)
        when Ast::MultipleAssignment  then cr_multiple_assignment_lines(node)
        when Ast::Case                then cr_case_lines(node)
        when Ast::MethodDef           then cr_method_def_lines(node)
        when Ast::ClassDef            then cr_class_def_lines(node)
        when Ast::ModuleDef           then cr_module_def_lines(node)
        else
          # Inline nodes or unconverted structural nodes
          s = cr(node)
          s.include?("\n") ? s.split("\n") : [s]
        end
      end

      # Write Crystal source for an AST node to the output buffer.
      def emit(node)
        lines = cr_lines(node)
        lines.each_with_index do |line, i|
          if i > 0
            emit_newline
            emit_indent
          end
          write line
        end
      end

      # Imperative dispatch — fallback for nodes not in cr() dispatch.
      def emit_node(node)
        case node
        when Ast::Block then unsupported!(node, "bare Block outside method call")
        else unsupported!(node)
        end
      end

      # -----------------------------------------------------------------------
      # Header
      # -----------------------------------------------------------------------

      def emit_header
        runtime = File.join(@output_dir, 'src', 'frozone_crystal')
        # Emit a relative require so Crystal can find the runtime
        # (Crystal absolute path resolution is quirky; relative is reliable).
        line %(require "../src/frozone_crystal")
        emit_newline
        line "RUBY_NIL    = RubyNil::INSTANCE"
        line "RUBY_TRUE   = RubyBool::TRUE"
        line "RUBY_FALSE  = RubyBool::FALSE"
        line "RUBY_GLOBALS = {} of String => RubyObject"
        line "Ruby_ARGV   = RubyArray.new(ARGV.map { |s| RubyString.new(s).as(RubyObject) })"
        line "module Ruby_ENV"
        line "  def self.[](key : RubyObject) : RubyObject"
        line '    val = ENV[key.to_s]?'
        line "    val ? RubyString.new(val).as(RubyObject) : RUBY_NIL"
        line "  end"
        line "  def self.[]=(key : RubyObject, val : RubyObject) : RubyObject"
        line '    ENV[key.to_s] = val.to_s'
        line "    val"
        line "  end"
        line "end"
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Literals
      # -----------------------------------------------------------------------

      def cr_nil = "RUBY_NIL"
      def cr_true = "RUBY_TRUE"
      def cr_false = "RUBY_FALSE"
      def cr_integer(node) = "RubyInteger.new(#{node.value.raw}_i64)"
      def cr_float(node) = "RubyFloat.new(#{float_bits_expr(node.value.respond_to?(:raw) ? node.value.raw : node.value)})"
      def emit_nil_literal = write cr_nil
      def emit_true_literal = write cr_true
      def emit_false_literal = write cr_false
      def emit_integer_literal(node) = write cr_integer(node)
      def emit_float_literal(node) = write cr_float(node)

      # Bit-exact IEEE 754 Float64 expression for Crystal.
      # Uses unsafe_as reinterpretation so the bit pattern round-trips perfectly
      # regardless of decimal formatting precision.
      def float_bits_expr(val)
        # Common values: emit readable Crystal float literals
        return "0.0_f64" if val == 0.0 && !val.negative?  # exclude -0.0
        s = val.inspect  # Ruby's Float#inspect is round-trip safe
        # If Crystal can parse it back to the same bits, use the readable form
        if s =~ /\A-?\d+\.\d+([eE][+-]?\d+)?\z/
          "#{s}_f64"
        else
          bits = [val].pack("d").unpack1("q")
          "#{bits}_i64.unsafe_as(Float64)"
        end
      end

      def cr_string(node) = %(RubyString.new(#{crystal_string_literal(node.value.raw)}))
      def cr_symbol(node) = %(RubySymbol.from(#{node.value.to_s.inspect}))
      def cr_self = "self"
      def emit_string_literal(node) = write cr_string(node)
      def emit_symbol_literal(node) = write cr_symbol(node)
      def emit_self_literal = write cr_self

      # -----------------------------------------------------------------------
      # Variables
      # -----------------------------------------------------------------------

      def cr_local_read(node) = crystal_local(node.name)
      def emit_local_var_read(node) = write cr_local_read(node)

      def cr_local_var_write(node) = "#{crystal_local(node.name)} = #{cr(node.value_node)}"
      def emit_local_var_write(node) = write cr_local_var_write(node)

      def cr_ivar_read(node) = node.name.to_s
      def emit_ivar_read(node) = write cr_ivar_read(node)

      def cr_ivar_write(node) = "#{node.name} = #{cr(node.value_node)}"
      def emit_ivar_write(node) = write cr_ivar_write(node)

      def cr_constant_read(node) = RUBY_TO_CRYSTAL_TYPE[node.name] || "Ruby_#{crystal_constant(node.name)}"
      def emit_constant_read(node) = write cr_constant_read(node)

      def cr_constant_path(node)
        parent = node.parent_node
        name = node.name
        if parent.is_a?(Ast::ConstantRead) && parent.name == :Math
          case name
          when :PI then "RubyFloat.new(Math::PI)"
          when :E  then "RubyFloat.new(Math::E)"
          else "RubyMath.#{crystal_method_name(name)}"
          end
        else
          "#{cr(parent)}::Ruby_#{crystal_constant(name)}"
        end
      end

      def cr_constant_write(node) = "Ruby_#{crystal_constant(node.name)} = #{cr(node.value_node)}"
      def emit_constant_path(node) = write cr_constant_path(node)
      def emit_constant_write(node) = write cr_constant_write(node)

      def cr_class_var_read(node) = node.name.to_s
      def emit_class_var_read(node) = write cr_class_var_read(node)

      def cr_class_var_write(node) = "#{node.name} = #{cr(node.value_node)}"
      def emit_class_var_write(node) = write cr_class_var_write(node)

      # -----------------------------------------------------------------------
      # Sequence
      # -----------------------------------------------------------------------

      def cr_sequence_lines(node) = node.nodes.flat_map { |child| cr_lines(child) }

      def emit_sequence(node)
        cr_sequence_lines(node).each_with_index do |line, i|
          emit_newline if i > 0; emit_indent; write line
        end
      end

      # -----------------------------------------------------------------------
      # Method call
      # -----------------------------------------------------------------------

      # Functional method call emission. Returns String. Subclasses (Codegen)
      # override this to add optimized paths via cr_method_call_optimized.
      def cr_method_call(node)
        name = node.name
        recv = node.receiver_node

        # Kernel methods (no receiver)
        if recv.nil?
          case name
          when :puts then return cr_puts(node)
          when :print then return cr_print(node)
          when :p then return cr_p(node)
          when :raise then return cr_raise(node)
          when :require, :require_relative then return cr_require_call(node)
          when :block_given? then return "block_given?"
          when :loop then return cr_loop(node)
          when :attr_accessor then return cr_attr_methods(node, reader: true, writer: true)
          when :attr_reader then return cr_attr_methods(node, reader: true, writer: false)
          when :attr_writer then return cr_attr_methods(node, reader: false, writer: true)
          when :include, :extend, :prepend
            mods = node.arg_nodes.map { |a|
              a.is_a?(Ast::ConstantRead) ? (RUBY_TO_CRYSTAL_TYPE[a.name] || "Ruby_#{a.name}") : nil
            }.compact
            return mods.map { |m| "include #{m}" }.join("\n") if name == :include && !mods.empty?
            return "# #{name} #{node.arg_nodes.map { |a| a.is_a?(Ast::ConstantRead) ? a.name : '?' }.join(', ')}"
          end
        end

        # Operators
        return cr_operator(node, name) if recv && operator?(name)

        # Built-in class .new
        if name == :new && recv.is_a?(Ast::ConstantRead)
          if (cr_type = RUBY_TO_CRYSTAL_TYPE[recv.name])
            return "#{cr_type}.new#{cr_call_args(node)}"
          end
          if recv.name == :Proc && node.block_node
            return cr_proc_new(node.block_node)
          end
        end

        # lambda { } and proc { }
        return cr_proc_new(node.block_node) if name == :lambda && recv.nil? && node.block_node
        return cr_proc_call(node) if name == :call && recv

        # [] subscript
        if name == :[] && recv && node.arg_nodes.size == 1
          return "#{cr(recv)}[#{cr(node.arg_nodes[0])}]"
        end

        # is_a? / kind_of? with constant
        if (name == :is_a? || name == :kind_of?) && recv &&
           node.arg_nodes.size == 1 && node.arg_nodes[0].is_a?(Ast::ConstantRead)
          const_name = node.arg_nodes[0].name.to_s
          ct = RUBY_TO_CRYSTAL_TYPE[node.arg_nodes[0].name] ||
               (BUILTIN_SUPERCLASSES.include?(const_name) ? "Ruby#{const_name}" : "Ruby_#{const_name}")
          return "(#{cr(recv)}.is_a?(#{ct}) ? RUBY_TRUE : RUBY_FALSE)"
        end

        # General method call
        prefix = recv ? "#{cr(recv)}." : ""
        "#{prefix}#{crystal_method_name(name)}#{cr_call_args(node)}"
      end

      def emit_method_call(node) = write cr_method_call(node)


      BINARY_OPS = %i[+ - * / % ** == != < <= > >= <=> << >> & | ^ === =~].to_set
      UNARY_OPS  = %i[-@ +@ ~ !].to_set
      # Comparison operators that return Crystal Bool — wrap in RubyBool for consistency
      COMPARE_OPS = %i[== != < <= > >= === =~].to_set

      def operator?(name) = BINARY_OPS.include?(name) || UNARY_OPS.include?(name)

      # AttributeWrite: obj.foo = val (setter) or obj[i] = val (index assign)
      def cr_attribute_write(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes
        if name == :[]=
          "#{cr(recv)}[#{cr(args[0])}] = #{cr(args[1])}"
        else
          "#{cr(recv)}.#{name.to_s.chomp('=')} = #{cr(args[0])}"
        end
      end

      def emit_attribute_write(node) = write cr_attribute_write(node)

      def cr_operator(node, name)
        if UNARY_OPS.include?(name)
          recv = cr(node.receiver_node)
          case name
          when :"-@" then "(#{recv}.-)"
          when :"+@" then recv
          when :"~"  then "~(#{recv})"
          when :"!"  then "((#{cr_truthy(node.receiver_node)}) ? RUBY_FALSE : RUBY_TRUE)"
          end
        elsif COMPARE_OPS.include?(name)
          "((#{cr_operator_recv(node.receiver_node)} #{name} #{cr(node.arg_nodes[0])}) ? RUBY_TRUE : RUBY_FALSE)"
        else
          "(#{cr_operator_recv(node.receiver_node)} #{name} #{cr(node.arg_nodes[0])})"
        end
      end

      def emit_operator(node, name) = write cr_operator(node, name)

      # Emit operator receiver, wrapping in parens if it contains an
      # embedded assignment (so Crystal groups `(q1 = expr) != 1` correctly).
      def cr_operator_recv(recv) = recv_contains_assignment?(recv) ? "(#{cr(recv)})" : cr(recv)
      def emit_operator_recv(recv) = write cr_operator_recv(recv)

      def recv_contains_assignment?(node)
        return true if node.is_a?(Ast::LocalVariableWrite) || node.is_a?(Ast::InstanceVariableWrite)
        return true if node.is_a?(Ast::IndexOperatorWrite) || node.is_a?(Ast::AttributeWrite)
        return true if node.is_a?(Ast::CallOrWrite)
        node.is_a?(Ast::Sequence) && node.nodes.size == 1 && recv_contains_assignment?(node.nodes.first)
      end

      def cr_puts(node)
        args = node.arg_nodes
        return "STDOUT.puts; RUBY_NIL" if args.empty?
        return "STDOUT.puts(#{cr(args[0])}.to_s); RUBY_NIL" if args.length == 1
        args.map { |a| "STDOUT.puts(#{cr(a)}.to_s)" }.join("; ") + "; RUBY_NIL"
      end

      def cr_print(node)
        args = node.arg_nodes.map { |a| "#{cr(a)}.to_s" }.join(", ")
        "STDOUT.print(#{args})"
      end

      def cr_p(node)
        node.arg_nodes.map { |a| "STDOUT.puts(#{cr(a)}.inspect)" }.join("; ")
      end

      def cr_raise(node)
        args = node.arg_nodes
        body = if args.empty?
          "RuntimeError.new"
        elsif args.size == 1
          arg = args[0]
          case arg
          when Ast::StringLiteral then "RuntimeError.new(#{crystal_string_literal(arg.value.raw)})"
          when Ast::InterpolatedString then "RuntimeError.new(#{cr(arg)}.to_s)"
          when Ast::ConstantRead then "Ruby_#{crystal_constant(arg.name)}.new"
          else cr(arg)
          end
        else
          exc = args[0].is_a?(Ast::ConstantRead) ? "Ruby_#{crystal_constant(args[0].name)}" : cr(args[0])
          "#{exc}.new(#{cr(args[1])}.to_s)"
        end
        "raise #{body}"
      end

      # Imperative wrappers for backward compat
      def emit_puts(node) = write cr_puts(node)
      def emit_print(node) = write cr_print(node)
      def emit_p(node) = write cr_p(node)
      def emit_raise(node) = write cr_raise(node)

      def cr_rescue_lines(node)
        lines = ["begin", *indent(cr_lines(node.body))]
        node.rescue_clauses.each do |clause|
          var = clause.var_name
          exc = clause.exception_nodes
          header = if exc.empty?
            var ? "rescue #{crystal_local(var)} : Exception" : "rescue"
          else
            types = exc.map { |en| en.is_a?(Ast::ConstantRead) ? "Ruby_#{crystal_constant(en.name)}" : "Exception" }.join(" | ")
            var ? "rescue #{crystal_local(var)} : #{types}" : "rescue #{types}"
          end
          lines.push(header, *indent(cr_lines(clause.body)))
        end
        lines.push("else", *indent(cr_lines(node.else_node))) if node.else_node
        lines.push("ensure", *indent(cr_lines(node.ensure_node))) if node.ensure_node
        lines << "end"
      end

      def emit_rescue(node)
        cr_rescue_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_super(node)
        args = node.arg_nodes
        if node.forwarding || args.nil? || args.empty?
          "super"
        else
          suffix = @in_exception_class ? ".to_s" : ""
          "super(#{args.map { |a| "#{cr(a)}#{suffix}" }.join(', ')})"
        end
      end

      def emit_super(node) = write cr_super(node)

      def cr_require_call(node) = "# require #{node.arg_nodes[0].inspect} (dropped — closed world)"

      # attr_accessor/attr_reader/attr_writer :name, :other, ...
      def cr_attr_methods(node, reader:, writer:)
        node.arg_nodes.flat_map { |sym|
          next [] unless sym.is_a?(Ast::SymbolLiteral)
          name = sym.value.to_s
          methods = []
          methods << "def #{name} : RubyObject; @#{name}; end" if reader
          methods << "def #{name}=(val : RubyObject) : RubyObject; @#{name} = val; val; end" if writer
          methods
        }.join("\n#{'  ' * @indent}")
      end

      def cr_call_args(node)
        return "" if node.arg_nodes.empty? && node.kw_arg_nodes.empty? && node.block_node.nil?
        parts = node.arg_nodes.map { |arg|
          arg.is_a?(Ast::SplatArg) ? "# UNSUPPORTED_SPLAT(#{cr(arg.value_node)})" : cr(arg)
        }
        node.kw_arg_nodes.each do |kw_name, val_node|
          key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
          parts << "#{key}: #{cr(val_node)}"
        end
        result = "(#{parts.join(', ')})"
        if node.block_node
          blk = node.block_node.is_a?(Ast::BlockArg) ? cr_block_arg(node.block_node) : cr_block(node.block_node)
          result += " #{blk}"
        end
        result
      end

      def emit_require_call(node) = write cr_require_call(node)
      def emit_attr_methods(node, reader:, writer:) = write cr_attr_methods(node, reader: reader, writer: writer)
      def emit_call_args(node) = write cr_call_args(node)

      # -----------------------------------------------------------------------
      # Block
      # -----------------------------------------------------------------------

      def cr_block(node)
        params = (node.required_params || []) + (node.optional_params || []).map(&:first)
        params += [node.rest_param].compact
        param_str = params.empty? ? "" : "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        "{ #{param_str}#{cr(node.body)} }"
      end

      def cr_block_arg(block_arg_node)
        value_node = block_arg_node.value_node
        if value_node.is_a?(Ast::SymbolLiteral)
          "{ |_sym2proc| _sym2proc.#{crystal_method_name(value_node.value)}.as(RubyObject) }"
        else
          "{ |_blkarg| (#{cr(value_node)}).as(RubyProc).call(_blkarg) }"
        end
      end

      def emit_block(node) = write cr_block(node)
      def emit_block_arg(node) = write cr_block_arg(node)

      # -----------------------------------------------------------------------
      # Control flow
      # -----------------------------------------------------------------------

      def cr_if_lines(node)
        cond = cr_truthy(node.pred_node)
        if node.then_node.is_a?(Ast::NilLiteral) && node.else_node
          return ["unless #{cond}", *indent(cr_lines(node.else_node)), "end"]
        end
        lines = ["if #{cond}", *indent(cr_lines(node.then_node))]
        if node.else_node
          lines.push("else", *indent(cr_lines(node.else_node)))
        end
        lines << "end"
      end

      def emit_if(node)
        cr_if_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_for_loop_lines(node)
        target = node.target
        var = case target[0]
        when :local then crystal_local(target[1])
        when :multi
          _, lefts, rest_sym, rights = target
          parts = lefts.map { |n| crystal_local(n) }
          parts << "*#{crystal_local(rest_sym)}" if rest_sym
          parts += rights.map { |n| crystal_local(n) }
          parts.join(", ")
        else "_for_var"
        end
        ["#{cr(node.collection_node)}.each do |#{var}|", *indent(cr_lines(node.body_node)), "end"]
      end

      def emit_for_loop(node)
        cr_for_loop_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_while_lines(node)
        ["while #{cr_truthy(node.condition_node)}", *indent(cr_lines(node.body_node)), "end"]
      end

      def cr_until_lines(node)
        ["until #{cr_truthy(node.condition_node)}", *indent(cr_lines(node.body_node)), "end"]
      end

      def emit_while(node)
        cr_while_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def emit_until(node)
        cr_until_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_return(node) = node.value_node ? "return #{cr(node.value_node)}" : "return"

      def cr_next(node)
        val = node.value_node
        (val.nil? || val.is_a?(Ast::NilLiteral)) ? "next" : "next (#{cr(val)})"
      end

      def cr_break(node)
        val = node.value_node
        (val.nil? || val.is_a?(Ast::NilLiteral)) ? "break" : "break (#{cr(val)})"
      end

      def emit_return(node) = write cr_return(node)
      def emit_next(node) = write cr_next(node)
      def emit_break(node) = write cr_break(node)

      def cr_loop_lines(node)
        body_lines = node.block_node ? cr_lines(node.block_node.body) : []
        ["loop do", *indent(body_lines), "end"]
      end

      # cr_loop is called from cr_method_call (returns String). Loop is multi-line
      # so it needs joining with newlines and current indent.
      def cr_loop(node) = cr_loop_lines(node).join("\n#{'  ' * @indent}")

      def emit_loop(node)
        cr_loop_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_lambda(node)
        params = node.required_params
        assigns = params.each_with_index.map { |p, i| "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL" }.join("; ")
        body = cr(node.body)
        prefix = assigns.empty? ? "" : "#{assigns}; "
        "RubyProc.new(->(args : Array(RubyObject)) { #{prefix}#{body} })"
      end

      def emit_lambda(node) = write cr_lambda(node)

      def cr_proc_new(block_node)
        params = block_node.required_params
        assigns = params.each_with_index.map { |p, i| "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL" }.join("; ")
        prefix = assigns.empty? ? "" : "#{assigns}; "
        "RubyProc.new(->(args : Array(RubyObject)) { #{prefix}#{cr(block_node.body)} })"
      end

      def cr_proc_call(node)
        recv = node.receiver_node
        bp_name = (defined?(@mctx) && @mctx&.block_param_name) ||
          (defined?(@current_block_param_name) && @current_block_param_name)
        is_block_param = recv.is_a?(Ast::LocalVariableRead) && bp_name && recv.name == bp_name
        cast = is_block_param ? "" : ".as(RubyProc)"
        args = node.arg_nodes.map { |a| cr(a) }.join(", ")
        "(#{cr(recv)})#{cast}.call(#{args})"
      end

      def emit_proc_new(block_node) = write cr_proc_new(block_node)
      def emit_proc_call(node) = write cr_proc_call(node)

      # Global variable read: $name → RUBY_GLOBALS["name"]? || RUBY_NIL
      MAPPED_GLOBALS = {
        :"$stdout" => "RUBY_NIL",  # TODO: IO wrapper
        :"$stderr" => "RUBY_NIL",
        :"$stdin"  => "RUBY_NIL",
      }.freeze

      def cr_global_var_read(node)
        mapped = MAPPED_GLOBALS[node.name]
        mapped || %((RUBY_GLOBALS[#{node.name.to_s.sub(/^\$/, '').inspect}]? || RUBY_NIL))
      end

      def emit_global_var_read(node) = write cr_global_var_read(node)

      def cr_global_var_write(node)
        key = node.name.to_s.sub(/^\$/, '')
        %(RUBY_GLOBALS[#{key.inspect}] = #{cr(node.value_node)})
      end

      def emit_global_var_write(node) = write cr_global_var_write(node)

      def cr_index_or_write(node)
        r, i, c = "_iorw_r#{@temp_counter}", "_iorw_i#{@temp_counter}", "_iorw_c#{@temp_counter}"
        @temp_counter += 1
        recv = node.receiver_node ? cr(node.receiver_node) : "self"
        idx = cr(node.index_arg_nodes[0])
        val = cr(node.value_node)
        "(#{r} = #{recv}; #{i} = #{idx}; #{c} = #{r}[#{i}]; #{c}.truthy? ? #{c} : (#{r}[#{i}] = #{val}))"
      end

      def cr_index_and_write(node)
        r, i, c = "_iandw_r#{@temp_counter}", "_iandw_i#{@temp_counter}", "_iandw_c#{@temp_counter}"
        @temp_counter += 1
        recv = node.receiver_node ? cr(node.receiver_node) : "self"
        idx = cr(node.index_arg_nodes[0])
        val = cr(node.value_node)
        "(#{r} = #{recv}; #{i} = #{idx}; #{c} = #{r}[#{i}]; #{c}.truthy? ? (#{r}[#{i}] = #{val}) : #{c})"
      end

      def emit_index_or_write(node) = write cr_index_or_write(node)
      def emit_index_and_write(node) = write cr_index_and_write(node)

      # a[i] += val → (_r = recv; _i = idx; _r[_i] = _r[_i] op val)
      def cr_index_op_write(node)
        r, i = "_iopw_r#{@temp_counter}", "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        recv = node.receiver_node ? cr(node.receiver_node) : "self"
        idx = cr(node.index_arg_nodes[0])
        val = cr(node.value_node)
        "(#{r} = #{recv}; #{i} = #{idx}; #{r}[#{i}] = (#{r}[#{i}] #{node.operator} #{val}))"
      end

      def cr_yield(node)
        args = node.arg_nodes
        args.empty? ? "yield" : "yield #{args.map { |a| "(#{cr(a)})" }.join(', ')}"
      end

      def emit_index_op_write(node) = write cr_index_op_write(node)
      def emit_yield(node) = write cr_yield(node)

      # -----------------------------------------------------------------------
      # Boolean operators
      # -----------------------------------------------------------------------

      # emit_and/emit_or return RubyObject (not Bool) so they work in value
      # contexts like `x = a && b` or `x ||= val`. emit_truthy adds .truthy?
      # when the result is used as a Crystal condition.
      def cr_and(node)
        tmp = "_and#{@temp_counter}"; @temp_counter += 1
        "(#{tmp} = #{cr(node.left_node)}; #{tmp}.truthy? ? (#{cr(node.right_node)}) : #{tmp})"
      end

      def cr_or(node)
        tmp = "_or#{@temp_counter}"; @temp_counter += 1
        "(#{tmp} = #{cr(node.left_node)}; #{tmp}.truthy? ? #{tmp} : (#{cr(node.right_node)}))"
      end

      def emit_and(node) = write cr_and(node)
      def emit_or(node) = write cr_or(node)

      # Wrap a value in a Crystal truthy check when used as a condition.
      # If the node is already a comparison/predicate that returns Bool, emit
      # it directly; otherwise wrap in .truthy?
      def cr_truthy(node)
        case node
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral, Ast::NilLiteral then "false"
        else
          if boolean_valued?(node)
            cr(node)
          elsif comparison_op_call?(node)
            "(#{cr_operator_recv(node.receiver_node)} #{node.name} #{cr(node.arg_nodes[0])})"
          else
            "#{cr(node)}.truthy?"
          end
        end
      end

      def emit_truthy(node) = write cr_truthy(node)

      # Methods that return Crystal Bool directly (not RubyObject).
      # Use the Crystal name (after RUBY_TO_CRYSTAL_METHOD mapping).
      BOOL_METHODS = %i[ruby_nil? empty? frozen? zero? positive? negative?
                        truthy? ruby_bool?
                        is_a? kind_of? instance_of? equal?].to_set

      # Heuristic: is this node likely to return a Crystal Bool directly?
      def boolean_valued?(node)
        case node
        when Ast::TrueLiteral, Ast::FalseLiteral then true
        when Ast::MethodCall
          crystal_name = RUBY_TO_CRYSTAL_METHOD.fetch(node.name, node.name)
          BOOL_METHODS.include?(crystal_name)
        else false
        end
      end

      # Is this a binary comparison operator call (receiver op arg)?
      def comparison_op_call?(node)
        node.is_a?(Ast::MethodCall) &&
          COMPARE_OPS.include?(node.name) &&
          node.receiver_node &&
          node.arg_nodes&.size == 1
      end

      # -----------------------------------------------------------------------
      # Case / when
      # -----------------------------------------------------------------------

      # Map Ruby core class names to Crystal type names for case/when type checks.
      RUBY_TO_CRYSTAL_TYPE = {
        Object:   'RubyGenericObject',
        Integer:  'RubyInteger',
        Float:    'RubyFloat',
        String:   'RubyString',
        Symbol:   'RubySymbol',
        Array:    'RubyArray',
        Hash:     'RubyHash',
        NilClass: 'RubyNil',
        Numeric:  'RubyObject',
        Struct:   'RubyObject',
        Math:     'RubyMath',
        Random:   'Ruby_Random',
      }.freeze

      # Returns true if a `when` condition node is a type-check (ConstantRead or nil).
      def type_check_cond?(cond) = cond.is_a?(Ast::NilLiteral) || cond.is_a?(Ast::ConstantRead)

      def cr_case_lines(node)
        subject = node.subject_node
        whens = node.whens
        else_n = node.else_node
        no_subject = subject.nil? || subject.is_a?(Ast::NilLiteral)
        is_local = !no_subject && subject.is_a?(Ast::LocalVariableRead)
        all_type = !no_subject && whens.all? { |w| w.condition_nodes.all? { |c| type_check_cond?(c) } }

        if is_local && all_type
          cr_case_native_lines(crystal_local(subject.name), whens, else_n)
        else
          lines = no_subject ? [] : ["_case_subj = #{cr(subject)}"]
          lines + cr_case_if_chain_lines(no_subject ? nil : "_case_subj", whens, else_n)
        end
      end

      def cr_case_native_lines(subj_name, whens, else_n)
        lines = ["case #{subj_name}"]
        whens.each do |w|
          types = w.condition_nodes.map { |c|
            c.is_a?(Ast::NilLiteral) ? "RubyNil" : (RUBY_TO_CRYSTAL_TYPE[c.name] || "Ruby_#{crystal_constant(c.name)}")
          }.join(", ")
          lines.push("when #{types}", *indent(cr_lines(w.body_node)))
        end
        lines.push("else", *indent(cr_lines(else_n))) if else_n
        lines << "end"
      end

      def cr_case_if_chain_lines(subj_var, whens, else_n)
        lines = []
        whens.each_with_index do |w, idx|
          keyword = idx == 0 ? "if " : "elsif "
          conds = w.condition_nodes.map { |c| subj_var ? cr_case_match(c, subj_var) : cr_truthy(c) }.join(" || ")
          lines.push("#{keyword}#{conds}", *indent(cr_lines(w.body_node)))
        end
        lines.push("else", *indent(cr_lines(else_n))) if else_n
        lines << "end"
      end

      def cr_case_match(cond_node, subj_var)
        case cond_node
        when Ast::NilLiteral then "#{subj_var}.ruby_nil?"
        when Ast::TrueLiteral then "#{subj_var}.truthy? && !#{subj_var}.ruby_nil?"
        when Ast::FalseLiteral then "!#{subj_var}.truthy?"
        when Ast::ConstantRead
          ct = RUBY_TO_CRYSTAL_TYPE[cond_node.name] || "Ruby_#{crystal_constant(cond_node.name)}"
          "#{subj_var}.is_a?(#{ct})"
        else "(#{cr(cond_node)}) == #{subj_var}"
        end
      end

      def emit_case(node)
        cr_case_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      # -----------------------------------------------------------------------
      # Collections
      # -----------------------------------------------------------------------

      def cr_array_literal(node)
        elems = node.element_nodes.map { |el| cr(el) }.join(", ")
        "RubyArray.new([#{elems}] of RubyObject)"
      end

      def cr_hash_literal(node)
        pairs = node.kv_nodes
        return "RubyHash.new" if pairs.empty?
        stores = pairs.map { |k, v| "_h.store(#{cr(k)}, #{cr(v)})" }.join("; ")
        "RubyHash.new.tap { |_h| #{stores} }"
      end

      def cr_range_literal(node)
        b = node.begin_node ? cr(node.begin_node) : "RUBY_NIL"
        e = node.end_node ? cr(node.end_node) : "RUBY_NIL"
        "RubyRange.new(#{b}, #{e}, #{node.exclusive})"
      end

      def emit_array_literal(node) = write cr_array_literal(node)
      def emit_hash_literal(node) = write cr_hash_literal(node)
      def emit_range_literal(node) = write cr_range_literal(node)

      def cr_multiple_assignment_lines(node)
        targets = node.targets
        tmp = "_ma#{@temp_counter}"; @temp_counter += 1
        lines = ["#{tmp} = masgn_coerce(#{cr(node.value_node)})"]
        splat_idx = targets.index { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if splat_idx
          pre = targets[0...splat_idx]
          post = targets[(splat_idx + 1)..]
          pre.each_with_index { |t, i| lines << cr_masgn_assign(t, "#{tmp}[#{i}_i64]") }
          splat_t = targets[splat_idx]
          unless splat_t[0] == :splat_nil
            lines << cr_masgn_assign(splat_t, "RubyArray.new(#{tmp}.data[#{pre.length}...(#{tmp}.data.size - #{post.length})])")
          end
          post.each_with_index { |t, i| lines << cr_masgn_assign(t, "#{tmp}[(-#{post.length - i})_i64]") }
        else
          targets.each_with_index { |t, i| lines << cr_masgn_assign(t, "#{tmp}[#{i}_i64]") }
        end
        lines.compact
      end

      def emit_multiple_assignment(node)
        cr_multiple_assignment_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_masgn_assign(target, value_code)
        case target[0]
        when :local, :local_splat then "#{crystal_local(target[1])} = #{value_code}"
        when :ivar, :ivar_splat then "#{target[1]} = #{value_code}"
        when :const, :const_splat then "Ruby_#{crystal_constant(target[1])} = #{value_code}"
        when :index, :index_splat
          "#{cr(target[1])}[#{target[2].map { |idx| cr(idx) }.join(', ')}] = #{value_code}"
        when :call, :call_splat
          "#{cr(target[1])}.#{crystal_method_name(target[2])} = #{value_code}"
        when :splat_nil then nil
        else "# UNSUPPORTED masgn target: #{target[0]}"
        end
      end

      def cr_interpolated_string(node)
        parts = node.parts.map { |part|
          case part
          when Ast::StringLiteral then "_s << #{crystal_string_literal(part.value.raw)}"
          else "_s << (#{cr(part)}).to_s"
          end
        }
        "RubyString.new(String.build { |_s| #{parts.join('; ')} })"
      end

      def emit_interpolated_string(node) = write cr_interpolated_string(node)

      # -----------------------------------------------------------------------
      # Method definition
      # -----------------------------------------------------------------------

      # Methods that must return Crystal String (override RubyObject abstract defs)
      STRING_RETURN_METHODS = %i[to_s inspect].to_set

      def cr_method_def_lines(node)
        recv = node.receiver_node
        name = node.name
        string_return = STRING_RETURN_METHODS.include?(name)
        crystal_name = string_return ? name.to_s : crystal_method_name(name)
        sig = recv ? "def #{cr(recv)}.#{crystal_name}" : "def #{crystal_name}"
        sig += " : String" if string_return
        sig += cr_param_list(node)
        body = if string_return
          ["(begin", *indent(cr_lines(node.body)), "end).to_s"]
        else
          cr_lines(node.body)
        end
        [sig, *indent(body), "end"]
      end

      def emit_method_def(node)
        cr_method_def_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      def cr_param_list(node)
        parts = []
        node.required_params.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        node.optional_params.each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        rp = node.rest_param
        parts << "*#{crystal_local(rp)} : RubyObject" if rp
        node.post_params.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        req_kw = node.required_kw_params || []
        opt_kw = node.optional_kw_params || []
        kr = node.kw_rest_param
        parts << "*" if (!req_kw.empty? || !opt_kw.empty?) && !rp
        req_kw.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        opt_kw.each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        parts << "**#{crystal_local(kr)}" if kr
        bp = node.block_param
        parts << "&#{crystal_local(bp)}" if bp
        parts.empty? ? "" : "(#{parts.join(', ')})"
      end

      def emit_param_list(node) = write cr_param_list(node)

      # -----------------------------------------------------------------------
      # Class / module definitions
      # -----------------------------------------------------------------------

      def cr_class_def_lines(node)
        name = crystal_constant(node.name)
        is_exc = @exception_classes.include?(node.name)
        sc = node.superclass_node
        parent = if is_exc
          (sc && !EXCEPTION_BASE_NAMES.include?(sc.name.to_s)) ? "Ruby_#{crystal_constant(sc.name)}" : "RubyException"
        elsif sc then "Ruby_#{crystal_constant(sc.name)}"
        else "RubyObject"
        end
        header = "class Ruby_#{name} < #{parent}"

        prev_exc = @in_exception_class
        @in_exception_class = is_exc
        preamble = cr_class_preamble(name, node, is_exc, sc)
        body = node.body
        body_lines = body.is_a?(Ast::NilLiteral) ? [] : cr_lines(body)
        @in_exception_class = prev_exc

        [header, *indent(preamble + body_lines), "end"]
      end

      def cr_class_preamble(name, node, is_exc, sc)
        lines = []
        ivars = collect_ivars(node.body)
        if is_exc
          ivars.each { |iv| lines << "#{iv} : RubyObject = RUBY_NIL" }
          lines << "" unless ivars.empty?
          lines << "def initialize(msg : String = \"#{name}\"); super(msg); end" unless has_initialize?(node.body)
        else
          cvars = collect_cvars(node.body)
          ivars.each { |iv| lines << "#{iv} : RubyObject = RUBY_NIL" }
          cvars.each { |cv| lines << "#{cv} : RubyObject = RUBY_NIL" }
          lines << "" unless ivars.empty? && cvars.empty?
          sc_name = sc.is_a?(Ast::ConstantRead) ? sc.name.to_s : nil
          unless sc_name && !BUILTIN_SUPERCLASSES.include?(sc_name)
            lines.push(
              "def to_s : String; \"#<#{name}>\"; end",
              "def inspect : String; \"#<#{name}>\"; end",
              "def ==(other : RubyObject) : Bool; same?(other); end",
              ""
            )
          end
        end
        lines
      end

      def emit_class_def(node)
        cr_class_def_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      # Returns true if the class body contains an explicit `initialize` method.
      def has_initialize?(body)
        return false unless body
        case body
        when Ast::Sequence
          body.nodes.any? { |n| n.is_a?(Ast::MethodDef) && n.name == :initialize }
        when Ast::MethodDef
          body.name == :initialize
        else false
        end
      end

      def cr_module_def_lines(node)
        body = node.body
        body_lines = body.is_a?(Ast::NilLiteral) ? [] : cr_lines(body)
        ["module Ruby_#{crystal_constant(node.name)}", *indent(body_lines), "end"]
      end

      def emit_module_def(node)
        cr_module_def_lines(node).each_with_index { |l, i| emit_newline if i > 0; emit_indent if i > 0; write l }
      end

      # -----------------------------------------------------------------------
      # Output helpers
      # -----------------------------------------------------------------------

      def write(*strs) = strs.each { |s| @out << s }
      def line(str) = @out << ("  " * @indent) << str << "\n"
      def emit_indent = @out << ("  " * @indent)
      def emit_newline = @out << "\n"

      def capture
        saved = @out
        @out = +""
        yield
        @out
      ensure
        @out = saved
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

      # Crystal built-in methods that shadow local variables of the same name.
      CRYSTAL_BUILTIN_METHODS = %w[p pp].to_set

      # Ruby method names that map to different Crystal method names at CALL sites.
      # (Crystal's to_s/inspect return String; Ruby's return RubyString)
      RUBY_TO_CRYSTAL_METHOD = {
        nil?:    :ruby_nil?,
        to_s:    :ruby_to_s,
        inspect: :ruby_inspect,
      }.freeze

      def crystal_constant(sym_or_str) = sym_or_str.to_s
      # Escape a Ruby string value (a native Ruby String) for use as a Crystal
      # string literal.
      def crystal_string_literal(str) = str.inspect

      def crystal_method_name(sym)
        return RUBY_TO_CRYSTAL_METHOD[sym].to_s if RUBY_TO_CRYSTAL_METHOD.key?(sym)
        s = sym.to_s
        CRYSTAL_KEYWORDS.include?(s) ? "ruby_#{s}" : s
      end

      def crystal_local(sym)
        s = sym.to_s
        (CRYSTAL_KEYWORDS.include?(s) || CRYSTAL_BUILTIN_METHODS.include?(s)) ? "loc_#{s}" : s
      end

      # -----------------------------------------------------------------------
      # Inline codegen for default parameter values
      # -----------------------------------------------------------------------

      def codegen_inline(node)
        sub = CrystalEmitter.new
        sub.instance_variable_set(:@indent, 0)
        sub.send(:emit, node)
        sub.instance_variable_get(:@out)
      end

      # -----------------------------------------------------------------------
      # Ivar collection — scan a class body AST for all @ivar assignments
      # -----------------------------------------------------------------------

      def collect_cvars(node, seen = Set.new)
        case node
        when Ast::ClassVariableWrite
          seen << node.name.to_s
          collect_cvars(node.value_node, seen)
        when Ast::ClassVariableRead
          seen << node.name.to_s
        when Ast::Sequence
          node.nodes.each { |n| collect_cvars(n, seen) }
        when Ast::MethodDef
          collect_cvars(node.body, seen) if node.body
        when Ast::If
          collect_cvars(node.then_node, seen)
          collect_cvars(node.else_node, seen) if node.else_node
        when nil
          # nothing
        else
          %i[body value_node then_node else_node body_node].each do |slot|
            child = node.instance_variable_defined?(:"@#{slot}") && node.instance_variable_get(:"@#{slot}")
            collect_cvars(child, seen) if child && child.is_a?(Ast::Node)
          end
        end
        seen.to_a.sort
      end

      ATTR_METHODS = %i[attr_accessor attr_reader attr_writer].to_set

      def collect_ivars(node, seen = Set.new)
        case node
        when Ast::InstanceVariableWrite
          seen << node.name.to_s
          collect_ivars(node.value_node, seen)
        when Ast::Sequence
          node.nodes.each { |n| collect_ivars(n, seen) }
        when Ast::MethodDef
          collect_ivars(node.body, seen) if node.body
        when Ast::MethodCall
          # attr_accessor/reader/writer declare implicit ivars
          if ATTR_METHODS.include?(node.name)
            node.arg_nodes.each do |a|
              seen << "@#{a.value}" if a.is_a?(Ast::SymbolLiteral)
            end
          end
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

      # REMOVED: def ivar(node, name) — replaced by direct attr_reader accessors

      # -----------------------------------------------------------------------
      # Error handling
      # -----------------------------------------------------------------------

      def unsupported!(node, msg = nil)
        name = node.class.name.split('::').last
        message = msg ? "#{name}: #{msg}" : name
        @errors << message
        write "RUBY_NIL # UNSUPPORTED: #{message}"
      end
    end
  end
end

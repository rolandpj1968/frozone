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
      attr_reader :out
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
        @literal_symbols = {}       # {Symbol => Int} — index per unique literal :foo for static constants
      end

      # Generate a complete Crystal source file from the top-level AST node.
      # Returns the Crystal source as a String.
      def generate(node)
        # Multi-pass: collect user-defined method names + literal symbol
        # values from the whole AST before emitting, so the header can
        # declare every Ruby_Sym_<i> constant once and call sites just
        # reference them (skipping the runtime hash lookup in
        # RubySymbol.from).
        collect_user_methods(node)
        collect_symbol_literals(node)
        emit_header
        emit_literal_symbols unless @literal_symbols.empty?
        emit_user_method_stubs unless @user_methods.empty?
        emit(node)
        emit_newline
        @out
      end

      # Walk the entire AST collecting every unique :foo literal value
      # into @literal_symbols. The index becomes the constant suffix.
      def collect_symbol_literals(node)
        return unless node.is_a?(Ast::Node)
        if node.is_a?(Ast::SymbolLiteral)
          @literal_symbols[node.value] ||= @literal_symbols.size
        end
        node.children.each { |c| collect_symbol_literals(c) }
      end

      # Emit one `Ruby_Sym_<i> = RubySymbol.from("name")` constant per
      # unique literal symbol. Constants are evaluated once at module
      # load time, so subsequent uses are a single static load.
      def emit_literal_symbols
        @literal_symbols.each do |sym, idx|
          line "Ruby_Sym_#{idx} = RubySymbol.from(#{sym.to_s.inspect})"
        end
        emit_newline
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

      # Functional dispatch entry point — returns Crystal source as a String.
      # Migration window: leaves with no subclass override go through direct
      # cr_* dispatch for every supported AST node — emit_node is gone.
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
        when Ast::ConstantRead       then cr_constant_read(node)
        when Ast::ConstantPath       then cr_constant_path(node)
        when Ast::ConstantWrite      then cr_constant_write(node)
        when Ast::InstanceVariableRead then cr_ivar_read(node)
        when Ast::ClassVariableRead  then cr_class_var_read(node)
        when Ast::ClassVariableWrite then cr_class_var_write(node)
        when Ast::GlobalVariableWrite then cr_global_var_write(node)
        when Ast::IndexOrWrite       then cr_index_or_write(node)
        when Ast::IndexAndWrite      then cr_index_and_write(node)
        when Ast::Yield              then cr_yield(node)
        when Ast::And                then cr_and(node)
        when Ast::Or                 then cr_or(node)
        when Ast::ArrayLiteral       then cr_array_literal(node)
        when Ast::LocalVariableWrite then cr_local_write(node)
        when Ast::InstanceVariableWrite then cr_ivar_write(node)
        when Ast::AttributeWrite     then cr_attribute_write(node)
        when Ast::IndexOperatorWrite then cr_index_op_write(node)
        when Ast::MultipleAssignment then cr_multiple_assignment(node)
        when Ast::MethodCall         then cr_method_call(node)
        when Ast::If                 then cr_if(node)
        when Ast::While              then cr_while(node)
        when Ast::Until              then cr_until(node)
        when Ast::ForLoop            then cr_for_loop(node)
        when Ast::Sequence           then "#{'  ' * @indent}#{cr_sequence(node)}"
        when Ast::Super              then cr_super(node)
        when Ast::Lambda             then cr_lambda(node)
        when Ast::Rescue             then cr_rescue(node)
        when Ast::Case               then cr_case(node)
        when Ast::MethodDef          then cr_method_def(node)
        when Ast::ClassDef           then cr_class_def(node)
        when Ast::ModuleDef          then cr_module_def(node)
        when Ast::RangeLiteral       then cr_range_literal(node)
        when Ast::HashLiteral        then cr_hash_literal(node)
        when Ast::InterpolatedString then cr_interpolated_string(node)
        when Ast::Return             then cr_return(node)
        when Ast::Next               then cr_next(node)
        when Ast::Break              then cr_break(node)
        when Ast::GlobalVariableRead then cr_global_var_read(node)
        when Ast::Retry              then "retry"
        when Ast::Block              then unsupported!(node, "bare Block outside method call")
        else                              unsupported!(node)
        end
      end

      def emit(node) = write cr(node)

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
      def cr_symbol(node)
        idx = @literal_symbols[node.value] ||= @literal_symbols.size
        "Ruby_Sym_#{idx}"
      end
      def cr_self = "self"

      # -----------------------------------------------------------------------
      # Variables
      # -----------------------------------------------------------------------

      def cr_local_read(node) = crystal_local(node.name)

      def cr_local_write(node) = "#{crystal_local(node.name)} = #{cr(node.value_node)}"

      def cr_ivar_read(node) = node.name.to_s

      def cr_ivar_write(node) = "#{node.name} = #{cr(node.value_node)}"

      def cr_constant_read(node) = RUBY_TO_CRYSTAL_TYPE[node.name] || "Ruby_#{crystal_constant(node.name)}"

      def cr_constant_path(node)
        parent = node.parent_node
        name = node.name
        # Special cases: Math::PI, Math::E → Crystal constants
        if parent.is_a?(Ast::ConstantRead) && parent.name == :Math
          case name
          when :PI then "RubyFloat.new(Math::PI)"
          when :E  then "RubyFloat.new(Math::E)"
          else "RubyMath.#{crystal_method_name(name)}"
          end
        elsif parent.is_a?(Ast::ConstantRead) && parent.name == :Encoding
          # Encoding::UTF_8, Encoding::BINARY, etc → Ruby_Encoding_<NAME>
          # singletons defined in crystal/src/ruby_encoding_object.cr.
          # The runtime interns one RubyEncodingObject per canonical
          # RubyEncoding enum member, so identity comparison still works.
          "Ruby_Encoding_#{crystal_constant(name)}"
        else
          "#{cr(parent)}::Ruby_#{crystal_constant(name)}"
        end
      end

      def cr_constant_write(node) = "Ruby_#{crystal_constant(node.name)} = #{cr(node.value_node)}"

      def cr_class_var_read(node) = node.name.to_s

      def cr_class_var_write(node) = "#{node.name} = #{cr(node.value_node)}"

      # -----------------------------------------------------------------------
      # Sequence
      # -----------------------------------------------------------------------

      def cr_sequence(node)
        indent_str = "  " * @indent
        node.nodes.map { |child| cr(child) }.join("\n#{indent_str}")
      end

      # -----------------------------------------------------------------------
      # Method call
      # -----------------------------------------------------------------------

      def cr_method_call(node)
        name = node.name

        # Kernel-level methods with no receiver map to top-level helpers
        if node.receiver_node.nil?
          case name
          when :puts         then return cr_puts(node)
          when :print        then return cr_print(node)
          when :p            then return cr_p(node)
          when :raise        then return cr_raise(node)
          when :require, :require_relative then return cr_require_call(node)
          when :block_given? then return "block_given?"
          when :loop         then return cr_loop_call(node)
          when :attr_accessor then return cr_attr_methods(node, reader: true, writer: true)
          when :attr_reader   then return cr_attr_methods(node, reader: true, writer: false)
          when :attr_writer   then return cr_attr_methods(node, reader: false, writer: true)
          when :include, :extend, :prepend
            mods = node.arg_nodes.filter_map do |a|
              if a.is_a?(Ast::ConstantRead)
                RUBY_TO_CRYSTAL_TYPE[a.name] || "Ruby_#{a.name}"
              end
            end
            indent_str = "  " * @indent
            return mods.map { |m| "include #{m}" }.join("\n#{indent_str}") if name == :include && !mods.empty?
            return "# #{name} #{node.arg_nodes.map { |a| a.is_a?(Ast::ConstantRead) ? a.name : '?' }.join(', ')}"
          end
        end

        # Operator and unary methods → Crystal operator syntax
        return cr_operator(node, name) if node.receiver_node && operator?(name)

        # Built-in class .new: Array.new(n, default), Hash.new, etc.
        if name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
          cr_type = RUBY_TO_CRYSTAL_TYPE[node.receiver_node.name]
          return "#{cr_type}.new#{cr_call_args(node)}" if cr_type
        end

        # Proc.new { |...| ... } → RubyProc wrapping a Crystal proc
        if name == :new && node.receiver_node.is_a?(Ast::ConstantRead) &&
           node.receiver_node.name == :Proc && node.block_node
          return cr_proc_new(node.block_node)
        end

        # lambda { |...| ... } (no receiver) → same as Proc.new
        return cr_proc_new(node.block_node) if name == :lambda && node.receiver_node.nil? && node.block_node

        # proc.call(args) → cast receiver to RubyProc then call
        return cr_proc_call(node) if name == :call && node.receiver_node

        # [] subscript: emit receiver[arg] instead of receiver.[](arg)
        if name == :[] && node.receiver_node && node.arg_nodes.size == 1
          return "#{cr(node.receiver_node)}[#{cr(node.arg_nodes[0])}]"
        end

        # is_a?/kind_of? with a constant → Crystal native is_a?(Type) → RubyBool
        if (name == :is_a? || name == :kind_of?) && node.receiver_node &&
           node.arg_nodes.size == 1 && node.arg_nodes[0].is_a?(Ast::ConstantRead)
          const_name = node.arg_nodes[0].name.to_s
          crystal_type = RUBY_TO_CRYSTAL_TYPE[node.arg_nodes[0].name] ||
                         (BUILTIN_SUPERCLASSES.include?(const_name) ? "Ruby#{const_name}" : "Ruby_#{const_name}")
          return "(#{cr(node.receiver_node)}.is_a?(#{crystal_type}) ? RUBY_TRUE : RUBY_FALSE)"
        end

        # General method call: receiver.method(args)
        recv_str = node.receiver_node ? "#{cr(node.receiver_node)}." : ""
        "#{recv_str}#{crystal_method_name(name)}#{cr_call_args(node)}"
      end

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

      def cr_operator(node, name)
        if UNARY_OPS.include?(name)
          case name
          when :"-@" then "(#{cr(node.receiver_node)}.-)"
          when :"+@" then cr(node.receiver_node)
          when :"~"  then "~(#{cr(node.receiver_node)})"
          when :"!"  then "((#{cr_truthy(node.receiver_node)}) ? RUBY_FALSE : RUBY_TRUE)"
          end
        elsif COMPARE_OPS.include?(name)
          "((#{cr_operator_recv(node.receiver_node)} #{name} #{cr(node.arg_nodes[0])}) ? RUBY_TRUE : RUBY_FALSE)"
        else
          "(#{cr_operator_recv(node.receiver_node)} #{name} #{cr(node.arg_nodes[0])})"
        end
      end

      # Operator receiver, wrapped in parens if it contains an embedded
      # assignment (so Crystal groups `(q1 = expr) != 1` correctly).
      def cr_operator_recv(recv) = recv_contains_assignment?(recv) ? "(#{cr(recv)})" : cr(recv)

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
        "#{args.map { |a| "STDOUT.puts(#{cr(a)}.to_s); " }.join}RUBY_NIL"
      end

      def cr_print(node) = "STDOUT.print(#{node.arg_nodes.map { |a| "#{cr(a)}.to_s" }.join(', ')})"

      def cr_p(node) = node.arg_nodes.map { |a| "STDOUT.puts(#{cr(a)}.inspect)" }.join("; ")

      def cr_raise(node)
        args = node.arg_nodes
        return "raise RuntimeError.new" if args.empty?
        if args.size == 1
          arg = args[0]
          body = case arg
                 when Ast::StringLiteral then "RuntimeError.new(#{crystal_string_literal(arg.value.raw)})"
                 when Ast::InterpolatedString then "RuntimeError.new(#{cr(arg)}.to_s)"
                 when Ast::ConstantRead then "Ruby_#{crystal_constant(arg.name)}.new"
                 else cr(arg)
                 end
          return "raise #{body}"
        end
        # args.size >= 2 — raise ExcClass, "msg"
        exc_node = args[0]
        msg_node = args[1]
        ctor = exc_node.is_a?(Ast::ConstantRead) ? "Ruby_#{crystal_constant(exc_node.name)}.new" : "#{cr(exc_node)}.new"
        "raise #{ctor}(#{cr(msg_node)}.to_s)"
      end

      def cr_rescue(node)
        indent_str = "  " * @indent
        body = nil
        indented { body = cr(node.body) }
        parts = ["begin", body]
        node.rescue_clauses.each do |clause|
          var = clause.var_name
          excs = clause.exception_nodes
          header = if excs.empty?
                     var ? "rescue #{crystal_local(var)} : Exception" : "rescue"
                   else
                     types = excs.map { |en| en.is_a?(Ast::ConstantRead) ? "Ruby_#{crystal_constant(en.name)}" : "Exception" }.join(" | ")
                     var ? "rescue #{crystal_local(var)} : #{types}" : "rescue #{types}"
                   end
          parts << "#{indent_str}#{header}"
          clause_body = nil
          indented { clause_body = cr(clause.body) }
          parts << clause_body
        end
        if (else_n = node.else_node)
          parts << "#{indent_str}else"
          else_body = nil
          indented { else_body = cr(else_n) }
          parts << else_body
        end
        if (ensure_n = node.ensure_node)
          parts << "#{indent_str}ensure"
          ensure_body = nil
          indented { ensure_body = cr(ensure_n) }
          parts << ensure_body
        end
        parts << "#{indent_str}end"
        parts.join("\n")
      end

      def cr_super(node)
        args = node.arg_nodes
        return "super" if node.forwarding || args.nil? || args.empty?
        suffix = @in_exception_class ? ".to_s" : ""
        "super(#{args.map { |a| "#{cr(a)}#{suffix}" }.join(', ')})"
      end

      # Silently drop require calls — closed world, all files already compiled.
      def cr_require_call(node) = "# require #{node.arg_nodes[0].inspect} (dropped — closed world)"

      # attr_accessor/attr_reader/attr_writer :name, :other, ...
      def cr_attr_methods(node, reader:, writer:)
        indent_str = "  " * @indent
        lines = []
        node.arg_nodes.each do |sym|
          next unless sym.is_a?(Ast::SymbolLiteral)
          name = sym.value.to_s
          lines << "def #{name} : RubyObject; @#{name}; end" if reader
          lines << "def #{name}=(val : RubyObject) : RubyObject; @#{name} = val; val; end" if writer
        end
        lines.join("\n#{indent_str}")
      end

      def cr_call_args(node)
        # Drop the block at call sites where the callee is statically known
        # to not use one. Ruby allows passing a block to any method (silently
        # ignored if unused), but Crystal requires the def to declare `&` —
        # which Frozone only emits when the Ruby def actually has a block
        # param. Without this elision, `instance.foo {}` calls to a
        # block-less Ruby def fail to compile.
        block_node = node.block_node
        if block_node && callee_ignores_block?(node)
          block_node = nil
        end
        return "" if node.arg_nodes.empty? && node.kw_arg_nodes.empty? && block_node.nil?
        parts = []
        node.arg_nodes.each do |arg|
          if arg.is_a?(Ast::SplatArg)
            parts << "# UNSUPPORTED_SPLAT(#{cr(arg.value_node)})"
          else
            parts << cr(arg)
          end
        end
        node.kw_arg_nodes.each do |kw_name, val_node|
          key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
          parts << "#{key}: #{cr(val_node)}"
        end
        s = "(#{parts.join(', ')})"
        if block_node
          s += " "
          s += block_node.is_a?(Ast::BlockArg) ? cr_block_arg(block_node) : cr_block(block_node)
        end
        s
      end

      # True when the call's callee is a user-defined Ruby method whose
      # `uses_block` static analysis says it never references the block.
      # Used to drop `{ ... }` from `instance.foo {}` style call sites.
      def callee_ignores_block?(node)
        return false unless defined?(@gctx) && @gctx&.method_uses_block
        recv = node.receiver_node
        if recv.nil?
          uses = @gctx.method_uses_block[[nil, node.name]]
          return uses == false
        end
        cls = expr_class(recv) rescue nil
        return false unless cls
        @gctx.method_uses_block[[cls, node.name]] == false
      end

      # -----------------------------------------------------------------------
      # Block
      # -----------------------------------------------------------------------

      def cr_block(node)
        params = (node.required_params || []) + (node.optional_params || []).map(&:first)
        params += [node.rest_param].compact
        param_str = params.empty? ? "" : "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        "{ #{param_str}#{cr(node.body)} }"
      end

      # &:method — single-arg block that calls the method
      def cr_block_arg(block_arg_node)
        value_node = block_arg_node.value_node
        if value_node.is_a?(Ast::SymbolLiteral)
          method_name = crystal_method_name(value_node.value)
          "{ |_sym2proc| _sym2proc.#{method_name}.as(RubyObject) }"
        else
          "{ |_blkarg| (#{cr(value_node)}).as(RubyProc).call(_blkarg) }"
        end
      end

      # -----------------------------------------------------------------------
      # Control flow
      # -----------------------------------------------------------------------

      def cr_if(node)
        pred = cr_truthy(node.pred_node)
        indent_str = "  " * @indent
        # Detect `unless` pattern: if cond; nil; else; body; end
        if node.then_node.is_a?(Ast::NilLiteral) && node.else_node
          body = nil
          indented { body = cr(node.else_node) }
          return "unless #{pred}\n#{body}\n#{indent_str}end"
        end
        then_body = nil
        indented { then_body = cr(node.then_node) }
        then_body = "  #{indent_str}#{then_body}" unless node.then_node.is_a?(Ast::Sequence)
        if node.else_node
          else_body = nil
          indented { else_body = cr(node.else_node) }
          else_body = "  #{indent_str}#{else_body}" unless node.else_node.is_a?(Ast::Sequence)
          "if #{pred}\n#{then_body}\n#{indent_str}else\n#{else_body}\n#{indent_str}end"
        else
          "if #{pred}\n#{then_body}\n#{indent_str}end"
        end
      end

      def cr_for_loop(node)
        target = node.target
        var_str = case target[0]
                  when :local then crystal_local(target[1])
                  when :multi
                    _, lefts, rest_sym, rights = target
                    parts = lefts.map { |n| crystal_local(n) }
                    parts << "*#{crystal_local(rest_sym)}" if rest_sym
                    parts += rights.map { |n| crystal_local(n) }
                    parts.join(", ")
                  else "_for_var"
                  end
        indent_str = "  " * @indent
        body = nil
        indented { body = cr(node.body_node) }
        "#{cr(node.collection_node)}.each do |#{var_str}|\n#{body}\n#{indent_str}end"
      end

      def cr_while(node) = cr_loop("while", node)
      def cr_until(node) = cr_loop("until", node)

      def cr_loop(keyword, node)
        cond = cr_truthy(node.condition_node)
        indent_str = "  " * @indent
        body = nil
        indented { body = cr(node.body_node) }
        "#{keyword} #{cond}\n#{body}\n#{indent_str}end"
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


      def cr_loop_call(node)
        return "loop do\nend" unless node.block_node
        indent_str = "  " * @indent
        body = nil
        indented { body = cr(node.block_node.body) }
        "loop do\n#{body}\n#{indent_str}end"
      end

      # Lambda node (-> syntax): ->(x) { body }
      def cr_lambda(node)
        param_binds = node.required_params.each_with_index.map { |p, i|
          "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL; "
        }.join
        "RubyProc.new(->(args : Array(RubyObject)) { #{param_binds}#{cr(node.body)} })"
      end

      # Proc.new { |x| ... } or lambda { |x| ... } → RubyProc
      def cr_proc_new(block_node)
        params = block_node.required_params
        binds = params.each_with_index.map { |p, i| "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL; " }.join
        "RubyProc.new(->(args : Array(RubyObject)) { #{binds}#{cr(block_node.body)} })"
      end

      # proc.call(args) → cast to RubyProc and call.
      # If the receiver is the method's &block param, call directly (it's a Crystal Proc).
      def cr_proc_call(node)
        recv = node.receiver_node
        bp_name = (defined?(@mctx) && @mctx&.block_param_name) ||
          (defined?(@current_block_param_name) && @current_block_param_name)
        is_block_param = recv.is_a?(Ast::LocalVariableRead) && bp_name && recv.name == bp_name
        cast = is_block_param ? "" : ".as(RubyProc)"
        "(#{cr(recv)})#{cast}.call(#{node.arg_nodes.map { |a| cr(a) }.join(', ')})"
      end

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


      def cr_global_var_write(node)
        key = node.name.to_s.sub(/^\$/, '')
        %(RUBY_GLOBALS[#{key.inspect}] = #{cr(node.value_node)})
      end

      # a[i] ||= val → (_r = recv; _i = idx; _c = _r[_i]; _c.truthy? ? _c : (_r[_i] = val))
      def cr_index_or_write(node)
        r = "_iorw_r#{@temp_counter}"
        i = "_iorw_i#{@temp_counter}"
        c = "_iorw_c#{@temp_counter}"
        @temp_counter += 1
        recv_str = node.receiver_node ? cr(node.receiver_node) : "self"
        "(#{r} = #{recv_str}; #{i} = #{cr(node.index_arg_nodes[0])}; #{c} = #{r}[#{i}]; #{c}.truthy? ? #{c} : (#{r}[#{i}] = #{cr(node.value_node)}))"
      end

      # a[i] &&= val → (_r = recv; _i = idx; _c = _r[_i]; _c.truthy? ? (_r[_i] = val) : _c)
      def cr_index_and_write(node)
        r = "_iandw_r#{@temp_counter}"
        i = "_iandw_i#{@temp_counter}"
        c = "_iandw_c#{@temp_counter}"
        @temp_counter += 1
        recv_str = node.receiver_node ? cr(node.receiver_node) : "self"
        "(#{r} = #{recv_str}; #{i} = #{cr(node.index_arg_nodes[0])}; #{c} = #{r}[#{i}]; #{c}.truthy? ? (#{r}[#{i}] = #{cr(node.value_node)}) : #{c})"
      end

      # a[i] += val → (_r = recv; _i = idx; _r[_i] = _r[_i] op val)
      def cr_index_op_write(node)
        r = "_iopw_r#{@temp_counter}"
        i = "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        recv_str = node.receiver_node ? cr(node.receiver_node) : "self"
        "(#{r} = #{recv_str}; #{i} = #{cr(node.index_arg_nodes[0])}; #{r}[#{i}] = (#{r}[#{i}] #{node.operator} #{cr(node.value_node)}))"
      end

      def cr_yield(node)
        args = node.arg_nodes
        return "yield" if args.empty?
        "yield #{args.map { |a| "(#{cr(a)})" }.join(', ')}"
      end

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


      # Wrap a value in a Crystal truthy check when used as a condition.
      # If the node is already a comparison/predicate that returns Bool, emit
      # it directly; otherwise wrap in .truthy?
      def cr_truthy(node)
        case node
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral, Ast::NilLiteral then "false"
        else
          if boolean_valued?(node) then cr(node)
          elsif comparison_op_call?(node)
            "(#{cr_operator_recv(node.receiver_node)} #{node.name} #{cr(node.arg_nodes[0])})"
          else "#{cr(node)}.truthy?"
          end
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

      def cr_case(node)
        subject = node.subject_node
        whens = node.whens
        else_n = node.else_node
        no_subject = subject.nil? || subject.is_a?(Ast::NilLiteral)
        is_local = !no_subject && subject.is_a?(Ast::LocalVariableRead)
        all_type = !no_subject && whens.all? { |w| w.condition_nodes.all? { |c| type_check_cond?(c) } }
        return cr_case_native(crystal_local(subject.name), whens, else_n) if is_local && all_type
        indent_str = "  " * @indent
        if no_subject
          cr_case_if_chain(nil, whens, else_n)
        else
          "_case_subj = #{cr(subject)}\n#{indent_str}#{cr_case_if_chain('_case_subj', whens, else_n)}"
        end
      end

      def cr_case_native(subj_name, whens, else_n)
        indent_str = "  " * @indent
        parts = ["case #{subj_name}"]
        whens.each do |w|
          conds = w.condition_nodes.map { |c|
            c.is_a?(Ast::NilLiteral) ? "RubyNil" :
              c.is_a?(Ast::ConstantRead) ? (RUBY_TO_CRYSTAL_TYPE[c.name] || "Ruby_#{crystal_constant(c.name)}") : ""
          }.join(", ")
          parts << "#{indent_str}when #{conds}"
          body = nil
          indented { body = cr(w.body_node) }
          parts << body
        end
        if else_n
          parts << "#{indent_str}else"
          else_body = nil
          indented { else_body = cr(else_n) }
          parts << else_body
        end
        parts << "#{indent_str}end"
        parts.join("\n")
      end

      def cr_case_if_chain(subj_var, whens, else_n)
        indent_str = "  " * @indent
        parts = []
        whens.each_with_index do |w, idx|
          keyword = idx == 0 ? "if " : "elsif "
          conds = w.condition_nodes.map { |c|
            subj_var ? cr_case_match(c, subj_var) : cr_truthy(c)
          }.join(" || ")
          parts << "#{idx == 0 ? '' : indent_str}#{keyword}#{conds}"
          body = nil
          indented { body = cr(w.body_node) }
          parts << body
        end
        if else_n
          parts << "#{indent_str}else"
          else_body = nil
          indented { else_body = cr(else_n) }
          parts << else_body
        end
        parts << "#{indent_str}end"
        parts.join("\n")
      end

      def cr_case_match(cond_node, subj_var)
        case cond_node
        when Ast::NilLiteral then "#{subj_var}.ruby_nil?"
        when Ast::TrueLiteral then "#{subj_var}.truthy? && !#{subj_var}.ruby_nil?"
        when Ast::FalseLiteral then "!#{subj_var}.truthy?"
        when Ast::ConstantRead
          type_name = cond_node.name
          crystal_type = RUBY_TO_CRYSTAL_TYPE[type_name] || "Ruby_#{crystal_constant(type_name)}"
          "#{subj_var}.is_a?(#{crystal_type})"
        else
          "(#{cr(cond_node)}) == #{subj_var}"
        end
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


      def cr_multiple_assignment(node)
        targets = node.targets
        rhs     = node.value_node
        tmp = "_ma#{@temp_counter}"
        @temp_counter += 1
        indent_str = "  " * @indent
        lines = ["#{tmp} = masgn_coerce(#{cr(rhs)})"]
        splat_idx = targets.index { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if splat_idx
          pre  = targets[0...splat_idx]
          post = targets[(splat_idx + 1)..]
          pre.each_with_index { |t, i| lines << cr_masgn_assign(t, "#{tmp}[#{i}_i64]") }
          splat_t = targets[splat_idx]
          unless splat_t[0] == :splat_nil
            splat_code = "RubyArray.new(#{tmp}.data[#{pre.length}...(#{tmp}.data.size - #{post.length})])"
            lines << cr_masgn_assign(splat_t, splat_code)
          end
          post.each_with_index do |t, i|
            neg = post.length - i
            lines << cr_masgn_assign(t, "#{tmp}[(-#{neg})_i64]")
          end
        else
          targets.each_with_index { |t, i| lines << cr_masgn_assign(t, "#{tmp}[#{i}_i64]") }
        end
        lines.join("\n#{indent_str}")
      end

      def cr_masgn_assign(target, value_code)
        case target[0]
        when :local, :local_splat then "#{crystal_local(target[1])} = #{value_code}"
        when :ivar, :ivar_splat   then "#{target[1]} = #{value_code}"
        when :const, :const_splat then "Ruby_#{crystal_constant(target[1])} = #{value_code}"
        when :index, :index_splat
          idxs = target[2].map { |idx| cr(idx) }.join(", ")
          "#{cr(target[1])}[#{idxs}] = #{value_code}"
        when :call, :call_splat
          "#{cr(target[1])}.#{crystal_method_name(target[2])} = #{value_code}"
        when :splat_nil then ""
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


      # -----------------------------------------------------------------------
      # Method definition
      # -----------------------------------------------------------------------

      # Methods that must return Crystal String (override RubyObject abstract defs)
      STRING_RETURN_METHODS = %i[to_s inspect].to_set

      def cr_method_def(node)
        recv = node.receiver_node
        name = node.name
        string_return = STRING_RETURN_METHODS.include?(name)
        crystal_name = string_return ? name.to_s : crystal_method_name(name)
        prefix = recv ? "def #{cr(recv)}.#{crystal_name}" : "def #{crystal_name}"
        ret_anno = string_return ? " : String" : ""
        params = cr_param_list(node)
        indent_str = "  " * @indent
        body = nil
        if string_return
          inner = nil
          indented do
            indented { inner = cr(node.body) }
            inner_indent = "  " * @indent
            body = "#{inner_indent}(begin\n#{inner}\n#{inner_indent}end).to_s"
          end
        else
          indented { body = cr(node.body) }
        end
        "#{prefix}#{params}#{ret_anno}\n#{body}\n#{indent_str}end"
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


      # -----------------------------------------------------------------------
      # Class / module definitions
      # -----------------------------------------------------------------------

      def cr_class_def(node)
        name = crystal_constant(node.name)
        sym_name = node.name
        is_exc = @exception_classes.include?(sym_name)
        sc = node.superclass_node
        super_str = if is_exc
                      (sc && !EXCEPTION_BASE_NAMES.include?(sc.name.to_s)) ? "Ruby_#{crystal_constant(sc.name)}" : "RubyException"
                    elsif sc
                      "Ruby_#{crystal_constant(sc.name)}"
                    else
                      "RubyObject"
                    end
        indent_str = "  " * @indent
        prev_exc = @in_exception_class
        @in_exception_class = is_exc
        body_lines = []
        indented do
          inner_indent = "  " * @indent
          if is_exc
            ivars = collect_ivars(node.body)
            ivars.each { |iv| body_lines << "#{inner_indent}#{iv} : RubyObject = RUBY_NIL" }
            body_lines << "" unless ivars.empty?
            unless has_initialize?(node.body)
              body_lines << "#{inner_indent}def initialize(msg : String = \"#{name}\"); super(msg); end"
            end
          else
            sc_name = sc.is_a?(Ast::ConstantRead) ? sc.name.to_s : nil
            user_superclass = sc_name && !BUILTIN_SUPERCLASSES.include?(sc_name)
            ivars = collect_ivars(node.body)
            ivars.each { |iv| body_lines << "#{inner_indent}#{iv} : RubyObject = RUBY_NIL" }
            cvars = collect_cvars(node.body)
            cvars.each { |cv| body_lines << "#{inner_indent}#{cv} : RubyObject = RUBY_NIL" }
            body_lines << "" unless ivars.empty? && cvars.empty?
            unless user_superclass
              body_lines << "#{inner_indent}def to_s : String; \"#<#{name}>\"; end"
              body_lines << "#{inner_indent}def inspect : String; \"#<#{name}>\"; end"
              body_lines << "#{inner_indent}def ==(other : RubyObject) : Bool; same?(other); end"
              body_lines << ""
            end
          end
          unless node.body.is_a?(Ast::NilLiteral)
            body_lines << "#{inner_indent}#{cr(node.body)}"
          end
        end
        @in_exception_class = prev_exc
        body_str = body_lines.join("\n")
        "class Ruby_#{name} < #{super_str}\n#{body_str}\n#{indent_str}end"
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

      def cr_module_def(node)
        indent_str = "  " * @indent
        body_str = ""
        unless node.body.is_a?(Ast::NilLiteral)
          inner = nil
          indented { inner = cr(node.body) }
          inner_indent = "  " * (@indent + 1)
          body_str = "\n#{inner_indent}#{inner}"
        end
        "module Ruby_#{crystal_constant(node.name)}#{body_str}\n#{indent_str}end"
      end

      # -----------------------------------------------------------------------
      # Output helpers
      # -----------------------------------------------------------------------

      def write(*strs) = strs.each { |s| @out << s }
      def line(str) = @out << ("  " * @indent) << str << "\n"
      def emit_indent = @out << ("  " * @indent)
      def emit_newline = @out << "\n"

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
        sub.send(:emit, node)
        sub.out
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
          node.children.each { |c| collect_cvars(c, seen) if c.is_a?(Ast::Node) }
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
          node.children.each { |c| collect_ivars(c, seen) if c.is_a?(Ast::Node) }
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

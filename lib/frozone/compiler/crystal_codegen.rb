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
        @out                = +""        # output buffer
        @indent             = 0          # current indentation level
        @errors             = []         # collect unsupported-node warnings
        @output_dir         = output_dir # used to compute relative runtime require path
        @user_methods       = Set.new    # names of user-defined methods (for RubyObject stubs)
        @exception_classes  = Set.new    # Ruby class names that inherit from exception bases
        @in_exception_class = false      # true while emitting inside an exception class body
        @temp_counter       = 0          # unique suffix for generated temp variable names
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
          sc = ivar(node, :superclass_node)
          if sc.is_a?(Ast::ConstantRead)
            sc_name = ivar(sc, :name).to_s
            if EXCEPTION_BASE_NAMES.include?(sc_name) || @exception_classes.include?(sc_name.to_sym)
              @exception_classes << ivar(node, :name)
            end
          end
          body = ivar(node, :body)
          collect_user_methods(body) if body
        when Ast::ModuleDef
          body = ivar(node, :body)
          collect_user_methods(body) if body
        when Ast::MethodDef
          @user_methods << ivar(node, :name)
        when Ast::MethodCall
          # attr_accessor/reader/writer implicitly define methods
          mname = ivar(node, :name)
          if ATTR_METHODS.include?(mname)
            ivar(node, :arg_nodes).each do |a|
              next unless a.is_a?(Ast::SymbolLiteral)
              sym_name = ivar(a, :value).raw
              @user_methods << sym_name           unless mname == :attr_writer
              @user_methods << :"#{sym_name}="    unless mname == :attr_reader
            end
          end
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
        when Ast::ConstantWrite         then emit_constant_write(node)
        when Ast::ClassVariableRead     then emit_class_var_read(node)
        when Ast::ClassVariableWrite    then emit_class_var_write(node)
        when Ast::Yield                 then emit_yield(node)
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
        when Ast::Rescue                then emit_rescue(node)
        when Ast::Super                 then emit_super(node)
        when Ast::Case                  then emit_case(node)
        when Ast::Next                  then emit_next(node)
        when Ast::Break                 then emit_break(node)
        when Ast::RangeLiteral          then emit_range_literal(node)
        when Ast::MultipleAssignment    then emit_multiple_assignment(node)
        when Ast::Lambda                then emit_lambda(node)
        when Ast::GlobalVariableRead    then emit_global_var_read(node)
        when Ast::GlobalVariableWrite   then emit_global_var_write(node)
        when Ast::IndexOrWrite          then emit_index_or_write(node)
        when Ast::IndexOperatorWrite    then emit_index_op_write(node)
        when Ast::IndexAndWrite         then emit_index_and_write(node)
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
        line "RUBY_NIL    = RubyNil::INSTANCE"
        line "RUBY_TRUE   = RubyBool::TRUE"
        line "RUBY_FALSE  = RubyBool::FALSE"
        line "RUBY_GLOBALS = {} of String => RubyObject"
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
        raw = ivar(node, :value)
        val = raw.respond_to?(:raw) ? raw.raw : raw
        write "RubyFloat.new(#{val}_f64)"
      end

      def emit_string_literal(node)
        raw = ivar(node, :value).raw
        write %(RubyString.new(#{crystal_string_literal(raw)}))
      end

      def emit_symbol_literal(node)
        sym = ivar(node, :value).raw  # SymbolObject#raw → native Ruby Symbol
        write %(RubySymbol.from(#{sym.to_s.inspect}))
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
        name = ivar(node, :name)
        crystal_type = RUBY_TO_CRYSTAL_TYPE[name]
        crystal_type ? write(crystal_type) : write("Ruby_#{crystal_constant(name)}")
      end

      def emit_constant_write(node)
        write "Ruby_#{crystal_constant(ivar(node, :name))} = "
        emit(ivar(node, :value_node))
      end

      def emit_class_var_read(node)
        write ivar(node, :name).to_s
      end

      def emit_class_var_write(node)
        write "#{ivar(node, :name)} = "
        emit(ivar(node, :value_node))
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
          when :puts         then return emit_puts(node)
          when :print        then return emit_print(node)
          when :p            then return emit_p(node)
          when :raise        then return emit_raise(node)
          when :require      then return emit_require_call(node)
          when :block_given? then return write("block_given?")
          when :loop         then return emit_loop(node)
          when :attr_accessor then return emit_attr_methods(node, reader: true, writer: true)
          when :attr_reader   then return emit_attr_methods(node, reader: true, writer: false)
          when :attr_writer   then return emit_attr_methods(node, reader: false, writer: true)
          when :include, :extend, :prepend
            return write("# #{name} #{node.arg_nodes.map { |a| a.is_a?(Ast::ConstantRead) ? ivar(a, :name) : '?' }.join(', ')}")
          end
        end

        # Operator and unary methods — emit as Crystal operator syntax
        if node.receiver_node
          return emit_operator(node, name) if operator?(name)
        end

        # Built-in class .new: Array.new(n, default), Hash.new, etc.
        if name == :new && node.receiver_node.is_a?(Ast::ConstantRead)
          cr_type = RUBY_TO_CRYSTAL_TYPE[ivar(node.receiver_node, :name)]
          if cr_type
            write "#{cr_type}.new"
            emit_call_args(node)
            return
          end
        end

        # Proc.new { |...| ... } → RubyProc wrapping a Crystal proc
        if name == :new && node.receiver_node.is_a?(Ast::ConstantRead) &&
           ivar(node.receiver_node, :name) == :Proc && node.block_node
          return emit_proc_new(node.block_node)
        end

        # lambda { |...| ... } (no receiver) → same as Proc.new
        if name == :lambda && node.receiver_node.nil? && node.block_node
          return emit_proc_new(node.block_node)
        end

        # proc.call(args) → cast receiver to RubyProc then call
        if name == :call && node.receiver_node
          return emit_proc_call(node)
        end

        # [] subscript: emit receiver[arg] instead of receiver.[](arg)
        if name == :[] && node.receiver_node && node.arg_nodes.size == 1
          emit(node.receiver_node)
          write "["
          emit(node.arg_nodes[0])
          write "]"
          return
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

      # AttributeWrite: obj.foo = val (setter) or obj[i] = val (index assign)
      def emit_attribute_write(node)
        name = ivar(node, :name)
        recv = ivar(node, :receiver_node)
        args = ivar(node, :arg_nodes)
        if name == :[]=
          # Index assignment: receiver[idx] = val
          emit(recv)
          write "["
          emit(args[0])
          write "] = "
          emit(args[1])
        else
          # Setter method: receiver.foo = val
          setter_name = name.to_s.chomp('=')
          emit(recv)
          write ".#{setter_name} = "
          emit(args[0])
        end
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
        args = node.arg_nodes
        if args.empty?
          write "RuntimeError.new"
        elsif args.size == 1
          arg = args[0]
          case arg
          when Ast::StringLiteral
            # raise "msg" → raise RuntimeError.new("msg")
            write "RuntimeError.new(#{crystal_string_literal(ivar(arg, :value).raw)})"
          when Ast::ConstantRead
            # raise ExcClass → raise Ruby_ExcClass.new
            write "Ruby_#{crystal_constant(ivar(arg, :name))}.new"
          else
            # raise exception_instance (e.g. raise MyError.new(...))
            emit(arg)
          end
        elsif args.size >= 2
          # raise ExcClass, "msg" [, backtrace] → raise Ruby_ExcClass.new("msg")
          exc_node = args[0]
          msg_node = args[1]
          if exc_node.is_a?(Ast::ConstantRead)
            write "Ruby_#{crystal_constant(ivar(exc_node, :name))}.new("
          else
            emit(exc_node)
            write ".new("
          end
          emit(msg_node)
          write ".to_s)"
        end
      end

      def emit_rescue(node)
        write "begin"
        emit_newline
        indented { emit(ivar(node, :body)) }
        emit_newline

        ivar(node, :rescue_clauses).each do |clause|
          emit_indent
          var_name  = clause.var_name
          exc_nodes = clause.exception_nodes

          if exc_nodes.empty?
            # bare rescue → catch all Crystal exceptions
            write var_name ? "rescue #{crystal_local(var_name)} : Exception" : "rescue"
          else
            # rescue ExcA, ExcB => e
            exc_types = exc_nodes.map do |en|
              en.is_a?(Ast::ConstantRead) ? "Ruby_#{crystal_constant(ivar(en, :name))}" : "Exception"
            end.join(" | ")
            write var_name ? "rescue #{crystal_local(var_name)} : #{exc_types}" : "rescue #{exc_types}"
          end
          emit_newline
          indented { emit(clause.body) }
          emit_newline
        end

        if (else_node = ivar(node, :else_node))
          emit_indent
          write "else"
          emit_newline
          indented { emit(else_node) }
          emit_newline
        end

        if (ensure_node = ivar(node, :ensure_node))
          emit_indent
          write "ensure"
          emit_newline
          indented { emit(ensure_node) }
          emit_newline
        end

        emit_indent
        write "end"
      end

      def emit_super(node)
        forwarding = ivar(node, :forwarding)
        args = ivar(node, :arg_nodes)
        if forwarding || args.nil? || args.empty?
          write "super"
        else
          write "super("
          args.each_with_index do |arg, i|
            write ", " if i > 0
            emit(arg)
            # In exception class initializers, super(msg) expects Crystal String
            write ".to_s" if @in_exception_class
          end
          write ")"
        end
      end

      def emit_require_call(node)
        # Silently drop require calls — closed world, all files already compiled.
        write "# require #{node.arg_nodes[0].inspect} (dropped — closed world)"
      end

      # attr_accessor/attr_reader/attr_writer :name, :other, ...
      # Emits Crystal getter and/or setter methods for each symbol arg.
      def emit_attr_methods(node, reader:, writer:)
        first = true
        node.arg_nodes.each do |sym|
          next unless sym.is_a?(Ast::SymbolLiteral)
          name = ivar(sym, :value).raw.to_s
          if first
            first = false
          else
            emit_newline
            emit_indent
          end
          if reader
            write "def #{name} : RubyObject; @#{name}; end"
          end
          if writer
            emit_newline; emit_indent if reader
            write "def #{name}=(val : RubyObject) : RubyObject; @#{name} = val; val; end"
          end
        end
      end

      def emit_call_args(node)
        return if node.arg_nodes.empty? && node.kw_arg_nodes.empty? && node.block_node.nil?

        write "("
        first = true
        node.arg_nodes.each do |arg|
          write ", " unless first
          first = false
          if arg.is_a?(Ast::SplatArg)
            # SplatArg: Crystal can't splat Array (only Tuple); emit unsupported marker
            write "# UNSUPPORTED_SPLAT("
            emit(ivar(arg, :value_node))
            write ")"
          else
            emit(arg)
          end
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

      def emit_next(node)
        val = ivar(node, :value_node)
        if val.nil? || val.is_a?(Ast::NilLiteral)
          write "next"
        else
          write "next ("
          emit(val)
          write ")"
        end
      end

      def emit_break(node)
        val = ivar(node, :value_node)
        if val.nil? || val.is_a?(Ast::NilLiteral)
          write "break"
        else
          write "break ("
          emit(val)
          write ")"
        end
      end

      def emit_loop(node)
        write "loop do"
        if node.block_node
          emit_newline
          indented { emit(ivar(node.block_node, :body)) }
          emit_newline
          emit_indent
        end
        write "end"
      end

      # Lambda node (-> syntax): ->(x) { body }
      def emit_lambda(node)
        params = ivar(node, :required_params)
        write "RubyProc.new(->(args : Array(RubyObject)) { "
        params.each_with_index do |p, i|
          write "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL; "
        end
        emit(ivar(node, :body))
        write " })"
      end

      # Proc.new { |x| ... } or lambda { |x| ... } → RubyProc
      def emit_proc_new(block_node)
        params = ivar(block_node, :required_params)
        write "RubyProc.new(->(args : Array(RubyObject)) { "
        params.each_with_index do |p, i|
          write "#{crystal_local(p)} = args.size > #{i} ? args[#{i}] : RUBY_NIL; "
        end
        emit(ivar(block_node, :body))
        write " })"
      end

      # proc.call(args) → cast to RubyProc and call
      def emit_proc_call(node)
        write "("
        emit(node.receiver_node)
        write ").as(RubyProc).call("
        node.arg_nodes.each_with_index do |arg, i|
          write ", " if i > 0
          emit(arg)
        end
        write ")"
      end

      # Global variable read: $name → RUBY_GLOBALS["name"]? || RUBY_NIL
      MAPPED_GLOBALS = {
        :"$stdout" => "RUBY_NIL",  # TODO: IO wrapper
        :"$stderr" => "RUBY_NIL",
        :"$stdin"  => "RUBY_NIL",
      }.freeze

      def emit_global_var_read(node)
        name = ivar(node, :name)
        if (mapped = MAPPED_GLOBALS[name])
          write mapped
        else
          key = name.to_s.sub(/^\$/, '')
          write %((RUBY_GLOBALS[#{key.inspect}]? || RUBY_NIL))
        end
      end

      def emit_global_var_write(node)
        name = ivar(node, :name)
        key  = name.to_s.sub(/^\$/, '')
        write %(RUBY_GLOBALS[#{key.inspect}] = )
        emit(ivar(node, :value_node))
      end

      # a[i] ||= val → (_r = recv; _i = idx; _c = _r[_i]; _c.truthy? ? _c : (_r[_i] = val))
      def emit_index_or_write(node)
        recv_node  = ivar(node, :receiver_node)
        index_args = ivar(node, :index_arg_nodes)
        val_node   = ivar(node, :value_node)
        r = "_iorw_r#{@temp_counter}"
        i = "_iorw_i#{@temp_counter}"
        c = "_iorw_c#{@temp_counter}"
        @temp_counter += 1
        write "(#{r} = "
        recv_node ? emit(recv_node) : write("self")
        write "; #{i} = "
        emit(index_args[0])
        write "; #{c} = #{r}[#{i}]; #{c}.truthy? ? #{c} : (#{r}[#{i}] = "
        emit(val_node)
        write "))"
      end

      # a[i] &&= val → (_r = recv; _i = idx; _c = _r[_i]; _c.truthy? ? (_r[_i] = val) : _c)
      def emit_index_and_write(node)
        recv_node  = ivar(node, :receiver_node)
        index_args = ivar(node, :index_arg_nodes)
        val_node   = ivar(node, :value_node)
        r = "_iandw_r#{@temp_counter}"
        i = "_iandw_i#{@temp_counter}"
        c = "_iandw_c#{@temp_counter}"
        @temp_counter += 1
        write "(#{r} = "
        recv_node ? emit(recv_node) : write("self")
        write "; #{i} = "
        emit(index_args[0])
        write "; #{c} = #{r}[#{i}]; #{c}.truthy? ? (#{r}[#{i}] = "
        emit(val_node)
        write ") : #{c})"
      end

      # a[i] += val → (_r = recv; _i = idx; _r[_i] = _r[_i] op val)
      def emit_index_op_write(node)
        op         = ivar(node, :operator)
        recv_node  = ivar(node, :receiver_node)
        index_args = ivar(node, :index_arg_nodes)
        val_node   = ivar(node, :value_node)
        r = "_iopw_r#{@temp_counter}"
        i = "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        write "(#{r} = "
        recv_node ? emit(recv_node) : write("self")
        write "; #{i} = "
        emit(index_args[0])
        write "; #{r}[#{i}] = (#{r}[#{i}] #{op} "
        emit(val_node)
        write "))"
      end

      def emit_yield(node)
        args = ivar(node, :arg_nodes)
        if args.empty?
          write "yield"
        else
          write "yield "
          args.each_with_index do |arg, i|
            write ", " if i > 0
            write "("
            emit(arg)
            write ")"
          end
        end
      end

      # -----------------------------------------------------------------------
      # Boolean operators
      # -----------------------------------------------------------------------

      # emit_and/emit_or return RubyObject (not Bool) so they work in value
      # contexts like `x = a && b` or `x ||= val`. emit_truthy adds .truthy?
      # when the result is used as a Crystal condition.
      def emit_and(node)
        tmp = "_and#{@temp_counter}"
        @temp_counter += 1
        write "(#{tmp} = "
        emit(ivar(node, :left_node))
        write "; #{tmp}.truthy? ? ("
        emit(ivar(node, :right_node))
        write ") : #{tmp})"
      end

      def emit_or(node)
        tmp = "_or#{@temp_counter}"
        @temp_counter += 1
        write "(#{tmp} = "
        emit(ivar(node, :left_node))
        write "; #{tmp}.truthy? ? #{tmp} : ("
        emit(ivar(node, :right_node))
        write "))"
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
      # Case / when
      # -----------------------------------------------------------------------

      # Map Ruby core class names to Crystal type names for case/when type checks.
      RUBY_TO_CRYSTAL_TYPE = {
        Integer:  'RubyInteger',
        Float:    'RubyFloat',
        String:   'RubyString',
        Symbol:   'RubySymbol',
        Array:    'RubyArray',
        Hash:     'RubyHash',
        NilClass: 'RubyNil',
        Numeric:  'RubyObject',
      }.freeze

      # Returns true if a `when` condition node is a type-check (ConstantRead or nil).
      def type_check_cond?(cond)
        cond.is_a?(Ast::NilLiteral) || cond.is_a?(Ast::ConstantRead)
      end

      def emit_case(node)
        subject = ivar(node, :subject_node)
        whens   = ivar(node, :whens)
        else_n  = ivar(node, :else_node)

        no_subject = subject.nil? || subject.is_a?(Ast::NilLiteral)

        # When subject is a simple local variable AND all when conditions are type
        # checks, use Crystal's native case/when so that Crystal narrows the
        # variable type inside each branch (allows calling Array#size etc).
        is_local   = !no_subject && subject.is_a?(Ast::LocalVariableRead)
        all_type   = !no_subject && whens.all? { |w| w.condition_nodes.all? { |c| type_check_cond?(c) } }

        if is_local && all_type
          emit_case_native(crystal_local(ivar(subject, :name)), whens, else_n)
          return
        end

        # General case: capture subject in temp var (avoids double-evaluation)
        # and emit an if/elsif chain with explicit matches.
        subj_var = nil
        unless no_subject
          subj_var = "_case_subj"
          write "_case_subj = "
          emit(subject)
          emit_newline
          emit_indent
        end

        emit_case_if_chain(subj_var, whens, else_n)
      end

      # Crystal native case/when — uses Crystal type narrowing.
      # Only valid when subject is a known local variable name.
      def emit_case_native(subj_name, whens, else_n)
        write "case #{subj_name}"
        emit_newline
        whens.each do |w|
          emit_indent
          write "when "
          w.condition_nodes.each_with_index do |cond, j|
            write ", " if j > 0
            if cond.is_a?(Ast::NilLiteral)
              write "RubyNil"
            elsif cond.is_a?(Ast::ConstantRead)
              name = ivar(cond, :name)
              write RUBY_TO_CRYSTAL_TYPE[name] || "Ruby_#{crystal_constant(name)}"
            end
          end
          emit_newline
          indented { emit(w.body_node) }
          emit_newline
        end
        if else_n
          emit_indent; write "else"; emit_newline
          indented { emit(else_n) }
          emit_newline
        end
        emit_indent
        write "end"
      end

      # If/elsif chain — used when Crystal type narrowing is not possible.
      def emit_case_if_chain(subj_var, whens, else_n)
        whens.each_with_index do |w, idx|
          write idx == 0 ? "if " : "elsif "
          w.condition_nodes.each_with_index do |cond, j|
            write " || " if j > 0
            subj_var ? emit_case_match(cond, subj_var) : emit_truthy(cond)
          end
          emit_newline
          indented { emit(w.body_node) }
          emit_newline
          emit_indent
        end
        if else_n
          write "else"; emit_newline
          indented { emit(else_n) }
          emit_newline
          emit_indent
        end
        write "end"
      end

      # Emit a single `when` condition match against subj_var.
      def emit_case_match(cond_node, subj_var)
        case cond_node
        when Ast::NilLiteral
          write "#{subj_var}.ruby_nil?"
        when Ast::TrueLiteral
          write "#{subj_var}.truthy? && !#{subj_var}.ruby_nil?"
        when Ast::FalseLiteral
          write "!#{subj_var}.truthy?"
        when Ast::ConstantRead
          type_name = ivar(cond_node, :name)
          crystal_type = RUBY_TO_CRYSTAL_TYPE[type_name] || "Ruby_#{crystal_constant(type_name)}"
          write "#{subj_var}.is_a?(#{crystal_type})"
        else
          # Value equality: emit (cond_val) == subj_var
          write "("
          emit(cond_node)
          write ") == #{subj_var}"
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

      def emit_range_literal(node)
        b = ivar(node, :begin_node)
        e = ivar(node, :end_node)
        excl = ivar(node, :exclusive)
        write "RubyRange.new("
        b ? emit(b) : write("RUBY_NIL")
        write ", "
        e ? emit(e) : write("RUBY_NIL")
        write ", #{excl})"
      end

      def emit_multiple_assignment(node)
        targets = ivar(node, :targets)
        rhs     = ivar(node, :value_node)

        tmp = "_ma#{@temp_counter}"
        @temp_counter += 1

        write "#{tmp} = masgn_coerce("
        emit(rhs)
        write ")"

        splat_idx = targets.index { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }

        if splat_idx
          pre  = targets[0...splat_idx]
          post = targets[(splat_idx + 1)..]

          pre.each_with_index do |t, i|
            emit_newline; emit_indent
            emit_masgn_assign(t, "#{tmp}[#{i}_i64]")
          end

          splat_t = targets[splat_idx]
          unless splat_t[0] == :splat_nil
            emit_newline; emit_indent
            pc = post.length
            splat_code = "RubyArray.new(#{tmp}.data[#{pre.length}...(#{tmp}.data.size - #{pc})])"
            emit_masgn_assign(splat_t, splat_code)
          end

          post.each_with_index do |t, i|
            emit_newline; emit_indent
            neg = post.length - i
            emit_masgn_assign(t, "#{tmp}[(-#{neg})_i64]")
          end
        else
          targets.each_with_index do |t, i|
            emit_newline; emit_indent
            emit_masgn_assign(t, "#{tmp}[#{i}_i64]")
          end
        end
      end

      def emit_masgn_assign(target, value_code)
        case target[0]
        when :local, :local_splat
          write "#{crystal_local(target[1])} = #{value_code}"
        when :ivar, :ivar_splat
          write "#{target[1]} = #{value_code}"
        when :const, :const_splat
          write "Ruby_#{crystal_constant(target[1])} = #{value_code}"
        when :splat_nil
          # discard — already skipped in caller, but guard here too
        else
          write "# UNSUPPORTED masgn target: #{target[0]}"
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
        name     = crystal_constant(ivar(node, :name))
        sym_name = ivar(node, :name)
        is_exc   = @exception_classes.include?(sym_name)
        sc       = ivar(node, :superclass_node)

        write "class Ruby_#{name}"
        if is_exc
          # Exception classes inherit from RubyException (< Exception) or a Ruby_ exc superclass
          if sc && !EXCEPTION_BASE_NAMES.include?(ivar(sc, :name).to_s)
            write " < Ruby_#{crystal_constant(ivar(sc, :name))}"
          else
            write " < RubyException"
          end
        elsif sc
          write " < Ruby_#{crystal_constant(ivar(sc, :name))}"
        else
          write " < RubyObject"
        end
        emit_newline

        prev_exc = @in_exception_class
        @in_exception_class = is_exc

        indented do
          if is_exc
            # Exception classes: ivar declarations + default message initializer
            ivars = collect_ivars(ivar(node, :body))
            ivars.each { |iv| line "#{iv} : RubyObject = RUBY_NIL" }
            emit_newline unless ivars.empty?
            # Default no-arg initializer passes class name as message if not overridden
            line "def initialize(msg : String = \"#{name}\"); super(msg); end" unless has_initialize?(ivar(node, :body))
          else
            # Regular classes: ivars + class vars + default to_s/inspect/==
            # Only emit default stubs if this class doesn't inherit from another user class
            # (inheriting from a user class would override inherited to_s/inspect/==).
            sc_name = sc.is_a?(Ast::ConstantRead) ? ivar(sc, :name).to_s : nil
            user_superclass = sc_name && !BUILTIN_SUPERCLASSES.include?(sc_name)
            ivars = collect_ivars(ivar(node, :body))
            ivars.each { |iv| line "#{iv} : RubyObject = RUBY_NIL" }
            cvars = collect_cvars(ivar(node, :body))
            cvars.each { |cv| line "#{cv} : RubyObject = RUBY_NIL" }
            emit_newline unless ivars.empty? && cvars.empty?
            unless user_superclass
              line "def to_s : String; \"#<#{name}>\"; end"
              line "def inspect : String; \"#<#{name}>\"; end"
              line "def ==(other : RubyObject) : Bool; same?(other); end"
              emit_newline
            end
          end
          body = ivar(node, :body)
          emit_indent
          emit(body) unless body.is_a?(Ast::NilLiteral)
        end

        @in_exception_class = prev_exc
        emit_newline
        emit_indent
        write "end"
      end

      # Returns true if the class body contains an explicit `initialize` method.
      def has_initialize?(body)
        return false unless body
        case body
        when Ast::Sequence
          body.nodes.any? { |n| n.is_a?(Ast::MethodDef) && ivar(n, :name) == :initialize }
        when Ast::MethodDef
          ivar(body, :name) == :initialize
        else false
        end
      end

      def emit_module_def(node)
        write "module Ruby_#{crystal_constant(ivar(node, :name))}"
        emit_newline
        body = ivar(node, :body)
        indented { emit(body) unless body.is_a?(Ast::NilLiteral) }
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

      def collect_cvars(node, seen = Set.new)
        case node
        when Ast::ClassVariableWrite
          seen << ivar(node, :name).to_s
          collect_cvars(ivar(node, :value_node), seen)
        when Ast::ClassVariableRead
          seen << ivar(node, :name).to_s
        when Ast::Sequence
          node.nodes.each { |n| collect_cvars(n, seen) }
        when Ast::MethodDef
          collect_cvars(ivar(node, :body), seen) if ivar(node, :body)
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
          seen << ivar(node, :name).to_s
          collect_ivars(ivar(node, :value_node), seen)
        when Ast::Sequence
          node.nodes.each { |n| collect_ivars(n, seen) }
        when Ast::MethodDef
          collect_ivars(ivar(node, :body), seen) if ivar(node, :body)
        when Ast::MethodCall
          # attr_accessor/reader/writer declare implicit ivars
          if ATTR_METHODS.include?(ivar(node, :name))
            ivar(node, :arg_nodes).each do |a|
              seen << "@#{ivar(a, :value).raw}" if a.is_a?(Ast::SymbolLiteral)
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

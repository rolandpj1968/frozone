require 'parser/ruby40'
require 'set'

require_relative '../ast'

module Frozone
  module Vm
    class WqParser
      # Scope chain for tracking local variable ownership and depth.
      # Variables are claimed in left-to-right, top-down order as we transform.
      class ScopeChain
        Scope = Struct.new(:claimed, :kind)  # kind: :method or :block

        def initialize
          @stack = []
          push(:method, [])  # top-level acts like a method scope
        end

        def push(kind, initial_names)
          @stack.push(Scope.new(Set.new(initial_names), kind))
        end

        def pop
          @stack.pop
        end

        def current
          @stack.last
        end

        # Register an lvasgn. Search outward (up to method boundary) for existing claim.
        # Returns depth (block boundaries between here and claiming scope, 0 = current).
        def register_write(name)
          d = depth_of(name)
          if d.nil?
            current.claimed.add(name)
            0
          else
            d
          end
        end

        # Look up depth for lvar read. Returns nil if not found (caller should use 0).
        def depth_of(name)
          depth = 0
          @stack.reverse_each do |scope|
            return depth if scope.claimed.include?(name)
            return nil if scope.kind == :method
            depth += 1
          end
          nil
        end
      end

      def initialize(text, dump_ast = false, filepath: nil)
        @text = text
        @dump_ast = dump_ast
        @filepath = filepath
      end

      def ast(raise_syntax_errors: false)
        buf = ::Parser::Source::Buffer.new(@filepath || '(string)', source: @text)
        wq = ::Parser::Ruby40.new
        wq.diagnostics.all_errors_are_fatal = false
        wq.diagnostics.ignore_warnings      = true

        begin
          wq_ast = wq.parse(buf)
        rescue => e
          raise FrozoneException.make(:SyntaxError, e.message) if raise_syntax_errors
          return Ast::NilLiteral::NIL
        end

        puts wq_ast.inspect if @dump_ast

        @scope_chain = ScopeChain.new
        result = transform(wq_ast)
        @top_level_locals = @scope_chain.current.claimed.to_a
        result || Ast::NilLiteral::NIL
      end

      def top_level_locals
        @top_level_locals || []
      end

      private

      # -----------------------------------------------------------------------
      # Main transform dispatch
      # -----------------------------------------------------------------------

      def transform(node)
        return Ast::NilLiteral::NIL if node.nil?

        type = node.type
        c    = node.children

        case type

        # --- Literals --------------------------------------------------------

        when :nil
          Ast::NilLiteral::NIL

        when :true
          Ast::TrueLiteral::TRUE

        when :false
          Ast::FalseLiteral::FALSE

        when :self
          Ast::SelfLiteral::SELF

        when :int
          Ast::IntegerLiteral.from(c[0])

        when :float
          Ast::FloatLiteral.from(c[0])

        when :rational
          # Rational literal r — evaluate as Float or Integer / n
          # We represent it as a method call: Rational(numerator, denominator)
          # c[0] = numerator (integer), c[1] = denominator
          Ast::MethodCall.new(:Rational,
            nil,
            [Ast::IntegerLiteral.from(c[0]), Ast::IntegerLiteral.from(c[1])],
            {})

        when :complex
          # Complex literal — represent as Complex(real, imag)
          Ast::MethodCall.new(:Complex,
            nil,
            [transform_numeric_value(c[0]), transform_numeric_value(c[1])],
            {})

        when :str
          Ast::StringLiteral.from(c[0])

        when :dstr
          Ast::InterpolatedString.new(transform_dstr_parts(node))

        when :sym
          Ast::SymbolLiteral.from(c[0])

        when :dsym
          parts = transform_dstr_parts(node)
          Ast::MethodCall.new(:to_sym, Ast::InterpolatedString.new(parts), [], {})

        when :regexp
          # s(:regexp, str_or_parts..., s(:regopt, :i, :m, ...))
          opts_node = c.last
          flags = parse_regexp_flags(opts_node)
          parts = c[0..-2]
          if parts.length == 1 && parts[0].type == :str
            Ast::RegexpLiteral.new(parts[0].children[0], flags)
          else
            regexp_parts = parts.map do |p|
              p.type == :str ? Ast::StringLiteral.from(p.children[0]) : transform_begin_part(p)
            end
            Ast::InterpolatedRegexpLiteral.new(regexp_parts, flags)
          end

        when :array
          Ast::ArrayLiteral.new(c.map { |e| transform(e) })

        when :hash
          Ast::HashLiteral.new(transform_hash_pairs(node))

        when :irange
          Ast::RangeLiteral.new(transform(c[0]), transform(c[1]), false)

        when :erange
          Ast::RangeLiteral.new(transform(c[0]), transform(c[1]), true)

        when :splat
          Ast::SplatArg.new(c[0].nil? ? Ast::LocalVariableRead.new(:__anon_rest__, 0) : transform(c[0]))

        when :block_pass
          if c[0].nil?
            Ast::ForwardBlock::INSTANCE
          else
            Ast::BlockArg.new(transform(c[0]))
          end

        # --- Variables -------------------------------------------------------

        when :lvar
          name = c[0]
          d = @scope_chain.depth_of(name) || 0
          Ast::LocalVariableRead.new(name, d)

        when :lvasgn
          name = c[0]
          if c.length < 2
            # Bare lvasgn (target context: for-loop, rescue var, multi-assign)
            # Just claim the name and return nil — caller handles this
            @scope_chain.register_write(name)
            return nil
          end
          d = @scope_chain.register_write(name)
          Ast::LocalVariableWrite.new(name, d, transform(c[1]))

        when :ivar
          Ast::InstanceVariableRead.new(c[0])

        when :ivasgn
          Ast::InstanceVariableWrite.new(c[0], transform(c[1]))

        when :gvar
          Ast::GlobalVariableRead.new(c[0])

        when :gvasgn
          Ast::GlobalVariableWrite.new(c[0], transform(c[1]))

        when :cvar
          Ast::ClassVariableRead.new(c[0])

        when :cvasgn
          Ast::ClassVariableWrite.new(c[0], transform(c[1]))

        when :nth_ref
          Ast::GlobalVariableRead.new(:"$#{c[0]}")

        when :back_ref
          Ast::GlobalVariableRead.new(c[0])

        # --- Constants -------------------------------------------------------

        when :const
          parent, name = c[0], c[1]
          if parent.nil?
            Ast::ConstantRead.new(name)
          elsif parent.type == :cbase
            # ::Name — absolute, treat as simple constant read
            Ast::ConstantRead.new(name)
          else
            Ast::ConstantPath.new(transform(parent), name)
          end

        when :cbase
          Ast::RootNamespaceNode::INSTANCE

        when :casgn
          parent, name, value_node = c[0], c[1], c[2]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathWrite.new(transform(parent), name, transform(value_node))
          end

        # --- Method calls ----------------------------------------------------

        when :send, :csend
          transform_send(node)

        when :block
          transform_block(node)

        when :numblock
          transform_numblock(node)

        when :lambda
          # Bare s(:lambda) — shouldn't appear outside s(:block) but handle gracefully
          Ast::Lambda.new([], [], nil, [], [], [], nil, nil, [], Ast::NilLiteral::NIL)

        # --- Defs ------------------------------------------------------------

        when :def
          name     = c[0]
          args_node = c[1]
          body_node = c[2]
          transform_def(name, nil, args_node, body_node)

        when :defs
          recv_node = c[0]
          name      = c[1]
          args_node = c[2]
          body_node = c[3]
          transform_def(name, transform(recv_node), args_node, body_node)

        # --- Classes / Modules -----------------------------------------------

        when :class
          const_node, superclass_node, body_node = c[0], c[1], c[2]
          name, namespace_node = extract_const_name(const_node)
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          superclass_ast = superclass_node ? transform(superclass_node) : nil
          Ast::ClassDef.new(name, locals, superclass_ast, body_ast, namespace_node: namespace_node)

        when :module
          const_node, body_node = c[0], c[1]
          name, namespace_node = extract_const_name(const_node)
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          Ast::ModuleDef.new(name, locals, body_ast, namespace_node: namespace_node)

        when :sclass
          expr_node, body_node = c[0], c[1]
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          Ast::SingletonClassDef.new(transform(expr_node), locals, body_ast)

        # --- Control flow ----------------------------------------------------

        when :if
          cond_node, then_node, else_node = c[0], c[1], c[2]
          Ast::If.new(transform(cond_node), transform(then_node), transform(else_node))

        when :unless
          cond_node, then_node, else_node = c[0], c[1], c[2]
          # unless cond; body; else alt; end == if cond; alt; else body; end
          Ast::If.new(transform(cond_node), transform(else_node), transform(then_node))

        when :while
          cond, body = c[0], c[1]
          body_ast = body.nil? ? Ast::NilLiteral::NIL : transform(body)
          Ast::While.new(transform(cond), body_ast, begin_modifier: false)

        when :while_post
          cond, body = c[0], c[1]
          Ast::While.new(transform(cond), transform_kwbegin_body(body), begin_modifier: true)

        when :until
          cond, body = c[0], c[1]
          body_ast = body.nil? ? Ast::NilLiteral::NIL : transform(body)
          Ast::Until.new(transform(cond), body_ast, begin_modifier: false)

        when :until_post
          cond, body = c[0], c[1]
          Ast::Until.new(transform(cond), transform_kwbegin_body(body), begin_modifier: true)

        when :for
          target_node, collection_node, body_node = c[0], c[1], c[2]
          target = parse_for_target(target_node)
          body_ast = body_node.nil? ? Ast::NilLiteral::NIL : transform(body_node)
          Ast::ForLoop.new(target, transform(collection_node), body_ast)

        when :case
          transform_case(node)

        when :case_match
          raise FrozoneException.make(:NotImplementedError,
            "pattern matching not yet supported in WqParser")

        # --- Exception handling ----------------------------------------------

        when :rescue
          # Standalone rescue (in modifier position or inside def body)
          transform_rescue_node(node, nil, nil)

        when :resbody
          # Shouldn't appear standalone outside rescue — return nil body
          Ast::NilLiteral::NIL

        when :ensure
          transform_ensure_node(node)

        when :begin
          transform_begin_seq(c)

        when :kwbegin
          # kwbegin wraps a single inner node (rescue, ensure, or sequence)
          transform_kwbegin(node)

        # --- Return / break / next / yield / super ---------------------------

        when :return
          value_node = c.empty? ? nil : transform_first_arg(c[0])
          Ast::Return.new(value_node)

        when :break
          value_node = c.empty? ? nil : transform_first_arg(c[0])
          Ast::Break.new(value_node)

        when :next
          value_node = c.empty? ? nil : transform_first_arg(c[0])
          Ast::Next.new(value_node)

        when :redo
          Ast::Redo.new

        when :retry
          Ast::Retry.new

        when :yield
          arg_nodes, kw_args, _kw_splats, _block = parse_call_args(c)
          Ast::Yield.new(arg_nodes, kw_args)

        when :super
          arg_nodes, kw_args, kw_splats, block_node = parse_call_args(c)
          Ast::Super.new(arg_nodes, block_node, forwarding: false, kw_splat_nodes: kw_splats)

        when :zsuper
          Ast::Super.new([], nil, forwarding: true)

        # --- Logical operators -----------------------------------------------

        when :and
          Ast::And.new(transform(c[0]), transform(c[1]))

        when :or
          Ast::Or.new(transform(c[0]), transform(c[1]))

        when :not
          Ast::MethodCall.new(:!, transform(c[0]), [], {})

        # --- Assignments (compound) ------------------------------------------

        when :op_asgn
          transform_op_asgn(node)

        when :or_asgn
          transform_or_asgn(node)

        when :and_asgn
          transform_and_asgn(node)

        when :masgn
          transform_masgn(node)

        # --- Misc special nodes ----------------------------------------------

        when :defined?
          transform_defined(c[0])

        when :alias
          new_name = c[0].children[0]
          old_name = c[1].children[0]
          Ast::MethodAlias.new(new_name, old_name)

        when :undef
          stmts = c.map do |sym_node|
            name_node = if sym_node.type == :sym
              Ast::SymbolLiteral.from(sym_node.children[0])
            else
              # Dynamic: dsym — evaluate interpolation
              transform(sym_node)
            end
            Ast::IntrinsicCall.new(:module_undef_method, [Ast::SelfLiteral::SELF, name_node])
          end
          stmts.length == 1 ? stmts[0] : Ast::Sequence.new(stmts)

        when :match_with_lvasgn
          # /(?<name>...)/ =~ string
          # Whitequark doesn't expose named capture targets directly,
          # so we simplify to a plain =~ call.
          regexp_node, str_node = c[0], c[1]
          Ast::MethodCall.new(:=~, transform(regexp_node), [transform(str_node)], {})

        when :match_current_line
          # /regexp/ in conditional context — `$_ =~ /regexp/`
          Ast::MethodCall.new(:=~,
            Ast::GlobalVariableRead.new(:"$_"),
            [transform(c[0])],
            {})

        when :iflipflop, :eflipflop
          Ast::FalseLiteral::FALSE

        when :xstr
          Ast::StringLiteral.from("")

        when :__FILE__
          Ast::StringLiteral.from(@filepath || "(string)")

        when :__LINE__
          # Not tracking line numbers — return 0 as placeholder
          Ast::IntegerLiteral.from(0)

        when :__ENCODING__
          Ast::ConstantPath.new(Ast::ConstantRead.new(:Encoding), :UTF_8)

        when :forward_args
          # Shouldn't appear as a standalone node; handled in parse_args
          Ast::NilLiteral::NIL

        when :forwarded_args
          # bar(...) expansion — handled in parse_call_args
          Ast::SplatArg.new(Ast::LocalVariableRead.new(:__forward_args__, 0))

        when :procarg0
          # |(a, b)| — single destructured proc param; treat as pass-through
          transform(c[0])

        when :mlhs
          # Multi-target LHS appearing standalone — treat as nil (handled in masgn)
          Ast::NilLiteral::NIL

        when :in_match
          raise FrozoneException.make(:NotImplementedError,
            "pattern matching not yet supported in WqParser")

        when :pin
          raise FrozoneException.make(:NotImplementedError,
            "pattern matching not yet supported in WqParser")

        when :match_as
          raise FrozoneException.make(:NotImplementedError,
            "pattern matching not yet supported in WqParser")

        else
          raise FrozoneException.make(:NotImplementedError,
            "Unsupported Ruby feature in WqParser: #{type}")
        end
      end

      # -----------------------------------------------------------------------
      # Send (method call) transformation
      # -----------------------------------------------------------------------

      def transform_send(node)
        type = node.type  # :send or :csend
        c    = node.children
        recv_node, name, *raw_args = c[0], c[1], *c[2..]
        safe_nav = (type == :csend)

        # Check for Intrinsics.method_name pattern
        if recv_node && recv_node.type == :const &&
           recv_node.children[0].nil? && recv_node.children[1] == :Intrinsics &&
           name != :new
          arg_nodes = raw_args.map { |a| transform(a) }
          return Ast::IntrinsicCall.new(name, arg_nodes)
        end

        # Build receiver (nil if implicit self, also treat explicit self as implicit)
        receiver_ast = if recv_node.nil? || recv_node.type == :self
          nil
        else
          transform(recv_node)
        end

        # Parse args (positional, keyword, block)
        arg_nodes, kw_args, kw_splats, block_node = parse_call_args(raw_args)

        # Attribute write: foo= setters and []= index setters (return assigned value, not setter result)
        # Exclude operator methods that end in = like ==, <=, >=, !=, <=>
        is_setter = name.to_s =~ /\A[a-z_][a-zA-Z0-9_]*=\z/ || name == :[]=
        if is_setter && !arg_nodes.empty? && block_node.nil? && kw_args.empty? && kw_splats.empty?
          return Ast::AttributeWrite.new(name, receiver_ast, arg_nodes, {}, safe_nav: safe_nav)
        end

        Ast::MethodCall.new(name, receiver_ast, arg_nodes, kw_args, block_node,
                            kw_splat_nodes: kw_splats, safe_nav: safe_nav)
      end

      # -----------------------------------------------------------------------
      # Block transformation
      # -----------------------------------------------------------------------

      def transform_block(node)
        send_node, args_node, body_node = node.children[0], node.children[1], node.children[2]

        # Detect lambda: s(:block, s(:send, nil, :lambda), ...)
        is_lambda = send_node.type == :send &&
                    send_node.children[0].nil? &&
                    send_node.children[1] == :lambda

        # Parse block params
        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow =
          parse_block_args(args_node, is_lambda: is_lambda)

        # Push a block scope — initial claimed = param names + shadow names
        initial = collect_param_names(required, optional, rest, post, req_kw, opt_kw,
                                      kw_rest, block_param) + shadow
        @scope_chain.push(:block, initial)

        body_ast = transform(body_node)
        locals = @scope_chain.current.claimed.to_a
        @scope_chain.pop

        # Extract destruct names from required (Hash params)
        destruct_locals = []
        required.each do |p|
          destruct_locals.concat(extract_destruct_names(p)) if p.is_a?(Hash)
        end
        locals = (locals + destruct_locals).uniq

        auto_splat = compute_auto_splat(required, optional, rest, post, req_kw, opt_kw)

        if is_lambda
          # Build the wrapping send node (s(:send, nil, :lambda)) and create a real call
          # Actually: Lambda AST node, which wraps the block
          Ast::Lambda.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                          block_param, locals, body_ast)
        else
          # Find the actual send node and wrap it in a MethodCall with this block
          block_obj = Ast::Block.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                                     block_param, auto_splat, locals, body_ast)
          transform_send_with_block(send_node, block_obj)
        end
      end

      def transform_numblock(node)
        send_node, count, body_node = node.children[0], node.children[1], node.children[2]

        required = (1..count).map { |i| :"_#{i}" }
        optional = []
        rest = nil
        post = []
        req_kw = []
        opt_kw = []
        kw_rest = nil
        block_param = nil

        initial = required.dup
        @scope_chain.push(:block, initial)
        body_ast = transform(body_node)
        locals = @scope_chain.current.claimed.to_a
        @scope_chain.pop

        auto_splat = (count >= 2)
        block_obj = Ast::Block.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                                   block_param, auto_splat, locals, body_ast)
        transform_send_with_block(send_node, block_obj)
      end

      # Given a send node and a block AST, create the appropriate MethodCall or AttributeWrite
      def transform_send_with_block(send_node, block_obj)
        if send_node.type == :send || send_node.type == :csend
          type = send_node.type
          c = send_node.children
          recv_node, name, *raw_args = c[0], c[1], *c[2..]
          safe_nav = (type == :csend)

          # Intrinsics don't take blocks normally, but handle gracefully
          if recv_node && recv_node.type == :const &&
             recv_node.children[0].nil? && recv_node.children[1] == :Intrinsics &&
             name != :new
            arg_nodes = raw_args.map { |a| transform(a) }
            return Ast::IntrinsicCall.new(name, arg_nodes)
          end

          receiver_ast = if recv_node.nil? || recv_node.type == :self
            nil
          else
            transform(recv_node)
          end

          arg_nodes, kw_args, kw_splats, _existing_block = parse_call_args(raw_args)
          Ast::MethodCall.new(name, receiver_ast, arg_nodes, kw_args, block_obj,
                              kw_splat_nodes: kw_splats, safe_nav: safe_nav)

        elsif send_node.type == :super
          arg_nodes, kw_args, kw_splats, _blk = parse_call_args(send_node.children)
          Ast::Super.new(arg_nodes, block_obj, forwarding: false, kw_splat_nodes: kw_splats)

        elsif send_node.type == :zsuper
          Ast::Super.new([], block_obj, forwarding: true)

        elsif send_node.type == :yield
          arg_nodes, kw_args, _kw_splats, _blk = parse_call_args(send_node.children)
          Ast::Yield.new(arg_nodes, kw_args)

        elsif send_node.type == :lambda
          # Should be handled in transform_block but just in case
          Ast::Lambda.new([], [], nil, [], [], [], nil, nil, [], Ast::NilLiteral::NIL)

        else
          transform(send_node)
        end
      end

      # -----------------------------------------------------------------------
      # Def transformation
      # -----------------------------------------------------------------------

      def transform_def(name, receiver_ast, args_node, body_node)
        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param =
          parse_method_args(args_node)

        initial = collect_param_names(required, optional, rest, post, req_kw, opt_kw,
                                      kw_rest, block_param)
        @scope_chain.push(:method, initial)

        body_ast = transform(body_node)
        locals = @scope_chain.current.claimed.to_a
        @scope_chain.pop

        # Extract destruct names from required (Hash params)
        destruct_locals = []
        required.each do |p|
          destruct_locals.concat(extract_destruct_names(p)) if p.is_a?(Hash)
        end
        locals = (locals + destruct_locals).uniq

        Ast::MethodDef.new(name, receiver_ast, required, optional, rest, post,
                           req_kw, opt_kw, kw_rest, block_param, locals, body_ast)
      end

      # -----------------------------------------------------------------------
      # Argument parsing helpers
      # -----------------------------------------------------------------------

      # Parse a :args node for method definitions.
      # Returns [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param]
      def parse_method_args(args_node)
        required    = []
        optional    = []
        rest        = nil
        post        = []
        req_kw      = []
        opt_kw      = []
        kw_rest     = nil
        block_param = nil

        return [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param] if args_node.nil?

        # Handle s(:forward_args) as the entire args
        if args_node.type == :forward_args
          return [required, optional, :__forward_args__, post, req_kw, opt_kw,
                  :__forward_kwargs__, :__forward_block__]
        end

        seen_optional = false
        seen_rest     = false

        args_node.children.each do |arg|
          next if arg.nil?
          case arg.type
          when :arg
            if seen_rest
              post << arg.children[0]
            elsif seen_optional
              post << arg.children[0]
            else
              required << arg.children[0]
            end
          when :mlhs
            # Destructured required param: |(a, b)|
            if seen_rest
              post << parse_multi_target_param(arg)
            else
              required << parse_multi_target_param(arg)
            end
          when :optarg
            seen_optional = true
            optional << [arg.children[0], transform(arg.children[1])]
          when :restarg
            seen_rest = true
            rest = arg.children[0] || :__anon_rest__
          when :kwarg
            req_kw << arg.children[0]
          when :kwoptarg
            opt_kw << [arg.children[0], transform(arg.children[1])]
          when :kwrestarg
            kw_rest = arg.children[0] || :__anon_kwargs__
          when :kwnilarg
            kw_rest = :__no_kwargs__
          when :blockarg
            block_param = arg.children[0] || :__anon_block__
          when :shadowarg
            # block-local var — just claim in current scope (will be added to locals)
            # don't add as a param
          when :procarg0
            # |(x)| single-arg destructuring in a method? unusual but handle
            inner = arg.children[0]
            if inner.type == :mlhs
              required << parse_multi_target_param(inner)
            else
              required << inner.children[0]
            end
          when :forward_args
            rest      = :__forward_args__
            kw_rest   = :__forward_kwargs__
            block_param = :__forward_block__
          when :anon_restarg
            seen_rest = true
            rest = :__anon_rest__
          when :anon_kwrestarg
            kw_rest = :__anon_kwargs__
          when :anon_blockarg
            block_param = :__anon_block__
          end
        end

        [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param]
      end

      # Parse block/lambda args node.
      # Returns [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow]
      def parse_block_args(args_node, is_lambda: false)
        required    = []
        optional    = []
        rest        = nil
        post        = []
        req_kw      = []
        opt_kw      = []
        kw_rest     = nil
        block_param = nil
        shadow      = []

        return [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow] if args_node.nil?

        seen_optional = false
        seen_rest     = false

        args_to_parse = if args_node.type == :args
          args_node.children
        else
          [args_node]
        end

        args_to_parse.each do |arg|
          next if arg.nil?
          case arg.type
          when :arg
            if seen_rest
              post << arg.children[0]
            elsif seen_optional
              post << arg.children[0]
            else
              required << arg.children[0]
            end
          when :mlhs
            # |(a, b)| style destructuring — counts as ONE required
            required << parse_multi_target_param(arg)
          when :procarg0
            # |(expr)| — single destructured arg
            inner = arg.children[0]
            if inner.type == :mlhs
              required << parse_multi_target_param(inner)
            else
              required << inner.children[0]
            end
          when :optarg
            seen_optional = true
            optional << [arg.children[0], transform(arg.children[1])]
          when :restarg
            seen_rest = true
            rest = arg.children[0] || :__anon_rest__
          when :kwarg
            req_kw << arg.children[0]
          when :kwoptarg
            opt_kw << [arg.children[0], transform(arg.children[1])]
          when :kwrestarg
            kw_rest = arg.children[0] || :__anon_kwargs__
          when :kwnilarg
            kw_rest = :__no_kwargs__
          when :blockarg
            block_param = arg.children[0] || :__anon_block__
          when :shadowarg
            shadow << arg.children[0]
          when :anon_restarg
            seen_rest = true
            rest = :__anon_rest__
          when :anon_kwrestarg
            kw_rest = :__anon_kwargs__
          when :anon_blockarg
            block_param = :__anon_block__
          end
        end

        [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow]
      end

      # Compute auto_splat for blocks (not lambdas)
      def compute_auto_splat(required, optional, rest, post, req_kw, opt_kw)
        is_empty      = required.empty? && optional.empty? && rest.nil? && post.empty?
        is_single_req = required.length == 1 && optional.empty? && rest.nil? && post.empty?
        is_single_opt = required.empty? && optional.length == 1 && rest.nil? && post.empty? &&
                        req_kw.empty? && opt_kw.empty?
        is_rest_only  = required.empty? && optional.empty? && rest && post.empty?
        !is_empty && !is_single_req && !is_single_opt && !is_rest_only
      end

      # Collect all flat param names (for initial claimed set)
      def collect_param_names(required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param)
        names = []
        required.each { |p| p.is_a?(Hash) ? names.concat(extract_destruct_names(p)) : names << p }
        optional.each { |name, _| names << name }
        names << rest if rest
        post.each { |p| p.is_a?(Hash) ? names.concat(extract_destruct_names(p)) : names << p }
        req_kw.each { |name| names << name }
        opt_kw.each { |name, _| names << name }
        names << kw_rest if kw_rest && kw_rest != :__no_kwargs__ &&
                            kw_rest != :__anon_kwargs__ && kw_rest != :__forward_kwargs__
        names << block_param if block_param
        names.compact
      end

      def extract_destruct_names(param)
        return [param] if param.is_a?(Symbol)
        names = (param[:names] || []).flat_map { |n| extract_destruct_names(n) }
        names << param[:rest] if param[:rest]
        names + ((param[:rights] || []).flat_map { |n| extract_destruct_names(n) })
      end

      # Parse call args (positional, keyword, splat, block_pass) from raw arg nodes
      # Returns [arg_nodes, kw_args, kw_splat_nodes, block_node]
      def parse_call_args(raw_args)
        arg_nodes   = []
        kw_args     = {}
        kw_splats   = []
        block_node  = nil
        has_forwarding = false

        raw_args.each do |arg|
          next if arg.nil?
          case arg.type
          when :block_pass
            block_node = arg.children[0].nil? ? Ast::ForwardBlock::INSTANCE :
                         Ast::BlockArg.new(transform(arg.children[0]))
          when :splat
            splat_expr = arg.children[0].nil? ?
              Ast::LocalVariableRead.new(:__anon_rest__, 0) :
              transform(arg.children[0])
            arg_nodes << Ast::SplatArg.new(splat_expr)
          when :forwarded_args
            has_forwarding = true
            arg_nodes << Ast::SplatArg.new(Ast::LocalVariableRead.new(:__forward_args__, 0))
            kw_splats << Ast::LocalVariableRead.new(:__forward_kwargs__, 0)
          when :hash
            # Check if this hash is keyword args or a positional hash literal
            if should_be_kw_args?(arg)
              arg.children.each do |pair|
                case pair.type
                when :pair
                  key_node, val_node = pair.children[0], pair.children[1]
                  kw_args[transform(key_node)] = transform(val_node)
                when :kwsplat
                  splat_val = pair.children[0].nil? ?
                    Ast::LocalVariableRead.new(:__anon_kwargs__, 0) :
                    transform(pair.children[0])
                  kw_splats << splat_val
                end
              end
            else
              arg_nodes << Ast::HashLiteral.new(transform_hash_pairs(arg))
            end
          when :kwargs
            # Ruby 3.0+ separate kwargs node
            arg.children.each do |pair|
              case pair.type
              when :pair
                key_node, val_node = pair.children[0], pair.children[1]
                kw_args[transform(key_node)] = transform(val_node)
              when :kwsplat
                splat_val = pair.children[0].nil? ?
                  Ast::LocalVariableRead.new(:__anon_kwargs__, 0) :
                  transform(pair.children[0])
                kw_splats << splat_val
              end
            end
          else
            arg_nodes << transform(arg)
          end
        end

        if has_forwarding
          block_node = Ast::BlockArg.new(Ast::LocalVariableRead.new(:__forward_block__, 0))
        end

        [arg_nodes, kw_args, kw_splats, block_node]
      end

      # Determine if a :hash node in call args should be treated as keyword args
      def should_be_kw_args?(hash_node)
        return false if hash_node.children.empty?
        hash_node.children.any? do |pair|
          pair.type == :kwsplat ||
          (pair.type == :pair && pair.children[0].type == :sym)
        end
      end

      # -----------------------------------------------------------------------
      # Multi-target / multi-assign parsing
      # -----------------------------------------------------------------------

      def parse_multi_target_param(mlhs_node)
        names  = []
        rest   = nil
        rights = []

        children = mlhs_node.children
        seen_rest = false

        children.each do |child|
          next if child.nil?
          case child.type
          when :arg
            if seen_rest
              rights << child.children[0]
            else
              names << child.children[0]
            end
          when :restarg
            seen_rest = true
            rest = child.children[0] || :__anon_rest__
          when :mlhs
            if seen_rest
              rights << parse_multi_target_param(child)
            else
              names << parse_multi_target_param(child)
            end
          when :splat
            seen_rest = true
            inner = child.children[0]
            rest = inner ? inner.children[0] : nil
          end
        end

        { names: names, rest: rest, rights: rights }
      end

      # Parse a multi-write target descriptor for masgn/mlhs
      def parse_masgn_target(node)
        case node.type
        when :lvasgn
          # Bare lvasgn in mlhs (no value) — register and return descriptor
          name = node.children[0]
          d = @scope_chain.register_write(name)
          [:local, name, d]
        when :ivasgn
          [:ivar, node.children[0]]
        when :gvasgn
          [:gvar, node.children[0]]
        when :cvasgn
          [:cvar, node.children[0]]
        when :casgn
          parent, name = node.children[0], node.children[1]
          if parent.nil? || parent.type == :cbase
            [:const, name]
          else
            [:const_path, transform(parent), name]
          end
        when :splat
          inner = node.children[0]
          if inner.nil?
            [:splat_nil]
          else
            inner_desc = parse_masgn_target(inner)
            [:"#{inner_desc[0]}_splat", *inner_desc[1..]]
          end
        when :send
          recv_node, mname, *_args = node.children
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          # Method name should be foo= for attribute assignment
          [:call, receiver_ast, mname]
        when :mlhs
          sub = node.children.map { |ch| parse_masgn_target(ch) }
          [:nested, sub]
        else
          # Fallback
          [:local, :_, 0]
        end
      end

      def transform_masgn(node)
        lhs_node, rhs_node = node.children[0], node.children[1]
        targets = lhs_node.children.map { |t| parse_masgn_target(t) }
        Ast::MultipleAssignment.new(targets, transform(rhs_node))
      end

      # -----------------------------------------------------------------------
      # Operator assignment transformations
      # -----------------------------------------------------------------------

      def transform_op_asgn(node)
        target_node, op, value_node = node.children[0], node.children[1], node.children[2]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d    = @scope_chain.register_write(name)
          read = Ast::LocalVariableRead.new(name, d)
          rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::LocalVariableWrite.new(name, d, rhs)

        when :ivasgn
          name = target_node.children[0]
          read = Ast::InstanceVariableRead.new(name)
          rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::InstanceVariableWrite.new(name, rhs)

        when :cvasgn
          name = target_node.children[0]
          read = Ast::ClassVariableRead.new(name)
          rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::ClassVariableWrite.new(name, rhs)

        when :gvasgn
          name = target_node.children[0]
          read = Ast::GlobalVariableRead.new(name)
          rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::GlobalVariableWrite.new(name, rhs)

        when :casgn
          parent, name = target_node.children[0], target_node.children[1]
          if parent.nil? || parent.type == :cbase
            read = Ast::ConstantRead.new(name)
            rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
            Ast::ConstantWrite.new(name, rhs)
          else
            parent_ast = transform(parent)
            read = Ast::ConstantPath.new(parent_ast, name)
            rhs  = Ast::MethodCall.new(op, read, [transform(value_node)], {})
            Ast::ConstantPathWrite.new(parent_ast, name, rhs)
          end

        when :send, :csend
          recv_node, mname, *index_args = target_node.children
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          safe_nav = (target_node.type == :csend)
          if mname == :[]
            index_arg_nodes = index_args.map { |a| transform(a) }
            val_node = transform(value_node)
            Ast::IndexOperatorWrite.new(op, receiver_ast, index_arg_nodes, val_node)
          else
            read_name  = mname
            write_name = :"#{mname}="
            val_node = transform(value_node)
            Ast::CallOperatorWrite.new(read_name, write_name, op, receiver_ast, val_node, safe_nav: safe_nav)
          end

        else
          # Fallback
          Ast::NilLiteral::NIL
        end
      end

      def transform_or_asgn(node)
        target_node, value_node = node.children[0], node.children[1]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d    = @scope_chain.register_write(name)
          read  = Ast::LocalVariableRead.new(name, d)
          write = Ast::LocalVariableWrite.new(name, d, transform(value_node))
          Ast::Or.new(read, write)

        when :ivasgn
          name = target_node.children[0]
          Ast::Or.new(Ast::InstanceVariableRead.new(name),
                      Ast::InstanceVariableWrite.new(name, transform(value_node)))

        when :cvasgn
          name = target_node.children[0]
          Ast::Or.new(Ast::ClassVariableRead.new(name),
                      Ast::ClassVariableWrite.new(name, transform(value_node)))

        when :gvasgn
          name = target_node.children[0]
          Ast::Or.new(Ast::GlobalVariableRead.new(name),
                      Ast::GlobalVariableWrite.new(name, transform(value_node)))

        when :casgn
          parent, name = target_node.children[0], target_node.children[1]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantOrWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathOrWrite.new(transform(parent), name, transform(value_node))
          end

        when :send, :csend
          recv_node, mname, *index_args = target_node.children
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          safe_nav = (target_node.type == :csend)
          if mname == :[]
            index_arg_nodes = index_args.map { |a| transform(a) }
            Ast::IndexOrWrite.new(receiver_ast, index_arg_nodes, transform(value_node))
          else
            Ast::CallOrWrite.new(mname, :"#{mname}=", receiver_ast, transform(value_node), safe_nav: safe_nav)
          end

        else
          Ast::NilLiteral::NIL
        end
      end

      def transform_and_asgn(node)
        target_node, value_node = node.children[0], node.children[1]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d    = @scope_chain.register_write(name)
          read  = Ast::LocalVariableRead.new(name, d)
          write = Ast::LocalVariableWrite.new(name, d, transform(value_node))
          Ast::And.new(read, write)

        when :ivasgn
          name = target_node.children[0]
          Ast::And.new(Ast::InstanceVariableRead.new(name),
                       Ast::InstanceVariableWrite.new(name, transform(value_node)))

        when :cvasgn
          name = target_node.children[0]
          Ast::And.new(Ast::ClassVariableRead.new(name),
                       Ast::ClassVariableWrite.new(name, transform(value_node)))

        when :gvasgn
          name = target_node.children[0]
          Ast::And.new(Ast::GlobalVariableRead.new(name),
                       Ast::GlobalVariableWrite.new(name, transform(value_node)))

        when :casgn
          parent, name = target_node.children[0], target_node.children[1]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantAndWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathAndWrite.new(transform(parent), name, transform(value_node))
          end

        when :send, :csend
          recv_node, mname, *index_args = target_node.children
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          safe_nav = (target_node.type == :csend)
          if mname == :[]
            index_arg_nodes = index_args.map { |a| transform(a) }
            Ast::IndexAndWrite.new(receiver_ast, index_arg_nodes, transform(value_node))
          else
            Ast::CallAndWrite.new(mname, :"#{mname}=", receiver_ast, transform(value_node), safe_nav: safe_nav)
          end

        else
          Ast::NilLiteral::NIL
        end
      end

      # -----------------------------------------------------------------------
      # Case transformation
      # -----------------------------------------------------------------------

      def transform_case(node)
        c = node.children
        subject_node = c[0]
        subject_ast  = subject_node ? transform(subject_node) : nil

        whens    = []
        else_ast = nil

        c[1..].each do |child|
          next if child.nil?
          case child.type
          when :when
            conds = child.children[0..-2].map { |cnd| transform(cnd) }
            body_node = child.children.last
            body_ast  = body_node.nil? ? Ast::NilLiteral::NIL : transform(body_node)
            whens << Ast::Case::When.new(conds, body_ast)
          else
            # else branch
            else_ast = transform(child)
          end
        end

        Ast::Case.new(subject_ast, whens, else_ast)
      end

      # -----------------------------------------------------------------------
      # Rescue / ensure transformation
      # -----------------------------------------------------------------------

      # Transform a :rescue node into Ast::Rescue.
      # Optionally wrap with an ensure clause.
      def transform_rescue_node(rescue_node, else_node_arg, ensure_node_arg)
        c = rescue_node.children
        # c[0] = body, c[1..] = resbodies except last which is the else
        body_node = c[0]
        body_ast  = transform(body_node)

        rescue_clauses = []
        else_ast = nil

        c[1..].each do |child|
          next if child.nil?
          if child.type == :resbody
            rescue_clauses << transform_resbody(child)
          else
            # The else branch appears as a non-resbody at the end
            else_ast = transform(child)
          end
        end

        else_ast ||= else_node_arg ? transform(else_node_arg) : nil
        ensure_ast = ensure_node_arg ? transform(ensure_node_arg) : nil

        Ast::Rescue.new(body_ast, rescue_clauses, else_ast, ensure_ast)
      end

      def transform_ensure_node(ensure_node)
        body_node, ensure_clause_node = ensure_node.children[0], ensure_node.children[1]
        ensure_ast = transform(ensure_clause_node)

        if body_node.nil?
          Ast::Rescue.new(Ast::NilLiteral::NIL, [], nil, ensure_ast)
        elsif body_node.type == :rescue
          result = transform_rescue_node(body_node, nil, nil)
          # Wrap result's ensure
          Ast::Rescue.new(result.instance_variable_get(:@body),
                          result.instance_variable_get(:@rescue_clauses),
                          result.instance_variable_get(:@else_node),
                          ensure_ast)
        else
          body_ast = transform(body_node)
          Ast::Rescue.new(body_ast, [], nil, ensure_ast)
        end
      end

      def transform_resbody(resbody_node)
        exc_node, var_node, body_node = resbody_node.children[0],
                                        resbody_node.children[1],
                                        resbody_node.children[2]

        exc_nodes = if exc_node.nil?
          []
        else
          exc_node.children.map { |e| transform(e) }
        end

        var_name   = nil
        var_depth  = nil
        assign_node = nil

        if var_node
          case var_node.type
          when :lvasgn
            name = var_node.children[0]
            d = @scope_chain.register_write(name)
            var_name  = name
            var_depth = d
          when :ivasgn
            assign_node = Ast::InstanceVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :gvasgn
            assign_node = Ast::GlobalVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :cvasgn
            assign_node = Ast::ClassVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :casgn
            assign_node = Ast::ConstantWrite.new(var_node.children[1], Ast::NilLiteral::NIL)
          end
        end

        body_ast = body_node.nil? ? Ast::NilLiteral::NIL : transform(body_node)
        Ast::RescueClause.new(exc_nodes, var_name, var_depth, body_ast, assign_node: assign_node)
      end

      # -----------------------------------------------------------------------
      # Begin / kwbegin transformation
      # -----------------------------------------------------------------------

      def transform_begin_seq(children)
        stmts = children.filter_map { |ch| transform(ch) }
        return Ast::NilLiteral::NIL if stmts.empty?
        stmts.length == 1 ? stmts[0] : Ast::Sequence.new(stmts)
      end

      def transform_kwbegin(node)
        children = node.children
        return Ast::NilLiteral::NIL if children.empty?
        # Multiple direct children = statement list (e.g. in or_asgn value)
        if children.length > 1
          return Ast::Sequence.new(children.map { |c| transform(c) })
        end
        inner = children[0]
        case inner.type
        when :rescue
          transform_rescue_node(inner, nil, nil)
        when :ensure
          transform_ensure_node(inner)
        when :begin
          transform_begin_seq(inner.children)
        else
          transform(inner)
        end
      end

      def transform_kwbegin_body(node)
        return Ast::NilLiteral::NIL if node.nil?
        return transform(node) unless node.type == :kwbegin
        children = node.children
        return Ast::NilLiteral::NIL if children.empty?
        # kwbegin in while_post can have multiple statement children
        stmts = children.map { |c| transform(c) }
        stmts.length == 1 ? stmts[0] : Ast::Sequence.new(stmts)
      end

      # -----------------------------------------------------------------------
      # Defined? transformation
      # -----------------------------------------------------------------------

      def transform_defined(val_node)
        return Ast::DefinedExpr.new(:expression) if val_node.nil?

        case val_node.type
        when :self
          Ast::DefinedExpr.new(:self)
        when :nil
          Ast::DefinedExpr.new(:nil)
        when :true
          Ast::DefinedExpr.new(:true)
        when :false
          Ast::DefinedExpr.new(:false)
        when :int, :float, :str, :sym, :rational, :complex, :hash, :lambda
          Ast::DefinedExpr.new(:literal)
        when :dstr, :dsym
          Ast::DefinedExpr.new(:literal)
        when :array
          element_checks = val_node.children.map do |e|
            e.type == :splat ? Ast::DefinedExpr.new(:expression) : transform_defined(e)
          end
          Ast::DefinedExpr.new(:array_literal, element_checks)
        when :const
          parent, name = val_node.children[0], val_node.children[1]
          if parent.nil? || parent.type == :cbase
            Ast::DefinedExpr.new(:constant, Ast::ConstantRead.new(name))
          else
            Ast::DefinedExpr.new(:constant, transform(val_node))
          end
        when :lvar
          Ast::DefinedExpr.new(:local_var)
        when :ivar
          Ast::DefinedExpr.new(:ivar, val_node.children[0])
        when :cvar
          Ast::DefinedExpr.new(:cvar, val_node.children[0])
        when :gvar
          Ast::DefinedExpr.new(:gvar, val_node.children[0])
        when :back_ref
          Ast::DefinedExpr.new(:back_ref, val_node.children[0])
        when :nth_ref
          Ast::DefinedExpr.new(:num_ref, val_node.children[0])
        when :send, :csend
          recv_node = val_node.children[0]
          method_name = val_node.children[1]
          receiver_ast = recv_node ? transform(recv_node) : nil
          receiver_defined = recv_node ? transform_defined(recv_node) : nil
          Ast::DefinedExpr.new(:method, [receiver_ast, method_name, receiver_defined])
        when :yield
          Ast::DefinedExpr.new(:yield)
        when :super, :zsuper
          Ast::DefinedExpr.new(:super)
        when :lvasgn, :ivasgn, :cvasgn, :gvasgn, :casgn, :masgn,
             :op_asgn, :or_asgn, :and_asgn
          if val_node.type == :lvasgn && val_node.children.length >= 2
            Ast::DefinedExpr.new(:assignment)
          elsif val_node.type == :lvasgn
            # Bare lvasgn — treat as expression
            Ast::DefinedExpr.new(:expression)
          else
            Ast::DefinedExpr.new(:assignment)
          end
        when :begin, :kwbegin
          inner = val_node.children[0]
          inner ? transform_defined(inner) : Ast::DefinedExpr.new(:expression)
        when :block, :numblock, :if, :while, :until, :for, :case,
             :and, :or, :return, :break, :next, :redo, :retry,
             :regexp, :irange, :erange, :defined?
          Ast::DefinedExpr.new(:expression)
        else
          Ast::NilLiteral::NIL
        end
      end

      # -----------------------------------------------------------------------
      # For-loop target parsing
      # -----------------------------------------------------------------------

      def parse_for_target(node)
        case node.type
        when :lvasgn
          name = node.children[0]
          @scope_chain.register_write(name)
          [:local, name]
        when :ivasgn
          [:ivar, node.children[0]]
        when :cvasgn
          [:cvar, node.children[0]]
        when :gvasgn
          [:gvar, node.children[0]]
        when :mlhs
          lefts  = []
          rest   = nil
          rights = []
          seen_splat = false

          node.children.each do |ch|
            next if ch.nil?
            case ch.type
            when :lvasgn
              name = ch.children[0]
              @scope_chain.register_write(name)
              seen_splat ? rights << name : lefts << name
            when :splat
              seen_splat = true
              inner = ch.children[0]
              if inner
                name = inner.children[0]
                @scope_chain.register_write(name)
                rest = name
              end
            end
          end

          [:multi, lefts, rest, rights]
        when :send
          recv_node, mname = node.children[0], node.children[1]
          recv_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          [:call, recv_ast, mname]
        else
          begin
            name = node.children[0]
            @scope_chain.register_write(name) if name.is_a?(Symbol)
            [:local, name]
          rescue
            [:local, :_]
          end
        end
      end

      # -----------------------------------------------------------------------
      # Constant name extraction
      # -----------------------------------------------------------------------

      def extract_const_name(const_node)
        parent = const_node.children[0]
        name   = const_node.children[1]
        if parent.nil?
          [name, nil]
        elsif parent.type == :cbase
          [name, Ast::RootNamespaceNode::INSTANCE]
        else
          [name, transform(parent)]
        end
      end

      # -----------------------------------------------------------------------
      # Hash pair helpers
      # -----------------------------------------------------------------------

      def transform_hash_pairs(hash_node)
        hash_node.children.map do |kv|
          case kv.type
          when :pair
            [transform(kv.children[0]), transform(kv.children[1])]
          when :kwsplat
            splat_val = kv.children[0].nil? ?
              Ast::LocalVariableRead.new(:__anon_kwargs__, 0) :
              transform(kv.children[0])
            [nil, splat_val]
          else
            raise "Unexpected hash element: #{kv.type}"
          end
        end
      end

      # -----------------------------------------------------------------------
      # Interpolated string / symbol parts
      # -----------------------------------------------------------------------

      def transform_dstr_parts(node)
        node.children.map do |part|
          case part.type
          when :str
            Ast::StringLiteral.from(part.children[0])
          when :begin
            # s(:begin, expr) — the interpolated expression
            transform_begin_part(part)
          else
            transform(part)
          end
        end
      end

      def transform_begin_part(part)
        # s(:begin, ...) inside interpolation: single child = the expr
        inner = part.children[0]
        inner ? transform(inner) : Ast::NilLiteral::NIL
      end

      # -----------------------------------------------------------------------
      # Regexp flag parsing
      # -----------------------------------------------------------------------

      def parse_regexp_flags(opts_node)
        flags = 0
        return flags if opts_node.nil? || opts_node.type != :regopt
        opts_node.children.each do |flag|
          case flag
          when :i then flags |= Regexp::IGNORECASE
          when :m then flags |= Regexp::MULTILINE
          when :x then flags |= Regexp::EXTENDED
          end
        end
        flags
      end

      # -----------------------------------------------------------------------
      # Misc helpers
      # -----------------------------------------------------------------------

      # For return/break/next: if c[0] is a begin node with one element, unwrap it
      def transform_first_arg(node)
        return nil if node.nil?
        if node.type == :begin && node.children.length == 1
          transform(node.children[0])
        else
          transform(node)
        end
      end

      def transform_numeric_value(val)
        case val
        when Integer then Ast::IntegerLiteral.from(val)
        when Float   then Ast::FloatLiteral.from(val)
        else              Ast::IntegerLiteral.from(0)
        end
      end
    end
  end
end

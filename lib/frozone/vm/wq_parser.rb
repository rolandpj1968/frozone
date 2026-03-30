require 'parser/ruby40'

require_relative '../ast'

module Frozone
  module Vm
    class WqParser
      # Scope chain for tracking local variable ownership and depth.
      # Variables are claimed in left-to-right, top-down order as we transform.
      class ScopeChain
        Scope = Struct.new(:claimed, :kind)  # kind: :method or :block

        def initialize(initial_names = [])
          @stack = []
          push(:method, initial_names)  # top-level acts like a method scope
        end

        def push(kind, initial_names) = @stack.push(Scope.new(Set.new(initial_names), kind))

        def pop = @stack.pop

        def current = @stack.last

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

      def initialize(text, dump_ast = false, filepath: nil, outer_locals: nil, encoding: nil, line: nil, forwarding: nil)
        @text = text
        @dump_ast = dump_ast
        @filepath = filepath
        @outer_locals = outer_locals
        @encoding = encoding
        @line = line
      end

      def ast(raise_syntax_errors: false)
        # Extract source encoding from magic comment before parsing
        # so the buffer is given the right encoding (affects string literal values).
        magic_enc = extract_magic_comment_encoding(@text)
        @source_encoding = magic_enc || @encoding || Encoding::UTF_8

        # Re-encode the source bytes with the detected encoding so the parser
        # emits string literals with the correct encoding.
        src =
          if magic_enc && magic_enc != Encoding::UTF_8 && @text.encoding == Encoding::UTF_8
            @text.dup.force_encoding(magic_enc)
          else
            @text
          end

        buf = ::Parser::Source::Buffer.new(@filepath || '(string)', @line || 1, source: src)
        ::Parser::Builders::Default.modernize
        # After modernize, emit_arg_inside_procarg0=true makes |a| and |(a)| AST-identical.
        # Set it to false so |a| -> s(:procarg0, :a) and |(a)| -> s(:procarg0, s(:arg, :a)).
        ::Parser::Builders::Default.emit_arg_inside_procarg0 = false

        wq_ast = parse_with_recovery(buf, src, raise_syntax_errors)

        puts wq_ast.inspect if @dump_ast

        validate_semantics!(wq_ast) if raise_syntax_errors && wq_ast

        @scope_chain = ScopeChain.new(@outer_locals || [])
        @raise_syntax_errors = raise_syntax_errors
        @prism_always_warnings = []
        @prism_verbose_warnings = []
        result = transform(wq_ast)
        @top_level_locals = @scope_chain.current.claimed.to_a
        result || Ast::NilLiteral::NIL
      end

      def top_level_locals = @top_level_locals || []

      def prism_always_warnings  = @prism_always_warnings  || []

      def prism_verbose_warnings = @prism_verbose_warnings || []

      private

      # Returns true for whitequark SyntaxErrors that are NOT real errors in Ruby 3.4+.
      # Parse `buf` with full error detection, then recover from known suppressable errors.
      # Always tries fatal mode first to detect error type, then applies targeted recovery.
      def parse_with_recovery(buf, src, raise_syntax_errors)
        # Always try with all_errors_are_fatal:true first so we can detect error type
        # and apply targeted recovery (e.g. ASCII-8BIT retry for binary string literals).
        # This ensures recovery works even when raise_syntax_errors is false.
        wq = make_wq_parser(all_errors_are_fatal: true)
        begin
          wq.parse(buf)
        rescue => e
          msg = e.message
          if msg.include?("literal contains escape sequences incompatible")
            # Non-UTF-8 bytes in string literal: retry with ASCII-8BIT source encoding.
            orig_encoding = @source_encoding
            bin_src = src.dup.force_encoding(Encoding::ASCII_8BIT)
            bin_buf = ::Parser::Source::Buffer.new(buf.name, @line || 1, source: bin_src)
            @source_encoding = Encoding::ASCII_8BIT
            result = begin
              make_wq_parser(all_errors_are_fatal: raise_syntax_errors).parse(bin_buf)
            rescue => e2
              raise_or_recover(e2, bin_buf, raise_syntax_errors)
            end
            # If the original encoding was UTF-8 and raise_syntax_errors is on,
            # check for sym nodes with invalid UTF-8 bytes (e.g. :"\xC3") —
            # these are parse-time SyntaxErrors in MRI >= 3.4.
            if raise_syntax_errors && orig_encoding != Encoding::ASCII_8BIT
              validate_sym_encoding!(result, orig_encoding || Encoding::UTF_8)
            end
            # Restore original encoding so that transform phase re-encodes
            # valid string/symbol literals back to their correct encoding via
            # apply_source_encoding, while genuinely binary strings stay binary.
            @source_encoding = orig_encoding
            result
          elsif msg.include?("circular argument reference")
            # Ruby 3.4+: circular arg defaults are valid (yield nil). Patch source and retry.
            patch_circular_arg_ref(src, raise_syntax_errors)
          elsif raise_syntax_errors && !suppress_wq_error?(msg)
            raise FrozoneException.make(:SyntaxError, normalize_syntax_error_message(msg))
          else
            nil
          end
        end
      end

      def make_wq_parser(all_errors_are_fatal:)
        wq = ::Parser::Ruby40.new
        wq.diagnostics.all_errors_are_fatal = all_errors_are_fatal
        wq.diagnostics.ignore_warnings = true
        @outer_locals&.each { |name| wq.static_env.declare(name) }
        wq
      end

      def raise_or_recover(e, buf, raise_syntax_errors)
        if raise_syntax_errors && !suppress_wq_error?(e.message)
          raise FrozoneException.make(:SyntaxError, normalize_syntax_error_message(e.message))
        end
        begin
          make_wq_parser(all_errors_are_fatal: false).parse(buf)
        rescue
          nil
        end
      end

      def patch_circular_arg_ref(src, raise_syntax_errors)
        patched = src.dup
        loop do
          wq_r = make_wq_parser(all_errors_are_fatal: true)
          patched_buf = ::Parser::Source::Buffer.new(@filepath || '(string)', source: patched)
          begin
            return wq_r.parse(patched_buf)
          rescue => e
            if e.message.include?("circular argument reference")
              arg_name = e.message.split.last
              patched = patched.sub(/\b#{Regexp.escape(arg_name)}\s*=\s*#{Regexp.escape(arg_name)}\b/, "#{arg_name} = nil")
            else
              return raise_or_recover(e, patched_buf, raise_syntax_errors)
            end
          end
        end
      end

      def suppress_wq_error?(msg)
        # Circular argument reference was a SyntaxError before Ruby 3.4; now it's allowed.
        msg.include?("circular argument reference")
      end

      # Normalize whitequark SyntaxError messages to match Ruby's expected messages.
      def normalize_syntax_error_message(msg)
        # "literal contains escape sequences incompatible with UTF-8" → "invalid symbol"
        return "invalid symbol" if msg.include?("literal contains escape sequences incompatible")
        msg
      end

      # -----------------------------------------------------------------------
      # Semantic validation (raise SyntaxError for invalid usages)
      # -----------------------------------------------------------------------

      # Context values used during semantic validation walk.
      # :top_level   - top-level program / class / module body (yield invalid, break/next/redo invalid)
      # :method      - inside a method def (yield valid, break/next/redo invalid unless in loop/block)
      # :block       - inside a block (yield propagates up, break/next/redo valid)
      # :loop        - inside a while/until/for loop (break/next/redo valid)
      # :rescue      - inside a rescue clause (retry valid)

      # Nodes that create a new method scope (break/next/redo/yield reset)
      METHOD_BOUNDARY_NODES = %i[def defs].freeze

      # Nodes that create a new block scope (break/next/redo valid, yield propagates)
      BLOCK_LIKE_NODES = %i[block numblock].freeze

      # Nodes that represent loops (break/next/redo valid)
      LOOP_NODES = %i[while until for while_post until_post].freeze

      # Nodes that create a class/module scope (break/next/redo/yield reset to invalid)
      CLASS_BOUNDARY_NODES = %i[class module sclass].freeze

      # Walk AST looking for :sym nodes with bytes invalid in enc.
      # Raises SyntaxError (as MRI >= 3.4 does) for e.g. :"\xC3" in UTF-8 source.
      def validate_sym_encoding!(node, enc)
        return unless node.is_a?(::Parser::AST::Node)
        if node.type == :sym
          sym_name = node.children[0].to_s
          sym_bytes = sym_name.dup.force_encoding(enc)
          unless sym_bytes.valid_encoding?
            raise FrozoneException.make(:SyntaxError, "invalid symbol in encoding #{enc}")
          end
        end
        node.children.each { |child| validate_sym_encoding!(child, enc) }
      end

      def validate_semantics!(node)
        # Walk the whole file at top-level; context tracks what's valid.
        # context is a Hash with:
        #   :in_method  => true if directly inside a method def (yield valid)
        #   :in_loop    => true if directly inside a loop/block (break/next/redo valid)
        #   :in_block   => true if inside a block (used for yield-in-block check)
        #   :in_rescue  => true if inside a rescue clause (retry valid)
        validate_node(node, in_method: false, in_loop: false, in_block: false, in_rescue: false)
      end

      def validate_node(node, in_method:, in_loop:, in_block:, in_rescue:)
        return unless node.is_a?(::Parser::AST::Node)

        type = node.type

        case type
        when :break
          unless in_loop
            raise FrozoneException.make(:SyntaxError, "Invalid break")
          end

        when :next
          unless in_loop
            raise FrozoneException.make(:SyntaxError, "Invalid next")
          end

        when :redo
          unless in_loop
            raise FrozoneException.make(:SyntaxError, "Invalid redo")
          end

        when :retry
          unless in_rescue
            raise FrozoneException.make(:SyntaxError, "Invalid retry")
          end

        when :yield
          # yield is invalid at top level, in module/class body, and in non-lambda block at top level
          if !in_method && !in_block
            raise FrozoneException.make(:SyntaxError, "Invalid yield")
          elsif in_block && !in_method
            raise FrozoneException.make(:SyntaxError, "Invalid yield")
          end

        when *METHOD_BOUNDARY_NODES
          # Inside a method: yield valid, break/next/redo invalid unless in loop/block
          node.children.each do |child|
            validate_node(child, in_method: true, in_loop: false, in_block: false, in_rescue: false)
          end
          return

        when *CLASS_BOUNDARY_NODES
          # Inside class/module: everything resets to invalid
          node.children.each do |child|
            validate_node(child, in_method: false, in_loop: false, in_block: false, in_rescue: false)
          end
          return

        when *LOOP_NODES
          # Inside a loop: break/next/redo valid; yield/retry status unchanged
          node.children.each do |child|
            validate_node(child, in_method: in_method, in_loop: true, in_block: in_block, in_rescue: in_rescue)
          end
          return

        when *BLOCK_LIKE_NODES
          # Inside a block: check if it's a lambda block (-> {})
          send_child = node.children[0]
          is_arrow_lambda = send_child.is_a?(::Parser::AST::Node) && send_child.type == :lambda
          if is_arrow_lambda
            # Arrow lambda: like a method (break/next/redo/yield all valid inside)
            node.children.each do |child|
              validate_node(child, in_method: true, in_loop: false, in_block: false, in_rescue: false)
            end
          else
            # Regular block: break/next/redo valid; yield propagates from enclosing method
            node.children.each do |child|
              validate_node(child, in_method: in_method, in_loop: true, in_block: true, in_rescue: in_rescue)
            end
          end
          return

        when :resbody
          # Inside rescue body: retry valid
          node.children.each do |child|
            validate_node(child, in_method: in_method, in_loop: in_loop, in_block: in_block, in_rescue: true)
          end
          return

        when :lvasgn, :ivasgn, :cvasgn, :gvasgn, :casgn, :masgn
          # Assignment: check for void value expression in value position.
          # Children: [name, value] for lvasgn/ivasgn/cvasgn/gvasgn; [scope, name, value] for casgn.
          value_child = node.children.last
          if value_child.is_a?(::Parser::AST::Node) && void_value_expr?(value_child)
            raise FrozoneException.make(:SyntaxError, "void value expression")
          end
          # lvasgn with a non-ASCII uppercase name inside a method is a dynamic constant assignment.
          # wq parser lexes e.g. `ἍBB = 1` as lvasgn (not casgn) because it doesn't know Unicode.
          if node.type == :lvasgn && in_method
            name = node.children[0].to_s
            if name.match?(/\A\p{Lu}/u) && !name.match?(/\A[A-Z]/)
              raise FrozoneException.make(:SyntaxError, "dynamic constant assignment")
            end
          end

        when :op_asgn, :or_asgn, :and_asgn
          # Operator assignment: value is last child
          value_child = node.children.last
          if value_child.is_a?(::Parser::AST::Node) && void_value_expr?(value_child)
            raise FrozoneException.make(:SyntaxError, "void value expression")
          end
        end

        node.children.each do |child|
          validate_node(child, in_method: in_method, in_loop: in_loop, in_block: in_block, in_rescue: in_rescue)
        end
      end

      # Returns true if node is a void-value expression (cannot produce a value).
      # This includes: return, break, next, and if/unless/case where ALL branches are void.
      def void_value_expr?(node)
        return false unless node.is_a?(::Parser::AST::Node)
        case node.type
        when :return, :break, :next
          true
        when :if
          # Both branches must be void
          then_branch = node.children[1]
          else_branch = node.children[2]
          void_value_expr?(then_branch) && void_value_expr?(else_branch)
        when :begin
          # Sequence: only last statement matters
          last = node.children.last
          void_value_expr?(last)
        else
          false
        end
      end

      # -----------------------------------------------------------------------
      # Main transform dispatch
      # -----------------------------------------------------------------------

      def transform(node)
        return Ast::NilLiteral::NIL if node.nil?

        type = node.type
        c = node.children

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
          # Rational literal r — represent as Rational(numerator, denominator)
          # Whitequark: s(:rational, (5/1)) — single Ruby Rational child
          # Prism: separate integer numerator/denominator
          val = c[0]
          if val.is_a?(::Rational)
            num_ast = Ast::IntegerLiteral.from(val.numerator)
            den_ast = Ast::IntegerLiteral.from(val.denominator)
          else
            num_ast = Ast::IntegerLiteral.from(val)
            den_ast = Ast::IntegerLiteral.from(c[1] || 1)
          end
          Ast::MethodCall.new(:Rational, nil, [num_ast, den_ast], {})

        when :complex
          # Complex literal — represent as Complex(real, imag)
          # Whitequark: s(:complex, (0+5i)) — single Ruby Complex child
          # Prism: separate real/imag parts
          val = c[0]
          if val.is_a?(::Complex)
            real_ast = transform_numeric_value(val.real)
            imag_ast = transform_numeric_value(val.imaginary)
          else
            real_ast = transform_numeric_value(val)
            imag_ast = transform_numeric_value(c[1])
          end
          Ast::MethodCall.new(:Complex, nil, [real_ast, imag_ast], {})

        when :str
          Ast::StringLiteral.from(apply_source_encoding(c[0]))

        when :dstr
          Ast::InterpolatedString.new(transform_dstr_parts(node), @source_encoding)

        when :sym
          Ast::SymbolLiteral.from(apply_source_encoding_sym(c[0]))

        when :dsym
          parts = transform_dstr_parts(node)
          Ast::MethodCall.new(:to_sym, Ast::InterpolatedString.new(parts, @source_encoding), [], {})

        when :regexp
          # s(:regexp, str_or_parts..., s(:regopt, :i, :m, ...))
          opts_node = c.last
          flags, enc_name = parse_regexp_flags(opts_node)
          parts = c[0..-2]
          if parts.length == 1 && parts[0].type == :str
            Ast::RegexpLiteral.new(parts[0].children[0], flags, enc_name)
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
          parent = c[0]
          name = c[1]
          if parent.nil?
            Ast::ConstantRead.new(name)
          elsif parent.type == :cbase
            # ::Name — absolute constant path from root namespace
            Ast::ConstantPath.new(Ast::RootNamespaceNode::INSTANCE, name)
          else
            Ast::ConstantPath.new(transform(parent), name)
          end

        when :cbase
          Ast::RootNamespaceNode::INSTANCE

        when :casgn
          parent = c[0]
          name = c[1]
          value_node = c[2]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathWrite.new(transform(parent), name, transform(value_node))
          end

        # --- Method calls ----------------------------------------------------

        when :send, :csend
          transform_send(node)

        when :index
          # With Builder::Default.modernize: arr[i] → s(:index, arr, i, ...)
          recv_node, *arg_nodes = node.children
          receiver_ast = recv_node ? transform(recv_node) : nil
          arg_asts, kw_args, kw_splats, block_ast = parse_call_args(arg_nodes)
          Ast::MethodCall.new(:[], receiver_ast, arg_asts, kw_args, block_ast,
                              kw_splat_nodes: kw_splats)

        when :indexasgn
          # With Builder::Default.modernize: arr[i] = v → s(:indexasgn, arr, i, v)
          # Last child is the value; the rest are receiver + index args.
          # Use AttributeWrite so the expression evaluates to the assigned value.
          children = node.children
          recv_node = children[0]
          val_node = children[-1]
          idx_nodes = children[1..-2]
          receiver_ast = recv_node ? transform(recv_node) : nil
          idx_asts = idx_nodes.map { |a| transform(a) }
          val_ast = transform(val_node)
          Ast::AttributeWrite.new(:[]=, receiver_ast, idx_asts + [val_ast], {})

        when :block
          transform_block(node)

        when :numblock
          transform_numblock(node)

        when :lambda
          # Bare s(:lambda) — shouldn't appear outside s(:block) but handle gracefully
          Ast::Lambda.new([], [], nil, [], [], [], nil, nil, [], Ast::NilLiteral::NIL)

        # --- Defs ------------------------------------------------------------

        when :def
          name = c[0]
          args_node = c[1]
          body_node = c[2]
          def_line = node.location&.line
          transform_def(name, nil, args_node, body_node, def_line: def_line)

        when :defs
          recv_node = c[0]
          name = c[1]
          args_node = c[2]
          body_node = c[3]
          def_line = node.location&.line
          transform_def(name, transform(recv_node), args_node, body_node, def_line: def_line)

        # --- Classes / Modules -----------------------------------------------

        when :class
          const_node = c[0]
          superclass_node = c[1]
          body_node = c[2]
          name, namespace_node = extract_const_name(const_node)
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          superclass_ast = superclass_node ? transform(superclass_node) : nil
          Ast::ClassDef.new(name, locals, superclass_ast, body_ast, namespace_node: namespace_node)

        when :module
          const_node = c[0]
          body_node = c[1]
          name, namespace_node = extract_const_name(const_node)
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          Ast::ModuleDef.new(name, locals, body_ast, namespace_node: namespace_node)

        when :sclass
          expr_node = c[0]
          body_node = c[1]
          @scope_chain.push(:method, [])
          body_ast = transform(body_node)
          locals = @scope_chain.pop.claimed.to_a
          Ast::SingletonClassDef.new(transform(expr_node), locals, body_ast)

        # --- Control flow ----------------------------------------------------

        when :if
          cond_node = c[0]
          then_node = c[1]
          else_node = c[2]
          Ast::If.new(transform(cond_node), transform(then_node), transform(else_node))

        when :unless
          cond_node = c[0]
          then_node = c[1]
          else_node = c[2]
          # unless cond; body; else alt; end == if cond; alt; else body; end
          Ast::If.new(transform(cond_node), transform(else_node), transform(then_node))

        when :while
          cond = c[0]
          body = c[1]
          body_ast = body.nil? ? Ast::NilLiteral::NIL : transform(body)
          Ast::While.new(transform(cond), body_ast, begin_modifier: false)

        when :while_post
          cond = c[0]
          body = c[1]
          Ast::While.new(transform(cond), transform_kwbegin_body(body), begin_modifier: true)

        when :until
          cond = c[0]
          body = c[1]
          body_ast = body.nil? ? Ast::NilLiteral::NIL : transform(body)
          Ast::Until.new(transform(cond), body_ast, begin_modifier: false)

        when :until_post
          cond = c[0]
          body = c[1]
          Ast::Until.new(transform(cond), transform_kwbegin_body(body), begin_modifier: true)

        when :for
          target_node = c[0]
          collection_node = c[1]
          body_node = c[2]
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
          value_node =
            if c.empty?
              nil
            elsif c.length == 1
              transform_first_arg(c[0])
            else
              Ast::ArrayLiteral.new(c.map { |a| transform(a) })
            end
          Ast::Return.new(value_node)

        when :break
          value_node =
            if c.empty?
              nil
            elsif c.length == 1
              transform_first_arg(c[0])
            else
              Ast::ArrayLiteral.new(c.map { |a| transform(a) })
            end
          Ast::Break.new(value_node)

        when :next
          value_node =
            if c.empty?
              nil
            elsif c.length == 1
              transform_first_arg(c[0])
            else
              Ast::ArrayLiteral.new(c.map { |a| transform(a) })
            end
          Ast::Next.new(value_node)

        when :redo
          Ast::Redo.new

        when :retry
          Ast::Retry.new

        when :yield
          arg_nodes, kw_args, _kw_splats, _block = parse_call_args(c)
          Ast::Yield.new(arg_nodes, kw_args)

        when :super
          arg_nodes, _, kw_splats, block_node = parse_call_args(c)
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
          new_name_node = c[0]
          old_name_node = c[1]
          # Global variable alias: s(:alias, s(:gvar, :$new), s(:gvar/:back_ref, :$old))
          if new_name_node.type == :gvar || new_name_node.type == :back_ref
            new_gvar = new_name_node.children[0]
            old_gvar = old_name_node.children[0]
            Ast::GlobalAlias.new(new_gvar.to_sym, old_gvar.to_sym)
          else
            new_name =
              if new_name_node.type == :sym
                new_name_node.children[0]
              else
                transform(new_name_node)
              end
            old_name =
              if old_name_node.type == :sym
                old_name_node.children[0]
              else
                transform(old_name_node)
              end
            Ast::MethodAlias.new(new_name, old_name)
          end

        when :undef
          stmts = c.map do |sym_node|
            name_node =
              if sym_node.type == :sym
                Ast::SymbolLiteral.from(sym_node.children[0])
              else
                # Dynamic: dsym — evaluate interpolation
                transform(sym_node)
              end
            Ast::IntrinsicCall.new(:module_undef_method, [Ast::SelfLiteral::SELF, name_node])
          end
          stmts.length == 1 ? stmts[0] : Ast::Sequence.new(stmts)

        when :match_with_lvasgn
          # /(?<name>...)/ =~ string — assign named captures to local variables
          regexp_node = c[0]
          str_node = c[1]
          call_node = Ast::MethodCall.new(:=~, transform(regexp_node), [transform(str_node)], {})
          # Extract named captures from the regexp pattern
          pattern = regexp_node.children.select { |ch| ch.is_a?(::Parser::AST::Node) && ch.type == :str }
                               .map { |ch| ch.children[0] }.join
          targets = begin
            Regexp.new(pattern).named_captures.keys.map do |name|
              sym = name.to_sym
              depth = @scope_chain.register_write(sym)
              [depth, sym]
            end
          rescue RegexpError
            []
          end
          targets.empty? ? call_node : Ast::MatchWrite.new(call_node, targets)

        when :match_current_line
          # /regexp/ in conditional context — `$_ =~ /regexp/`
          # Emit warning: "regex literal in condition" (matches Prism's literal_in_condition_default)
          @prism_always_warnings << "regex literal in condition"
          Ast::MethodCall.new(:=~,
                              Ast::GlobalVariableRead.new(:"$_"),
                              [transform(c[0])],
                              {})

        when :iflipflop, :eflipflop
          left_node = c[0] ? transform(c[0]) : Ast::NilLiteral::NIL
          right_node = c[1] ? transform(c[1]) : Ast::NilLiteral::NIL
          exclude_end = (type == :eflipflop)
          left_int = c[0]&.type == :int
          right_int = c[1]&.type == :int
          @prism_always_warnings << "integer literal in flip-flop" if left_int
          @prism_always_warnings << "integer literal in flip-flop" if right_int
          Ast::FlipFlop.new(left_node, right_node, exclude_end,
                            left_int_literal: left_int,
                            right_int_literal: right_int)

        when :preexe
          # BEGIN{} block — hoist body (or nil if empty)
          c[0].nil? ? Ast::NilLiteral::NIL : transform(c[0])

        when :postexe
          # END{} block — run via at_exit stub (Kernel#at_exit is a no-op in frozone)
          body_ast = c[0].nil? ? Ast::NilLiteral::NIL : transform(c[0])
          Ast::MethodCall.new(:at_exit, nil, [], {}, Ast::Block.new([], [], nil, [], [], [], nil, nil, false, [], body_ast))

        when :xstr
          # Backtick command: `cmd` — build string from parts and call `
          # Simple: s(:xstr, s(:str, "content")) — one or more str children
          # Interpolated: s(:xstr, s(:str, "part"), s(:begin, expr), ...) — mixed
          if c.length == 1 && c[0].type == :str
            cmd = Ast::StringLiteral.frozen_from(c[0].children[0])
          else
            parts = c.map do |part|
              case part.type
              when :str   then Ast::StringLiteral.from(part.children[0])
              when :begin then transform_begin_part(part)
              else             transform(part)
              end
            end
            cmd = Ast::InterpolatedString.new(parts, @source_encoding)
          end
          Ast::MethodCall.new(:"`", nil, [cmd], {}, nil)

        when :__FILE__
          Ast::StringLiteral.from(@filepath || "(string)")

        when :__LINE__
          # Not tracking line numbers — return 0 as placeholder
          Ast::IntegerLiteral.from(0)

        when :__ENCODING__
          enc = @source_encoding || Encoding::UTF_8
          enc_const = enc.name.upcase.tr('-', '_').gsub(/[^A-Z0-9_]/, '_').to_sym
          Ast::ConstantPath.new(Ast::ConstantRead.new(:Encoding), enc_const)

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

      # Returns true if the method body uses a block (yield or super).
      # Does NOT recurse into nested defs/classes/lambdas (block boundaries for this check).
      # Note: block_given? does NOT count as using the block (warning still emitted).
      BLOCK_USE_NODES_WQ = %i[yield zsuper super].freeze
      BLOCK_BOUNDARY_NODES_WQ = %i[def defs class module sclass lambda].freeze

      def body_uses_block?(node)
        return false unless node.is_a?(::Parser::AST::Node)
        return true if BLOCK_USE_NODES_WQ.include?(node.type)
        return false if BLOCK_BOUNDARY_NODES_WQ.include?(node.type)
        node.children.any? { |c| body_uses_block?(c) }
      end

      # Returns true if node (WQ AST) contains a bare `it` call anywhere.
      def body_uses_it?(node)
        return false unless node.is_a?(::Parser::AST::Node)
        return true if node.type == :send && node.children[0].nil? &&
                       node.children[1] == :it && node.children.length == 2
        # Don't descend into nested blocks/defs (new scope)
        return false if %i[block numblock def defs class module sclass].include?(node.type)

        node.children.any? { |c| body_uses_it?(c) }
      end

      def transform_send(node)
        type = node.type  # :send or :csend
        c = node.children
        recv_node, name, *raw_args = c[0], c[1], *c[2..]
        safe_nav = (type == :csend)

        # __dir__ — bake directory at parse time (like __FILE__), not runtime file stack
        if recv_node.nil? && name == :__dir__ && raw_args.empty?
          dir = if @filepath.nil? || @filepath.start_with?('(')
                  nil
                else
                  File.dirname(@filepath)
                end
          return dir ? Ast::StringLiteral.from(dir) : Ast::NilLiteral::NIL
        end

        # "literal".freeze — mirrors YARV OPT_STR_FREEZE: returns same frozen object each time,
        # and registers it in the dedup table (matches MRI 4.0 fstring behavior for literals)
        if name == :freeze && raw_args.empty? && recv_node&.type == :str
          return Ast::StringLiteral.frozen_from(recv_node.children[0])
        end

        # `it` as implicit block parameter — treat as lvar read when in scope
        if recv_node.nil? && name == :it && raw_args.empty?
          d = @scope_chain.depth_of(:it)
          return Ast::LocalVariableRead.new(:it, d) unless d.nil?
        end

        # Numbered params _10+ are invalid in Ruby (only _1.._9 are supported).
        # Whitequark emits them as bare method calls. Convert to a runtime NameError.
        if recv_node.nil? && raw_args.empty? && name.to_s =~ /\A_(\d+)\z/ && ::Regexp.last_match(1).to_i >= 10
          n = name
          exc_class = FrozoneException
          return Class.new(Ast::Node) {
            define_method(:evaluate) { |_ctx|
              raise exc_class.make(:NameError, "undefined local variable or method '#{n}' for an instance of Object")
            }
          }.new
        end

        # Frozone.compile! (no-block form — unusual but handle gracefully)
        if recv_node && recv_node.type == :const &&
           recv_node.children[0].nil? && recv_node.children[1] == :Frozone &&
           name == :"compile!"
          return Ast::FrozoneCompile.new(nil)
        end

        # Check for Intrinsics.method_name pattern
        if recv_node && recv_node.type == :const &&
           recv_node.children[0].nil? && recv_node.children[1] == :Intrinsics &&
           name != :new
          arg_nodes = raw_args.map { |a| transform(a) }
          return Ast::IntrinsicCall.new(name, arg_nodes)
        end

        # Build receiver (nil if implicit self, also treat explicit self as implicit)
        receiver_ast =
          if recv_node.nil? || recv_node.type == :self
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

        call_loc = @filepath && node.location ? "#{@filepath}:#{node.location.line}" : nil
        Ast::MethodCall.new(name, receiver_ast, arg_nodes, kw_args, block_node,
                            kw_splat_nodes: kw_splats, safe_nav: safe_nav, source_location: call_loc)
      end

      # -----------------------------------------------------------------------
      # Block transformation
      # -----------------------------------------------------------------------

      def transform_block(node)
        send_node = node.children[0]
        args_node = node.children[1]
        body_node = node.children[2]

        # Detect arrow lambda: s(:block, s(:lambda), ...) — from `-> { }` syntax.
        # With Builder::Default.modernize, `->` lambdas emit s(:lambda) as the block send node.
        # Note: s(:block, s(:send, nil, :lambda), ...) is the `lambda { }` call form — must dispatch
        # to the `lambda` method (so it can be mocked/overridden), not directly create Ast::Lambda.
        is_arrow_lambda = send_node.type == :lambda
        is_lambda_call = (send_node.type == :send &&
                           send_node.children[0].nil? &&
                           send_node.children[1] == :lambda)
        is_lambda = is_arrow_lambda || is_lambda_call

        # Parse block params
        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow, implicit_rest =
          parse_block_args(args_node, is_lambda: is_lambda)

        # Ruby 3.4+: `it` in block/lambda body with no explicit params → implicit first param
        # Explicit params: either param arrays are non-empty OR the args node has a source location
        # (which means `()` or `||` was written explicitly even if no params).
        has_explicit_params = !(required.empty? && optional.empty? && rest.nil? && post.empty? &&
                                req_kw.empty? && opt_kw.empty? && kw_rest.nil? && block_param.nil?) ||
                              (args_node.is_a?(::Parser::AST::Node) && !args_node.location&.expression.nil?)
        uses_it = body_uses_it?(body_node)
        it_param = false

        if uses_it
          if has_explicit_params
            if @raise_syntax_errors
              raise FrozoneException.make(:SyntaxError, "ordinary parameter is defined")
            end
          else
            required = [:it]
            it_param = true
          end
        end

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

        auto_splat = compute_auto_splat(required, optional, rest, post, req_kw, opt_kw, implicit_rest: implicit_rest)

        src_loc = @filepath && node.location ? [@filepath, node.location.line] : nil
        if is_arrow_lambda
          # `-> { }` syntax: create Ast::Lambda directly (no method dispatch needed)
          Ast::Lambda.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                          block_param, locals, body_ast, it_param: it_param, source_location: src_loc)
        else
          # `lambda { }` or other block call: dispatch through method call so `lambda` can be overridden.
          # For `lambda { }`, Kernel#lambda will receive the block and make it a lambda-style proc.
          block_obj = Ast::Block.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                                     block_param, auto_splat, locals, body_ast, it_param: it_param,
                                                                                source_location: src_loc)
          transform_send_with_block(send_node, block_obj)
        end
      end

      def transform_numblock(node)
        send_node = node.children[0]
        count = node.children[1]
        body_node = node.children[2]

        # `it` cannot be mixed with numbered parameters
        if @raise_syntax_errors && body_uses_it?(body_node)
          raise FrozoneException.make(:SyntaxError, "'it' is already used in block; numbered parameter is already used in it")
        end

        required = (1..count).map { |i| :"_#{i}" }
        optional = []
        rest = nil
        post = []
        req_kw = []
        opt_kw = []
        kw_rest = nil
        block_param = nil

        is_arrow_lambda = send_node.type == :lambda
        is_lambda = is_arrow_lambda || (send_node.type == :send &&
                                        send_node.children[0].nil? &&
                                        send_node.children[1] == :lambda)

        initial = required.dup
        @scope_chain.push(:block, initial)
        body_ast = transform(body_node)
        locals = @scope_chain.current.claimed.to_a
        @scope_chain.pop

        if is_arrow_lambda
          Ast::Lambda.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                          block_param, locals, body_ast)
        else
          auto_splat = is_lambda ? false : (count >= 2)
          block_obj = Ast::Block.new(required, optional, rest, post, req_kw, opt_kw, kw_rest,
                                     block_param, auto_splat, locals, body_ast)
          transform_send_with_block(send_node, block_obj)
        end
      end

      # Given a send node and a block AST, create the appropriate MethodCall or AttributeWrite
      def transform_send_with_block(send_node, block_obj)
        if send_node.type == :send || send_node.type == :csend
          type = send_node.type
          c = send_node.children
          recv_node, name, *raw_args = c[0], c[1], *c[2..]
          safe_nav = (type == :csend)

          # Frozone.compile! { execute_phase } — snapshot-based AOT compilation hook
          if recv_node && recv_node.type == :const &&
             recv_node.children[0].nil? && recv_node.children[1] == :Frozone &&
             name == :"compile!"
            return Ast::FrozoneCompile.new(block_obj)
          end

          # Intrinsics don't take blocks normally, but handle gracefully
          if recv_node && recv_node.type == :const &&
             recv_node.children[0].nil? && recv_node.children[1] == :Intrinsics &&
             name != :new
            arg_nodes = raw_args.map { |a| transform(a) }
            return Ast::IntrinsicCall.new(name, arg_nodes)
          end

          receiver_ast =
            if recv_node.nil? || recv_node.type == :self
              nil
            else
              transform(recv_node)
            end

          arg_nodes, kw_args, kw_splats, _existing_block = parse_call_args(raw_args)
          call_loc = @filepath && send_node.location ? "#{@filepath}:#{send_node.location.line}" : nil
          Ast::MethodCall.new(name, receiver_ast, arg_nodes, kw_args, block_obj,
                              kw_splat_nodes: kw_splats, safe_nav: safe_nav, source_location: call_loc)

        elsif send_node.type == :super
          arg_nodes, _, kw_splats, _blk = parse_call_args(send_node.children)
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

      def transform_def(name, receiver_ast, args_node, body_node, def_line: nil)
        # Collect all param names first (without transforming defaults) so that
        # default-value expressions (e.g. lambdas) are parsed inside the method scope,
        # allowing them to capture enclosing params by the correct depth.
        initial = collect_all_param_names(args_node)
        @scope_chain.push(:method, initial)

        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param =
          parse_method_args(args_node)

        body_ast = transform(body_node)
        locals = @scope_chain.current.claimed.to_a
        @scope_chain.pop

        # Extract destruct names from required (Hash params)
        destruct_locals = []
        required.each do |p|
          destruct_locals.concat(extract_destruct_names(p)) if p.is_a?(Hash)
        end
        locals = (locals + destruct_locals).uniq

        uses_block = block_param || body_uses_block?(body_node)
        source_loc = def_line && @filepath ? "#{@filepath}:#{def_line}" : nil

        Ast::MethodDef.new(name, receiver_ast, required, optional, rest, post,
                           req_kw, opt_kw, kw_rest, block_param, locals, body_ast,
                           uses_block: uses_block, source_location: source_loc)
      end

      # Collect all flat parameter names from an args node without transforming defaults.
      # Used to pre-populate the method scope before parsing default values.
      def collect_all_param_names(args_node)
        return [] if args_node.nil?
        return [:__forward_args__, :__forward_kwargs__, :__forward_block__] if args_node.type == :forward_args

        names = []
        seen_rest = false
        seen_underscore = false
        unique_underscore = ->(name, arg) {
          return name unless name == :_
          if seen_underscore
            :"__discard_#{arg.object_id}__"
          else
            seen_underscore = true
            :_
          end
        }

        args_node.children.each do |arg|
          next if arg.nil?
          case arg.type
          when :arg, :optarg
            names << unique_underscore.call(arg.children[0], arg)
          when :restarg
            seen_rest = true
            raw_name = arg.children[0]
            names << (raw_name ? unique_underscore.call(raw_name, arg) : :__anon_rest__)
          when :kwarg, :kwoptarg
            names << arg.children[0]
          when :kwrestarg
            kw = arg.children[0]
            names << kw if kw && kw != :__no_kwargs__ && kw != :__anon_kwargs__
          when :kwnilarg
            # no name
          when :blockarg
            names << (arg.children[0] || :__anon_block__)
          when :shadowarg
            # not a param name
          when :mlhs
            names.concat(extract_mlhs_names(arg))
          when :procarg0
            inner = arg.children[0]
            if inner.is_a?(::Parser::AST::Node) && inner.type == :mlhs
              names.concat(extract_mlhs_names(inner))
            elsif inner.is_a?(::Parser::AST::Node)
              names << inner.children[0]
            end
          when :forward_args, :forward_arg
            names.concat([:__forward_args__, :__forward_kwargs__, :__forward_block__])
          when :anon_restarg
            names << :__anon_rest__
          when :anon_kwrestarg
            names << :__anon_kwargs__
          when :anon_blockarg
            names << :__anon_block__
          end
        end

        names.compact
      end

      # Extract all local variable names from an mlhs node recursively.
      def extract_mlhs_names(mlhs_node)
        names = []
        mlhs_node.children.each do |child|
          next if child.nil?
          case child.type
          when :arg    then names << child.children[0]
          when :restarg then names << (child.children[0] || :__anon_rest__)
          when :mlhs   then names.concat(extract_mlhs_names(child))
          end
        end
        names
      end

      # -----------------------------------------------------------------------
      # Argument parsing helpers
      # -----------------------------------------------------------------------

      # Parse a :args node for method definitions.
      # Returns [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param]
      def parse_method_args(args_node)
        required = []
        optional = []
        rest = nil
        post = []
        req_kw = []
        opt_kw = []
        kw_rest = nil
        block_param = nil

        return [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param] if args_node.nil?

        # Handle s(:forward_args) as the entire args
        if args_node.type == :forward_args
          return [required, optional, :__forward_args__, post, req_kw, opt_kw,
                  :__forward_kwargs__, :__forward_block__]
        end

        seen_optional = false
        seen_rest = false
        seen_underscore = false
        # Helper: rename `_` params uniquely if duplicated
        unique_underscore = ->(name, arg) {
          return name unless name == :_
          if seen_underscore
            :"__discard_#{arg.object_id}__"
          else
            seen_underscore = true
            :_
          end
        }

        args_node.children.each do |arg|
          next if arg.nil?
          case arg.type
          when :arg
            name = unique_underscore.call(arg.children[0], arg)
            if seen_rest
              post << name
            elsif seen_optional
              post << name
            else
              required << name
            end
          when :mlhs
            # Destructured required param: |(a, b)|
            if seen_rest || seen_optional
              post << parse_multi_target_param(arg)
            else
              required << parse_multi_target_param(arg)
            end
          when :optarg
            seen_optional = true
            name = unique_underscore.call(arg.children[0], arg)
            optional << [name, transform(arg.children[1])]
          when :restarg
            seen_rest = true
            raw_name = arg.children[0]
            rest = raw_name ? unique_underscore.call(raw_name, arg) : :__anon_rest__
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
            required << if inner.type == :mlhs
                          parse_multi_target_param(inner)
                        else
                          inner.children[0]
                        end
          when :forward_args, :forward_arg
            rest = :__forward_args__
            kw_rest = :__forward_kwargs__
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
      # Returns [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow, implicit_rest]
      def parse_block_args(args_node, is_lambda: false)
        required = []
        optional = []
        rest = nil
        post = []
        req_kw = []
        opt_kw = []
        kw_rest = nil
        block_param = nil
        shadow = []
        implicit_rest = false

        return [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow, implicit_rest] if args_node.nil?

        seen_optional = false
        seen_rest = false
        seen_param_names = {}

        args_to_parse =
          if args_node.type == :args
            args_node.children
          else
            [args_node]
          end

        args_to_parse.each do |arg|
          next if arg.nil?
          case arg.type
          when :arg
            name = arg.children[0]
            # Duplicate `_` params: rename 2nd+ to unique discard names (matches Prism behaviour)
            if name == :_ && seen_param_names[:_]
              name = :"__discard_#{arg.object_id}__"
            else
              seen_param_names[name] = true
            end
            if seen_rest
              post << name
            elsif seen_optional
              post << name
            else
              required << name
            end
          when :mlhs
            # |(a, b)| style destructuring — required or post (if after rest/optional)
            if seen_rest || seen_optional
              post << parse_multi_target_param(arg)
            else
              required << parse_multi_target_param(arg)
            end
          when :procarg0
            # With emit_arg_inside_procarg0=false:
            #   |a|   -> s(:procarg0, :a)           (Symbol child — simple param)
            #   |(a)| -> s(:procarg0, s(:arg, :a))  (Node child — destructuring)
            if arg.children.size == 1
              inner = arg.children[0]
              if inner.is_a?(::Parser::AST::Node)
                if inner.type == :mlhs
                  required << parse_multi_target_param(inner)
                else
                  # |(a)| — single arg in parens → destructure
                  name = inner.children[0]
                  required << { names: [name], rest: nil, rights: [] }
                end
              else
                # |a| — plain symbol → simple param
                required << inner
              end
            else
              # |(a, b)| — multiple children means destructured tuple (no wrapping mlhs)
              required << parse_multi_target_param(arg)
            end
          when :optarg
            seen_optional = true
            optional << [arg.children[0], transform(arg.children[1])]
          when :restarg
            seen_rest = true
            rest_name = arg.children[0]
            if rest_name
              rest = rest_name
            elsif arg.location&.expression&.source&.include?('*')
              # Explicit anonymous `*` — real rest param (e.g. `|a, *|`, `-> (*) {}`)
              rest = :__anon_rest__
            else
              # Trailing comma `|a, |` — implicit rest (auto-splat, no arity effect)
              implicit_rest = true
            end
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

        [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, shadow, implicit_rest]
      end

      # Compute auto_splat for blocks (not lambdas)
      def compute_auto_splat(required, optional, rest, post, req_kw, opt_kw, implicit_rest: false)
        is_empty = required.empty? && optional.empty? && rest.nil? && post.empty? && !implicit_rest
        is_single_req = required.length == 1 && optional.empty? && rest.nil? && post.empty? && !implicit_rest
        is_single_opt = required.empty? && optional.length == 1 && rest.nil? && post.empty? &&
                        req_kw.empty? && opt_kw.empty?
        is_rest_only = required.empty? && optional.empty? && rest && post.empty?
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
        arg_nodes = []
        kw_args = {}
        kw_splats = []
        block_node = nil
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
          when :forwarded_restarg
            # def m(*); target(*) end — forward anonymous rest
            arg_nodes << Ast::SplatArg.new(Ast::LocalVariableRead.new(:__anon_rest__, 0))
          when :forwarded_kwrestarg
            # def m(**); target(**) end — forward anonymous kw_rest
            kw_splats << Ast::LocalVariableRead.new(:__anon_kwargs__, 0)
          when :hash
            # With Builder::Default.modernize, :hash in call args is always a positional
            # hash literal (braced). Bare keyword syntax produces :kwargs nodes instead.
            arg_nodes << Ast::HashLiteral.new(transform_hash_pairs(arg))
          when :kwargs
            # Ruby 3.0+ separate kwargs node (bare hash syntax, no braces = always kwargs context).
            # Symbol-keyed pairs go to kw_args; non-symbol-keyed pairs go as a kw_splat hash.
            non_sym_pairs = []
            arg.children.each do |pair|
              case pair.type
              when :pair
                key_node = pair.children[0]
                val_node = pair.children[1]
                if key_node.type == :sym
                  kw_args[transform(key_node)] = transform(val_node)
                else
                  non_sym_pairs << [transform(key_node), transform(val_node)]
                end
              when :kwsplat
                splat_val = pair.children[0].nil? ?
                  Ast::LocalVariableRead.new(:__anon_kwargs__, 0) :
                  transform(pair.children[0])
                kw_splats << splat_val
              when :forwarded_kwrestarg
                # def m(**); target(**) end — with modernize, forwarded_kwrestarg inside kwargs
                kw_splats << Ast::LocalVariableRead.new(:__anon_kwargs__, 0)
              end
            end
            kw_splats << Ast::HashLiteral.new(non_sym_pairs) unless non_sym_pairs.empty?
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
        names = []
        rest = nil
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
          parent = node.children[0]
          name = node.children[1]
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
        when :indexasgn
          # With Builder::Default.modernize: b[0] in mlhs → s(:indexasgn, recv, idx...)
          recv_node = node.children[0]
          idx_nodes = node.children[1..]
          receiver_ast =
            if recv_node.nil?
              nil
            elsif recv_node.type == :self
              Ast::SelfLiteral::SELF
            else
              transform(recv_node)
            end
          [:index, receiver_ast, idx_nodes.map { |a| transform(a) }]

        when :send
          recv_node, mname, *arg_nodes = node.children
          receiver_ast =
            if recv_node.nil?
              nil
            elsif recv_node.type == :self
              Ast::SelfLiteral::SELF
            else
              transform(recv_node)
                         end
          if mname == :[]=
            # Index assignment: object[k] = val — include index args
            [:index, receiver_ast, arg_nodes.map { |a| transform(a) }]
          else
            # Attribute assignment: object.foo = val
            [:call, receiver_ast, mname]
          end
        when :mlhs
          sub = node.children.map { |ch| parse_masgn_target(ch) }
          [:nested, sub]
        else
          # Fallback
          [:local, :_, 0]
        end
      end

      def transform_masgn(node)
        lhs_node = node.children[0]
        rhs_node = node.children[1]
        targets = lhs_node.children.map { |t| parse_masgn_target(t) }
        Ast::MultipleAssignment.new(targets, transform(rhs_node))
      end

      # -----------------------------------------------------------------------
      # Operator assignment transformations
      # -----------------------------------------------------------------------

      def transform_op_asgn(node)
        target_node = node.children[0]
        op = node.children[1]
        value_node = node.children[2]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d = @scope_chain.register_write(name)
          read = Ast::LocalVariableRead.new(name, d)
          rhs = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::LocalVariableWrite.new(name, d, rhs)

        when :ivasgn
          name = target_node.children[0]
          read = Ast::InstanceVariableRead.new(name)
          rhs = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::InstanceVariableWrite.new(name, rhs)

        when :cvasgn
          name = target_node.children[0]
          read = Ast::ClassVariableRead.new(name)
          rhs = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::ClassVariableWrite.new(name, rhs)

        when :gvasgn
          name = target_node.children[0]
          read = Ast::GlobalVariableRead.new(name)
          rhs = Ast::MethodCall.new(op, read, [transform(value_node)], {})
          Ast::GlobalVariableWrite.new(name, rhs)

        when :casgn
          parent = target_node.children[0]
          name = target_node.children[1]
          if parent.nil? || parent.type == :cbase
            read = Ast::ConstantRead.new(name)
            rhs = Ast::MethodCall.new(op, read, [transform(value_node)], {})
            Ast::ConstantWrite.new(name, rhs)
          else
            # Use ConstantPathOperatorWrite so parent is evaluated only once.
            parent_ast = transform(parent)
            Ast::ConstantPathOperatorWrite.new(parent_ast, name, op, transform(value_node))
          end

        when :indexasgn
          recv_node = target_node.children[0]
          idx_nodes = target_node.children[1..]
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          index_arg_nodes = idx_nodes.map { |a| transform(a) }
          Ast::IndexOperatorWrite.new(op, receiver_ast, index_arg_nodes, transform(value_node))

        when :send, :csend
          recv_node, mname, *index_args = target_node.children
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          safe_nav = (target_node.type == :csend)
          if mname == :[]
            index_arg_nodes = index_args.map { |a| transform(a) }
            val_node = transform(value_node)
            Ast::IndexOperatorWrite.new(op, receiver_ast, index_arg_nodes, val_node)
          else
            read_name = mname
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
        target_node = node.children[0]
        value_node = node.children[1]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d = @scope_chain.register_write(name)
          read = Ast::LocalVariableRead.new(name, d)
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
          Ast::Or.new(Ast::GlobalVariableRead.new(name, no_warn: true),
                      Ast::GlobalVariableWrite.new(name, transform(value_node)))

        when :casgn
          parent = target_node.children[0]
          name = target_node.children[1]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantOrWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathOrWrite.new(transform(parent), name, transform(value_node))
          end

        when :indexasgn
          recv_node = target_node.children[0]
          idx_nodes = target_node.children[1..]
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          index_arg_nodes = idx_nodes.map { |a| transform(a) }
          Ast::IndexOrWrite.new(receiver_ast, index_arg_nodes, transform(value_node))

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
        target_node = node.children[0]
        value_node = node.children[1]

        case target_node.type
        when :lvasgn
          name = target_node.children[0]
          d = @scope_chain.register_write(name)
          read = Ast::LocalVariableRead.new(name, d)
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
          Ast::And.new(Ast::GlobalVariableRead.new(name, no_warn: true),
                       Ast::GlobalVariableWrite.new(name, transform(value_node)))

        when :casgn
          parent = target_node.children[0]
          name = target_node.children[1]
          if parent.nil? || parent.type == :cbase
            Ast::ConstantAndWrite.new(name, transform(value_node))
          else
            Ast::ConstantPathAndWrite.new(transform(parent), name, transform(value_node))
          end

        when :indexasgn
          recv_node = target_node.children[0]
          idx_nodes = target_node.children[1..]
          receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          index_arg_nodes = idx_nodes.map { |a| transform(a) }
          Ast::IndexAndWrite.new(receiver_ast, index_arg_nodes, transform(value_node))

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
        subject_ast = subject_node ? transform(subject_node) : nil

        whens = []
        else_ast = nil
        # Track seen condition sources for duplicate detection (verbose warning)
        seen_cond_lines = {}

        c[1..].each do |child|
          next if child.nil?
          case child.type
          when :when
            when_line = child.location&.line
            conds = child.children[0..-2].map do |cnd|
              # Check for duplicate when clauses (verbose warning)
              cond_src = cnd.location&.expression&.source
              if cond_src && seen_cond_lines.key?(cond_src)
                orig_line = seen_cond_lines[cond_src]
                @prism_verbose_warnings << "'when' clause on line #{when_line} duplicates 'when' clause on line #{orig_line} and is ignored"
              elsif cond_src
                seen_cond_lines[cond_src] = when_line
              end
              transform(cnd)
            end
            body_node = child.children.last
            body_ast = body_node.nil? ? Ast::NilLiteral::NIL : transform(body_node)
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
        body_ast = transform(body_node)

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
        body_node = ensure_node.children[0]
        ensure_clause_node = ensure_node.children[1]
        ensure_ast = transform(ensure_clause_node)

        if body_node.nil?
          Ast::Rescue.new(Ast::NilLiteral::NIL, [], nil, ensure_ast)
        elsif body_node.type == :rescue
          result = transform_rescue_node(body_node, nil, nil)
          # Wrap result's ensure
          Ast::Rescue.new(result.body, result.rescue_clauses, result.else_node, ensure_ast)
        else
          body_ast = transform(body_node)
          Ast::Rescue.new(body_ast, [], nil, ensure_ast)
        end
      end

      def transform_resbody(resbody_node)
        exc_node = resbody_node.children[0]
        var_node = resbody_node.children[1]
        body_node = resbody_node.children[2]

        exc_nodes =
          if exc_node.nil?
            []
          else
            exc_node.children.map { |e| transform(e) }
          end

        var_name = nil
        var_depth = nil
        assign_node = nil

        if var_node
          case var_node.type
          when :lvasgn
            name = var_node.children[0]
            d = @scope_chain.register_write(name)
            var_name = name
            var_depth = d
          when :ivasgn
            assign_node = Ast::InstanceVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :gvasgn
            assign_node = Ast::GlobalVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :cvasgn
            assign_node = Ast::ClassVariableWrite.new(var_node.children[0], Ast::NilLiteral::NIL)
          when :casgn
            assign_node = Ast::ConstantWrite.new(var_node.children[1], Ast::NilLiteral::NIL)
          when :send, :csend
            # rescue => obj.setter= — setter capture
            safe_nav = (var_node.type == :csend)
            recv_node = var_node.children[0]
            setter_name = var_node.children[1]
            receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
            assign_node = Ast::RescueCallTarget.new(receiver_ast, setter_name, safe_nav)
          when :indexasgn
            # rescue => obj[idx]= — index capture
            recv_node = var_node.children[0]
            idx_nodes = var_node.children[1..]
            receiver_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
            assign_node = Ast::RescueIndexTarget.new(receiver_ast, idx_nodes.map { |a| transform(a) })
          end
        end

        body_ast = body_node.nil? ? Ast::NilLiteral::NIL : transform(body_node)
        Ast::RescueClause.new(exc_nodes, var_name, var_depth, body_ast, assign_node: assign_node)
      end

      # -----------------------------------------------------------------------
      # Begin / kwbegin transformation
      # -----------------------------------------------------------------------

      def transform_begin_seq(children)
        # Hoist BEGIN{} blocks to run before other statements (Ruby semantics).
        begin_nodes, other_nodes = children.partition { |ch| ch.is_a?(::Parser::AST::Node) && ch.type == :preexe }
        hoisted = begin_nodes.filter_map { |ch| ch.children[0] ? transform(ch.children[0]) : nil }
        # Non-last statements are in void context.
        # `defined?` in void context → emit verbose warning + no-op.
        rest = other_nodes.each_with_index.filter_map do |ch, i|
          is_void = i < other_nodes.length - 1
          if is_void && ch.is_a?(::Parser::AST::Node) && ch.type == :"defined?"
            @prism_verbose_warnings << "possibly useless use of defined? in void context"
            nil  # no-op: don't emit any node
          else
            transform(ch)
          end
        end
        stmts = hoisted + rest
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
        when :__ENCODING__
          # `defined?(__ENCODING__)` → "expression"
          Ast::DefinedExpr.new(:expression)
        when :const
          # Detect __ENCODING__ — whitequark converts it to Encoding::UTF_8 (or similar),
          # but `defined?(__ENCODING__)` should always return "expression".
          if val_node.location&.expression&.source == "__ENCODING__"
            return Ast::DefinedExpr.new(:expression)
          end
          parent = val_node.children[0]
          name = val_node.children[1]
          if parent.nil?
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
        when :indexasgn
          # `defined?(a[0] = 1)` → "method" (same as []= method call)
          recv_node = val_node.children[0]
          receiver_ast = recv_node ? transform(recv_node) : nil
          receiver_defined = recv_node ? transform_defined(recv_node) : nil
          Ast::DefinedExpr.new(:method, [receiver_ast, :[]=, receiver_defined])
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
        when :casgn
          # Constant assignment: children = [scope, name] (scope nil = unscoped)
          [:constant, node.children[1]]
        when :mlhs
          lefts = []
          rest = nil
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
        when :indexasgn
          recv_node = node.children[0]
          idx_nodes = node.children[1..]
          recv_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          [:index, recv_ast, idx_nodes.map { |a| transform(a) }]

        when :send
          recv_node = node.children[0]
          mname = node.children[1]
          recv_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          [:call, recv_ast, mname, false]
        when :csend
          recv_node = node.children[0]
          mname = node.children[1]
          recv_ast = recv_node.nil? || recv_node.type == :self ? nil : transform(recv_node)
          [:call, recv_ast, mname, true]
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
        name = const_node.children[1]
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
            Ast::StringLiteral.from(apply_source_encoding(part.children[0]))
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
        enc_name = nil
        return [flags, enc_name] if opts_node.nil? || opts_node.type != :regopt
        opts_node.children.each do |flag|
          case flag
          when :i then flags |= Regexp::IGNORECASE
          when :m then flags |= Regexp::MULTILINE
          when :x then flags |= Regexp::EXTENDED
          when :u then flags |= Regexp::FIXEDENCODING; enc_name = 'UTF-8'
          when :e then flags |= Regexp::FIXEDENCODING; enc_name = 'EUC-JP'
          when :s then flags |= Regexp::FIXEDENCODING; enc_name = 'Windows-31J'
          when :n then flags |= Regexp::NOENCODING
          end
        end
        [flags, enc_name]
      end

      # -----------------------------------------------------------------------
      # Misc helpers
      # -----------------------------------------------------------------------

      # Apply @source_encoding to a string value from whitequark (which always gives UTF-8).
      # If @source_encoding differs from the string's encoding, attempt to re-encode/force
      # so that the resulting StringObject has the correct encoding.
      def apply_source_encoding(s)
        return s if @source_encoding.nil? || s.encoding == @source_encoding
        # ASCII-8BIT → target: reinterpret bytes (force_encoding) rather than transcode,
        # since ASCII-8BIT encode raises on non-ASCII bytes. Only reinterpret if the bytes
        # form a valid string in the target encoding.
        if s.encoding == Encoding::ASCII_8BIT && !s.ascii_only?
          reinterpreted = s.dup.force_encoding(@source_encoding)
          return reinterpreted if reinterpreted.valid_encoding?
          return s
        end
        # Try to re-encode; fall back to force_encoding for binary-compatible cases.
        if s.valid_encoding? && s.ascii_only?
          s.dup.force_encoding(@source_encoding)
        else
          begin
            s.encode(@source_encoding)
          rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
            s
          end
        end
      end

      # Like apply_source_encoding but for Symbol values.
      # After ASCII-8BIT retry, symbols may have binary encoding even though they
      # contain valid UTF-8 bytes. Re-encode the symbol's string representation
      # and intern a correctly-encoded symbol.
      def apply_source_encoding_sym(sym)
        s = sym.to_s
        return sym if @source_encoding.nil? || s.encoding == @source_encoding
        apply_source_encoding(s).to_sym
      end

      # Extract encoding from Ruby magic comment (# encoding: NAME or # -*- coding: NAME -*-)
      # Checks the first two lines (to allow shebang on line 1). Case-insensitive.
      # Uses binary-safe scan to handle files with non-UTF-8 content before the comment.
      def extract_magic_comment_encoding(source)
        # Use binary encoding for regex match to avoid invalid-byte-sequence errors.
        binary = source.dup.force_encoding(Encoding::BINARY)
        # Grab first two lines as binary (newline is 0x0a in all encodings we care about).
        first_two_bytes = binary.slice(/\A[^\n]*\n[^\n]*\n?/)
        return nil unless first_two_bytes
        match = first_two_bytes.match(/\A(?:#[^\n]*\n)?#.*coding\s*[:=]\s*([a-zA-Z0-9-]+)/mi)
        return nil unless match
        Encoding.find(match[1].force_encoding(Encoding::UTF_8))
      rescue ArgumentError, Encoding::CompatibilityError
        nil
      end

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

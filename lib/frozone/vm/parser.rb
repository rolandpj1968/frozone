require 'prism'

require_relative '../ast'

module Frozone
  module Vm
    class Parser
      def initialize(text, dump_ast = false, filepath: nil)
        @text = text
        @dump_ast = dump_ast
        @filepath = filepath
      end

      def ast
        parse_opts = @filepath ? { filepath: @filepath } : {}
        program_node = Prism.parse(@text, **parse_opts).value

        puts program_node.inspect if @dump_ast

        raise "Unexpected Prism.parse value type #{value.class} expecting Prism::ProgramNode" unless program_node.is_a?(Prism::ProgramNode)

        @top_level_locals = program_node.locals
        transform(program_node.statements)
      end

      def top_level_locals = @top_level_locals || []

      private

      def parse_lambda(prism_node)
        params = []
        locals = prism_node.locals
        unless prism_node.parameters.nil?
          bp = prism_node.parameters
          unless bp.parameters.nil?
            raise "lambda parameters is not a Prism::ParametersNode" unless bp.parameters.is_a?(Prism::ParametersNode)
            # TODO: optional/rest/keyword lambda params
            params = bp.parameters.requireds.map do |required|
              raise "lambda required parameter is not a Prism::RequiredParameterNode" unless required.is_a?(Prism::RequiredParameterNode)
              required.name
            end
          end
        end
        body = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
        [params, locals, body]
      end

      def parse_multi_write_target(target)
        case target
        when Prism::LocalVariableTargetNode
          [:local, target.name, target.depth]
        when Prism::InstanceVariableTargetNode
          [:ivar, target.name]
        when Prism::ConstantTargetNode
          [:const, target.name]
        when Prism::SplatNode
          if target.expression.nil?
            [:splat_nil]
          else
            # Delegate to the inner target but mark as splat for collection
            inner = parse_multi_write_target(target.expression)
            [:"#{inner[0]}_splat", *inner[1..]]
          end
        when Prism::GlobalVariableTargetNode
          [:gvar, target.name]
        when Prism::IndexTargetNode
          index_nodes = target.arguments.nil? ? [] : target.arguments.arguments.map { |a| transform(a) }
          [:index, transform(target.receiver), index_nodes]
        when Prism::CallTargetNode
          # obj.method= in multi-write: a.foo, b = 1, 2 (target.name already has '=')
          [:call, transform(target.receiver), target.name]
        when Prism::ClassVariableTargetNode
          [:cvar, target.name]
        when Prism::ConstantPathTargetNode
          # A::B in multi-write
          parent_node = transform(target.parent)
          [:const_path, parent_node, target.child.name]
        when Prism::ImplicitRestNode
          # Implicit * with no variable: a, *, b = arr
          [:splat_nil]
        when Prism::MultiTargetNode
          # Nested destructuring: (a, b), c = arr
          sub_targets = target.lefts.map { |t| parse_multi_write_target(t) }
          sub_targets << parse_multi_write_target(target.rest) unless target.rest.nil?
          sub_targets += target.rights.map { |t| parse_multi_write_target(t) }
          [:nested, sub_targets]
        else
          raise "Unsupported multi-write target type: #{target.class}"
        end
      end

      def parse_multi_write(prism_node)
        targets = prism_node.lefts.map { |t| parse_multi_write_target(t) }
        unless prism_node.rest.nil?
          targets << parse_multi_write_target(prism_node.rest)
        end
        targets += prism_node.rights.map { |t| parse_multi_write_target(t) }
        Ast::MultipleAssignment.new(targets, transform(prism_node.value))
      end

      def parse_block(prism_block_node)
        params = []
        unless prism_block_node.parameters.nil?
          bp = prism_block_node.parameters
          unless bp.parameters.nil?
            raise "block parameters is not a Prism::ParametersNode" unless bp.parameters.is_a?(Prism::ParametersNode)
            # TODO: optional/rest/keyword block params
            params = bp.parameters.requireds.map do |required|
              case required
              when Prism::RequiredParameterNode
                required.name
              when Prism::MultiTargetNode
                # Destructuring block param like |(a, b)| — use anonymous name for now
                :_
              else
                raise "block required parameter is not a Prism::RequiredParameterNode (got #{required.class})"
              end
            end
          end
        end
        body = prism_block_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_block_node.body)
        Ast::Block.new(params, prism_block_node.locals, body)
      end

      def parse_method_params(prism_node)
        required_params = []
        optional_params = []
        rest_param = nil
        post_params = []
        required_kw_params = []
        optional_kw_params = []
        kw_rest_param = nil
        unless prism_node.parameters.nil?
          raise "Prism::DefNode.parameters is not a Prism::ParametersNode" unless prism_node.parameters.is_a?(Prism::ParametersNode)
          parameters = prism_node.parameters
          block_param = parameters.block.nil? ? nil : parameters.block.name
          required_params = parameters.requireds.map do |required|
            raise "required parameter is not a Prism::RequiredParameterNode" unless required.is_a?(Prism::RequiredParameterNode)
            required.name
          end
          optional_params = parameters.optionals.map do |optional|
            raise "optional parameter is not a Prism::OptionalParameterNode" unless optional.is_a?(Prism::OptionalParameterNode)
            [optional.name, transform(optional.value)]
          end
          unless parameters.rest.nil?
            raise "rest parameter is not a Prism::RestParameterNode" unless parameters.rest.is_a?(Prism::RestParameterNode)
            rest_param = parameters.rest.name
          end
          post_params = parameters.posts.map do |post|
            raise "post parameter is not a Prism::RequiredParameterNode" unless post.is_a?(Prism::RequiredParameterNode)
            post.name
          end
          prism_node.parameters.keywords.each do |kw|
            case kw
            when Prism::RequiredKeywordParameterNode
              required_kw_params << kw.name
            when Prism::OptionalKeywordParameterNode
              optional_kw_params << [kw.name, transform(kw.value)]
            else
              raise "kw parameter is neither a Prism::RequiredKeywordParameterNode or a Prism::OptionalKeywordParameterNode"
            end
          end
          unless parameters.keyword_rest.nil?
            raise "keyword_rest parameter is not a Prism::KeywordRestParameterNode" unless parameters.keyword_rest.is_a?(Prism::KeywordRestParameterNode)
            kw_rest_param = parameters.keyword_rest.name
          end
        end
        [required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param]
      end

      def transform(prism_node)
        case prism_node
        when nil
          Ast::NilLiteral::NIL

        when Prism::NilNode
          Ast::NilLiteral::NIL

        when Prism::TrueNode
          Ast::TrueLiteral::TRUE

        when Prism::FalseNode
          Ast::FalseLiteral::FALSE

        when Prism::SelfNode
          Ast::SelfLiteral::SELF

        when Prism::IntegerNode
          Ast::IntegerLiteral.from(prism_node.value)

        when Prism::FloatNode
          Ast::FloatLiteral.from(prism_node.value)

        when Prism::StringNode
          Ast::StringLiteral.from(prism_node.unescaped)

        when Prism::SymbolNode
          Ast::SymbolLiteral.from(prism_node.unescaped)

        when Prism::RegularExpressionNode
          flags = 0
          flags |= Regexp::IGNORECASE if prism_node.ignore_case?
          flags |= Regexp::MULTILINE  if prism_node.multi_line?
          flags |= Regexp::EXTENDED   if prism_node.extended?
          Ast::RegexpLiteral.new(prism_node.unescaped, flags)

        when Prism::InterpolatedRegularExpressionNode
          flags = 0
          flags |= Regexp::IGNORECASE if prism_node.ignore_case?
          flags |= Regexp::MULTILINE  if prism_node.multi_line?
          flags |= Regexp::EXTENDED   if prism_node.extended?
          parts = prism_node.parts.map do |part|
            case part
            when Prism::StringNode            then Ast::StringLiteral.from(part.unescaped)
            when Prism::EmbeddedStatementsNode then transform(part.statements)
            else raise "Unexpected interpolated regexp part: #{part.class}"
            end
          end
          Ast::InterpolatedRegexpLiteral.new(parts, flags)

        when Prism::ArrayNode
          Ast::ArrayLiteral.new(prism_node.elements.map { |e| transform(e) })

        when Prism::SplatNode
          Ast::SplatArg.new(prism_node.expression.nil? ? nil : transform(prism_node.expression))

        when Prism::HashNode
          kv_nodes = prism_node.elements.map do |kv|
            case kv
            when Prism::AssocNode then [transform(kv.key), transform(kv.value)]
            when Prism::AssocSplatNode then [nil, transform(kv.value)]
            else raise "Hash literal element is not a Prism::AssocNode: #{kv.class}"
            end
          end
          Ast::HashLiteral.new(kv_nodes)

        when Prism::AndNode
          Ast::And.new(transform(prism_node.left), transform(prism_node.right))

        when Prism::OrNode
          Ast::Or.new(transform(prism_node.left), transform(prism_node.right))

        when Prism::ParenthesesNode
          transform(prism_node.body)

        when Prism::StatementsNode
          Ast::Sequence.new(prism_node.body.map { |pn| transform(pn) })

        when Prism::IfNode
          Ast::If.new(
            transform(prism_node.predicate),
            transform(prism_node.statements),
            prism_node.consequent.nil? ? nil : transform(prism_node.consequent)
          )

        when Prism::WhileNode
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          Ast::While.new(transform(prism_node.predicate), body, begin_modifier: prism_node.begin_modifier?)

        when Prism::UntilNode
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          Ast::Until.new(transform(prism_node.predicate), body, begin_modifier: prism_node.begin_modifier?)

        when Prism::UnlessNode
          # unless cond; body; else alt; end  ==  if cond; alt; else body; end
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          alt  = prism_node.consequent.nil? ? Ast::NilLiteral::NIL : transform(prism_node.consequent)
          Ast::If.new(transform(prism_node.predicate), alt, body)

        when Prism::CaseNode
          subject_node = prism_node.predicate.nil? ? nil : transform(prism_node.predicate)
          whens = prism_node.conditions.map do |w|
            raise "case condition is not a WhenNode" unless w.is_a?(Prism::WhenNode)
            body = w.statements.nil? ? Ast::NilLiteral::NIL : transform(w.statements)
            Ast::Case::When.new(w.conditions.map { |c| transform(c) }, body)
          end
          else_node = prism_node.consequent.nil? ? nil : transform(prism_node.consequent)
          Ast::Case.new(subject_node, whens, else_node)

        when Prism::InterpolatedStringNode
          parts = prism_node.parts.map do |part|
            case part
            when Prism::StringNode
              Ast::StringLiteral.from(part.unescaped)
            when Prism::EmbeddedStatementsNode
              transform(part.statements)
            when Prism::EmbeddedVariableNode
              transform(part.variable)
            when Prism::InterpolatedStringNode
              transform(part)
            else
              raise "Unexpected interpolated string part type #{part.class}"
            end
          end
          Ast::InterpolatedString.new(parts)

        when Prism::ElseNode
          transform(prism_node.statements)

        when Prism::LocalVariableReadNode
          Ast::LocalVariableRead.new(prism_node.name, prism_node.depth)

        when Prism::LocalVariableWriteNode
          Ast::LocalVariableWrite.new(prism_node.name, prism_node.depth, transform(prism_node.value))

        when Prism::LocalVariableOperatorWriteNode
          # i += rhs  →  i = i.op(rhs)
          read = Ast::LocalVariableRead.new(prism_node.name, prism_node.depth)
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::LocalVariableWrite.new(prism_node.name, prism_node.depth, rhs)

        when Prism::InstanceVariableOperatorWriteNode
          read = Ast::InstanceVariableRead.new(prism_node.name)
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::InstanceVariableWrite.new(prism_node.name, rhs)

        when Prism::GlobalVariableOperatorWriteNode
          read = Ast::GlobalVariableRead.new(prism_node.name)
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::GlobalVariableWrite.new(prism_node.name, rhs)

        when Prism::ConstantOperatorWriteNode
          read = Ast::ConstantRead.new(prism_node.name)
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::ConstantWrite.new(prism_node.name, rhs)

        when Prism::InstanceVariableReadNode
          Ast::InstanceVariableRead.new(prism_node.name)

        when Prism::InstanceVariableWriteNode
          Ast::InstanceVariableWrite.new(prism_node.name, transform(prism_node.value))

        when Prism::GlobalVariableReadNode
          Ast::GlobalVariableRead.new(prism_node.name)

        when Prism::GlobalVariableWriteNode
          Ast::GlobalVariableWrite.new(prism_node.name, transform(prism_node.value))

        when Prism::ConstantReadNode
          Ast::ConstantRead.new(prism_node.name)

        when Prism::ConstantWriteNode
          Ast::ConstantWrite.new(prism_node.name, transform(prism_node.value))

        when Prism::CallNode
          # TODO - only when parsing core files
          if prism_node.receiver.is_a?(Prism::ConstantReadNode) && prism_node.receiver.name.equal?(:Intrinsics)
            arg_pnodes = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments
            Ast::IntrinsicCall.new(prism_node.name, arg_pnodes.map { |pn| transform(pn) })
          else
            receiver_node = prism_node.receiver.nil? ? nil : transform(prism_node.receiver)
            arg_nodes = []
            kw_args = {}
            kw_splats = []
            unless prism_node.arguments.nil?
              prism_node.arguments.arguments.each do |argument|
                # Prism parses this a bit weirdly - keyword args appear as a Prism::KeywordHashNode in the general arguments array
                case argument
                when Prism::KeywordHashNode
                  # If any AssocNode uses => (hash-rocket), treat the whole node as a positional hash literal
                  has_hash_rocket = argument.elements.any? { |e| e.is_a?(Prism::AssocNode) && !e.operator_loc.nil? }
                  if has_hash_rocket
                    pairs = argument.elements.map do |kw_arg|
                      raise "Unexpected KeywordHashNode element: #{kw_arg.class}" unless kw_arg.is_a?(Prism::AssocNode)
                      [transform(kw_arg.key), transform(kw_arg.value)]
                    end
                    arg_nodes << Ast::HashLiteral.new(pairs)
                  else
                    argument.elements.each do |kw_arg|
                      case kw_arg
                      when Prism::AssocNode
                        raise "syntax errors found" if kw_arg.value.is_a?(Prism::MissingNode)
                        kw_args[transform(kw_arg.key)] = transform(kw_arg.value)
                      when Prism::AssocSplatNode
                        kw_splats << transform(kw_arg.value)
                      else
                        raise "Unexpected KeywordHashNode element: #{kw_arg.class}"
                      end
                    end
                  end
                when Prism::SplatNode
                  arg_nodes << Ast::SplatArg.new(argument.expression.nil? ? nil : transform(argument.expression))
                else
                  arg_nodes << transform(argument)
                end
              end
            end

            block_node =
              case prism_node.block
              when nil then nil
              when Prism::BlockNode then parse_block(prism_node.block)
              when Prism::BlockArgumentNode then Ast::BlockArg.new(transform(prism_node.block.expression))
              else raise "Unsupported block type: #{prism_node.block.class}"
              end

            Ast::MethodCall.new(prism_node.name, receiver_node, arg_nodes, kw_args, block_node, kw_splat_nodes: kw_splats)
          end

        when Prism::ModuleNode
          namespace_node = nil
          if prism_node.constant_path.is_a?(Prism::ConstantPathNode)
            # module A::B — namespace_node evaluates to A
            namespace_node = transform(prism_node.constant_path.parent)
          elsif !prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "unexpected module name type: #{prism_node.constant_path.class}"
          end
          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
          Ast::ModuleDef.new(prism_node.name, prism_node.locals, body_ast, namespace_node: namespace_node)

        when Prism::ClassNode
          # Prism seems a bit weird - it successfully parses class defns where the class name can be an arbitrary expression
          #   prehaps looking to the future?
          namespace_node = nil
          if prism_node.constant_path.is_a?(Prism::ConstantPathNode)
            # class A::B — namespace_node evaluates to A
            namespace_node = transform(prism_node.constant_path.parent)
          elsif !prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "unexpected class name type: #{prism_node.constant_path.class}"
          end
          # TODO - disappointing that we need to use upcase here
          unless prism_node.name.length > 0 && prism_node.name[0].upcase == prism_node.name[0]
            # TODO - this is a real runtime error
            raise "class name '#{prism_node.name}' is not a valid constant name"
          end
          superclass_node =
            if prism_node.superclass.nil?
              nil
            elsif prism_node.superclass.is_a?(Prism::ConstantReadNode)
              Ast::ConstantRead.new(prism_node.superclass.name)
            elsif prism_node.superclass.is_a?(Prism::ConstantPathNode)
              transform(prism_node.superclass)
            else
              raise "class superclass must be a constant (e.g. class B < A or class B < A::C)"
            end
          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
          Ast::ClassDef.new(prism_node.name, prism_node.locals, superclass_node, body_ast, namespace_node: namespace_node)

        when Prism::SingletonClassNode
          expression_node = transform(prism_node.expression)
          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
          Ast::SingletonClassDef.new(expression_node, prism_node.locals, body_ast)

        when Prism::DefNode
          required_params, optional_params, rest_param, post_params,
            required_kw_params, optional_kw_params, kw_rest_param, block_param = parse_method_params(prism_node)

          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)

          receiver_node = prism_node.receiver.nil? ? nil : transform(prism_node.receiver)
          Ast::MethodDef.new(prism_node.name, receiver_node, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param, prism_node.locals, body_ast)

        when Prism::ReturnNode
          value_node =
            if prism_node.arguments.nil? || prism_node.arguments.arguments.empty?
              nil
            else
              transform(prism_node.arguments.arguments.first)
            end
          Ast::Return.new(value_node)

        when Prism::LambdaNode
          params, locals, body = parse_lambda(prism_node)
          Ast::Lambda.new(params, locals, body)

        when Prism::YieldNode
          arg_nodes = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          Ast::Yield.new(arg_nodes)

        when Prism::MultiWriteNode
          parse_multi_write(prism_node)

        when Prism::NextNode
          value_node = prism_node.arguments.nil? || prism_node.arguments.arguments.empty? ? nil : transform(prism_node.arguments.arguments.first)
          Ast::Next.new(value_node)

        when Prism::RedoNode
          Ast::Redo.new

        when Prism::RetryNode
          Ast::Retry.new

        when Prism::DefinedNode
          if prism_node.value.is_a?(Prism::ConstantReadNode)
            Ast::DefinedConstant.new(prism_node.value.name)
          else
            # Conservative stub: returns nil for non-constant expressions
            Ast::NilLiteral::NIL
          end

        when Prism::BeginNode
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          rescue_clauses = []
          rc = prism_node.rescue_clause
          while rc
            exc_nodes = rc.exceptions.map { |e| transform(e) }
            var_name = nil
            var_depth = nil
            assign_node = nil
            if rc.reference.nil?
              # no-op
            elsif rc.reference.is_a?(Prism::LocalVariableTargetNode)
              var_name  = rc.reference.name
              var_depth = rc.reference.depth
            elsif rc.reference.is_a?(Prism::InstanceVariableTargetNode)
              assign_node = Ast::InstanceVariableWrite.new(rc.reference.name, Ast::NilLiteral::NIL)
            elsif rc.reference.is_a?(Prism::GlobalVariableTargetNode)
              assign_node = Ast::GlobalVariableWrite.new(rc.reference.name, Ast::NilLiteral::NIL)
            else
              raise "Unsupported rescue reference type: #{rc.reference.class}"
            end
            rc_body = rc.statements.nil? ? Ast::NilLiteral::NIL : transform(rc.statements)
            rescue_clauses << Ast::RescueClause.new(exc_nodes, var_name, var_depth, rc_body, assign_node: assign_node)
            rc = rc.consequent
          end
          else_node   = prism_node.else_clause.nil?   ? nil : transform(prism_node.else_clause)
          ensure_node = prism_node.ensure_clause.nil? ? nil : transform(prism_node.ensure_clause.statements)
          Ast::BeginRescue.new(body, rescue_clauses, else_node, ensure_node)

        when Prism::RescueModifierNode
          # expr rescue fallback  →  begin; expr; rescue StandardError; fallback; end
          body = transform(prism_node.expression)
          fallback = transform(prism_node.rescue_expression)
          Ast::BeginRescue.new(body, [Ast::RescueClause.new([], nil, nil, fallback)], nil, nil)

        when Prism::AliasMethodNode
          raise "new_name #{prism_node.new_name.class} must be a Prism::SymbolNode" unless prism_node.new_name.is_a?(Prism::SymbolNode)
          raise "old_name #{prism_node.old_name.class} must be a Prism::SymbolNode" unless prism_node.old_name.is_a?(Prism::SymbolNode)
          Ast::MethodAlias.new(prism_node.new_name.unescaped.to_sym, prism_node.old_name.unescaped.to_sym)

        when Prism::BreakNode
          value_node = prism_node.arguments.nil? || prism_node.arguments.arguments.empty? ? nil : transform(prism_node.arguments.arguments.first)
          Ast::Break.new(value_node)

        when Prism::XStringNode, Prism::InterpolatedXStringNode
          # Backtick command execution — not supported; return empty string stub
          Ast::StringLiteral.from("")

        when Prism::SuperNode
          arg_nodes = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          block_node = case prism_node.block
                       when nil then nil
                       when Prism::BlockNode then parse_block(prism_node.block)
                       when Prism::BlockArgumentNode then Ast::BlockArg.new(transform(prism_node.block.expression))
                       else raise "Unsupported super block type: #{prism_node.block.class}"
                       end
          Ast::Super.new(arg_nodes, block_node, forwarding: false)

        when Prism::ForwardingSuperNode
          block_node = case prism_node.block
                       when nil then nil
                       when Prism::BlockNode then parse_block(prism_node.block)
                       when Prism::BlockArgumentNode then Ast::BlockArg.new(transform(prism_node.block.expression))
                       else raise "Unsupported super block type: #{prism_node.block.class}"
                       end
          Ast::Super.new([], block_node, forwarding: true)

        when Prism::LocalVariableOrWriteNode
          read  = Ast::LocalVariableRead.new(prism_node.name, prism_node.depth)
          write = Ast::LocalVariableWrite.new(prism_node.name, prism_node.depth, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::LocalVariableAndWriteNode
          read  = Ast::LocalVariableRead.new(prism_node.name, prism_node.depth)
          write = Ast::LocalVariableWrite.new(prism_node.name, prism_node.depth, transform(prism_node.value))
          Ast::And.new(read, write)

        when Prism::InstanceVariableOrWriteNode
          read  = Ast::InstanceVariableRead.new(prism_node.name)
          write = Ast::InstanceVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::InstanceVariableAndWriteNode
          read  = Ast::InstanceVariableRead.new(prism_node.name)
          write = Ast::InstanceVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::And.new(read, write)

        when Prism::GlobalVariableOrWriteNode
          read  = Ast::GlobalVariableRead.new(prism_node.name)
          write = Ast::GlobalVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::GlobalVariableAndWriteNode
          read  = Ast::GlobalVariableRead.new(prism_node.name)
          write = Ast::GlobalVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::And.new(read, write)

        when Prism::ConstantOrWriteNode
          read  = Ast::ConstantRead.new(prism_node.name)
          write = Ast::ConstantWrite.new(prism_node.name, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::ConstantAndWriteNode
          read  = Ast::ConstantRead.new(prism_node.name)
          write = Ast::ConstantWrite.new(prism_node.name, transform(prism_node.value))
          Ast::And.new(read, write)

        when Prism::ConstantPathNode
          if prism_node.parent.nil?
            # ::Foo — absolute constant path from root (OBJECT_CLASS)
            Ast::ConstantRead.new(prism_node.child.name)
          else
            parent_node = transform(prism_node.parent)
            Ast::ConstantPath.new(parent_node, prism_node.child.name)
          end

        when Prism::ConstantPathWriteNode
          parent_node = transform(prism_node.target.parent)
          Ast::ConstantPathWrite.new(parent_node, prism_node.target.child.name, transform(prism_node.value))

        when Prism::ConstantPathOrWriteNode
          read  = Ast::ConstantPath.new(transform(prism_node.target.parent), prism_node.target.child.name)
          write = Ast::ConstantPathWrite.new(transform(prism_node.target.parent), prism_node.target.child.name, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::ClassVariableReadNode
          Ast::ClassVariableRead.new(prism_node.name)

        when Prism::ClassVariableWriteNode
          Ast::ClassVariableWrite.new(prism_node.name, transform(prism_node.value))

        when Prism::ClassVariableOperatorWriteNode
          read = Ast::ClassVariableRead.new(prism_node.name)
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::ClassVariableWrite.new(prism_node.name, rhs)

        when Prism::ClassVariableOrWriteNode
          read  = Ast::ClassVariableRead.new(prism_node.name)
          write = Ast::ClassVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::Or.new(read, write)

        when Prism::ClassVariableAndWriteNode
          read  = Ast::ClassVariableRead.new(prism_node.name)
          write = Ast::ClassVariableWrite.new(prism_node.name, transform(prism_node.value))
          Ast::And.new(read, write)

        when Prism::IndexOperatorWriteNode
          receiver_node = transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          read = Ast::MethodCall.new(:[], receiver_node, index_args, {})
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [val_node], {})
          Ast::MethodCall.new(:[]=, receiver_node, index_args + [rhs], {})

        when Prism::IndexOrWriteNode
          receiver_node = transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          read  = Ast::MethodCall.new(:[], receiver_node, index_args, {})
          write = Ast::MethodCall.new(:[]=, receiver_node, index_args + [val_node], {})
          Ast::Or.new(read, write)

        when Prism::IndexAndWriteNode
          receiver_node = transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          read  = Ast::MethodCall.new(:[], receiver_node, index_args, {})
          write = Ast::MethodCall.new(:[]=, receiver_node, index_args + [val_node], {})
          Ast::And.new(read, write)

        when Prism::InterpolatedSymbolNode
          parts = prism_node.parts.map do |part|
            case part
            when Prism::StringNode           then Ast::StringLiteral.from(part.unescaped)
            when Prism::EmbeddedStatementsNode then transform(part.statements)
            else raise "Unexpected interpolated symbol part type #{part.class}"
            end
          end
          Ast::MethodCall.new(:to_sym, Ast::InterpolatedString.new(parts), [], {})

        when Prism::RangeNode
          begin_node = prism_node.left.nil? ? nil : transform(prism_node.left)
          end_node   = prism_node.right.nil? ? nil : transform(prism_node.right)
          Ast::RangeLiteral.new(begin_node, end_node, prism_node.exclude_end?)

        when Prism::SourceFileNode
          Ast::StringLiteral.from(prism_node.filepath)

        when Prism::SourceLineNode
          Ast::IntegerLiteral.from(prism_node.location.start_line)

        when Prism::BackReferenceReadNode
          Ast::GlobalVariableRead.new(prism_node.name)

        when Prism::NumberedReferenceReadNode
          Ast::GlobalVariableRead.new(:"$#{prism_node.number}")

        when Prism::KeywordHashNode
          # KeywordHashNode used as a value expression (e.g. in yield args, array literals)
          pairs = prism_node.elements.map do |assoc|
            case assoc
            when Prism::AssocNode then [transform(assoc.key), transform(assoc.value)]
            when Prism::AssocSplatNode then [nil, transform(assoc.value)]
            else raise "Unexpected KeywordHashNode element: #{assoc.class}"
            end
          end
          Ast::HashLiteral.new(pairs)

        when Prism::ConstantPathOperatorWriteNode
          parent_node = transform(prism_node.target.parent)
          child_name  = prism_node.target.child.name
          read  = Ast::ConstantPath.new(parent_node, child_name)
          rhs   = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::ConstantPathWrite.new(parent_node, child_name, rhs)

        when Prism::CallOrWriteNode
          receiver_node = prism_node.receiver ? transform(prism_node.receiver) : nil
          read  = Ast::MethodCall.new(prism_node.read_name, receiver_node, [], {})
          write = Ast::MethodCall.new(prism_node.write_name, receiver_node, [transform(prism_node.value)], {})
          Ast::Or.new(read, write)

        when Prism::CallAndWriteNode
          receiver_node = prism_node.receiver ? transform(prism_node.receiver) : nil
          read  = Ast::MethodCall.new(prism_node.read_name, receiver_node, [], {})
          write = Ast::MethodCall.new(prism_node.write_name, receiver_node, [transform(prism_node.value)], {})
          Ast::And.new(read, write)

        when Prism::CallOperatorWriteNode
          receiver_node = prism_node.receiver ? transform(prism_node.receiver) : nil
          read = Ast::MethodCall.new(prism_node.read_name, receiver_node, [], {})
          rhs  = Ast::MethodCall.new(prism_node.operator, read, [transform(prism_node.value)], {})
          Ast::MethodCall.new(prism_node.write_name, receiver_node, [rhs], {})

        when Prism::FlipFlopNode
          # Flip-flop not implemented; evaluates to false
          Ast::FalseLiteral::FALSE

        else
          raise FrozoneException.make(:NotImplementedError, "Unsupported Ruby feature: #{prism_node.class.name.split('::').last.sub('Node', '')}")
        end
      end
    end
  end
end

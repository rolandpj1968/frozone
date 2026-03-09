require 'prism'

require_relative '../ast'

module Frozone
  module Vm
    class Parser
      def initialize(text, dump_ast = false)
        @text = text
        @dump_ast = dump_ast
      end

      def ast
        program_node = Prism.parse(@text).value

        puts program_node.inspect if @dump_ast

        raise "Unexpected Prism.parse value type #{value.class} expecting Prism::ProgramNode" unless program_node.is_a?(Prism::ProgramNode)

        transform(program_node.statements)
      end

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
          elsif target.expression.is_a?(Prism::LocalVariableTargetNode)
            [:local_splat, target.expression.name, target.expression.depth]
          elsif target.expression.is_a?(Prism::InstanceVariableTargetNode)
            [:ivar_splat, target.expression.name]
          else
            raise "Unsupported splat target type: #{target.expression.class}"
          end
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
              raise "block required parameter is not a Prism::RequiredParameterNode" unless required.is_a?(Prism::RequiredParameterNode)
              required.name
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

        when Prism::ArrayNode
          Ast::ArrayLiteral.new(prism_node.elements.map { |e| transform(e) })

        when Prism::HashNode
          kv_nodes = prism_node.elements.map do |kv|
            raise "Hash literal element is not a Prism::AssocNode" unless kv.is_a?(Prism::AssocNode)
            [transform(kv.key), transform(kv.value)]
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
          raise "begin..end while not yet supported" if prism_node.begin_modifier?
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          Ast::While.new(transform(prism_node.predicate), body)

        when Prism::UntilNode
          raise "begin..end until not yet supported" if prism_node.begin_modifier?
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          Ast::Until.new(transform(prism_node.predicate), body)

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
            Ast::IntrinsicCall.new(prism_node.name, prism_node.arguments.arguments.map { |pn| transform(pn) })
          else
            receiver_node = prism_node.receiver.nil? ? nil : transform(prism_node.receiver)
            arg_nodes = []
            kw_args = {}
            unless prism_node.arguments.nil?
              prism_node.arguments.arguments.each do |argument|
                # Prism parses this a bit weirdly - keyword args appear as a Prism::KeywordHashNode in the general arguments array
                case argument
                when Prism::KeywordHashNode
                  kw_args = argument.elements.to_h do |kw_arg|
                    raise "Keyword argument is not a Prism::AssocNode" unless kw_arg.is_a?(Prism::AssocNode)
                    # TODO - this is a runtime error"
                    raise "syntax errors found" if kw_arg.value.is_a?(Prism::MissingNode)

                    [transform(kw_arg.key), transform(kw_arg.value)]
                  end
                else
                  arg_nodes << transform(argument)
                end
              end
            end

            block_node =
              case prism_node.block
              when nil then nil
              when Prism::BlockNode then parse_block(prism_node.block)
              else raise "Unsupported block type: #{prism_node.block.class}"
              end

            Ast::MethodCall.new(prism_node.name, receiver_node, arg_nodes, kw_args, block_node)
          end

        when Prism::ModuleNode
          unless prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "module defs with nested namespaced paths are not yet implemented"
          end
          unless prism_node.constant_path.name.is_a?(Symbol) and prism_node.constant_path.name.equal?(prism_node.name)
            raise "Prism or RPJ or both are confused"
          end
          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
          Ast::ModuleDef.new(prism_node.name, prism_node.locals, body_ast)

        when Prism::ClassNode
          # Prism seems a bit weird - it successfully parses class defns where the class name can be an arbitrary expression
          #   prehaps looking to the future?
          unless prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "class defs with nested namespaced paths are not yet implemented"
          end
          unless prism_node.constant_path.name.is_a?(Symbol) and prism_node.constant_path.name.equal?(prism_node.name)
            raise "Prism or RPJ or both are confused"
          end
          # TODO - disappointing that we need to use upcase here
          unless prism_node.name.length > 0 && prism_node.name[0].upcase == prism_node.name[0]
            # TODO - this is a real runtime error
            raise "class name '#{prism_node.name} is not a valid constant name"
          end
          superclass_node =
            if prism_node.superclass.nil?
              nil
            elsif prism_node.superclass.is_a?(Prism::ConstantReadNode)
              Ast::ConstantRead.new(prism_node.superclass.name)
            else
              raise "class superclass must be a simple constant name (e.g. class B < A)"
            end
          body_ast = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
          Ast::ClassDef.new(prism_node.name, prism_node.locals, superclass_node, body_ast)

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

        when Prism::BeginNode
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          rescue_clauses = []
          rc = prism_node.rescue_clause
          while rc
            exc_nodes = rc.exceptions.map { |e| transform(e) }
            var_name, var_depth =
              if rc.reference.nil?
                [nil, nil]
              elsif rc.reference.is_a?(Prism::LocalVariableTargetNode)
                [rc.reference.name, rc.reference.depth]
              else
                raise "Unsupported rescue reference type: #{rc.reference.class}"
              end
            rc_body = rc.statements.nil? ? Ast::NilLiteral::NIL : transform(rc.statements)
            rescue_clauses << Ast::RescueClause.new(exc_nodes, var_name, var_depth, rc_body)
            rc = rc.consequent
          end
          else_node   = prism_node.else_clause.nil?   ? nil : transform(prism_node.else_clause)
          ensure_node = prism_node.ensure_clause.nil? ? nil : transform(prism_node.ensure_clause.statements)
          Ast::BeginRescue.new(body, rescue_clauses, else_node, ensure_node)

        when Prism::AliasMethodNode
          raise "new_name #{prism_node.new_name.class} must be a Prism::SymbolNode" unless prism_node.new_name.is_a?(Prism::SymbolNode)
          raise "old_name #{prism_node.old_name.class} must be a Prism::SymbolNode" unless prism_node.old_name.is_a?(Prism::SymbolNode)
          Ast::MethodAlias.new(prism_node.new_name.unescaped.to_sym, prism_node.old_name.unescaped.to_sym)

        when Prism::BreakNode
          value_node = prism_node.arguments.nil? || prism_node.arguments.arguments.empty? ? nil : transform(prism_node.arguments.arguments.first)
          Ast::Break.new(value_node)

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
          parent_node = transform(prism_node.parent)
          Ast::ConstantPath.new(parent_node, prism_node.child.name)

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

        else
          raise "Unexpected Prism node type #{prism_node.class}"
        end
      end
    end
  end
end

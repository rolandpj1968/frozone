require 'prism'

require_relative '../ast'

module Frozone
  module Vm
    class Parser
      attr_reader :text, :dump_ast

      def initialize(text, dump_ast = false)
        @text = text
        @dump_ast = dump_ast
      end

      def ast
        program_node = Prism.parse(text).value

        puts program_node.inspect if dump_ast

        raise "Unexpected Prism.parse value type #{value.class} expecting Prism::ProgramNode" unless program_node.is_a?(Prism::ProgramNode)

        transform(program_node.statements)
      end

      private

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
          puts "Hallo RPJ"
          Ast::ArrayLiteral.new(prism_node.elements.map { |e| transform(e) })
          
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

        when Prism::ElseNode
          transform(prism_node.statements)

        when Prism::LocalVariableReadNode
          Ast::LocalVariableRead.new(prism_node.name, prism_node.depth)

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
            args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |pn| transform(pn) }

            Ast::MethodCall.new(prism_node.name, receiver_node, args)
          end

        when Prism::ClassNode
          # Prism seems a bit weird - it successfully parses class defns where the class name can be an arbitrary expression
          #   prehaps looking to the future?
          unless prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "class defs with nested namespaced paths are not yet implemented"
          end
          unless prism_node.constant_path.name.is_a?(Symbol) and prism_node.constant_path.name.equal?(prism_node.name)
            raise "Prism or RPJ or both are confused"
          end
          unless prism_node.superclass.nil?
            raise "class inheritance not yet implemented"
          end
          # TODO - disappointing that we need to use upcase here
          unless prism_node.name.length > 0 && prism_node.name[0].upcase == prism_node.name[0]
            # TODO - this is a real runtime error
            raise "class name '#{prism_node.name} is not a valid constant name"
          end
          body_ast =
            if prism_node.body.nil?
              Ast::NilLiteral::NIL
            else
              transform(prism_node.body)
            end
          Ast::ClassDef.new(prism_node.name, prism_node.locals, body_ast)

        when Prism::DefNode
          raise "singleton/receiver method defs not supported yet" unless prism_node.receiver.nil?

          required_params = []
          unless prism_node.parameters.nil?
            raise "Prism::DefNode is not a Prism::ParametersNode" unless prism_node.parameters.is_a?(Prism::ParametersNode)
            parameters = prism_node.parameters
            raise "optional params not yet supported" unless parameters.optionals.empty?
            raise "*rest params not yet supported" unless parameters.rest.nil?
            raise "posts params not yet supported" unless parameters.posts.empty?
            raise "keyword params not yet supported" unless parameters.keywords.empty?
            raise "**keyword_rest params not yet supported" unless parameters.keyword_rest.nil?
            raise "block param not yet supported" unless parameters.block.nil?
            required_params = parameters.requireds.map do |required|
              raise "required parameter is not a Prism::RequiredParameterNode" unless required.is_a?(Prism::RequiredParameterNode)
              required.name
            end
          end
          #raise "not sure what locals_body_index is - expecting same as params count" unless prism_node.locals_body_index == params.length - not present in ruby 4.0.1

          body_ast =
            if prism_node.body.nil?
              Ast::NilLiteral::NIL
            else
              transform(prism_node.body)
            end
          Ast::MethodDef.new(prism_node.name, required_params, optional_params = nil, rest_param = nil, post_params = nil, prism_node.locals, body_ast)

        when Prism::AliasMethodNode
          raise "new_name #{prism_node.new_name.class} must be a Prism::SymbolNode" unless prism_node.new_name.is_a?(Prism::SymbolNode)
          raise "old_name #{prism_node.old_name.class} must be a Prism::SymbolNode" unless prism_node.old_name.is_a?(Prism::SymbolNode)
          Ast::MethodAlias.new(prism_node.new_name.unescaped.to_sym, prism_node.old_name.unescaped.to_sym)

        else
          raise "Unexpected Prism node type #{prism_node.class}"
        end
      end
    end
  end
end

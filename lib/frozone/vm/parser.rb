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

      def ast(raise_syntax_errors: false)
        parse_opts = @filepath ? { filepath: @filepath } : {}
        result = Prism.parse(@text, **parse_opts)

        if raise_syntax_errors && result.errors.any?
          msg = result.errors.map(&:message).first
          raise FrozoneException.make(:SyntaxError, msg)
        end

        program_node = result.value
        puts program_node.inspect if @dump_ast

        raise "Unexpected Prism.parse value type #{program_node.class} expecting Prism::ProgramNode" unless program_node.is_a?(Prism::ProgramNode)

        @top_level_locals = program_node.locals
        transform(program_node.statements)
      end

      def top_level_locals = @top_level_locals || []

      private

      def parse_lambda(prism_node)
        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, _auto_splat =
          parse_block_or_lambda_params(prism_node.parameters, auto_splat: false)
        body = prism_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_node.body)
        [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, prism_node.locals, body]
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

      def parse_multi_target_param(node)
        # Returns {names: [...], rest: name_or_nil, rights: [...]}
        # Each element of names/rights is either a Symbol or a nested Hash (for nested destructuring).
        names  = node.lefts.map { |n|
          case n
          when Prism::RequiredParameterNode then n.name
          when Prism::MultiTargetNode       then parse_multi_target_param(n)
          end
        }.compact
        rest   = case node.rest
                 when Prism::RestParameterNode then node.rest.name || :__anon_rest__
                 when Prism::SplatNode then node.rest.expression.is_a?(Prism::RequiredParameterNode) ? node.rest.expression.name : :__anon_rest__
                 else nil
                 end
        rights = node.rights.map { |n|
          case n
          when Prism::RequiredParameterNode then n.name
          when Prism::MultiTargetNode       then parse_multi_target_param(n)
          end
        }.compact
        { names: names, rest: rest, rights: rights }
      end

      def parse_block(prism_block_node)
        required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, auto_splat =
          parse_block_or_lambda_params(prism_block_node.parameters, auto_splat: true)
        body = prism_block_node.body.nil? ? Ast::NilLiteral::NIL : transform(prism_block_node.body)
        # Compute locals: recursively expand destructure params to their sub-variable names
        locals = prism_block_node.locals.dup
        required.each { |p| locals.concat(extract_destruct_names(p)) if p.is_a?(Hash) }
        Ast::Block.new(required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param,
                       auto_splat, locals, body)
      end

      def extract_destruct_names(param)
        return [param] if param.is_a?(Symbol)
        names = param[:names].flat_map { |n| extract_destruct_names(n) }
        names << param[:rest] if param[:rest]
        names + (param[:rights] || []).flat_map { |n| extract_destruct_names(n) }
      end

      # Parse block/lambda params from a Prism BlockParametersNode or ParametersNode.
      # Returns [required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, auto_splat]
      def parse_block_or_lambda_params(params_node, auto_splat: false)
        required_params = []; optional_params = []; rest_param = nil; post_params = []
        required_kw_params = []; optional_kw_params = []; kw_rest_param = nil; block_param = nil
        implicit_rest = false

        return [required_params, optional_params, rest_param, post_params,
                required_kw_params, optional_kw_params, kw_rest_param, block_param, false] if params_node.nil?

        if params_node.is_a?(Prism::NumberedParametersNode)
          n = params_node.respond_to?(:maximum) ? params_node.maximum : 9
          required_params = (1..n).map { |i| :"_#{i}" }
          # Numbered params: auto-splat if 2+ params
          as = auto_splat && n >= 2
          return [required_params, optional_params, rest_param, post_params,
                  required_kw_params, optional_kw_params, kw_rest_param, block_param, as]
        end

        # Extract ParametersNode from BlockParametersNode
        parameters = if params_node.is_a?(Prism::BlockParametersNode)
                       block_param = nil  # block-local vars are just locals, not the &block
                       params_node.parameters
                     else
                       params_node  # ParametersNode directly (for lambdas)
                     end

        return [required_params, optional_params, rest_param, post_params,
                required_kw_params, optional_kw_params, kw_rest_param, block_param, false] if parameters.nil?

        seen_param_names = {}
        required_params = parameters.requireds.filter_map do |r|
          case r
          when Prism::RequiredParameterNode
            name = r.name
            # Duplicate `_` params (blank params): use a unique discard name for 2nd+
            if seen_param_names[name]
              :"__discard_#{r.object_id}__"
            else
              seen_param_names[name] = true
              name
            end
          when Prism::MultiTargetNode then parse_multi_target_param(r)
          else nil
          end
        end

        optional_params = parameters.optionals.map do |o|
          [o.name, transform(o.value)]
        end

        unless parameters.rest.nil?
          case parameters.rest
          when Prism::RestParameterNode then rest_param = parameters.rest.name || :__anon_rest__
          when Prism::ImplicitRestNode  then implicit_rest = true
          end
        end

        post_params = parameters.posts.filter_map do |p|
          p.is_a?(Prism::RequiredParameterNode) ? p.name : nil
        end

        parameters.keywords.each do |kw|
          case kw
          when Prism::RequiredKeywordParameterNode  then required_kw_params << kw.name
          when Prism::OptionalKeywordParameterNode  then optional_kw_params << [kw.name, transform(kw.value)]
          end
        end

        case parameters.keyword_rest
        when Prism::KeywordRestParameterNode
          kw_rest_param = parameters.keyword_rest.name || :__anon_kwargs__
        when Prism::NoKeywordsParameterNode
          kw_rest_param = :__no_kwargs__
        end

        unless parameters.block.nil?
          block_param = parameters.block.name || :__anon_block__
        end

        # Also check BlockParametersNode locals for &block param
        if params_node.is_a?(Prism::BlockParametersNode) && params_node.respond_to?(:opening_loc)
          # block_param already set from parameters.block above
        end

        # Auto-splat: procs/blocks auto-splat unless:
        #   - empty params, OR single required (no others), OR single optional (no others),
        #     OR single rest (no others)
        if auto_splat
          no_req_kw = required_kw_params.empty? && optional_kw_params.empty?
          no_post = post_params.empty?
          is_empty        = required_params.empty? && optional_params.empty? && rest_param.nil? && !implicit_rest && no_post
          is_single_req   = required_params.length == 1 && optional_params.empty? && rest_param.nil? && !implicit_rest && no_post
          is_single_opt   = required_params.empty? && optional_params.length == 1 && rest_param.nil? && !implicit_rest && no_post && no_req_kw
          is_rest_only    = required_params.empty? && optional_params.empty? && rest_param && !implicit_rest && no_post
          auto_splat = !is_empty && !is_single_req && !is_single_opt && !is_rest_only
        end

        [required_params, optional_params, rest_param, post_params,
         required_kw_params, optional_kw_params, kw_rest_param, block_param, auto_splat]
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
          # Anonymous block param `&` has name=nil; use synthetic name for forwarding support
          block_param = parameters.block.nil? ? nil : (parameters.block.name || :__anon_block__)
          required_params = parameters.requireds.filter_map do |required|
            case required
            when Prism::RequiredParameterNode then required.name
            when Prism::MultiTargetNode       then parse_multi_target_param(required)
            else nil
            end
          end
          optional_params = parameters.optionals.map do |optional|
            raise "optional parameter is not a Prism::OptionalParameterNode" unless optional.is_a?(Prism::OptionalParameterNode)
            [optional.name, transform(optional.value)]
          end
          unless parameters.rest.nil?
            raise "rest parameter is not a Prism::RestParameterNode" unless parameters.rest.is_a?(Prism::RestParameterNode)
            # Anonymous rest `*` uses synthetic name for forwarding
            rest_param = parameters.rest.name || :__anon_rest__
          end
          post_params = parameters.posts.filter_map do |post|
            case post
            when Prism::RequiredParameterNode then post.name
            when Prism::MultiTargetNode       then parse_multi_target_param(post)
            else nil
            end
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
            if parameters.keyword_rest.is_a?(Prism::ForwardingParameterNode)
              # def foo(...) — capture all args, kwargs, block for forwarding
              rest_param     = :__forward_args__
              kw_rest_param  = :__forward_kwargs__
              block_param    = :__forward_block__
            elsif parameters.keyword_rest.is_a?(Prism::NoKeywordsParameterNode)
              # **nil disallows all keyword arguments
              kw_rest_param = :__no_kwargs__
            elsif parameters.keyword_rest.is_a?(Prism::KeywordRestParameterNode)
              # Anonymous `**` uses synthetic name for forwarding
              kw_rest_param = parameters.keyword_rest.name || :__anon_kwargs__
            end
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
            receiver_node = (prism_node.receiver.nil? || prism_node.receiver.is_a?(Prism::SelfNode)) ? nil : transform(prism_node.receiver)
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
                        # Anonymous `**` with no value — forward __anon_kwargs__
                        splat_val = kw_arg.value.nil? ? Ast::LocalVariableRead.new(:__anon_kwargs__, 0) : transform(kw_arg.value)
                        kw_splats << splat_val
                      else
                        raise "Unexpected KeywordHashNode element: #{kw_arg.class}"
                      end
                    end
                  end
                when Prism::SplatNode
                  # Anonymous `*` with no expression — forward __anon_rest__
                  splat_expr = argument.expression.nil? ? Ast::LocalVariableRead.new(:__anon_rest__, 0) : transform(argument.expression)
                  arg_nodes << Ast::SplatArg.new(splat_expr)
                when Prism::ForwardingArgumentsNode
                  # bar(...) — expand forwarded args, kwargs, block
                  arg_nodes << Ast::SplatArg.new(Ast::LocalVariableRead.new(:__forward_args__, 0))
                  kw_splats << Ast::LocalVariableRead.new(:__forward_kwargs__, 0)
                  # block is handled below via __forward_block__
                else
                  arg_nodes << transform(argument)
                end
              end
            end

            # Check if ForwardingArgumentsNode was used — if so, use __forward_block__ as block
            has_forwarding = !prism_node.arguments.nil? &&
              prism_node.arguments.arguments.any? { |a| a.is_a?(Prism::ForwardingArgumentsNode) }

            block_node =
              if has_forwarding
                Ast::BlockArg.new(Ast::LocalVariableRead.new(:__forward_block__, 0))
              else
                case prism_node.block
                when nil then nil
                when Prism::BlockNode then parse_block(prism_node.block)
                when Prism::BlockArgumentNode
                  expr = prism_node.block.expression
                  expr.nil? ? Ast::ForwardBlock::INSTANCE : Ast::BlockArg.new(transform(expr))
                else raise "Unsupported block type: #{prism_node.block.class}"
                end
              end

            safe_nav = prism_node.safe_navigation?
            if prism_node.attribute_write?
              Ast::AttributeWrite.new(prism_node.name, receiver_node, arg_nodes, kw_args, safe_nav: safe_nav)
            else
              Ast::MethodCall.new(prism_node.name, receiver_node, arg_nodes, kw_args, block_node, kw_splat_nodes: kw_splats, safe_nav: safe_nav)
            end
          end

        when Prism::ModuleNode
          namespace_node = nil
          if prism_node.constant_path.is_a?(Prism::ConstantPathNode)
            # module A::B — namespace_node evaluates to A
            # module ::A — parent is nil (absolute path), namespace is root Object
            namespace_node = prism_node.constant_path.parent.nil? ? Ast::RootNamespaceNode::INSTANCE : transform(prism_node.constant_path.parent)
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
            # class ::A — parent is nil (absolute path), namespace is root Object
            namespace_node = prism_node.constant_path.parent.nil? ? Ast::RootNamespaceNode::INSTANCE : transform(prism_node.constant_path.parent)
          elsif !prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            raise "unexpected class name type: #{prism_node.constant_path.class}"
          end
          # TODO - disappointing that we need to use upcase here
          unless prism_node.name.length > 0 && prism_node.name[0].upcase == prism_node.name[0]
            # TODO - this is a real runtime error
            raise "class name '#{prism_node.name}' is not a valid constant name"
          end
          superclass_node = prism_node.superclass.nil? ? nil : transform(prism_node.superclass)
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
          required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, locals, body = parse_lambda(prism_node)
          Ast::Lambda.new(required, optional, rest, post, req_kw, opt_kw, kw_rest, block_param, locals, body)

        when Prism::YieldNode
          arg_nodes = []
          kw_args   = {}
          unless prism_node.arguments.nil?
            prism_node.arguments.arguments.each do |argument|
              case argument
              when Prism::KeywordHashNode
                has_rocket = argument.elements.any? { |e| e.is_a?(Prism::AssocNode) && !e.operator_loc.nil? }
                if has_rocket
                  pairs = argument.elements.map { |e| [transform(e.key), transform(e.value)] }
                  arg_nodes << Ast::HashLiteral.new(pairs)
                else
                  argument.elements.each do |kw_arg|
                    kw_args[transform(kw_arg.key)] = transform(kw_arg.value) if kw_arg.is_a?(Prism::AssocNode)
                  end
                end
              when Prism::SplatNode
                splat_expr = argument.expression.nil? ? Ast::LocalVariableRead.new(:__anon_rest__, 0) : transform(argument.expression)
                arg_nodes << Ast::SplatArg.new(splat_expr)
              else
                arg_nodes << transform(argument)
              end
            end
          end
          Ast::Yield.new(arg_nodes, kw_args)

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
          transform_defined_value(prism_node.value)

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
            elsif rc.reference.is_a?(Prism::ClassVariableTargetNode)
              assign_node = Ast::ClassVariableWrite.new(rc.reference.name, Ast::NilLiteral::NIL)
            elsif rc.reference.is_a?(Prism::ConstantTargetNode)
              assign_node = Ast::ConstantWrite.new(rc.reference.name, Ast::NilLiteral::NIL)
            elsif rc.reference.is_a?(Prism::CallTargetNode)
              receiver_node = rc.reference.receiver.is_a?(Prism::SelfNode) ? nil : transform(rc.reference.receiver)
              assign_node = Ast::RescueCallTarget.new(receiver_node, rc.reference.name, rc.reference.safe_navigation?)
            elsif rc.reference.is_a?(Prism::IndexTargetNode)
              receiver_node = rc.reference.receiver.is_a?(Prism::SelfNode) ? nil : transform(rc.reference.receiver)
              arg_nodes = (rc.reference.arguments&.arguments || []).map { |a| transform(a) }
              assign_node = Ast::RescueIndexTarget.new(receiver_node, arg_nodes)
            else
              assign_node = nil
            end
            rc_body = rc.statements.nil? ? Ast::NilLiteral::NIL : transform(rc.statements)
            rescue_clauses << Ast::RescueClause.new(exc_nodes, var_name, var_depth, rc_body, assign_node: assign_node)
            rc = rc.consequent
          end
          else_node   = prism_node.else_clause.nil?   ? nil : transform(prism_node.else_clause)
          ensure_node = prism_node.ensure_clause.nil? ? nil : transform(prism_node.ensure_clause.statements)
          Ast::Rescue.new(body, rescue_clauses, else_node, ensure_node)

        when Prism::RescueModifierNode
          # expr rescue fallback  →  begin; expr; rescue StandardError; fallback; end
          body = transform(prism_node.expression)
          fallback = transform(prism_node.rescue_expression)
          Ast::Rescue.new(body, [Ast::RescueClause.new([], nil, nil, fallback)], nil, nil)

        when Prism::AliasGlobalVariableNode
          # alias $new $old — stub as nil (Frozone uses a flat globals hash)
          Ast::NilLiteral::NIL

        when Prism::UndefNode
          # undef :foo, :bar — remove methods from current class
          stmts = prism_node.names.map do |sym_node|
            name_node = case sym_node
                        when Prism::SymbolNode
                          Ast::SymbolLiteral.from(sym_node.unescaped.to_sym)
                        when Prism::InterpolatedSymbolNode
                          # Dynamic undef: evaluate interpolation, convert to symbol
                          transform(sym_node)  # InterpolatedSymbolNode → MethodCall(:to_sym, ...)
                        else
                          Ast::SymbolLiteral.from(sym_node.unescaped.to_sym)
                        end
            Ast::IntrinsicCall.new(:module_undef_method, [Ast::SelfLiteral::SELF, name_node])
          end
          stmts.length == 1 ? stmts[0] : Ast::Sequence.new(stmts)

        when Prism::AliasMethodNode
          # Alias with non-simple symbol names (e.g. interpolated) — stub as nil
          if prism_node.new_name.is_a?(Prism::SymbolNode) && prism_node.old_name.is_a?(Prism::SymbolNode)
            Ast::MethodAlias.new(prism_node.new_name.unescaped.to_sym, prism_node.old_name.unescaped.to_sym)
          else
            Ast::NilLiteral::NIL
          end

        when Prism::BreakNode
          value_node = prism_node.arguments.nil? || prism_node.arguments.arguments.empty? ? nil : transform(prism_node.arguments.arguments.first)
          Ast::Break.new(value_node)

        when Prism::XStringNode, Prism::InterpolatedXStringNode
          # Backtick command execution — not supported; return empty string stub
          Ast::StringLiteral.from("")

        when Prism::SuperNode
          raw_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments
          has_forwarding = raw_args.any? { |a| a.is_a?(Prism::ForwardingArgumentsNode) }
          arg_nodes = []
          kw_splats = []
          raw_args.each do |a|
            if a.is_a?(Prism::ForwardingArgumentsNode)
              arg_nodes << Ast::SplatArg.new(Ast::LocalVariableRead.new(:__forward_args__, 0))
              kw_splats << Ast::LocalVariableRead.new(:__forward_kwargs__, 0)
            else
              arg_nodes << transform(a)
            end
          end
          block_node = if has_forwarding
                         Ast::BlockArg.new(Ast::LocalVariableRead.new(:__forward_block__, 0))
                       else
                         case prism_node.block
                         when nil then nil
                         when Prism::BlockNode then parse_block(prism_node.block)
                         when Prism::BlockArgumentNode
                           expr = prism_node.block.expression
                           expr.nil? ? Ast::ForwardBlock::INSTANCE : Ast::BlockArg.new(transform(expr))
                         else raise "Unsupported super block type: #{prism_node.block.class}"
                         end
                       end
          Ast::Super.new(arg_nodes, block_node, forwarding: false, kw_splat_nodes: kw_splats)

        when Prism::ForwardingSuperNode
          block_node = case prism_node.block
                       when nil then nil
                       when Prism::BlockNode then parse_block(prism_node.block)
                       when Prism::BlockArgumentNode
                expr = prism_node.block.expression
                expr.nil? ? Ast::ForwardBlock::INSTANCE : Ast::BlockArg.new(transform(expr))
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
          Ast::ConstantOrWrite.new(prism_node.name, transform(prism_node.value))

        when Prism::ConstantAndWriteNode
          Ast::ConstantAndWrite.new(prism_node.name, transform(prism_node.value))

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
          if prism_node.target.parent.nil?
            # ::FOO ||= val
            Ast::ConstantPathOrWrite.new(Ast::RootNamespaceNode::INSTANCE, prism_node.target.child.name, transform(prism_node.value))
          else
            Ast::ConstantPathOrWrite.new(transform(prism_node.target.parent), prism_node.target.child.name, transform(prism_node.value))
          end

        when Prism::ConstantPathAndWriteNode
          if prism_node.target.parent.nil?
            # ::FOO &&= val
            Ast::ConstantPathAndWrite.new(Ast::RootNamespaceNode::INSTANCE, prism_node.target.child.name, transform(prism_node.value))
          else
            Ast::ConstantPathAndWrite.new(transform(prism_node.target.parent), prism_node.target.child.name, transform(prism_node.value))
          end

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
          receiver_node = prism_node.receiver.is_a?(Prism::SelfNode) ? nil : transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          Ast::IndexOperatorWrite.new(prism_node.operator, receiver_node, index_args, val_node)

        when Prism::IndexOrWriteNode
          receiver_node = prism_node.receiver.is_a?(Prism::SelfNode) ? nil : transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          Ast::IndexOrWrite.new(receiver_node, index_args, val_node)

        when Prism::IndexAndWriteNode
          receiver_node = prism_node.receiver.is_a?(Prism::SelfNode) ? nil : transform(prism_node.receiver)
          index_args = prism_node.arguments.nil? ? [] : prism_node.arguments.arguments.map { |a| transform(a) }
          val_node = transform(prism_node.value)
          Ast::IndexAndWrite.new(receiver_node, index_args, val_node)

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

        when Prism::SourceEncodingNode
          # Returns the Encoding object for the current source file encoding (UTF-8)
          Ast::ConstantPath.new(Ast::ConstantRead.new(:Encoding), :UTF_8)

        when Prism::MatchWriteNode
          # /(?<name>...)/ =~ string — perform match and assign named captures to locals
          call_node = transform(prism_node.call)
          targets = prism_node.targets.map { |t| [t.depth, t.name] }
          Ast::MatchWrite.new(call_node, targets)

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
          receiver_node = (prism_node.receiver.nil? || prism_node.receiver.is_a?(Prism::SelfNode)) ? nil : transform(prism_node.receiver)
          Ast::CallOrWrite.new(prism_node.read_name, prism_node.write_name, receiver_node, transform(prism_node.value), safe_nav: prism_node.safe_navigation?)

        when Prism::CallAndWriteNode
          receiver_node = (prism_node.receiver.nil? || prism_node.receiver.is_a?(Prism::SelfNode)) ? nil : transform(prism_node.receiver)
          Ast::CallAndWrite.new(prism_node.read_name, prism_node.write_name, receiver_node, transform(prism_node.value), safe_nav: prism_node.safe_navigation?)

        when Prism::CallOperatorWriteNode
          receiver_node = (prism_node.receiver.nil? || prism_node.receiver.is_a?(Prism::SelfNode)) ? nil : transform(prism_node.receiver)
          Ast::CallOperatorWrite.new(prism_node.read_name, prism_node.write_name, prism_node.operator, receiver_node, transform(prism_node.value), safe_nav: prism_node.safe_navigation?)

        when Prism::ForNode
          # for x in collection; body; end
          # For loops do NOT create a new scope - use target descriptor for direct assignment.
          target = case prism_node.index
                   when Prism::LocalVariableTargetNode
                     [:local, prism_node.index.name]
                   when Prism::InstanceVariableTargetNode
                     [:ivar, prism_node.index.name]
                   when Prism::ClassVariableTargetNode
                     [:cvar, prism_node.index.name]
                   when Prism::GlobalVariableTargetNode
                     [:gvar, prism_node.index.name]
                   when Prism::MultiTargetNode
                     idx = prism_node.index
                     lefts = (idx.lefts rescue []).filter_map { |r| r.is_a?(Prism::LocalVariableTargetNode) ? r.name : nil }
                     rest_sym = case (idx.rest rescue nil)
                                when Prism::SplatNode
                                  expr = idx.rest.expression
                                  expr.is_a?(Prism::LocalVariableTargetNode) ? expr.name : nil
                                else
                                  nil
                                end
                     rights = (idx.rights rescue []).filter_map { |r| r.is_a?(Prism::LocalVariableTargetNode) ? r.name : nil }
                     [:multi, lefts, rest_sym, rights]
                   when Prism::CallTargetNode
                     [:call, transform(prism_node.index.receiver), prism_node.index.name]
                   when Prism::IndexTargetNode
                     arg_nodes = (prism_node.index.arguments&.arguments || []).map { |a| transform(a) }
                     [:index, transform(prism_node.index.receiver), arg_nodes]
                   else
                     begin; [:local, prism_node.index.name]; rescue; [:local, :_]; end
                   end
          collection = transform(prism_node.collection)
          body = prism_node.statements.nil? ? Ast::NilLiteral::NIL : transform(prism_node.statements)
          Ast::ForLoop.new(target, collection, body)

        when Prism::ImplicitNode
          # {a:} shorthand hash syntax - ImplicitNode wraps the value (local variable)
          transform(prism_node.value)

        when Prism::FlipFlopNode
          # Flip-flop not implemented; evaluates to false
          Ast::FalseLiteral::FALSE

        else
          raise FrozoneException.make(:NotImplementedError, "Unsupported Ruby feature: #{prism_node.class.name.split('::').last.sub('Node', '')}")
        end
      end

      DEFINED_ASSIGNMENT_NODES = [
        Prism::LocalVariableWriteNode, Prism::InstanceVariableWriteNode,
        Prism::ClassVariableWriteNode, Prism::GlobalVariableWriteNode,
        Prism::ConstantWriteNode, Prism::ConstantPathWriteNode,
        Prism::MultiWriteNode,
        Prism::LocalVariableOrWriteNode, Prism::LocalVariableAndWriteNode,
        Prism::LocalVariableOperatorWriteNode,
        Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
        Prism::InstanceVariableOperatorWriteNode,
        Prism::ClassVariableOrWriteNode, Prism::ClassVariableAndWriteNode,
        Prism::ClassVariableOperatorWriteNode,
        Prism::GlobalVariableOrWriteNode, Prism::GlobalVariableAndWriteNode,
        Prism::GlobalVariableOperatorWriteNode,
        Prism::ConstantOrWriteNode, Prism::ConstantAndWriteNode,
        Prism::ConstantOperatorWriteNode,
        Prism::ConstantPathOrWriteNode, Prism::ConstantPathAndWriteNode,
        Prism::ConstantPathOperatorWriteNode,
        Prism::CallOrWriteNode, Prism::CallAndWriteNode, Prism::CallOperatorWriteNode,
        Prism::IndexOrWriteNode, Prism::IndexAndWriteNode, Prism::IndexOperatorWriteNode,
      ].freeze

      DEFINED_EXPRESSION_NODES = [
        Prism::BlockNode, Prism::LambdaNode,
        Prism::AndNode, Prism::OrNode,
        Prism::IfNode, Prism::UnlessNode, Prism::CaseNode, Prism::CaseMatchNode,
        Prism::ForNode, Prism::WhileNode, Prism::UntilNode,
        Prism::BreakNode, Prism::NextNode, Prism::RedoNode, Prism::RetryNode,
        Prism::ReturnNode, Prism::BeginNode,
        Prism::SourceFileNode, Prism::SourceLineNode, Prism::SourceEncodingNode,
        Prism::RegularExpressionNode, Prism::InterpolatedRegularExpressionNode,
        Prism::RangeNode,
      ].freeze

      def transform_defined_value(val)
        case val
        when Prism::SelfNode
          Ast::DefinedExpr.new(:self)
        when Prism::NilNode
          Ast::DefinedExpr.new(:nil)
        when Prism::TrueNode
          Ast::DefinedExpr.new(:true)
        when Prism::FalseNode
          Ast::DefinedExpr.new(:false)
        when Prism::IntegerNode, Prism::FloatNode, Prism::ImaginaryNode, Prism::RationalNode,
             Prism::StringNode, Prism::InterpolatedStringNode, Prism::SymbolNode,
             Prism::InterpolatedSymbolNode, Prism::HashNode, Prism::LambdaNode
          Ast::DefinedExpr.new(:literal)
        when Prism::ArrayNode
          element_checks = val.elements.map { |e|
            e.is_a?(Prism::SplatNode) ? Ast::DefinedExpr.new(:expression) : transform_defined_value(e)
          }
          Ast::DefinedExpr.new(:array_literal, element_checks)
        when Prism::ConstantReadNode
          Ast::DefinedExpr.new(:constant, Ast::ConstantRead.new(val.name))
        when Prism::ConstantPathNode
          Ast::DefinedExpr.new(:constant, transform(val))
        when Prism::LocalVariableReadNode
          Ast::DefinedExpr.new(:local_var)
        when Prism::InstanceVariableReadNode
          Ast::DefinedExpr.new(:ivar, val.name)
        when Prism::ClassVariableReadNode
          Ast::DefinedExpr.new(:cvar, val.name)
        when Prism::GlobalVariableReadNode
          Ast::DefinedExpr.new(:gvar, val.name)
        when Prism::BackReferenceReadNode
          Ast::DefinedExpr.new(:back_ref, val.name)
        when Prism::NumberedReferenceReadNode
          Ast::DefinedExpr.new(:num_ref, val.number)
        when Prism::CallNode
          receiver_node = val.receiver.nil? ? nil : transform(val.receiver)
          receiver_defined = val.receiver.nil? ? nil : transform_defined_value(val.receiver)
          Ast::DefinedExpr.new(:method, [receiver_node, val.name, receiver_defined])
        when Prism::YieldNode
          Ast::DefinedExpr.new(:yield)
        when Prism::SuperNode, Prism::ForwardingSuperNode
          Ast::DefinedExpr.new(:super)
        when *DEFINED_ASSIGNMENT_NODES
          Ast::DefinedExpr.new(:assignment)
        when Prism::ParenthesesNode
          inner = val.body&.body&.first
          inner ? transform_defined_value(inner) : Ast::DefinedExpr.new(:expression)
        when *DEFINED_EXPRESSION_NODES
          Ast::DefinedExpr.new(:expression)
        else
          Ast::NilLiteral::NIL
        end
      end
    end
  end
end

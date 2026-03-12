require_relative 'node'
require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef < Node
      def initialize(name, receiver_node, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param, locals, body)
        @name = check_type("name", name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)

        @required_params = check_array_type("required_params", required_params, Symbol)
        @optional_params = check_array_of_pairs_of_types("optional_params", optional_params, Symbol, Ast::Node)
        @rest_param = check_nil_or_type("rest_param", rest_param, Symbol)
        @post_params = check_array_type("post_params", post_params, Symbol)

        @required_kw_params = check_array_type("required_kw_params", required_kw_params, Symbol)
        @optional_kw_params = check_array_of_pairs_of_types("optional_kw_params", optional_kw_params, Symbol, Ast::Node)
        @kw_rest_param = check_nil_or_type("kw_rest_param", kw_rest_param, Symbol)

        @block_param = check_nil_or_type("block_param", block_param, Symbol)

        @locals = check_array_type("locals", locals, Symbol)
        @body = check_type("body", body, Node)
      end

      def evaluate(context)
        # Determine the defining scope: def_scope from frame (set by instance_eval or Method#invoke)
        # takes priority over the lexical context.scopes.last.
        frame = context.frame
        def_scope = frame.def_scope
        # Method's lexical scopes: include def_scope as last if it overrides the current scope
        method_scopes = if def_scope && !def_scope.equal?(context.scopes.last)
          context.scopes + [def_scope]
        else
          context.scopes
        end
        method = Vm::Method.new(
          method_scopes,
          @name,
          @required_params,
          @optional_params,
          @rest_param,
          @post_params,
          @required_kw_params,
          @optional_kw_params,
          @kw_rest_param,
          @block_param,
          @locals,
          @body
        )
        if @receiver_node.nil?
          scope = def_scope || context.scopes.last
          # Visibility: def resets to public inside a real method body, but closures
          # (blocks/lambdas) at class-body level look outside for the current_visibility.
          inside_method = frame.method_frame&.current_method != nil
          private_by_default = %i[initialize initialize_copy initialize_dup initialize_clone respond_to_missing?].include?(@name)
          vis = private_by_default ? :private : (inside_method ? :public : scope.current_visibility)
          if vis == :module_function
            # module_function: private instance method + public singleton method
            method.visibility = :private
            scope.set_method(@name, method)
            singleton_method = Vm::Method.new(method.scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body)
            singleton_method.visibility = :public
            scope.singleton_class.set_method(@name, singleton_method)
          else
            method.visibility = vis
            scope.set_method(@name, method)
          end
        else
          @receiver_node.evaluate(context).define_singleton_method(@name, method)
        end
        Vm::SymbolObject.from(@name)
      end
    end
  end
end

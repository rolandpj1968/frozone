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
        method = Vm::Method.new(
          context.frame.scopes,
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
          scope = context.scopes.last
          # Inside a method or block, def is always public.
          # Only def directly in a class/module body or top-level respects current_visibility.
          frame = context.frame
          inside_method_or_block = !frame.method_frame.nil? || !frame.parent_frame.nil?
          method.visibility = @name == :initialize ? :private : (inside_method_or_block ? :public : scope.current_visibility)
          scope.set_method(@name, method)
        else
          @receiver_node.evaluate(context).define_singleton_method(@name, method)
        end
        Vm::SymbolObject.from(@name)
      end
    end
  end
end

require_relative 'node'
require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef < Node
      def initialize(name, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, locals, body)
        @name = check_type("name", name, Vm::SymbolObject)

        @required_params = check_array_type("required_params", required_params, Vm::SymbolObject)
        @optional_params = check_array_of_pairs_of_types("optional_params", optional_params, Vm::SymbolObject, Ast::Node)
        @rest_param = check_nil_or_type("rest_param", rest_param, Vm::SymbolObject)
        @post_params = check_array_type("post_params", post_params, Vm::SymbolObject)
        raise "post_params but no rest_param" if rest_param.nil? && post_params.any?

        @required_kw_params = check_array_type("required_kw_params", required_kw_params, Vm::SymbolObject)
        @optional_kw_params = check_array_of_pairs_of_types("optional_kw_params", optional_kw_params, Vm::SymbolObject, Ast::Node)
        @kw_rest_param = check_nil_or_type("kw_rest_param", kw_rest_param, Vm::SymbolObject)

        @locals = check_array_type("locals", locals, Vm::SymbolObject)
        @body = check_type("body", body, Node)
      end

      def evaluate(context)
        context.scopes.last.set_method(
          @name,
          Vm::Method.new(
            context.scopes,
            @name,
            @required_params,
            @optional_params,
            @rest_param,
            @post_params,
            @required_kw_params,
            @optional_kw_params,
            @kw_rest_param,
            @locals,
            @body
          )
        )
        @name
      end
    end
  end
end

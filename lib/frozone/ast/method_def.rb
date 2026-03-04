require_relative "../utils"
require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef
      include Utils

      attr_reader :name, :required_params, :optional_params, :rest_param, :post_params, :locals, :ast

      def initialize(name, required_params, optional_params, rest_param, post_params, locals, ast)
        @name = check_type("name", name, Symbol)
        @required_params = check_array_type("required_params", required_params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)

        @ast = ast
      end

      def evaluate(context)
        context.scopes.last.set_method(
          name,
          Vm::Method.new(
            context.scopes,
            name,
            required_params,
            optional_params,
            rest_param,
            post_params,
            locals,
            ast
          )
        )
        Vm::SymbolObject.from(@name)
      end
    end
  end
end

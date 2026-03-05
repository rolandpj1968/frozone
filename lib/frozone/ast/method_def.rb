require_relative 'node'
require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef < Node
      def initialize(name, required_params, optional_params, rest_param, post_params, locals, body)
        @name = check_type("name", name, Symbol)
        @required_params = check_array_type("required_params", required_params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)

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
            @locals,
            @body
          )
        )
        Vm::SymbolObject.from(@name)
      end
    end
  end
end

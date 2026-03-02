require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef
      def initialize(name, params, locals, ast)
        raise "class name must be a Symbol" unless name.class.equal?(Symbol)
        @name = name

        # TODO - must be an array of Symbols
        raise "params must be an array of Symbols" unless params.class.equal?(Array)
        @params = params

        # TODO - must be an array of Symbols
        raise "locals must be an array of Symbols" unless locals.class.equal?(Array)
        @locals = locals

        @ast = ast
      end

      def evaluate(context)
        context.scopes.last.set_method(
          @name,
          Vm::Method.new(
            context.scopes,
            @name,
            @params,
            @locals,
            @ast
          )
        )
        # Ruby seems to generate the method name
        #   ruby -e 'a = def m = 3; puts a; puts a.class' -> m, Symbol
        Vm::SymbolObject.from(@name)
      end
    end
  end
end

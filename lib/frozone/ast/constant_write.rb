require_relative '../vm/module_object'

module Frozone
  module Ast
    class ConstantWrite
      def initialize(name, ast)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @name = name
        @ast = ast
      end

      def to_s = "con=(#{@name}, #{@ast})"

      def evaluate(context) = context.scopes.last.set_constant(@name, @ast.evaluate(context))
    end
  end
end

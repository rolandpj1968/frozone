require_relative '../vm/module_object'

module Frozone
  module Ast
    class ConstantWrite
      def initialize(name, ast)
        raise "name must be a Symbol" unless name.class.equal?(Symbol)

        @name = name
        @ast = ast
      end

      def to_s = "con=(#{@name}, #{@ast})"

      def execute(context) = context.scopes.last.set_constant(@name, @ast.execute(context))
    end
  end
end

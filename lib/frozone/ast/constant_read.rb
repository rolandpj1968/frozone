require_relative '../vm/module_object'

module Frozone
  module Ast
    # TODO - dedup with hash
    class ConstantRead
      def initialize(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @name = name
      end

      def to_s = "con(#{@name})"

      def evaluate(context) = Vm::ModuleObject.lookup_constant(@name, context.scopes)
    end
  end
end

require_relative '../vm/module_object'

module Frozone
  module Ast
    # TODO - dedup with hash
    class ConstantRead
      def initialize(name)
        raise "name must be a Symbol" unless name.class.equal?(Symbol)

        @name = name
      end

      def to_s = "con(#{@name})"

      def execute(context) = Vm::ModuleObject.lookup_constant(@name, context.scopes)
    end
  end
end

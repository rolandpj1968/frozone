require_relative 'node'
require_relative '../vm/integer_object'

module Frozone
  module Ast
    class IntegerLiteral < Node
      def initialize(value)
        @value = check_type("value", value, Vm::IntegerObject)
      end

      # Only via IntegerLiteral.from
      private_class_method :new

      def to_s = "int(#{@value})"

      def evaluate(_) = @value

      # TODO - thread-safety
      IntegerLiterals = {}

      def self.from(value)
        IntegerLiterals[value] ||= new(Vm::IntegerObject.new(value))
      end
    end
  end
end

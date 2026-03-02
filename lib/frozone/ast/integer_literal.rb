require_relative '../vm/integer_object'

module Frozone
  module Ast
    class IntegerLiteral
      def initialize(value)
        raise "IntegerLiteral value must be an IntegerObject" unless value.class.equal?(::Frozone::Vm::IntegerObject)
        @value = value
      end

      # Only via IntegerLiteral.from
      private_class_method :new

      def to_s = "int(#{@value})"

      def evaluate(_) = @value

      # TODO - thread-safety
      IntegerLiterals = {}

      def self.from(value)
        raise "IntegerLiteral value must be an Integer not #{value.class}" unless value.class.equal?(Integer)

        IntegerLiterals[value] ||= new(::Frozone::Vm::IntegerObject.new(value))
      end
    end
  end
end

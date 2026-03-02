require_relative '../vm/false_object'

module Frozone
  module Ast
    class FalseLiteral
      FALSE = FalseLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "false"

      def execute(_) = Vm::FalseObject::FALSE
    end
  end
end

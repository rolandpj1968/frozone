require_relative 'node'
require_relative '../vm/false_object'

module Frozone
  module Ast
    class FalseLiteral < Node
      FALSE = FalseLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "false"

      def evaluate(_) = Vm::FalseObject::FALSE
    end
  end
end

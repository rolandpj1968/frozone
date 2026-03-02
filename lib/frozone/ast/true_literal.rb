require_relative '../vm/true_object'

module Frozone
  module Ast
    class TrueLiteral
      TRUE = TrueLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "true"

      def execute(_) = Vm::TrueObject::TRUE
    end
  end
end

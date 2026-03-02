require_relative '../vm/nil_object'

module Frozone
  module Ast
    class NilLiteral
      NIL = NilLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "nil"

      def execute(_) = Vm::NilObject::NIL
    end
  end
end

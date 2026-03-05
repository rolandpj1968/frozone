require_relative 'node'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class NilLiteral < Node
      NIL = NilLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "nil"

      def evaluate(_) = Vm::NilObject::NIL
    end
  end
end

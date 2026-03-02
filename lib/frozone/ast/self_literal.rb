module Frozone
  module Ast
    class SelfLiteral
      SELF = SelfLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "self"

      def evaluate(context) = context.frame.the_self
    end
  end
end

module Frozone
  module Ast
    class SelfLiteral
      SELF = SelfLiteral.new

      # Global singleton
      private_class_method :new

      def to_s = "self"

      def execute(context) = context.frame.the_self
    end
  end
end

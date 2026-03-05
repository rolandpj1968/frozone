require_relative 'node'

module Frozone
  module Ast
    class FloatLiteral < Node
      attr_reader :value

      def initialize(value)
        @value = check_type("value", value, Float)
      end

      def to_s = "float(#{@value})"

      def self.from(value)
        # TODO dedup; Vm::FloatObject
        new(value)
      end
    end
  end
end

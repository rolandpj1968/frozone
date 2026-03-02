require_relative '../vm/string_object'

module Frozone
  module Ast
    class StringLiteral
      attr_reader :value

      def initialize(value)
        @value = value
      end

      # Only via StringLiteral.from to dedup
      private_class_method :new

      def to_s = "str(#{value})"

      def execute(_) = @value.dup

      # TODO - share with symbols
      # TODO - thread-safety
      StringLiterals = {}

      def self.from(value)
        raise "StringLiteral value must be an String not #{value.class}" unless value.is_a?(String)

        # TODO - handle locale encoding
        StringLiterals[value] ||= new(Vm::StringObject.new(value))
      end
    end
  end
end

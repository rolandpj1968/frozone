require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class SymbolLiteral
      def initialize(value)
        raise "value must be a Vm::SymbolObject" unless value.is_a?(Vm::SymbolObject)
        @value = value
      end

      # Only via SymbolLiteral.from to dedup
      private_class_method :new

      def to_s = "sym(#{@value})"

      def evaluate(_) = @value

      # TODO - thread-safety
      SymbolLiterals = {}

      def self.from(value)
        raise "SymbolLiteral value must be an String not #{value.class}" unless value.is_a?(String)

        # TODO - handle locale encoding?
        symbol = value.to_sym
        SymbolLiterals[symbol] ||= new(Vm::SymbolObject.from(symbol))
      end
    end
  end
end

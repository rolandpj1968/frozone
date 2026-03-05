require_relative 'node'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class SymbolLiteral < Node
      def initialize(value)
        @value = value
      end

      # Only via SymbolLiteral.from to dedup
      private_class_method :new

      def to_s = "sym(#{@value})"

      def evaluate(_) = @value

      # TODO - thread-safety
      SymbolLiterals = {}

      def self.from(value)
        # TODO - handle locale encoding?
        symbol = value.to_sym
        SymbolLiterals[symbol] ||= new(Vm::SymbolObject.from(symbol))
      end
    end
  end
end

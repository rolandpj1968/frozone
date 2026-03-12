require_relative 'node'
require_relative '../vm/float_object'

module Frozone
  module Ast
    class FloatLiteral < Node
      def initialize(value)
        @value = value
      end

      def to_s = "float(#{@value})"

      def self.from(value) = new(value)

      def evaluate(_context) = Vm::FloatObject.new(@value)
    end
  end
end

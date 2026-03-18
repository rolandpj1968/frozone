require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class SymbolObject < ObjectObject
      attr_reader :raw

      def initialize(value)
        raise "SymbolObject must have an Symbol value" unless value.is_a?(Symbol)

        super(Core::SYMBOL_CLASS)

        @raw = value
        @frozen_object = true
      end

      # Only via SymbolObject.from since Symbol's are globally unique in ruby
      private_class_method :new

      def to_s = ":#{@raw}"
      def inspect_for_error = ":#{@raw}"

      # TODO - share with unique strings???
      # TODO - thread-safety
      SymbolObjects = {}

      def self.from(value)
        raise "SymbolObject must have an Symbol value" unless value.is_a?(Symbol)

        SymbolObjects[value] ||= new(value)
      end
    end
  end
end

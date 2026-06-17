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

      # TODO - share with unique strings???
      # TODO - thread-safety
      SymbolObjects = {}

      def self.from(value)
        raise "SymbolObject must have an Symbol value" unless value.is_a?(Symbol)

        SymbolObjects[value] ||= new(value)
      end

      # Marshal support: serialize as the raw symbol name so the intern table
      # is consulted on load, restoring the correct singleton instance.
      def _dump(_) = @raw.to_s

      def self._load(data) = from(data.to_sym)
    end
  end
end

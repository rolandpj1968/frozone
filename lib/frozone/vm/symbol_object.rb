require_relative 'object_object'

module Frozone
  module Vm
    class SymbolObject < ObjectObject
      def initialize(value)
        raise "SymbolObject must have a Symbol value" unless value.is_a?(Symbol)

        # Don't call super with Core::SYMBOL_CLASS here because SYMBOL_CLASS may not
        # exist yet when the first SymbolObjects are created during core bootstrap.
        # We set the instance variables directly and patch them via bootstrap! later.
        @value = value
        @class_object = nil
        @eigenclass = nil
        @instance_variables = {}
      end

      def raw = @value

      # Only via SymbolObject.from since Symbol's are globally unique in ruby
      private_class_method :new

      def to_s = ":#{@value}"

      # TODO - share with unique strings???
      # TODO - thread-safety
      SymbolObjects = {}

      def self.from(value)
        raise "SymbolObject must have a Symbol value" unless value.is_a?(Symbol)

        SymbolObjects[value] ||= new(value)
      end

      # Called from core.rb after SYMBOL_CLASS is defined to patch all existing instances.
      def self.bootstrap!(symbol_class)
        SymbolObjects.each_value do |sym_obj|
          sym_obj.instance_variable_set(:@class_object, symbol_class)
          sym_obj.instance_variable_set(:@eigenclass, symbol_class)
        end
      end
    end
  end
end


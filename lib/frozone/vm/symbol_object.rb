require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class SymbolObject < ObjectObject
      def initialize(value)
        raise "SymbolObject must have an Symbol value" unless value.class.equal?(Symbol)

        super(Core::SYMBOL_CLASS)

        @value = value
      end

      # Only via SymbolObject.from since Symbol's are globally unique in ruby
      private_class_method :new

      def to_s = ":#{@value}"

      # TODO - share with unique strings???
      # TODO - thread-safety
      SymbolObjects = {}

      def self.from(value)
        raise "SymbolObject must have an Symbol value" unless value.class.equal?(Symbol)

        SymbolObjects[value] ||= new(value)
      end
    end
  end
end


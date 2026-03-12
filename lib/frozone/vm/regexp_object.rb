require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class RegexpObject < ObjectObject
      attr_reader :raw

      def initialize(source, flags = 0)
        super(Core::OBJECT_CLASS.get_constant(:Regexp))
        @raw = Regexp.new(source, flags)
      end

      def truthy? = true
    end
  end
end

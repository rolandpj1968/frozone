require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class RegexpObject < ObjectObject
      def initialize(source, flags = 0)
        super(Core::OBJECT_CLASS.get_constant(:Regexp))
        @regexp = Regexp.new(source, flags)
      end

      def raw = @regexp
      def truthy? = true
    end
  end
end

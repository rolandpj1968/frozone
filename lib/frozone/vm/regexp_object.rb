require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class RegexpObject < ObjectObject
      attr_reader :raw

      def initialize(source, flags = 0, encoding_name = nil)
        super(Core::OBJECT_CLASS.get_constant(:Regexp))
        if encoding_name
          src = source.dup.force_encoding(encoding_name)
          @raw = Regexp.new(src, flags)
        else
          @raw = Regexp.new(source, flags)
        end
      end

      def truthy? = true
    end
  end
end

require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class RegexpObject < ObjectObject
      attr_reader :raw
      attr_accessor :newly_created_for_subclass

      def initialize(source, flags = 0, encoding_name = nil, klass: nil, timeout: nil)
        super(klass || Core::OBJECT_CLASS.get_constant(:Regexp))
        if encoding_name
          src = source.dup.force_encoding(encoding_name)
          @raw = timeout ? Regexp.new(src, flags, timeout: timeout) : Regexp.new(src, flags)
        else
          @raw = timeout ? Regexp.new(source, flags, timeout: timeout) : Regexp.new(source, flags)
        end
      end

      def truthy? = true
    end
  end
end

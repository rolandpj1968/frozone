require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    # A Frozone VM object wrapping a native MRI Encoding::Converter.
    class EncodingConverterObject < ObjectObject
      attr_reader :mri_converter

      def initialize(mri_converter, converter_class = nil)
        klass = converter_class ||
                Core::OBJECT_CLASS.get_constant(:Encoding)&.get_constant(:Converter) ||
                Core::OBJECT_CLASS
        super(klass)
        @mri_converter = mri_converter
      end

      def truthy? = true

      def patch_class_object(klass)
        @class_object = klass
      end
    end
  end
end

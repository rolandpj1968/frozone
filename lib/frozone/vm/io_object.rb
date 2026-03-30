module Frozone
  module Vm
    # A Frozone VM object wrapping a native Ruby IO stream ($stdout, $stderr, $stdin).
    class IOObject < ObjectObject
      # explicit_encoding: true if encoding was specified in the mode string (e.g., 'r:utf-8')
      def initialize(native_io, io_class = nil, explicit_encoding: false)
        super(io_class || Core::OBJECT_CLASS)
        @native_io = native_io
        @explicit_encoding = explicit_encoding
      end

      def native_io = @native_io
      def native_io=(io); @native_io = io; end
      def explicit_encoding? = @explicit_encoding
      def buffered_write? = @buffered_write || false
      def buffered_write=(v); @buffered_write = v; end

      def patch_class_object(io_class) = @class_object = io_class
    end
  end
end

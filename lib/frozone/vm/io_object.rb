module Frozone
  module Vm
    # A Frozone VM object wrapping a native Ruby IO stream ($stdout, $stderr, $stdin).
    class IOObject < ObjectObject
      def initialize(native_io, io_class = nil)
        super(io_class || Core::OBJECT_CLASS)
        @native_io = native_io
      end

      def native_io = @native_io

      def patch_class_object(io_class)
        @class_object = io_class
      end
    end
  end
end

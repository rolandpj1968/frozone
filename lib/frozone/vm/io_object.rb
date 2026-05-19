module Frozone
  module Vm
    # A Frozone VM object wrapping a native Ruby IO stream ($stdout, $stderr, $stdin).
    class IOObject < ObjectObject
      # explicit_encoding: true if encoding was specified in the mode string (e.g., 'r:utf-8')
      def initialize(native_io, io_class = nil, explicit_encoding: false, stream_tag: nil)
        super(io_class || Core::OBJECT_CLASS)
        @native_io = native_io
        @explicit_encoding = explicit_encoding
        # :stdout / :stderr / :stdin — set at vm.rb bootstrap so
        # compiled box-first can route writes when @native_io is nil
        # (the GLOBALS["$stdout"] chicken-egg: the global isn't
        # populated yet at construction, so we can't recover stream
        # identity from there later).
        @stream_tag = stream_tag
      end

      def native_io = @native_io
      def native_io=(io); @native_io = io; end
      def stream_tag = @stream_tag
      def stream_tag=(t); @stream_tag = t; end
      def explicit_encoding? = @explicit_encoding
      def explicit_encoding=(v); @explicit_encoding = v; end
      def buffered_write? = @buffered_write || false
      def buffered_write=(v); @buffered_write = v; end

      def patch_class_object(io_class) = @class_object = io_class
    end
  end
end

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

      # Bootstrap constructor for $stdout/$stderr/$stdin — bypasses
      # `IOObject.new`, which under box-first fusion would dispatch
      # `IO#initialize(fd, ...)` and reject the (nil, io_class, kwargs)
      # shape with TypeError. Allocates a bare instance and sets the
      # state the io intrinsics need (class_object + @native_io +
      # @stream_tag). Used only at vm.rb startup.
      def self.bootstrap_stream(native, tag, io_class = nil)
        obj = allocate
        obj.send(:__bootstrap_init__, native, tag, io_class)
        obj
      end

      private

      def __bootstrap_init__(native, tag, io_class)
        @class_object = io_class || Core::OBJECT_CLASS
        @native_io = native
        @stream_tag = tag
        @explicit_encoding = false
        @frozen_object = false
        @instance_variables_hash = {}
        @eigenclass = nil
      end

      public

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

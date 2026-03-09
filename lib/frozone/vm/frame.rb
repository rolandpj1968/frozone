module Frozone
  module Vm
    class Frame
      def initialize(the_self, locals, scopes, parent_frame = nil)
        # TODO - map locals to slot number
        @locals = {}
        locals.each do |local|
          @locals[local] = NilObject::NIL
        end
        @the_self = the_self
        @scopes = scopes
        @parent_frame = parent_frame
        @block = nil
      end

      def the_self = @the_self
      def scopes = @scopes
      def block = @block
      def block=(b); @block = b; end
      attr_accessor :method_frame

      def get_local(local) = @locals[local]

      def set_local(local, value)
        @locals[local] = value
      end

      def frame_at_depth(depth)
        return self if depth == 0
        raise "no enclosing frame at depth #{depth}" if @parent_frame.nil?
        @parent_frame.frame_at_depth(depth - 1)
      end
    end
  end
end

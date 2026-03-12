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
        @scopes = scopes.frozen? ? scopes : scopes.dup.freeze
        @parent_frame = parent_frame
        @block = nil
      end

      def the_self = @the_self
      def scopes = @scopes
      def parent_frame = @parent_frame
      def block = @block
      def block=(b); @block = b; end
      attr_accessor :method_frame
      attr_accessor :current_method, :method_args, :method_kwargs
      attr_accessor :def_scope  # singleton class scope set by instance_eval or method's defining scope

      def get_local(local) = @locals[local]

      def set_local(local, value)
        @locals[local] = value
      end

      def frame_at_depth(depth, original_depth = depth)
        return self if depth == 0
        raise "no enclosing frame at depth #{original_depth}" if @parent_frame.nil?
        @parent_frame.frame_at_depth(depth - 1, original_depth)
      end
    end
  end
end

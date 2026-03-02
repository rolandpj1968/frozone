module Frozone
  module Vm
    class Context
      def initialize
        # execution stack - one frame per call
        @frames = []
        # lexical scope stack - one per class/module nesting
        #   - mostly interesting when parsing
        @scopes = []
      end

      def push_frame(frame)
        raise "frame must be a Frame" unless frame.class.equal?(Frame)

        @frames.push(frame)
      end

      def pop_frame
        @frames.pop
      end

      def frame = @frames.last

      def push_scope(scope)
        unless scope.class.equal?(ClassObject) || scope.class.equal?(ModuleObject)
          raise "scope must be a ClassObject or ModuleObject"
        end

        @scopes.push(scope)
      end

      def pop_scope
        @scopes.pop
      end

      def scopes = @scopes
    end
  end
end

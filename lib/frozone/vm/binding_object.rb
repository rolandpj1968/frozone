module Frozone
  module Vm
    # Lightweight VM binding object — wraps a captured frame for use with eval/local_variables.
    class BindingObject < ObjectObject
      NUMBERED_PARAM_RE = /\A_[1-9]\z/.freeze

      attr_reader :captured_frame

      def initialize(frame)
        super(Core.binding_class || Core::OBJECT_CLASS)
        @captured_frame = frame
      end

      # Returns names of user-visible local variables (excludes numbered params _1-_9 and :it).
      def local_variable_names
        @captured_frame.local_names.reject do |n|
          n == :it || NUMBERED_PARAM_RE.match?(n.to_s)
        end
      end
    end
  end
end

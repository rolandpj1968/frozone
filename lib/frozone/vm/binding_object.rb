module Frozone
  module Vm
    # Lightweight VM binding object — wraps a captured frame for use with eval/local_variables.
    class BindingObject < ObjectObject
      NUMBERED_PARAM_RE = /\A_[1-9]\z/.freeze

      attr_reader :captured_frame, :binding_call_site
      attr_accessor :binding_local_names

      def initialize(frame, call_site = nil)
        super(Core.binding_class || Core::OBJECT_CLASS)
        @captured_frame = frame
        @binding_call_site = call_site
        # Compute the authoritative name set for this binding from the closure chain.
        # Uses frame.own_locals when set (eval frames) so eval-native vars appear first.
        @binding_local_names = collect_local_names(frame)
      end

      private

      def collect_local_names(frame)
        names = []
        f = frame
        while f
          (f.own_locals || f.local_names).each { |n| names << n unless names.include?(n) }
          # Stop at real method frame boundaries (method_frame == self AND current_method is a Method).
          # Lambdas also have method_frame == self but ARE closures — don't stop there.
          break if f.method_frame.equal?(f) && f.current_method.is_a?(Method)
          f = f.parent_frame
        end
        names
      end
    end
  end
end

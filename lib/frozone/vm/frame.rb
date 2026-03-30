module Frozone
  module Vm
    class Frame
      attr_reader :the_self, :scopes
      attr_accessor :parent_frame, :own_locals
      attr_accessor :block
      attr_accessor :method_frame
      attr_accessor :current_method, :method_args, :method_kwargs
      attr_accessor :def_scope              # singleton class scope set by instance_eval or method's defining scope
      attr_accessor :cvar_scope             # lexical scope for class variable lookup (preserved through instance_eval)
      attr_accessor :instance_eval_const_scope  # receiver's singleton class for instance_eval string constant lookup
      attr_accessor :incoming_call_site    # "file:line" where this frame was invoked from
      attr_accessor :thread_boundary       # true when block runs as a Thread body — break → LocalJumpError
      attr_accessor :active_refinements    # list of refinement modules activated by `using` in this frame
      attr_accessor :current_refining_module  # set during module_refine_eval so method_def can record it
      attr_accessor :callee_name           # name used at call site (may differ from method name when aliased)

      def alive? = @alive != false
      def local_names = @locals.keys
      def get_local(local) = @locals[local]

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

      def kill! = @alive = false

      def set_local(local, value) = @locals[local] = value

      def frame_at_depth(depth, original_depth = depth)
        return self if depth == 0
        raise "no enclosing frame at depth #{original_depth}" if @parent_frame.nil?
        @parent_frame.frame_at_depth(depth - 1, original_depth)
      end
    end
  end
end

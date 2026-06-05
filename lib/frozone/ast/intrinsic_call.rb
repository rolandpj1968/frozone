require_relative 'node'
require_relative '../vm/frozone_exception'
require_relative '../vm/intrinsics'

module Frozone
  module Ast
    # `Intrinsics.foo(...)` is recognised by both parsers and lowered to an
    # IntrinsicCall (rather than a regular MethodCall). The original design
    # cached a resolved Method object at AST-construction time as a perf
    # optimisation — name is a literal Symbol in source, known at parse
    # time, never variable. Under MRI that worked great: `Module#method`
    # returns a real bound Method, `.call` invokes it directly, no per-call
    # dispatch.
    #
    # Under box-first compiled, `Module#method` returns a Proc-shim that
    # redispatches via send — so we lose the optimisation, AND the shim
    # depends on the underlying method existing in the methods table
    # (vulnerable to the call-surface pruner).
    #
    # The fix: skip the Method roundtrip and just `send` directly. Under
    # MRI this is essentially as fast (Ruby's inline method cache makes
    # send ~free for repeated calls). Under box-first, send is an O(1)
    # method-id vtable dispatch — the optimisation lands "for free" via
    # the existing send machinery.
    class IntrinsicCall < Node
      attr_reader :name, :param_nodes

      def initialize(name, param_nodes)
        # No name validation here: the AOT box-first init order constructs
        # IntrinsicCall nodes during snapshot deserialization BEFORE the
        # Vm::Intrinsics module is fully populated, so an early respond_to?
        # check raises NameError on real, soon-to-be-defined intrinsics.
        # Calls to unknown intrinsics surface at evaluate time via the send
        # on line 41 (NoMethodError on Vm::Intrinsics).
        @name = name
        @param_nodes = param_nodes
      end

      def children = @param_nodes

      def to_s = "intrinsic[#{@name}](#{@param_nodes.map(&:to_s).join(', ')})"

      def evaluate(context)
        args = @param_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        Vm::Intrinsics.send(@name, context, *args)
      end

      def marshal_dump = [@name, @param_nodes]

      def marshal_load(data)
        @name, @param_nodes = data
      end
    end
  end
end

module Frozone
  module Ast
    # TODO - dedup with hash
    # TODO - specialize 0 depth
    class LocalVariableRead
      def initialize(local, depth)
        raise "local must be a Symbol" unless local.is_a?(Symbol)
        raise "depth must be an Integer" unless depth.is_a?(Integer)

        @local = local
        @depth = depth
      end

      def to_s = "local(#{@local})"

      # TODO depth
      def evaluate(context) = context.frame.get_local(@local)
    end
  end
end

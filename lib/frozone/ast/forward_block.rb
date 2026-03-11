require_relative 'node'

module Frozone
  module Ast
    # Represents `&` with no expression - forwards the current method's block.
    class ForwardBlock < Node
      INSTANCE = new

      def evaluate(context)
        context.frame.block  # already a ProcObject or nil
      end
    end
  end
end

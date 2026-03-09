require_relative 'node'

module Frozone
  module Ast
    # Raised to restart the current block/loop body iteration; caught by
    # BlockObject#invoke or While/Until#evaluate.
    class RedoException < StandardError; end

    class Redo < Node
      def evaluate(context) = raise RedoException.new
    end
  end
end

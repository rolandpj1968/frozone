require_relative 'node'
require_relative 'block'

module Frozone
  module Ast
    # for x in collection; body; end
    # Desugared to: collection.each { |x| body }
    # Note: variable scoping differs from real for (vars persist), but good enough for most specs
    class ForLoop < Node
      def initialize(var_names, all_locals, collection_node, body_node)
        @var_names = var_names        # Array of Symbol
        @all_locals = all_locals      # Array of Symbol (all local vars in scope)
        @collection_node = check_type("collection_node", collection_node, Node)
        @body_node = check_type("body_node", body_node, Node)
      end

      def evaluate(context)
        collection = @collection_node.evaluate(context)
        block_ast = Block.new(@var_names, @all_locals, @body_node)
        block_obj = block_ast.evaluate(context)
        begin
          collection.dispatch(context, :each, [], {}, block_obj)
        rescue Ast::BreakException => e
          return e.value
        end
        collection
      end
    end
  end
end

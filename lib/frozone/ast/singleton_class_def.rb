require_relative 'node'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class SingletonClassDef < Node
      def initialize(expression_node, locals, body)
        @expression_node = expression_node
        @locals = locals
        @body = body
      end

      def evaluate(context)
        obj = @expression_node.evaluate(context)
        sc = obj.singleton_class

        context.scopes << sc
        prev_visibility = sc.current_visibility
        sc.current_visibility = :public
        new_frame = Vm::Frame.new(sc, @locals, context.scopes)
        context.push_frame(new_frame)

        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
          context.scopes.pop
          sc.current_visibility = prev_visibility
        end
      end
    end
  end
end

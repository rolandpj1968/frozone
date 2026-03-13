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
        if obj.is_a?(Vm::IntegerObject) || obj.is_a?(Vm::SymbolObject) || obj.is_a?(Vm::FloatObject)
          raise Vm::FrozoneException.make(:TypeError, "can't define singleton for #{obj.class_object.name}")
        end
        # true/false/nil are singleton instances — their "singleton class" is their actual class
        sc = if obj.is_a?(Vm::TrueObject) || obj.is_a?(Vm::FalseObject) || obj.is_a?(Vm::NilObject)
          obj.class_object
        else
          obj.singleton_class
        end

        context.scopes << sc
        prev_visibility = sc.current_visibility
        sc.current_visibility = :public
        new_frame = Vm::Frame.new(sc, @locals, context.scopes, context.frame)
        new_frame.method_frame = context.frame.method_frame
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

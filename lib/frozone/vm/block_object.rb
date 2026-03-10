module Frozone
  module Vm
    class BlockObject
      def initialize(params, locals, body, enclosing_frame)
        @params = params            # Array of Symbol - required param names
        @locals = locals            # Array of Symbol - all locals in block scope
        @body = body                # Ast::Node
        @enclosing_frame = enclosing_frame
      end

      def invoke(context, args, receiver: nil)
        new_frame = Frame.new(
          receiver || @enclosing_frame.the_self,
          @locals,
          @enclosing_frame.scopes,
          @enclosing_frame
        )
        # Block parameter matching is lenient: missing args become nil, extras are ignored.
        @params.each_with_index { |param, i| new_frame.set_local(param, args.fetch(i, NilObject::NIL)) }
        # Propagate enclosing method's block so `yield` inside a block calls the outer block.
        new_frame.block = @enclosing_frame.block
        # `return` inside a block exits the enclosing method, not the method that invoked yield.
        new_frame.method_frame = @enclosing_frame.method_frame

        context.push_frame(new_frame)
        begin
          loop do
            begin
              return @body.evaluate(context)
            rescue Ast::RedoException
              # redo: re-run body with same args
            end
          end
        rescue Ast::NextException => e
          e.value
        rescue Ast::BreakException => e
          e.from_block = true
          raise
        ensure
          context.pop_frame
        end
      end
    end
  end
end

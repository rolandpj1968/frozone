module Frozone
  module Ast
    class MethodCall
      def initialize(name, receiver_node, arg_nodes)
        raise "name must be a Symbol" unless name.class.equal?(Symbol)
        @name = name
        @receiver_node = receiver_node # nil if no explicit receiver
        @arg_nodes = arg_nodes
      end

      def to_s
        "call(#{@name}, #{@receiver_node || '_'}, #{@arg_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        #puts "          RPJ = MethodCall#evaluate method :#{@name} receiver #{@receiver_node}"
        receiver =
          if @receiver_node.nil?
            context.frame.the_self
          else
            @receiver_node.evaluate(context)
          end
      
        args = @arg_nodes.map { |arg_node| arg_node.evaluate(context) }

        method = receiver.lookup_method(@name)
        #puts "          RPJ = MethodCall#evaluate method :#{@name} receiver #{receiver.class}"
        #puts "          RPJ =    method found is #{method}"

        # TODO - this is a runtime exception, not an assert
        raise "method :#{@name} not found - not yet doing missing_method" if method.nil?

        new_frame = Vm::Frame.new(receiver, method.locals, method.scopes)

        params = method.params

        # TODO - this is a runtime error, not an intrinsic error
        raise "wrong number of arguments (given #{args.length} expecting #{params.length})" if args.length != params.length

        params.length.times do |i|
          new_frame.set_local(params[i], args[i])
        end

        context.push_frame(new_frame)
        begin
          method.ast.evaluate(context)
        ensure
          context.pop_frame
        end
      end
    end
  end
end

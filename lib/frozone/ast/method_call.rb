module Frozone
  module Ast
    class MethodCall
      def initialize(name, receiver_node, arg_nodes)
        raise "name must be a Symbol" unless name.is_a?(Symbol)
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

        # TODO - mode this into Method#call
        new_frame = Vm::Frame.new(receiver, method.locals, method.scopes)

        required_params = method.required_params

        # TODO - this is a runtime error, not an intrinsic error
        raise "wrong number of arguments (given #{args.length} expecting #{required_params.length})" if args.length != required_params.length

        required_params.length.times do |i|
          new_frame.set_local(required_params[i], args[i])
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

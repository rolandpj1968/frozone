require_relative 'node'

module Frozone
  module Ast
    # /(?<name>...)/ =~ string — performs match and assigns named captures to locals
    class MatchWrite < Node
      def initialize(call_node, targets)
        @call_node = call_node   # the =~ CallNode
        @targets = targets     # array of [depth, name] pairs for local vars
      end

      def children = [@call_node]

      def evaluate(context)
        result = @call_node.evaluate(context)
        m = Fiber[:last_match]
        if m
          @targets.each do |depth, name|
            capture = m[name]
            value = capture ? Vm::StringObject.new(capture) : Vm::NilObject::NIL
            context.frame.frame_at_depth(depth).set_local(name, value)
          end
        else
          @targets.each do |depth, name|
            context.frame.frame_at_depth(depth).set_local(name, Vm::NilObject::NIL)
          end
        end
        result
      end
    end
  end
end

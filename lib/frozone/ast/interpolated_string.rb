require_relative 'node'

module Frozone
  module Ast
    class InterpolatedString < Node
      def initialize(parts)
        @parts = parts
      end

      def to_s = "interp_str(#{@parts.map(&:to_s).join(', ')})"

      def evaluate(context)
        raw = @parts.map do |part|
          val = part.evaluate(context)
          val.is_a?(Vm::StringObject) ? val.raw : val.dispatch(context, :to_s, [], {}, nil, private_ok: true).raw
        end.join
        Vm::StringObject.new(raw)
      end
    end
  end
end

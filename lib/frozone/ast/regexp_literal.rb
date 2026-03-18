require_relative 'node'
require_relative '../vm/regexp_object'

module Frozone
  module Ast
    class RegexpLiteral < Node
      def initialize(source, flags)
        @source = source
        @flags  = flags
        @cached = nil
      end

      def evaluate(_context)
        @cached ||= Vm::RegexpObject.new(@source, @flags)
      end
    end

    class InterpolatedRegexpLiteral < Node
      def initialize(parts, flags)
        @parts = parts
        @flags = flags
      end

      def evaluate(context)
        source = @parts.map do |p|
          val = p.evaluate(context)
          if val.respond_to?(:raw)
            val.raw.to_s
          else
            str_result = val.dispatch(context, :to_s, [], {})
            str_result.respond_to?(:raw) ? str_result.raw.to_s : val.inspect
          end
        end.join
        Vm::RegexpObject.new(source, @flags)
      end
    end
  end
end

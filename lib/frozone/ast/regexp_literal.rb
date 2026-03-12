require_relative 'node'
require_relative '../vm/regexp_object'

module Frozone
  module Ast
    class RegexpLiteral < Node
      def initialize(source, flags)
        @source = source
        @flags  = flags
      end

      def evaluate(_context) = Vm::RegexpObject.new(@source, @flags)
    end

    class InterpolatedRegexpLiteral < Node
      def initialize(parts, flags)
        @parts = parts
        @flags = flags
      end

      def evaluate(context)
        source = @parts.map { |p| p.evaluate(context).raw.to_s }.join
        Vm::RegexpObject.new(source, @flags)
      end
    end
  end
end

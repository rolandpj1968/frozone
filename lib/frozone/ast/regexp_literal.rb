require_relative 'node'
require_relative '../vm/regexp_object'

module Frozone
  module Ast
    class RegexpLiteral < Node
      def initialize(source, flags, encoding_name = nil)
        @source = source
        @flags  = flags
        @encoding_name = encoding_name
        @cached = nil
      end

      def evaluate(_context)
        @cached ||= Vm::RegexpObject.new(@source, @flags, @encoding_name).tap(&:freeze_object!)
      end
    end

    class InterpolatedRegexpLiteral < Node
      def initialize(parts, flags)
        @parts = parts
        @flags = flags
      end

      def children = @parts

      def evaluate(context)
        source = @parts.map do |p|
          val = p.evaluate(context)
          if val.is_a?(Vm::StringObject)
            val.raw.to_s
          else
            str_result = val.dispatch(context, :to_s, [], {})
            # NOTE: respond_to?(:raw) here covers all raw-bearing VM types (Integer, Symbol, etc.)
            # returned from to_s; no shared superclass, so duck-typing is appropriate.
            str_result.respond_to?(:raw) ? str_result.raw.to_s : val.inspect
          end
        end.join
        Vm::RegexpObject.new(source, @flags)
      end
    end
  end
end

require_relative 'node'

module Frozone
  module Ast
    class InterpolatedString < Node
      # chilled: true = no frozen_string_literal magic (chilled, warn on mutation)
      # chilled: false = frozen_string_literal: false (regular mutable, no warning)
      # chilled: nil = interpolated with runtime expression (always mutable, no warning)
      def initialize(parts, source_encoding = nil, chilled: nil)
        @parts = parts
        @source_encoding = source_encoding
        @chilled = chilled
      end

      def to_s = "interp_str(#{@parts.map(&:to_s).join(', ')})"

      def evaluate(context)
        strings = @parts.map do |part|
          val = part.evaluate(context)
          r = val.is_a?(Vm::StringObject) ? val.raw : val.dispatch(context, :to_s, [], {}, nil, private_ok: true).raw
          r.is_a?(String) ? r : r.to_s
        end
        # Use source encoding as the base if available; otherwise fall back to Ruby's default join
        if @source_encoding && @source_encoding != Encoding::UTF_8
          base = "".dup.force_encoding(@source_encoding)
          raw = strings.reduce(base) { |acc, s| acc + s }
        else
          raw = strings.join
        end
        Vm::StringObject.new(raw, chilled_source: (@chilled ? :literal : nil))
      end
    end
  end
end

require_relative 'node'
require_relative '../vm/string_object'

module Frozone
  module Ast
    class StringLiteral < Node
      attr_reader :value
      # mode: :chilled = no frozen_string_literal magic → chilled (warn on mutation)
      #        :mutable = frozen_string_literal: false → regular mutable (no warning)
      #        :frozen  = frozen_string_literal: true or explicit .freeze → shared frozen object
      def initialize(value, mode: :chilled)
        @value = value
        @mode = mode
      end

      # Only via factory methods to dedup
      private_class_method :new

      def to_s = "str(#{@value})"

      def evaluate(_)
        case @mode
        when :frozen
          @value  # same shared frozen object every time
        when :mutable
          Vm::StringObject.new(@value.raw.dup)  # fresh non-chilled mutable copy
        else
          Vm::StringObject.new(@value.raw.dup, chilled_source: :literal)  # fresh chilled copy
        end
      end

      # TODO - share with symbols
      # TODO - thread-safety
      StringLiterals = {}

      # No frozen_string_literal magic comment → chilled string (Ruby 4.0 default)
      def self.from(value)
        StringLiterals[[value, value.encoding]] ||= new(Vm::StringObject.new(value), mode: :chilled)
      end

      MutableStringLiterals = {}

      # frozen_string_literal: false → non-chilled regular mutable string
      def self.mutable_from(value)
        MutableStringLiterals[[value, value.encoding]] ||= new(Vm::StringObject.new(value), mode: :mutable)
      end

      FrozenStringLiterals = {}

      # frozen_string_literal: true or "literal".freeze → shared frozen object, registered in dedup table
      def self.frozen_from(value)
        FrozenStringLiterals[[value, value.encoding]] ||= new(Vm::StringObject.new(value, frozen: true), mode: :frozen).tap do |node|
          # Register in the dedup table so that str.dedup/-@ finds the literal's canonical frozen object
          str_obj = node.instance_variable_get(:@value)
          key = "#{value.b}\x00#{value.encoding.name}"
          Vm::Intrinsics::STRING_DEDUP_TABLE[key] ||= str_obj
        end
      end
    end
  end
end

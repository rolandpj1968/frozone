require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class StringObject < ObjectObject
      attr_accessor :raw

      # chilled_source: nil = not chilled; :literal = from literal; Symbol = from Symbol#to_s
      attr_accessor :chilled_source

      def initialize(value, frozen: false, class_obj: nil, chilled_source: nil)
        raise "StringObject must have an String value" unless value.is_a?(String)

        super(class_obj || Core::STRING_CLASS)

        @raw = value.frozen? ? value.dup : value
        @frozen_object = frozen
        @deduped = false
        @chilled_source = chilled_source
      end

      def initialize_copy(orig)
        super
        @raw = @raw.dup
        @frozen_object = false
        @deduped = false
        @chilled_source = nil  # dup clears chilled status
      end

      def frozen? = @frozen_object
      def deduped? = @deduped
      def mark_deduped! = @deduped = true

      def chilled? = !@chilled_source.nil? && !@frozen_object

      def chilled_warning
        case @chilled_source
        when :literal
          "literal string will be frozen in the future (run with --debug-frozen-string-literal for more information)"
        when Symbol
          "string returned by :#{@chilled_source}.to_s will be frozen in the future (run with --debug-frozen-string-literal for more information)"
        end
      end

      def unchilled!
        @chilled_source = nil
      end

      def to_s = @raw

      # Marshal support: serialize just the raw string and frozen state,
      # restoring with the live Core::STRING_CLASS so deserialized objects dispatch correctly.
      def marshal_dump
        [@raw, @frozen_object, @chilled_source]
      end

      def marshal_load(data)
        raw, frozen, chilled_source = data
        @raw = raw
        @class_object = Core::STRING_CLASS
        @frozen_object = frozen
        @chilled_source = chilled_source
        @instance_variables_hash = {}
        @eigenclass = nil
      end
    end
  end
end

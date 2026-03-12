require_relative 'object_object'

module Frozone
  module Vm
    class RangeObject < ObjectObject
      attr_reader :begin_val, :end_val, :exclusive

      def initialize(begin_val, end_val, exclusive)
        super(Core::OBJECT_CLASS.get_constant(:Range))
        @begin_val = begin_val
        @end_val   = end_val
        @exclusive = exclusive
      end

      def exclusive? = @exclusive

      def raw
        b = @begin_val.respond_to?(:raw) ? @begin_val.raw : @begin_val
        e = @end_val.respond_to?(:raw) ? @end_val.raw : @end_val
        Range.new(b, e, @exclusive)
      end
    end
  end
end

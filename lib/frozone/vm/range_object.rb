require_relative 'object_object'

module Frozone
  module Vm
    class RangeObject < ObjectObject
      attr_reader :begin_val, :end_val, :exclusive

      def initialize(begin_val, end_val, exclusive, initialized: true)
        super(Core::OBJECT_CLASS.get_constant(:Range))
        @begin_val   = begin_val
        @end_val     = end_val
        @exclusive   = exclusive
        @initialized = initialized
      end

      def initialized? = @initialized

      def set_range(begin_val, end_val, exclusive)
        @begin_val   = begin_val
        @end_val     = end_val
        @exclusive   = exclusive
        @initialized = true
      end

      def exclusive? = @exclusive

      def raw
        # NOTE: respond_to?(:raw) is intentional duck-typing — VM value types (Integer, String, etc.)
        # share no single superclass defining raw, so respond_to? is the cleanest check here.
        b = @begin_val.respond_to?(:raw) ? @begin_val.raw : @begin_val
        e = @end_val.respond_to?(:raw) ? @end_val.raw : @end_val
        Range.new(b, e, @exclusive)
      end
    end
  end
end

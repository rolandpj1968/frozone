require_relative 'object_object'

module Frozone
  module Vm
    class RangeObject < ObjectObject
      def initialize(begin_val, end_val, exclusive)
        super(Core::OBJECT_CLASS.get_constant(:Range))
        @begin_val = begin_val
        @end_val   = end_val
        @exclusive = exclusive
      end

      attr_reader :begin_val, :end_val, :exclusive
      def exclusive? = @exclusive
    end
  end
end

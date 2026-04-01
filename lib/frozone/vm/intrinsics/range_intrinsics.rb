# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Range
        def range_initialized_q(_, range) = n2f_bool(range.is_a?(RangeObject) && range.initialized?)
        def range_begin(_, range) = range.begin_val
        def range_end(_, range) = range.end_val
        def range_exclude_end(_, range) = n2f_bool(range.exclusive?)

        def range_allocate(_, klass)
          obj = RangeObject.new(FNIL, FNIL, false, initialized: false)
          range_class = Core::OBJECT_CLASS.get_constant(:Range)
          obj.instance_variable_set(:@class_object, klass) if klass && !klass.equal?(range_class)
          obj
        end

        def range_set(_, range, b, e, excl)
          excl = fnil?(excl) ? false : excl.truthy?
          e = FNIL if e.nil?
          range.set_range(b, e, excl)
          range
        end
      end
    end
  end
end

require_relative '../ast/node'

module Frozone
  module Vm
    # Marker placed in a constant slot when --hoist-class-consts has
    # moved that constant's initialiser to the AOT execute phase.
    # The constant slot is occupied at load time so any subsequent
    # load-phase code that reads or rewrites the constant is caught
    # by Ast::ConstantRead / Ast::ConstantPath / Ast::ConstantWrite /
    # Ast::ConstantPathWrite (and *not* silently fed nil or silently
    # overwriting the marker).
    #
    # Carries the original source location so the diagnostic points at
    # the def-site that got hoisted, which is what you want when
    # debugging a load-time read-of-hoisted-const.
    class HoistedConstantSentinel
      attr_reader :qualified_name, :source_location

      def initialize(qualified_name, source_location)
        @qualified_name = qualified_name
        @source_location = source_location
      end

      def inspect = "#<HoistedConstantSentinel #{@qualified_name}>"
      def to_s    = inspect
    end
  end

  module Ast
    # Synthetic literal that evaluates to a HoistedConstantSentinel.
    # Inserted by vm.rb#hoist_expensive_class_constants! as the value
    # node of the placeholder ConstantWrite that occupies the slot of
    # a hoisted constant.
    class HoistedSentinelLiteral < Node
      def initialize(qualified_name, source_location)
        @sentinel = Vm::HoistedConstantSentinel.new(qualified_name, source_location)
      end

      def evaluate(_context) = @sentinel
    end
  end
end

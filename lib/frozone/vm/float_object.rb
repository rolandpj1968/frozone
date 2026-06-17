require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class FloatObject < ObjectObject
      # Thin wrapper around a host MRI `Float` — see docs/design.md.

      attr_reader :raw

      def initialize(value)
        super(Core::OBJECT_CLASS.get_constant(:Float))
        @raw = value
        @frozen_object = true
      end
    end
  end
end

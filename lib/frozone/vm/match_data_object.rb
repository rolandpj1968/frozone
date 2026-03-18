require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class MatchDataObject < ObjectObject
      attr_reader :raw, :frozone_regexp

      def initialize(match_data, regexp_obj = nil)
        super(Core::OBJECT_CLASS.get_constant(:MatchData))
        @raw = match_data
        @frozone_regexp = regexp_obj
      end

      def truthy? = true
    end
  end
end

require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class MatchDataObject < ObjectObject
      attr_reader :raw

      def initialize(match_data)
        super(Core::OBJECT_CLASS.get_constant(:MatchData))
        @raw = match_data
      end

      def truthy? = true
    end
  end
end

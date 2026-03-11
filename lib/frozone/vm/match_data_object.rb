require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class MatchDataObject < ObjectObject
      def initialize(match_data)
        super(Core::OBJECT_CLASS.get_constant(:MatchData))
        @match_data = match_data
      end

      def raw = @match_data
      def truthy? = true
    end
  end
end

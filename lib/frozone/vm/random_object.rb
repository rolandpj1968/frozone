require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class RandomObject < ObjectObject
      attr_accessor :rng

      def initialize(seed = nil)
        super(Core::OBJECT_CLASS.get_constant(:Random))
        @rng = seed.nil? ? Random.new : Random.new(seed)
      end

      def truthy? = true
    end
  end
end

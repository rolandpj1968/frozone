module Frozone
  module Utils
    def check_type(name, value, type)
      raise "#{name} of type #{name.class} expected to be a #{type}" unless value.is_a?(type)
      value
    end

    def check_nil_or_type(name, value, type)
      raise "#{name} of type #{name.class} expected to be nil or a #{type}" unless value.nil? || value.is_a?(type)
      value
    end

    def check_array_type(name, value, element_type)
      check_type(name, value, Array)
      raise "#{name} must be an Array of #{element_type}" unless value.all?(element_type)
      value
    end
  end
end

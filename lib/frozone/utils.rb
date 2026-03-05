module Frozone
  module Utils
    def check_type(name, value, type)
      raise "#{name} of type #{value.class} expected to be a #{type}" unless value.is_a?(type)
      value
    end

    def check_nil_or_type(name, value, type)
      raise "#{name} of type #{value.class} expected to be nil or a #{type}" unless value.nil? || value.is_a?(type)
      value
    end

    def check_array_type(name, value, element_type)
      check_type(name, value, Array)
      raise "#{name} must be an Array of #{element_type}" unless value.all?(element_type)
      value
    end

    def check_nil_or_array_type(name, value, element_type)
      check_nil_or_array_type(name, value, Array)
      raise "#{name} must be an Array of #{element_type}" unless value.nil? || value.all?(element_type)
      value
    end

    def check_array_of_pairs_of_types(name, value, element_type_1, element_type_2)
      check_type(name, value, Array)
      value.each do |o|
        raise "#{name} must be an array of [#{element_type_1}, #{element_type_2}] pairs" unless o.is_a?(Array) && o.length == 2 && o[0].is_a?(element_type_1) && o[1].is_a?(element_type_2)
      end
      value
    end
  end
end

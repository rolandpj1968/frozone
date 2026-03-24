module Warning
  KNOWN_CATEGORIES = %i[deprecated experimental performance strict_unused_block unused_block].freeze

  # Use parallel arrays instead of a Hash to avoid Symbol#hash ordering issues
  # (object.rb loads before symbol.rb, so Hash uses __id__ as hash function).
  @cat_keys = [:deprecated, :experimental, :performance, :strict_unused_block, :unused_block]
  @cat_vals = [true, true, false, false, false]

  extend self

  def self.categories = KNOWN_CATEGORIES

  def self.[](category)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    idx = @cat_keys.index { |k| k == category }
    raise ArgumentError, "unknown category: #{category}" unless idx
    @cat_vals[idx]
  end

  def self.[]=(category, value)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    idx = @cat_keys.index { |k| k == category }
    raise ArgumentError, "unknown category: #{category}" unless idx
    @cat_vals[idx] = value ? true : false
  end

  def self.warn(msg, category: nil)
    return nil if category && !self[category]
    $stderr.write(msg)
    nil
  end
end

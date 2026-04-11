# Module erasure A/B test — exercises methods, constants, and ivars
# inherited through modules and superclasses.

module Greetable
  GREETING = "Hello"

  def greet(name)
    "#{GREETING}, #{name}!"
  end
end

module Sizeable
  def size_desc
    s = size
    if s < 5
      "small"
    elsif s < 10
      "medium"
    else
      "large"
    end
  end
end

class Collection
  include Sizeable
  attr_reader :items

  def initialize
    @items = []
  end

  def add(item)
    @items << item
    self
  end

  def size
    @items.size
  end
end

class GreetingCollection < Collection
  include Greetable
  SEPARATOR = ", "

  def all_greetings
    @items.map { |name| greet(name) }.join(SEPARATOR)
  end
end

# Test basic module method dispatch
c = GreetingCollection.new
c.add("Alice").add("Bob").add("Charlie")

puts c.greet("World")
puts c.size
puts c.size_desc
puts c.all_greetings
puts c.is_a?(Greetable)
puts c.is_a?(Sizeable)
puts c.is_a?(Collection)

# Test constant access
puts GreetingCollection::GREETING
puts GreetingCollection::SEPARATOR

# Test inherited constants from superclass
puts Collection.new.add(1).add(2).size_desc

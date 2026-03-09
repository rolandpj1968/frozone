module Kernel
end

class Object < BasicObject
  include Kernel
end

module Comparable
end

module Enumerable
end

class String < Object
  include Comparable
end

class Symbol < Object
  include Comparable
end

class Array < Object
  include Enumerable
end

class Hash < Object
  include Enumerable
end

class Numeric < Object
  include Comparable
end

class Integer < Numeric
end

class Float < Numeric
end

class Proc < Object
end

class Range < Object
end

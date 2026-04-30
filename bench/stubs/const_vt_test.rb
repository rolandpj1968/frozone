# Exercises the c_X virtual surface used for dynamic-receiver
# constant lookup (`self.class::CONST`). Static `Foo::CONST` keeps
# the cheap k_<flat>() accessor and isn't tested here.

class A
  ITEM = 100
  def show = self.class::ITEM
end

class B < A
  ITEM = 200
end

class C < A
  # inherits ITEM from A
end

puts A.new.show
puts B.new.show
puts C.new.show

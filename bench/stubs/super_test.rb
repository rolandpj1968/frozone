# Exercises Ast::Super lowering: explicit args (super(args)),
# forwarding (bare super), and super-with-block.

class Base
  def foo(x) = "Base(#{x})"
end

class Sub < Base
  def foo(x) = "Sub:" + super(x * 10)
end

class Forwarder < Base
  def foo(x) = "Forwarder:" + super
end

class WithBlock < Base
  def foo(x)
    super(x.to_s + (block_given? ? "|y" : ""))
  end
end

puts Sub.new.foo(2)
puts Forwarder.new.foo(3)
puts WithBlock.new.foo(4) { |z| z * 2 }

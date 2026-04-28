class Catcher
  def method_missing(name, *args)
    puts "caught: #{name} with #{args.size} args"
    :handled
  end
end

c = Catcher.new
puts c.foo
puts c.bar(1, 2, 3)

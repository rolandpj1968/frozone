# Exercises the Module/Class split: Math.class == Module,
# String.class == Class, nil::FOO raises TypeError, Module::UNDEF
# raises NameError. Class < Module < Object inheritance verified
# via is_a? on the IS_A LUT.

module M; end
class C; end

puts Math.class
puts M.class
puts C.class
puts Module.class
puts Class.class

puts M.is_a?(Module)
puts M.is_a?(Class)
puts C.is_a?(Module)
puts C.is_a?(Class)

# nil::FOO → TypeError (not a class/module)
begin
  nil::FOO
rescue TypeError
  puts "nil::FOO raised TypeError"
end

# M::UNDEFINED → NameError (uninitialized constant)
begin
  M::UNDEFINED
rescue NameError
  puts "M::UNDEFINED raised NameError"
end

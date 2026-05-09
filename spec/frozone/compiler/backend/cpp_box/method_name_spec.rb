require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/class_emitter'

# Round-trip property tests for Ruby ↔ C++ method-name mangling.
#
# The mangling has to be INJECTIVE: every Ruby method name maps to a
# unique C++ identifier, and the reverse recovers the original Ruby
# name exactly. Loss-of-information here causes runtime dispatch
# failures that look like "undefined method 'foo' for an instance of
# Bar" (the methods_table lookup uses the round-tripped Ruby name; if
# the round-trip is wrong, the lookup misses and method_missing
# fires).
#
# The previous scheme used `_q`/`_b`/`_set` suffixes which collide
# with literal Ruby names ending in those sequences (Ruby
# `module_const_set` and Ruby `module_const=` would both produce
# `m_module_const_set`). The current scheme uses a per-kind PREFIX
# (`m_`/`mq_`/`mb_`/`me_`) which is unambiguous: the prefix
# distinguishes the suffix kind, the rest of the name is the
# Ruby identifier verbatim.

C = Frozone::Compiler::Backend::CppBox::Cpp unless defined?(C)
CE = Frozone::Compiler::Backend::CppBox::ClassEmitter unless defined?(CE)

RSpec.describe "Ruby ↔ C++ method-name mangling" do
  describe "Cpp.method_name (forward)" do
    {
      :foo                => "m_foo",
      :"foo?"             => "mm_foo_q",
      :"foo!"             => "mm_foo_bang",
      :"foo="             => "mm_foo_eq",
      :module_const_set   => "m_module_const_set",   # literal _set ending — NOT a setter
      :"module_const="    => "mm_module_const_eq",   # actual setter
      :module_const__set  => "m_module_const__set",  # literal __set ending
      :foo_q              => "m_foo_q",              # literal _q ending — NOT a predicate
      :foo_bang           => "m_foo_bang",           # literal _bang ending — NOT a bang
      :foo_eq             => "m_foo_eq",             # literal _eq ending — NOT a setter
      :"respond_to?"      => "mm_respond_to_q",
      :"is_a?"            => "mm_is_a_q",
      :"empty?"           => "mm_empty_q",
      :"name_?"           => "mm_name__q",           # `?` after trailing underscore
      :name__q            => "m_name__q",            # literal __q
      :__send__           => "m___send__",           # leading double-underscore
      :name__             => "m_name__",             # trailing double underscore, no special suffix
      :mm_foo_q           => "m_mm_foo_q",           # `mm_` prefix as part of literal Ruby name
      :mm_foo             => "m_mm_foo",
    }.each do |ruby, expected_cpp|
      it "encodes Ruby :#{ruby.inspect} → #{expected_cpp.inspect}" do
        expect(C.method_name(ruby)).to eq(expected_cpp)
      end
    end

    # Operator names go through OP_NAMES — verify we don't accidentally
    # touch them. They share the C++ namespace but use `op_` prefix so
    # never collide with identifier method names.
    {
      :+   => "op_plus",
      :==  => "op_eq_q",
      :[]= => "op_aset",
      :"<=>" => "op_spaceship",
    }.each do |ruby_op, expected|
      it "leaves operator :#{ruby_op.inspect} alone (#{expected})" do
        expect(C.method_name(ruby_op)).to eq(expected)
      end
    end
  end

  describe "ClassEmitter.cpp_name_to_ruby (reverse)" do
    # Same cases reversed.
    {
      "m_foo"               => "foo",
      "mm_foo_q"            => "foo?",
      "mm_foo_bang"         => "foo!",
      "mm_foo_eq"           => "foo=",
      "m_module_const_set"  => "module_const_set",
      "mm_module_const_eq"  => "module_const=",
      "m_module_const__set" => "module_const__set",
      "m_foo_q"             => "foo_q",
      "m_foo_bang"          => "foo_bang",
      "m_foo_eq"            => "foo_eq",
      "mm_respond_to_q"     => "respond_to?",
      "mm_is_a_q"           => "is_a?",
      "mm_empty_q"          => "empty?",
      "mm_name__q"          => "name_?",
      "m_name__q"           => "name__q",
      "m___send__"          => "__send__",
      "m_name__"            => "name__",
      "m_mm_foo_q"          => "mm_foo_q",
      "m_mm_foo"            => "mm_foo",
    }.each do |cpp, expected_ruby|
      it "decodes C++ #{cpp.inspect} → #{expected_ruby.inspect}" do
        expect(CE.cpp_name_to_ruby(cpp)).to eq(expected_ruby)
      end
    end
  end

  describe "round-trip" do
    # Property: forward(reverse(c)) == c for every C++ name we emit;
    # reverse(forward(r)) == r for every valid Ruby method name.
    %w[foo foo? foo! foo= empty? respond_to? __send__
       module_const_set module_const= module_const__set
       name_? name__q name_q name__ name_set
       foo_bang foo_eq mm_foo mm_foo_q mm_foo_bang mm_foo_eq].each do |ruby|
      it "round-trips Ruby :#{ruby.inspect} through forward + reverse" do
        cpp = C.method_name(ruby.to_sym)
        round_tripped = CE.cpp_name_to_ruby(cpp)
        expect(round_tripped).to eq(ruby)
      end
    end
  end

  describe "no collisions on real-world frozone names" do
    # Sanity check: every Ruby method name in lib/ should produce a
    # unique cpp_name. Catches regressions where two Ruby names get
    # the same C++ name.
    it "doesn't map two Ruby names to the same C++ name" do
      names = `grep -rhoE '\\bdef [a-z_][a-zA-Z0-9_]*[?!=]?' lib/core/4.0/ lib/frozone/`
                .split("\n")
                .map { |l| l.sub(/^def /, '').strip }
                .reject(&:empty?)
                .uniq
      cpp_to_ruby = {}
      names.each do |ruby|
        cpp = C.method_name(ruby.to_sym)
        if cpp_to_ruby.key?(cpp) && cpp_to_ruby[cpp] != ruby
          fail "collision: Ruby '#{ruby}' and Ruby '#{cpp_to_ruby[cpp]}' both map to C++ '#{cpp}'"
        end
        cpp_to_ruby[cpp] = ruby
      end
    end
  end
end

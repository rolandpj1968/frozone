#include "../runtime/frozone.hpp"





static auto greet(auto name, auto greeting = RubyString("hello", 5)) {
  ruby_puts(greeting);
  return ruby_puts(name);
}


int main() {
  greet(RubyString("world", 5));
  greet(RubyString("ruby", 4), RubyString("hi", 2));
  return 0;
}

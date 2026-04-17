#include "../runtime/frozone.hpp"






int main() {
  ruby_puts(({ auto _l = (true); (_l) ? decltype((RubyString("hello", 5)))(RubyString("hello", 5)) : decltype((RubyString("hello", 5)))(_l); }));
  ruby_puts(({ auto _l = (false); (_l) ? decltype((RubyString("world", 5)))(_l) : (RubyString("world", 5)); }));
  return 0;
}

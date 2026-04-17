#include "../runtime/frozone.hpp"






int main() {
  (/* UNSUPPORTED: GlobalVariableRead */ << File.expand_path(RubyString("../harness/loader.rb", 20), RubyString("/tmp", 4)));
  /* UNSUPPORTED: MethodDef */;
  /* UNSUPPORTED: ClassDef */;
  Ruby_Foo();
  Ruby_Foo();
  ruby_puts(Foo.count());
  return 0;
}

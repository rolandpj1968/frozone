#include "../runtime/frozone.hpp"





static auto twice() {
  /* UNSUPPORTED: Yield */;
  return /* UNSUPPORTED: Yield */;
}


int main() {
  twice();
  return 0;
}

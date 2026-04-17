#include "../runtime/frozone.hpp"

static const RubyString A = RubyString("this is a long string with no useful contents yada yada yada yada", 65);
static const RubyString B = RubyString("this is also a long string with no useful contents yada yada daaaaaa", 68);




static auto ruby_xor_b(auto a, auto b) {
  std::decay_t<decltype(a.len())> l{};
  std::decay_t<decltype(b.len())> lb{};
  int64_t i = 0;
  std::decay_t<decltype(a.get_byte(i))> ba{};
  std::decay_t<decltype(b.get_byte(i))> bb{};
  if (({ auto _l = ((!(true))); (_l) ? decltype(((!(true))))(_l) : ((!(true))); })) {
    throw Ruby_RuntimeError("expected two string arguments");
  }
  (l = a.len());
  (lb = b.len());
  if ((lb < l)) {
    (l = lb);
  }
  (i = INT64_C(0));
  while ((i < l)) {
    (ba = a.get_byte(i));
    (bb = b.get_byte(i));
    a.set_byte(i, (ba ^ bb));
    (i = (i + INT64_C(1)));
  }
  return a;
}


int main() {
  RubyString a;
  RubyString b;
  int64_t sum = 0;
  RubyString result;
  (a = A);
  (b = B);
  (sum = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(2000); _i++) {
    (result = ruby_xor_b(a.dup_(), b));
    (sum = (sum + result.len()));
  }
  ruby_puts(sum);
  return 0;
}

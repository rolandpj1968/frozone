#include "../runtime/frozone.hpp"

static const int64_t MAX_DEPTH = 14LL;
static const int64_t MIN_DEPTH = 4LL;
static const int64_t STRETCH_DEPTH = 15LL;




static auto item_check(auto left, auto right) {
  if (ruby_nil_q(left)) {
    return INT64_C(1);
  }
  return ((INT64_C(1) + item_check(left[INT64_C(0)], left[INT64_C(1)])) + item_check(right[INT64_C(0)], right[INT64_C(1)]));
}

static auto bottom_up_tree(auto depth) {
  if (!((depth > INT64_C(0)))) {
    return RubyTree(RUBY_NIL, RUBY_NIL);
  }
  (depth = (depth - INT64_C(1)));
  return RubyTree(bottom_up_tree(depth), bottom_up_tree(depth));
}


int main() {
  FROZONE_GC_INIT();
  int64_t total = 0;
  RubyTree stretch_tree;
  RubyTree long_lived_tree;
  int64_t depth = 0;
  int64_t iterations = 0;
  int64_t check = 0;
  RubyTree temp_tree;
  (total = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(60); _i++) {
    (stretch_tree = bottom_up_tree(STRETCH_DEPTH));
    (stretch_tree = RUBY_NIL);
    (long_lived_tree = bottom_up_tree(MAX_DEPTH));
    (depth = MIN_DEPTH);
    while ((depth <= MAX_DEPTH)) {
      (iterations = (INT64_C(1) << ((MAX_DEPTH - depth) + MIN_DEPTH)));
      (check = INT64_C(0));
      for (int64_t i = INT64_C(1); i <= iterations; i++) {
      (temp_tree = bottom_up_tree(depth));
      (check = (check + item_check(temp_tree[INT64_C(0)], temp_tree[INT64_C(1)])));
    };
      (total = (total + check));
      (depth = (depth + INT64_C(2)));
    };
  }
  ruby_puts(total);
  FROZONE_GC_SHUTDOWN();
  return 0;
}

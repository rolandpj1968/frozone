#include "../runtime/frozone.hpp"



static auto HARD20 = []() { RubyArray<RubyString> _a(20);
  (*_a.data)[0] = RubyString("..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9", 81);
  (*_a.data)[1] = RubyString(".......12........3..23..4....18....5.6..7.8.......9.....85.....9...4.5..47...6...", 81);
  (*_a.data)[2] = RubyString(".2..5.7..4..1....68....3...2....8..3.4..2.5.....6...1...2.9.....9......57.4...9..", 81);
  (*_a.data)[3] = RubyString("........3..1..56...9..4..7......9.5.7.......8.5.4.2....8..2..9...35..1..6........", 81);
  (*_a.data)[4] = RubyString("12.3....435....1....4........54..2..6...7.........8.9...31..5.......9.7.....6...8", 81);
  (*_a.data)[5] = RubyString("1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1", 81);
  (*_a.data)[6] = RubyString(".......39.....1..5..3.5.8....8.9...6.7...2...1..4.......9.8..5..2....6..4..7.....", 81);
  (*_a.data)[7] = RubyString("12.3.....4.....3....3.5......42..5......8...9.6...5.7...15..2......9..6......7..8", 81);
  (*_a.data)[8] = RubyString("..3..6.8....1..2......7...4..9..8.6..3..4...1.7.2.....3....5.....5...6..98.....5.", 81);
  (*_a.data)[9] = RubyString("1.......9..67...2..8....4......75.3...5..2....6.3......9....8..6...4...1..25...6.", 81);
  (*_a.data)[10] = RubyString("..9...4...7.3...2.8...6...71..8....6....1..7.....56...3....5..1.4.....9...2...7..", 81);
  (*_a.data)[11] = RubyString("....9..5..1.....3...23..7....45...7.8.....2.......64...9..1.....8..6......54....7", 81);
  (*_a.data)[12] = RubyString("4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........", 81);
  (*_a.data)[13] = RubyString("7.8...3.....2.1...5.........4.....263...8.......1...9..9.6....4....7.5...........", 81);
  (*_a.data)[14] = RubyString("3.7.4...........918........4.....7.....16.......25..........38..9....5...2.6.....", 81);
  (*_a.data)[15] = RubyString("........8..3...4...9..2..6.....79.......612...6.5.2.7...8...5...1.....2.4.5.....3", 81);
  (*_a.data)[16] = RubyString(".......1.4.........2...........5.4.7..8...3....1.9....3..4..2...5.1........8.6...", 81);
  (*_a.data)[17] = RubyString(".......12....35......6...7.7.....3.....4..8..1...........12.....8.....4..5....6..", 81);
  (*_a.data)[18] = RubyString("1.......2.9.4...5...6...7...5.3.4.......6........58.4...2...6...3...9.8.7.......1", 81);
  (*_a.data)[19] = RubyString(".....1.2.3...4.5.....6....7..2.....1.8..9..3.4.....8..5....2....9..3.4....67.....", 81);
  return _a; }();


static auto make_shareable(auto x) {
  return x;
}

static auto sd_genmat() {
  RubyArray<RubyArray<int64_t>> mr;
  RubyArray<RubyArray<int64_t>> mc;
  int64_t r = 0;
  int64_t i = 0;
  int64_t j = 0;
  int64_t k = 0;
  RubyArray<int64_t> mcr;
  int64_t r2 = 0;
  int64_t c2 = 0;
  (mr = ({ auto _n = INT64_C(324); int64_t _ai = 0; auto _e0 = RubyArray_I64(0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = RubyArray_I64(0); } _arr; }));
  (mc = ({ auto _n = INT64_C(729); int64_t _ai = 0; auto _e0 = make_ra(INT64_C(4), INT64_C(0)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(INT64_C(4), INT64_C(0)); } _arr; }));
  (r = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(9))) {
    (j = INT64_C(0));
    while ((j < INT64_C(9))) {
    (k = INT64_C(0));
    while ((k < INT64_C(9))) {
    (mcr = mc[r]);
    mcr[INT64_C(0)] = ((INT64_C(9) * i) + j);
    mcr[INT64_C(1)] = (((((ruby_div(i, INT64_C(3)) * INT64_C(3)) + ruby_div(j, INT64_C(3))) * INT64_C(9)) + k) + INT64_C(81));
    mcr[INT64_C(2)] = (((INT64_C(9) * i) + k) + INT64_C(162));
    mcr[INT64_C(3)] = (((INT64_C(9) * j) + k) + INT64_C(243));
    (r = (r + INT64_C(1)));
    (k = (k + INT64_C(1)));
  };
    (j = (j + INT64_C(1)));
  };
    (i = (i + INT64_C(1)));
  }
  (r2 = INT64_C(0));
  while ((r2 < INT64_C(729))) {
    (c2 = INT64_C(0));
    while ((c2 < INT64_C(4))) {
    (mr[mc[r2][c2]] << r2);
    (c2 = (c2 + INT64_C(1)));
  };
    (r2 = (r2 + INT64_C(1)));
  }
  return ({ auto _e0 = mr; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mc; _a; });
}

static auto sd_update_forward(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t min = 0;
  int64_t min_c = 0;
  RubyArray<int64_t> mcr;
  int64_t c2 = 0;
  RubyArray<int64_t> mrc;
  int64_t r2 = 0;
  int64_t rr = 0;
  RubyArray<int64_t> p;
  int64_t cc2 = 0;
  int64_t cc = 0;
  (min = INT64_C(10));
  (min_c = INT64_C(0));
  (mcr = mc[r]);
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    sc[mcr[c2]] += INT64_C(128);
    (c2 = (c2 + INT64_C(1)));
  }
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    (mrc = mr[mcr[c2]]);
    (r2 = INT64_C(0));
    while ((r2 < INT64_C(9))) {
    (rr = mrc[r2]);
    if ((sr[rr] += INT64_C(1) == INT64_C(1))) {
    (p = mc[rr]);
    (cc2 = INT64_C(0));
    while ((cc2 < INT64_C(4))) {
    (cc = p[cc2]);
    if ((sc[cc] -= INT64_C(1) < min)) {
    (min = sc[cc]);
    (min_c = cc);
  };
    (cc2 = (cc2 + INT64_C(1)));
  };
  };
    (r2 = (r2 + INT64_C(1)));
  };
    (c2 = (c2 + INT64_C(1)));
  }
  return ({ auto _e0 = min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = min_c; _a; });
}

static auto sd_update_reverse(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t c2 = 0;
  int64_t c = 0;
  int64_t r2 = 0;
  int64_t rr = 0;
  RubyArray<int64_t> p;
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    sc[mc[r][c2]] -= INT64_C(128);
    (c2 = (c2 + INT64_C(1)));
  }
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    (c = mc[r][c2]);
    (r2 = INT64_C(0));
    while ((r2 < INT64_C(9))) {
    (rr = mr[c][r2]);
    if ((sr[rr] -= INT64_C(1) == INT64_C(0))) {
    (p = mc[rr]);
    sc[p[INT64_C(0)]] += INT64_C(1);
    sc[p[INT64_C(1)]] += INT64_C(1);
    sc[p[INT64_C(2)]] += INT64_C(1);
    sc[p[INT64_C(3)]] += INT64_C(1);
  };
    (r2 = (r2 + INT64_C(1)));
  };
    (c2 = (c2 + INT64_C(1)));
  }
  return RubyNil();
}

static auto sd_solve(auto mr, auto mc, auto s) {
  RubyArray<int64_t> sr;
  RubyArray<int64_t> sc;
  int64_t hints = 0;
  int64_t i = 0;
  std::decay_t<decltype(s[i])> rb_char{};
  int64_t a = 0;
  RubyArray<int64_t> cr;
  RubyArray<int64_t> cc;
  int64_t min = 0;
  int64_t dir = 0;
  int64_t c = 0;
  int64_t r2 = 0;
  RubyArray<int64_t> o;
  int64_t j = 0;
  int64_t r = 0;
  (sr = make_ra(INT64_C(729), INT64_C(0)));
  (sc = make_ra(INT64_C(324), INT64_C(9)));
  (hints = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(81))) {
    (rb_char = s[i]);
    (a = (({ auto _l = ((rb_char >= RubyString("1", 1))); (_l) ? decltype(((rb_char <= RubyString("9", 1))))((rb_char <= RubyString("9", 1))) : decltype(((rb_char <= RubyString("9", 1))))(_l); }) ? ((rb_char.ord() - INT64_C(49))) : (INT64_C(-1))));
    if ((a >= INT64_C(0))) {
    sd_update_forward(mr, mc, sr, sc, ((i * INT64_C(9)) + a));
    (hints = (hints + INT64_C(1)));
  };
    (i = (i + INT64_C(1)));
  }
  (cr = make_ra(INT64_C(81), INT64_C(-1)));
  (cc = make_ra(INT64_C(81), INT64_C(0)));
  (i = INT64_C(0));
  (min = INT64_C(10));
  (dir = INT64_C(1));
  while (true) {
    while (({ auto _l = ((i >= INT64_C(0))); (_l) ? decltype(((i < (INT64_C(81) - hints))))((i < (INT64_C(81) - hints))) : decltype(((i < (INT64_C(81) - hints))))(_l); })) {
    if ((dir == INT64_C(1))) {
    if ((min > INT64_C(1))) {
    (c = INT64_C(0));
    while ((c < INT64_C(324))) {
    if ((sc[c] < min)) {
    (min = sc[c]);
    cc[i] = c;
    if ((min < INT64_C(2))) {
    break;
  };
  };
    (c = (c + INT64_C(1)));
  };
  };
    if (({ auto _l = ((min == INT64_C(0))); (_l) ? decltype(((min == INT64_C(10))))(_l) : ((min == INT64_C(10))); })) {
    cr[i] = (dir = INT64_C(-1));
    (i = (i - INT64_C(1)));
  };
  };
    (c = cc[i]);
    if (({ auto _l = ((dir == INT64_C(-1))); (_l) ? decltype(((cr[i] >= INT64_C(0))))((cr[i] >= INT64_C(0))) : decltype(((cr[i] >= INT64_C(0))))(_l); })) {
    sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]]);
  };
    (r2 = (cr[i] + INT64_C(1)));
    while (({ auto _l = ((r2 < INT64_C(9))); (_l) ? decltype(((sr[mr[c][r2]] != INT64_C(0))))((sr[mr[c][r2]] != INT64_C(0))) : decltype(((sr[mr[c][r2]] != INT64_C(0))))(_l); })) {
    (r2 = (r2 + INT64_C(1)));
  };
    if ((r2 < INT64_C(9))) {
    auto _masgn1 = sd_update_forward(mr, mc, sr, sc, mr[c][r2]);
    min = _masgn1[INT64_C(0)];
    cc[(i + INT64_C(1))] = _masgn1[INT64_C(1)];
    cr[i] = r2;
    (dir = INT64_C(1));
    (i = (i + INT64_C(1)));
  } else {
    cr[i] = INT64_C(-1);
    (dir = INT64_C(-1));
    (i = (i - INT64_C(1)));
  };
  };
    if ((i < INT64_C(0))) {
    break;
  };
    (o = make_ra(INT64_C(81), INT64_C(0)));
    (j = INT64_C(0));
    while ((j < INT64_C(81))) {
    o[j] = (s[j].ord() - INT64_C(48));
    (j = (j + INT64_C(1)));
  };
    (j = INT64_C(0));
    while ((j < i)) {
    (r = mr[cc[j]][cr[j]]);
    o[ruby_div(r, INT64_C(9))] = (ruby_mod(r, INT64_C(9)) + INT64_C(1));
    (j = (j + INT64_C(1)));
  };
    o.join();
    (i = (i - INT64_C(1)));
    (dir = INT64_C(-1));
  }
  return RubyNil();
}


int main() {
  FROZONE_GC_INIT();
  RubyArray<RubyArray<int64_t>> mr;
  RubyArray<RubyArray<int64_t>> mc;
  RubyString last;
  auto _masgn2 = sd_genmat();
  mr = _masgn2[INT64_C(0)];
  mc = _masgn2[INT64_C(1)];
  (last = RubyString("", 0));
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    { auto _coll = HARD20; for (auto& line : *_coll.data) {
      (last = sd_solve(mr, mc, line));
    } };
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}

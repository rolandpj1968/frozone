# Exercises the c_X virtual surface used for dynamic-receiver
# constant lookup (`self.class::CONST`). Static `Foo::CONST` keeps
# the cheap k_<flat>() accessor and isn't tested here.
#
# KNOWN-FAILING under box-first as of 2026-04-30: the compiled binary
# hangs at startup. The cpp file builds clean (m_show + c_ITEM
# overrides emit correctly) so the bug is in static initialization
# or first-call dispatch — not the c_X path itself (a one-class
# test with bare lexical `ITEM` also hangs). Diagnosis blocked by
# the binary being too large for gdb to attach quickly. Test kept
# as documentation of intended semantics.

class A
  ITEM = 100
  def show = self.class::ITEM
end

class B < A
  ITEM = 200
end

class C < A
  # inherits ITEM from A
end

puts A.new.show
puts B.new.show
puts C.new.show

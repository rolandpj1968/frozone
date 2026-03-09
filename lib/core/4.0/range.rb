class Range
  def each(&block)
    Intrinsics.range_each(self, block)
  end
  def to_a           = Intrinsics.range_to_a(self)
  def include?(val)  = Intrinsics.range_include(self, val)
  alias member? include?
  alias cover? include?
  def size           = Intrinsics.range_size(self)
  alias count size
  alias length size
  def begin          = Intrinsics.range_begin(self)
  def end            = Intrinsics.range_end(self)
  def exclude_end?   = Intrinsics.range_exclude_end(self)
  def first          = self.begin
  def last           = self.end
  def min            = self.begin
  def max            = self.exclusive? ? self.end - 1 : self.end
  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end
  def map;    r = []; each { |x| r << yield(x) };      r; end
  def select; r = []; each { |x| r << x if yield(x) }; r; end
  def any?  = (each { |x| return true  if yield(x) }; false)
  def all?  = (each { |x| return false unless yield(x) }; true)
  def none? = (each { |x| return false if yield(x) }; true)
  def to_s  = Intrinsics.range_to_s(self)
end

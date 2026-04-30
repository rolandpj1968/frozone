# Trivial / closed-world-decidable defined?(...) cases.
# Other kinds (:method, :gvar, :super, etc.) are deferred and
# hard-fail at AOT under FROZONE_BOX_HARD_FAIL=1.

class Holder
  def initialize
    @iv = 5
  end

  def show
    puts defined?(self)        # "self"
    puts defined?(nil)         # "nil"
    puts defined?(true)        # "true"
    puts defined?(false)       # "false"
    puts defined?("literal")   # "expression"
    puts defined?(@iv)         # "instance-variable"
    x = 7
    puts defined?(x)           # "local-variable"
  end

  def with_block(&_block)
    puts defined?(yield)       # "yield" or nil
  end
end

h = Holder.new
h.show
h.with_block { 1 }
h.with_block

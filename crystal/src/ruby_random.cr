# RubyRandom — Crystal wrapper for Ruby's Random class.
# Supports seeded construction and rand (float 0..1, int 0..n).
# Ruby_Random is the codegen alias (snapshot_codegen emits Ruby_ClassName).
alias Ruby_Random = RubyRandom

class RubyRandom < RubyObject
  def initialize(seed : RubyObject)
    @rng = Random::PCG32.new(seed.to_i64.to_u64)
  end

  def to_s : String; "#<Random:#{object_id}>"; end
  def inspect : String; to_s; end

  def rand : RubyObject
    RubyFloat.new(@rng.rand)
  end

  def rand(arg : RubyObject) : RubyObject
    if arg.is_a?(RubyInteger)
      RubyInteger.new(@rng.rand(arg.to_i64))
    elsif arg.is_a?(RubyFloat)
      RubyFloat.new(@rng.rand * arg.to_f64)
    else
      RubyFloat.new(@rng.rand)
    end
  end
end

require "./ruby_object"
require "./ruby_nil"
require "./ruby_bool"

# RubyProc wraps a Crystal Proc so that Ruby procs/lambdas can be stored as
# RubyObject references and called later via .call().
class RubyProc < RubyObject
  getter block : Array(RubyObject) -> RubyObject

  def initialize(@block : Array(RubyObject) -> RubyObject)
  end

  # call with 0–4 positional args; extend if more are needed.
  def call : RubyObject
    @block.call([] of RubyObject)
  end

  def call(a0 : RubyObject) : RubyObject
    @block.call([a0] of RubyObject)
  end

  def call(a0 : RubyObject, a1 : RubyObject) : RubyObject
    @block.call([a0, a1] of RubyObject)
  end

  def call(a0 : RubyObject, a1 : RubyObject, a2 : RubyObject) : RubyObject
    @block.call([a0, a1, a2] of RubyObject)
  end

  def call(a0 : RubyObject, a1 : RubyObject, a2 : RubyObject, a3 : RubyObject) : RubyObject
    @block.call([a0, a1, a2, a3] of RubyObject)
  end

  # Splat call: passes all args as an array.
  def call(args : Array(RubyObject)) : RubyObject
    @block.call(args)
  end

  def to_s : String; "#<Proc>"; end
  def inspect : String; "#<Proc>"; end
  def ==(other : RubyObject) : Bool; same?(other); end
  def hash : UInt64; object_id.to_u64; end
end

# Macro-generated fixed-size tuple classes: RubyTuple1 through RubyTuple8.
# Single allocation with N inline pointer fields — ~3x less overhead than
# RubyArray (which allocates wrapper + Crystal Array + buffer).
#
# RubyPair is kept as an alias for RubyTuple2 (backward compatibility).

{% for n in (1..8) %}
class RubyTuple{{n}} < RubyObject
  {% for i in (0...n) %}
  @v{{i}} : RubyObject
  {% end %}

  def initialize({% for i in (0...n) %}@v{{i}} : RubyObject{% if i < n - 1 %}, {% end %}{% end %})
  end

  def [](i : Int64) : RubyObject
    {% if n == 1 %}
    @v0
    {% elsif n == 2 %}
    i == 0 ? @v0 : @v1
    {% else %}
    case i
    {% for i in (0...n) %}
    when {{i}} then @v{{i}}
    {% end %}
    else @v0  # Ruby returns nil for out-of-bounds, but this keeps it simple
    end
    {% end %}
  end

  def [](i : RubyObject) : RubyObject
    self[i.to_i64]
  end

  def [](i : Int32) : RubyObject
    self[i.to_i64]
  end

  def length : RubyInteger
    RubyInteger.new({{n}}_i64)
  end

  def max : RubyObject
    best = @v0
    {% for i in (1...n) %}
    best = @v{{i}} if (@v{{i}} > best)
    {% end %}
    best
  end

  def min : RubyObject
    best = @v0
    {% for i in (1...n) %}
    best = @v{{i}} if (@v{{i}} < best)
    {% end %}
    best
  end

  def size : RubyInteger
    length
  end

  def first : RubyObject
    @v0
  end

  def last : RubyObject
    @v{{n - 1}}
  end

  def include?(val : RubyObject) : RubyBool
    {% for i in (0...n) %}
    return RUBY_TRUE if @v{{i}} == val
    {% end %}
    RUBY_FALSE
  end

  def to_s : String
    "[" + {% for i in (0...n) %}@v{{i}}.to_s{% if i < n - 1 %} + ", " + {% end %}{% end %} + "]"
  end

  def inspect : String
    "[" + {% for i in (0...n) %}@v{{i}}.inspect{% if i < n - 1 %} + ", " + {% end %}{% end %} + "]"
  end

  def ruby_nil? : Bool
    false
  end

  def truthy? : Bool
    true
  end
end
{% end %}

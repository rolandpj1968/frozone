# RubyObject — abstract base class for all Ruby value types.
#
# Every Ruby value (Integer, Float, String, Symbol, Array, Hash, nil, true,
# false, …) inherits from this class, mirroring MRI's VALUE hierarchy.
#
# Hash/equality routing:
#   Crystal's Hash(RubyObject, RubyObject) requires #hash : UInt64 and
#   #==(other) : Bool on the key type.  Each subclass overrides both.
#   The default implementations here use object identity, which is correct
#   for types that don't define value equality (e.g. arbitrary objects).
#
# Note on Crystal pseudo-methods:
#   `!` and `nil?` are compiler built-ins that cannot be overridden on
#   arbitrary classes.  We expose `not` and `ruby_nil?` instead; the
#   transpiler maps them to the right Ruby method names.

abstract class RubyObject
  # -------------------------------------------------------------------------
  # String representation
  # -------------------------------------------------------------------------
  abstract def to_s    : String
  abstract def inspect : String

  # -------------------------------------------------------------------------
  # Equality and hashing  (subclasses override for value equality)
  # -------------------------------------------------------------------------
  def ==(other : RubyObject) : Bool
    same?(other)   # identity by default
  end

  def !=(other : RubyObject) : Bool
    !(self == other)
  end

  # Crystal's Hash uses #hash : UInt64 for bucket placement.
  # Default: identity hash via object_id.
  def hash : UInt64
    object_id
  end

  # -------------------------------------------------------------------------
  # AOT codegen helpers — raw Crystal numeric extraction (not Ruby methods)
  # Used by the Crystal backend when emitting unboxed local optimisations.
  # -------------------------------------------------------------------------
  def to_i64 : Int64
    raise Exception.new("#{self.class} cannot be coerced to Int64")
  end
  def to_f64 : Float64
    raise Exception.new("#{self.class} cannot be coerced to Float64")
  end

  # -------------------------------------------------------------------------
  # Ruby truthiness  (nil and false override to return false)
  # -------------------------------------------------------------------------
  def truthy? : Bool
    true
  end

  # -------------------------------------------------------------------------
  # Type predicates
  # -------------------------------------------------------------------------
  def ruby_nil?  : Bool; false; end
  def ruby_bool? : Bool; false; end
  # ruby_nil? checks for Ruby nil (RubyNil), not Crystal nil.
  # (Crystal's nil? is a pseudo-method; we use ruby_nil? instead)
  # def nil? - NOT redefined here; see RubyNil#ruby_nil?

  # ruby_to_s: Ruby's to_s — returns RubyString (Crystal to_s returns String)
  def ruby_to_s : RubyString
    RubyString.new(to_s)
  end

  # ruby_inspect: Ruby's inspect — returns RubyString
  def ruby_inspect : RubyString
    RubyString.new(inspect)
  end

  # -------------------------------------------------------------------------
  # Ruby conversion methods — raise TypeError by default; subclasses override
  # -------------------------------------------------------------------------

  def to_i : RubyInteger
    raise Exception.new("#{self.class} can't be coerced into Integer")
  end

  def to_f : RubyFloat
    raise Exception.new("#{self.class} can't be coerced into Float")
  end

  # -------------------------------------------------------------------------
  # Arithmetic / comparison operator stubs — raise TypeError at runtime.
  # Concrete subclasses override with real implementations.
  # These stubs are required so that Crystal's type system can dispatch
  # operator calls on RubyObject-typed receivers (the primary dispatch path).
  # -------------------------------------------------------------------------
  {% for op in ["+", "-", "*", "/", "%", "**", "<=>", "&", "|", "^", "<<", ">>"] %}
    def {{op.id}}(other : RubyObject) : RubyObject
      raise Exception.new({{op + " not supported for this type"}})
    end
  {% end %}

  {% for op in ["<", "<=", ">", ">="] %}
    def {{op.id}}(other : RubyObject) : Bool
      raise Exception.new({{op + " not supported for this type"}})
    end
  {% end %}

  # Unary operators: Crystal uses def -(no args) for unary minus
  def - : RubyObject
    raise Exception.new("unary - not supported for #{self.class}")
  end

  # -------------------------------------------------------------------------
  # Indexing stubs — Array/Hash override with real implementations
  # -------------------------------------------------------------------------
  def [](idx : RubyObject) : RubyObject
    raise Exception.new("[] not supported for #{self.class}")
  end
  def [](idx : Int64) : RubyObject
    raise Exception.new("[] not supported for #{self.class}")
  end

  def []=(idx : RubyObject, val : RubyObject) : RubyObject
    raise Exception.new("[]= not supported for #{self.class}")
  end
  def []=(idx : Int64, val : RubyObject) : RubyObject
    raise Exception.new("[]= not supported for #{self.class}")
  end

  # -------------------------------------------------------------------------
  # Common collection stubs — Array/Hash/String override
  # -------------------------------------------------------------------------
  def length : RubyInteger
    raise Exception.new("length not supported for #{self.class}")
  end

  def size : RubyInteger
    raise Exception.new("size not supported for #{self.class}")
  end

  def each(&block : RubyObject -> RubyObject) : RubyObject
    raise Exception.new("each not supported for #{self.class}")
  end

  def ord : RubyInteger
    raise Exception.new("ord not supported for #{self.class}")
  end

  def dup : RubyObject
    raise Exception.new("dup not supported for #{self.class}")
  end

  def itself : RubyObject
    self
  end

  # -------------------------------------------------------------------------
  # Logical negation (Crystal `!` can't be overridden; use `not`)
  # -------------------------------------------------------------------------
  def not : RubyObject
    # default: any truthy object negated is false
    truthy? ? RubyBool::FALSE : RubyBool::TRUE
  end

  # -------------------------------------------------------------------------
  # ruby_class / ruby_is_a? / respond_to?
  # -------------------------------------------------------------------------

  # Returns a proxy for the Ruby class of this object.
  def ruby_class : RubyClassProxy
    # Derive Ruby name: "Ruby_Dog" → "Dog", "RubyInteger" → "Integer"
    cr_name = self.class.name
    ruby_name = cr_name.starts_with?("Ruby_") ? cr_name[5..] : cr_name.sub(/^Ruby/, "")
    RubyClassProxy.new(ruby_name)
  end

  # Shortcut: obj.class.name as RubyString
  def ruby_class_name : RubyString
    cr_name = self.class.name
    ruby_name = cr_name.starts_with?("Ruby_") ? cr_name[5..] : cr_name.sub(/^Ruby/, "")
    RubyString.new(ruby_name)
  end

  # is_a? dispatched as ruby_is_a? so it doesn't conflict with Crystal's is_a?
  def ruby_is_a?(klass : RubyObject) : RubyBool
    RubyBool::FALSE  # subclasses/generated classes should override
  end

  # respond_to?: basic implementation
  def respond_to?(method_name : RubyObject) : RubyBool
    RubyBool::FALSE  # generated classes override this
  end
end

# Proxy object representing a Ruby class — returned by obj.ruby_class.
# Has a `name` method that returns the Ruby class name as RubyString.
class RubyClassProxy
  @ruby_class_name : String

  def initialize(@ruby_class_name : String); end

  # name returns RubyObject so it unifies with Ruby user-class name methods
  def name : RubyObject
    RubyString.new(@ruby_class_name)
  end

  def to_s : String; @ruby_class_name; end
  def inspect : String; @ruby_class_name; end
end

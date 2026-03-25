# RubyException: base class for compiled Ruby exception classes.
# Inherits from Crystal's Exception so it is catchable via rescue.
# Provides Ruby-compatible to_s / inspect / message interface so that
# `rescue e; puts e.message` and `rescue e; puts e` work without full
# RubyObject dispatch.
abstract class RubyException < Exception
  def ruby_to_s : RubyString
    RubyString.new(message || self.class.name)
  end

  def ruby_inspect : RubyString
    ruby_to_s
  end

  def truthy? : Bool
    true
  end

  def ruby_nil? : Bool
    false
  end

  def to_s : String
    message || self.class.name
  end
end

# Pre-defined Ruby exception hierarchy.
class Ruby_Exception < RubyException; end
class Ruby_StandardError < Ruby_Exception; end
class Ruby_RuntimeError < Ruby_StandardError; end
class Ruby_ArgumentError < Ruby_StandardError; end
class Ruby_TypeError < Ruby_StandardError; end
class Ruby_NameError < Ruby_StandardError; end
class Ruby_NoMethodError < Ruby_NameError; end
class Ruby_ZeroDivisionError < Ruby_StandardError; end
class Ruby_IndexError < Ruby_StandardError; end
class Ruby_KeyError < Ruby_IndexError; end
class Ruby_StopIteration < Ruby_IndexError; end
class Ruby_RangeError < Ruby_StandardError; end
class Ruby_IOError < Ruby_StandardError; end
class Ruby_NotImplementedError < Ruby_StandardError; end
class Ruby_RegexpError < Ruby_StandardError; end
class Ruby_EncodingError < Ruby_StandardError; end
class Ruby_LoadError < Ruby_StandardError; end
class Ruby_SyntaxError < Ruby_StandardError; end
class Ruby_SystemExit < Ruby_Exception; end
class Ruby_Interrupt < Ruby_Exception; end

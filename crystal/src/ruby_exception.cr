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

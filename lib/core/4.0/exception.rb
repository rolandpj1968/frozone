class Exception
  def initialize(message = nil)
    @message = message
  end

  def message
    @message || self.class.to_s
  end

  def to_s = message.to_s

  def backtrace = []
  def backtrace_locations = []

  def self.exception(message = nil) = new(message)
  def exception(message = nil)
    message ? self.class.new(message) : self
  end
end

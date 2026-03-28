# Minimal mspec-compatible test harness for compiled specs.
#
# Provides describe/it/should with the same API as mspec but without
# instance_eval (blocks run in their lexical scope, which is fine for
# most specs since describe/it/should are Kernel-level methods).

$spec_pass = 0
$spec_fail = 0
$spec_errors = []

def describe(name, _msg = nil, &block)
  block.call
end

def it(name, &block)
  block.call
  $spec_pass += 1
rescue => e
  $spec_fail += 1
  $spec_errors << "FAIL: #{name}: #{e.message}"
end

def before(_scope = nil, &block)
  # TODO: store and call before each `it`
end

class SpecPositiveOperatorMatcher
  def initialize(actual)
    @actual = actual
  end

  def ==(expected)
    unless @actual == expected
      raise "expected #{expected.inspect}, got #{@actual.inspect}"
    end
  end

  def !=(expected)
    if @actual == expected
      raise "expected #{@actual.inspect} to not equal #{expected.inspect}"
    end
  end

  def <(expected)
    unless @actual < expected
      raise "expected #{@actual.inspect} < #{expected.inspect}"
    end
  end

  def <=(expected)
    unless @actual <= expected
      raise "expected #{@actual.inspect} <= #{expected.inspect}"
    end
  end

  def >(expected)
    unless @actual > expected
      raise "expected #{@actual.inspect} > #{expected.inspect}"
    end
  end

  def >=(expected)
    unless @actual >= expected
      raise "expected #{@actual.inspect} >= #{expected.inspect}"
    end
  end
end

class Object
  def should(matcher = nil)
    if matcher
      unless matcher.matches?(self)
        raise matcher.failure_message
      end
    else
      SpecPositiveOperatorMatcher.new(self)
    end
  end
end

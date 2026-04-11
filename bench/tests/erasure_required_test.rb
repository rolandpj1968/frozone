# Tests that REQUIRE module erasure to work correctly.
# These exercise patterns that break without flattening:
#
# 1. Inherited constant via :: on child class
# 2. Constant from superclass's included module (deep chain)
# 3. Module method using ivar on including class
# 4. Prepended module method with super
#
# Run:
#   bundle exec ruby frozone.rb bench/tests/erasure_required_test.rb           # may fail
#   bundle exec ruby frozone.rb --flatten bench/tests/erasure_required_test.rb  # should pass
#
# For AOT:
#   bundle exec ruby frozone.rb --aot bench/tests/erasure_required_test.rb
#   crystal build crystal/gen/erasure_required_test.cr -o crystal/erasure_required_test
#   crystal/erasure_required_test

# All definitions must be in the load phase (before any bare expressions).
# The AOT splitter classifies modules/classes/methods as load nodes.

# --- Test 1: Inherited constant via :: ---
module Defaults
  TIMEOUT = 30
  MAX_RETRIES = 3
end

class BaseClient
  include Defaults
end

class HttpClient < BaseClient
end

# --- Test 2: Deep chain constant resolution ---
module Protocols
  VERSION = "1.1"
end

module Networking
  include Protocols
end

class Server
  include Networking
end

class WebServer < Server
end

# --- Test 3: Module method using ivar ---
module Memoizable
  def memoized_result
    @_memo ||= expensive_compute
  end
end

class Calculator
  include Memoizable

  def expensive_compute
    6 * 7
  end
end

# --- Test 4: Prepend with super ---
module Validation
  def process(x)
    raise "invalid" if x < 0
    super
  end
end

class Processor
  prepend Validation

  def process(x)
    x * 2
  end
end

# --- Execute phase (all puts below) ---
puts HttpClient::TIMEOUT
puts HttpClient::MAX_RETRIES
puts WebServer::VERSION
c = Calculator.new
puts c.memoized_result
puts c.memoized_result
puts Processor.new.process(5)
begin
  Processor.new.process(-1)
  puts "BUG: should have raised"
rescue => e
  puts e.message
end

# --- Expected output ---
# 30
# 3
# 1.1
# 42
# 42
# 10
# invalid

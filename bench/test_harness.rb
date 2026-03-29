# Minimal mspec-compatible test harness for compiled specs.
#
# Provides the core mspec API (describe/it/should/should_not/before/after)
# without instance_eval or dynamic dispatch. Blocks run in lexical scope.
#
# Usage:
#   frozone --aot -r bench/test_harness.rb spec/ruby-spec/language/if_spec.rb

$spec_pass = 0
$spec_fail = 0
$spec_errors = []

# --- ScratchPad (mspec utility for capturing side effects) ---
# Uses a class (not module) so instance vars work in Crystal compilation.

class ScratchPad
  @@recorded = nil

  def self.record(value)
    @@recorded = value
  end

  def self.recorded
    @@recorded
  end

  def self.clear
    @@recorded = nil
  end

  def self.<<(value)
    @@recorded = [] if @@recorded.nil?
    @@recorded << value
  end
end

# --- describe/it ---
# Note: before/after hooks are stubs for now — they accept blocks but don't run them.
# This avoids Crystal type issues with global Proc arrays. Most language specs
# don't depend on before/after for correctness.

def before(_scope = nil, &block)
  # TODO: store and invoke before each `it`
end

def after(_scope = nil, &block)
  # TODO: store and invoke after each `it`
end

def describe(name, _opts = nil, &block)
  block.call
end

def it(name, &block)
  block.call
  $spec_pass += 1
rescue => e
  $spec_fail += 1
  $spec_errors << "FAIL: #{name}: #{e.message}"
end

# Stubs for mspec features we don't support yet
def it_behaves_like(*args); end
def context(name, &block); describe(name, &block); end

# --- should / should_not ---

class SpecPositiveOperatorMatcher
  def initialize(actual)
    @actual = actual
  end

  def ==(expected)
    raise "expected #{expected.inspect}, got #{@actual.inspect}" unless @actual == expected
    true
  end

  def !=(expected)
    raise "expected not #{expected.inspect}" if @actual == expected
    true
  end

  def <(expected)
    raise "expected #{@actual.inspect} < #{expected.inspect}" unless @actual < expected
  end

  def <=(expected)
    raise "expected #{@actual.inspect} <= #{expected.inspect}" unless @actual <= expected
  end

  def >(expected)
    raise "expected #{@actual.inspect} > #{expected.inspect}" unless @actual > expected
  end

  def >=(expected)
    raise "expected #{@actual.inspect} >= #{expected.inspect}" unless @actual >= expected
  end

  # Predicate matchers: value.should.zero?, value.should.nil?, etc.
  def zero?
    raise "expected #{@actual.inspect} to be zero" unless @actual.zero?
  end

  def nil?
    raise "expected #{@actual.inspect} to be nil" unless @actual.nil?
  end

  def empty?
    raise "expected #{@actual.inspect} to be empty" unless @actual.empty?
  end

  def frozen?
    raise "expected #{@actual.inspect} to be frozen" unless @actual.frozen?
  end

  def equal?(other)
    raise "expected #{@actual.inspect} to be equal to #{other.inspect}" unless @actual.equal?(other)
  end
end

class SpecNegativeOperatorMatcher
  def initialize(actual)
    @actual = actual
  end

  def ==(expected)
    raise "expected #{@actual.inspect} to not equal #{expected.inspect}" if @actual == expected
    true
  end

  def zero?
    raise "expected #{@actual.inspect} to not be zero" if @actual.zero?
  end

  def nil?
    raise "expected #{@actual.inspect} to not be nil" if @actual.nil?
  end

  def empty?
    raise "expected #{@actual.inspect} to not be empty" if @actual.empty?
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

  def should_not(matcher = nil)
    if matcher
      if matcher.matches?(self)
        raise matcher.negative_failure_message
      end
    else
      SpecNegativeOperatorMatcher.new(self)
    end
  end
end

# --- Stubs for version guards and platform checks ---
def ruby_version_is(*args); yield if block_given?; end
def platform_is(*args); yield if block_given?; end
def platform_is_not(*args); yield if block_given?; end
def guard(condition, &block); yield if block_given?; end
def guard_not(condition, &block); yield if block_given?; end
def with_feature(*args); yield if block_given?; end
def ruby_bug(*args); yield if block_given?; end

# Stub for CODE_LOADING_DIR (used by spec_helper)
CODE_LOADING_DIR = "." unless defined?(CODE_LOADING_DIR)

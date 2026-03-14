require 'mspec'
require 'mspec/runner/formatters/dotted'

# Patch SpecPositiveOperatorMatcher / SpecNegativeOperatorMatcher to support
# the `s.should.empty?` / `s.should.include?(x)` chained style used by newer
# ruby-spec tests.  mspec 1.9.1 omits method_missing, so we add it here.
class SpecPositiveOperatorMatcher
  # mspec 1.9.1 lacks !=, so `x.should != y` silently checks equality (bug).
  # Define != to properly check that @actual != expected.
  def !=(expected)
    if @actual == expected
      SpecExpectation.fail_with("Expected #{@actual.inspect}", "not to equal #{expected.inspect}")
    end
  end

  def method_missing(name, *args, &block)
    result = @actual.__send__(name, *args, &block)
    unless result
      SpecExpectation.fail_with("Expected #{@actual.inspect}", "to be #{name}")
    end
    result
  end

  def respond_to_missing?(name, include_private = false)
    @actual.respond_to?(name, include_private)
  end
end

class SpecNegativeOperatorMatcher
  def method_missing(name, *args, &block)
    result = @actual.__send__(name, *args, &block)
    if result
      SpecExpectation.fail_with("Expected #{@actual.inspect}", "not to be #{name}")
    end
    result
  end

  def respond_to_missing?(name, include_private = false)
    @actual.respond_to?(name, include_private)
  end
end

# Extend ComplainMatcher and complain() to support verbose: keyword (mspec 1.9.1 lacks it).
class ComplainMatcher
  def initialize(complaint, verbose: nil)
    @complaint = complaint
    @verbose = verbose
  end

  def matches?(proc)
    @saved_err = $stderr
    @stderr = $stderr = IOStub.new
    @saved_verbose = $VERBOSE
    $VERBOSE = @verbose.nil? ? false : @verbose

    proc.call

    unless @complaint.nil?
      case @complaint
      when Regexp
        return false unless $stderr =~ @complaint
      else
        return false unless $stderr == @complaint
      end
    end

    return $stderr.empty? ? false : true
  ensure
    $VERBOSE = @saved_verbose
    $stderr = @saved_err
  end
end

# guard -> { condition } do ... end — run block only when condition is true.
# This is a newer mspec feature missing from 1.9.1.
class Object
  def guard(condition, &block)
    block.call if condition.call
  end

  def complain(complaint = nil, verbose: nil)
    ComplainMatcher.new(complaint, verbose: verbose)
  end

  # Override ruby_version_is to handle no-block usage (ternary context).
  # mspec 1.9.1 always yields, but tests sometimes use it without a block.
  def ruby_version_is(*args)
    g = VersionGuard.new(*args)
    begin
      g.name = :ruby_version_is
      if block_given?
        yield if g.yield?
      else
        g.yield?
      end
    ensure
      g.unregister
    end
  end

  # raise_consistent_error — mspec 1.9.1 lacks this; delegate to raise_error.
  def raise_consistent_error(exception = Exception, message = nil, &block)
    raise_error(exception, message, &block)
  end

  # Override ruby_cmd to use single-quoting so shell does not expand $variables
  # in code snippets (mspec 1.9.1 uses code.inspect → double-quoted, breaks $a, $b, etc.)
  # Unset bundler env vars so subprocesses don't load bundler (which causes spurious warnings).
  CLEAR_BUNDLER_ENV = "env RUBYOPT= BUNDLE_GEMFILE= BUNDLE_BIN_PATH= RUBYLIB="

  def ruby_cmd(code, opts = {})
    body = code
    if code && !File.exist?(code)
      safe = code.gsub("'", "'\\\\''")
      body = "-e '#{safe}'"
    end
    [CLEAR_BUNDLER_ENV, RUBY_EXE, ENV['RUBY_FLAGS'], opts[:options], body, opts[:args]].compact.join(' ')
  end
end

VersionGuard::FULL_RUBY_VERSION = SpecVersion.new(RUBY_VERSION)
ENV['MSPEC_RUNNER'] = '1'
MSpec.instance_variable_set(:@env, Object.new.extend(MSpec))
class MSpecScript
  def self.config = { backtrace_filter: /mspec/ }
end

formatter = DottedFormatter.new
formatter.register
MSpec.actions(:start)

spec_dir = File.expand_path(ENV.fetch('RUBY_SPEC_DIR', '../../spec/ruby-spec'), __dir__)
specs = ARGV.empty? ? Dir["#{spec_dir}/language/*_spec.rb"].sort : ARGV

specs.each do |f|
  begin
    require_relative f
  rescue Exception => e
    puts "LOAD_ERROR #{File.basename(f)}: #{e.class}: #{e.message.to_s[0, 120]}"
  end
end

puts "SPECS_DONE"
MSpec.actions(:finish)
puts "FINISH_DONE"

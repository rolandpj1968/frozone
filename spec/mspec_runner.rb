require 'mspec'
require 'mspec/runner/formatters/dotted'

# Add max_long/min_long helpers not present in mspec 1.9.1 (platform C long limits)
class Object
  def max_long
    require 'rbconfig/sizeof'
    2 ** (RbConfig::SIZEOF['long'] * 8 - 1) - 1
  rescue LoadError
    2**63 - 1  # default to 64-bit
  end

  def min_long
    require 'rbconfig/sizeof'
    -(2 ** (RbConfig::SIZEOF['long'] * 8 - 1))
  rescue LoadError
    -(2**63)
  end
end

# Patch PlatformGuard to support :pointer_size option (mspec 1.9.1 only handles :wordsize)
class PlatformGuard
  alias_method :match_without_pointer_size?, :match?

  def match?
    result = match_without_pointer_size?
    # Handle :pointer_size option not in mspec 1.9.1
    if @options.key?(:pointer_size)
      pointer_bits = 8 * 1.size  # Size of a Ruby Integer pointer (8 on 64-bit)
      result &&= (@options[:pointer_size] == pointer_bits)
    end
    result
  end
end

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

  # mspec 1.9.1 lacks ===, so `x.should === y` falls through to Object#=== → ==
  # which triggers SpecPositiveOperatorMatcher#== (checks @actual == expected).
  # Define === to correctly check @actual === expected.
  def ===(expected)
    unless @actual === expected
      SpecExpectation.fail_with("Expected #{@actual.inspect}", "to equal #{expected.inspect}")
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

# Patch PlatformGuard to handle c_long_size (not in mspec 1.9.1)
class PlatformGuard
  alias match_without_c_long_size? match?

  def match?
    result = match_without_c_long_size?
    if result && @options.key?(:c_long_size)
      result &&= (@options[:c_long_size] == 8 * 1.size)
    end
    result
  end
end

# guard -> { condition } do ... end — run block only when condition is true.
# This is a newer mspec feature missing from 1.9.1.
class Object
  def guard(condition, &block)
    block.call if condition.call
  end

  # suppress_warning — run block with $VERBOSE = nil to suppress warnings.
  # mspec 1.9.1 lacks this helper.
  def suppress_warning
    saved = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = saved
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
  CLEAR_BUNDLER_ENV = "env -u BUNDLER_SETUP RUBYOPT= BUNDLE_GEMFILE= BUNDLE_BIN_PATH= RUBYLIB= BUNDLER_VERSION="

  def ruby_cmd(code, opts = {})
    body = code
    if code && !File.exist?(code)
      safe = code.gsub("'", "'\\\\''")
      body = "-e '#{safe}'"
    end
    [CLEAR_BUNDLER_ENV, RUBY_EXE, ENV['RUBY_FLAGS'], opts[:options], body, opts[:args]].compact.join(' ')
  end

  # ruby_exe with no args returns the RUBY_EXE path (used for IO.popen([*ruby_exe, ...]) pattern).
  # ruby_exe(nil, opts) with opts runs ruby from stdin/file (code=nil = no -e or file arg).
  def ruby_exe(code = nil, opts = {})
    return RUBY_EXE if code.nil? && opts.empty?
    `#{ruby_cmd(code, opts)}`
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
  # Reset @env per file (mirroring real mspec's MSpec.files behavior) so that
  # singleton methods defined on @env inside one spec's `it` blocks don't
  # contaminate later spec files.
  MSpec.instance_variable_set(:@env, Object.new.extend(MSpec))
  begin
    require_relative f
  rescue Exception => e
    puts "LOAD_ERROR #{File.basename(f)}: #{e.class}: #{e.message.to_s[0, 120]}"
  end
end

puts "SPECS_DONE"
MSpec.actions(:finish)
puts "FINISH_DONE"

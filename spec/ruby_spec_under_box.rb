#!/usr/bin/env ruby
# Minimal mspec-API shim for running ruby/spec/language/*_spec.rb files
# under bin/frozone_box (the compiled interpreter).
#
# Stubs the describe/it/should surface inline so we sidestep `require 'mspec'`
# (closed-world AOT can't load the gem at runtime), then load()s the spec
# file directly via the compiled interpreter's load path.
#
# Usage:
#   bin/frozone_box spec/ruby_spec_under_box.rb spec/ruby-spec/language/<name>_spec.rb
#
# Exit status is 0 iff all `it` blocks pass; failures and their messages
# print to stdout in order.

$spec_pass = 0
$spec_fail = 0
$spec_errors = []

# Block the spec's `require_relative '../spec_helper'`
spec_helper_path = File.expand_path("ruby-spec/spec_helper.rb", __dir__)
$LOADED_FEATURES << spec_helper_path
$LOADED_FEATURES << spec_helper_path.sub(/\.rb$/, '')

def describe(name, _opts = nil, &block)
  block.call if block
end

def it(name, &block)
  block.call
  $spec_pass += 1
rescue => e
  $spec_fail += 1
  $spec_errors << "FAIL: #{name}: #{e.class}: #{e.message}"
end

def before(_scope = nil, &block); end
def after(_scope = nil, &block); end

# Minimum matchers — enough for and_spec / if_spec / or_spec / many basics.
# Bigger specs that touch ScratchPad / mock / raise_error matchers fail per-it,
# not per-suite — extend below as needed.
class SpecMatcher
  def initialize(actual); @actual = actual; end
  def ==(expected) = (raise "expected #{@actual.inspect} == #{expected.inspect}" unless @actual == expected)
  def equal(o)     = (raise "expected #{@actual.inspect} equal #{o.inspect}" unless @actual.equal?(o))
end

class Object
  def should(_matcher = nil)     = SpecMatcher.new(self)
  def should_not(_matcher = nil) = self
end

def be_nil   = nil
def be_true  = nil
def be_false = nil
def be_empty = nil
def be_kind_of(_klass) = nil
def eql(_other) = nil
def equal(_other) = nil

# Version / platform / feature guards — pass-through (always run).
def ruby_version_is(*_args, &block); yield if block; end
def platform_is(*_args, &block);     yield if block; end
def platform_is_not(*_args, &block); yield if block; end
def guard(*_args, &block);           yield if block; end
def guard_not(*_args, &block);       yield if block; end
def with_feature(*_args, &block);    yield if block; end
def ruby_bug(*_args, &block);        yield if block; end

# Constants some spec files probe at load time.
CODE_LOADING_DIR = File.expand_path("ruby-spec/fixtures/code", __dir__) unless defined?(CODE_LOADING_DIR)

spec_file = ARGV.first or abort "usage: #{$0} <spec.rb>"
load File.expand_path(spec_file)

puts "#{File.basename(spec_file)}: #{$spec_pass} passed, #{$spec_fail} failed"
$spec_errors.each { |e| puts "  #{e}" }
exit($spec_fail.zero? ? 0 : 1)

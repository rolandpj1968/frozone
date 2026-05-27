#!/usr/bin/env ruby
# Box-first intrinsic coverage report.
#
# Denominator = every `Intrinsics.<name>` call in the compiled Ruby
# surface (lib/core/4.0). That's the set of intrinsics reachable from
# compiled code — what must be lowered to fully support core (and what
# the universe.rb hand-coded methods delegate to under the single-source
# model). NOT the ~857 Ruby-side intrinsic names (most are interpreter-
# internal / membrane and never called from core).
#
# lowered = IntrinsicLowering::TEMPLATES ∪ HPP_INTRINSICS (the single
# lowering entry point — from_intrinsic_call → IntrinsicLowering.lower).
#
# Usage: ruby scripts/intrinsic_coverage.rb [--gap] [--prefix=str]

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'set'
require 'frozone/compiler/backend/cpp_box/cpp'

IL = Frozone::Compiler::Backend::CppBox::IntrinsicLowering
lowered = (IL::TEMPLATES.keys.map(&:to_s) + IL::HPP_INTRINSICS.map(&:to_s)).to_set

core_glob = File.expand_path('../lib/core/4.0/**/*.rb', __dir__)
calls = Hash.new { |h, k| h[k] = 0 }   # cpp-name => call-site count
Dir[core_glob].sort.each do |f|
  File.read(f).scan(/\bIntrinsics\.([a-z_][A-Za-z0-9_]*\??)/) do |(name)|
    cpp = name.end_with?('?') ? "#{name.chomp('?')}_q" : name
    calls[cpp] += 1
  end
end

reachable = calls.keys.to_set
gap = (reachable - lowered).to_a.sort
covered = (reachable & lowered).to_a

cat = ->(n) { n.split('_').first }
by_cat = gap.group_by(&cat)
reach_by_cat = reachable.group_by(&cat)

puts "=== Box-first intrinsic coverage (compiled core/4.0 surface) ==="
puts "reachable: #{reachable.size}   lowered: #{covered.size}   GAP: #{gap.size}"
puts
puts "By category  (reachable / gap):"
reach_by_cat.keys.sort_by { |c| -(by_cat[c]&.size || 0) }.each do |c|
  g = by_cat[c]&.size || 0
  next if g.zero? && !ARGV.include?('--all')
  printf "  %-12s %3d / %-3d\n", c, reach_by_cat[c].size, g
end

if ARGV.include?('--gap') || (pfx = ARGV.find { |a| a.start_with?('--prefix=') })
  filter = pfx ? pfx.split('=', 2).last : nil
  puts
  puts "Gap detail#{filter ? " (#{filter})" : ''}:"
  by_cat.sort_by { |c, ns| -ns.size }.each do |c, ns|
    next if filter && c != filter
    puts "  #{c} (#{ns.size}): #{ns.sort.join(', ')}"
  end
end

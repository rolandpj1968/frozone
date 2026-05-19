#!/usr/bin/env ruby
# Split cpp/runtime/intrinsics.hpp into per-category headers under
# cpp/runtime/intrinsics/. intrinsics.hpp becomes an aggregator that
# #includes all the per-category headers — keeps existing callers
# working unchanged. Per-TU include pruning is a separate follow-up.
#
# Usage: ruby tools/split_intrinsics.rb

require 'fileutils'

SRC = 'cpp/runtime/intrinsics.hpp'
DST_DIR = 'cpp/runtime/intrinsics'

CATEGORY_MERGE = {
  'basic'  => 'object',
  'match'  => 'regexp',
  'dbg'    => 'kernel',
  'symbol' => 'string',
  'array'  => 'string',
  'fiber'  => 'kernel',
}

def category_for(prefix)
  CATEGORY_MERGE.fetch(prefix, prefix)
end

src_lines = File.readlines(SRC)

# Walk line-by-line. State machine:
#  :pre        — before any intrinsic; collect into preamble.
#  :gap        — between functions; comments + helper namespaces.
#                Namespace blocks (`namespace X { ... }`) belong in
#                the aggregator's preamble (file-scope helpers like
#                `fs_detail` / `random_detail` that multiple categories
#                use); other gap content (comments) attaches to the
#                next intrinsic function.
#  :in_fn      — inside a multi-line function body; collect into the
#                current function block, exit when brace depth hits 0.
#  :in_ns      — inside a `namespace X { ... }` block; collect into
#                the aggregator preamble.
SIG_RE = /^(?:\[\[noreturn\]\] +)?inline +BasicObject\* +intrinsic_([a-z][a-z0-9]*)_/
NS_OPEN_RE = /^namespace [a-z_][a-z0-9_]* \{\s*$/

state = :pre
preamble = +''
ns_buf   = +''
gap_buf  = +''
cur_buf  = +''
cur_cat  = nil
depth    = 0

by_cat = Hash.new { |h, k| h[k] = +'' }

def brace_delta(line)
  # Count braces ignoring those inside // line comments and "string"/'char' literals.
  # Crude but works for this file.
  s = line.dup
  s.sub!(%r{//.*$}, '')   # drop line comments
  s.gsub!(/"(?:\\.|[^"\\])*"/, '')   # drop "..." strings
  s.gsub!(/'(?:\\.|[^'\\])*'/, '')   # drop '...' chars
  s.count('{') - s.count('}')
end

src_lines.each do |line|
  case state
  when :pre
    if line =~ SIG_RE
      cat = category_for($1)
      cur_cat = cat
      cur_buf = gap_buf + line
      gap_buf = +''
      depth = brace_delta(line)
      if depth.zero? && line.include?('{') && line.rstrip.end_with?('}')
        by_cat[cur_cat] << cur_buf
        cur_buf = +''
        cur_cat = nil
        state = :gap
      else
        state = :in_fn
      end
    elsif line =~ NS_OPEN_RE
      ns_buf = line
      depth = brace_delta(line)
      state = :in_ns
    elsif line.start_with?('#endif')
      break
    else
      preamble << line
    end
  when :gap
    if line =~ SIG_RE
      cat = category_for($1)
      cur_cat = cat
      cur_buf = gap_buf + line
      gap_buf = +''
      depth = brace_delta(line)
      if depth.zero? && line.include?('{') && line.rstrip.end_with?('}')
        by_cat[cur_cat] << cur_buf
        cur_buf = +''
        cur_cat = nil
      else
        state = :in_fn
      end
    elsif line =~ NS_OPEN_RE
      # Flush gap_buf as preamble content (comment headings above the
      # namespace logically belong to it).
      preamble << gap_buf
      gap_buf = +''
      ns_buf = line
      depth = brace_delta(line)
      state = :in_ns
    elsif line.start_with?('#endif')
      break
    else
      gap_buf << line
    end
  when :in_fn
    cur_buf << line
    depth += brace_delta(line)
    if depth.zero?
      by_cat[cur_cat] << cur_buf
      cur_buf = +''
      cur_cat = nil
      state = :gap
    end
  when :in_ns
    ns_buf << line
    depth += brace_delta(line)
    if depth.zero?
      preamble << ns_buf
      ns_buf = +''
      state = :gap
    end
  end
end

# Sanity check.
total_defs = by_cat.values.sum { |s| s.scan(SIG_RE).size }
unique_defs = by_cat.values.join.scan(SIG_RE).map(&:first).group_by(&:itself).transform_values(&:size)
puts "total intrinsic defs across split files: #{total_defs}"

# Helpers (namespaces like fs_detail) live in the preamble OR the
# gap_buf before the first function. Attach trailing gap (after last
# fn) is none. Preamble's helpers stay in intrinsics.hpp itself before
# the includes.

FileUtils.mkdir_p(DST_DIR)
by_cat.keys.sort.each do |cat|
  path = File.join(DST_DIR, "#{cat}_intrinsics.hpp")
  guard = "FROZONE_#{cat.upcase}_INTRINSICS_HPP"
  File.open(path, 'w') do |f|
    f.puts "// #{cat.capitalize}-category intrinsics — split from cpp/runtime/intrinsics.hpp."
    f.puts "// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper."
    f.puts
    f.puts "#ifndef #{guard}"
    f.puts "#define #{guard}"
    f.puts
    f.write(by_cat[cat])
    f.puts "#endif  // #{guard}"
  end
  fn_count = by_cat[cat].scan(SIG_RE).size
  puts "wrote #{path} (#{by_cat[cat].lines.size} lines, #{fn_count} fns)"
end

# Find namespace blocks in preamble — these are shared helpers (fs_detail
# etc.) that some categories depend on. Keep them in intrinsics.hpp so
# every aggregator-using TU still sees them.
File.open(SRC, 'w') do |f|
  f.write(preamble.rstrip)
  f.puts
  f.puts
  f.puts '// Aggregator — pulls all per-category intrinsic headers.'
  f.puts '// Per-TU include pruning is a follow-up (task #117 step B); for now'
  f.puts '// every TU still gets every category, but the file split lets that'
  f.puts '// change cleanly later. Helpers (namespaces, free functions) above'
  f.puts '// stay in this file so every per-category header can see them.'
  by_cat.keys.sort.each do |cat|
    f.puts %|#include "intrinsics/#{cat}_intrinsics.hpp"|
  end
  f.puts
  f.puts '#endif // FROZONE_INTRINSICS_HPP'
end
puts "rewrote #{SRC} as aggregator"

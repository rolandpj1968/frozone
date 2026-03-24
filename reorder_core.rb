#!/usr/bin/env ruby
# Reorders methods in core/4.0 Ruby files.
# Uses Ripper.lex for accurate token analysis.
#
# Within each class/module body section:
# - one-liner defs come first, then multi-line defs
# - private/public/protected keywords create separate sub-sections
# - alias stays immediately after the method it aliases
# - non-def lines are NOT moved
# - one blank line between multi-line methods; no blank lines between adjacent one-liners

require 'ripper'

CORE_DIR = File.join(__dir__, 'lib/core/4.0')

# Analyze a file using Ripper.lex to find:
# - Block boundaries (class/module/def start/end lines)
# - Whether each def is endless (one-liner) or regular (multi-line)
# - visibility markers (private/public/protected)
#
# Returns: {defs: [...], classes: [...], visibility_markers: [...]}
# Each def: {start_line:, end_line:, is_oneliner:}
# Each class: {start_line:, end_line:}
# Each visibility_marker: {line:, col:}
def analyze(content)
  tokens = Ripper.lex(content)

  # We'll scan through tokens tracking a "block stack"
  # Each stack entry: {keyword:, line:, is_endless: false}
  # When we see 'end', we pop the stack

  block_stack = []
  defs = []
  classes = []
  visibility_markers = []

  i = 0
  n = tokens.size

  while i < n
    pos, type, value, state = tokens[i]
    line, col = pos

    # Handle visibility markers (private/public/protected) - they're on_ident in Ripper
    if (type == :on_ident || type == :on_kw) && %w[private public protected].include?(value)
      is_standalone = true
      j = i + 1
      while j < n
        tpos, ttype, tval = tokens[j]
        break if tpos[0] > line
        case ttype
        when :on_sp; j += 1
        when :on_nl, :on_ignored_nl; break
        else; is_standalone = false; break
        end
      end
      visibility_markers << {line: line, col: col, standalone: is_standalone} if is_standalone
    end

    if type == :on_kw
      case value
      when 'class', 'module'
        # Check it's not `class << self` style - actually handle it the same way
        block_stack.push({keyword: value, line: line, col: col})

      when 'def'
        # Look ahead to determine if this is an endless def.
        # An endless def has `=` (not ==, !=, <=, >=) at paren_depth=0 after the method name+params.
        # We must be careful: `def foo(x = 1)` has `=` at paren_depth=1, not an endless marker.
        # `def foo(x) = body` has `=` at paren_depth=0.

        is_endless = false
        j = i + 1
        found_eq = false
        paren_depth = 0
        while j < n
          tpos, ttype, tval, tstate = tokens[j]
          tline = tpos[0]
          # Stop if we've gone past this line
          break if tline > line
          # Track paren depth
          case ttype
          when :on_lparen, :on_lbracket
            paren_depth += 1
          when :on_rparen, :on_rbracket
            paren_depth -= 1
          when :on_op
            if tval == '=' && paren_depth == 0 && tstate.to_s == 'BEG'
              found_eq = true
              break
            end
          when :on_nl, :on_ignored_nl
            break
          end
          j += 1
        end
        is_endless = found_eq

        if is_endless
          # Endless defs don't have an `end`, so record directly without pushing to stack
          defs << {
            start_line: line,
            end_line: line,
            is_oneliner: true
          }
        else
          block_stack.push({keyword: 'def', line: line, col: col, is_endless: false})
        end

      when 'do', 'begin', 'if', 'unless', 'case', 'while', 'until', 'for'
        # Only count these if they're in BEG state (not as modifiers)
        # Modifier if/unless/while/until appear in END state (after an expression)
        s = state.to_s
        if s == 'BEG' || s == 'FNAME'
          block_stack.push({keyword: value, line: line, col: col, is_endless: false})
        end
        # Special: `do` in middle of a line might be in various states
        # For `do`, it's a block opener when in BEG state after a method call
        # Actually, `do` used as a block opener is typically in :BEG state

      when 'end'
        unless block_stack.empty?
          opener = block_stack.pop
          end_line = line

          case opener[:keyword]
          when 'def'
            is_oneliner = opener[:is_endless] || opener[:line] == end_line
            defs << {
              start_line: opener[:line],
              end_line: end_line,
              is_oneliner: is_oneliner
            }
          when 'class', 'module'
            classes << {
              start_line: opener[:line],
              end_line: end_line
            }
          # Other keywords (if/unless/do/etc.) just pop without recording
          end
        end

      end
    end

    i += 1
  end

  {defs: defs, classes: classes, visibility_markers: visibility_markers}
end

# Reorder defs within a list of items.
# items: [{kind: :def/:other, ...}]
# One-liner defs first, then multi-line defs.
# :other items stay in place (non-def lines).
def reorder_items(items)
  output = []
  i = 0
  m = items.size

  while i < m
    item = items[i]

    if item[:kind] == :def
      # Collect def group: consecutive defs with only blank-line :other items between them
      group = [item]
      i += 1
      while i < m
        it = items[i]
        if it[:kind] == :def
          group << it
          i += 1
        elsif it[:kind] == :other && it[:lines].all? { |l| l.strip.empty? }
          # Blank line - skip it
          i += 1
        else
          break
        end
      end

      # Reorder: one-liners first, then multi-liners
      oneliners  = group.select { |it| it[:is_oneliner] }
      multiliners = group.select { |it| !it[:is_oneliner] }

      # Emit one-liners (no blank lines between)
      oneliners.each do |it|
        output.concat(it[:lines])
        output.concat(it[:alias_lines] || [])
      end

      # Blank line between one-liner block and multi-liner block
      output << "\n" if oneliners.any? && multiliners.any?

      # Emit multi-liners with blank line between each
      multiliners.each_with_index do |it, idx|
        output << "\n" if idx > 0
        output.concat(it[:lines])
        output.concat(it[:alias_lines] || [])
      end
    else
      output.concat(item[:lines])
      i += 1
    end
  end

  output
end

# Process the body of a class/module.
# body_lines: array of lines in the body (0-indexed, without the class/end header lines)
# body_line_start: 1-based line number of body_lines[0] in the original file
# info: result of analyze() for the whole file
def process_body(body_lines, body_line_start, info)
  return body_lines if body_lines.empty?

  n = body_lines.size
  body_line_end = body_line_start + n - 1  # 1-based

  # Find defs directly in this body (not in nested classes)
  # A def is "directly in this body" if no nested class contains it
  nested_classes = info[:classes].select do |c|
    c[:start_line] >= body_line_start && c[:end_line] <= body_line_end
  end

  nested_line_set = {}
  nested_classes.each do |c|
    (c[:start_line]..c[:end_line]).each { |l| nested_line_set[l] = true }
  end

  direct_defs = info[:defs].select do |d|
    d[:start_line] >= body_line_start &&
    d[:end_line]   <= body_line_end   &&
    !nested_line_set[d[:start_line]]
  end

  # Find standalone visibility markers in this body (not in nested classes)
  direct_markers = info[:visibility_markers].select do |vm|
    vm[:line] >= body_line_start &&
    vm[:line] <= body_line_end   &&
    !nested_line_set[vm[:line]]
  end

  # Split body by visibility markers into sections
  # Each section: lines before next marker
  section_ranges = []
  sorted_markers = direct_markers.sort_by { |vm| vm[:line] }

  prev_start = body_line_start
  sorted_markers.each do |vm|
    # Section before marker
    if vm[:line] > prev_start
      section_ranges << {start: prev_start, end_: vm[:line] - 1, marker: false}
    end
    # The marker line itself
    section_ranges << {start: vm[:line], end_: vm[:line], marker: true}
    prev_start = vm[:line] + 1
  end
  # Last section
  if prev_start <= body_line_end
    section_ranges << {start: prev_start, end_: body_line_end, marker: false}
  end

  output = []

  section_ranges.each do |sec|
    if sec[:marker]
      output << body_lines[sec[:start] - body_line_start]
      next
    end

    sec_start = sec[:start]
    sec_end   = sec[:end_]
    sec_lines = body_lines[(sec_start - body_line_start)..(sec_end - body_line_start)]
    next if sec_lines.nil? || sec_lines.empty?

    # Defs in this section
    sec_defs = direct_defs.select { |d| d[:start_line] >= sec_start && d[:end_line] <= sec_end }

    # Nested classes in this section
    sec_classes = nested_classes.select { |c| c[:start_line] >= sec_start && c[:end_line] <= sec_end }

    if sec_classes.any?
      # Process section with nested classes: don't reorder across class boundaries
      processed = process_section_with_nested_classes(sec_lines, sec_start, sec_defs, sec_classes, nested_line_set, info)
      output.concat(processed)
    else
      # Simple section: parse into items and reorder
      items = build_items(sec_lines, sec_start, sec_defs, nested_line_set, info)
      output.concat(reorder_items(items))
    end
  end

  output
end

def process_section_with_nested_classes(sec_lines, sec_start, sec_defs, sec_classes, nested_line_set, info)
  n = sec_lines.size
  sec_end = sec_start + n - 1
  output = []

  # Only process "direct" nested classes - those not contained within another class in this list
  direct_classes = sec_classes.select do |c|
    !sec_classes.any? { |other|
      other.object_id != c.object_id &&
      other[:start_line] < c[:start_line] &&
      other[:end_line] > c[:end_line]
    }
  end

  # Sort direct nested classes by start line
  sorted_classes = direct_classes.sort_by { |c| c[:start_line] }

  prev_rel = 0  # 0-based index into sec_lines
  sorted_classes.each do |c|
    class_start_rel = c[:start_line] - sec_start
    class_end_rel   = c[:end_line]   - sec_start

    # Process lines before this nested class
    if prev_rel < class_start_rel
      pre_lines = sec_lines[prev_rel...class_start_rel]
      pre_start = sec_start + prev_rel
      pre_defs = sec_defs.select { |d| d[:start_line] >= pre_start && d[:end_line] < c[:start_line] && !nested_line_set[d[:start_line]] }
      items = build_items(pre_lines, pre_start, pre_defs, nested_line_set, info)
      output.concat(reorder_items(items))
    end

    # Process the nested class
    if class_start_rel == class_end_rel
      # Single-line class/module (e.g., "module Foo; end")
      output << sec_lines[class_start_rel]
    else
      # Multi-line class/module
      # Header line
      output << sec_lines[class_start_rel]

      # Body
      if class_end_rel > class_start_rel + 1
        inner_start = c[:start_line] + 1
        inner_end   = c[:end_line] - 1
        inner_lines = sec_lines[(class_start_rel+1)..(class_end_rel-1)]
        inner_processed = process_body(inner_lines, inner_start, info)
        output.concat(inner_processed)
      end

      # Closing end
      output << sec_lines[class_end_rel]
    end

    prev_rel = class_end_rel + 1
  end

  # Lines after all nested classes
  if prev_rel < n
    post_lines = sec_lines[prev_rel..]
    post_start = sec_start + prev_rel
    post_defs = sec_defs.select { |d| d[:start_line] >= post_start && !nested_line_set[d[:start_line]] }
    items = build_items(post_lines, post_start, post_defs, nested_line_set, info)
    output.concat(reorder_items(items))
  end

  output
end

# Build items array from sec_lines for reordering
# Each item: {kind: :def/:other, lines: [...], is_oneliner: bool, alias_lines: [...]}
def build_items(sec_lines, sec_start, sec_defs, nested_line_set, info)
  n = sec_lines.size
  sec_end = sec_start + n - 1

  # Build a map from line number to def index
  line_to_def = {}
  sec_defs.each_with_index do |d, di|
    (d[:start_line]..d[:end_line]).each { |l| line_to_def[l] = di }
  end

  items = []
  i = 0
  while i < n
    lno = sec_start + i  # 1-based

    if line_to_def.key?(lno)
      di = line_to_def[lno]
      d = sec_defs[di]

      # Collect def lines
      def_start_rel = d[:start_line] - sec_start
      def_end_rel   = d[:end_line]   - sec_start
      def_lines = sec_lines[def_start_rel..def_end_rel]

      # Look for alias lines immediately after
      alias_lines = []
      j = def_end_rel + 1
      while j < n && sec_lines[j].strip =~ /\Aalias\b/
        alias_lines << sec_lines[j]
        j += 1
      end

      items << {
        kind: :def,
        lines: def_lines,
        is_oneliner: d[:is_oneliner],
        alias_lines: alias_lines
      }

      i = j  # Skip past alias lines
    else
      items << {kind: :other, lines: [sec_lines[i]]}
      i += 1
    end
  end

  items
end

# Process an entire file
def process_file(content)
  info = analyze(content)

  # Find top-level class/module blocks
  top_level_classes = info[:classes].select do |c|
    !info[:classes].any? { |other|
      other.object_id != c.object_id &&
      other[:start_line] < c[:start_line] &&
      other[:end_line]   > c[:end_line]
    }
  end

  lines = content.lines
  output_lines = lines.dup

  # Process in reverse order so line indices don't shift
  top_level_classes.sort_by { |c| -c[:start_line] }.each do |c|
    body_start = c[:start_line] + 1
    body_end   = c[:end_line] - 1
    next if body_start > body_end

    body_lines = output_lines[(body_start-1)..(body_end-1)]
    processed = process_body(body_lines, body_start, info)

    output_lines[(body_start-1)..(body_end-1)] = processed
  end

  output_lines.join
end

# Verify file content is syntactically OK using Ripper's lex error detection
def syntax_ok_via_ripper?(content)
  # Ripper.lex doesn't report errors; use a different check
  # We can check if block_stack is balanced after processing
  info = analyze(content)
  # If any class has negative span, something is wrong
  info[:classes].all? { |c| c[:end_line] >= c[:start_line] } &&
  info[:defs].all? { |d| d[:end_line] >= d[:start_line] }
end

# Main
Dir.glob(File.join(CORE_DIR, '**/*.rb')).sort.each do |file|
  rel = file.sub(CORE_DIR + '/', '')
  puts "Processing: #{rel}"
  content = File.read(file)

  begin
    new_content = process_file(content)

    if new_content != content
      # Sanity check: no lines should have been lost (count non-blank lines)
      orig_nonblank = content.lines.count { |l| !l.strip.empty? }
      new_nonblank  = new_content.lines.count { |l| !l.strip.empty? }
      if orig_nonblank != new_nonblank
        puts "  -> WARNING: non-blank line count changed (#{orig_nonblank} -> #{new_nonblank}), skipping"
        next
      end
      File.write(file, new_content)
      puts "  -> Modified"
    else
      puts "  -> Unchanged"
    end
  rescue => e
    puts "  -> ERROR: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
end

puts "\nDone!"

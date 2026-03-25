#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates src/encoding/single_byte_tables.cr from MRI Ruby enc/trans/*-tbl.rb files.
# Run from the repo root: ruby tool/gen_crystal_tables.rb

REPO_ROOT = File.expand_path('..', __dir__)
TRANS_DIR = File.join(REPO_ROOT, 'enc', 'trans')
OUT_FILE  = File.join(REPO_ROOT, 'src', 'encoding', 'single_byte_tables.cr')

# All single-byte encodings to process (from single_byte.trans)
ENCODINGS = %w[
  ISO-8859-1
  ISO-8859-2
  ISO-8859-3
  ISO-8859-4
  ISO-8859-5
  ISO-8859-6
  ISO-8859-7
  ISO-8859-8
  ISO-8859-9
  ISO-8859-10
  ISO-8859-11
  ISO-8859-13
  ISO-8859-14
  ISO-8859-15
  ISO-8859-16
  WINDOWS-874
  WINDOWS-1250
  WINDOWS-1251
  WINDOWS-1252
  WINDOWS-1253
  WINDOWS-1254
  WINDOWS-1255
  WINDOWS-1256
  WINDOWS-1257
  IBM437
  IBM720
  IBM737
  IBM775
  IBM852
  IBM855
  IBM857
  IBM860
  IBM861
  IBM862
  IBM863
  IBM864
  IBM865
  IBM866
  IBM869
  MACCROATIAN
  MACCYRILLIC
  MACGREEK
  MACICELAND
  MACROMAN
  MACROMANIA
  MACTURKISH
  MACUKRAINE
  KOI8-U
  KOI8-R
  TIS-620
  CP850
  CP852
  CP855
].freeze

# Mangle encoding name to Crystal constant name suffix
# e.g. "ISO-8859-1" -> "ISO_8859_1", "KOI8-U" -> "KOI8_U"
def mangle_name(enc_name)
  enc_name.gsub('-', '_').upcase
end

# Load the -tbl.rb file for the given encoding and return the raw mapping array.
# Returns array of [hex_string, codepoint] pairs.
def load_table(enc_name)
  tbl_name  = enc_name.downcase + '-tbl.rb'
  tbl_path  = File.join(TRANS_DIR, tbl_name)
  unless File.exist?(tbl_path)
    warn "WARNING: table file not found: #{tbl_path}"
    return []
  end
  # Evaluate the file to get the constant defined therein.
  eval(File.read(tbl_path), binding, tbl_path) # rubocop:disable Security/Eval
  const_name = mangle_name(enc_name) + '_TO_UCS_TBL'
  Object.const_get(const_name)
rescue StandardError => e
  warn "WARNING: failed to load #{tbl_path}: #{e}"
  []
end

# Build a 256-element forward table (byte -> codepoint, -1 = invalid).
# Bytes 0x00-0x7F are identity-mapped (ASCII).
# For ISO-8859-* encodings, the C1 control range 0x80-0x9F is also identity-mapped.
def build_forward_table(enc_name, raw_entries)
  table = Array.new(256, -1)

  # ASCII identity map
  (0x00..0x7F).each { |b| table[b] = b }

  # For ISO-8859-* encodings, add C1 control codes (0x80-0x9F identity)
  if enc_name.start_with?('ISO-8859')
    (0x80..0x9F).each { |b| table[b] = b }
  end

  # Apply entries from the table file (only 2-char hex keys = single byte)
  raw_entries.each do |hex_str, codepoint|
    next unless hex_str.length == 2
    byte = hex_str.to_i(16)
    table[byte] = codepoint
  end

  table
end

# Build a sorted reverse table: array of {codepoint, byte} pairs for codepoints > 0x7F.
# We skip ASCII (0x00-0x7F) since those are identity and handled separately.
def build_reverse_table(forward_table)
  pairs = []
  forward_table.each_with_index do |codepoint, byte|
    next if codepoint < 0    # invalid
    next if codepoint <= 0x7F # ASCII identity, skip
    pairs << [codepoint, byte]
  end
  # Sort by codepoint for binary search
  pairs.sort_by { |cp, _b| cp }
end

# Format a StaticArray literal for the forward table
def format_forward_table(table, enc_name)
  const_name = "BYTE_TO_UCS_#{mangle_name(enc_name)}"
  lines = ["  #{const_name} = StaticArray(Int32, 256).new { |i|"]
  lines << "    case i"
  # Group consecutive identity-mapped ranges for compactness
  # Emit individual entries grouped by value
  # Build groups of (value -> [bytes])
  by_value = Hash.new { |h, k| h[k] = [] }
  table.each_with_index { |v, i| by_value[v] << i }

  # Emit -1 as else clause, everything else as when clauses
  # But we want compactness: emit ranges where possible
  entries = table.each_with_index.map { |v, i| [i, v] }.reject { |_i, v| v == -1 }
  # Sort by byte for determinism
  entries.sort_by! { |i, _v| i }

  # Group consecutive bytes with consecutive codepoints as ranges
  groups = []
  entries.each do |byte, cp|
    if groups.empty? ||
       byte != groups.last[:end_byte] + 1 ||
       cp != groups.last[:end_cp] + 1
      groups << { start_byte: byte, end_byte: byte, start_cp: cp, end_cp: cp }
    else
      groups.last[:end_byte] = byte
      groups.last[:end_cp]   = cp
    end
  end

  groups.each do |g|
    sb  = g[:start_byte]
    eb  = g[:end_byte]
    scp = g[:start_cp]
    if sb == eb
      lines << "    when 0x#{sb.to_s(16).upcase.rjust(2, '0')} then 0x#{scp.to_s(16).upcase}"
    else
      offset = scp - sb
      if offset >= 0
        lines << "    when 0x#{sb.to_s(16).upcase.rjust(2, '0')}..0x#{eb.to_s(16).upcase.rjust(2, '0')} then i + 0x#{offset.to_s(16).upcase}"
      else
        lines << "    when 0x#{sb.to_s(16).upcase.rjust(2, '0')}..0x#{eb.to_s(16).upcase.rjust(2, '0')} then i - 0x#{(-offset).to_s(16).upcase}"
      end
    end
  end

  lines << "    else -1"
  lines << "    end"
  lines << "  }"
  lines.join("\n")
end

# Format the reverse table as an Array of Tuple literal
def format_reverse_table(pairs, enc_name)
  const_name = "UCS_TO_BYTE_#{mangle_name(enc_name)}"
  if pairs.empty?
    return "  #{const_name} = [] of {Int32, UInt8}"
  end

  lines = ["  #{const_name} = ["]
  pairs.each do |cp, byte|
    lines << "    {0x#{cp.to_s(16).upcase}, 0x#{byte.to_s(16).upcase.rjust(2, '0')}_u8},"
  end
  lines << "  ]"
  lines.join("\n")
end

# Ensure output directory exists
Dir.mkdir(File.join(REPO_ROOT, 'src', 'encoding')) unless Dir.exist?(File.join(REPO_ROOT, 'src', 'encoding'))

puts "Generating #{OUT_FILE}..."

File.open(OUT_FILE, 'w') do |f|
  f.puts <<~HEADER
    # GENERATED FILE — do not edit by hand.
    # Run `ruby tool/gen_crystal_tables.rb` to regenerate.
    # Source: MRI Ruby enc/trans/*-tbl.rb (BSD 2-Clause License, Copyright Yukihiro Matsumoto)

    module Encoding
      module SingleByte
  HEADER

  ENCODINGS.each do |enc_name|
    raw_entries   = load_table(enc_name)
    forward_table = build_forward_table(enc_name, raw_entries)
    reverse_pairs = build_reverse_table(forward_table)

    f.puts
    f.puts "    # #{enc_name}"
    f.puts format_forward_table(forward_table, enc_name).gsub(/^/, '    ')
    f.puts
    f.puts format_reverse_table(reverse_pairs, enc_name).gsub(/^/, '    ')
  end

  f.puts
  f.puts "  end"
  f.puts "end"
end

puts "Done. Generated #{ENCODINGS.size} encodings."

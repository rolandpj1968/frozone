#!/usr/bin/env ruby
# frozen_string_literal: true

# Frozone Crystal compiler entry point.
#
# Usage:
#   ruby compile.rb input.rb               # writes input.cr
#   ruby compile.rb input.rb -o output.cr  # explicit output path
#   ruby compile.rb input.rb --run         # compile + crystal build + run
#   ruby compile.rb input.rb --emit        # print Crystal source to stdout

$LOAD_PATH.unshift File.join(__dir__, 'lib')

require 'frozone/vm/parser'
require 'frozone/compiler/crystal_codegen'

def usage
  warn "Usage: ruby compile.rb <input.rb> [-o output.cr] [--run] [--emit]"
  exit 1
end

# --- Parse arguments ---------------------------------------------------------

input_file  = nil
output_file = nil
run_after   = false
emit_only   = false
bench_mode  = false

args = ARGV.dup
until args.empty?
  arg = args.shift
  case arg
  when '-o'        then output_file = args.shift or usage
  when '--run'     then run_after  = true
  when '--emit'    then emit_only  = true
  when '--bench'   then bench_mode = true; run_after = true
  else
    usage if arg.start_with?('-')
    input_file = arg
  end
end

usage unless input_file
unless File.exist?(input_file)
  warn "compile.rb: file not found: #{input_file}"
  exit 1
end

crystal_dir  = File.expand_path('crystal', __dir__)
basename     = File.basename(input_file, '.rb')
output_file  ||= File.join(crystal_dir, "#{basename}.cr")

# --- Parse -------------------------------------------------------------------

source = File.read(input_file)
parser = Frozone::Vm::Parser.new(source, filepath: input_file)

begin
  ast = parser.ast(raise_syntax_errors: true)
rescue => e
  warn "compile.rb: parse error in #{input_file}: #{e.message}"
  exit 1
end

# --- Generate ----------------------------------------------------------------

codegen = Frozone::Compiler::CrystalCodegen.new
crystal_source = codegen.generate(ast)
crystal_source = crystal_source.sub('require "./src/frozone_crystal"',
  "require \"./src/frozone_crystal\"\nrequire \"./src/bench_harness\"") if bench_mode

unless codegen.errors.empty?
  warn "compile.rb: #{codegen.errors.size} unsupported node(s):"
  codegen.errors.each { |e| warn "  - #{e}" }
end

if emit_only
  print crystal_source
  exit codegen.errors.empty? ? 0 : 1
end

# --- Write output ------------------------------------------------------------

File.write(output_file, crystal_source)
puts "Wrote #{output_file}"

# --- Optionally build and run ------------------------------------------------

if run_after
  binary = output_file.sub(/\.cr$/, '')
  # Build from crystal/ dir so relative require "./src/frozone_crystal" resolves
  cmd = "cd #{crystal_dir} && crystal build #{output_file} -o #{binary}"
  puts "Building: #{cmd}"
  system(cmd) or exit 1
  puts "Running: #{binary}"
  exec binary
end

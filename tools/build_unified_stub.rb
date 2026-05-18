#!/usr/bin/env ruby
# Bundle multiple bench/stubs/*.rb files into one Ruby program that
# the AOT pipeline can build as a single binary. Each stub's code
# is wrapped in `module Stub_<name>` to namespace user classes;
# top-level `def foo` becomes `def self.foo` (a module method);
# top-level execute statements become `def self.run`'s body.
#
# Output stub: $LOADED_FEATURES + stub of run_benchmark, then for
# each stub:
#   module Stub_<name>
#     <classes and self.X method defs at module level>
#     def self.run
#       <execute statements>
#     end
#   end
# Trailer: prints `=== <name> ===` and calls `Stub_<name>.run` per stub.
#
# Usage: ruby tools/build_unified_stub.rb stub_a stub_b ... > out.rb
require 'prism'

STUBS = ARGV.dup
abort "usage: #{$0} stub1 stub2 ..." if STUBS.empty?

def inline_requires(stmts, src)
  # Replace any `require_relative '../benchmarks/<x>'` with the parsed
  # statements of bench/benchmarks/<x>.rb. The required files are
  # plain Ruby (no harness boilerplate), so we can splice them in.
  out = []
  stmts.each do |n|
    if n.is_a?(Prism::CallNode) && n.name == :require_relative && n.arguments&.arguments&.length == 1
      arg = n.arguments.arguments.first
      if arg.is_a?(Prism::StringNode)
        path = arg.unescaped
        # Only inline `../benchmarks/...` requires; leave anything else
        # (e.g. relative to harness/) for the wrapper to handle.
        if path.start_with?('../benchmarks/')
          full = File.join('bench', path.sub('../', ''))
          full += '.rb' unless full.end_with?('.rb')
          if File.exist?(full)
            sub_src = File.read(full)
            sub_result = Prism.parse(sub_src)
            abort "parse failed: #{full}" unless sub_result.success?
            sub_stmts = sub_result.value.statements.body
            # Strip nested require_relative '../../harness/loader' lines
            # that some benchmarks include.
            sub_stmts = sub_stmts.reject do |s|
              s.is_a?(Prism::CallNode) && s.name == :require_relative &&
                s.arguments&.arguments&.first.is_a?(Prism::StringNode) &&
                s.arguments.arguments.first.unescaped.include?('harness')
            end
            out.concat(inline_requires(sub_stmts, sub_src))
            next
          end
        end
      end
    end
    out << [n, src]
  end
  out
end

def wrap_stub(name)
  src = File.read("bench/stubs/#{name}.rb")
  result = Prism.parse(src)
  abort "parse failed: #{result.errors.inspect}" unless result.success?
  prog = result.value
  abort "expected Prism::ProgramNode" unless prog.is_a?(Prism::ProgramNode)
  stmts = prog.statements.body

  # Drop the harness header lines: $LOADED_FEATURES, def run_benchmark.
  # (They're load-phase global setup that we'll handle once in the outer
  # file. Inside the wrapped module they're either irrelevant or wrong.)
  stmts = stmts.drop_while do |n|
    case n
    when Prism::GlobalVariableOperatorWriteNode then n.name == :$LOADED_FEATURES
    when Prism::CallNode then n.name == :<< && n.receiver.is_a?(Prism::GlobalVariableReadNode) && n.receiver.name == :$LOADED_FEATURES
    when Prism::DefNode then n.name == :run_benchmark
    else false
    end
  end

  # Strip any `def run_benchmark(*, &); end` that appears later (some
  # stubs have it as a no-op for the bench harness).
  stmts = stmts.reject { |n| n.is_a?(Prism::DefNode) && n.name == :run_benchmark }

  # Inline `require_relative '../benchmarks/X'` content directly into
  # the stub so the required file's top-level defs become module methods
  # rather than depending on top-level dispatch through MainObject.
  noded = inline_requires(stmts, src)

  # Partition: ClassNode + DefNode + assignment-of-constant go module-
  # level; everything else goes into the run method. Constant assigns
  # (BENCH_N etc.) must live at module-level for class methods to see
  # them.
  module_level = []
  exec_stmts   = []
  noded.each do |n, owner_src|
    case n
    when Prism::ClassNode, Prism::ModuleNode
      module_level << [n, owner_src]
    when Prism::DefNode
      module_level << [n, owner_src]
    when Prism::ConstantWriteNode
      module_level << [n, owner_src]
    else
      exec_stmts << [n, owner_src]
    end
  end

  out = +""
  out << "module Stub_#{name.tr('-', '_')}\n"
  module_level.each do |node, owner_src|
    body = owner_src.byteslice(node.location.start_offset, node.location.length)
    if node.is_a?(Prism::DefNode)
      body = body.sub(/\Adef\s+/, 'def self.')
    end
    body.each_line { |l| out << "  " << l }
    out << "\n" unless body.end_with?("\n")
  end
  out << "  def self.run\n"
  exec_stmts.each do |node, owner_src|
    body = owner_src.byteslice(node.location.start_offset, node.location.length)
    body.each_line { |l| out << "    " << l }
    out << "\n" unless body.end_with?("\n")
  end
  out << "  end\n"
  out << "end\n"
  out
end

# Outer file.
puts %|$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)|
puts %|def run_benchmark(*, &); end|
puts

STUBS.each do |name|
  puts wrap_stub(name)
  puts
end

# Orchestrator: print delimiters around each stub's run output.
STUBS.each do |name|
  mod = "Stub_#{name.tr('-', '_')}"
  puts %|puts "=== #{name} ==="|
  puts %|#{mod}.run|
  puts %|puts "=== /#{name} ==="|
end

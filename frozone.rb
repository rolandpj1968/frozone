require 'optparse'

require_relative 'lib/frozone/vm/vm'
# Load both parser frontends unconditionally so closed-world AOT has
# both available; runtime --parser=X selects. Without this, the
# conditional `require_relative` for wq_parser inside the
# execute-phase `if options[:parser] == :wq` block would be a
# closed-world violation (BUILD_FILES is captured at load-phase end).
require_relative 'lib/frozone/vm/wq_parser'

options = {
  verbose:        false,
  scripts:        [],
  requires:       [],
  parser:         :prism,
  aot:            false,
  hoist_consts:   false,
}

OptionParser.new do |opts|
  opts.banner = "Usage: frozone.rb [options] [file ...]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-e SCRIPT", "Evaluate SCRIPT") do |v|
    options[:scripts] << v
  end

  opts.on("-r", "--require=PATH", "Require PATH before evaluating the script") do |v|
    options[:requires] << v
  end

  opts.on("--aot", "AOT compile: split file into load/execute phases, compile execute to Crystal") do
    options[:aot] = true
  end

  opts.on("--flatten", "Interpret with module erasure: split load/execute, flatten modules, then interpret") do
    options[:flatten] = true
  end

  opts.on("--hoist-class-consts",
          "AOT only: hoist expensive class-body constant initialisers " \
          "(those containing .map / .each / etc) out of the load phase " \
          "into the execute phase so they're built by compiled Crystal " \
          "instead of the interpreter. Outrageous but effective for " \
          "lookup-table-heavy code like optcarrot's TILE_LUT.") do
    options[:hoist_consts] = true
  end

  opts.on("--parser=FLAVOR", %w[prism wq],
          "Parser to use: prism (default) or wq (Parser::Ruby40)") do |v|
    options[:parser] = v.to_sym
  end
end.order!

if options[:parser] == :wq
  require_relative 'lib/frozone/vm/wq_parser'
  Frozone::Vm.send(:remove_const, :Parser)
  Frozone::Vm::Parser = Frozone::Vm::WqParser
end

options[:argv] = ARGV

Frozone::Vm::Vm.new(options).run

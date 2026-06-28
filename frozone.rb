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
  # nil default routes to WqParser via vm.rb. Box-first compiled mode
  # has no Prism (C extension); interpreter mode users who want Prism
  # pass `--parser=prism`. The rake spec tasks pass it explicitly.
  parser:         nil,
  aot:            false,
  hoist_consts:   false,
}

# Pre-scan ARGV for `-e SCRIPT` before handing to OptionParser. The
# compiled bin/frozone_box's stdlib OptionParser has accumulated gaps
# in closed-world compile (Hash#complete dispatch, Version ConstantPath,
# etc.) that silently swallow `-e`. The pre-scan keeps `-e` working
# under frozone_box so it can serve as `RUBY_EXE` for mspec
# subprocesses, while the rest of the option surface still flows
# through OptionParser. Mirrors MRI's `ruby -e SCRIPT` semantics:
# multiple -e args concatenate.
i = 0
while i < ARGV.length
  case ARGV[i]
  when "-e"
    options[:scripts] << ARGV[i + 1] if ARGV[i + 1]
    ARGV.slice!(i, 2)
  when /\A-e(.+)/m
    options[:scripts] << ::Regexp.last_match(1)
    ARGV.slice!(i, 1)
  else
    i += 1
  end
end

OptionParser.new do |opts|
  opts.banner = "Usage: frozone.rb [options] [file ...]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  # NOTE: `-e SCRIPT` is consumed by the pre-OptionParser scan above
  # (see comment near `options[:scripts]` init). Don't re-register here
  # — would conflict with the pre-scan and (more importantly) re-expose
  # the closed-world OptionParser gap that motivated the pre-scan.

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

# Note: legacy --parser=wq used to rebind `Frozone::Vm::Parser` to
# `WqParser` here. That dance is dead — `Vm#parse` (vm.rb) already
# dispatches on `options[:parser]` and routes "wq"/nil/"" → WqParser
# directly, and `EVAL_PARSER_CLASS` is hardcoded to WqParser at vm.rb
# load. Removing the rebind avoids the closed-world abort on
# Module#remove_const that triggered when frozone-cpp processed the
# old block.

options[:argv] = ARGV

Frozone::Vm::Vm.new(options).run

require 'optparse'

require_relative 'lib/frozone/vm/vm'

options = {
  verbose:   false,
  scripts:   [],
  requires:  [],
  parser:    :prism,
  aot:       false,
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

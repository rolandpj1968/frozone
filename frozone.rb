require 'optparse'

require_relative 'lib/frozone/vm/vm'

options = {
  verbose:   false,
  scripts:   [],
  parser:    :prism,
  ast_cache: ENV['FROZONE_NO_AST_CACHE'] != '1',
}

OptionParser.new do |opts|
  opts.banner = "Usage: frozone.rb [options] [file ...]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-e SCRIPT", "Evaluate SCRIPT") do |v|
    options[:scripts] << v
  end

  opts.on("--parser=FLAVOR", %w[prism wq],
          "Parser to use: prism (default) or wq (Parser::Ruby40)") do |v|
    options[:parser] = v.to_sym
  end

  opts.on("--no-ast-cache", "Disable the AST cache (~/.frozone/ast/)") do
    options[:ast_cache] = false
  end
end.order!

if options[:parser] == :wq
  require_relative 'lib/frozone/vm/wq_parser'
  Frozone::Vm.send(:remove_const, :Parser)
  Frozone::Vm::Parser = Frozone::Vm::WqParser
end

if options[:ast_cache]
  Frozone::Vm::AstCache.cleanup_old_versions
else
  Frozone::Vm::AstCache.disable!
end

options[:argv] = ARGV

Frozone::Vm::Vm.new(options).run

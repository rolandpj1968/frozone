puts "Ruby Version: #{RUBY_VERSION}"
puts "Ruby Patchlevel: #{RUBY_PATCHLEVEL}"
puts "Ruby Release Date: #{RUBY_RELEASE_DATE}"
puts "Ruby Platform: #{RUBY_PLATFORM}"
puts "Ruby Description: #{RUBY_DESCRIPTION}"

$is_inner = RUBY_DESCRIPTION.match?(/frozone/)

puts "RPJ -                                                                         $is_inner is #{$is_inner}"

require 'optparse'

require_relative 'lib/frozone/vm/vm'

puts "RPJ -                                                                         $is_inner is #{$is_inner} frozone.rb after requires"

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

puts "RPJ -                                                                         $is_inner is #{$is_inner} frozone.rb before potential parser switch"

if options[:parser] == :wq
  puts "RPJ -                                                                         $is_inner is #{$is_inner} frozone.rb before require_relative 'lib/frozone/vm/wq_parser'"
  require_relative 'lib/frozone/vm/wq_parser'
  puts "RPJ -                                                                         $is_inner is #{$is_inner} frozone.rb after require_relative 'lib/frozone/vm/wq_parser'"
  Frozone::Vm.send(:remove_const, :Parser)
  Frozone::Vm::Parser = Frozone::Vm::WqParser
end

unless $is_inner
if options[:ast_cache]
  Frozone::Vm::AstCache.cleanup_old_versions
else
  Frozone::Vm::AstCache.disable!
end
end

options[:argv] = ARGV

puts "RPJ -                                                                         $is_inner is #{$is_inner} frozone.rb before Frozone::Vm::Vm.new(options).run"

Frozone::Vm::Vm.new(options).run

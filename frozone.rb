begin
  RubyVM::YJIT.enable
rescue NameError
  # YJIT not available, no-op
end


require 'optparse'

require_relative 'lib/frozone/vm/vm'

options = {
  verbose: false,
  scripts: [],
}

OptionParser.new do |opts|
  opts.banner = "Usage: frozone.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-e SCRIPT", "", "Run a script") do |v|
    options[:scripts] << v
  end
end.order!

options[:argv] = ARGV

Frozone::Vm::Vm.new(options).run

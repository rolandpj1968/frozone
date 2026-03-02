begin
  RubyVM::YJIT.enable
  puts "RubyVM::YJIT.enabled? #{RubyVM::YJIT.enabled?}"
rescue NameError
  puts "RubyVM::YJIT not available"
end


require 'optparse'

require_relative 'lib/frozone/vm/vm'

options = {
  verbose: false,
  scripts: [],
}

puts "ARGV:"
puts ARGV

OptionParser.new do |opts|
  opts.banner = "Usage: frozone.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-e SCRIPT", "", "Run a script") do |v|
    options[:scripts] << v
  end
end.order!

puts "ARGV:"
puts ARGV

options[:argv] = ARGV

Frozone::Vm::Vm.new(options).run

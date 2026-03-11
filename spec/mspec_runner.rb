require 'mspec'
require 'mspec/runner/formatters/dotted'

VersionGuard::FULL_RUBY_VERSION = SpecVersion.new(RUBY_VERSION)
ENV['MSPEC_RUNNER'] = '1'
MSpec.instance_variable_set(:@env, Object.new.extend(MSpec))
class MSpecScript
  def self.config = { backtrace_filter: /mspec/ }
end

formatter = DottedFormatter.new
formatter.register
MSpec.actions(:start)

spec_dir = File.expand_path(ENV.fetch('RUBY_SPEC_DIR', '../../spec/ruby-spec'), __dir__)
specs = ARGV.empty? ? Dir["#{spec_dir}/language/*_spec.rb"].sort : ARGV

specs.each do |f|
  begin
    require_relative f
  rescue Exception => e
    puts "LOAD_ERROR #{File.basename(f)}: #{e.class}: #{e.message.to_s[0, 120]}"
  end
end

puts "SPECS_DONE"
MSpec.actions(:finish)
puts "FINISH_DONE"

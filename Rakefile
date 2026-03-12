RUBY_SPEC_DIR = ENV.fetch('RUBY_SPEC_DIR', File.expand_path('spec/ruby-spec', __dir__))
MSPEC_RUNNER  = File.expand_path('spec/mspec_runner.rb', __dir__)

# Internal RSpec suite
task default: :spec

desc "Run internal RSpec suite"
task :spec do
  sh "bundle exec rspec"
end

# Language spec helpers
def run_language_specs(*spec_files)
  args = spec_files.map { |f| File.expand_path(f) }.join(' ')
  sh "bundle exec ruby frozone.rb #{MSPEC_RUNNER} #{args}"
end

def language_spec_path(name)
  "#{RUBY_SPEC_DIR}/language/#{name}_spec.rb"
end

# Run all language specs
desc "Run all ruby/spec language specs (RUBY_SPEC_DIR=... to override path)"
task :language do
  all_specs = Dir["#{RUBY_SPEC_DIR}/language/*_spec.rb"].sort
  run_language_specs(*all_specs)
end

# Individual language spec tasks: rake language:array, rake language:hash, etc.
namespace :language do
  spec_files = Dir["#{RUBY_SPEC_DIR}/language/*_spec.rb"]

  if spec_files.empty?
    task(:_missing) { abort "No ruby-spec found at #{RUBY_SPEC_DIR}. Set RUBY_SPEC_DIR= or add as submodule at spec/ruby-spec" }
  else
    spec_files.each do |path|
      name = File.basename(path, '_spec.rb')
      desc "Run language/#{name}_spec.rb"
      task name do
        run_language_specs(path)
      end
    end
  end

  # Also support arbitrary names for forward compat: rake language:foo
  rule '' do |t|
    path = language_spec_path(t.name.sub('language:', ''))
    abort "No spec file: #{path}" unless File.exist?(path)
    run_language_specs(path)
  end
end

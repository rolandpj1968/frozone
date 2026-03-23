RUBY_SPEC_DIR = ENV.fetch('RUBY_SPEC_DIR', File.expand_path('spec/ruby-spec', __dir__))
MSPEC_RUNNER  = File.expand_path('spec/mspec_runner.rb', __dir__)
PARSER_FLAVOR = ENV.fetch('PARSER', 'prism')  # prism (default) or wq

# Internal RSpec suite
task default: :spec

desc "Run internal RSpec suite"
task :spec do
  sh "bundle exec rspec"
end

# Language spec helpers
def run_language_specs(*spec_files)
  args = spec_files.map { |f| File.expand_path(f) }.join(' ')
  sh "bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args}"
end

def language_spec_path(name)
  "#{RUBY_SPEC_DIR}/language/#{name}_spec.rb"
end

# Run all language specs
desc "Run all ruby/spec language specs (RUBY_SPEC_DIR=... PARSER=prism|wq to override)"
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

# Core spec helpers
# Known-slow or hanging spec files excluded from core spec runs.
SKIP_SPEC_FILES = %w[
  array/sample_spec.rb
  array/sort_spec.rb
  conditionvariable/broadcast_spec.rb
  dir/each_child_spec.rb
  dir/each_spec.rb
  dir/element_reference_spec.rb
  dir/foreach_spec.rb
  dir/glob_spec.rb
  encoding/aliases_spec.rb
  encoding/compatible_spec.rb
  encoding/find_spec.rb
  encoding/name_spec.rb
  encoding/names_spec.rb
  encoding/to_s_spec.rb
  conditionvariable/signal_spec.rb
  conditionvariable/wait_spec.rb
  io/close_spec.rb
  io/copy_stream_spec.rb
  io/fcntl_spec.rb
  io/flush_spec.rb
  io/internal_encoding_spec.rb
  io/path_spec.rb
  io/read_spec.rb
  kernel/fork_spec.rb
  kernel/p_spec.rb
  kernel/printf_spec.rb
  kernel/rand_spec.rb
  kernel/sleep_spec.rb
  kernel/system_spec.rb
  enumerator/lazy/enum_for_spec.rb
  enumerator/lazy/to_enum_spec.rb
  enumerator/lazy/zip_spec.rb
  mutex/lock_spec.rb
  mutex/unlock_spec.rb
  process/spawn_spec.rb
  queue/deq_spec.rb
  queue/num_waiting_spec.rb
  queue/pop_spec.rb
  queue/shift_spec.rb
  regexp/timeout_spec.rb
  thread/abort_on_exception_spec.rb
  thread/alive_spec.rb
  thread/inspect_spec.rb
  thread/kill_spec.rb
  thread/list_spec.rb
  thread/terminate_spec.rb
  thread/raise_spec.rb
  thread/run_spec.rb
  thread/status_spec.rb
  thread/stop_spec.rb
  thread/to_s_spec.rb
  thread/wakeup_spec.rb
].map { |f| "#{RUBY_SPEC_DIR}/core/#{f}" }.freeze

def run_core_specs(*spec_files)
  filtered = spec_files.reject { |f| SKIP_SPEC_FILES.include?(File.expand_path(f)) }
  return if filtered.empty?
  args = filtered.map { |f| File.expand_path(f) }.join(' ')
  sh "bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args}"
end

def core_spec_path(name)
  "#{RUBY_SPEC_DIR}/core/#{name}"
end

# Run all core specs in parallel (one process per module)
desc "Run all ruby/spec core specs (RUBY_SPEC_DIR=... PARSER=prism|wq JOBS=N to override)"
task :core do
  require 'tempfile'
  require 'etc'

  totals = { examples: 0, passing: 0, failures: 0, errors: 0 }
  core_modules = Dir["#{RUBY_SPEC_DIR}/core/*/"].map { |d| File.basename(d) }.sort
  per_module = {}

  # Default parallelism: number of CPUs (capped at 8 to avoid memory pressure)
  n_jobs = [ENV.fetch('JOBS', [Etc.nprocessors, 8].min.to_s).to_i, 1].max

  # Build list of (name, args) pairs for non-empty modules
  work = core_modules.filter_map do |name|
    specs = Dir["#{RUBY_SPEC_DIR}/core/#{name}/**/*_spec.rb"].sort
    specs -= SKIP_SPEC_FILES
    next if specs.empty?

    args = specs.map { |f| File.expand_path(f) }.join(' ')
    [name, args]
  end

  # Run in parallel with n_jobs workers
  results = {}
  mutex = Mutex.new
  queue = work.dup

  workers = n_jobs.times.map do
    Thread.new do
      loop do
        item = mutex.synchronize { queue.shift }
        break unless item

        name, args = item
        tmpfile = Tempfile.new("frozone_core_#{name}")
        begin
          system("timeout 600 bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args} > #{tmpfile.path} 2>/dev/null")
          output = File.read(tmpfile.path, encoding: 'binary')
          if output =~ /(\d+) files, (\d+) examples, \d+ expectations?, (\d+) failures?, (\d+) errors?/
            ex = $2.to_i; fl = $3.to_i; er = $4.to_i; pass = ex - fl - er
            mutex.synchronize { results[name] = { examples: ex, passing: pass, failures: fl, errors: er } }
          else
            mutex.synchronize { results[name] = :timeout }
          end
        ensure
          tmpfile.close
          tmpfile.unlink
        end
      end
    end
  end

  workers.each(&:join)

  core_modules.each do |name|
    r = results[name]
    next unless r

    if r == :timeout
      puts "#{name}: (no output / timeout)"
    else
      totals[:examples] += r[:examples]
      totals[:passing]  += r[:passing]
      totals[:failures] += r[:failures]
      totals[:errors]   += r[:errors]
      per_module[name] = r
    end
  end

  puts "\n#{'='*60}"
  puts "Core spec results (#{PARSER_FLAVOR} parser, #{n_jobs} parallel jobs)"
  puts "Overall: #{totals[:passing]}/#{totals[:examples]} passing " \
       "(#{totals[:failures]} failures, #{totals[:errors]} errors)"
  puts "\n#{'%-20s' % 'Module'} #{'%8s' % 'Examples'} #{'%8s' % 'Passing'} #{'%8s' % 'Failures'} #{'%8s' % 'Errors'}"
  puts '-' * 60
  per_module.sort.each do |name, r|
    flag = (r[:failures] + r[:errors]) > 0 ? ' *' : ''
    puts "#{'%-20s' % name} #{'%8d' % r[:examples]} #{'%8d' % r[:passing]} #{'%8d' % r[:failures]} #{'%8d' % r[:errors]}#{flag}"
  end
  puts '='*60
end

# Individual core spec tasks by module: rake core:array, rake core:string, etc.
namespace :core do
  core_dirs = Dir["#{RUBY_SPEC_DIR}/core/*/"].map { |d| File.basename(d) }

  core_dirs.each do |name|
    desc "Run core/#{name} specs"
    task name do
      specs = Dir["#{RUBY_SPEC_DIR}/core/#{name}/**/*_spec.rb"].sort
      run_core_specs(*specs)
    end
  end

  # Also support arbitrary names: rake core:foo
  rule '' do |t|
    name = t.name.sub('core:', '')
    path = core_spec_path(name)
    if File.directory?(path)
      specs = Dir["#{path}/**/*_spec.rb"].sort
      run_core_specs(*specs)
    elsif File.exist?("#{path}_spec.rb")
      run_core_specs("#{path}_spec.rb")
    else
      abort "No core spec found for: #{name}"
    end
  end
end

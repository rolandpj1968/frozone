require 'tempfile'
require 'etc'

RUBY_SPEC_DIR = ENV.fetch('RUBY_SPEC_DIR', File.expand_path('spec/ruby-spec', __dir__))
MSPEC_RUNNER  = File.expand_path('spec/mspec_runner.rb', __dir__)
PARSER_FLAVOR = ENV.fetch('PARSER', 'prism')  # prism (default) or wq
FLATTEN_FLAG  = ENV['FLATTEN'] ? ' --flatten' : ''

# Internal RSpec suite
task default: :spec

desc "Run Crystal runtime library specs (crystal/)"
task :crystal do
  sh "cd crystal && crystal spec"
end

desc "Run internal RSpec suite"
task :spec do
  sh "bundle exec rspec"
end

# Language spec helpers
def run_language_specs(*spec_files)
  args = spec_files.map { |f| File.expand_path(f) }.join(' ')
  sh "bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR}#{FLATTEN_FLAG} #{MSPEC_RUNNER} #{args}"
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
  conditionvariable/broadcast_spec.rb
  dir/glob_spec.rb
  conditionvariable/signal_spec.rb
  conditionvariable/wait_spec.rb
  io/buffer/and_spec.rb
  io/buffer/empty_spec.rb
  io/buffer/external_spec.rb
  io/buffer/for_spec.rb
  io/buffer/free_spec.rb
  io/buffer/initialize_spec.rb
  io/buffer/internal_spec.rb
  io/buffer/locked_spec.rb
  io/buffer/map_spec.rb
  io/buffer/mapped_spec.rb
  io/buffer/not_spec.rb
  io/buffer/null_spec.rb
  io/buffer/or_spec.rb
  io/buffer/private_spec.rb
  io/buffer/readonly_spec.rb
  io/buffer/resize_spec.rb
  io/buffer/shared_spec.rb
  io/buffer/string_spec.rb
  io/buffer/transfer_spec.rb
  io/buffer/valid_spec.rb
  io/buffer/xor_spec.rb
  io/close_spec.rb
  io/copy_stream_spec.rb
  io/eof_spec.rb
  io/output_spec.rb
  io/pipe_spec.rb
  io/fcntl_spec.rb
  io/flush_spec.rb
  io/path_spec.rb
  io/read_nonblock_spec.rb
  io/read_spec.rb
  io/readpartial_spec.rb
  io/select_spec.rb
  kernel/fork_spec.rb
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
  filetest/socket_spec.rb
  regexp/timeout_spec.rb
  thread/abort_on_exception_spec.rb
  thread/alive_spec.rb
  thread/handle_interrupt_spec.rb
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
  sizedqueue/append_spec.rb
  sizedqueue/deq_spec.rb
  sizedqueue/enq_spec.rb
  sizedqueue/pop_spec.rb
  sizedqueue/push_spec.rb
  sizedqueue/shift_spec.rb
].map { |f| "#{RUBY_SPEC_DIR}/core/#{f}" }.freeze

# Hanging library spec files (GC-dependent, blocking IO, or mspec mock + Delegator infinite recursion).
SKIP_LIBRARY_SPEC_FILES = %w[
  weakref/__getobj___spec.rb
  weakref/weakref_alive_spec.rb
  delegate/delegator/equal_value_spec.rb
  delegate/delegator/not_equal_spec.rb
].map { |f| "#{RUBY_SPEC_DIR}/library/#{f}" }.freeze

def run_core_specs(*spec_files)
  filtered = spec_files.reject { |f| SKIP_SPEC_FILES.include?(File.expand_path(f)) }
  return if filtered.empty?
  args = filtered.map { |f| File.expand_path(f) }.join(' ')
  sh "bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args}"
end

def core_spec_path(name)
  "#{RUBY_SPEC_DIR}/core/#{name}"
end

# Fast smoke test — high-value modules covering the most-refactored areas.
# Runs in ~60-90s; use before committing. Skip slow/OS-heavy/threading modules.
SMOKE_MODULES = %w[
  integer float numeric
  string
  hash
  enumerable comparable
  range regexp matchdata
  exception proc symbol
].freeze

# Parse mspec summary line into { examples:, passing:, failures:, errors: } or nil.
def parse_mspec_output(output)
  # matches both "N examples, ..." and "N files, N examples, ..."
  m = output.match(/(\d+) examples,\s*\d+ expectations?,\s*(\d+) failures?,\s*(\d+) errors?/)
  return nil unless m
  ex = m[1].to_i; fl = m[2].to_i; er = m[3].to_i
  { examples: ex, passing: ex - fl - er, failures: fl, errors: er }
end

# Run a list of [name, args_string] pairs in parallel, returning { name => result }.
# result is either { examples:, passing:, failures:, errors: } or :timeout.
def run_parallel_specs(work, timeout_secs: 600)
  n_jobs = [ENV.fetch('JOBS', [Etc.nprocessors, 8].min.to_s).to_i, 1].max
  results = {}
  mutex = Mutex.new
  queue = work.dup

  workers = n_jobs.times.map do
    Thread.new do
      loop do
        item = mutex.synchronize { queue.shift }
        break unless item
        name, args = item
        tmpfile = Tempfile.new(["frozone_#{name}", '.txt'])
        begin
          system("timeout #{timeout_secs} bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args} > #{tmpfile.path} 2>/dev/null")
          output = File.read(tmpfile.path, encoding: 'binary')
          parsed = parse_mspec_output(output)
          mutex.synchronize { results[name] = parsed || :timeout }
        ensure
          tmpfile.close
          tmpfile.unlink
        end
      end
    end
  end

  workers.each(&:join)
  results
end

# Print a formatted results table and return totals hash.
def print_results_table(label, results, ordered_names)
  totals = { examples: 0, passing: 0, failures: 0, errors: 0 }
  per_module = {}

  ordered_names.each do |name|
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

  n_jobs = [ENV.fetch('JOBS', [Etc.nprocessors, 8].min.to_s).to_i, 1].max
  puts "\n#{'=' * 60}"
  puts "#{label} (#{PARSER_FLAVOR} parser, #{n_jobs} parallel jobs)"
  puts "Overall: #{totals[:passing]}/#{totals[:examples]} passing " \
       "(#{totals[:failures]} failures, #{totals[:errors]} errors)"
  puts "\n#{'%-20s' % 'Module'} #{'%8s' % 'Examples'} #{'%8s' % 'Passing'} #{'%8s' % 'Failures'} #{'%8s' % 'Errors'}"
  puts '-' * 60
  per_module.sort.each do |name, r|
    flag = (r[:failures] + r[:errors]) > 0 ? ' *' : ''
    puts "#{'%-20s' % name} #{'%8d' % r[:examples]} #{'%8d' % r[:passing]} #{'%8d' % r[:failures]} #{'%8d' % r[:errors]}#{flag}"
  end
  puts '=' * 60
end

desc "Fast smoke test — rspec + language + key core modules + Frozone² + compiler (~2-3 min)"
task :smoke do
  # RSpec unit tests
  sh "bundle exec rspec --format progress"
  # Language specs
  run_language_specs(*Dir["#{RUBY_SPEC_DIR}/language/*_spec.rb"].sort)
  # Frozone² self-hosting
  sh "bundle exec ruby frozone.rb frozone.rb -e 'puts \"frozone² ok\"'"
  # AOT compile + Crystal build + run for key benchmarks (catches codegen regressions)
  Rake::Task[:bench_smoke].invoke
  # Core module specs (parallel)
  work = SMOKE_MODULES.filter_map do |name|
    specs = Dir["#{RUBY_SPEC_DIR}/core/#{name}/**/*_spec.rb"].sort
    specs -= SKIP_SPEC_FILES
    next if specs.empty?
    [name, specs.map { |f| File.expand_path(f) }.join(' ')]
  end

  results = run_parallel_specs(work, timeout_secs: 120)
  print_results_table("Smoke test results", results, SMOKE_MODULES)
end

# Benchmark smoke test: AOT-compile + Crystal-build + run a representative set
# of benchmarks to catch codegen regressions. Skips splay (slow GC-bound run)
# and structaset (pre-existing Struct subclass codegen bug).
BENCH_SMOKE = %w[fib blurhash sudoku nqueens]

desc "Compile + run all benchmarks via C++ backend; report pass/fail vs bench/expected"
task :bench_cpp do
  pass = []; fail = []; mismatch = []
  Dir['bench/stubs/*.rb'].sort.each do |stub|
    name = File.basename(stub, '.rb')
    expected_path = "bench/expected/#{name}.txt"
    next unless File.exist?(expected_path)
    expected = File.read(expected_path)
    unless system("FROZONE_CPP=1 bundle exec ruby frozone.rb --aot #{stub} > /dev/null 2>&1")
      puts "  #{name.ljust(25)} GEN_FAIL"; fail << name; next
    end
    cpp = "cpp/gen/#{name}.cpp"
    bin = "cpp/gen/#{name}"
    if system("g++ -O2 -std=c++20 #{cpp} -o #{bin} 2>/dev/null")
      actual = `./#{bin} 2>&1`
      if actual == expected
        puts "  #{name.ljust(25)} PASS"; pass << name
      else
        puts "  #{name.ljust(25)} MISMATCH"; mismatch << name
      end
    else
      puts "  #{name.ljust(25)} COMPILE_FAIL"; fail << name
    end
  end
  total = pass.size + fail.size + mismatch.size
  puts ''
  puts "C++ backend: #{pass.size}/#{total} pass, #{mismatch.size} mismatch, #{fail.size} fail"
end

desc "Compile + run key benchmarks end-to-end (catches codegen regressions)"
task :bench_smoke do
  failures = []
  BENCH_SMOKE.each do |name|
    print "  #{name.ljust(12)} "
    begin
      sh "bundle exec ruby frozone.rb --aot bench/stubs/#{name}.rb > /dev/null 2>&1"
      sh "cd crystal && crystal build gen/#{name}.cr --release -o #{name} > /dev/null 2>&1"
      t0 = Time.now
      out = `cd crystal && ./#{name} 2>&1`
      raise "binary exited #{$?.exitstatus}" unless $?.success?
      ms = ((Time.now - t0) * 1000).to_i
      expected_path = File.expand_path("bench/expected/#{name}.txt", __dir__)
      if File.exist?(expected_path)
        expected = File.read(expected_path)
        if out != expected
          puts "✗ output mismatch"
          puts "    expected: #{expected.inspect[0..120]}"
          puts "    actual:   #{out.inspect[0..120]}"
          failures << "#{name} (output mismatch)"
          next
        end
        puts "✓ #{ms}ms (output verified)"
      else
        puts "✓ #{ms}ms (no expected output captured)"
      end
    rescue => e
      puts "✗ #{e.message.lines.first&.strip}"
      failures << name
    end
  end
  abort "bench_smoke FAILED: #{failures.join(', ')}" unless failures.empty?
end

# Codegen golden-file check: AOT-compile each smoke benchmark and diff its
# generated .cr against the committed copy in spec/golden/codegen/. Catches
# silent emission drift (optimization paths that stop firing, etc.) before
# bench_smoke would only flag a perf regression or compile failure.
desc "Compare current AOT codegen output against committed goldens"
task :bench_check_codegen do
  golden_dir = File.expand_path('spec/golden/codegen', __dir__)
  failures = []
  BENCH_SMOKE.each do |name|
    print "  #{name.ljust(12)} "
    sh "bundle exec ruby frozone.rb --aot bench/stubs/#{name}.rb > /dev/null 2>&1"
    cur = File.expand_path("crystal/gen/#{name}.cr", __dir__)
    gold = File.join(golden_dir, "#{name}.cr")
    if File.read(cur) == File.read(gold)
      puts '✓ matches golden'
    else
      puts '✗ DIFFERS from golden'
      failures << name
    end
  end
  unless failures.empty?
    puts
    puts "Drift detected. Review with:"
    failures.each { |n| puts "  diff -u spec/golden/codegen/#{n}.cr crystal/gen/#{n}.cr" }
    puts "Update goldens (after review) with: rake bench_update_goldens"
    abort "bench_check_codegen FAILED: #{failures.join(', ')}"
  end
end

desc "Update committed codegen goldens from current AOT output"
task :bench_update_goldens do
  golden_dir = File.expand_path('spec/golden/codegen', __dir__)
  BENCH_SMOKE.each do |name|
    sh "bundle exec ruby frozone.rb --aot bench/stubs/#{name}.rb > /dev/null 2>&1"
    cur = File.expand_path("crystal/gen/#{name}.cr", __dir__)
    FileUtils.cp(cur, File.join(golden_dir, "#{name}.cr"))
    puts "  updated #{name}.cr"
  end
end

# Run all core specs in parallel (one process per module)
desc "Run all ruby/spec core specs (RUBY_SPEC_DIR=... PARSER=prism|wq JOBS=N to override)"
task :core do
  core_modules = Dir["#{RUBY_SPEC_DIR}/core/*/"].map { |d| File.basename(d) }.sort

  work = core_modules.filter_map do |name|
    specs = Dir["#{RUBY_SPEC_DIR}/core/#{name}/**/*_spec.rb"].sort
    specs -= SKIP_SPEC_FILES
    next if specs.empty?
    [name, specs.map { |f| File.expand_path(f) }.join(' ')]
  end

  results = run_parallel_specs(work, timeout_secs: 600)
  print_results_table("Core spec results", results, core_modules)
end

# Run all library specs in parallel (one process per module)
desc "Run all ruby/spec library specs (RUBY_SPEC_DIR=... PARSER=prism|wq JOBS=N to override)"
task :library do
  lib_modules = Dir["#{RUBY_SPEC_DIR}/library/*/"].map { |d| File.basename(d) }.sort

  work = lib_modules.filter_map do |name|
    specs = Dir["#{RUBY_SPEC_DIR}/library/#{name}/**/*_spec.rb"].sort
    specs -= SKIP_LIBRARY_SPEC_FILES
    next if specs.empty?
    [name, specs.map { |f| File.expand_path(f) }.join(' ')]
  end

  results = run_parallel_specs(work, timeout_secs: 120)
  print_results_table("Library spec results", results, lib_modules)
end

# Individual library spec tasks: rake library:stringio, rake library:set, etc.
namespace :library do
  lib_dirs = Dir["#{RUBY_SPEC_DIR}/library/*/"].map { |d| File.basename(d) }

  lib_dirs.each do |name|
    desc "Run library/#{name} specs"
    task name do
      specs = Dir["#{RUBY_SPEC_DIR}/library/#{name}/**/*_spec.rb"].sort
      specs -= SKIP_LIBRARY_SPEC_FILES
      next if specs.empty?
      args = specs.map { |f| File.expand_path(f) }.join(' ')
      sh "bundle exec ruby frozone.rb --parser=#{PARSER_FLAVOR} #{MSPEC_RUNNER} #{args}"
    end
  end
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

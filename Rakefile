require 'tempfile'
require 'etc'
require 'fileutils'

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

# Three-way perf comparison: MRI vs box-first vs Frozone interpreter.
#
# Stub workload (large, for MRI + box-first): bench/stubs/X.rb. The
# stub stubs out run_benchmark, requires the bench file for its method
# defs, then explicitly iterates with a workload sized for compiled
# performance (e.g. fib(35)×3).
#
# Bench workload (smaller, for interpreter): bench/benchmarks/X.rb.
# Uses the run_benchmark harness with workloads sized for the
# tree-walking interpreter (e.g. fib(20)×3 ≈ 2s/iter on Frozone).
#
# Wall-clock totals are reported per cell (not normalised to ms/iter
# since stub vs bench workloads differ). Doc/perf table lives at
# docs/box-first-benchmarks.md.
def time_command(cmd, env: {}, timeout: nil)
  # `timeout(SEC) cmd` returns 124 if it killed the child. We treat
  # that as :timeout sentinel so the table can render TIMEOUT instead
  # of a misleading wall-clock number for runs that never completed.
  full_cmd = timeout ? "timeout #{timeout} #{cmd}" : cmd
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ok = system(env, full_cmd, out: File::NULL, err: File::NULL)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  return [:timeout, elapsed] if !ok && $?&.exitstatus == 124
  [ok, elapsed]
end

def box_compile(stub_name)
  dir = "cpp/gen/box/#{stub_name}"
  bin = "#{dir}/#{stub_name}_box"
  # Per-app gen dir → full isolation. Wipe the whole subtree (its own
  # class/ included), so no cross-program stomping and no leftover .cpp
  # sneaking into this stub's compile glob.
  FileUtils.rm_rf(dir)
  return [:gen_fail, nil] unless system({"FROZONE_CPP" => "1", "FROZONE_BOX_FIRST" => "1"},
    "bundle exec ruby frozone.rb --aot bench/stubs/#{stub_name}.rb",
    out: File::NULL, err: File::NULL)
  cpp_files = Dir.glob("#{dir}/*.cpp").sort
  return [:gen_fail, nil] if cpp_files.empty?
  # Parallel compile each .cpp → .o, then link.
  parallel = ENV.fetch('JOBS', Etc.nprocessors.to_s).to_i
  queue = Queue.new
  cpp_files.each { |f| queue << f }
  o_files = []
  errors = []
  mutex = Mutex.new
  Array.new(parallel) do
    Thread.new do
      loop do
        cpp = queue.pop(true) rescue break
        o = cpp.sub(/\.cpp\z/, '.o')
        ok = system("g++ -O2 -std=c++20 -I #{ONIGMO_INCLUDE} -c #{cpp} -o #{o} 2>/dev/null")
        mutex.synchronize { ok ? o_files << o : errors << cpp }
      end
    end
  end.each(&:join)
  return [:compile_fail, nil] unless errors.empty?
  return [:compile_fail, nil] unless system(
    "g++ -O2 -std=c++20 #{o_files.sort.join(' ')} #{ONIGMO_LIB} -lgc -o #{bin} 2>/dev/null"
  )
  [:ok, bin]
end

# Resolve the bench-file path. Some benchmarks ship as
# `bench/benchmarks/<name>.rb` (single file), others as
# `bench/benchmarks/<name>/benchmark.rb` (subdirectory holding
# benchmark + data fixtures, e.g. blurhash/test.bin).
def bench_file_path(name)
  flat = "bench/benchmarks/#{name}.rb"
  return flat if File.exist?(flat)
  nested = "bench/benchmarks/#{name}/benchmark.rb"
  return nested if File.exist?(nested)
  nil
end

desc "Three-way perf comparison: MRI / box-first / Frozone interp on BENCH_SMOKE"
task :bench_compare do
  rows = BENCH_SMOKE.map do |name|
    stub_path = "bench/stubs/#{name}.rb"
    bench_path = bench_file_path(name)
    row = { name: name }

    # MRI on stub (large compiled-friendly workload)
    if File.exist?(stub_path)
      _ok, mri_t = time_command("ruby #{stub_path}")
      row[:mri_stub] = mri_t
    end

    # Box-first on stub (same workload as MRI(stub))
    if File.exist?(stub_path)
      status, bin = box_compile(name)
      if status == :ok
        _ok, box_t = time_command("./#{bin}")
        row[:box_stub] = box_t
      else
        row[:box_stub] = status
      end
    end

    # MRI on bench file with BENCH_N override — gives a direct
    # denominator for the interpreter row so "interp / mri_bench"
    # is a meaningful slowdown ratio on identical workload.
    n = ENV.fetch('INTERP_BENCH_N', '1')
    timeout_s = ENV.fetch('INTERP_TIMEOUT', '300').to_i
    if bench_path
      _ok, mri_bench_t = time_command(
        "ruby bench/run_bench.rb #{bench_path}",
        env: { "BENCH_N" => n }
      )
      row[:mri_bench] = mri_bench_t

      # Frozone interp on bench file (same N, with timeout — sudoku
      # at HARD20.each is too heavy even at N=1).
      result, interp_t = time_command(
        "bundle exec ruby frozone.rb bench/run_bench.rb #{bench_path}",
        env: { "BENCH_N" => n },
        timeout: timeout_s
      )
      row[:interp_bench] = result == :timeout ? :timeout : interp_t
    end

    row
  end

  fmt = ->(v) {
    case v
    when nil then "-"
    when :timeout then "TIMEOUT"
    when Symbol then v.to_s.upcase
    else format("%6.2fs", v)
    end
  }
  ratio = ->(num, den) {
    return "-" unless num.is_a?(Numeric) && den.is_a?(Numeric) && den > 0
    format("%.1f×", num / den)
  }

  puts ""
  puts "Stub workload (MRI/Box-first comparison):"
  puts "Benchmark    | MRI (stub)  | Box-first (stub) | Box/MRI"
  puts "-------------|-------------|------------------|--------"
  rows.each do |r|
    puts format("%-12s | %11s | %16s | %7s",
                r[:name],
                fmt.call(r[:mri_stub]),
                fmt.call(r[:box_stub]),
                ratio.call(r[:box_stub], r[:mri_stub]))
  end
  puts ""
  puts "Bench workload (Interp/MRI comparison, BENCH_N=#{ENV.fetch('INTERP_BENCH_N', '1')}):"
  puts "Benchmark    | MRI (bench) | Interp (bench)   | Interp/MRI"
  puts "-------------|-------------|------------------|----------"
  rows.each do |r|
    puts format("%-12s | %11s | %16s | %9s",
                r[:name],
                fmt.call(r[:mri_bench]),
                fmt.call(r[:interp_bench]),
                ratio.call(r[:interp_bench], r[:mri_bench]))
  end
  puts ""
end

DUSTMAN_DIR     = File.expand_path('vendor/dustman', __dir__)
DUSTMAN_BUILD   = File.join(DUSTMAN_DIR, 'build')
DUSTMAN_LIB     = File.join(DUSTMAN_BUILD, 'libdustman.a')
DUSTMAN_INCLUDE = File.join(DUSTMAN_DIR, 'include')

ONIGMO_DIR     = File.expand_path('vendor/Onigmo', __dir__)
ONIGMO_PREFIX  = File.join(ONIGMO_DIR, '_install')
ONIGMO_INCLUDE = File.join(ONIGMO_PREFIX, 'include')
ONIGMO_LIB     = File.join(ONIGMO_PREFIX, 'lib', 'libonigmo.a')

namespace :dustman do
  desc "Build vendor/dustman (Release) via CMake + Ninja → vendor/dustman/build/libdustman.a"
  task :build do
    raise "vendor/dustman not checked out — run `git submodule update --init`" unless File.exist?(File.join(DUSTMAN_DIR, 'CMakeLists.txt'))
    FileUtils.mkdir_p(DUSTMAN_BUILD)
    sh "cmake -S #{DUSTMAN_DIR} -B #{DUSTMAN_BUILD} -G Ninja -DCMAKE_BUILD_TYPE=Release -DDUSTMAN_BUILD_TESTS=OFF -DDUSTMAN_BUILD_BENCHMARKS=OFF"
    sh "cmake --build #{DUSTMAN_BUILD} --target dustman"
  end

  desc "Remove vendor/dustman/build"
  task :clean do
    FileUtils.rm_rf(DUSTMAN_BUILD)
  end
end

namespace :onigmo do
  desc "Build vendor/Onigmo (static lib) → vendor/Onigmo/_install/lib/libonigmo.a"
  task :build do
    raise "vendor/Onigmo not checked out — run `git submodule update --init`" unless File.exist?(File.join(ONIGMO_DIR, 'configure.ac'))
    next if File.exist?(ONIGMO_LIB)
    Dir.chdir(ONIGMO_DIR) do
      sh "./autogen.sh" unless File.exist?('configure')
      sh "./configure --prefix=#{ONIGMO_PREFIX} --disable-shared --enable-static"
      sh "make -j#{`nproc`.to_i.nonzero? || 4}"
      sh "make install"
    end
  end

  desc "Remove vendor/Onigmo/_install"
  task :clean do
    FileUtils.rm_rf(ONIGMO_PREFIX)
  end
end

# Compile one generated cpp/gen/<backend>/<name>.cpp for a given GC mode.
# Returns [:pass | :mismatch | :compile_fail, elapsed_seconds_or_nil].
def cpp_compile_run(name, gc: :none, expected: nil, backend: 'legacy')
  cpp = "cpp/gen/#{backend}/#{name}.cpp"
  bin = "cpp/gen/#{backend}/#{name}_#{gc}"
  cflags =
    case gc
    when :boehm
      "-DFROZONE_USE_BOEHM_GC -lgc"
    when :dustman
      "-DFROZONE_USE_DUSTMAN_GC -I #{DUSTMAN_INCLUDE} #{DUSTMAN_LIB}"
    else
      ""
    end
  cflags = "#{cflags} -I #{ONIGMO_INCLUDE} #{ONIGMO_LIB}" if backend == 'box' && File.exist?(ONIGMO_LIB)
  return [:compile_fail, nil] unless system("g++ -O2 -std=c++20 #{cpp} -o #{bin} #{cflags} 2>/dev/null")
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  actual = `./#{bin} 2>&1`
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  [actual == expected ? :pass : :mismatch, elapsed]
end

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
    status, _elapsed = cpp_compile_run(name, gc: :none, expected: expected)
    case status
    when :pass         then puts "  #{name.ljust(25)} PASS"; pass << name
    when :mismatch     then puts "  #{name.ljust(25)} MISMATCH"; mismatch << name
    when :compile_fail then puts "  #{name.ljust(25)} COMPILE_FAIL"; fail << name
    end
  end
  total = pass.size + fail.size + mismatch.size
  puts ''
  puts "C++ backend: #{pass.size}/#{total} pass, #{mismatch.size} mismatch, #{fail.size} fail"
end

desc "Compile + run all benchmarks against Dustman GC; report pass/fail and per-bench elapsed"
task bench_cpp_dustman: 'dustman:build' do
  raise "Dustman library not built — run `rake dustman:build`" unless File.exist?(DUSTMAN_LIB)
  pass = []; fail = []; mismatch = []
  timings = {}
  Dir['bench/stubs/*.rb'].sort.each do |stub|
    name = File.basename(stub, '.rb')
    expected_path = "bench/expected/#{name}.txt"
    next unless File.exist?(expected_path)
    expected = File.read(expected_path)
    unless system("FROZONE_CPP=1 bundle exec ruby frozone.rb --aot #{stub} > /dev/null 2>&1")
      puts "  #{name.ljust(25)} GEN_FAIL"; fail << name; next
    end
    status, elapsed = cpp_compile_run(name, gc: :dustman, expected: expected)
    timings[name] = elapsed if elapsed
    case status
    when :pass         then puts "  #{name.ljust(25)} PASS       #{format('%.3fs', elapsed)}"; pass << name
    when :mismatch     then puts "  #{name.ljust(25)} MISMATCH   #{format('%.3fs', elapsed)}"; mismatch << name
    when :compile_fail then puts "  #{name.ljust(25)} COMPILE_FAIL"; fail << name
    end
  end
  total = pass.size + fail.size + mismatch.size
  puts ''
  puts "Dustman: #{pass.size}/#{total} pass, #{mismatch.size} mismatch, #{fail.size} fail"
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

# Compare each benchmark's MRI Ruby output against bench/expected/*.txt.
# bench/expected/ was historically captured from the Crystal backend, so
# this surfaces real Crystal-vs-MRI semantic divergences (e.g. RNG choice,
# UTF-8 length vs bytesize, `puts array` formatting). Slow benchmarks
# (nqueens ~3min, respond_to ~10min) need the long timeout.
desc "Diff each benchmark's MRI output against bench/expected/*.txt"
task :bench_check_mri_parity do
  require 'shellwords'
  match = []; diff = []
  Dir['bench/stubs/*.rb'].sort.each do |stub|
    name = File.basename(stub, '.rb')
    expected_path = "bench/expected/#{name}.txt"
    next unless File.exist?(expected_path)
    expected = File.read(expected_path)
    cmd = "ARGV.clear; load '#{File.expand_path('bench/harness.rb', __dir__)}'; load '#{File.expand_path(stub, __dir__)}'"
    actual = `timeout 600 bundle exec ruby -e #{cmd.shellescape} 2>/dev/null`
    if actual == expected
      printf "  %-25s MATCH\n", name
      match << name
    else
      printf "  %-25s DIFF golden=%s mri=%s\n", name,
             expected.inspect[0..40], actual.inspect[0..40]
      diff << [name, expected, actual]
    end
  end
  puts ''
  puts "Parity: #{match.size}/#{match.size + diff.size} match MRI; #{diff.size} differ from golden"
end

# Capture each benchmark's MRI output as the new bench/expected/. Use this
# to re-baseline the goldens against MRI Ruby semantics. After this, any
# Crystal-or-C++-vs-MRI divergence becomes a visible regression.
desc "Capture MRI Ruby output as the new bench/expected/*.txt goldens"
task :bench_update_mri_goldens do
  require 'shellwords'
  Dir['bench/stubs/*.rb'].sort.each do |stub|
    name = File.basename(stub, '.rb')
    expected_path = "bench/expected/#{name}.txt"
    next unless File.exist?(expected_path)
    cmd = "ARGV.clear; load '#{File.expand_path('bench/harness.rb', __dir__)}'; load '#{File.expand_path(stub, __dir__)}'"
    actual = `timeout 600 bundle exec ruby -e #{cmd.shellescape} 2>/dev/null`
    if actual.empty?
      puts "  #{name.ljust(25)} SKIP (empty MRI output — likely timed out or errored)"
      next
    end
    File.write(expected_path, actual)
    puts "  #{name.ljust(25)} updated (#{actual.bytesize} bytes)"
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

# ---- Frozone self-compile (box-first AOT of frozone.rb itself) ------
#
# Pipeline: gen frozone.rb through its own AOT backend → ~660 .cpp files
# in cpp/gen/box/ → parallel compile → link → /usr/local/bin-style
# frozone_box binary. Cold build is ~30 min at -O2 / -j8 on this host;
# warm rebuild with ccache + mtime-stale detection is much faster.
#
# Tasks:
#   rake frozone:build              incremental (smart-stale .o)
#   rake frozone:rebuild            nuke .o + full rebuild
#   rake frozone:gen                gen phase only (regenerate .cpp/.hpp)
#   rake frozone:compile            compile-only (assumes gen ran)
#   rake frozone:link               link-only (assumes .o present)
#   rake frozone:run[script.rb]     run a script through the built binary
#   rake frozone:clean              wipe .o + binary
#
# Env knobs (all optional):
#   OPT=O0|O1|O2|O3    optimisation level (default O2)
#   JOBS=N             parallel compile workers (default nprocessors)
#   FROZONE_BOX_BIN    binary output path (default bin/frozone_box)
#   CCACHE=0           disable ccache even if installed (default: auto-use)

FROZONE_BOX_GEN_DIR   = File.expand_path('cpp/gen/box/frozone', __dir__)
FROZONE_BOX_BIN       = ENV.fetch('FROZONE_BOX_BIN', File.expand_path('bin/frozone_box', __dir__))
FROZONE_HEADER_STAMP  = File.join(FROZONE_BOX_GEN_DIR, '.headers.fingerprint')
FROZONE_OPT_STAMP     = File.join(FROZONE_BOX_GEN_DIR, '.opt')

def frozone_box_opt
  ENV.fetch('OPT', 'O2')
end

def frozone_box_jobs
  # Default to half the cores — g++ -O2 on these TUs peaks at 300-500MB
  # per worker; full -j on a 12-core / 28GB box OOM-thrashes. Floor of 2.
  default = [(Etc.nprocessors / 2), 2].max
  ENV.fetch('JOBS', default.to_s).to_i
end

def frozone_box_cxx
  use_ccache = ENV['CCACHE'] != '0' && system('which ccache > /dev/null 2>&1')
  use_ccache ? 'ccache g++' : 'g++'
end

# SHA of all runtime headers — mtime-based .o staleness misses header
# edits (intrinsics.hpp, box_first.hpp, layouts/post split, etc.). We
# fingerprint the header tree and force a full rebuild on change.
def frozone_box_header_fingerprint
  require 'digest'
  Digest::SHA1.new.tap do |h|
    Dir['cpp/runtime/**/*.{hpp,h}'].sort.each do |f|
      h.update(f)
      h.update(File.read(f))
    end
    Dir['cpp/gen/box/frozone/frozone_*.hpp', 'cpp/gen/box/frozone/class/*.hpp'].sort.each do |f|
      h.update(f)
      h.update(File.read(f))
    end
  end.hexdigest
end

# Run the gen phase: invokes frozone-on-MRI to produce ~660 .cpp/.hpp
# files under cpp/gen/box/ from frozone.rb itself.
def frozone_box_gen
  t0 = Time.now
  ok = system({'FROZONE_CPP' => '1', 'FROZONE_BOX_FIRST' => '1'},
              'bundle exec ruby frozone.rb --aot --hoist-class-consts frozone.rb')
  abort '[frozone:gen] gen failed' unless ok
  elapsed = Time.now - t0
  count = Dir["#{FROZONE_BOX_GEN_DIR}/frozone*.cpp"].size
  puts "[frozone:gen] #{count} .cpp in %.1fs" % elapsed
end

# Compile stale .cpps in parallel. A .cpp is stale if (a) no .o exists,
# (b) .cpp is newer than .o, or (c) header fingerprint changed since the
# last successful build (forces full recompile). `force: true` ignores
# the staleness check and recompiles everything.
def frozone_box_compile(force: false)
  cpp_files = Dir["#{FROZONE_BOX_GEN_DIR}/frozone*.cpp"].sort
  abort '[frozone:compile] no .cpp files — run frozone:gen first' if cpp_files.empty?

  opt = frozone_box_opt
  current_fp = frozone_box_header_fingerprint
  last_fp = File.exist?(FROZONE_HEADER_STAMP) ? File.read(FROZONE_HEADER_STAMP) : nil
  last_opt = File.exist?(FROZONE_OPT_STAMP) ? File.read(FROZONE_OPT_STAMP).strip : nil
  full_rebuild = force || last_fp != current_fp || last_opt != opt

  stale = if full_rebuild
            cpp_files
          else
            cpp_files.select do |cpp|
              o = "#{cpp}.o"
              !File.exist?(o) || File.mtime(cpp) > File.mtime(o)
            end
          end

  if stale.empty?
    puts "[frozone:compile] up-to-date (#{cpp_files.size} TUs)"
    return
  end

  reason = if force then 'forced'
           elsif last_fp != current_fp then 'header change'
           elsif last_opt != opt then "opt change (#{last_opt || 'none'} → #{opt})"
           else "#{stale.size}/#{cpp_files.size} stale"
           end
  puts "[frozone:compile] compiling #{stale.size} TUs at -#{opt} (-j#{frozone_box_jobs}, #{reason})"

  cxx = frozone_box_cxx
  jobs = frozone_box_jobs
  queue = Queue.new
  stale.each { |f| queue << f }
  errors = []
  mutex = Mutex.new
  t0 = Time.now

  Array.new(jobs) do
    Thread.new do
      loop do
        cpp = queue.pop(true) rescue break
        cmd = %(#{cxx} -std=c++20 -#{opt} -c "#{cpp}" -I #{ONIGMO_INCLUDE} -o "#{cpp}.o")
        unless system(cmd)
          mutex.synchronize { errors << cpp }
        end
      end
    end
  end.each(&:join)

  elapsed = Time.now - t0
  if errors.empty?
    File.write(FROZONE_HEADER_STAMP, current_fp)
    File.write(FROZONE_OPT_STAMP, opt)
    puts "[frozone:compile] %d TUs in %.1fs" % [stale.size, elapsed]
  else
    abort "[frozone:compile] #{errors.size} TUs failed: #{errors.first(3).join(', ')}#{'…' if errors.size > 3}"
  end
end

# Link all .o files into the frozone_box binary.
def frozone_box_link
  o_files = Dir["#{FROZONE_BOX_GEN_DIR}/frozone*.cpp.o"].sort
  abort '[frozone:link] no .o files — run frozone:compile first' if o_files.empty?
  FileUtils.mkdir_p(File.dirname(FROZONE_BOX_BIN))
  opt = frozone_box_opt
  cxx = frozone_box_cxx
  t0 = Time.now
  cmd = %(#{cxx} -std=c++20 -#{opt} #{o_files.join(' ')} -I #{ONIGMO_INCLUDE} #{ONIGMO_LIB} -lgc -o #{FROZONE_BOX_BIN})
  ok = system(cmd)
  elapsed = Time.now - t0
  if ok
    size_mb = File.size(FROZONE_BOX_BIN) / (1024.0 * 1024.0)
    puts "[frozone:link] %.0fM in %.1fs → %s" % [size_mb, elapsed, FROZONE_BOX_BIN]
  else
    abort '[frozone:link] link failed'
  end
end

namespace :frozone do
  desc 'Self-compile frozone.rb to frozone_box (gen + incremental compile + link)'
  task :build do
    frozone_box_gen
    frozone_box_compile
    frozone_box_link
  end

  desc 'Force-clean .o + full self-compile rebuild'
  task :rebuild do
    FileUtils.rm_f(Dir["#{FROZONE_BOX_GEN_DIR}/frozone*.cpp.o"])
    FileUtils.rm_f(FROZONE_HEADER_STAMP)
    FileUtils.rm_f(FROZONE_OPT_STAMP)
    frozone_box_gen
    frozone_box_compile(force: true)
    frozone_box_link
  end

  desc 'Run gen phase only (regenerate cpp/gen/box/)'
  task :gen do
    frozone_box_gen
  end

  desc 'Compile-only (assumes gen has run)'
  task :compile do
    frozone_box_compile
  end

  desc 'Link-only (assumes .o files present)'
  task :link do
    frozone_box_link
  end

  desc 'Run a script through frozone_box (rake frozone:run[path/to/script.rb])'
  task :run, [:script] do |_, args|
    abort 'usage: rake frozone:run[path/to/script.rb]' unless args[:script]
    abort "frozone_box not built — run `rake frozone:build` first" unless File.executable?(FROZONE_BOX_BIN)
    exec FROZONE_BOX_BIN, args[:script]
  end

  desc 'Wipe .o files + binary (keeps .cpp/.hpp gen)'
  task :clean do
    FileUtils.rm_f(Dir["#{FROZONE_BOX_GEN_DIR}/frozone*.cpp.o"])
    FileUtils.rm_f(FROZONE_BOX_BIN)
    FileUtils.rm_f(FROZONE_HEADER_STAMP)
    FileUtils.rm_f(FROZONE_OPT_STAMP)
    puts '[frozone:clean] removed .o files and binary'
  end
end

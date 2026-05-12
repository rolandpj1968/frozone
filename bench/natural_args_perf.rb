#!/usr/bin/env ruby
# Benchmark sweep: box-first AOT with FROZONE_NATURAL_ARGS=1 vs unset.
# For each stub with a bench/expected/<name>.txt validator, build the
# binary twice (off, on), time the median of 3 runs, print a table.
#
# Output dirs (preserved for inspection):
#   /tmp/na_off/<name>{,*.cpp,binary}
#   /tmp/na_on/<name>{,*.cpp,binary}
#
# Usage: bundle exec ruby bench/natural_args_perf.rb [benchmark_name ...]

require 'open3'
require 'fileutils'

PROJECT_ROOT = File.expand_path('..', __dir__)
GEN_DIR      = File.join(PROJECT_ROOT, 'cpp', 'gen', 'box')
ONIGMO_DIR   = File.join(PROJECT_ROOT, 'vendor', 'Onigmo', '_install')
ONIGMO_INC   = File.join(ONIGMO_DIR, 'include')
ONIGMO_LIB   = File.join(ONIGMO_DIR, 'lib', 'libonigmo.a')

PARALLEL = (ENV['JOBS'] || 12).to_i
TIMEOUT  = (ENV['TIMEOUT'] || 600).to_i
RUNS     = (ENV['RUNS'] || 3).to_i

def aot(name, natural_args:)
  Dir.chdir(PROJECT_ROOT) do
    FileUtils.rm_rf(Dir.glob(File.join(GEN_DIR, "#{name}*")))
    FileUtils.rm_rf(File.join(GEN_DIR, 'class'))
    env = { 'FROZONE_CPP' => '1', 'FROZONE_BOX_FIRST' => '1' }
    env['FROZONE_NATURAL_ARGS'] = '1' if natural_args
    out, status = Open3.capture2e(env, 'bundle', 'exec', 'ruby', 'frozone.rb', '--aot', "bench/stubs/#{name}.rb")
    return false, out unless status.success?
    [true, out]
  end
end

def compile_link(name, dest_bin)
  Dir.chdir(GEN_DIR) do
    Dir.glob("#{name}*.o").each { |f| File.unlink(f) }
    cpps = Dir.glob("#{name}*.cpp").sort
    return false, 'no .cpp' if cpps.empty?
    queue = Queue.new
    cpps.each { |f| queue << f }
    errors = []
    mutex = Mutex.new
    objs = []
    Array.new(PARALLEL) do
      Thread.new do
        loop do
          cpp = (queue.pop(true) rescue break)
          obj = cpp.sub(/\.cpp\z/, '.o')
          out, status = Open3.capture2e('g++', '-std=c++20', '-O0', '-c', cpp, '-I', ONIGMO_INC, '-o', obj)
          mutex.synchronize do
            if status.success?
              objs << obj
            else
              errors << "g++ -c #{cpp}:\n#{out}"
            end
          end
        end
      end
    end.each(&:join)
    return false, errors.first unless errors.empty?
    link_args = ['g++', '-std=c++20', '-O0', *objs.sort, ONIGMO_LIB, '-lgc', '-o', dest_bin]
    out, status = Open3.capture2e(*link_args)
    return false, "link:\n#{out}" unless status.success?
    [true, nil]
  end
end

def time_one(bin)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  out, status = Open3.capture2e("timeout #{TIMEOUT} #{bin}")
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  return :timeout if status.exitstatus == 124
  return nil unless status.success?
  [elapsed, out]
end

def time_median(bin)
  times = []
  RUNS.times do
    r = time_one(bin)
    return r if r == :timeout
    return nil unless r
    times << r[0]
  end
  times.sort[RUNS / 2]
end

def build_one(name, natural_args:, dest_dir:)
  FileUtils.mkdir_p(dest_dir)
  ok, err = aot(name, natural_args: natural_args)
  return [:aot_fail, err] unless ok
  bin_path = File.join(dest_dir, name)
  ok, err = compile_link(name, bin_path)
  return [:compile_fail, err] unless ok
  Dir.glob(File.join(GEN_DIR, "#{name}*")).each { |f| FileUtils.cp_r(f, dest_dir) }
  FileUtils.cp_r(File.join(GEN_DIR, 'class'), dest_dir) if Dir.exist?(File.join(GEN_DIR, 'class'))
  [:ok, bin_path]
end

bench_names = ARGV.empty? ?
  Dir["#{PROJECT_ROOT}/bench/expected/*.txt"].map { |f| File.basename(f, '.txt') }.sort :
  ARGV
bench_names = bench_names.select { |n| File.exist?("#{PROJECT_ROOT}/bench/stubs/#{n}.rb") }

results = []
puts format("%-25s %12s %12s %8s   %s",
            "Benchmark", "Off (s)", "On (s)", "Δ", "Status")
puts "-" * 80

bench_names.each do |name|
  off_status, off_info = build_one(name, natural_args: false, dest_dir: "/tmp/na_off")
  on_status,  on_info  = build_one(name, natural_args: true,  dest_dir: "/tmp/na_on")
  if off_status != :ok || on_status != :ok
    puts format("%-25s %12s %12s %8s   off=%s on=%s",
                name, '---', '---', '---', off_status, on_status)
    next
  end
  off_t = time_median(off_info)
  on_t  = time_median(on_info)
  case
  when off_t.nil? || on_t.nil?
    puts format("%-25s %12s %12s %8s   run failed", name, '---', '---', '---')
  when off_t == :timeout || on_t == :timeout
    puts format("%-25s %12s %12s %8s   timeout", name, '---', '---', '---')
  else
    delta = on_t / off_t
    puts format("%-25s %12.3f %12.3f %7.2fx   ok",
                name, off_t, on_t, delta)
    results << { name: name, off: off_t, on: on_t }
  end
end

puts "-" * 80
if results.any?
  avg_off = results.sum { |r| r[:off] } / results.size
  avg_on  = results.sum { |r| r[:on] }  / results.size
  puts format("%-25s %12.3f %12.3f %7.2fx",
              "AVERAGE", avg_off, avg_on, avg_on / avg_off)
end

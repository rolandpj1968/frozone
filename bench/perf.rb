#!/usr/bin/env ruby
# Benchmark timing: MRI vs legacy C++ vs box-first C++ vs Crystal for all AOT benchmarks.
# Usage: bundle exec ruby bench/perf.rb [--timeout SECS] [benchmark_name ...]

require 'open3'
require 'shellwords'

DEFAULT_TIMEOUT_SECS = 600

argv = ARGV.dup
timeout_secs = DEFAULT_TIMEOUT_SECS
if (i = argv.index('--timeout'))
  timeout_secs = Integer(argv.delete_at(i + 1))
  argv.delete_at(i)
end

BENCHMARKS = Dir['bench/expected/*.txt'].map { |f| File.basename(f, '.txt') }.sort
selected = argv.empty? ? BENCHMARKS : argv

# Returns [elapsed_seconds, stdout] on success, :timeout on timeout, nil on error.
def time_cmd(cmd, timeout:)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  out, status = Open3.capture2("timeout #{timeout} #{cmd}", stdin_data: '', binmode: true)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  return :timeout if status.exitstatus == 124
  return nil unless status.success?
  [elapsed, out]
rescue Errno::ENOENT
  nil
end

# Returns median elapsed seconds, :timeout, or nil.
def time_average(cmd, runs:, timeout:)
  times = []
  runs.times do
    r = time_cmd(cmd, timeout: timeout)
    return r if r == :timeout
    return nil unless r
    times << r[0]
  end
  times.sort[times.size / 2]
end

def fmt(ms_or_sentinel)
  case ms_or_sentinel
  when :timeout then "  TIMEOUT"
  when nil      then "     N/A"
  else format("%8.1f", ms_or_sentinel * 1000)
  end
end

def fmt_ratio(mri, other)
  return "  N/A" if mri.nil? || other == :timeout || other.nil?
  format("%5.2fx", mri / other)
end

results = []
puts "(timeout: #{timeout_secs}s per run)"
puts format("%-25s %10s %10s %10s %10s   %s   %s   %s",
            "Benchmark", "MRI (ms)", "Legacy", "Box-first", "Crystal",
            "Lcy/MRI", "Box/MRI", "Cr/MRI")
puts "-" * 110

selected.each do |name|
  stub = "bench/stubs/#{name}.rb"
  next unless File.exist?(stub)

  mri = time_average("ruby #{stub}", runs: 1, timeout: timeout_secs)

  legacy_bin = "cpp/gen/legacy/#{name}"
  legacy = File.exist?(legacy_bin) ? time_average("./#{legacy_bin}", runs: 3, timeout: timeout_secs) : nil

  box_bin = "cpp/gen/box/#{name}"
  box = File.exist?(box_bin) ? time_average("./#{box_bin}", runs: 3, timeout: timeout_secs) : nil

  cr_bin = "crystal/#{name}"
  cr = File.exist?(cr_bin) ? time_average("./#{cr_bin}", runs: 3, timeout: timeout_secs) : nil

  puts format("%-25s %10s %10s %10s %10s   %s   %s   %s",
              name, fmt(mri), fmt(legacy), fmt(box), fmt(cr),
              fmt_ratio(mri, legacy), fmt_ratio(mri, box), fmt_ratio(mri, cr))
  results << { name: name, mri: mri, legacy: legacy, box: box, cr: cr }
end

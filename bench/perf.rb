#!/usr/bin/env ruby
# Benchmark timing: MRI vs C++ vs Crystal for all AOT benchmarks.
# Usage: bundle exec ruby bench/perf.rb [benchmark_name]

require 'open3'

BENCHMARKS = Dir['bench/expected/*.txt'].map { |f| File.basename(f, '.txt') }.sort
selected = ARGV.empty? ? BENCHMARKS : ARGV

def time_cmd(cmd, timeout: 120)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  out, status = Open3.capture2(cmd, stdin_data: '', binmode: true)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  return nil unless status.success?
  [elapsed, out]
rescue Errno::ENOENT
  nil
end

def time_average(cmd, runs: 3, timeout: 120)
  times = []
  runs.times do
    r = time_cmd(cmd, timeout: timeout)
    return nil unless r
    times << r[0]
  end
  times.sort[times.size / 2] # median
end

results = []
puts format("%-25s %10s %10s %10s   %s   %s", "Benchmark", "MRI (ms)", "C++ (ms)", "Crystal", "C++/MRI", "Cr/MRI")
puts "-" * 95

selected.each do |name|
  stub = "bench/stubs/#{name}.rb"
  next unless File.exist?(stub)

  # MRI
  mri = time_average("ruby #{stub}", runs: 1)

  # C++ (already compiled by bench_cpp)
  cpp_bin = "cpp/gen/#{name}"
  cpp = File.exist?(cpp_bin) ? time_average("./#{cpp_bin}", runs: 3) : nil

  # Crystal
  cr_bin = "crystal/#{name}"
  cr = File.exist?(cr_bin) ? time_average("./#{cr_bin}", runs: 3) : nil

  mri_ms = mri ? format("%8.1f", mri * 1000) : "N/A"
  cpp_ms = cpp ? format("%8.1f", cpp * 1000) : "N/A"
  cr_ms = cr ? format("%8.1f", cr * 1000) : "N/A"
  cpp_ratio = (mri && cpp) ? format("%5.2fx", mri / cpp) : "N/A"
  cr_ratio = (mri && cr) ? format("%5.2fx", mri / cr) : "N/A"

  puts format("%-25s %10s %10s %10s   %s   %s", name, mri_ms, cpp_ms, cr_ms, cpp_ratio, cr_ratio)
  results << { name: name, mri: mri, cpp: cpp, cr: cr }
end

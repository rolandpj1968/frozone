#!/usr/bin/env ruby
# Benchmark sweep: box-first AOT with opts on vs off.
# Per-stub: gen + parallel-compile + link + run × 3, report min wall.

require 'etc'
require 'fileutils'

BENCHES = %w[
  fib nbody nqueens matmul splay binarytrees blurhash fannkuchredux loops_times
]
# Iter-count overrides: keep per-bench wall under ~5s so the sweep finishes
# quickly. Same workload across opts modes — delta is still meaningful.
SCALE = {
  'fib'           => [/^3\.times/,   '1.times'],
  'nqueens'       => [/^500\.times/, '50.times'],
  'nbody'         => [/^100\.times/, '20.times'],
  'splay'         => [/^200\.times/, '40.times'],
  'binarytrees'   => [/^60\.times/,  '12.times'],
  'matmul'        => [/^20\.times/,  '4.times'],
}
ONIGMO_INCLUDE = File.expand_path('vendor/Onigmo/_install/include', __dir__ + '/..')
ONIGMO_LIB     = File.expand_path('vendor/Onigmo/_install/lib/libonigmo.a', __dir__ + '/..')
PROJECT_ROOT   = File.expand_path('..', __dir__)
LTO_FLAG = '-flto=auto'
JOBS = Etc.nprocessors

def t_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def stub_path(stub)
  base = "bench/stubs/#{stub}.rb"
  return base unless SCALE.key?(stub)
  # Scaled stub lives in a sibling subdir of bench/stubs/. Bump every
  # `require_relative '../X'` to `'../../X'` so the chain still hits
  # bench/benchmarks/ + bench/harness/. Absolute-path rewriting broke
  # gen for nbody (Frozone load-phase hung indefinitely).
  scaled_dir = "bench/stubs/.scaled"
  FileUtils.mkdir_p(scaled_dir)
  scaled = "#{scaled_dir}/#{stub}.rb"
  pat, repl = SCALE[stub]
  src = File.read(base).sub(pat, repl)
  src = src.gsub(%r{require_relative '\.\.}, "require_relative '../..")
  src = src.gsub(%r{File\.expand_path\('\.\.}, "File.expand_path('../..")
  File.write(scaled, src)
  scaled
end

def gen(stub, env)
  dir = "cpp/gen/box/#{stub}"
  FileUtils.rm_rf(dir)
  cmd_env = {'FROZONE_CPP' => '1'}.merge(env)
  t0 = t_now
  ok = system(cmd_env, "bundle exec ruby frozone.rb --aot #{stub_path(stub)}",
              out: File::NULL, err: File::NULL)
  [ok, t_now - t0, dir]
end

def compile_link(stub, dir)
  cpps = Dir.glob("#{dir}/*.cpp").sort
  return :no_cpp if cpps.empty?
  q = Queue.new
  cpps.each { |f| q << f }
  errs = []; os = []
  m = Mutex.new
  t0 = t_now
  Array.new(JOBS) do
    Thread.new do
      loop do
        cpp = q.pop(true) rescue break
        o = cpp.sub(/\.cpp\z/, '.o')
        ok = system("g++ -O2 #{LTO_FLAG} -std=c++20 -I #{ONIGMO_INCLUDE} -c #{cpp} -o #{o} 2>/dev/null")
        m.synchronize { ok ? os << o : errs << cpp }
      end
    end
  end.each(&:join)
  return :compile_fail unless errs.empty?
  bin = "#{dir}/#{stub}_box"
  ok = system("g++ -O2 #{LTO_FLAG} -std=c++20 #{os.sort.join(' ')} #{ONIGMO_LIB} -lgc -o #{bin} 2>/dev/null")
  return :link_fail unless ok
  [t_now - t0, bin]
end

def run_min(bin, n: 1)
  times = []
  n.times do
    t0 = t_now
    system("./#{bin} > /dev/null 2>&1")
    times << t_now - t0
  end
  times.min
end

Dir.chdir(PROJECT_ROOT)

modes = [
  ['on', {'FROZONE_ALL_OPTS' => '1'}],
  ['stk', {'FROZONE_ALL_OPTS' => '1', 'FROZONE_STACK_BLOCKS' => '1'}],
  ['sub', {'FROZONE_ALL_OPTS' => '1', 'FROZONE_STACK_BLOCKS' => '1', 'FROZONE_BLOCK_SUBCLASS' => '1'}],
]
rows = []

modes.each do |label, env|
  BENCHES.each do |stub|
    row = { stub: stub, mode: label }
    print "[#{label}] #{stub.ljust(12)} gen..."; STDOUT.flush
    ok, gen_t, dir = gen(stub, env)
    unless ok
      row[:status] = 'GEN_FAIL'
      puts " GEN_FAIL"
      rows << row; next
    end
    row[:gen] = gen_t
    print " compile..."; STDOUT.flush
    result = compile_link(stub, dir)
    if result.is_a?(Symbol)
      row[:status] = result.to_s.upcase
      puts " #{result.to_s.upcase}"
      rows << row; next
    end
    cl_t, bin = result
    row[:compile] = cl_t
    print " run..."; STDOUT.flush
    row[:run] = run_min(bin)
    row[:status] = 'OK'
    puts " gen=%.1fs compile=%.1fs run=%.2fs" % [gen_t, cl_t, row[:run]]
    rows << row
  end
end

puts
puts "Results"
puts "%-12s %-4s %8s %8s %8s %s" % ['bench', 'mode', 'gen', 'compile', 'run', 'status']
puts '-' * 60
rows.each do |r|
  puts "%-12s %-4s %8s %8s %8s %s" % [
    r[:stub], r[:mode],
    r[:gen]     ? '%.1fs' % r[:gen]     : '-',
    r[:compile] ? '%.1fs' % r[:compile] : '-',
    r[:run]     ? '%.2fs' % r[:run]     : '-',
    r[:status]
  ]
end

puts
puts "Deltas (run only)"
on  = rows.select { |r| r[:mode] == 'on'  && r[:run] }
stk = rows.select { |r| r[:mode] == 'stk' && r[:run] }
sub = rows.select { |r| r[:mode] == 'sub' && r[:run] }
BENCHES.each do |b|
  n = on.find  { |r| r[:stub] == b }
  s = stk.find { |r| r[:stub] == b }
  u = sub.find { |r| r[:stub] == b }
  next unless n && s && u
  ds = (s[:run] / n[:run] - 1.0) * 100
  du = (u[:run] / n[:run] - 1.0) * 100
  puts "  %-15s on=%.2fs stk=%.2fs sub=%.2fs  stk:%+.1f%% sub:%+.1f%%" % [
    b, n[:run], s[:run], u[:run], ds, du,
  ]
end
puts
puts "Compile-time and final-binary-size (last mode = sub)"
rows.select { |r| r[:mode] == 'sub' }.each do |r|
  dir = "cpp/gen/box/#{r[:stub]}"
  bin = "#{dir}/#{r[:stub]}_box"
  bin_size_mb = File.exist?(bin) ? File.size(bin) / 1024.0 / 1024.0 : 0
  puts "  %-15s compile=%.1fs run=%.2fs binMB=%.1f" % [r[:stub], r[:compile], r[:run] || 0.0, bin_size_mb]
end

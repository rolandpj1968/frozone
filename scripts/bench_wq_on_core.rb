#!/usr/bin/env ruby
# Per-file MRI-WQ parse timing on lib/core/4.0/*.rb. Compare against
# frozone_box's boot-trace per-file numbers (the smoke test under
# FROZONE_BOX_BOOT_TRACE=1 + FROZONE_TRACE_LOAD=1) to find out where
# the slowdown is — is the WQ parser algorithmically slow (MRI also
# slow), or did the box-first AOT make it slow (MRI fast, compiled slow)?

require_relative '../lib/frozone/vm/wq_parser'

files = Dir[File.expand_path('../lib/core/4.0/*.rb', __dir__)].sort
total = 0.0
files.each do |f|
  src = File.read(f)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  parser = Frozone::Vm::WqParser.new(src, false, filepath: f)
  _ast = parser.ast(raise_syntax_errors: false)
  dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  total += dt
  printf "%8.1f ms  %s\n", dt * 1000, File.basename(f)
end
printf "----\n%8.1f ms  TOTAL\n", total * 1000

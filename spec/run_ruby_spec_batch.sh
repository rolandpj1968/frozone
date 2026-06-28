#!/usr/bin/env bash
# Run multiple ruby-spec files through mspec under bin/frozone-cpp in ONE
# invocation, amortizing the ~40s startup across the batch. Same driver MRI
# uses (spec/mspec_runner.rb + real mspec gem), so results mean the same
# thing MRI's `bundle exec rake language` would mean.
#
# Usage:
#   ./spec/run_ruby_spec_batch.sh spec/ruby-spec/language/and_spec.rb [...]
#
# Knows which gems/stdlibs to inject into $LOAD_PATH so the mspec gem and
# its `require 'fileutils'`/`require 'rbconfig'` chain resolve (see vm.rb
# init_globals — RUBYLIB/GEM_HOME/FROZONE_LOAD_PATHS are honored only when
# Gem::Specification is empty, i.e. when running bin/frozone-cpp).

set -u
MSPEC_LIB=$(bundle show mspec)/lib
RUBY_STDLIB=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
RUBY_ARCH=$(ruby -e 'puts RbConfig::CONFIG["archdir"]')
export FROZONE_LOAD_PATHS="$MSPEC_LIB:$RUBY_STDLIB:$RUBY_ARCH"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <spec.rb> [spec2.rb ...]" >&2
  exit 2
fi

ABS=()
for s in "$@"; do ABS+=("$(realpath "$s")"); done

t0=$(date +%s.%N)
bin/frozone-cpp spec/mspec_runner.rb "${ABS[@]}"
rc=$?
t1=$(date +%s.%N)
awk -v t0="$t0" -v t1="$t1" -v rc="$rc" -v n="${#ABS[@]}" 'BEGIN{
  printf "\n[batch] %d specs in %.1fs (exit=%d)\n", n, t1-t0, rc
}'
exit $rc

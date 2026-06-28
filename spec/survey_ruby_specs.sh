#!/usr/bin/env bash
# Survey: run every spec in a directory through bin/frozone-cpp's mspec
# driver, in parallel. Each spec is a separate process so parallelism is
# trivial. Defaults to JOBS=Etc.nprocessors (matches the build harness).
#
# Usage:
#   ./spec/survey_ruby_specs.sh                # language/*_spec.rb
#   ./spec/survey_ruby_specs.sh core/integer   # core/integer/*_spec.rb
#   JOBS=4 ./spec/survey_ruby_specs.sh
#
# Output columns: <elapsed>s <status> <name> <mspec-summary>
# Status: OK (clean) / OK* (finished, some F/E) / STUB:<name> /
#         TIMEOUT (180s) / ABORT (other nonzero exit) / UNK.

set -u
DIR="${1:-language}"
SPECS_DIR="spec/ruby-spec/$DIR"
if [ ! -d "$SPECS_DIR" ]; then
  echo "no such dir: $SPECS_DIR" >&2
  exit 2
fi

MSPEC_LIB=$(bundle show mspec)/lib
RUBY_STDLIB=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
RUBY_ARCH=$(ruby -e 'puts RbConfig::CONFIG["archdir"]')
export FROZONE_LOAD_PATHS="$MSPEC_LIB:$RUBY_STDLIB:$RUBY_ARCH"

JOBS=${JOBS:-$(ruby -retc -e 'puts Etc.nprocessors')}

run_one() {
  local spec="$1"
  local name=$(basename "$spec" .rb)
  local abs=$(realpath "$spec")
  local t0=$(date +%s.%N)
  local out
  out=$(timeout 180 bin/frozone-cpp spec/mspec_runner.rb "$abs" 2>&1)
  local rc=$?
  local t1=$(date +%s.%N)
  local elapsed=$(awk -v t0="$t0" -v t1="$t1" 'BEGIN{printf "%.0f", t1-t0}')
  local stub=$(echo "$out" | grep -oE 'intrinsic [a-z_]+ not impl' | head -1 | awk '{print $2}')
  local summary=$(echo "$out" | grep -E 'examples,.*expectations' | head -1)
  local status
  if [ $rc -eq 124 ]; then status="TIMEOUT"
  elif [ -n "$summary" ]; then
    if echo "$summary" | grep -q '0 failures, 0 errors'; then status="OK"
    else status="OK*"
    fi
  elif [ -n "$stub" ]; then status="STUB:$stub"
  elif [ $rc -ne 0 ]; then status="ABORT"
  else status="UNK"
  fi
  printf "%3ss  %-22s  %-30s  %s\n" "$elapsed" "$status" "$name" "$summary"
}
export -f run_one

specs=("$SPECS_DIR"/*_spec.rb)
echo "[survey] ${#specs[@]} specs, JOBS=$JOBS" >&2
printf '%s\0' "${specs[@]}" | xargs -0 -P "$JOBS" -I {} bash -c 'run_one "$@"' _ {}

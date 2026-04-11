#!/bin/bash
# A/B test: normal interpreter vs --flatten on ruby-spec files.
# Usage: bash bench/tests/ab_flatten.sh [spec_dir]
#
# Runs each .rb file through both modes, diffs stdout.
# Reports PASS/FAIL per file.

SPEC_DIR="${1:-spec/ruby-spec/language}"
PASS=0
FAIL=0
ERROR=0

for f in "$SPEC_DIR"/*.rb; do
  base=$(basename "$f" .rb)

  # Normal mode (30s timeout)
  timeout 30 bundle exec ruby frozone.rb "$f" > /tmp/ab_normal.txt 2>/dev/null
  normal_rc=$?

  # Flatten mode (30s timeout)
  timeout 30 bundle exec ruby frozone.rb --flatten "$f" > /tmp/ab_flatten.txt 2>/dev/null
  flatten_rc=$?

  if [ $normal_rc -ne 0 ] && [ $flatten_rc -ne 0 ]; then
    # Both errored — skip (spec might need mspec infrastructure)
    continue
  fi

  if [ $normal_rc -ne 0 ] || [ $flatten_rc -ne 0 ]; then
    echo "ERROR $base (normal=$normal_rc flatten=$flatten_rc)"
    ERROR=$((ERROR + 1))
    continue
  fi

  if diff -q /tmp/ab_normal.txt /tmp/ab_flatten.txt > /dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    echo "FAIL $base"
    diff /tmp/ab_normal.txt /tmp/ab_flatten.txt | head -5
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS pass, $FAIL fail, $ERROR error"

#!/usr/bin/env bash
# Sync (or check) MRI encoding table source files against ruby/ruby HEAD.
# Usage:
#   ./tool/sync-mri-encoding.sh          — overwrite enc/trans/ and tool/transcode-tblgen.rb
#   ./tool/sync-mri-encoding.sh --check  — report diffs only, exit 1 if there are any

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_ONLY=false
if [[ "${1-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Sparse-cloning ruby/ruby HEAD (enc/trans + tool) ..."
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/ruby/ruby.git "$TMPDIR/ruby-sparse" -q
git -C "$TMPDIR/ruby-sparse" sparse-checkout set enc/trans tool

COMMIT="$(git -C "$TMPDIR/ruby-sparse" log -1 --format="%H %as")"
echo "ruby/ruby HEAD: $COMMIT"

if $CHECK_ONLY; then
  echo ""
  DIFFS=0
  diff -rq "$TMPDIR/ruby-sparse/enc/trans" "$REPO_ROOT/enc/trans" && true; DIFFS=$((DIFFS + $?))
  diff -q  "$TMPDIR/ruby-sparse/tool/transcode-tblgen.rb" "$REPO_ROOT/tool/transcode-tblgen.rb" && true; DIFFS=$((DIFFS + $?))
  if [[ $DIFFS -eq 0 ]]; then
    echo "No changes."
  else
    echo ""
    echo "Files differ — run without --check to sync."
    exit 1
  fi
else
  rsync -a --delete "$TMPDIR/ruby-sparse/enc/trans/" "$REPO_ROOT/enc/trans/"
  cp "$TMPDIR/ruby-sparse/tool/transcode-tblgen.rb" "$REPO_ROOT/tool/transcode-tblgen.rb"
  echo "Synced from ruby/ruby $COMMIT"
  echo "Remember to update the commit SHA in README.md."
fi

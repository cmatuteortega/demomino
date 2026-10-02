#!/usr/bin/env bash
# Run the plain-Lua unit tests (no Love2D needed). Usage: tests/run.sh
# Uses luajit (what LÖVE runs on) if present, else lua5.1.
set -uo pipefail
cd "$(dirname "$0")/.."
LUA="$(command -v luajit || command -v lua5.1 || true)"
[ -n "$LUA" ] || { echo "need luajit or lua5.1"; exit 2; }
status=0
for t in tests/test_*.lua; do
  echo "== $t"
  # map generation logs progress with print(); keep test output readable
  out="$("$LUA" "$t" 2>&1)"; rc=$?
  printf '%s\n' "$out" | grep -E "^(  PASS|  FAIL|[A-Z][a-zA-Z.:_ /]*$|[0-9]+ passed|luajit:|lua5.1:|\s+\[C\]|\s+tests/)" || true
  [ $rc -eq 0 ] || { echo "   -> exit code $rc"; status=1; }
done
[ $status -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $status

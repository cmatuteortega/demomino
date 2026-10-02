#!/usr/bin/env bash
# Usage: [GOLDEN_MODE=fuzz|scenario] tests/golden/run.sh <out-file> [seed] [steps]
# Runs the game under Xvfb with scripted fuzz input and writes a state trace.
# Compare traces from before/after a refactor with `diff`.
set -euo pipefail
HARNESS="$(cd "$(dirname "$0")" && pwd)"
# GOLDEN_REPO: game checkout to run (default: this one). Lets the current
# harness replay a baseline worktree.
REPO="$(realpath "${GOLDEN_REPO:-$HARNESS/../..}")"
OUT="$(realpath -m "${1:?out file}")"
SEED="${2:-1}"; STEPS="${3:-1500}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for f in "$REPO"/*; do
  name="$(basename "$f")"
  case "$name" in main.lua|conf.lua) continue;; esac
  ln -s "$f" "$WORK/$name"
done
ln -s "$REPO/main.lua" "$WORK/game_main.lua"
ln -s "$REPO/conf.lua" "$WORK/game_conf.lua"
cp "$HARNESS/conf.lua" "$WORK/conf.lua"
cp "$HARNESS/harness.lua" "$WORK/main.lua"
rm -f "$OUT"
mkdir -p "$WORK/xdg"
cd "$WORK"
# LP_NUM_THREADS=1 keeps llvmpipe from spawning a thread per core in every run
XDG_DATA_HOME="$WORK/xdg" ALSOFT_DRIVERS=null LP_NUM_THREADS=1 \
GOLDEN_MODE="${GOLDEN_MODE:-fuzz}" GOLDEN_SEED="$SEED" GOLDEN_STEPS="$STEPS" GOLDEN_OUT="$OUT" \
  timeout -s KILL "${GOLDEN_TIMEOUT:-900}" xvfb-run -a -s "-screen 0 1280x720x24" love . >"${GOLDEN_LOG:-$WORK/love.log}" 2>&1 || true
if [ ! -s "$OUT" ]; then echo "harness produced no trace"; tail -30 "${GOLDEN_LOG:-$WORK/love.log}"; exit 1; fi
if grep -q "^ERROR" "$OUT"; then
  grep -A40 "^ERROR" "$OUT"; exit 1
fi
if ! grep -q "^PHASES" "$OUT"; then
  echo "TRACE TRUNCATED (crash/exit) at:"; tail -2 "$OUT" | cut -c1-200
  tail -15 "${GOLDEN_LOG:-$WORK/love.log}"; exit 1
fi
grep "^PHASES" "$OUT"

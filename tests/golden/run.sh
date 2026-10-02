#!/usr/bin/env bash
# Usage: [GOLDEN_MODE=fuzz|scenario] tests/golden/run.sh <out-file> [seed] [steps]
# Runs the game under Xvfb with scripted fuzz input and writes a state trace.
# Compare traces from before/after a refactor with `diff`.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
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
cp "$REPO/tests/golden/conf.lua" "$WORK/conf.lua"
cp "$REPO/tests/golden/harness.lua" "$WORK/main.lua"
rm -f "$OUT"
mkdir -p "$WORK/xdg"
cd "$WORK"
XDG_DATA_HOME="$WORK/xdg" ALSOFT_DRIVERS=null \
GOLDEN_MODE="${GOLDEN_MODE:-fuzz}" GOLDEN_SEED="$SEED" GOLDEN_STEPS="$STEPS" GOLDEN_OUT="$OUT" \
  timeout -s KILL "${GOLDEN_TIMEOUT:-900}" xvfb-run -a -s "-screen 0 1280x720x24" love . >"${GOLDEN_LOG:-$WORK/love.log}" 2>&1 || true
if [ ! -s "$OUT" ]; then echo "harness produced no trace"; tail -30 "${GOLDEN_LOG:-$WORK/love.log}"; exit 1; fi
grep -E "^(ERROR|PHASES)" "$OUT" || { echo "TRACE TRUNCATED (crash/exit) at:"; tail -2 "$OUT" | cut -c1-200; tail -15 "${GOLDEN_LOG:-$WORK/love.log}"; }

# Golden-master harness

Drives the real game (LÖVE 11.x under Xvfb) with deterministic input and
writes a per-step trace of `gameState`, so a refactor can be checked for
behaviour changes by diffing traces.

```bash
tests/golden/run.sh out.txt [seed] [steps]          # fuzz from the title screen
GOLDEN_MODE=scenario tests/golden/run.sh out.txt 1  # enter every node type, fuzz each
GOLDEN_MODE=resetleak tests/golden/run.sh out.txt 1 # state that survives NEW GAME
```

Needs `love` and `xvfb-run` (`apt-get install love xvfb`). Exits non-zero on
any Lua error or crash, so it doubles as a smoke test (CI runs it).

## How it stays deterministic

- `love.timer.getTime`, `os.time` and `os.clock` are frozen to a virtual clock
  advanced 1/60 s per frame; `math.random` and `love.math` are seeded, and the
  cosmetic generator (`RNG.cosmetic`, game/rng.lua) seeds from the frozen `os.time`.
- The fuzzer uses its own LCG so it never consumes the game's random stream.
- `conf.lua` here wraps the game's `conf.lua` to match the installed LÖVE
  version; otherwise LÖVE shows a blocking "made for 12.0" dialog.
- Game code must not let `pairs()` order over string keys influence random
  draws (LuaJIT seeds string hashing per process). Use `Map.sortedPairs` or
  sort first. If two runs of the same seed differ, that is the first suspect.

## Trace format

One line per step: `<n> <action> | <gamePhase> | <key>:<hash> ...` listing
every top-level `gameState` key whose deep hash changed that step, then a
final `PHASES` line with steps spent per phase. `ERROR <traceback>` marks a
Lua error.

## Checking a refactor

```bash
git worktree add /tmp/base <commit-before>
GOLDEN_REPO=/tmp/base GOLDEN_MODE=scenario tests/golden/run.sh /tmp/a.txt 1
GOLDEN_MODE=scenario tests/golden/run.sh /tmp/b.txt 1
diff /tmp/a.txt /tmp/b.txt   # empty for a pure refactor
```

Use the same harness for both sides (`GOLDEN_REPO` only swaps the game
code). Several seeds of both modes give much better coverage than one.

## Other knobs

| Variable | Effect |
| --- | --- |
| `GOLDEN_COVERAGE=1` | write `<out>.cov`: functions that ran, by definition line. Turns the JIT off, which perturbs some float results, so never diff a coverage trace against a normal one |
| `GOLDEN_SCENARIOS` | comma list limiting scenario mode, e.g. `gamble,deal` |
| `GOLDEN_PIXELS=1` | draw at the end of each step and append `px:<md5>` of the rendered frame, to check renderer refactors |
| `GOLDEN_DRAW_ALL=1` | draw every frame instead of only before input (slow) |
| `GOLDEN_SCENARIO_STEPS` | fuzz steps per scenario (default 110; combat ×3) |
| `GOLDEN_TIMEOUT` | seconds before the run is killed (default 900) |
| `GOLDEN_LOG` | keep LÖVE's stdout/stderr at this path |
| `GOLDEN_DUMP_STEP` + `GOLDEN_DUMP_KEY` | dump one `gameState` key at a step to `<out>.dump` |
| `GOLDEN_PROFILE=1` | per-step timings on stderr |

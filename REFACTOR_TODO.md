# Refactor hand-off: remaining work

Follow-up list from the refactor session on branch `ccr-26e627f1-3ql5so`
(last commit `7faeee6`). Everything listed under "Done" is pushed. CI
(`tests.yml` and `android.yml`) is green on that commit.

## Done (for context)

| Commit | What |
| --- | --- |
| `48410e9` | Golden-master harness; map/shop generation made reproducible from the seed (sorted iteration instead of `pairs`) |
| `d6574a1` | Sprite loaders moved to `ui/sprites.lua`; data-driven domino loader |
| `d6c49b3` | `Touch.pressed`/`Touch.released` split into handler tables; shared workbench helpers; chain-fit logic moved to `Validation` |
| `825f33b`, `2705eb7` | Harness: target-aware fuzzing, coverage, pixel hashes, reset-leak mode, virtual-clock audio |
| `10dba91` | Bug fixes: Enhance upgrades lost on Continue, boss flags leaking after an abandoned fight, save float precision / inf/nan, workbench reset. Unit tests and CI |
| `5bde442` | `UI.Layout.getTileSpriteScale()` replaces 29 copies of the scale formula |
| `da08140` | `main.lua` split into `ui/dialogue_flow.lua`, `ui/hud_animation.lua`, `ui/scoring_sequence.lua`, `ui/tile_fire.lua`, `game/casino.lua` |
| `7faeee6` | CI tolerates `love`'s man-page postinst failure |

## Environment setup for the next session

The cloud container doesn't ship these; install them first:

```bash
apt-get install -y luajit love xvfb   # love's postinst may fail on missing man pages; the binary still works
tests/run.sh                           # unit tests (seconds)
GOLDEN_MODE=scenario tests/golden/run.sh /tmp/s1.txt 1   # smoke run (~2 min)
```

Lessons from the last session:
- `run.sh` already sets `LP_NUM_THREADS=1`. Without it, parallel runs
  oversubscribe the CPU through llvmpipe threads and become 10× slower.
- Never `pkill -f <pattern>` from a command line that contains the same
  pattern: it kills its own shell. Use `pkill -x love` or the bracket trick
  (`pkill -f "run.s[h]"`).
- Don't edit files in a checkout while golden runs against it are still
  starting. Each run loads the game when it starts. Record from `git worktree`s
  (`GOLDEN_REPO=<worktree>`).
- Coverage runs (`GOLDEN_COVERAGE=1`) turn the JIT off, which perturbs float
  results. Use them only to see what ran; never diff them against normal
  traces.

### Verify any refactor

```bash
git worktree add /tmp/base HEAD            # before your change
# ... make the change ...
for s in 1 2; do
  GOLDEN_REPO=/tmp/base GOLDEN_MODE=scenario tests/golden/run.sh /tmp/a_s$s.txt $s &
  GOLDEN_MODE=scenario tests/golden/run.sh /tmp/b_s$s.txt $s &
  GOLDEN_REPO=/tmp/base tests/golden/run.sh /tmp/a_f$s.txt $s 1500 &
  tests/golden/run.sh /tmp/b_f$s.txt $s 1500 &
done; wait
for t in s1 s2 f1 f2; do cmp /tmp/a_$t.txt /tmp/b_$t.txt && echo "$t identical"; done
```

Add `GOLDEN_PIXELS=1` to both sides when the change touches drawing.

## Remaining work, highest value first

### 1. Move game rules out of `ui/touch.lua` (~7,860 lines)
Input handling still owns the economy and the shop, contract and workbench
actions:

- `Touch.purchaseTool`, `purchaseShopPlacedTile`, `purchaseContract`, `purchaseArtifactsShopTool(Direct)`
- `Touch.sellPawnTile`, `sellToolFromInventory`
- `Touch.confirmEnhance`, `confirmFusion`, `confirmFlatten`, `confirmMitosis`
- `Touch.rerollShopTiles`, `rerollArtifactsShopTools`, `rerollFusionHand`
- `Touch.signSelectedContract`, `sealSelectedContract`, `acceptDeal`, `acceptArtifactDeal`
- `Touch.useToolDirectly`, `Touch.checkGameEnd`, `Touch.routeToNode` (~376 lines)

Approach: for each action, split the pure rule from its animation and sound
calls. The pure part covers cost checks, collection and deck mutation, coin
changes and contract state. Move it into `game/shop.lua`,
`game/workbench.lua` and `game/run.lua`, which return results that `touch.lua`
then animates. Add unit tests for the pure halves. This is judgement work,
not a mechanical move; do one screen per commit and verify each with the
golden traces.

### 2. Single run-state factory (replace field-by-field resets)
`love.load`, `resetGameToFresh`, `initializeGame`, `initializeCombatRound`
and `UI.TitleScreen.continueGame` each reset overlapping fields by hand.
`GOLDEN_MODE=resetleak` lists what still survives NEW GAME. Today the
survivors are harmless (shop offers and dialogue states rebuilt on entry,
cached UI values), but the pattern keeps producing bugs. Split `gameState`
into run-scoped, round-scoped and persistent/settings layers, each with a
constructor, and have resets replace the whole layer. Re-run `resetleak`
afterwards. It should list only presentation state and the freshly
generated map.

### 3. Give cosmetic randomness its own generator
Gameplay (deck shuffles, shop rolls, map) and cosmetic effects (coin
offsets in `ui/hud_animation.lua`, chip-loop and typewriter sound picks in
`ui/audio.lua`, renderer shake, eye blinks) share `love.math.random`. Worse,
`updateChipLoopSound` draws when a sound finishes in *real* time, so
gameplay randomness depends on audio timing and seeded runs aren't fully
reproducible on real devices. Fix: use a `love.math.newRandomGenerator()`
for cosmetics, or one for gameplay seeded from the map seed. This changes
the RNG streams, so traces will differ. Check that diffs are limited to
random outcomes, not crashes or phase changes.

### 4. Split large renderer functions (`ui/renderer.lua`, ~8,400 lines)
The largest functions are `drawScore` (519 lines), `drawCollectionMenu` (322),
`drawDomino` (313), `drawTooltip` (285), `drawTitlePlayModal` (199) and
`drawTilesMenu` (162). The renderer also writes hit-test bounds into
`gameState` (`*Bounds`, `*Button`), which `touch.lua` reads back. Long term,
compute rects in `ui/layout.lua` and have both sides read them. Verify every
change with `GOLDEN_PIXELS=1`.

### 5. Map fog-of-war performance
`ui/renderer.lua` draws the fog as about 18,000 4×4 rectangles per frame,
with a distance check per lit candle, and it's the slowest thing in the game
headless. Replace it with a shader (one full-screen quad with candle
positions as uniforms), or at least compare squared distances and draw into
a low-res canvas. Pixel hashes will change slightly, so compare screenshots
by eye.

### 6. Smaller cleanups
- [ ] `game/map.lua` has 39 debug `print` calls run during every map
      generation. Remove them or put them behind a debug flag.
- [ ] `lib/suit` is vendored but never `require`d. Delete it, or note why it's kept.
- [ ] CLAUDE.md "Tile Connection Logic" still mentions
      `Validation.findValidChain()`, which doesn't exist.
- [ ] Renderer `eyeBlinkStates` is keyed by `tile.id` (e.g. `"3-5"`), so
      duplicate tiles share blink state. Key by `instanceId`.
- [ ] `conf.lua` declares `t.version = "12.0"`; stock LÖVE 11.x shows a
      blocking compatibility dialog. Fine for the Android 12.0 build, but
      desktop players on 11.5 see it.
- [ ] Most cross-module functions are still globals (`updateCoins`,
      `initializeDialogue`, `getToolAt`, sprite tables, ...). Moving them into
      module tables would make dependencies explicit; do it gradually.
- [ ] `love.update`'s menus branch (~110 lines covering
      tiles/artifacts/contracts/deal/restore) could use the same per-phase
      handler table as `Touch.released`.
- [ ] `Save.deserialize` runs the save file with `loadstring`. Fine for local
      saves, but a sandboxed `setfenv(f, {})` would stop a tampered save from
      running code.

### 7. Harness coverage gaps
These handlers never ran during golden runs, so their extraction was
verified only as a mechanical move. Add targeted scenarios (for example,
pre-fill a slot, then drag from it):
`releaseDropHandlers.fusionHand/mitosisHand/flattenHand/artifactsShopHand/artifactsShopBoard/flattenSlot/mitosisSlot/fusionSlot`,
`Touch.rerollFusionHand/rerollFlattenHand/rerollMitosisHand/rerollShopTiles`,
`showWorkbenchWarning`, `returnSlotTileToHand`. Check with
`GOLDEN_COVERAGE=1` and the definition-line report; see `tests/golden/README.md`.

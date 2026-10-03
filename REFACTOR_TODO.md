# Refactor hand-off: remaining work

Follow-up list for the refactor on PR #25. The first session (branch
`ccr-26e627f1-3ql5so`, up to `3220184`) and the second session (branch
`ccr-429268fc-hu0li8`, on top of it) are listed under "Done".

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

Second session (each pure refactor verified byte-identical on 2 scenario + 2 fuzz seeds):

| Commit | What |
| --- | --- |
| `ed7de51` | `game/workbench.lua`: enhance / fusion / flatten / mitosis / pawn rules out of `touch.lua` (+ `tests/test_workbench.lua`) |
| `1418799` | `game/shop.lua`: tool / tile / contract purchases, renewal, tool selling, deal nodes (+ `tests/test_shop.lua`); one `showShopError` helper |
| `e7b2f44` | `game/run.lua`: round reward and win/loss progression (+ `tests/test_run.lua`); `Touch.routeToNode` → `nodeEntryHandlers` |
| `21c3648` | Map generation logging behind `Map.DEBUG`; CLAUDE.md `findValidChain` reference fixed |
| `ff455b1` | Cosmetic randomness on its own generator (`game/rng.lua`, `RNG.cosmetic`). Changes RNG streams by design |
| `3a3d794` | Eye-blink state keyed by `instanceId` |
| `315a232` | Save/settings files loaded as sandboxed data (no bytecode, empty env) |
| `451a2bf` | `love.update` node-menu branch → `updateNodeMenu` with lookup tables |

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

### 1. Game rules out of `ui/touch.lua` — mostly done
Workbench, shop, contract, deal and round-end rules now live in
`game/workbench.lua`, `game/shop.lua` and `game/run.lua` with unit tests.
`Touch.useToolDirectly` already delegated to `Tools.canUse` / `Tools.use`.
What's left is small:
- The rerolls (`rerollShopTiles`, `rerollArtifactsShopTools`,
  `rerollFusionHand`, `rerollWorkbenchHand`) are mostly animation. Their rule
  is "pay `shopRerollCost` / 1 coin, draw new offers", and the offers already
  come from `Domino.generateShopTileOffers` / `Tools.generateRandomToolOffers`.
- Behaviour quirks kept as-is during the move, worth a look:
  `Run.DISCARDS_FOR_REWARD` is a fixed 2, not `maxDiscardsPerRound`.
  `Workbench.sell` matches `tileType` raw, but enhance/flatten treat nil as
  `"normal"`, while `Domino.clone` defaults to `"regular"`. Fusion matches on
  values only, so it can consume a relic copy of the same pips.

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

### 3. ~~Give cosmetic randomness its own generator~~ — done (`ff455b1`)
Cosmetic draws use `RNG.cosmetic` (game/rng.lua), and gameplay keeps
`love.math.random`. Remaining edge: `Dialogue.getRandomPhrase` counts as
cosmetic, but the chosen line's length sets how long dialogue stays up.
That shows in traces but not in gameplay outcomes.

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
- [x] `game/map.lua` debug prints are behind `Map.DEBUG`.
- [ ] `lib/suit` is vendored but never `require`d. Delete it, or note why it's kept
      (not done: needs the owner's OK).
- [x] CLAUDE.md "Tile Connection Logic" no longer mentions `findValidChain`.
- [x] Renderer `eyeBlinkStates` is keyed by `instanceId`.
- [ ] `conf.lua` declares `t.version = "12.0"`; stock LÖVE 11.x shows a
      blocking compatibility dialog. Fine for the Android 12.0 build, but
      desktop players on 11.5 see it.
- [ ] Most cross-module functions are still globals (`updateCoins`,
      `initializeDialogue`, `getToolAt`, sprite tables, ...). Moving them into
      module tables would make dependencies explicit; do it gradually.
- [x] `love.update`'s menus branch is `updateNodeMenu(dt)`. The rest of
      `love.update` is still an if/elseif chain over phases.
- [x] Save and settings files load through a sandboxed `loadDataChunk`.

### 7. Harness coverage gaps
These handlers never ran during golden runs, so their extraction was
verified only as a mechanical move. Add targeted scenarios (for example,
pre-fill a slot, then drag from it):
`releaseDropHandlers.fusionHand/mitosisHand/flattenHand/artifactsShopHand/artifactsShopBoard/flattenSlot/mitosisSlot/fusionSlot`,
`Touch.rerollFusionHand/rerollFlattenHand/rerollMitosisHand/rerollShopTiles`,
`showWorkbenchWarning`, `returnSlotTileToHand`. Check with
`GOLDEN_COVERAGE=1` and the definition-line report; see `tests/golden/README.md`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a domino-based roguelike deckbuilding game written in Lua using the LÖVE (Love2D) framework. Players place domino tiles on a board to score points, progress through a procedural map, and build their tile collection across multiple runs.

## Running the Game
- Run the game with Love2D: `love .` (requires Love2D/LÖVE framework installed)
- The game is designed to work on desktop and mobile platforms (Android/iOS)

## Architecture

### Core Game Structure
The game follows a modular Lua architecture with clear separation of concerns:

- **main.lua**: Entry point with Love2D callbacks (love.load, love.update, love.draw), the initial `gameState`, new-run/round initialization (`resetGameToFresh`, `initializeGame`, `initializeCombatRound`, round intro) and app pause handling. `TARGET_SCORE` and `BASE_HAND_SIZE` constants live at the top. The other former main.lua systems are separate files that still define the same global functions: `ui/dialogue_flow.lua` (tutorial + dialogue orchestration), `ui/hud_animation.lua` (`updateScore`, `updateCoins`, coin/tool HUD animations), `ui/scoring_sequence.lua` (tile-by-tile scoring after PLAY), `ui/tile_fire.lua` (Lucifer hand fire, Beelzebub burn; `TileFire.update*`), `game/casino.lua` (gamble node)
- **game/**: Core game logic modules
  - **domino.lua**: Domino tile creation, manipulation, and utilities. Authoritative source for tile connection logic (`Domino.canConnect`), odd/even special tiles, fusion system, sprite caching, deck generation (standard 28-tile 0-0 to 6-6 plus special tiles)
  - **hand.lua**: Player hand management — tile drawing with staggered animations, selection, idle floating animations, arc-trajectory sorting, drag-and-drop, discard animations, hand reordering
  - **board.lua**: Board state management — dynamic scaling for tile chains, tile positioning (`arrangePlacedTiles`), hit detection (`getTileAt`), bounds calculation. Uses `gameState.placedTiles` as the active tile array
  - **scoring.lua**: Score calculation with breakdowns — tile value summation, obsidian multipliers, double bonuses, contract integration hooks, high score tracking
  - **validation.lua**: Chain validation (`validateSequentialPlacement`, `canConnectTiles`) and chain-end placement helpers used when dropping a tile on the board (`canFitAtEnd`, `orientForEnd`, `canConnectBothWays`); all delegate odd/even logic to `Domino.canConnect`
  - **challenges.lua**: Challenge type definitions (anchor tiles, max tiles, banned numbers), per-challenge state management, modular effect system applied at placement validation
  - **contracts.lua**: 6 contract types with scoring modifiers (Lucky Five, Greedy, Perfect Loop), shop generation, dual active contract limit (max 2 active)
  - **tools.lua**: 9 tool/artifact types (Tile Injector, Transformer, etc.), shop generation, usage/cost tracking, 3-tool max. Tool sprites appear as persistent dice on the board
  - **dialogue.lua**: Dialogue text management, trigger types (on_enter, idle, action), text wrapping, typewriter effect support for all screens
  - **demon_data.lua**: Demon name pools (boss vs regular), description data, icon sprite associations for 22 demon characters
  - **map.lua**: DAG-based procedural map generation — 8-12 depth levels, 5-6 possible paths, camera scrolling, candle lighting, fog of war, node-based progression. Generation is reproducible from `map.seed`: iterate string-keyed tables with `Map.sortedPairs`, never `pairs`, anywhere random numbers are drawn (LuaJIT randomizes `pairs` order per process)
  - **boss_behaviors.lua**: Per-boss hooks (`onBeforeScore`, `onCombatEnd`, ...) keyed by demon name
  - **drawbacks.lua**: Tile penalties offered with deal-node contracts
  - **i18n.lua**: UI string tables (en/es) and the current language
  - **save.lua**: Save/load system — full game state serialization, map persistence, tile collection, settings (music/sfx/tutorial), stats tracking (bestRound persists across all runs). `Save.tileToData`/`Save.tileFromData` define which tile properties persist; add new permanent tile properties there
- **ui/**: User interface and interaction modules
  - **layout.lua**: Responsive layout calculations and screen positioning — hand area, board area, button positions, tool stack positions, mobile vs desktop detection
  - **renderer.lua**: Drawing and visual representation of all game elements (~8400 lines). 74 draw functions covering dominoes, board, hand, score formula, menus, dialogue, tool sprites, CRT shader
  - **touch.lua**: Input handling for mouse/touch (~7800 lines) — drag-and-drop for tiles and tools, double-tap detection, hand reordering, map panning, button hit detection, gesture recognition (tap vs drag). Still also holds most shop/workbench/contract actions. `Touch.released` dispatches per-screen work through `releasePhaseHandlers[gamePhase]`, drops through `releaseDropHandlers[draggedFrom]`, and `Touch.pressed` calls `pressHandlers.*` in place; handlers return `true` when they consumed the event. Fusion/enhance/pawn/flatten/mitosis share the workbench helpers at the top of the file
  - **animation.lua**: Core animation engine — easing functions (easeOutQuart, easeOutBack, easeOutElastic, easeOutBounce), physics simulation for dice (momentum/friction/wall bouncing), floating text, score popups, cup capture animation, avoidance zones to prevent dice landing on UI
  - **fonts.lua**: Pixellari.ttf loading with 11 responsive sizes, `drawText()` and `drawAnimatedText()` (opacity, scale, rotation, shake, shadow)
  - **colors.lua**: 6-color theme palette constants (Background dark, Background light, Font white, Font pink, Font red, Font red dark) plus tile blend colors for the hard-light shader
  - **audio.lua**: SFX banks (4 tile placement variants, UI sounds, chip loops, dice settle), background music at 15% volume, map ambiance system (dinner loop + random texture sounds), volume control, dynamic dampening when menus are open
  - **title_screen.lua**: Title screen with animated DEMOMINO tiles, NEW GAME/CONTINUE buttons, best round display
  - **sprites.lua**: All sprite loaders (`loadDominoSprites`, `loadNodeSprites`, ...) filling the global sprite tables, plus `getToolSpriteType`. Domino sprite lookup keys are built from a data table of `{key, file, inverted, flipped}` entries

### Game State Management
- Global `gameState` table (110+ fields) contains all game data initialized in `love.load()`
- **Game phases**: `"title_screen"`, `"intro_dialogue"`, `"demon_discovery"`, `"round_intro"`, `"playing"`, `"won"`, `"lost"`, `"run_complete"`, `"map"`, `"node_confirmation"`, `"tiles_menu"` (trade/pawn/alchemy/enhance/flatten/mitosis, chosen by `currentTilesNodeType`), `"artifacts_menu"`, `"contracts_menu"`, `"deal_menu"`, `"deal_artifacts_menu"`, `"restore_menu"`, `"casino"`
- `"intro_dialogue"` — cutscene sequence triggered after NEW GAME
- `"round_intro"` — animated "Night X" transition before combat
- Screen scaling system for cross-platform compatibility
- Save/load system persists progress between sessions

### Key Game Mechanics
- Standard domino deck (28 tiles, 0-0 through 6-6) plus special odd/even tiles
- 7-tile hand with automatic refilling after plays
- Drag-and-drop tile placement with auto-connection logic
- Scoring system with bonuses for doubles, chain length (3+ tiles), and connections
- Limited discards and plays per round (configurable via `maxDiscardsPerRound`, `maxHandsPerRound`)
- Touch/mouse input with gesture recognition (tap vs drag)
- Roguelike progression: coins, tile collection, tools, contracts persist across rounds

### Code Conventions
- Modules return themselves for require() usage
- CamelCase module names (Domino, Hand, Board, etc.)
- Functions use module.functionName pattern
- UI namespace with sub-modules (UI.Layout, UI.Renderer, UI.Animation, UI.Fonts, UI.Touch, UI.Colors, UI.Audio)
- No external dependencies beyond Love2D framework

## Development Commands

### Running the Game
```bash
love .
```
Requires Love2D/LÖVE framework installed. Game supports desktop and mobile platforms.

### Tests
- **Unit tests** (no Love2D needed): `tests/run.sh` runs every `tests/test_*.lua` with LuaJIT. `tests/helpers.lua` stubs `love.math`/`love.filesystem`/`UI.Layout` and provides `T.eq`/`T.ok`.
- **Golden-master / smoke harness** (needs `love` and `xvfb-run`): `tests/golden/run.sh <trace> [seed] [steps]` boots the real game under Xvfb with a frozen clock and seeded RNG, replays deterministic fuzz input and writes a per-step hash of every `gameState` key. `GOLDEN_MODE=scenario` enters every node type via `Touch.routeToNode` and fuzzes each screen; `GOLDEN_MODE=resetleak` lists state that survives NEW GAME. It exits non-zero on any Lua error or crash.
- **Refactoring safely**: record traces on the commit before the change (`git worktree add` + `GOLDEN_REPO=<worktree>`), record again after, and `diff` them. A pure refactor must give identical traces for the same seeds.
- CI (`.github/workflows/tests.yml`) runs the unit tests and a scenario + fuzz smoke run on every push.

### Building for Distribution
- **CI (GitHub Actions)**: `.github/workflows/android.yml` builds a signed APK named **DEMOMINO** (`com.cmatute.demomino`, `sensorLandscape`) on every push. Landscape is enforced at runtime too: CI patches love-android's `GameActivity.setOrientationBis` to always pass a landscape-only hint, because `t.window.resizable = true` would otherwise make SDL allow portrait; `v*` tags also publish a GitHub Release with the APK. Signing uses the `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` repo secrets (throwaway key if missing). Pushes touching only docs, `tests/`, `fire-trial/` or `*.sh` skip the build.
- **Launcher icon**: `android/res/` (vertical 5|5 demon double with eye pips chained between horizontal regular 2|5 / 5|6 tiles on the maroon `#3E2D35` background), copied over love-android's `res/` by CI. Regenerate with `python3 android/make_icons.py` (needs Pillow).
- **.love file**: The `dominatrix.love` file is the packaged game
- **Mobile builds**: Use Love2D's mobile build tools for Android/iOS deployment
  - **IMPORTANT**: Configure app to **FORCE LANDSCAPE ORIENTATION** (game is designed for horizontal play only)
  - Set orientation in AndroidManifest.xml: `android:screenOrientation="sensorLandscape"`
  - Set orientation in iOS Info.plist: `UISupportedInterfaceOrientations` to landscape only
- **IMPORTANT**: Save files (`demomino_save.lua`) are created at runtime in user directories, NOT in the game package
  - Do not include `demomino_save.lua` when packaging for distribution
  - Each fresh install will start with no saved game (title screen shows only NEW GAME and OPTIONS)
  - Save locations: Android (`/data/data/[app.id]/files/`), iOS (`Documents/`), Desktop (`~/.local/share/love/[game]/`)

## Key Architecture Details

### Module Loading Order
The game loads modules in this specific order (top of `love.load()` in main.lua):
1. Core game modules: i18n, domino, hand, board, validation, scoring, challenges, boss_behaviors, demon_data, map, save, tools, contracts, drawbacks, dialogue
2. UI modules: touch, layout, fonts, colors, renderer, animation, audio, title_screen, sprites, tile_fire, hud_animation, scoring_sequence, dialogue_flow, then game/casino
3. Sprite loading (functions in `ui/sprites.lua`):
   - `loadDominoSprites()` — standard tiles (162 files including odd/even variants)
   - `loadDemonTileSprites()` — animated demon tile eye frames
   - `loadTitleScreenSprites()` — animated title tile
   - `loadNodeSprites()` — 8 map node type icons
   - `loadCoinSprite()` — currency sprite
   - `loadDemonIconSprites()` — 22 demon character portraits
   - `loadCandleSprites()` — candle variants for map
   - `loadToolSprites()` — 9 die/cup sprites for tools
   - `loadCupSprites()` — cup animation frames

### Title Screen & Save System
- Game starts at `gamePhase = "title_screen"` instead of directly initializing a game
- **NEW GAME**: Starts fresh game, deletes any existing save, resets ALL state (shop, fusion, challenges, coins)
- **CONTINUE**: Only visible if save file exists, loads saved progress
- **OPTIONS**: Opens settings menu (music toggle only from title screen)
- **Best Round Display**: Shows highest round achieved (persists across all runs)
- Auto-save triggers:
  - When returning to title screen from in-game
  - After winning a combat round (on "Continue to Map")
  - When selecting "Return to Title" from lost screen
- Save data includes: currentRound, coins, tileCollection, map state, targetScore
- Stats data (separate file): bestRound (persists even when save is deleted)
- Lost screen offers: "RESTART RUN" (deletes save) or "RETURN TO TITLE" (saves progress)
- Settings menu (in-game) offers: "RESTART RUN" (deletes save) or "RETURN TO TITLE" (saves progress)

### Settings/Pause Menu
- **Accessible from**: Title screen, main game, map, node confirmation, tiles menu, artifacts menu, contracts menu
- **Functions as pause menu** during gameplay (game continues in background on map/menus)
- **Music toggle**: Enable/disable background music
- **RESTART RUN**: Complete reset to round 1, deletes save (only in-game)
- **RETURN TO TITLE**: Auto-saves and returns to title screen (only in-game)
- Settings button: Gear icon in top-right corner

### Animation System
- Comprehensive text animation system documented in `ANIMATION_GUIDE.txt`
- Central `UI.Animation` module (`ui/animation.lua`) with easing functions (easeOutQuart, easeOutBack, easeOutElastic, easeOutBounce)
- Physics simulation for tool dice: full momentum, friction (0.92x per frame), wall bouncing (0.7x energy), avoidance zones
- Cup capture animation: swooping entrance, dice throwing, ascending exit
- Animation states tracked in global `gameState` (multiple per-system tables)
- Font system with auto-scaling based on screen resolution

### Tile Connection Logic
- **Authoritative source**: `Domino.canConnect(domino1, side1, domino2, side2)` in `game/domino.lua`
- Supports direct pip matching and special odd/even tile matching
- `Validation.validateSequentialPlacement()`, `Validation.canFitAtEnd()`, `Validation.orientForEnd()` and `Validation.canConnectBothWays()` delegate to `Domino.canConnect`
- **When modifying connection rules**, only change `Domino.canConnect` — validation picks it up automatically

### Fusion/Alchemy System
- `gameState.tilesMenuMode` switches between `"shop"` and `"fusion"` within the tiles menu
- `gameState.fusionHand` — 7-tile hand shown in fusion mode
- `gameState.fusionSlotTiles` — `{tile1, tile2}` slots for the fusion input
- Fusion result logic lives in ui/touch.lua (`Touch.confirmFusion`) and game/domino.lua (`Domino.fuseTiles`)

### Tools vs Artifacts
- **Tools** (`game/tools.lua`): 9 types, max 3 owned, appear as persistent dice sprites on the board, dragged from the tool stack UI via `gameState.draggedTool`
- **Artifacts menu** (`"artifacts_menu"` phase): shop for purchasing tools
- Tool stack UI state: `gameState.toolStackAnimation`, `gameState.toolStackExplosion`, `gameState.activeDieSprites`

### Coin System
- `gameState.coins` — current player currency
- Full animation state in `gameState.coinsAnimation` — falling coins, chip loops, flip animations
- Coin update logic (`updateCoins()`) lives in ui/hud_animation.lua

### Board vs Placed Tiles
- `gameState.board` — populated by `Board.placeTiles()` during chain arrangement; cleared by `Board.clear()`
- `gameState.placedTiles` — the live array used by `Board.arrangePlacedTiles()`, `Board.getTileAt()`, and scoring; reflects what the player sees on the board
- `Board.clear()` resets `gameState.board`; main.lua resets `gameState.placedTiles` separately on round start

### Map System
- DAG-based map generation in `game/map.lua` (~2800 lines)
- 8-12 depth levels with 5-6 possible paths
- Camera scrolling system for navigation
- Node types: combat, tile shop, artifact shop, contract shop
- Candle lighting + fog of war system
- Demon assignment per node via `game/demon_data.lua`
- One known TODO: L-shape intermediate point calculation in path drawing (search `TODO` in map.lua)

### Asset Structure
- **Sprites**: `sprites/tiles/` (162 files — normal dominoes + odd/even variants) and `sprites/titled_tiles/` (168 files — rotated versions)
- **Demon tiles**: `sprites/demon_tiles/` — vertical/tilted variants + eye animation frames
- **Demon icons**: `sprites/demon_icon/` — 22 character portraits (ASTAROTH, ASMODEUS, BEELZEBUB, etc.) + imp variants
- **Map nodes**: `sprites/nodes/` — 8 node type icons with selected variants
- **Tool dice**: `sprites/dice/` — 9 sprites (blood, bone, brain, guts, void, cup frames 1-4)
- **Map assets**: `sprites/map/` — 8 sprites (candle variants, light radius indicators)
- **Currency**: `sprites/currency/` — coin sprite
- **Font**: `Pixellari.ttf` (pixel art style with fallback support)
- **Naming**: Domino sprites follow pattern `XY.png` where X and Y are pip values; tilted versions use same pattern in `titled_tiles/`
- **Shader**: `shaders/background_crt.glsl` — CRT post-processing effect

### Dialogue System
The game has two integrated dialogue systems that share the same visual presentation:

#### Combat Dialogue (Regular Gameplay)
- Displays random flavour text during combat on specific triggers
- Active in all combat rounds EXCEPT round 1 when tutorial is enabled
- Managed by `gameState.dialogueAnimation` table in main.lua
- Auto-dismisses after 2 seconds or on player tap (top third of screen)
- Reset in `initializeCombatRound()` to ensure proper state for each round

#### Tutorial Dialogue (Round 1 with Tutorial Toggle ON)
- Teaching system for first-time players, triggered only in round 1
- Controlled by `gameState.tutorialEnabled` setting (persisted in `demomino_settings.lua`)
- Managed by `gameState.tutorialState` table tracking progress flags
- **IMPORTANT**: Resets completely every time player enters round 1 (even on restarts)

**Tutorial Message Flow**:
1. Round start: "Try to score {targetScore} points" (auto-dismiss after 2s)
2. After message 1 dismiss: "Drag tiles from hand to center to play" (requires action)
3. After first tile placed: "Good! Chain as many tiles as you can" (auto-dismiss after 2s)
4. After 5s idle (post-message 3): Random idle prompt (requires action)
5. After non-winning play: "Still missing a couple" (auto-dismiss after 2s)
6. After winning play: "Good luck, proceed" (auto-dismiss after 2s)
7. BONUS: On board drag attempt: "Tap tiles on board twice to return them to hand"

**Key Implementation Rules**:
- **Pending Message System**: Game actions (tile placement, hand plays) set `tutorialState.pendingMessage` instead of showing messages immediately
- **Dismiss Animation**: All dismissals (auto or manual) trigger 0.1s pink flash + sound before clearing dialogue
- **Message Queueing**: New messages only show AFTER dismiss animation completes (checked in `updateTutorialDialogue()`)
- **Action-Required Messages**: Messages 2 and 4 have `currentMessageRequiresAction = true` to prevent auto-dismiss
- **Tap Detection**: Only top third of screen registers dialogue taps (same as combat dialogue)
- **Integration**: Tutorial uses same `dialogueAnimation` table as combat dialogue (not separate system)

**Core Functions** (all in ui/dialogue_flow.lua):
- `showTutorialMessage(message, requiresAction)`: Initializes tutorial dialogue with typewriter effect
- `dismissTutorialOnAction()`: Triggers dismiss animation when player performs relevant action
- `updateTutorialDialogue(dt)`: Handles timing, auto-dismiss, animation, and message queueing
- `initializeDialogue(text, category)`: Suppressed during round 1 with tutorial enabled

**Files Involved**:
- **main.lua**: Tutorial state (`gameState.tutorialState`)
- **ui/dialogue_flow.lua**: Tutorial message logic, timing, animation handling
- **ui/touch.lua**: Tap detection (top third), tile placement triggers, discard triggers, drag detection
- **ui/renderer.lua**: Settings menu tutorial toggle rendering
- **game/save.lua**: Tutorial setting persistence (`saveSettings()`, `loadSettings()`)

### Cross-Platform Compatibility
- **Mobile (Android/iOS)**: Automatic fullscreen, **ALWAYS LANDSCAPE MODE** (game is designed for horizontal orientation)
- **Desktop**: Resizable windows with iPhone-like landscape aspect ratio (1014x468 default, 2.16:1)
- Nearest-neighbor filtering for pixel art graphics
- Responsive layout system that adapts to screen dimensions
- Save file location: `demomino_save.lua` in user directory (varies by platform)

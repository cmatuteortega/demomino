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

- **main.lua**: Entry point with Love2D callbacks (love.load, love.update, love.draw) and global `gameState` management. Houses tutorial logic, dialogue orchestration, round initialization, coin updates, and sprite loading functions.
- **game/**: Core game logic modules
  - **domino.lua**: Domino tile creation, manipulation, and utilities. Authoritative source for tile connection logic (`Domino.canConnect`), odd/even special tiles, fusion system, sprite caching, deck generation (standard 28-tile 0-0 to 6-6 plus special tiles)
  - **hand.lua**: Player hand management — tile drawing with staggered animations, selection, idle floating animations, arc-trajectory sorting, drag-and-drop, discard animations, hand reordering
  - **board.lua**: Board state management — dynamic scaling for tile chains, tile positioning (`arrangePlacedTiles`), hit detection (`getTileAt`), bounds calculation. Uses `gameState.placedTiles` as the active tile array
  - **scoring.lua**: Score calculation with breakdowns — tile value summation, obsidian multipliers, double bonuses, contract integration hooks, high score tracking
  - **validation.lua**: Chain validation, sequential placement checking, `findValidChain` (tries all permutations), `createDominoChain`, `isValidPlacement` (delegates odd/even logic to `Domino.canConnect`)
  - **challenges.lua**: Challenge type definitions (anchor tiles, max tiles, banned numbers), per-challenge state management, modular effect system applied at placement validation
  - **contracts.lua**: 6 contract types with scoring modifiers (Lucky Five, Greedy, Perfect Loop), shop generation, dual active contract limit (max 2 active)
  - **tools.lua**: 9 tool/artifact types (Tile Injector, Transformer, etc.), shop generation, usage/cost tracking, 3-tool max. Tool sprites appear as persistent dice on the board
  - **dialogue.lua**: Dialogue text management, trigger types (on_enter, idle, action), text wrapping, typewriter effect support for all screens
  - **demon_data.lua**: Demon name pools (boss vs regular), description data, icon sprite associations for 22 demon characters
  - **map.lua**: DAG-based procedural map generation — 8-12 depth levels, 5-6 possible paths, camera scrolling, candle lighting, fog of war, node-based progression
  - **save.lua**: Save/load system — full game state serialization, map persistence, tile collection, settings (music/sfx/tutorial), stats tracking (bestRound persists across all runs)
- **ui/**: User interface and interaction modules
  - **layout.lua**: Responsive layout calculations and screen positioning — hand area, board area, button positions, tool stack positions, mobile vs desktop detection
  - **renderer.lua**: Drawing and visual representation of all game elements (~5400 lines). 74 draw functions covering dominoes, board, hand, score formula, menus, dialogue, tool sprites, CRT shader
  - **touch.lua**: Input handling for mouse/touch (~3400 lines) — drag-and-drop for tiles and tools, double-tap detection, hand reordering, map panning, button hit detection, gesture recognition (tap vs drag)
  - **animation.lua**: Core animation engine — easing functions (easeOutQuart, easeOutBack, easeOutElastic, easeOutBounce), physics simulation for dice (momentum/friction/wall bouncing), floating text, score popups, cup capture animation, avoidance zones to prevent dice landing on UI
  - **fonts.lua**: Pixellari.ttf loading with 11 responsive sizes, `drawText()` and `drawAnimatedText()` (opacity, scale, rotation, shake, shadow)
  - **colors.lua**: 6-color theme palette constants (Background dark, Background light, Font white, Font pink, Font red, Font red dark) plus tile blend colors for the hard-light shader
  - **audio.lua**: SFX banks (4 tile placement variants, UI sounds, chip loops, dice settle), background music at 15% volume, map ambiance system (dinner loop + random texture sounds), volume control, dynamic dampening when menus are open
  - **title_screen.lua**: Title screen with animated DEMOMINO tiles, NEW GAME/CONTINUE buttons, best round display

### Game State Management
- Global `gameState` table (110+ fields) contains all game data initialized in `love.load()`
- **Game phases**: `"title_screen"`, `"intro_dialogue"`, `"round_intro"`, `"playing"`, `"won"`, `"lost"`, `"map"`, `"node_confirmation"`, `"tiles_menu"`, `"artifacts_menu"`, `"contracts_menu"`
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

### Building for Distribution
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
The game loads modules in this specific order (main.lua lines 20-39):
1. Core game modules: domino, hand, board, validation, scoring, challenges, demon_data, map, save, tools, contracts, dialogue
2. UI modules: touch, layout, fonts, colors, renderer, animation, audio, title_screen
3. Sprite loading:
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
- `Validation.validateSequentialPlacement()` and `Validation.findValidChain()` delegate to `Domino.canConnect`
- **When modifying connection rules**, only change `Domino.canConnect` — validation picks it up automatically

### Fusion/Alchemy System
- `gameState.tilesMenuMode` switches between `"shop"` and `"fusion"` within the tiles menu
- `gameState.fusionHand` — 7-tile hand shown in fusion mode
- `gameState.fusionSlotTiles` — `{tile1, tile2}` slots for the fusion input
- Fusion result logic lives in main.lua and tools.lua

### Tools vs Artifacts
- **Tools** (`game/tools.lua`): 9 types, max 3 owned, appear as persistent dice sprites on the board, dragged from the tool stack UI via `gameState.draggedTool`
- **Artifacts menu** (`"artifacts_menu"` phase): shop for purchasing tools
- Tool stack UI state: `gameState.toolStackAnimation`, `gameState.toolStackExplosion`, `gameState.activeDieSprites`

### Coin System
- `gameState.coins` — current player currency
- Full animation state in `gameState.coinsAnimation` — falling coins, chip loops, flip animations
- Not a separate module — coin update logic (`updateCoins()`) lives in main.lua

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
- One known TODO: L-shape intermediate point calculation in path drawing (map.lua:1779)

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

**Core Functions** (all in main.lua):
- `showTutorialMessage(message, requiresAction)`: Initializes tutorial dialogue with typewriter effect
- `dismissTutorialOnAction()`: Triggers dismiss animation when player performs relevant action
- `updateTutorialDialogue(dt)`: Handles timing, auto-dismiss, animation, and message queueing
- `initializeDialogue(text, category)`: Suppressed during round 1 with tutorial enabled

**Files Involved**:
- **main.lua**: Tutorial state, message logic, timing, animation handling
- **ui/touch.lua**: Tap detection (top third), tile placement triggers, discard triggers, drag detection
- **ui/renderer.lua**: Settings menu tutorial toggle rendering
- **game/save.lua**: Tutorial setting persistence (`saveSettings()`, `loadSettings()`)

### Cross-Platform Compatibility
- **Mobile (Android/iOS)**: Automatic fullscreen, **ALWAYS LANDSCAPE MODE** (game is designed for horizontal orientation)
- **Desktop**: Resizable windows with iPhone-like landscape aspect ratio (1014x468 default, 2.16:1)
- Nearest-neighbor filtering for pixel art graphics
- Responsive layout system that adapts to screen dimensions
- Save file location: `demomino_save.lua` in user directory (varies by platform)

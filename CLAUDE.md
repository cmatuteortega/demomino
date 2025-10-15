# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a domino-based deckbuilding game written in Lua using the LÖVE (Love2D) framework. The game involves placing domino tiles on a board to create scoring combinations.

## Running the Game
- Run the game with Love2D: `love .` (requires Love2D/LÖVE framework installed)
- The game is designed to work on desktop and mobile platforms (Android/iOS)

## Architecture

### Core Game Structure
The game follows a modular Lua architecture with clear separation of concerns:

- **main.lua**: Entry point with Love2D callbacks (love.load, love.update, love.draw) and global gameState management
- **game/**: Core game logic modules
  - **domino.lua**: Domino tile creation, manipulation, and utilities (standard 28-tile deck from 0-0 to 6-6)
  - **hand.lua**: Player hand management, tile drawing, selection, and positioning
  - **board.lua**: Board state management and tile placement validation
  - **scoring.lua**: Score calculation with bonuses for doubles, chain length, and connections
  - **validation.lua**: Game rule validation for tile connections and legal moves
  - **save.lua**: Save/load system for game persistence (saves to user directory at runtime)
- **ui/**: User interface and interaction modules
  - **layout.lua**: Responsive layout calculations and screen positioning
  - **renderer.lua**: Drawing and visual representation of game elements
  - **touch.lua**: Input handling for mouse/touch interactions, drag-and-drop mechanics
  - **title_screen.lua**: Title screen with NEW GAME, CONTINUE, and OPTIONS buttons

### Game State Management
- Global `gameState` table contains all game data (deck, hand, board, score, screen dimensions)
- Game phases: "title_screen", "playing", "won", "lost", "map", "tiles_menu", "artifacts_menu", "contracts_menu", "node_confirmation"
- Screen scaling system for cross-platform compatibility
- Save/load system persists progress between sessions

### Key Game Mechanics
- Standard domino deck (28 tiles, 0-0 through 6-6)
- 7-tile hand with automatic refilling after plays
- Drag-and-drop tile placement with auto-connection logic
- Scoring system with bonuses for doubles, chain length (3+ tiles), and connections
- Limited discards (2 max) and plays (win at 100 points or lose after 2 plays + 2 discards)
- Touch/mouse input with gesture recognition (tap vs drag)

### Code Conventions
- Modules return themselves for require() usage
- CamelCase module names (Domino, Hand, Board, etc.)
- Functions use module.functionName pattern
- UI namespace with sub-modules (UI.Layout, UI.Renderer, UI.Animation, UI.Fonts, UI.Touch)
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
The game loads modules in this specific order (main.lua:18-33):
1. Core game modules (domino, hand, board, validation, scoring, challenges, map, save)
2. UI modules (touch, layout, fonts, colors, renderer, animation, audio, title_screen)
3. Sprite loading via `loadDominoSprites()`, `loadDemonTileSprites()`, `loadNodeSprites()`, `loadCoinSprite()`

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
- Central `UI.Animation` module with easing functions (easeOutQuart, easeOutBack, easeOutElastic)
- Animation states tracked in global `gameState`
- Font system with auto-scaling based on screen resolution

### Map System
- DAG-based map generation in `game/map.lua`
- 8-12 depth levels with 5-6 possible paths
- Camera scrolling system for navigation
- Node-based progression system

### Asset Structure
- **Sprites**: `sprites/tiles/` (normal dominoes) and `sprites/titled_tiles/` (rotated versions)
- **Font**: `Pixellari.ttf` (pixel art style with fallback support)
- **Naming**: Domino sprites follow pattern `XY.png` where X and Y are pip values (0-6)

### Cross-Platform Compatibility
- **Mobile (Android/iOS)**: Automatic fullscreen, **ALWAYS LANDSCAPE MODE** (game is designed for horizontal orientation)
- **Desktop**: Resizable windows with iPhone-like landscape aspect ratio (1014x468 default, 2.16:1)
- Nearest-neighbor filtering for pixel art graphics
- Responsive layout system that adapts to screen dimensions
- Save file location: `demomino_save.lua` in user directory (varies by platform)
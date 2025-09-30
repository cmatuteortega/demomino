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
- **ui/**: User interface and interaction modules
  - **layout.lua**: Responsive layout calculations and screen positioning
  - **renderer.lua**: Drawing and visual representation of game elements
  - **touch.lua**: Input handling for mouse/touch interactions, drag-and-drop mechanics

### Game State Management
- Global `gameState` table contains all game data (deck, hand, board, score, screen dimensions)
- Game phases: "playing", "won", "lost"
- Screen scaling system for cross-platform compatibility

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

## Key Architecture Details

### Module Loading Order
The game loads modules in this specific order (main.lua:18-28):
1. Core game modules (domino, hand, board, validation, scoring, map)
2. UI modules (touch, layout, fonts, renderer, animation)
3. Sprite loading via `loadDominoSprites()`

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
- Automatic fullscreen on mobile (Android/iOS)
- Resizable windows on desktop
- Nearest-neighbor filtering for pixel art graphics
- Responsive layout system that adapts to screen dimensions